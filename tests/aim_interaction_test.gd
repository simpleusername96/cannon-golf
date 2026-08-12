extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")
const TARGET_TOLERANCE := 1.2

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.physics_ticks_per_second = 60
	root.size = Vector2i(1280, 720)
	var game_state := root.get_node("/root/GameState")
	game_state.persistence_enabled = false
	var save_data: Dictionary = root.get_node("/root/SaveSystem").default_data()
	save_data.unlocked_stages = ["first_descent"]
	game_state.initialize_from_data(save_data)
	_assert_true(game_state.select_stage(&"first_descent"), "First Descent must be selectable")

	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_01")
	root.add_child(gameplay)
	await physics_frame
	await process_frame
	await _check_targeted_aim_and_inspection_input(gameplay)
	gameplay.queue_free()
	await process_frame

	game_state.persistence_enabled = true

	if not _failed:
		print("Aim interaction passed: terrain click/drag, target-preserving controls, and unchanged Map Inspection routing.")
	quit(1 if _failed else 0)


func _check_targeted_aim_and_inspection_input(gameplay: Node) -> void:
	var cannon: CannonController = gameplay.get_node("Cannon")
	var camera: Camera3D = gameplay.get_node("Camera")
	var terrain: TerrainSurface = gameplay.get_node("TerrainSurface")
	var stage_controller: StageController = gameplay.get_node("StageController")
	var camera_director: CameraDirector = gameplay.get_node("CameraDirector")
	var aim_input: AimInputController = gameplay.get_node("AimInputController")
	var terrain_aim: TerrainAimController = gameplay.get_node("TerrainAimController")
	_assert_true(stage_controller.begin_aiming(), "input fixture must enter the aiming phase")
	camera_director.set_mode(CameraDirector.Mode.AIMING, true)
	_assert_true(camera_director.aim_is_locked(), "aiming must begin in Aim View")
	await _wait_for_settled_target(terrain_aim)
	_assert_true(terrain_aim.selected_target() != null, "default exact terrain prediction must initialize a target")
	if terrain_aim.selected_target() == null:
		return

	# W/S commits a target-preserving approximate tuple in the same input turn.
	var target_before_controls := terrain_aim.selected_target()
	var elevation_before := cannon.elevation_degrees
	await _push_key(KEY_W, true)
	await _push_key(KEY_W, false)
	await _wait_for_settled_target(terrain_aim)
	_assert_true(is_equal_approx(cannon.elevation_degrees, elevation_before + 0.5),
		"W must request one 0.5-degree target-preserving elevation step")
	_assert_true(terrain_aim.selected_target() == target_before_controls,
		"elevation adjustment must retain the selected terrain target")

	var power_before := cannon.power_percent
	await _push_mouse_button(Vector2(640, 320), MOUSE_BUTTON_WHEEL_UP, true)
	await _wait_for_settled_target(terrain_aim)
	_assert_true(is_equal_approx(cannon.power_percent, power_before + 1.0),
		"wheel up must request one target-preserving power step")
	_assert_true(terrain_aim.selected_target() == target_before_controls,
		"power adjustment must retain the selected terrain target")

	var aim_before_d := _aim(cannon)
	await _push_key(KEY_D, true)
	await _push_key(KEY_D, false)
	_assert_aim_unchanged(cannon, aim_before_d, "A/D must no longer alter human target-locked aim")

	# Representative nearby top points commit immediately; exact prediction may
	# later confirm the marker but never owns the input transaction.
	var anchor := terrain_aim.selected_target().world_point
	for offset in [Vector2(-2.0, -1.0), Vector2(0.0, -2.0), Vector2(2.0, -1.0)]:
		var desired := terrain.world_surface_point(Vector2(anchor.x, anchor.z) + offset)
		_assert_true(not camera.is_position_behind(desired), "representative target must remain visible")
		await _click_world_point(camera, desired)
		await _wait_for_settled_target(terrain_aim)
		var selected := terrain_aim.selected_target()
		_assert_true(selected != null and selected.world_point.distance_to(desired) <= 0.2,
			"clicking playable terrain must move the selected target to the ray hit")
		if selected != null:
			_assert_true(
				terrain_aim.last_solve_elapsed_usec() < 16667,
				"clicked terrain solve must finish within one 60 Hz frame budget"
			)
			_assert_true(
				bool(stage_controller.fire_readiness_snapshot().fireable),
				"approximate target commit must leave Fire immediately available"
			)

	# Many pointer samples before one physics callback collapse into one pick and
	# one solve request; the last sample wins without a drag backlog.
	var solve_count_before := terrain_aim.solve_request_count()
	var drag_start := terrain_aim.selected_target().world_point
	var drag_end := terrain.world_surface_point(Vector2(anchor.x, anchor.z - 2.0))
	var drag_start_screen := camera.unproject_position(drag_start)
	var drag_end_screen := camera.unproject_position(drag_end)
	for sample_index in range(40):
		var progress := float(sample_index + 1) / 40.0
		terrain_aim.queue_pointer_target(drag_start_screen.lerp(drag_end_screen, progress), false)
	await physics_frame
	await process_frame
	_assert_true(terrain_aim.solve_request_count() == solve_count_before + 1,
		"long drag input must consume only the newest pointer sample per physics tick (%d -> %d)" % [
			solve_count_before, terrain_aim.solve_request_count()
		])
	await _wait_for_settled_target(terrain_aim)
	var dragged := terrain_aim.selected_target()
	_assert_true(dragged != null and dragged.world_point.distance_to(drag_end) <= 0.2,
		"the newest drag point must become the selected surface target")

	# Map Inspection retains its camera-only meanings and never mutates aim or
	# selected-target state.
	var aim_before_inspection := _aim(cannon)
	var target_before_inspection := terrain_aim.selected_target()
	await _push_key(KEY_TAB, true)
	await _push_key(KEY_TAB, false)
	_assert_true(
		stage_controller.current_state == StageController.State.AIMING \
				and camera_director.current_interaction_mode == CameraDirector.InteractionMode.MAP_INSPECTION,
		"Tab must enter Map Inspection without leaving the aiming phase"
	)
	var distance_before_zoom := camera_director.inspection_distance()
	await _push_mouse_button(Vector2(640, 320), MOUSE_BUTTON_WHEEL_UP, true)
	_assert_true(camera_director.inspection_distance() < distance_before_zoom,
		"wheel up in Map Inspection must zoom toward the map")
	var camera_before_orbit := camera.global_position
	await _push_mouse_button(Vector2(640, 320), MOUSE_BUTTON_LEFT, true)
	await _push_mouse_motion(Vector2(700, 330), Vector2(60, 10), true)
	await physics_frame
	await process_frame
	await _push_mouse_button(Vector2(700, 330), MOUSE_BUTTON_LEFT, false)
	_assert_true(camera.global_position.distance_to(camera_before_orbit) > 0.01,
		"left drag in Map Inspection must orbit the camera")
	_assert_true(not aim_input.request_fire(), "Map Inspection must block Fire")
	_assert_aim_unchanged(cannon, aim_before_inspection, "Map Inspection must not change stored aim")
	_assert_true(terrain_aim.selected_target() == target_before_inspection,
		"Map Inspection must not change the selected terrain target")

	await _push_key(KEY_TAB, true)
	await _push_key(KEY_TAB, false)
	_assert_true(camera_director.aim_is_locked(), "Tab must return to Aim View")
	_assert_aim_unchanged(cannon, aim_before_inspection, "returning to Aim View must preserve aim")


func _wait_for_settled_target(controller: TerrainAimController, maximum_ticks: int = 240) -> void:
	for _tick in range(maximum_ticks):
		await physics_frame
		await process_frame
		if controller.selected_target() != null \
				and controller.selected_target_state() in [
					TerrainTargetPreview.STATE_SELECTED,
					TerrainTargetPreview.STATE_CONFIRMED,
				]:
			return
	_assert_true(false, "terrain target must commit inside the bounded fixture window")


func _click_world_point(camera: Camera3D, world_point: Vector3) -> void:
	var screen := camera.unproject_position(world_point)
	await _push_mouse_button(screen, MOUSE_BUTTON_LEFT, true)
	await _push_mouse_button(screen, MOUSE_BUTTON_LEFT, false)


func _aim(cannon: CannonController) -> Vector3:
	return Vector3(cannon.yaw_degrees, cannon.elevation_degrees, cannon.power_percent)


func _push_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _push_mouse_button(position: Vector2, button_index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _push_mouse_motion(position: Vector2, screen_delta: Vector2, dragging: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.relative = screen_delta
	motion.screen_relative = screen_delta
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	Input.parse_input_event(motion)
	await process_frame


func _assert_aim_unchanged(cannon: CannonController, expected: Vector3, message: String) -> void:
	_assert_true(_aim(cannon).is_equal_approx(expected), message)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Aim interaction check failed: %s" % message)
