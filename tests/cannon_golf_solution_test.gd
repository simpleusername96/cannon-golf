extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for course_index in range(CannonGolfCourseCatalog.all_courses().size()):
		var game := GAME_SCENE.instantiate() as CannonGolfGame
		root.add_child(game)
		await process_frame
		await process_frame
		if course_index > 0:
			game._load_course(course_index)
			await process_frame
		var course := game.active_course()
		var solution := course.direct_solution()
		game._course_builder.launcher.set_setup(solution.x, solution.y)
		_assert_true(game.fire(), "Solution witness must start for %s." % course.course_id)
		for _frame in range(60 * 18):
			await physics_frame
			if game.launch_state == CannonGolfGame.LaunchState.CLEARED:
				break
			if game.launch_state == CannonGolfGame.LaunchState.PLANNING:
				break
		_assert_true(
			game.launch_state == CannonGolfGame.LaunchState.CLEARED,
			"Direct solution witness failed for %s at %.0f degrees / %.0f percent; state %d; outcome %s; last mark %s; ball %s; velocity %s." % [
				course.course_id,
				solution.x,
				solution.y,
				game.launch_state,
				game.last_launch_outcome,
				str(game._impact_history.newest_position()),
				str(game.current_ball.global_position) if game.current_ball != null else "none",
				str(game.current_ball.linear_velocity) if game.current_ball != null else "none",
			]
		)
		game.queue_free()
		await process_frame
	print("Cannon Golf direct-solution replay passed for both courses.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
