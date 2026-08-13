extends SceneTree


func _initialize() -> void:
	var courses := CannonGolfCourseCatalog.all_courses()
	_assert_true(courses.size() == 3, "The prototype must ship the two legacy courses and deep relay.")
	var ids: Array[StringName] = []
	for course in courses:
		_assert_true(course != null and course.is_valid(), "Every shipped course must be valid.")
		_assert_true(not ids.has(course.course_id), "Course identifiers must be unique.")
		ids.append(course.course_id)
		_assert_true(
			course.generation_profile != null and course.generation_profile.is_valid(),
			"Each course needs a valid Paint Mountain generation profile."
		)
		var expected_leg_count := 2 if course.course_id == &"deep_relay" else 1
		_assert_true(course.leg_count() == expected_leg_count, "Course leg normalization must match authored data.")
		for leg_index in range(course.leg_count()):
			var leg := course.leg_at(leg_index)
			_assert_true(leg != null and leg.is_valid(), "Every normalized leg must be valid.")
			_assert_true(leg.default_setup() == Vector3(50.0, 50.0, 50.0), "Every leg starts at 50 / 50 / 50.")
			var solution := course.solution_for_leg(leg_index)
			_assert_true(solution.x >= 0.0 and solution.x <= 100.0, "Solution horizontal aim must be legal.")
			_assert_true(solution.y >= 10.0 and solution.y <= 68.0, "Solution elevation must be legal.")
			_assert_true(solution.z >= 10.0 and solution.z <= 100.0, "Solution power must be legal.")
		if not course.has_explicit_legs():
			_assert_true(course.play_bounds.has_point(course.cannon_position), "Legacy cannon must be in play bounds.")
			_assert_true(course.play_bounds.has_point(course.goal_position), "Legacy goal must be in play bounds.")
	_assert_true(
		ids == [&"first_ridge", &"rising_bend", &"deep_relay"],
		"Catalog order must preserve the legacy courses and append deep relay."
	)
	var relay := CannonGolfCourseCatalog.course_at(2)
	_assert_true(relay.terrain_vertical_scale == 1.35, "Deep relay must use the locked vertical scale.")
	_assert_true(relay.generation_profile.generation_contract is CannonGolfLongitudinalGenerationContract, "Deep relay must isolate its longitudinal contract.")
	print("Cannon Golf course contract passed for %d courses." % courses.size())
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
