extends SceneTree

const FIXTURE_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var flat_surface := await _load_fixture(TerrainTestFixtureFactory.Kind.FLAT)
	_assert_true(flat_surface.get_node_or_null("TerrainTopBody") is StaticBody3D, "fixture must load TerrainTopBody")
	_assert_true(flat_surface.get_node_or_null("TerrainShellBody") is StaticBody3D, "fixture must load TerrainShellBody")
	_assert_true(flat_surface.is_top_collider(await _cast(Vector3(0, 10, 0), Vector3(0, -100, 0))), "flat cast must hit top body")
	_assert_true(flat_surface.is_top_collider(await _cast(Vector3(-10, 1, 0), Vector3(80, -20, 0))), "graze cast must hit top body")
	_assert_true(flat_surface.is_skirt_collider(await _cast(Vector3(20, -4, 0), Vector3(-100, 0, 0))), "skirt cast must hit shell body")
	flat_surface.queue_free()
	await physics_frame

	var ramp_surface := await _load_fixture(TerrainTestFixtureFactory.Kind.RAMP)
	var ramp_y := TerrainTestFixtureFactory.ramp_height(0.0)
	_assert_true(ramp_surface.is_top_collider(await _cast(Vector3(0, ramp_y + 10, 0), Vector3(0, -100, 0))), "ramp cast must hit top body")
	ramp_surface.queue_free()
	await physics_frame
	if not _failed:
		print("Phase 2 terrain fixture checks passed: flat, ramp, graze, and skirt classified by body identity.")
	quit(1 if _failed else 0)


func _load_fixture(kind: TerrainTestFixtureFactory.Kind) -> TerrainSurface:
	var surface := FIXTURE_SCENE.instantiate() as TerrainSurface
	root.add_child(surface)
	surface.configure(TerrainTestFixtureFactory.build_layout(kind))
	await physics_frame
	await physics_frame
	return surface


func _cast(start: Vector3, motion: Vector3) -> Object:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.motion = motion
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var space := root.get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	if fractions.is_empty() or fractions[0] >= 1.0:
		return null
	query.transform.origin = start + motion * minf(float(fractions[1]) + 0.002, 1.0)
	var hits := space.intersect_shape(query, 8)
	return hits[0].collider if not hits.is_empty() else null


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Phase 2 fixture check failed: %s" % message)
