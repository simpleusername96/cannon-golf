extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var relay_index := CannonGolfCourseCatalog.index_of(&"deep_relay")
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = relay_index
	root.add_child(game)
	await process_frame
	await process_frame
	var original_position := game._course_builder.launcher.position
	var second_goal := game._course_builder.goal_at(1)
	_assert(game.fire(), "The free-goal course must permit its first shot.")
	var confirmed := game.current_ball
	confirmed.global_position = second_goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
	confirmed.linear_velocity = Vector3.ZERO
	confirmed.angular_velocity = Vector3.ZERO
	game._update_live_ball(confirmed, second_goal.settle_seconds + 0.1)
	_assert(
		game.completed_goal_indices == [1] \
				and game.launch_state == CannonGolfGame.LaunchState.PLANNING,
		"Goal 2 may confirm before Goal 1 without clearing the course."
	)
	_assert(
		game._course_builder.launcher.position.is_equal_approx(original_position),
		"Confirmation must leave the currently selected Start source unchanged."
	)
	_assert(not game.select_launcher_source(0), "Goal 1 must remain locked until completed.")
	var next_source := game._hud.get_node("%LauncherSourceNext") as Button
	_assert(not next_source.disabled, "A completed goal must enable the next source arrow.")
	next_source.pressed.emit()
	_assert(game.selected_launcher_goal_index == 1, "The next arrow must select completed Goal 2.")
	_assert(
		Vector2(
			game._course_builder.launcher.position.x,
			game._course_builder.launcher.position.z
		).is_equal_approx(Vector2(second_goal.position.x, second_goal.position.z)),
		"The selected goal source must use the exact basin-floor center."
	)
	game._on_setup_changed(64.0, 52.0, 71.0)
	_assert(game.fire(), "The selected completed-goal source must fire.")
	var first_origin := game.current_ball.global_position
	var first_velocity := game.current_ball.linear_velocity
	_assert(game.select_launcher_source(-1), "Start must remain selectable during flight.")
	_assert(game.retry_attempt(), "Retry must remain available after a source change.")
	_assert(
		game.selected_launcher_goal_index == 1 \
				and game.current_ball.global_position.is_equal_approx(first_origin) \
				and game.current_ball.linear_velocity.is_equal_approx(first_velocity),
		"Retry must restore the live shot's recorded source and setup exactly."
	)
	var first_goal := game._course_builder.goal_at(0)
	game.current_ball.global_position = first_goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
	game.current_ball.linear_velocity = Vector3.ZERO
	game.current_ball.angular_velocity = Vector3.ZERO
	game._update_live_ball(game.current_ball, first_goal.settle_seconds + 0.1)
	_assert(
		game.launch_state == CannonGolfGame.LaunchState.CLEARED \
				and game.completed_goal_indices == [0, 1] \
				and game.completed_goal_count() == 2,
		"Completing the remaining goal must clear with both goal identities recorded."
	)
	game.reset_course()
	_assert(
		game.completed_goal_indices.is_empty() \
				and game.selected_launcher_goal_index == -1 \
				and game._course_builder.launcher.position.is_equal_approx(original_position),
		"Course reset must clear progress and restore Start."
	)
	game.queue_free()
	await process_frame
	if not _failed:
		print("Cannon Golf free-goal launcher-source contract passed.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
