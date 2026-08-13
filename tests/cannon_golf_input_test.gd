extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame

	var fire_button := game._hud.get_node("%FireButton") as Button
	_assert_true(fire_button.has_focus(), "Fire must own initial keyboard focus.")
	await _push_space()
	_assert_ball_count(game, 1, "One physical Space press must create exactly one ball.")

	game.return_to_planning_view()
	game.set_planning_view(&"side")
	var oblique_button := game._hud.get_node("%ObliqueButton") as Button
	oblique_button.grab_focus()
	await process_frame
	await _push_space()
	_assert_ball_count(game, 1, "Space on a secondary button must not launch another ball.")
	_assert_true(game.planning_view == &"oblique", "A focused secondary button must keep native Space activation.")

	fire_button.grab_focus()
	await process_frame
	await _push_space()
	_assert_ball_count(game, 2, "The second physical Space press must add exactly one ball.")
	await _push_space()
	_assert_ball_count(game, 2, "Space must not bypass the two-live-ball capacity.")

	var launcher := game._course_builder.launcher
	var stored_setup := Vector3(
		launcher.horizontal_aim,
		launcher.elevation_degrees,
		launcher.power_percent
	)
	var zoom_before_wheel := game.planning_zoom
	_assert_true(game._camera_rig.camera_mode == &"follow", "The newest Space launch must enter Shot Follow.")
	await _push_mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	_assert_true(
		game._camera_rig.camera_mode == &"planning" and game.planning_zoom < zoom_before_wheel,
		"Wheel input during follow must return to planning and zoom toward the terrain."
	)

	_assert_true(game.toggle_shot_camera(), "A live ball must remain available for drag-from-follow coverage.")
	var focus_before_drag := game._camera_rig.planning_focus()
	var orbit_before_drag := game._camera_rig.orbit_degrees
	await _push_drag(Vector2(640.0, 300.0), Vector2(88.0, -36.0))
	_assert_true(
		game._camera_rig.camera_mode == &"planning" \
				and not game._camera_rig.orbit_degrees.is_equal_approx(orbit_before_drag),
		"Left drag during follow must return to planning and orbit the course."
	)
	_assert_true(
		game._camera_rig.planning_focus().is_equal_approx(focus_before_drag),
		"Direct drag must not refocus the planning camera."
	)
	var orbit_after_drag := game._camera_rig.orbit_degrees
	await _push_click(Vector2(640.0, 300.0))
	_assert_true(
		game._camera_rig.orbit_degrees.is_equal_approx(orbit_after_drag) \
				and game._camera_rig.planning_focus().is_equal_approx(focus_before_drag),
		"A click without drag must not move or refocus the camera."
	)
	_assert_true(
		Vector3(launcher.horizontal_aim, launcher.elevation_degrees, launcher.power_percent) \
				.is_equal_approx(stored_setup),
		"Camera exploration must preserve all three launch values."
	)

	(game._hud.get_node("%HorizontalSlider") as HSlider).grab_focus()
	await process_frame
	await _push_key(KEY_HOME)
	_assert_true(
		game.planning_view == &"oblique" and game.planning_pan.is_zero_approx() \
				and is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.DEFAULT_ZOOM) \
				and game._camera_rig.orbit_degrees.is_zero_approx(),
		"Home must restore the authored planning camera even when a slider has focus."
	)
	(game._hud.get_node("%ZoomInButton") as Button).pressed.emit()
	await process_frame
	_assert_true(
		game.planning_zoom < CannonGolfCourseCameraRig.DEFAULT_ZOOM,
		"The compact zoom-in action must use the planning camera owner."
	)
	(game._hud.get_node("%CameraResetButton") as Button).pressed.emit()
	await process_frame
	_assert_true(
		is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.DEFAULT_ZOOM),
		"The compact reset action must restore the authored planning camera."
	)
	(game._hud.get_node("%ZoomOutButton") as Button).pressed.emit()
	await process_frame
	_assert_true(
		game.planning_zoom > CannonGolfCourseCameraRig.DEFAULT_ZOOM,
		"The compact zoom-out action must use the planning camera owner."
	)
	(game._hud.get_node("%CameraResetButton") as Button).pressed.emit()
	await process_frame
	await _push_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(640.0, 300.0))
	_assert_true(game._planning_drag_active, "World press must enter drag state.")
	game.toggle_pause()
	_assert_true(not game._planning_drag_active, "Pause must cancel drag state.")
	game.toggle_pause()
	await _push_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(640.0, 300.0))

	if not _failed:
		print("Cannon Golf physical input contract passed: one Space press, one launch.")
	quit(1 if _failed else 0)


func _push_space() -> void:
	await _push_key(KEY_SPACE)


func _push_key(key: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = key
	pressed.physical_keycode = key
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame


func _push_mouse_button(button_index: MouseButton, pressed: bool, position := Vector2(640.0, 300.0)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT \
			if pressed and button_index == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)
	await process_frame


func _push_click(position: Vector2) -> void:
	await _push_mouse_button(MOUSE_BUTTON_LEFT, true, position)
	await _push_mouse_button(MOUSE_BUTTON_LEFT, false, position)


func _push_drag(position: Vector2, relative: Vector2) -> void:
	await _push_mouse_button(MOUSE_BUTTON_LEFT, true, position)
	var motion := InputEventMouseMotion.new()
	motion.position = position + relative
	motion.global_position = motion.position
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await process_frame
	await _push_mouse_button(MOUSE_BUTTON_LEFT, false, motion.position)


func _assert_ball_count(game: CannonGolfGame, expected: int, message: String) -> void:
	_assert_true(
		game.active_ball_count() == expected and game._ball_root.get_child_count() == expected,
		"%s Active: %d, nodes: %d." % [
			message,
			game.active_ball_count(),
			game._ball_root.get_child_count(),
		]
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
