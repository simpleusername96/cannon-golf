extends SceneTree


func _initialize() -> void:
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	for course in CannonGolfCourseCatalog.all_courses():
		builder.build(course)
		_assert_true(builder.course == course, "Builder must retain selected course identity.")
		_assert_true(builder.launcher != null, "Built course must contain one launcher.")
		_assert_true(builder.goal != null, "Built course must contain one settlement goal.")
		_assert_true(builder.terrain_body_count() == course.block_centers.size(), "Every terrain block needs collision.")
		_assert_true(builder.get_node_or_null("Mechanisms") == null, "Fresh courses must not contain devices.")
	print("Cannon Golf course-build contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
