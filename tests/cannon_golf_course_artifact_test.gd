extends SceneTree


func _initialize() -> void:
	var payloads: Dictionary = {}
	for course in CannonGolfCourseCatalog.all_courses():
		var path := CannonGolfCourseCatalog.prepared_path_for(course)
		var prepared := ResourceLoader.load(path) as CannonGolfPreparedCourse
		_assert_true(prepared != null and prepared.is_valid_for(course), "Prepared course must match authored identity: %s." % course.course_id)
		_assert_true(
			prepared.has_complete_construction_for(course),
			"Trajectory-built artifacts must retain their construction contract."
		)
		_assert_true(
			not prepared.has_any_certificate_data(),
			"Trajectory construction must not be presented as a physics certificate."
		)
		_assert_true(not payloads.has(prepared.payload_sha256), "Every prepared course needs a distinct semantic payload.")
		payloads[prepared.payload_sha256] = true
		_assert_true(prepared.legs.size() == course.leg_count(), "Prepared artifact must retain every authored goal.")
		_assert_true(prepared.render_mesh != null and prepared.top_shape != null and prepared.skirt_shape != null, "Prepared artifact must retain render and collision resources.")
		for leg in prepared.legs:
			_assert_true(
				absf(prepared.height_at_local(leg.goal_position.x, leg.goal_position.z) - leg.goal_position.y) <= 0.08,
				"Prepared sampled surface must reproduce each goal center."
			)
		var stale_course := course.duplicate(true) as CannonGolfCourseData
		stale_course.terrain_seed_window.x += 1
		_assert_true(not prepared.is_valid_for(stale_course), "A stale authored identity must fail closed.")
		var malformed := prepared.duplicate(true) as CannonGolfPreparedCourse
		malformed.heights = malformed.heights.duplicate()
		malformed.heights[0] += 1.0
		_assert_true(not malformed.is_valid(), "A mutated payload must fail SHA-256 validation.")
		var certificate_mutation := prepared.duplicate(true) as CannonGolfPreparedCourse
		certificate_mutation.resolved_plan_sha256 = "tampered"
		certificate_mutation.legs[0].default_attempt_count = 1
		_assert_true(not certificate_mutation.is_valid(), "Partial certificate metadata must fail closed.")
	print("Cannon Golf prepared artifact identity and payload contract passed for ten courses.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
