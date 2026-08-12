extends SceneTree


func _initialize() -> void:
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	for course in CannonGolfCourseCatalog.all_courses():
		builder.build(course)
		_assert_true(builder.course != course and builder.course.course_id == course.course_id, "Builder must isolate runtime course data while retaining course identity.")
		_assert_true(builder.launcher != null, "Built course must contain one launcher.")
		_assert_true(builder.goal != null, "Built course must contain one settlement goal.")
		_assert_true(builder.terrain_body_count() == 1, "A course must expose one connected terrain body.")
		_assert_true(builder.terrain_body != null, "Built course must retain the terrain body.")
		_assert_true(builder.terrain_body.is_in_group(&"impact_mark_surface"), "Terrain body must stamp impact history.")
		_assert_true(builder.terrain_layout != null and builder.terrain_layout.is_valid(), "Built course must retain generated topology.")
		_assert_true(builder.goal.find_children("*", "StaticBody3D", true, false).is_empty(), "Goal visuals must not own collision.")
		_assert_true(builder.get_node_or_null("Mechanisms") == null, "Fresh courses must not contain devices.")
	print("Cannon Golf course-build contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
