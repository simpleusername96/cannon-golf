extends SceneTree


func _initialize() -> void:
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	for course in CannonGolfCourseCatalog.all_courses():
		_assert_true(builder.build(course), "Every catalog course must build from its prepared artifact.")
		_assert_true(builder.course != course and builder.course.course_id == course.course_id, "Builder must isolate authored runtime data while retaining identity.")
		_assert_true(builder.prepared_course != null and builder.prepared_course.is_valid_for(course), "Builder must retain the matching prepared artifact.")
		_assert_true(builder.launcher != null, "Built course must contain one launcher.")
		_assert_true(builder.goal != null, "Built course must contain one settlement goal.")
		_assert_true(builder.leg_count() == course.leg_count(), "Built course must expose every normalized course leg.")
		_assert_true(builder.goals.size() == course.leg_count(), "Built course must create one goal node per leg.")
		_assert_true(builder.terrain_body_count() == 1, "A course must expose one connected terrain body.")
		_assert_true(builder.terrain_body != null and builder.terrain_body.is_in_group(&"impact_mark_surface"), "Prepared terrain must retain impact-mark collision ownership.")
		_assert_true(builder.course.content_bounds.has_point(builder.course.cannon_position), "Content bounds must include the launcher.")
		_assert_true(builder.course.content_bounds.has_point(builder.course.goal_position), "Content bounds must include the active goal.")
		_assert_true(builder.goal.find_children("*", "StaticBody3D", true, false).is_empty(), "Goal visuals must not own collision.")
		_assert_true(builder.get_node_or_null("Mechanisms") == null, "Fresh courses must not contain devices.")
		_assert_true(
			(builder.terrain_body.get_node("TerrainMesh") as MeshInstance3D).mesh \
					== builder.prepared_course.render_mesh,
			"Runtime terrain must use the prepared render mesh without rebuilding it."
		)
		var first_anchor := builder.launcher.position
		for leg_index in range(1, course.leg_count()):
			var previous_goal_center := builder.goals[leg_index - 1].position
			_assert_true(builder.activate_leg(leg_index), "Every prepared checkpoint must activate.")
			_assert_true(builder.goal == builder.goals[leg_index], "Activation must expose the ordered active goal.")
			_assert_true(
				Vector2(builder.launcher.position.x, builder.launcher.position.z).is_equal_approx(
					Vector2(previous_goal_center.x, previous_goal_center.z)
				),
				"Every later launcher must be centered on the completed goal."
			)
			_assert_true(builder.get_node_or_null("Launcher") == builder.launcher, "Checkpoint activation must not spawn another launcher.")
		if course.leg_count() > 1:
			_assert_true(not builder.launcher.position.is_equal_approx(first_anchor), "A multi-goal course must relocate its reusable launcher.")
		_assert_true(builder.activate_leg(0), "Builder must return to the first leg for the next build.")
	print("Cannon Golf prepared course-build contract passed for ten courses.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
