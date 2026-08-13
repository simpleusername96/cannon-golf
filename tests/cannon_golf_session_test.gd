extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	root.add_child(game)
	await process_frame
	await process_frame
	_assert_true(game.active_course().course_id == &"first_ridge", "First course must load.")
	var launcher := game._course_builder.launcher
	game._on_setup_changed(63.0, 47.0, 64.0)
	game.set_planning_view(&"side")
	game.pan_planning(Vector2(1.0, -1.0))
	game._camera_rig.adjust_zoom(0.2)
	var stored_pan := game.planning_pan
	var stored_zoom := game.planning_zoom
	for index in range(5):
		game._impact_history.stamp(Vector3(float(index), 6.0, -12.0), Vector3.UP)
	var mark_identities := game._impact_history.mark_instance_ids()
	var first_velocity := launcher.launch_velocity()

	_assert_true(game.fire(), "The first live shot must launch.")
	var first_ball := game.current_ball
	_assert_true(first_ball != null and game.active_ball_count() == 1, "Shot one must remain live.")
	_assert_true(game._camera_rig.is_following(first_ball), "Fire must enter Shot Follow for the newest ball.")
	_assert_true(game._hud.get_node("%HorizontalSlider").editable, "Live flight must not lock horizontal aim.")
	_assert_true(game._hud.get_node("%ElevationSlider").editable, "Live flight must not lock vertical aim.")
	_assert_true(game._hud.get_node("%PowerSlider").editable, "Live flight must not lock power.")
	_assert_true(not game._hud.get_node("%FireButton").disabled, "Shot two must remain immediately available.")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	game._unhandled_input(tab)
	_assert_true(game._camera_rig.camera_mode == &"planning", "Tab must leave Shot Follow during flight.")
	game._unhandled_input(tab)
	_assert_true(game._camera_rig.is_following(first_ball), "Tab must return to the newest live ball.")
	_assert_true(game.return_to_planning_view(), "The explicit camera action must also return to planning.")
	_assert_true(game.planning_view == &"side", "Camera return must preserve planning view.")
	_assert_true(game.planning_pan.is_equal_approx(stored_pan), "Camera return must preserve planning pan.")
	_assert_true(is_equal_approx(game.planning_zoom, stored_zoom), "Camera return must preserve planning zoom.")

	game._on_setup_changed(58.0, 44.0, 73.0)
	var second_origin := launcher.launch_origin()
	var second_velocity := launcher.launch_velocity()
	_assert_true(not second_velocity.is_equal_approx(first_velocity), "Edited setup must change the next launch.")
	_assert_true(game.fire(), "Shot two must launch while shot one is still live.")
	var second_ball := game.current_ball
	_assert_true(
		second_ball != first_ball and game.active_ball_count() == 2,
		"Two distinct unconfirmed balls must coexist."
	)
	_assert_true(is_instance_valid(first_ball), "Launching shot two must not remove shot one.")
	_assert_true(second_ball.global_position.is_equal_approx(second_origin), "Shot two must use the edited origin.")
	_assert_true(second_ball.linear_velocity.is_equal_approx(second_velocity), "Shot two must use the edited velocity.")
	_assert_true(not game.fire(), "A third simultaneous live ball must be bounded.")
	_assert_true(game._hud.get_node("%FireButton").disabled, "Fire must show the two-live-ball capacity state.")

	game._fail_ball(first_ball, &"out_of_bounds")
	await process_frame
	await process_frame
	_assert_true(game.active_ball_count() == 1, "Failure of shot one must remove only shot one.")
	_assert_true(game.current_ball == second_ball and is_instance_valid(second_ball), "Shot two must survive shot one's failure.")
	_assert_true(not game._hud.get_node("%FireButton").disabled, "A released slot must re-enable Fire.")

	var retry_ball := game.current_ball
	var retry_origin := launcher.launch_origin()
	var retry_velocity := launcher.launch_velocity()
	_assert_true(game.retry_attempt(), "Quick retry must replace the newest active ball.")
	_assert_true(game.active_ball_count() == 1, "Quick retry must not add a second copy of the replaced ball.")
	_assert_true(game.current_ball != retry_ball, "Quick retry must create a different ball.")
	_assert_true(game.current_ball.global_position.is_equal_approx(retry_origin), "Quick retry must reuse the exact launch origin.")
	_assert_true(game.current_ball.linear_velocity.is_equal_approx(retry_velocity), "Quick retry must reuse the exact launch velocity.")
	_assert_true(game.planning_view == &"side" and game.planning_pan.is_equal_approx(stored_pan), "Quick retry must preserve planning context.")
	_assert_true(game._impact_history.mark_instance_ids() == mark_identities, "Quick retry must preserve all five mark identities.")

	game.toggle_pause()
	_assert_true(paused, "Pause must stop the scene tree during flight.")
	_assert_true(game.active_ball_count() == 1, "Pause must preserve every live ball.")
	game.toggle_pause()
	_assert_true(not paused, "Resume must release the scene-tree pause.")

	game._fail_launch(&"stopped_outside")
	await process_frame
	await process_frame
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.PLANNING, "The last miss must return to planning.")
	_assert_true(game.current_ball == null and game.active_ball_count() == 0, "The last failed ball must leave simulation.")
	_assert_true(not game.retry_attempt(), "Quick retry must reject a state without a live ball.")
	for retry in range(7):
		_assert_true(game.fire(false), "Unlimited sequential retry must admit launch %d." % (retry + 1))
		game._fail_launch(&"stopped_outside")
		await process_frame
		await process_frame
	_assert_true(game.fire(), "A followed ball must launch before external cleanup coverage.")
	game.current_ball.free()
	game._physics_process(1.0 / 60.0)
	_assert_true(
		game.active_ball_count() == 0 and game.current_ball == null,
		"An unexpectedly freed ball must be removed from every live-shot owner."
	)
	_assert_true(
		game._camera_rig.camera_mode == &"planning" \
				and not (game._hud.get_node("%FollowButton") as Button).button_pressed,
		"An unexpectedly ended follow target must return both camera and HUD to planning."
	)

	for index in range(8):
		game._impact_history.stamp(Vector3(float(index), 6.0, -12.0), Vector3.UP)
	_assert_true(game.impact_mark_count() == 5, "Impact history must retain five marks.")
	game.reset_course()
	_assert_true(game.impact_mark_count() == 0, "Full reset must clear impact history.")
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.PLANNING, "Full reset must return to planning.")
	_assert_true(
		game._course_builder.launcher.horizontal_aim == 50.0 \
				and game._course_builder.launcher.elevation_degrees == 50.0 \
				and game._course_builder.launcher.power_percent == 50.0,
		"Full reset must restore all three visible defaults to 50."
	)

	game.set_planning_view(&"side")
	game.pan_planning(Vector2(1.0, -1.0))
	stored_pan = game.planning_pan
	for index in range(5):
		game._impact_history.stamp(Vector3(float(index), 6.0, -12.0), Vector3.UP)
	var oldest_color := game._impact_history.oldest_color()
	var newest_color := game._impact_history.newest_color()
	_assert_true(oldest_color.get_luminance() > newest_color.get_luminance(), "Older marks must be lighter than the newest.")
	_assert_true(game.fire(false), "Shot one must be available before confirmation.")
	first_ball = game.current_ball
	game._on_setup_changed(57.0, 45.0, 70.0)
	_assert_true(game.fire(false), "Shot two must coexist before either confirms.")
	second_ball = game.current_ball
	first_ball.global_position = game._course_builder.goal.global_position + Vector3.UP * 0.6
	game._confirm_goal(first_ball)
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.CLEARED, "Either live ball may confirm the course.")
	_assert_true(game.confirmed_ball == first_ball and first_ball.freeze, "The winning ball must remain frozen and visible.")
	_assert_true(second_ball.is_queued_for_deletion(), "Confirmation must remove other unconfirmed live balls.")
	_assert_true(game.active_ball_count() == 0 and not game.fire(), "A cleared goal must reject later launches.")
	_assert_true(game.planning_view == &"side" and game.planning_pan.is_equal_approx(stored_pan), "Clear must preserve planning context.")
	if not _failed:
		print("Cannon Golf multi-shot session contract passed.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
