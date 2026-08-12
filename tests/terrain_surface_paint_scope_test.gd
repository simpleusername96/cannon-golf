extends SceneTree

const TERRAIN_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const TUNING: PaintSurfaceTuning = preload("res://resources/paint/default_paint_surface_tuning.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	var stage := catalog.get_stage(&"stage_01")
	var layout := StageLayoutBakeCodec.hydrate(
		load(catalog.get_layout_path(stage.stage_id)) as BakedStageLayoutData,
		stage
	)
	var terrain := TERRAIN_SCENE.instantiate() as TerrainSurface
	terrain.position = stage.terrain_center
	root.add_child(terrain)
	terrain.configure(layout)
	await physics_frame
	var top_body := terrain.get_node("TerrainTopBody") as StaticBody3D
	var shell_body := terrain.get_node("TerrainShellBody") as StaticBody3D
	var non_target_sample := _first_non_target_surface_sample(layout)
	_assert(not non_target_sample.is_empty(), "Stage 01 must expose playable non-target terrain")
	if not non_target_sample.is_empty():
		var world_point := terrain.to_global(non_target_sample.point as Vector3)
		var top_contact := _contact(
			world_point,
			top_body,
			TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
			TerrainSurface.TOP_SHAPE_ID
		)
		_assert(SurfaceContactGapValidator.is_paintable_contact(terrain, TUNING, top_contact), "non-target Playable Terrain Surface must still paint")
		var shell_contact := _contact(world_point, shell_body, TerrainSurface.SHELL_OWNER_ID, TerrainSurface.SHELL_SHAPE_ID)
		_assert(not SurfaceContactGapValidator.is_paintable_contact(terrain, TUNING, shell_contact), "Support Shell must never paint")
	var fake_apron := StaticBody3D.new()
	root.add_child(fake_apron)
	var apron_contact := _contact(Vector3.ZERO, fake_apron, PlayBoundsSpec.APRON_OWNER_ID, PlayBoundsSpec.APRON_SHAPE_ID)
	_assert(not SurfaceContactGapValidator.is_paintable_contact(terrain, TUNING, apron_contact), "apron must never paint")
	terrain.queue_free()
	fake_apron.queue_free()
	if not _failed:
		print("terrain_surface_paint_scope_test passed: all playable surface paints; shell/apron do not")
	quit(1 if _failed else 0)


func _first_non_target_surface_sample(layout: GeneratedStageLayout) -> Dictionary:
	var mask := layout.target_mask
	for cell_y in range(layout.cell_count.y):
		for cell_x in range(layout.cell_count.x):
			var local_xz := layout.local_bounds.position + Vector2(
				(float(cell_x) + 0.5) / float(layout.cell_count.x) * layout.local_bounds.size.x,
				(float(cell_y) + 0.5) / float(layout.cell_count.y) * layout.local_bounds.size.y
			)
			var sample := layout.surface_sample_at_local(local_xz.x, local_xz.y, false)
			if sample.is_empty():
				continue
			var pixel := Vector2i(
				clampi(floori((local_xz.x - layout.local_bounds.position.x) / layout.local_bounds.size.x * 512.0), 0, 511),
				clampi(floori((local_xz.y - layout.local_bounds.position.y) / layout.local_bounds.size.y * 512.0), 0, 511)
			)
			if mask[pixel.y * 512 + pixel.x] < 128:
				return sample
	return {}


func _contact(point: Vector3, body: StaticBody3D, owner: StringName, shape: StringName) -> ProjectileContact:
	return ProjectileContact.new(
		point, Vector3.UP, point + Vector3.UP, 0.0, Vector3.DOWN, 1.0,
		Vector3.ZERO, body, 0, 0, 1, true, false, owner, shape, body.get_rid()
	)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
