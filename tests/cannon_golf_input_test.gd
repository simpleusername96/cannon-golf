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
	game.set_planning_view(&"cannon")
	game.pan_planning(Vector2(1.0, -1.0))
	game.orbit_planning(Vector2(72.0, -24.0))
	game.zoom_planning(2.0)
	game._camera_rig.update(1.0)
	var fire_view := game.planning_view
	var fire_pan := game.planning_pan
	var fire_zoom := game.planning_zoom
	var fire_orbit := game._camera_rig.orbit_degrees
	await _push_space()
	_assert_ball_count(game, 1, "One physical Space press must create exactly one ball.")
	_assert_true(
		game._camera_rig.camera_mode == &"follow"
				and game.planning_view == fire_view
				and game.planning_pan.is_equal_approx(fire_pan)
				and is_equal_approx(game.planning_zoom, fire_zoom)
				and game._camera_rig.orbit_degrees.is_equal_approx(fire_orbit),
		"Physical Fire must follow the newest ball without changing the stored planning state."
	)
	await _push_key(KEY_TAB)
	_assert_true(
		game._camera_rig.camera_mode == &"planning" and game.planning_view == fire_view
				and game.planning_pan.is_equal_approx(fire_pan)
				and is_equal_approx(game.planning_zoom, fire_zoom),
		"Tab must restore the exact pre-fire planning state."
	)
	await _push_key(KEY_TAB)
	_assert_true(game._camera_rig.camera_mode == &"planning", "Tab must never re-enter Shot Follow.")

	game.set_planning_view(&"cannon")
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
	_assert_ball_count(game, 3, "Every physical Space press must add another live ball.")
	await _push_space()
	_assert_ball_count(game, 4, "Rapid Fire must not impose a simultaneous-ball limit.")

	var launcher := game._course_builder.launcher
	var hud := game._hud
	var initial_setup := Vector3(
		launcher.horizontal_aim,
		launcher.elevation_degrees,
		launcher.power_percent
	)
	_press_step(hud.get_node("%HorizontalDecrease"))
	_assert_setup(launcher, initial_setup + Vector3(-1.0, 0.0, 0.0), "Horizontal decrease must change only horizontal aim.")
	_press_step(hud.get_node("%HorizontalIncrease"))
	_press_step(hud.get_node("%ElevationDecrease"))
	_assert_setup(launcher, initial_setup + Vector3(0.0, -1.0, 0.0), "Elevation decrease must change only elevation.")
	_press_step(hud.get_node("%ElevationIncrease"))
	_press_step(hud.get_node("%PowerDecrease"))
	_assert_setup(launcher, initial_setup + Vector3(0.0, 0.0, -1.0), "Power decrease must change only power.")
	_press_step(hud.get_node("%PowerIncrease"))
	_assert_setup(launcher, initial_setup, "Matching step buttons must restore the initial setup.")

	var horizontal_increase := hud.get_node("%HorizontalIncrease") as Button
	horizontal_increase.button_down.emit()
	hud._process(CannonGolfHUD.STEP_HOLD_DELAY + CannonGolfHUD.STEP_HOLD_REPEAT * 2.1)
	horizontal_increase.button_up.emit()
	_assert_true(
		launcher.horizontal_aim >= initial_setup.x + 3.0,
		"Holding a step button must repeat after the initial press."
	)
	game._on_setup_changed(initial_setup.x, initial_setup.y, initial_setup.z)
	hud.set_setup(CannonGolfBallistics.MINIMUM_HORIZONTAL_AIM, -90.0, 10.0)
	_assert_true(not (hud.get_node("%HorizontalDecrease") as Button).disabled, "Horizontal aim must remain circular at its displayed lower edge.")
	_assert_true((hud.get_node("%ElevationDecrease") as Button).disabled, "Elevation decrease must stop only at straight down.")
	_assert_true((hud.get_node("%PowerDecrease") as Button).disabled, "Power decrease must stop at minimum power.")
	hud.set_setup(CannonGolfBallistics.MAXIMUM_HORIZONTAL_AIM, 90.0, 100.0)
	_assert_true(not (hud.get_node("%HorizontalIncrease") as Button).disabled, "Horizontal aim must remain circular at its displayed upper edge.")
	_assert_true((hud.get_node("%ElevationIncrease") as Button).disabled, "Elevation increase must stop only at straight up.")
	_assert_true((hud.get_node("%PowerIncrease") as Button).disabled, "Power increase must stop at maximum power.")
	horizontal_increase.button_down.emit()
	_assert_true(
		is_equal_approx(
			(hud.get_node("%HorizontalSlider") as HSlider).value,
			CannonGolfBallistics.MINIMUM_HORIZONTAL_AIM
		) and hud._held_slider == hud.get_node("%HorizontalSlider"),
		"Horizontal increase must wrap and keep repeating across the circular seam."
	)
	horizontal_increase.button_up.emit()
	hud.set_setup(initial_setup.x, initial_setup.y, initial_setup.z)
	hud.set_launch_availability(4, true)
	for button_name in [
		"HorizontalDecrease", "HorizontalIncrease", "ElevationDecrease",
		"ElevationIncrease", "PowerDecrease", "PowerIncrease",
	]:
		_assert_true((hud.get_node("%%%s" % button_name) as Button).disabled, "%s must disable after clear." % button_name)
	hud.set_launch_availability(4, false)

	var pause_emissions := [0]
	hud.pause_requested.connect(func() -> void: pause_emissions[0] += 1)
	_assert_true(not hud.is_shortcut_panel_visible(), "Shortcut help must start collapsed.")
	(hud.get_node("%ShortcutButton") as Button).pressed.emit()
	await process_frame
	_assert_true(hud.is_shortcut_panel_visible(), "The help action must open shortcut help.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud._unhandled_input(escape)
	await process_frame
	_assert_true(
		not hud.is_shortcut_panel_visible() and pause_emissions[0] == 0,
		"Escape must close shortcut help before it can pause."
	)
	(hud.get_node("%ShortcutButton") as Button).pressed.emit()
	await process_frame
	(hud.get_node("%ShortcutCloseButton") as Button).pressed.emit()
	await process_frame
	_assert_true(
		not hud.is_shortcut_panel_visible() and (hud.get_node("%ShortcutButton") as Button).has_focus(),
		"The shortcut close action must restore focus to its opener."
	)

	var stored_setup := Vector3(
		launcher.horizontal_aim,
		launcher.elevation_degrees,
		launcher.power_percent
	)
	var zoom_before_wheel := game.planning_zoom
	_assert_true(game._camera_rig.camera_mode == &"follow", "The newest Space launch must follow its ball.")
	await _push_mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	_assert_true(
		game._camera_rig.camera_mode == &"planning" \
				and game.planning_zoom > zoom_before_wheel,
		"Wheel input during follow must return to planning and visibly zoom toward the terrain."
	)

	_assert_true(game.toggle_shot_camera(), "A live ball must remain available for drag-from-follow coverage.")
	var focus_before_drag := game._camera_rig.planning_focus()
	var orbit_before_drag := game._camera_rig.orbit_degrees
	await _push_drag(Vector2(640.0, 300.0), Vector2(88.0, -36.0))
	_assert_true(
		game._camera_rig.camera_mode == &"planning" \
				and not game._camera_rig.planning_focus().is_equal_approx(focus_before_drag),
		"Left drag during follow must return to planning and move across the terrain."
	)
	_assert_true(
		game._camera_rig.orbit_degrees.is_equal_approx(orbit_before_drag),
		"Left drag must not rotate the terrain."
	)
	var focus_after_drag := game._camera_rig.planning_focus()
	await _push_drag(
		Vector2(640.0, 300.0), Vector2(88.0, -36.0), MOUSE_BUTTON_RIGHT
	)
	_assert_true(
		not game._camera_rig.orbit_degrees.is_equal_approx(orbit_before_drag) \
				and game._camera_rig.planning_focus().is_equal_approx(focus_after_drag),
		"Right drag must orbit around the player-selected planning focus."
	)
	var orbit_after_drag := game._camera_rig.orbit_degrees
	await _push_click(Vector2(640.0, 300.0))
	_assert_true(
		game._camera_rig.orbit_degrees.is_equal_approx(orbit_after_drag) \
				and game._camera_rig.planning_focus().is_equal_approx(focus_after_drag),
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
		is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.DEFAULT_ZOOM + 1.0),
		"The compact zoom-in action must visibly use the planning camera owner."
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
		is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.DEFAULT_ZOOM - 1.0),
		"The compact zoom-out action must visibly use the planning camera owner."
	)
	(game._hud.get_node("%CameraResetButton") as Button).pressed.emit()
	await process_frame
	await _push_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(640.0, 300.0))
	_assert_true(game._planning_drag_active, "World press must enter drag state.")
	game.toggle_pause()
	_assert_true(not game._planning_drag_active, "Pause must cancel drag state.")
	game.toggle_pause()
	await _push_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(640.0, 300.0))
	game._load_course(2)
	await process_frame
	await process_frame
	var relay_focus_before_drag := game._camera_rig.planning_focus()
	for _drag_index in range(4):
		await _push_drag(Vector2(640.0, 360.0), Vector2(120.0, 0.0))
	var relay_focus_after_drag := game._camera_rig.planning_focus()
	var relay_drag_distance := relay_focus_after_drag.distance_to(relay_focus_before_drag)
	var relay_span := maxf(
		game.active_course().content_bounds.size.x,
		game.active_course().content_bounds.size.z
	)
	_assert_true(
		relay_drag_distance > 1.0 \
				and relay_drag_distance <= relay_span * 0.083 \
				and game.active_course().content_bounds.has_point(relay_focus_after_drag),
		"Course left drag %.3f must stay within %.3f and inside exploration bounds (%s)." % [
			relay_drag_distance,
			relay_span * 0.083,
			game.active_course().content_bounds.has_point(relay_focus_after_drag),
		]
	)

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


func _push_drag(
	position: Vector2,
	relative: Vector2,
	button: MouseButton = MOUSE_BUTTON_LEFT
) -> void:
	await _push_mouse_button(button, true, position)
	var motion := InputEventMouseMotion.new()
	motion.position = position + relative
	motion.global_position = motion.position
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT \
			if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	await process_frame
	await _push_mouse_button(button, false, motion.position)


func _press_step(button: Button) -> void:
	button.button_down.emit()
	button.button_up.emit()


func _assert_setup(launcher: CannonGolfLauncher, expected: Vector3, message: String) -> void:
	_assert_true(
		Vector3(launcher.horizontal_aim, launcher.elevation_degrees, launcher.power_percent) \
				.is_equal_approx(expected),
		message
	)


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
