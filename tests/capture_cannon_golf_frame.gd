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
	if requested_state == "course_select":
		app.show_course_select(false)
		if requested_course > 0:
			var course_select := app.get_node("ScreenLayer/CourseSelect") as CannonGolfCourseSelect
			course_select.select_course(requested_course)
	elif requested_state == "settings":
		app.show_settings()
	elif requested_state == "side":
		game.set_planning_view(&"side")
	elif requested_state == "pause":
		game.toggle_pause()
	elif requested_state == "clear":
		game.fire()
		game.current_ball.global_position = game._course_builder.goal.global_position \
				+ Vector3.UP * CannonGolfBall.RADIUS
		game._confirm_goal()
	for _frame in range(36):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save Cannon Golf capture to %s (error %d)." % [output_path, error])
		quit(1)
		return
	print("Captured Cannon Golf '%s' state to %s." % [requested_state, output_path])
	quit(0)
