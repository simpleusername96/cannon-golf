extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")


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
	var horizontal := launcher.horizontal_aim
	var elevation := launcher.elevation_degrees
	var power := launcher.power_percent
	game.set_planning_view(&"side")
	game.pan_planning(Vector2(1.0, -1.0))
	game._camera_rig.adjust_zoom(0.2)
	var stored_pan := game.planning_pan
	var stored_zoom := game.planning_zoom
	for index in range(5):
		game._impact_history.stamp(Vector3(float(index), 6.0, -12.0), Vector3.UP)
	var mark_identities := game._impact_history.mark_instance_ids()
	var expected_origin := launcher.launch_origin()
	var expected_velocity := launcher.launch_velocity()
	_assert_true(game.fire(), "Planning state must admit Fire.")
	_assert_true(not game.fire(), "Only one active ball may be fired.")
	_assert_true(game.planning_view == &"side", "Launch must preserve planning view.")
	_assert_true(game.planning_pan.is_equal_approx(stored_pan), "Launch must preserve planning pan.")
	_assert_true(is_equal_approx(game.planning_zoom, stored_zoom), "Launch must preserve planning zoom.")
	_assert_true(is_equal_approx(launcher.horizontal_aim, horizontal), "Launch must preserve horizontal aim.")
	_assert_true(is_equal_approx(launcher.elevation_degrees, elevation), "Launch must preserve elevation.")
	_assert_true(is_equal_approx(launcher.power_percent, power), "Launch must preserve power.")
	var retry_ball := game.current_ball
	_assert_true(game.retry_attempt(), "Quick retry must accept an active unconfirmed ball.")
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.FLYING, "Quick retry must immediately relaunch.")
	_assert_true(game.current_ball != null and game.current_ball != retry_ball, "Quick retry must replace only the active ball.")
	_assert_true(game.planning_view == &"side" and game.planning_pan.is_equal_approx(stored_pan) and is_equal_approx(game.planning_zoom, stored_zoom), "Quick retry must preserve planning context.")
	_assert_true(is_equal_approx(launcher.horizontal_aim, horizontal), "Quick retry must preserve horizontal aim.")
	_assert_true(is_equal_approx(launcher.elevation_degrees, elevation), "Quick retry must preserve elevation.")
	_assert_true(is_equal_approx(launcher.power_percent, power), "Quick retry must preserve power.")
	_assert_true(game.current_ball.global_position.is_equal_approx(expected_origin), "Quick retry must reuse the exact launch origin.")
	_assert_true(game.current_ball.linear_velocity.is_equal_approx(expected_velocity), "Quick retry must reuse the exact launch velocity.")
	_assert_true(game._impact_history.mark_instance_ids() == mark_identities, "Quick retry must preserve all five mark identities.")
	game.toggle_pause()
	_assert_true(paused, "Pause must stop the scene tree during flight.")
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.FLYING, "Pause must preserve the launch state.")
	game.toggle_pause()
	_assert_true(not paused, "Resume must release the scene-tree pause.")
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.FLYING, "Resume must restore the prior launch state.")
	game._fail_launch(&"out_of_bounds")
	await process_frame
	await process_frame
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.PLANNING, "Miss must return to planning.")
	_assert_true(game.current_ball == null, "Failed ball must leave the active simulation.")
	_assert_true(not game.retry_attempt(), "Quick retry must reject a planning state without an active ball.")
	for retry in range(7):
		_assert_true(game.fire(), "Unlimited retry must admit launch %d." % (retry + 1))
		game._fail_launch(&"stopped_outside")
		await process_frame
		await process_frame
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
	_assert_true(game.fire(), "A final launch must be available before confirmation.")
	game.current_ball.global_position = game._course_builder.goal.global_position + Vector3.UP * 0.6
	game._confirm_goal()
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.CLEARED, "Confirmation must clear the course.")
	_assert_true(game.confirmed_ball != null and game.confirmed_ball.freeze, "Confirmed ball must remain frozen and visible.")
	_assert_true(not game.fire(), "A cleared goal must reject later launches.")
	_assert_true(game.planning_view == &"side" and game.planning_pan.is_equal_approx(stored_pan), "Clear must preserve planning context.")
	print("Cannon Golf session-state contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
