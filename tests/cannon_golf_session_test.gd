extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	root.add_child(game)
	await process_frame
	await process_frame
	_assert_true(game.active_course().course_id == &"quiet_shelf", "First course must load.")
	var launcher := game._course_builder.launcher
	var elevation := launcher.elevation_degrees
	var power := launcher.power_percent
	game.set_planning_view(&"side")
	game.pan_planning(Vector2(1.0, -1.0))
	var stored_pan := game.planning_pan
	_assert_true(game.fire(), "Planning state must admit Fire.")
	_assert_true(not game.fire(), "Only one active ball may be fired.")
	_assert_true(game.planning_view == &"side", "Launch must preserve planning view.")
	_assert_true(game.planning_pan.is_equal_approx(stored_pan), "Launch must preserve planning pan.")
	_assert_true(is_equal_approx(launcher.elevation_degrees, elevation), "Launch must preserve elevation.")
	_assert_true(is_equal_approx(launcher.power_percent, power), "Launch must preserve power.")
	game._fail_launch(&"out_of_bounds")
	await process_frame
	await process_frame
	_assert_true(game.launch_state == CannonGolfGame.LaunchState.PLANNING, "Miss must return to planning.")
	_assert_true(game.current_ball == null, "Failed ball must leave the active simulation.")
	for retry in range(7):
		_assert_true(game.fire(), "Unlimited retry must admit launch %d." % (retry + 1))
		game._fail_launch(&"stopped_outside")
		await process_frame
		await process_frame
	for index in range(8):
		game._impact_history.stamp(Vector3(float(index), 6.0, -12.0), Vector3.UP)
	_assert_true(game.impact_mark_count() == 5, "Impact history must retain five marks.")
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
