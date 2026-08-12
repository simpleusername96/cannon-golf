extends SceneTree


func _initialize() -> void:
	var goal := CannonGolfSettlementGoal.new()
	goal.configure(Vector3(3.0, 2.0, -8.0), 5.5)
	root.add_child(goal)
	_assert_true(goal.find_children("*", "StaticBody3D", true, false).is_empty(), "Goal must be a non-colliding marker over the terrain depression.")
	_assert_true(goal.contains_ball(Vector3(3.0, 2.7, -8.0), 0.55), "Centered ball must be inside.")
	_assert_true(not goal.contains_ball(Vector3(9.2, 2.7, -8.0), 0.55), "Outside ball must not be contained.")
	_assert_true(goal.motion_is_safe(Vector3(0.2, 0.1, 0.2), Vector3(0.0, 0.8, 0.0)), "Slow motion must be safe.")
	_assert_true(not goal.motion_is_safe(Vector3(1.2, 0.0, 0.0), Vector3.ZERO), "Fast translation must not settle.")
	_assert_true(not goal.motion_is_safe(Vector3.ZERO, Vector3(0.0, 3.0, 0.0)), "Fast rotation must not settle.")
	print("Cannon Golf settlement-goal contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
