extends SceneTree

const TERRAIN_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const CANNON_SCENE := preload("res://scenes/gameplay/cannon.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	for stage_id in [&"stage_01", &"stage_30"]:
		await _check_stage(catalog, stage_id)
	if not _failed:
		print("phase8_aiming_composition_test passed: readable mountain mass, foreground cannon, and cached Aim View")
	quit(1 if _failed else 0)


func _check_stage(catalog: StageCatalogData, stage_id: StringName) -> void:
	var stage := catalog.get_stage(stage_id)
	var layout := StageLayoutBakeCodec.hydrate(
		load(catalog.get_layout_path(stage_id)) as BakedStageLayoutData,
		stage
	)
	var host := Node3D.new()
	root.add_child(host)
	var terrain := TERRAIN_SCENE.instantiate() as TerrainSurface
	terrain.position = stage.terrain_center
	host.add_child(terrain)
	terrain.configure(layout)
	var cannon := CANNON_SCENE.instantiate() as CannonController
	host.add_child(cannon)
	cannon.global_transform = stage.cannon_transform
	var camera := Camera3D.new()
	camera.fov = 48.0
	host.add_child(camera)
	var manager := ProjectileManager.new()
	host.add_child(manager)
	var director := CameraDirector.new()
	host.add_child(director)
	director.configure(camera, stage, manager, terrain, cannon)
	director.set_mode(CameraDirector.Mode.AIMING, true)
	for _frame in range(12):
		await physics_frame
		await process_frame
	var build_count := director.aiming_interest_build_count()
	_assert(build_count == 1, "%s Aim View must build immutable interest data once" % stage_id)
	director.set_interaction_mode(CameraDirector.InteractionMode.MAP_INSPECTION)
	director.set_interaction_mode(CameraDirector.InteractionMode.AIM_LOCKED)
	_assert(director.aiming_interest_build_count() == build_count, "%s Aim/Map toggle must reuse the cached pose" % stage_id)
	var terrain_points := terrain.playable_top_world_points()
	var interest := terrain_points.duplicate()
	for summit in layout.summit_region(0.25):
		var point := terrain.to_global(summit.point as Vector3)
		interest.append(point)
		interest.append(point + Vector3.UP * 8.0)
	interest.append(cannon.global_position)
	interest.append(cannon.get_launch_origin())
	var pose := AimCameraComposer.compose(interest, terrain.render_world_aabb(), stage.cannon_transform, 48.0, 16.0 / 9.0)
	_assert(not pose.is_empty(), "%s shared Aim View composer must return a pose" % stage_id)
	if not pose.is_empty():
		var runtime_position := camera.global_position
		var runtime_focus := director.camera_focus_position()
		var terrain_rect := _projected_rect(terrain_points, runtime_position, runtime_focus)
		var cannon_rect := _projected_rect(_cannon_points(cannon), runtime_position, runtime_focus)
		var silhouette_ratio := terrain_rect.size.y / maxf(terrain_rect.size.x, 0.0001) * (720.0 / 1280.0)
		var cannon_height_ratio := cannon_rect.size.y * 0.5
		print("%s runtime pose=%s focus=%s silhouette=%.3f cannon=%.3f visible=%.3f" % [stage_id, str(runtime_position), str(runtime_focus), silhouette_ratio, cannon_height_ratio, _visible_fraction(cannon_rect)])
		_assert(_visible_fraction(terrain_rect) >= 0.65, "%s Aim View must retain most of the useful mountain mass" % stage_id)
		_assert(_visible_fraction(cannon_rect) >= 0.85, "%s cannon must remain visibly anchored in the lower foreground" % stage_id)
		_assert(cannon_height_ratio >= 0.10, "%s cannon must not disappear in the foreground; got %.3f viewport height" % [stage_id, cannon_height_ratio])
	host.queue_free()
	await process_frame


func _projected_rect(points: PackedVector3Array, position: Vector3, focus: Vector3) -> Rect2:
	var forward := (focus - position).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var vertical_tangent := tan(deg_to_rad(24.0))
	var horizontal_tangent := vertical_tangent * (16.0 / 9.0)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		var relative := point - position
		var depth := maxf(relative.dot(forward), 0.0001)
		var projected := Vector2(
			relative.dot(right) / (depth * horizontal_tangent),
			relative.dot(up) / (depth * vertical_tangent)
		)
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	return Rect2(minimum, maximum - minimum)


func _visible_fraction(projected_rect: Rect2) -> float:
	if not projected_rect.has_area():
		return 0.0
	var viewport_rect := Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0))
	return viewport_rect.intersection(projected_rect).get_area() / projected_rect.get_area()


func _cannon_points(cannon: CannonController) -> PackedVector3Array:
	var points := PackedVector3Array()
	for node in cannon.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var bounds := mesh_node.global_transform * mesh_node.mesh.get_aabb()
		for corner in TerrainCameraFramer.bounds_corners(bounds):
			points.append(corner)
	return points


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
