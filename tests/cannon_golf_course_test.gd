extends SceneTree


func _initialize() -> void:
	var courses := CannonGolfCourseCatalog.all_courses()
	_assert_true(courses.size() == 2, "The prototype must ship exactly two courses.")
	var ids: Array[StringName] = []
	for course in courses:
		_assert_true(course != null and course.is_valid(), "Every shipped course must be valid.")
		_assert_true(not ids.has(course.course_id), "Course identifiers must be unique.")
		ids.append(course.course_id)
		_assert_true(
			course.generation_profile != null and course.generation_profile.is_valid(),
			"Each course needs a valid Paint Mountain generation profile."
		)
		_assert_true(
			course.default_elevation_degrees != course.solution_elevation_degrees \
					and course.default_power_percent != course.solution_power_percent,
			"Default setup must not reveal the certified solution."
		)
		_assert_true(course.play_bounds.has_point(course.cannon_position), "Cannon must be in play bounds.")
		_assert_true(course.play_bounds.has_point(course.goal_position), "Goal must be in play bounds.")
		var solution := course.direct_solution()
		_assert_true(solution.x >= 10.0 and solution.x <= 68.0, "Solution elevation must be legal.")
		_assert_true(solution.y >= 10.0 and solution.y <= 100.0, "Solution power must be legal.")
	_assert_true(ids.has(&"first_ridge") and ids.has(&"rising_bend"), "Both course IDs must be present.")
	print("Cannon Golf course contract passed for %d courses." % courses.size())
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
