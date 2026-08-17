extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_confirmation_restores_planning_pose()
	await _assert_free_order(4, [2, 0, 1])
	await _assert_free_order(9, [5, 1, 4, 0, 3, 2])
	if not _failed:
		print("Cannon Golf player-directed multi-goal contract passed.")
	quit(1 if _failed else 0)


func _assert_confirmation_restores_planning_pose() -> void:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = CannonGolfCourseCatalog.index_of(&"deep_relay")
	root.add_child(game)
	await process_frame
	await process_frame
	_assert(game._course_builder.goals.size() > 1, "Camera regression fixture needs multiple goals.")
	game.zoom_planning(CannonGolfCourseCameraRig.CLOSE_ZOOM)
	game.orbit_planning(Vector2(96.0, -34.0))
	game.pan_planning(Vector2(1.0, 0.0))
	game._camera_rig.update(1.0)
	var expected_transform := game._camera.global_transform
	var launcher_before := game._course_builder.launcher.global_position
	_assert(game.fire(), "Camera regression fixture must launch its unrelated live ball.")
	var unrelated_ball := game.current_ball
	_assert(game.fire(), "Camera regression fixture must launch its confirming ball.")
	var winning_ball := game.current_ball
	var goal := game._course_builder.goal_at(0)
	winning_ball.global_position = goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
	winning_ball.linear_velocity = Vector3.ZERO
	winning_ball.angular_velocity = Vector3.ZERO
	game._confirm_goal(winning_ball, 0)
	_assert(
		game._camera_rig.camera_mode == &"planning" \
				and game._camera.global_transform.is_equal_approx(expected_transform),
		"Intermediate confirmation must restore the exact saved planning pose immediately."
	)
	_assert(
		winning_ball.is_queued_for_deletion() and not game.active_balls().has(winning_ball) \
				and game.active_balls().has(unrelated_ball),
		"Camera restoration must release the resolved winner and keep every other live ball active."
	)
	_assert(
		game._course_builder.launcher.global_position.is_equal_approx(launcher_before) \
				and game.can_fire(),
		"Intermediate confirmation must not move the cannon or block the next launch."
	)
	var expected_pan := game.planning_pan
	var expected_zoom := game.planning_zoom
	var expected_orbit := game._camera_rig.orbit_degrees
	_assert(game.select_launcher_source(0), "The completed goal must be selectable as a source.")
	game._camera_rig.update(1.0)
	_assert(
		game.planning_view == &"oblique" \
				and game.planning_pan.is_equal_approx(expected_pan) \
				and is_equal_approx(game.planning_zoom, expected_zoom) \
				and game._camera_rig.orbit_degrees.is_equal_approx(expected_orbit) \
				and game._camera.global_transform.is_equal_approx(expected_transform),
		"Selecting a completed goal source must not reset or switch the overview camera."
	)
	game.queue_free()
	await process_frame


func _assert_free_order(course_index: int, completion_order: Array[int]) -> void:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = course_index
	root.add_child(game)
	await process_frame
	await process_frame
	_assert(
		game._course_builder.goals.size() == completion_order.size(),
		"Runtime must build every numbered goal."
	)
	_assert(game.selected_launcher_goal_index == -1, "Every course must begin at Start.")
	_assert(not game.select_launcher_source(0), "An incomplete goal cannot become a cannon source.")
	_assert(game.fire() and game.fire(), "Concurrent setup must accept multiple live balls.")
	var unrelated_ball := game.current_ball
	for goal_index in completion_order:
		var launcher_before := game._course_builder.launcher.position
		_assert(game.fire(), "Every free-order attempt must be immediately playable.")
		var ball := game.current_ball
		var goal := game._course_builder.goal_at(goal_index)
		ball.global_position = goal.global_position + Vector3.UP * CannonGolfBall.RADIUS
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		game._update_live_ball(ball, goal.settle_seconds + 0.1)
		_assert(
			game.completed_goal_indices.has(goal_index),
			"Any incomplete goal must confirm without waiting for a numeric predecessor."
		)
		_assert(
			game._course_builder.launcher.position.is_equal_approx(launcher_before),
			"Goal confirmation must not move the cannon automatically."
		)
		_assert(
			game._course_builder.goal_at(goal_index).visual_state \
					== CannonGolfSettlementGoal.VisualState.CONFIRMED,
			"The confirmed goal must retain its completed world state."
		)
		if game.completed_goal_indices.size() == 1:
			_assert(
				game.active_balls().has(unrelated_ball),
				"An intermediate confirmation must preserve every other live ball."
			)
		if game.completed_goal_indices.size() < completion_order.size():
			_assert(
				game.launch_state != CannonGolfGame.LaunchState.CLEARED and game.can_fire(),
				"A remaining incomplete goal must keep the course playable."
			)
			_assert(
				game.select_launcher_source(goal_index),
				"A confirmed goal must unlock as an optional cannon source."
			)
			_assert(
				Vector2(
					game._course_builder.launcher.position.x,
					game._course_builder.launcher.position.z
				).is_equal_approx(Vector2(goal.position.x, goal.position.z)),
				"The selected goal source must center the one reusable cannon."
			)
			_assert_defaults(game, "A newly selected cannon source")
	_assert(
		game.launch_state == CannonGolfGame.LaunchState.CLEARED \
				and game.completed_goal_count() == completion_order.size(),
		"Only completion of every goal may clear a multi-goal course."
	)
	game.queue_free()
	await process_frame


func _assert_defaults(game: CannonGolfGame, label: String) -> void:
	_assert(
		game._course_builder.launcher.horizontal_aim == 50.0 \
				and game._course_builder.launcher.elevation_degrees == 50.0 \
				and game._course_builder.launcher.power_percent == 50.0,
		"%s must start at 50 / 50 / 50." % label
	)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
