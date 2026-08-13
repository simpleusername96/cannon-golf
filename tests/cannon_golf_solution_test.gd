extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for course_index in range(CannonGolfCourseCatalog.all_courses().size()):
		var course := CannonGolfCourseCatalog.course_at(course_index)
		for default_leg_index in range(course.leg_count()):
			var default_result := await _replay(course_index, false, default_leg_index)
			_assert_true(
				not bool(default_result.cleared) \
						and int(default_result.confirmed_count) == default_leg_index,
				"Default setup must miss relay leg %d for %s, not advance it." % [
					default_leg_index + 1, default_result.course_id,
				]
			)
		var solution_result := await _replay(course_index, true)
		_assert_true(
			bool(solution_result.cleared),
			"Direct solution witness failed for %s at %.0f horizontal / %.0f degrees / %.0f percent; state %d; outcome %s; last mark %s; ball %s; velocity %s." % [
				solution_result.course_id,
				solution_result.setup.x,
				solution_result.setup.y,
				solution_result.setup.z,
				solution_result.state,
				solution_result.outcome,
				solution_result.mark,
				solution_result.ball,
				solution_result.velocity,
			]
		)
	print("Cannon Golf default-miss and per-leg direct-solution replay passed for all courses.")
	quit(0)


func _replay(course_index: int, use_solution: bool, default_leg_index: int = 0) -> Dictionary:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = course_index
	root.add_child(game)
	await process_frame
	await process_frame
	var course := game.active_course()
	var setup := course.leg_at(0).default_setup()
	var completed_legs := 0
	var leg_limit := course.leg_count() if use_solution else default_leg_index + 1
	for leg_index in range(leg_limit):
		setup = course.solution_for_leg(leg_index) \
				if use_solution or leg_index < default_leg_index \
				else course.leg_at(leg_index).default_setup()
		game._course_builder.launcher.set_setup(setup.x, setup.y, setup.z)
		_assert_true(game.fire(), "Replay must start leg %d for %s." % [leg_index + 1, course.course_id])
		for _frame in range(60 * 18):
			await physics_frame
			if game.launch_state == CannonGolfGame.LaunchState.CLEARED \
					or game.launch_state == CannonGolfGame.LaunchState.PLANNING:
				break
		if game.launch_state == CannonGolfGame.LaunchState.CLEARED:
			completed_legs = leg_index + 1
			break
		if leg_index + 1 < leg_limit:
			_assert_true(
				game.launch_state == CannonGolfGame.LaunchState.PLANNING \
						and game.active_leg_index == leg_index + 1 \
						and game.confirmed_ball_count() == leg_index + 1,
				"Solution witness must confirm relay leg %d before replaying the next leg for %s; state %d; outcome %s; ball %s; velocity %s." % [
					leg_index + 1,
					course.course_id,
					game.launch_state,
					game.last_launch_outcome,
					str(game.current_ball.global_position) if game.current_ball != null else "none",
					str(game.current_ball.linear_velocity) if game.current_ball != null else "none",
				]
			)
			completed_legs = leg_index + 1
	var result := {
		"course_id": course.course_id,
		"setup": setup,
		"cleared": game.launch_state == CannonGolfGame.LaunchState.CLEARED,
		"state": game.launch_state,
		"outcome": game.last_launch_outcome,
		"mark": str(game._impact_history.newest_position()),
		"ball": str(game.current_ball.global_position) if game.current_ball != null else "none",
		"velocity": str(game.current_ball.linear_velocity) if game.current_ball != null else "none",
		"completed_legs": completed_legs,
		"confirmed_count": game.confirmed_ball_count(),
	}
	game.queue_free()
	await process_frame
	return result


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
