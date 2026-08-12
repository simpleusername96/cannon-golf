extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for course_index in range(CannonGolfCourseCatalog.all_courses().size()):
		var default_result := await _replay(course_index, false)
		_assert_true(
			not bool(default_result.cleared),
			"Default setup must be a learnable miss for %s, not the answer." % default_result.course_id
		)
		var solution_result := await _replay(course_index, true)
		_assert_true(
			bool(solution_result.cleared),
			"Direct solution witness failed for %s at %.0f degrees / %.0f percent; state %d; outcome %s; last mark %s; ball %s; velocity %s." % [
				solution_result.course_id,
				solution_result.setup.x,
				solution_result.setup.y,
				solution_result.state,
				solution_result.outcome,
				solution_result.mark,
				solution_result.ball,
				solution_result.velocity,
			]
		)
	print("Cannon Golf default-miss and direct-solution replay passed for both courses.")
	quit(0)


func _replay(course_index: int, use_solution: bool) -> Dictionary:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = course_index
	root.add_child(game)
	await process_frame
	await process_frame
	var course := game.active_course()
	var setup := course.direct_solution() if use_solution else Vector2(
		course.default_elevation_degrees, course.default_power_percent
	)
	game._course_builder.launcher.set_setup(setup.x, setup.y)
	_assert_true(game.fire(), "Replay must start for %s." % course.course_id)
	for _frame in range(60 * 18):
		await physics_frame
		if game.launch_state == CannonGolfGame.LaunchState.CLEARED \
				or game.launch_state == CannonGolfGame.LaunchState.PLANNING:
			break
	var result := {
		"course_id": course.course_id,
		"setup": setup,
		"cleared": game.launch_state == CannonGolfGame.LaunchState.CLEARED,
		"state": game.launch_state,
		"outcome": game.last_launch_outcome,
		"mark": str(game._impact_history.newest_position()),
		"ball": str(game.current_ball.global_position) if game.current_ball != null else "none",
		"velocity": str(game.current_ball.linear_velocity) if game.current_ball != null else "none",
	}
	game.queue_free()
	await process_frame
	return result


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
