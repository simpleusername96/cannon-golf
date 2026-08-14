extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for course_index in [4, 9]:
		var game := GAME_SCENE.instantiate() as CannonGolfGame
		game.initial_course_index = course_index
		root.add_child(game)
		await process_frame
		await process_frame
		var expected_count := 3 if course_index == 4 else 6
		_assert(game._course_builder.leg_count() == expected_count, "Runtime must build every authored checkpoint.")
		for leg_index in range(expected_count):
			_assert(game.active_leg_index == leg_index, "Only the ordered active checkpoint may advance.")
			_assert(game.fire(), "Every checkpoint launcher must be immediately usable.")
			var ball := game.current_ball
			game._confirm_goal(ball)
			_assert(game.confirmed_ball_count() == leg_index + 1, "Each confirmed ball must persist.")
			if leg_index + 1 < expected_count:
				_assert(game.launch_state == CannonGolfGame.LaunchState.PLANNING, "Intermediate goals must not clear the course.")
			else:
				_assert(game.launch_state == CannonGolfGame.LaunchState.CLEARED, "Only the final ordered goal may clear.")
		game.queue_free()
		await process_frame
	if not _failed:
		print("Cannon Golf three- and six-goal runtime transition contract passed.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
