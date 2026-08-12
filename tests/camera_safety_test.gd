extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.persistence_enabled = false
	game_state.unlocked_stages.assign([&"first_descent", &"burst_basin", &"split_ridge"])
	Engine.time_scale = 4.0
	var requested_stage := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			requested_stage = argument.trim_prefix("--stage=")
	var catalog := StageCatalog.all_stages()
	var probe_indices := [0, 9, 19, 29]
	if not requested_stage.is_empty():
		probe_indices = []
		for index in range(catalog.size()):
			if String(catalog[index].stage_id) == requested_stage:
				probe_indices.append(index)
	for stage_index in probe_indices:
		if stage_index < 0 or stage_index >= catalog.size():
			continue
		var stage := catalog[stage_index]
		print("Camera safety fixture started for %s." % stage.stage_id)
		game_state.selected_stage_id = stage.stage_id
		var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(stage.stage_id)
		_assert_true(gameplay != null, "%s must instantiate from its accepted baked layout" % stage.stage_id)
		if gameplay == null:
			continue
		root.add_child(gameplay)
		await physics_frame
		await physics_frame
		var camera: Camera3D = gameplay.get_node("Camera")
		var director: CameraDirector = gameplay.get_node("CameraDirector")
		var terrain: TerrainSurface = gameplay.get_node("TerrainSurface")
		var cannon: CannonController = gameplay.get_node("Cannon")
		if stage.stage_id in [&"stage_01", &"stage_02", &"stage_30"]:
			await _assert_presentation_frames(stage, camera, director, terrain)
		print("Camera safety: briefing fixtures.")
		_assert_true(
			director.current_interaction_mode == CameraDirector.InteractionMode.MAP_INSPECTION,
			"%s briefing must begin in Map Inspection" % stage.stage_id
		)
		_assert_true(
			director.camera_focus_position().is_equal_approx(terrain.visual_world_center()),
			"%s briefing must focus the fixed terrain visual center" % stage.stage_id
		)
		for yaw in [-22.0, 0.0, 22.0]:
			for zoom in [-22.0, 28.0]:
				director.set_mode(CameraDirector.Mode.BRIEFING, true)
				director.set_briefing_offsets(yaw, zoom)
				await _sample_camera(camera, director, terrain, 4, "%s briefing %.0f/%.0f" % [stage.stage_id, yaw, zoom])
		for mode in [CameraDirector.Mode.AIMING, CameraDirector.Mode.RESULT]:
			director.set_mode(mode)
			await _sample_camera(camera, director, terrain, 6, "%s bookmark %s" % [stage.stage_id, CameraDirector.Mode.keys()[mode]])
		_assert_safe_aiming_frame(stage, camera, director, terrain, cannon)
		print("Camera safety: bookmarks complete.")
		var center_surface := terrain.world_surface_point(Vector2(stage.terrain_center.x, stage.terrain_center.z))
		var safe_top := director.safe_position_for(center_surface - Vector3.UP * 12.0, center_surface, true)
		_assert_clearance(safe_top, terrain, "%s top fixture" % stage.stage_id)
		var edge_xz := Vector2(stage.terrain_center.x + stage.terrain_size.x * 0.49, stage.terrain_center.z)
		var edge_surface := terrain.world_surface_point(edge_xz)
		var safe_skirt := director.safe_position_for(edge_surface - Vector3.UP * 8.0, edge_surface, true)
		_assert_clearance(safe_skirt, terrain, "%s skirt fixture" % stage.stage_id)
		await _exercise_map_inspection(camera, director, terrain, stage)
		print("Camera safety: map inspection complete.")
		print("Camera safety fixture completed for %s." % stage.stage_id)
		gameplay.queue_free()
		await process_frame
		await process_frame
	Engine.time_scale = 1.0
	game_state.persistence_enabled = true
	if not _failed:
		print("Camera safety checks passed for lifecycle views, map inspection, and terrain fixtures.")
	quit(1 if _failed else 0)


func _exercise_map_inspection(
		camera: Camera3D,
		director: CameraDirector,
		terrain: TerrainSurface,
		stage: StageData
) -> void:
	director.set_mode(CameraDirector.Mode.AIMING, true)
	_assert_true(director.aim_is_locked(), "%s Aiming must begin in Aim Lock" % stage.stage_id)
	_assert_true(
		director.set_interaction_mode(CameraDirector.InteractionMode.MAP_INSPECTION, true),
		"%s must allow Map Inspection during Aiming" % stage.stage_id
	)
	var center := terrain.visual_world_center()
	_assert_true(
		director.camera_focus_position().is_equal_approx(center),
		"%s Map Inspection must use the fixed terrain visual center" % stage.stage_id
	)
	var distance_before := director.inspection_distance()
	_assert_true(director.orbit_inspection(Vector2(80.0, -30.0)), "%s inspection orbit must accept drag" % stage.stage_id)
	_assert_true(director.zoom_inspection(1.0), "%s inspection zoom must accept wheel input" % stage.stage_id)
	_assert_true(director.inspection_distance() < distance_before, "%s wheel up must zoom closer" % stage.stage_id)
	await _sample_camera(camera, director, terrain, 8, "%s map inspection" % stage.stage_id)
	_assert_true(
		director.camera_focus_position().is_equal_approx(center),
		"%s orbit and zoom must not move the terrain visual center" % stage.stage_id
	)
	_assert_true(
		director.set_interaction_mode(CameraDirector.InteractionMode.AIM_LOCKED, true),
		"%s must return to Aim Lock" % stage.stage_id
	)
	await _sample_camera(camera, director, terrain, 2, "%s aim lock return" % stage.stage_id)


func _sample_camera(camera: Camera3D, director: CameraDirector, terrain: TerrainSurface, ticks: int, label: String) -> void:
	for _tick in range(ticks):
		await physics_frame
		_assert_clearance(camera.global_position, terrain, label)
		var focus := director.camera_focus_position()
		if director.current_interaction_mode == CameraDirector.InteractionMode.MAP_INSPECTION \
				and director.current_mode in [CameraDirector.Mode.BRIEFING, CameraDirector.Mode.AIMING]:
			_assert_true(
				focus.is_equal_approx(terrain.visual_world_center()),
				"%s inspection focus must remain at the terrain visual center" % label
			)
			var camera_forward := -camera.global_transform.basis.z.normalized()
			_assert_true(
				camera_forward.dot((focus - camera.global_position).normalized()) >= 0.999,
				"%s inspection camera must look at the fixed center" % label
			)
			continue
		var surface_focus := terrain.contains_world_xz(Vector2(focus.x, focus.z)) \
				and focus.distance_to(terrain.world_surface_point(Vector2(focus.x, focus.z))) <= 0.3
		_assert_true(
			director.view_ray_is_clear(camera.global_position, focus, surface_focus),
			"%s camera ray must not cross terrain: camera=%s focus=%s terrain_focus=%s" % [
				label, camera.global_position, focus, surface_focus,
			]
		)


func _assert_clearance(position: Vector3, terrain: TerrainSurface, label: String) -> void:
	if not terrain.contains_world_xz(Vector2(position.x, position.z)):
		return
	var surface_y := terrain.world_surface_point(Vector2(position.x, position.z)).y
	_assert_true(position.y - surface_y >= 1.5 - 0.001, "%s camera clearance is %.3fm" % [label, position.y - surface_y])


func _assert_safe_aiming_frame(
	stage: StageData,
	camera: Camera3D,
	director: CameraDirector,
	_terrain: TerrainSurface,
		cannon: CannonController
) -> void:
	director.set_mode(CameraDirector.Mode.AIMING, true)
	var focus := director.camera_focus_position()
	_assert_points_inside_frustum(
		"%s cannon landmarks" % stage.stage_id,
		[cannon.global_position, cannon.get_launch_origin()],
		camera.global_position,
		focus,
		camera.fov
	)
	_assert_true(
		is_equal_approx(camera.fov, 48.0),
		"%s Aim Lock must retain the authored 48-degree FOV" % stage.stage_id
	)


func _assert_presentation_frames(
	stage: StageData,
	camera: Camera3D,
	director: CameraDirector,
	terrain: TerrainSurface
) -> void:
	var points := terrain.presentation_world_points()
	var same_aspect_build_count := -1
	for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		for mode in [CameraDirector.Mode.BRIEFING, CameraDirector.Mode.RESULT]:
			director.set_mode(mode, true)
			await physics_frame
			await process_frame
			var safe_rect := CameraDirector.BRIEFING_SAFE_RECT \
					if mode == CameraDirector.Mode.BRIEFING else CameraDirector.RESULT_SAFE_RECT
			_assert_true(
				TerrainCameraFramer.pose_fits_points_in_normalized_rect(
					points,
					camera.global_position,
					director.camera_focus_position(),
					camera.fov,
					float(viewport_size.x) / float(viewport_size.y),
					safe_rect
				),
				"%s %s presentation points must fit %s" % [
					stage.stage_id, CameraDirector.Mode.keys()[mode], viewport_size,
				]
			)
		if same_aspect_build_count < 0:
			same_aspect_build_count = director.presentation_pose_build_count()
		else:
			_assert_true(
				director.presentation_pose_build_count() == same_aspect_build_count,
				"same-aspect viewport sizes must reuse cached presentation poses"
			)
	root.size = Vector2i(1280, 800)
	await process_frame
	await process_frame
	var before_aspect_change := director.presentation_pose_build_count()
	director.set_mode(CameraDirector.Mode.BRIEFING, true)
	await physics_frame
	await process_frame
	_assert_true(
		director.presentation_pose_build_count() == before_aspect_change + 1,
		"viewport aspect changes must invalidate one mode-specific presentation pose"
	)
	_assert_true(
		TerrainCameraFramer.pose_fits_points_in_normalized_rect(
			points,
			camera.global_position,
			director.camera_focus_position(),
			camera.fov,
			16.0 / 10.0,
			CameraDirector.BRIEFING_SAFE_RECT
		),
		"%s Briefing presentation points must fit the 16:10 safe region" % stage.stage_id
	)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
func _assert_points_inside_frustum(
		label: String,
		points,
		camera_position: Vector3,
		focus: Vector3,
		vertical_fov_degrees: float
) -> void:
	var forward := (focus - camera_position).normalized()
	var reference_up := Vector3.FORWARD if absf(forward.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var right := forward.cross(reference_up).normalized()
	var up := right.cross(forward).normalized()
	var vertical_tangent := tan(deg_to_rad(vertical_fov_degrees * 0.5))
	var horizontal_tangent := vertical_tangent * (16.0 / 9.0)
	for point_value in points:
		var point: Vector3 = point_value
		var relative: Vector3 = point - camera_position
		var depth: float = relative.dot(forward)
		_assert_true(depth > 0.0, "%s point must remain in front of the camera" % label)
		_assert_true(absf(relative.dot(right)) <= depth * horizontal_tangent + 0.002, "%s point must fit horizontally" % label)
		_assert_true(absf(relative.dot(up)) <= depth * vertical_tangent + 0.002, "%s point must fit vertically" % label)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true
