extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")
const APP_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_app.tscn")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var requested_state := "planning"
	var requested_course := 0
	var requested_size := Vector2i(1280, 720)
	var background_capture := false
	var output_path := ProjectSettings.globalize_path(
		"res://.godot/capture-temp/cannon-golf.png"
	)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--state="):
			requested_state = argument.trim_prefix("--state=")
		elif argument.begins_with("--course="):
			requested_course = int(argument.trim_prefix("--course="))
		elif argument.begins_with("--output="):
			output_path = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
		elif argument.begins_with("--width="):
			requested_size.x = int(argument.trim_prefix("--width="))
		elif argument.begins_with("--height="):
			requested_size.y = int(argument.trim_prefix("--height="))
		elif argument == "--background":
			background_capture = true
	if background_capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_position(Vector2i(-32000, -32000))
	root.size = requested_size
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var game: CannonGolfGame
	var app: CannonGolfApp
	if requested_state in ["menu", "course_select", "settings"]:
		app = APP_SCENE.instantiate() as CannonGolfApp
		root.add_child(app)
	else:
		game = GAME_SCENE.instantiate() as CannonGolfGame
		game.initial_course_index = requested_course
		root.add_child(game)
	await process_frame
	await process_frame
	# Warm the HUD font atlas before applying an immediate scripted gameplay state.
	# A real player sees these frames before Fire can be pressed.
	for _warmup_frame in range(2):
		await RenderingServer.frame_post_draw
		await process_frame
	if requested_state == "course_select":
		app.show_course_select(false)
		if requested_course > 0:
			var course_select := app.get_node("ScreenLayer/CourseSelect") as CannonGolfCourseSelect
			course_select.select_course(requested_course)
	elif requested_state == "settings":
		app.show_settings()
	elif requested_state == "side":
		game.set_planning_view(&"side")
	elif requested_state == "explored":
		game.orbit_planning(Vector2(190.0, -62.0))
		game.zoom_planning(2.0)
		game.pan_planning(Vector2(1.0, 0.0))
	elif requested_state == "shortcuts":
		game._hud.set_shortcut_panel_visible(true)
	elif requested_state == "follow":
		if not game.fire():
			push_error("Follow capture could not launch its ball.")
			quit(1)
			return
	elif requested_state == "two_live":
		if not game.fire():
			push_error("Two-live capture could not launch its first ball.")
			quit(1)
			return
		game.return_to_planning_view()
		game._on_setup_changed(56.0, 50.0, 50.0)
		if not game.fire(false):
			push_error("Two-live capture could not launch its second ball.")
			quit(1)
			return
	elif requested_state == "pause":
		game.toggle_pause()
	elif requested_state == "clear":
		game.fire()
		game.current_ball.global_position = game._course_builder.goal.global_position \
				+ Vector3.UP * CannonGolfBall.RADIUS
		game._confirm_goal()
	for _frame in range(36):
		await process_frame
	if game != null and requested_state in ["planning", "side", "explored", "shortcuts"]:
		if game.launch_state != CannonGolfGame.LaunchState.PLANNING or game.current_ball != null:
			push_error("Planning capture received live input and left the planning state.")
			quit(1)
			return
	if game != null and requested_state == "explored":
		if game._camera_rig.orbit_degrees.is_zero_approx() \
				or is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.DEFAULT_ZOOM):
			push_error("Explored capture did not retain an orbit and zoom change.")
			quit(1)
			return
	if game != null and requested_state == "shortcuts" \
			and not game._hud.is_shortcut_panel_visible():
		push_error("Shortcut capture did not retain its open help panel.")
		quit(1)
		return
	if game != null and requested_state == "follow":
		if game.active_ball_count() != 1 or game._camera_rig.camera_mode != &"follow":
			push_error("Follow capture did not retain one followed live ball.")
			quit(1)
			return
	if game != null and requested_state == "two_live":
		if game.active_ball_count() != 2 or game._camera_rig.camera_mode != &"planning":
			push_error("Two-live capture did not retain two balls in planning view.")
			quit(1)
			return
	# Compatibility rendering can publish the terrain frame before every font
	# atlas and Control batch has reached the viewport texture. Wait for several
	# completed draws so delivery evidence records a stable composed frame.
	for _render_frame in range(12):
		await RenderingServer.frame_post_draw
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save Cannon Golf capture to %s (error %d)." % [output_path, error])
		quit(1)
		return
	print("Captured Cannon Golf '%s' state to %s." % [requested_state, output_path])
	quit(0)
