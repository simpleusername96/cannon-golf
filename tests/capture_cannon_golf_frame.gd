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
	var panned_start_focus := Vector3.ZERO
	var panned_end_focus := Vector3.ZERO
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
	if requested_state in [
		"menu", "course_select", "course_preparing", "course_ready", "course_failed",
		"course_scrolled", "settings",
	]:
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
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		await process_frame
	if requested_state in [
		"course_select", "course_preparing", "course_ready", "course_failed", "course_scrolled",
	]:
		app.show_course_select(false)
		var course_select := app.get_node("ScreenLayer/CourseSelect") as CannonGolfCourseSelect
		if requested_course > 0:
			course_select.select_course(requested_course)
		if requested_state == "course_preparing":
			course_select.set_course_preparation_state(
				CannonGolfCourseSelect.CoursePreparationState.PREPARING
			)
		elif requested_state == "course_ready":
			course_select.set_course_preparation_state(
				CannonGolfCourseSelect.CoursePreparationState.READY
			)
		elif requested_state == "course_failed":
			course_select.set_course_preparation_state(
				CannonGolfCourseSelect.CoursePreparationState.FAILED
			)
		elif requested_state == "course_scrolled":
			course_select.select_course(9)
			(course_select.get_node("CardsPanel/Margin/Scroll") as ScrollContainer).scroll_vertical = 100000
	elif requested_state == "settings":
		app.show_settings()
	elif requested_state == "cannon":
		game.set_planning_view(&"cannon")
	elif requested_state == "explored":
		game.orbit_planning(Vector2(190.0, -62.0))
		game.zoom_planning(2.0)
		game.pan_planning(Vector2(1.0, 0.0))
	elif requested_state == "panned":
		game.zoom_planning(CannonGolfCourseCameraRig.CLOSE_ZOOM)
		panned_start_focus = game._camera_rig.planning_focus()
		for _drag_index in range(4):
			game.pan_planning_drag(Vector2(760.0, 360.0), Vector2(-700.0, -700.0))
			game._camera_rig.update(1.0)
		panned_end_focus = game._camera_rig.planning_focus()
	elif requested_state == "zoom_close":
		game.zoom_planning(CannonGolfCourseCameraRig.CLOSE_ZOOM)
	elif requested_state == "zoom_far":
		game.zoom_planning(CannonGolfCourseCameraRig.OVERVIEW_ZOOM)
	elif requested_state == "collision_edge":
		game.orbit_planning(Vector2(220.0, -1000.0))
		game.zoom_planning(CannonGolfCourseCameraRig.CLOSE_ZOOM)
		for _pan_step in range(8):
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
		game._on_setup_changed(56.0, 50.0, 50.0)
		if not game.fire():
			push_error("Two-live capture could not launch its second ball.")
			quit(1)
			return
		game.return_to_planning_view()
	elif requested_state == "unrestricted_aim":
		game._on_setup_changed(
			CannonGolfBallistics.MAXIMUM_HORIZONTAL_AIM,
			-45.0,
			50.0
		)
		game.set_planning_view(&"cannon")
	elif requested_state == "halo_overview_extreme":
		game._on_setup_changed(
			CannonGolfBallistics.MAXIMUM_HORIZONTAL_AIM,
			-45.0,
			50.0
		)
		game.zoom_planning(CannonGolfCourseCameraRig.OVERVIEW_ZOOM)
	elif requested_state == "halo_cannon_down":
		game._on_setup_changed(
			CannonGolfBallistics.MAXIMUM_HORIZONTAL_AIM,
			CannonGolfBallistics.MINIMUM_ELEVATION_DEGREES,
			50.0
		)
		game.set_planning_view(&"cannon")
	elif requested_state == "rapid_fire":
		for shot_index in range(6):
			game._on_setup_changed(50.0 + float(shot_index), 50.0, 50.0)
			if not game.fire():
				push_error("Rapid-fire capture rejected shot %d." % (shot_index + 1))
				quit(1)
				return
		game.return_to_planning_view()
	elif requested_state == "fired_explored":
		game.set_planning_view(&"cannon")
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
	elif requested_state in ["relay_confirmed", "launcher_source"]:
		if not game.fire():
			push_error("Cannon-source capture could not launch its settlement ball.")
			quit(1)
			return
		var source_goal_index := 0 if requested_state == "relay_confirmed" \
				else mini(2, game._course_builder.goals.size() - 1)
		game.current_ball.global_position = game._course_builder.goals[source_goal_index].global_position \
				+ Vector3.UP * CannonGolfBall.RADIUS
		game._confirm_goal(game.current_ball, source_goal_index)
		if not game.select_launcher_source(source_goal_index):
			push_error("Cannon-source capture could not select its completed goal.")
			quit(1)
			return
		game.set_planning_view(&"cannon")
	elif requested_state == "relay_overview":
		game.zoom_planning(-100.0)
	for _frame in range(36):
		await process_frame
	if game != null and requested_state in [
		"planning", "cannon", "explored", "panned", "zoom_close", "zoom_far",
		"collision_edge", "shortcuts", "unrestricted_aim", "halo_overview_extreme",
		"halo_cannon_down",
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
	if game != null and requested_state == "halo_cannon_down":
		var halo := game._course_builder.launcher.get_node_or_null("AimHalo") \
				as CannonGolfAimHalo
		var reticle := game._hud.get_node_or_null("%AimReticle") as Control
		if halo == null or not halo.visible \
				or not halo.scale.is_equal_approx(
					Vector3.ONE * CannonGolfAimHalo.CANNON_PERSPECTIVE_SCALE
				) \
				or reticle == null or not reticle.is_visible_in_tree() \
				or not game._camera.global_transform.is_finite():
			push_error("Exact-down cannon perspective must keep a compact finite guide.")
			quit(1)
			return
	if game != null and requested_state == "panned":
		var drag_distance := panned_end_focus.distance_to(panned_start_focus)
		var course_span := maxf(
			game.active_course().content_bounds.size.x,
			game.active_course().content_bounds.size.z
		)
		if drag_distance <= 1.0 or drag_distance > course_span * 0.081 \
				or not game.active_course().content_bounds.has_point(panned_end_focus):
			push_error("Panned capture did not retain restrained bounded movement.")
			quit(1)
			return
		if not _camera_boom_is_clear(game):
			push_error("Panned capture put the overview boom through terrain.")
			quit(1)
			return
	if game != null and requested_state == "zoom_close" \
			and not is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.CLOSE_ZOOM):
		push_error("Close-zoom capture did not move materially toward the course.")
		quit(1)
		return
	if game != null and requested_state == "zoom_far" \
			and not is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.OVERVIEW_ZOOM):
		push_error("Far-zoom capture did not move materially away from the course.")
		quit(1)
		return
	if game != null and requested_state == "collision_edge":
		var camera_position := game._camera.global_position
		var terrain_bounds := game._course_builder.prepared_course.local_bounds
		if terrain_bounds.has_point(Vector2(camera_position.x, camera_position.z)) \
				and camera_position.y < game._course_builder.height_at_local(
					camera_position.x, camera_position.z
				) + CannonGolfCourseCameraRig.CAMERA_TERRAIN_CLEARANCE - 0.01:
			push_error("Collision-edge capture placed the planning camera inside terrain.")
			quit(1)
			return
		if not _camera_boom_is_clear(game):
			push_error("Collision-edge capture put the overview boom through terrain.")
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
	if game != null and requested_state == "rapid_fire":
		var rapid_fire_button := game._hud.get_node("%FireButton") as Button
		if game.active_ball_count() != 6 or not game.can_fire() or rapid_fire_button.disabled \
				or game._camera_rig.camera_mode != &"planning":
			push_error("Rapid-fire capture did not retain six live balls with Fire available.")
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
		var result_overlay := game._hud.get_node("Root/ResultOverlay") as Control
		var result_panel := game._hud.get_node("Root/ResultOverlay/Panel") as Control
		var result_primary := game._hud.get_node("%ResultPrimary") as Button
		var panel_center_delta := result_panel.get_global_rect().get_center().distance_to(
			result_overlay.get_global_rect().get_center()
		)
		if game.completed_goal_count() != 1 \
				or game.active_ball_count() != 0 or game._ball_root.get_child_count() != 0 \
				or game._camera_rig.camera_mode != &"planning" \
				or panel_center_delta > 1.0 \
				or not result_overlay.visible or not result_primary.has_focus():
			push_error(
				"Clear state invalid: camera=%s center_delta=%.2f overlay=%s focus=%s completed=%d balls=%d." % [
					game._camera_rig.camera_mode,
					panel_center_delta,
					result_overlay.visible,
					result_primary.has_focus(),
					game.completed_goal_count(),
					game._ball_root.get_child_count(),
				]
			)
			quit(1)
			return
	if game != null and requested_state == "relay_initial":
		if game.active_course().course_id != &"deep_relay" \
				or not game.completed_goal_indices.is_empty() \
				or game.selected_launcher_goal_index != -1 \
				or game._course_builder.goals.size() != 2 \
				or game._course_builder.goals[0].visual_state != CannonGolfSettlementGoal.VisualState.ACTIVE \
				or game._course_builder.goals[1].visual_state != CannonGolfSettlementGoal.VisualState.ACTIVE:
			push_error("Initial multi-goal capture did not expose both free goals from Start.")
			quit(1)
			return
	if game != null and requested_state == "relay_confirmed":
		var relay_launcher := game._course_builder.launcher
		var relay_fire_button := game._hud.get_node("%FireButton") as Button
		var relay_progress := game._hud.get_node("%GoalProgressLabel") as Label
		var source_selector := game._hud.get_node("%LauncherSourceButton") as OptionButton
		var selected_source := int(source_selector.get_item_metadata(source_selector.selected))
		if game.active_course().course_id != &"deep_relay" \
				or game.completed_goal_indices != [0] \
				or game.selected_launcher_goal_index != 0 \
				or game.completed_goal_count() != 1 \
				or game.launch_state != CannonGolfGame.LaunchState.PLANNING \
				or game._camera_rig.camera_mode != &"planning" \
				or not game.can_fire() \
				or relay_fire_button.disabled \
				or not Vector2(relay_launcher.global_position.x, relay_launcher.global_position.z).is_equal_approx(
					Vector2(
						game._course_builder.goals[0].global_position.x,
						game._course_builder.goals[0].global_position.z
					)
				) \
				or source_selector.item_count != 2 or selected_source != 0 \
				or relay_progress.text != "골 1 / 2":
			push_error("Confirmed multi-goal capture did not retain free choice and the selected source.")
			quit(1)
			return
	if game != null and requested_state == "launcher_source":
		var source_selector := game._hud.get_node("%LauncherSourceButton") as OptionButton
		var selected_source := int(source_selector.get_item_metadata(source_selector.selected))
		if game.completed_goal_indices.size() != 1 \
				or game.selected_launcher_goal_index < 0 \
				or selected_source != game.selected_launcher_goal_index \
				or game.planning_view != &"cannon" \
				or game._camera_rig.camera_mode != &"planning":
			push_error("Launcher-source capture did not retain its selected completed goal.")
			quit(1)
			return
	if game != null and requested_state == "relay_overview":
		if game.active_course().course_id != &"deep_relay" \
				or not is_equal_approx(game.planning_zoom, CannonGolfCourseCameraRig.OVERVIEW_ZOOM) \
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
	if game != null and requested_state == "halo_close":
		var launcher := game._course_builder.launcher
		var forward := launcher.launch_direction()
		forward.y = 0.0
		forward = forward.normalized()
		var side := Vector3.UP.cross(forward).normalized()
		game.set_process(false)
		game._camera.global_position = launcher.global_position \
				- forward * 15.0 + side * 9.0 + Vector3.UP * 12.0
		game._camera.look_at(launcher.global_position + Vector3.UP * 1.8, Vector3.UP)
	# Compatibility rendering can publish the terrain frame before every font
	# atlas and Control batch has reached the viewport texture. Wait for several
	# completed draws so delivery evidence records a stable composed frame.
	for _render_frame in range(12):
		if DisplayServer.get_name() != "headless":
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


func _camera_boom_is_clear(game: CannonGolfGame) -> bool:
	var focus := game._camera_rig.planning_focus()
	for step in range(25):
		var point := focus.lerp(game._camera.global_position, float(step) / 24.0)
		for offset in game._camera_rig.terrain_footprint_offsets():
			var sample := point + Vector3(offset.x, 0.0, offset.y)
			if not game._course_builder.prepared_course.local_bounds.has_point(
				Vector2(sample.x, sample.z)
			):
				continue
			if point.y + 0.05 < game._course_builder.height_at_local(sample.x, sample.z) \
					+ CannonGolfOverviewCameraSolver.BOOM_RADIUS:
				return false
	return true
