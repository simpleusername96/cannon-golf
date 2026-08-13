extends SceneTree


func _initialize() -> void:
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	for course in CannonGolfCourseCatalog.all_courses():
		builder.build(course)
		_assert_true(builder.course != course and builder.course.course_id == course.course_id, "Builder must isolate runtime course data while retaining course identity.")
		_assert_true(builder.launcher != null, "Built course must contain one launcher.")
		_assert_true(builder.goal != null, "Built course must contain one settlement goal.")
		_assert_true(builder.leg_count() == course.leg_count(), "Built course must expose every normalized course leg.")
		_assert_true(builder.goals.size() == course.leg_count(), "Built course must create one goal node per leg.")
		_assert_true(builder.terrain_body_count() == 1, "A course must expose one connected terrain body.")
		_assert_true(builder.terrain_body != null, "Built course must retain the terrain body.")
		_assert_true(builder.terrain_body.is_in_group(&"impact_mark_surface"), "Terrain body must stamp impact history.")
		_assert_true(builder.terrain_layout != null and builder.terrain_layout.is_valid(), "Built course must retain generated topology.")
		_assert_true(builder.course.content_bounds.has_volume(), "Built course must retain generated content bounds.")
		_assert_true(builder.course.content_bounds.has_point(builder.course.cannon_position), "Content bounds must include the cannon.")
		_assert_true(builder.course.content_bounds.has_point(builder.course.goal_position), "Content bounds must include the goal.")
		_assert_true(builder.goal.find_children("*", "StaticBody3D", true, false).is_empty(), "Goal visuals must not own collision.")
		_assert_true(builder.get_node_or_null("Mechanisms") == null, "Fresh courses must not contain devices.")
		if course.has_explicit_legs():
			_assert_true(builder.generated_course != null, "Relay courses must keep their typed generated result.")
			_assert_true(builder.get_node_or_null("Launcher") == builder.launcher, "Relay must retain one reusable launcher node.")
			_assert_true(builder.goal == builder.goals[0], "Relay must begin on its first ordered goal.")
			var first_anchor := builder.launcher.position
			var completed_goal_center := builder.goals[0].position
			_assert_true(builder.activate_leg(1), "Relay must activate its authored second leg.")
			_assert_true(builder.goal == builder.goals[1], "Relay activation must expose the second goal.")
			_assert_true(not builder.launcher.position.is_equal_approx(first_anchor), "Relay activation must relocate the reusable launcher.")
			_assert_true(
				Vector2(builder.launcher.position.x, builder.launcher.position.z).is_equal_approx(
					Vector2(completed_goal_center.x, completed_goal_center.z)
				),
				"Relay activation must center the reusable launcher in the completed goal."
			)
			_assert_true(builder.get_node_or_null("Launcher") == builder.launcher, "Relay activation must not spawn a second launcher.")
			_assert_true(builder.activate_leg(0), "Relay builder must return to the first leg for the next build.")
	print("Cannon Golf course-build contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
