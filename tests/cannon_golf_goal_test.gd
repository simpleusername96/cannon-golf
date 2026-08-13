extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var goal := CannonGolfSettlementGoal.new()
	goal.configure(Vector3(3.0, 2.0, -8.0), 10.0, 5.5)
	root.add_child(goal)
	_assert_true(goal.find_children("*", "StaticBody3D", true, false).is_empty(), "Goal must be a non-colliding marker over the terrain depression.")
	_assert_true(goal.contains_ball(Vector3(3.0, 2.7, -8.0), 0.55), "Centered ball must be inside.")
	_assert_true(not goal.contains_ball(Vector3(14.0, 2.7, -8.0), 0.55), "Outside ball must not be contained.")
	_assert_true(goal.motion_is_safe(Vector3(0.2, 0.1, 0.2), Vector3(0.0, 0.8, 0.0)), "Slow motion must be safe.")
	_assert_true(not goal.motion_is_safe(Vector3(1.2, 0.0, 0.0), Vector3.ZERO), "Fast translation must not settle.")
	_assert_true(not goal.motion_is_safe(Vector3.ZERO, Vector3(0.0, 3.0, 0.0)), "Fast rotation must not settle.")
	goal.queue_free()
	await process_frame
	for course in CannonGolfCourseCatalog.all_courses():
		await _assert_physical_basin(course)
	print("Cannon Golf settlement-goal contract passed.")
	quit(0)


func _assert_physical_basin(course: CannonGolfCourseData) -> void:
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
		var surface_y := builder.terrain_layout.height_at_local(xz.x, xz.y)
		var ball := CannonGolfBall.new()
		ball.configure(
			builder.course.play_bounds,
			Vector3(xz.x, surface_y + CannonGolfBall.RADIUS + 0.08, xz.y),
			Vector3.ZERO
		)
		builder.add_child(ball)
		var remained_contained := true
		for _frame in range(240):
			await physics_frame
			if not builder.goal.contains_rebound_column(ball.global_position, CannonGolfBall.RADIUS):
				remained_contained = false
				break
		_assert_true(remained_contained, "%s low-speed basin start must remain contained." % course.course_id)
		ball.queue_free()
		await process_frame
	var fast_ball := CannonGolfBall.new()
	fast_ball.configure(
		builder.course.play_bounds,
		center + Vector3.UP * (CannonGolfBall.RADIUS + 0.08),
		Vector3(24.0, 6.0, 0.0)
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
