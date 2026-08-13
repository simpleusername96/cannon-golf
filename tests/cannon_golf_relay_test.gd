extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var relay := await _new_game(2)
	_assert_true(relay.active_course().course_id == &"deep_relay", "Relay test must load the third course.")
	_assert_true(relay._course_builder.terrain_body_count() == 1, "Relay must build one terrain body.")
	_assert_true(relay._course_builder.goals.size() == 2, "Relay must build two ordered goals.")
	_assert_true(relay._course_builder.get_node_or_null("Launcher") == relay._course_builder.launcher, "Relay must own one launcher.")
	_assert_true(relay.active_leg_index == 0 and relay._course_builder.goal == relay._course_builder.goals[0], "Relay must begin at goal one.")

	# A ball resting in the future basin is still evaluated only against goal one.
	_assert_true(relay.fire(), "Relay must permit the first shot.")
	var future_probe := relay.current_ball
	future_probe.global_position = relay._course_builder.goals[1].global_position
	future_probe.linear_velocity = Vector3.ZERO
	future_probe.angular_velocity = Vector3.ZERO
	relay._update_live_ball(future_probe, relay._course_builder.goal.settle_seconds + 0.1)
	_assert_true(relay.confirmed_ball_count() == 0 and relay.active_leg_index == 0, "A future goal must not confirm before it becomes active.")

	# Goal one confirmation locks its ball, removes a competing shot, and relocates the same launcher.
	var first_anchor := relay._course_builder.launcher.global_position
	var first_ball := future_probe
	_assert_true(relay.fire(), "A second unconfirmed shot must coexist before relay confirmation.")
	var discarded_ball := relay.current_ball
	first_ball.global_position = relay._course_builder.goals[0].global_position + Vector3.UP * CannonGolfBall.RADIUS
	relay._confirm_goal(first_ball)
	_assert_true(relay.launch_state == CannonGolfGame.LaunchState.PLANNING, "Goal one must not clear a two-leg relay.")
	_assert_true(relay.confirmed_ball_count() == 1 and relay.confirmed_ball == first_ball and first_ball.freeze, "Goal one ball must remain protected.")
	_assert_true(discarded_ball.is_queued_for_deletion(), "Goal one confirmation must remove other unconfirmed balls.")
	_assert_true(relay.active_leg_index == 1 and relay._course_builder.goal == relay._course_builder.goals[1], "Goal one confirmation must activate leg two.")
	_assert_true(not relay._course_builder.launcher.global_position.is_equal_approx(first_anchor), "Goal one confirmation must relocate the launcher.")
	_assert_defaults(relay, "A new relay leg")
	await process_frame
	_assert_true(is_instance_valid(first_ball) and first_ball.is_inside_tree(), "Goal one ball must survive deferred cleanup.")

	# Current-leg retry keeps the checkpoint, edited setup, and impact-history identities.
	relay._on_setup_changed(64.0, 52.0, 71.0)
	for index in range(3):
		relay._impact_history.stamp(Vector3(float(index), 6.0, -18.0), Vector3.UP)
	var mark_ids := relay._impact_history.mark_instance_ids()
	_assert_true(relay.fire(), "Leg two must accept a live attempt.")
	var retry_ball := relay.current_ball
	_assert_true(relay.retry_attempt(), "Relay quick retry must replace only the newest current-leg ball.")
	_assert_true(relay.active_leg_index == 1, "Quick retry must not return to an earlier relay anchor.")
	_assert_true(relay.current_ball != retry_ball and relay.active_ball_count() == 1, "Quick retry must replace, not duplicate, the current ball.")
	_assert_true(relay.confirmed_ball_count() == 1 and is_instance_valid(first_ball), "Quick retry must preserve the confirmed checkpoint ball.")
	_assert_true(relay._impact_history.mark_instance_ids() == mark_ids, "Quick retry must preserve impact history.")
	_assert_true(relay._course_builder.launcher.horizontal_aim == 64.0 and relay._course_builder.launcher.elevation_degrees == 52.0 and relay._course_builder.launcher.power_percent == 71.0, "Quick retry must preserve the edited current-leg setup.")

	# Only the final goal clears, retaining both confirmed balls.
	var final_ball := relay.current_ball
	final_ball.global_position = relay._course_builder.goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
	relay._confirm_goal(final_ball)
	_assert_true(relay.launch_state == CannonGolfGame.LaunchState.CLEARED, "The final relay goal alone must clear the course.")
	_assert_true(relay.confirmed_ball_count() == 2 and final_ball.freeze, "Final clear must retain both protected balls.")
	_assert_true(is_instance_valid(first_ball) and is_instance_valid(final_ball), "Both relay checkpoint balls must remain valid after final clear.")

	relay.reset_course()
	_assert_true(relay.active_leg_index == 0 and relay.confirmed_ball_count() == 0, "Full reset must restore relay leg one and clear checkpoints.")
	_assert_true(relay._course_builder.goal == relay._course_builder.goals[0], "Full reset must restore goal one as active.")
	_assert_defaults(relay, "Relay reset")
	relay.queue_free()
	await process_frame

	var single_goal := await _new_game(0)
	_assert_true(single_goal._course_builder.leg_count() == 1, "Legacy courses must normalize to one leg.")
	_assert_true(single_goal.fire(), "Legacy course must still fire.")
	var single_ball := single_goal.current_ball
	single_goal._confirm_goal(single_ball)
	_assert_true(single_goal.launch_state == CannonGolfGame.LaunchState.CLEARED and single_goal.confirmed_ball_count() == 1, "One-goal confirmation must still clear immediately.")
	single_goal.queue_free()
	await process_frame
	if not _failed:
		print("Cannon Golf ordered relay runtime contract passed.")
	quit(1 if _failed else 0)


func _new_game(course_index: int) -> CannonGolfGame:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = course_index
	root.add_child(game)
	await process_frame
	await process_frame
	return game


func _assert_defaults(game: CannonGolfGame, context: String) -> void:
	var launcher := game._course_builder.launcher
	_assert_true(launcher.horizontal_aim == 50.0 and launcher.elevation_degrees == 50.0 and launcher.power_percent == 50.0, "%s must show 50 / 50 / 50 defaults." % context)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
