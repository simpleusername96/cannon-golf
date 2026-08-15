extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_rebound_cancels_candidate_and_allows_reentry()
	await _assert_timeout_applies_only_before_contact()
	await _assert_bounds_exit_is_immediate()
	quit(1 if _failed else 0)


func _assert_rebound_cancels_candidate_and_allows_reentry() -> void:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = CannonGolfCourseCatalog.index_of(&"deep_relay")
	root.add_child(game)
	await process_frame
	await process_frame
	_assert(game._course_builder.goals.size() >= 2, "Fixture course needs two incomplete goals.")
	_assert(game.fire(), "Lifecycle fixture must launch one live ball.")
	var ball := game.current_ball
	var first_goal := game._course_builder.goal_at(0)
	var second_goal := game._course_builder.goal_at(1)
	ball.global_position = first_goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	game._update_live_ball(ball, 0.1)
	var shot := game._shot_state(ball)
	_assert(
		shot.settlement_goal_index == 0 and ball.settlement_drag_is_active(),
		"Entering a plate must create a settlement candidate and enable bounded drag."
	)
	ball.linear_velocity = Vector3(3.0, 0.0, 0.0)
	game._update_live_ball(ball, 0.1)
	_assert(
		shot.settlement_goal_index == 0 and is_zero_approx(shot.settle_elapsed),
		"Unsafe motion inside a plate must reset dwell without discarding its candidate."
	)
	ball.global_position = game._course_builder.course.play_bounds.get_center() + Vector3.UP * 8.0
	ball.linear_velocity = Vector3(8.0, 0.0, 0.0)
	ball.angular_velocity = Vector3.ZERO
	game._update_live_ball(ball, 0.1)
	_assert(
		game.active_ball_count() == 1 and not shot.ending \
				and shot.settlement_goal_index == -1 \
				and is_zero_approx(shot.settle_elapsed) \
				and not ball.settlement_drag_is_active(),
		"Leaving a plate must clear only settlement state and retain the live ball."
	)
	ball.global_position = first_goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
	ball.linear_velocity = Vector3(1.0, 0.0, 0.0)
	game._update_live_ball(ball, 0.1)
	_assert(shot.settlement_goal_index == 0, "A rebounded ball must be eligible to re-enter the same goal.")
	ball.global_position = game._course_builder.course.play_bounds.get_center() + Vector3.UP * 8.0
	ball.linear_velocity = Vector3(8.0, 0.0, 0.0)
	game._update_live_ball(ball, 0.1)
	ball.global_position = second_goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
	ball.linear_velocity = Vector3(1.0, 0.0, 0.0)
	game._update_live_ball(ball, 0.1)
	_assert(shot.settlement_goal_index == 1, "A rebounded ball must be eligible for another incomplete goal.")
	ball.global_position = game._course_builder.course.play_bounds.get_center() + Vector3.UP * 8.0
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.sleeping = true
	game._update_live_ball(ball, 1.99)
	_assert(not shot.ending, "Stable outside rest must not resolve before two real seconds.")
	game._update_live_ball(ball, 0.01)
	_assert(shot.ending, "Stable outside rest must resolve after two continuous real seconds.")
	await process_frame
	await process_frame
	game.queue_free()
	await process_frame


func _assert_timeout_applies_only_before_contact() -> void:
	var untouched := CannonGolfBall.new()
	var untouched_reasons: Array[StringName] = []
	untouched.launch_ended.connect(func(_ball: CannonGolfBall, reason: StringName) -> void:
		untouched_reasons.append(reason)
	)
	root.add_child(untouched)
	await process_frame
	untouched.configure(AABB(Vector3(-100.0, -100.0, -100.0), Vector3(200.0, 200.0, 200.0)), Vector3.ZERO, Vector3.ZERO)
	untouched._elapsed = CannonGolfBall.MAXIMUM_FLIGHT_SECONDS - 0.01
	untouched._physics_process(0.02)
	_assert(untouched_reasons == [&"timeout"], "A never-contacted ball must time out after fifteen seconds.")
	untouched.queue_free()
	var contacted := CannonGolfBall.new()
	var contacted_reasons: Array[StringName] = []
	contacted.launch_ended.connect(func(_ball: CannonGolfBall, reason: StringName) -> void:
		contacted_reasons.append(reason)
	)
	root.add_child(contacted)
	await process_frame
	contacted.configure(AABB(Vector3(-100.0, -100.0, -100.0), Vector3(200.0, 200.0, 200.0)), Vector3.ZERO, Vector3.ZERO)
	contacted._first_contact_emitted = true
	contacted._elapsed = CannonGolfBall.MAXIMUM_FLIGHT_SECONDS + 30.0
	contacted._physics_process(0.02)
	_assert(contacted_reasons.is_empty(), "A contacted ball must not have an absolute flight timeout.")
	contacted.queue_free()
	await process_frame


func _assert_bounds_exit_is_immediate() -> void:
	var ball := CannonGolfBall.new()
	var reasons: Array[StringName] = []
	ball.launch_ended.connect(func(_ball: CannonGolfBall, reason: StringName) -> void:
		reasons.append(reason)
	)
	root.add_child(ball)
	await process_frame
	ball.configure(AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0)), Vector3(3.0, 0.0, 0.0), Vector3.ZERO)
	ball._physics_process(0.01)
	_assert(reasons == [&"out_of_bounds"], "Leaving playable bounds must resolve immediately.")
	ball.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
