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
	var fired_view: StringName
	var fired_pan := Vector3.ZERO
	var fired_zoom := 0.0
	var fired_orbit := Vector2.ZERO
	var fired_transform := Transform3D.IDENTITY
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
	elif requested_state == "zoom_close":
		game.zoom_planning(3.0)
	elif requested_state == "zoom_far":
		game.zoom_planning(-3.0)
	elif requested_state == "shortcuts":
		game._hud.set_shortcut_panel_visible(true)
	elif requested_state == "follow":
		if not game.fire():
			push_error("Follow capture could not launch its ball.")
			quit(1)
			return
		if not game.toggle_shot_camera():
			push_error("Follow capture could not enter explicit Shot Follow.")
			quit(1)
			return
	elif requested_state == "two_live":
		if not game.fire():
			push_error("Two-live capture could not launch its first ball.")
			quit(1)
			return
		game._on_setup_changed(56.0, 50.0, 50.0)
		if not game.fire():
			push_error("Two-live capture could not launch its second ball.")
			quit(1)
			return
	elif requested_state == "fired_explored":
		game.set_planning_view(&"side")
		game.orbit_planning(Vector2(190.0, -62.0))
		game.zoom_planning(2.0)
		game.pan_planning(Vector2(1.0, 0.0))
		game._camera_rig.update(1.0)
		fired_view = game.planning_view
		fired_pan = game.planning_pan
		fired_zoom = game.planning_zoom
		fired_orbit = game._camera_rig.orbit_degrees
		fired_transform = game._camera.global_transform
		if not game.fire():
			push_error("Explored-fire capture could not launch its ball.")
			quit(1)
			return
	elif requested_state == "pause":
		game.toggle_pause()
	elif requested_state == "clear":
		game.fire()
		game.current_ball.global_position = game._course_builder.goal.global_position \
				+ Vector3.UP * CannonGolfBall.RADIUS
		game._confirm_goal()
	elif requested_state == "relay_confirmed":
		if not game.fire():
			push_error("Relay capture could not launch its checkpoint ball.")
			quit(1)
			return
		game.current_ball.global_position = game._course_builder.goal.global_position \
				+ Vector3.UP * CannonGolfBall.RADIUS
		game._confirm_goal()
	elif requested_state == "relay_overview":
		game.zoom_planning(-100.0)
	for _frame in range(36):
		await process_frame
	if game != null and requested_state in [
		"planning", "side", "explored", "zoom_close", "zoom_far", "shortcuts",
		"relay_initial", "relay_overview",
	]:
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
	if game != null and requested_state == "zoom_close" \
			and game.planning_zoom >= CannonGolfCourseCameraRig.DEFAULT_ZOOM * 0.55:
		push_error("Close-zoom capture did not move materially toward the course.")
		quit(1)
		return
	if game != null and requested_state == "zoom_far" \
			and game.planning_zoom < CannonGolfCourseCameraRig.MAXIMUM_ZOOM:
		push_error("Far-zoom capture did not reach its bounded course view.")
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
	if game != null and requested_state == "fired_explored":
		if game._camera_rig.camera_mode != &"planning" \
				or game.planning_view != fired_view \
				or not game.planning_pan.is_equal_approx(fired_pan) \
				or not is_equal_approx(game.planning_zoom, fired_zoom) \
				or not game._camera_rig.orbit_degrees.is_equal_approx(fired_orbit) \
				or not game._camera.global_transform.is_equal_approx(fired_transform):
			push_error("Fire changed the explored planning camera.")
			quit(1)
			return
	if game != null and requested_state == "clear":
		var confirmed := game.confirmed_ball
		var confirmed_mesh := confirmed.get_node_or_null("GolfBallMesh") as MeshInstance3D \
				if confirmed != null else null
		var result_panel := game._hud.get_node("Root/ResultOverlay/Panel") as Control
		var ball_screen_position := game._camera.unproject_position(confirmed.global_position) \
				if confirmed != null else Vector2.ZERO
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
		if confirmed == null or not is_instance_valid(confirmed) \
				or not confirmed.is_inside_tree() or confirmed.is_queued_for_deletion() \
				or confirmed_mesh == null or not confirmed_mesh.is_visible_in_tree() \
				or not game._camera_rig.is_following(confirmed) \
				or game._camera.is_position_behind(confirmed.global_position) \
				or not viewport_rect.has_point(ball_screen_position) \
				or result_panel.get_global_rect().has_point(ball_screen_position):
			push_error("Clear capture did not retain an unobstructed visible confirmed ball.")
			quit(1)
			return
	if game != null and requested_state == "relay_initial":
		if game.active_course().course_id != &"deep_relay" \
				or game.active_leg_index != 0 \
				or game._course_builder.goals.size() != 2:
			push_error("Initial relay capture did not show the ordered two-goal course at leg one.")
			quit(1)
			return
	if game != null and requested_state == "relay_confirmed":
		if game.active_course().course_id != &"deep_relay" \
				or game.active_leg_index != 1 \
				or game.confirmed_ball_count() != 1 \
				or game.launch_state != CannonGolfGame.LaunchState.PLANNING \
				or game._camera_rig.camera_mode != &"planning":
			push_error("Confirmed relay capture did not retain checkpoint one in the leg-two planning frame.")
			quit(1)
			return
	if game != null and requested_state == "relay_overview":
		if game.active_course().course_id != &"deep_relay" \
				or not is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.MAXIMUM_ZOOM) \
				or not TerrainCameraFramer.pose_fits_bounds(
					game.active_course().content_bounds,
					game._camera.global_position,
					game._camera_rig.planning_focus(),
					game._camera.fov,
					float(root.size.x) / float(root.size.y),
					1.0
				):
			push_error("Relay overview capture did not frame the complete generated course.")
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
