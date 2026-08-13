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

	# A visibly captured edge landing must settle promptly, relocate the one
	# launcher, and make the next leg immediately playable.
	var first_anchor := relay._course_builder.launcher.global_position
	_assert_true(relay.fire(), "Relay must permit an edge-settlement probe.")
	var edge_probe := relay.current_ball
	var first_goal := relay._course_builder.goal
	var edge_x := first_goal.global_position.x + first_goal.inner_radius * 0.90
	var edge_z := first_goal.global_position.z
	var edge_y := relay._course_builder.terrain_layout.height_at_local(edge_x, edge_z) \
			+ CannonGolfBall.RADIUS + 0.08
	edge_probe.global_position = Vector3(edge_x, edge_y, edge_z)
	edge_probe.linear_velocity = Vector3.ZERO
	edge_probe.angular_velocity = Vector3.ZERO
	var edge_settle_frames := 0
	for frame in range(180):
		await physics_frame
		edge_settle_frames = frame + 1
		if relay.active_leg_index == 1:
			break
	var leg_two := relay._course_builder.generated_course.leg_at(1)
	_assert_true(
		relay.active_leg_index == 1 and edge_settle_frames <= 180 \
				and relay.confirmed_ball_count() == 1,
		"A contained relay edge landing must confirm within three seconds."
	)
	_assert_true(
		relay._course_builder.launcher.global_position.is_equal_approx(leg_two.launcher_position) \
				and not relay._course_builder.launcher.global_position.is_equal_approx(first_anchor),
		"Goal one confirmation must place the same launcher at the authored leg-two anchor."
	)
	var leg_two_origin := relay._course_builder.launcher.launch_origin()
	_assert_true(
		relay.can_fire() and leg_two_origin.is_finite() \
				and leg_two_origin.distance_to(edge_probe.global_position) > 2.0,
		"The relocated launcher must expose a safe, immediately usable muzzle origin."
	)
	_assert_true(relay.fire(), "The relocated launcher must fire without a course reset.")
	_assert_true(
		relay.current_ball.global_position.is_equal_approx(leg_two_origin) \
				and relay.active_leg_index == 1,
		"The next ball must originate from the leg-two relay launcher."
	)
	relay.reset_course()
	_assert_true(relay.active_leg_index == 0, "Edge-settlement probe cleanup must restore leg one.")

	# Settlement drag must never capture a fast arrival that can clear the rim.
	_assert_true(relay.fire(), "Relay must permit a physical bounce-out probe.")
	var fast_probe := relay.current_ball
	fast_probe.global_position = relay._course_builder.goal.global_position \
			+ Vector3.UP * (CannonGolfBall.RADIUS + 0.08)
	fast_probe.linear_velocity = Vector3(30.0, 16.0, 0.0)
	fast_probe.angular_velocity = Vector3.ZERO
	for _frame in range(120):
		await physics_frame
		if relay.current_ball == null:
			break
	_assert_true(
		relay.active_leg_index == 0 and relay.confirmed_ball_count() == 0 \
				and relay.last_launch_outcome == &"bounced_out",
		"A fast goal arrival must escape and fail instead of entering settlement drag."
	)
	relay.reset_course()

	# A late arrival inside the active basin must settle instead of being removed
	# by the general flight horizon.
	_assert_true(relay.fire(), "Relay must permit a late-arrival settlement probe.")
	var timeout_probe := relay.current_ball
	timeout_probe.global_position = relay._course_builder.goal.global_position \
			+ Vector3.UP * CannonGolfBall.RADIUS
	timeout_probe.linear_velocity = Vector3.ZERO
	timeout_probe.angular_velocity = Vector3.ZERO
	relay._update_live_ball(timeout_probe, 0.01)
	timeout_probe.end_launch(&"timeout")
	await process_frame
	_assert_true(
		relay.active_ball_count() == 1 and relay.active_leg_index == 0,
		"An active-goal timeout must defer to settlement instead of deleting the ball."
	)
	relay._update_live_ball(timeout_probe, relay._course_builder.goal.settle_seconds + 0.1)
	_assert_true(
		relay.active_leg_index == 1 and relay.confirmed_ball_count() == 1,
		"A late safe arrival must confirm relay goal one."
	)
	relay.reset_course()
	_assert_true(relay.active_leg_index == 0, "Timeout regression setup must restore relay leg one.")
	_assert_true(relay.fire(), "Relay must permit a post-timeout bounce-out probe.")
	var bounce_probe := relay.current_ball
	bounce_probe.global_position = relay._course_builder.goal.global_position \
			+ Vector3.UP * CannonGolfBall.RADIUS
	relay._update_live_ball(bounce_probe, 0.01)
	bounce_probe.end_launch(&"timeout")
	bounce_probe.global_position += Vector3.RIGHT \
			* (relay._course_builder.goal.inner_radius + CannonGolfBall.RADIUS)
	relay._update_live_ball(bounce_probe, 0.01)
	await process_frame
	_assert_true(
		relay.confirmed_ball_count() == 0 and relay.active_leg_index == 0 \
				and relay.last_launch_outcome == &"bounced_out",
		"A timed-out ball that leaves the active goal must still fail as bounced out."
	)

	# A ball resting in the future basin is still evaluated only against goal one.
	_assert_true(relay.fire(), "Relay must permit the first shot.")
	var future_probe := relay.current_ball
	future_probe.global_position = relay._course_builder.goals[1].global_position
	future_probe.linear_velocity = Vector3.ZERO
	future_probe.angular_velocity = Vector3.ZERO
	relay._update_live_ball(future_probe, relay._course_builder.goal.settle_seconds + 0.1)
	_assert_true(relay.confirmed_ball_count() == 0 and relay.active_leg_index == 0, "A future goal must not confirm before it becomes active.")

	# Goal one confirmation locks its ball, removes a competing shot, and relocates the same launcher.
	first_anchor = relay._course_builder.launcher.global_position
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
