extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var goal := CannonGolfSettlementGoal.new()
	goal.configure(Vector3(3.0, 2.0, -8.0), 10.0, 3.1, 24.0, 0.0)
	root.add_child(goal)
	_assert_true(goal.find_children("*", "StaticBody3D", true, false).size() == 1, "Goal must own one physical plate body.")
	_assert_true(goal.find_children("GoalPlateFloorCollision", "CollisionShape3D", true, false).size() == 1, "Goal plate must own one floor collision.")
	_assert_true(goal.find_children("GoalPlateWallCollision*", "CollisionShape3D", true, false).size() == 13, "Goal plate must leave a three-segment incoming opening.")
	_assert_true(goal.contains_ball(Vector3(3.0, 3.0, -8.0), CannonGolfBall.RADIUS), "Centered ball must be inside.")
	_assert_true(not goal.contains_ball(Vector3(14.0, 3.0, -8.0), CannonGolfBall.RADIUS), "Outside ball must not be contained.")
	_assert_true(is_equal_approx(goal.settle_seconds, 1.0), "Goal dwell must be one continuous second.")
	_assert_true(goal.motion_is_safe(Vector3(0.2, 0.1, 0.2), Vector3(0.0, 0.8, 0.0)), "Slow motion must be safe.")
	_assert_true(goal.motion_is_safe(Vector3(1.2, 0.0, 0.0), Vector3.ZERO), "Equivalent time-scaled safe motion must settle.")
	_assert_true(not goal.motion_is_safe(Vector3(2.5, 0.0, 0.0), Vector3.ZERO), "Fast translation must not settle.")
	_assert_true(not goal.motion_is_safe(Vector3.ZERO, Vector3(0.0, 5.0, 0.0)), "Fast rotation must not settle.")
	_assert_true(
		goal.motion_allows_settlement_drag(Vector3(4.0, 0.0, 0.0), Vector3(0.0, 16.0, 0.0)),
		"A contained low-energy ball must be admitted to settlement drag."
	)
	_assert_true(
		not goal.motion_allows_settlement_drag(Vector3(4.1, 0.0, 0.0), Vector3.ZERO) \
				and not goal.motion_allows_settlement_drag(Vector3.ZERO, Vector3(0.0, 16.1, 0.0)),
		"A fast translating or spinning ball must retain ordinary drag."
	)
	var drag_ball := CannonGolfBall.new()
	root.add_child(drag_ball)
	_assert_true(
		is_equal_approx(drag_ball.linear_damp, CannonGolfBallistics.LINEAR_DAMP) \
				and is_equal_approx(drag_ball.angular_damp, CannonGolfBall.ORDINARY_ANGULAR_DAMP),
		"A new ball must begin with ordinary drag."
	)
	drag_ball.set_settlement_drag(true)
	_assert_true(
		drag_ball.settlement_drag_is_active() \
				and is_equal_approx(drag_ball.linear_damp, 1.2) \
				and is_equal_approx(drag_ball.angular_damp, 2.4),
		"Settlement drag must apply the bounded ball-local values."
	)
	drag_ball.set_settlement_drag(false)
	_assert_true(
		not drag_ball.settlement_drag_is_active() \
				and is_equal_approx(drag_ball.linear_damp, CannonGolfBallistics.LINEAR_DAMP) \
				and is_equal_approx(drag_ball.angular_damp, CannonGolfBall.ORDINARY_ANGULAR_DAMP),
		"Leaving settlement drag must restore ordinary ball motion."
	)
	drag_ball.queue_free()
	_assert_true(_visible_rim_marker_count(goal) == 13, "The active plate must show every wall segment outside its entry.")
	goal.set_visual_state(CannonGolfSettlementGoal.VisualState.FUTURE)
	_assert_true(_visible_rim_marker_count(goal) == 7, "A future goal must use an alternating wall rhythm.")
	goal.set_visual_state(CannonGolfSettlementGoal.VisualState.CONFIRMED)
	_assert_true(_visible_rim_marker_count(goal) == 4, "A confirmed goal must defer to its retained ball.")
	goal.set_visual_state(CannonGolfSettlementGoal.VisualState.ACTIVE)
	goal.queue_free()
	await process_frame
	for course in CannonGolfCourseCatalog.all_courses():
		await _assert_physical_plate(course)
	print("Cannon Golf settlement-goal contract passed.")
	quit(0)


func _assert_physical_plate(course: CannonGolfCourseData) -> void:
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	builder.build(course)
	var center: Vector3 = builder.course.goal_position
	var start_offsets := [
		Vector2.ZERO,
		Vector2(course.goal_radius * 0.32, 0.0),
		Vector2(-course.goal_radius * 0.24, course.goal_radius * 0.22),
	]
	for raw_offset in start_offsets:
		var offset: Vector2 = raw_offset
		var xz: Vector2 = Vector2(center.x, center.z) + offset
		var ball := CannonGolfBall.new()
		ball.configure(
			builder.course.play_bounds,
			Vector3(xz.x, center.y + CannonGolfBall.RADIUS + 0.08, xz.y),
			Vector3.ZERO
		)
		builder.add_child(ball)
		var remained_contained := true
		for _frame in range(240):
			await physics_frame
			if not builder.goal.contains_rebound_column(ball.global_position, CannonGolfBall.RADIUS):
				remained_contained = false
				break
		_assert_true(remained_contained, "%s low-speed plate start must remain contained." % course.course_id)
		ball.queue_free()
		await process_frame
	var fast_ball := CannonGolfBall.new()
	fast_ball.configure(
		builder.course.play_bounds,
		center + Vector3.UP * (
			builder.goal.rim_height + CannonGolfBall.RADIUS + 0.20
		),
		Vector3(96.0, 24.0, 0.0)
	)
	builder.add_child(fast_ball)
	var exited := false
	for _frame in range(240):
		await physics_frame
		if not builder.goal.contains_rebound_column(fast_ball.global_position, CannonGolfBall.RADIUS):
			exited = true
			break
	_assert_true(exited, "%s fast ball must be able to exit and remain unconfirmed." % course.course_id)
	fast_ball.queue_free()
	builder.queue_free()
	await process_frame


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _visible_rim_marker_count(goal: CannonGolfSettlementGoal) -> int:
	var count := 0
	for child in goal.find_children("GoalRimMarker*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and String(child.name).begins_with("GoalRimMarker") \
				and child.visible:
			count += 1
	return count
