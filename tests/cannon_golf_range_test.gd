extends SceneTree


func _initialize() -> void:
	for course in CannonGolfCourseCatalog.all_courses():
		var generated: Variant = CannonGolfCourseTerrainFactory.build(course)
		if course.has_explicit_legs():
			var relay := generated as CannonGolfGeneratedCourse
			_assert_true(relay != null and relay.union_range_metrics.size() > 0, "Relay must provide union admission metrics.")
			for point in relay.admission_points:
				if CannonGolfCourseTerrainFactory._is_relay_launch_exclusion(point, relay.legs):
					continue
				var admitted := false
				for leg in relay.legs:
					var admission := CannonGolfBallistics.admit_world_point(point, leg.launcher_position, leg.shot_axis_yaw_degrees)
					admitted = admitted or bool(admission.passed)
				_assert_true(admitted, "Every relay terrain point must be admitted by at least one leg.")
			continue
		var layout := generated.layout as GeneratedStageLayout
		_assert_true(
			layout.local_bounds.size.is_equal_approx(Vector2(210.0, 120.0)),
			"%s must retain the original 210 x 120 metre mountain extent." % course.course_id
		)
		var cannon_position: Vector3 = generated.cannon_position
		var goal_position: Vector3 = generated.goal_position
		_assert_true(
			Vector2(cannon_position.x, cannon_position.z).distance_to(
				Vector2(goal_position.x, goal_position.z)
			) >= 140.0,
			"%s cannon-to-goal distance must express the large course." % course.course_id
		)
		var metrics: Dictionary = generated.range_metrics
		_assert_true(float(metrics.farthest_distance) >= 175.0, "%s far terrain must be at least 175 metres away." % course.course_id)
		_assert_true(float(metrics.minimum_range_margin) >= 8.0, "%s range margin failed." % course.course_id)
		_assert_true(float(metrics.minimum_yaw_margin_degrees) >= 8.0, "%s yaw margin failed." % course.course_id)
		_assert_true(
			float(metrics.minimum_height_margin) >= CannonGolfBallistics.REQUIRED_HEIGHT_MARGIN,
			"%s height margin failed." % course.course_id
		)
		for point in generated.admission_points as PackedVector3Array:
			var admission := CannonGolfBallistics.admit_world_point(
				point, cannon_position, float(generated.shot_axis_yaw_degrees)
			)
			_assert_true(bool(admission.passed), "%s terrain point escaped the admitted launch envelope." % course.course_id)
	print("Cannon Golf whole-terrain launch-envelope contract passed for all courses.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
