extends SceneTree

const PROJECTILE_DATA: ProjectileData = preload("res://resources/projectiles/basic_paintball.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var effects := PresentationEffects.new()
	root.add_child(effects)
	await process_frame
	var sources := effects.warmup_sources()
	_assert_true(sources.size() == 5, "warm-up must cover every distinct presentation effect family")
	for source in sources:
		_assert_true(not source.emitting, "warm-up sources must start inactive")
	_assert_shared_effect_resources(effects)

	var warmup := GameplayFirstUseWarmup.new()
	root.add_child(warmup)
	var completed_count := [0]
	warmup.completed.connect(func() -> void: completed_count[0] += 1)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/paint/terrain_paint.gdshader")
	await warmup.run(_triangle_mesh(), material, PROJECTILE_DATA, sources)
	_assert_true(warmup.is_complete(), "render-only warm-up must publish completion")
	_assert_true(
		warmup.warmed_effect_family_count() == sources.size(),
		"warm-up must render each effect material family exactly once"
	)
	_assert_true(completed_count[0] == 1, "first warm-up run must emit one completion")
	_assert_true(
		warmup.get_node_or_null("FirstUseWarmupViewport") == null,
		"temporary render viewport must be freed before completion is published"
	)
	_assert_true(
		warmup.find_children("*", "RigidBody3D", true, false).is_empty(),
		"render-only warm-up must never create a physics projectile"
	)
	_assert_true(
		warmup.find_children("*", "StageController", true, false).is_empty() \
				and warmup.find_children("*", "PaintSystem", true, false).is_empty(),
		"warm-up must not create stage-rule or mutable-paint owners"
	)
	for source in sources:
		_assert_true(not source.emitting, "warm-up must not mutate the live presentation pools")

	var shared_warmup := GameplayFirstUseWarmup.new()
	root.add_child(shared_warmup)
	var shared_completed_count := [0]
	shared_warmup.completed.connect(func() -> void: shared_completed_count[0] += 1)
	var shared_start_frame := Engine.get_process_frames()
	shared_warmup.run(_triangle_mesh(), material, PROJECTILE_DATA, sources)
	_assert_true(
		shared_warmup.is_complete() and Engine.get_process_frames() == shared_start_frame,
		"a later stage with the same render families must reuse process-local warm-up synchronously"
	)
	_assert_true(
		shared_completed_count[0] == 1 \
				and shared_warmup.warmed_effect_family_count() == sources.size(),
		"shared completion must retain the exact warmed effect-family coverage"
	)
	_assert_true(
		shared_warmup.get_node_or_null("FirstUseWarmupViewport") == null,
		"shared warm-up reuse must not create another render viewport"
	)

	warmup.run(_triangle_mesh(), material, PROJECTILE_DATA, sources)
	_assert_true(completed_count[0] == 2, "idempotent repeated warm-up must complete synchronously")
	_assert_true(
		warmup.warmed_effect_family_count() == sources.size(),
		"idempotent repeated warm-up must not render any family twice"
	)
	if not _failed:
		print("Gameplay first-use warm-up passed: complete families, cleanup, idempotence, and no gameplay owners.")
	warmup.queue_free()
	shared_warmup.queue_free()
	effects.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _triangle_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-1.0, -1.0, 0.0),
		Vector3(1.0, -1.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.BACK,
		Vector3.BACK,
		Vector3.BACK,
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2.ZERO,
		Vector2.RIGHT,
		Vector2(0.5, 1.0),
	])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.RED, Color.RED])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _assert_shared_effect_resources(effects: PresentationEffects) -> void:
	for pair in [
		["PaintSplash01", "PaintSplash02"],
		["PaintMist01", "PaintMist02"],
		["ImpactRipple01", "ImpactRipple02"],
		["MuzzleRing01", "MuzzleRing02"],
		["Glint01", "Glint02"],
	]:
		var first := effects.get_node(String(pair[0])) as GPUParticles3D
		var second := effects.get_node(String(pair[1])) as GPUParticles3D
		_assert_true(
			first.process_material == second.process_material \
					and first.draw_pass_1 == second.draw_pass_1,
			"effect family %s must share immutable process and draw resources" % pair[0]
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
