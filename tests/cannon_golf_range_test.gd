extends SceneTree


func _initialize() -> void:
	for course in CannonGolfCourseCatalog.all_courses():
		var prepared := ResourceLoader.load(CannonGolfCourseCatalog.prepared_path_for(course)) \
			as CannonGolfPreparedCourse
		_assert_true(
			prepared != null and prepared.is_valid_for(course),
			"%s must load an identity-checked prepared course." % course.course_id
		)
		if prepared == null or not prepared.is_valid_for(course):
			continue
		_assert_whole_terrain_admission(prepared, course)
		_assert_leg_corridor_admission(prepared, course)
	print("Cannon Golf whole-terrain launch-envelope contract passed for all prepared courses.")
	quit(0)


func _assert_whole_terrain_admission(
		prepared: CannonGolfPreparedCourse, course: CannonGolfCourseData
) -> void:
	var metrics := prepared.union_range_metrics
	_assert_true(not metrics.is_empty(), "%s must retain whole-terrain admission metrics." % course.course_id)
	_assert_true(float(metrics.get("minimum_range_margin", -INF)) >= 8.0, "%s range margin failed." % course.course_id)
	_assert_true(float(metrics.get("minimum_yaw_margin_degrees", -INF)) >= 8.0, "%s yaw margin failed." % course.course_id)
	_assert_true(
		float(metrics.get("minimum_height_margin", -INF)) \
				>= CannonGolfCourseTerrainFactory.RELAY_CENTERED_UNION_HEIGHT_MARGIN,
		"%s whole terrain must remain inside at least one reachable height interval." % course.course_id
	)
	var topology := TerrainTopTopology.build(
		prepared.cell_count, prepared.local_bounds, prepared.heights, prepared.footprint
	)
	_assert_true(topology != null and topology.is_valid(), "%s prepared terrain topology must reconstruct." % course.course_id)
	if topology == null:
		return
	var admitted_points := CannonGolfCourseTerrainFactory._terrain_admission_points(topology)
	_assert_true(
		int(metrics.get("point_count", -1)) == admitted_points.size(),
		"%s whole-terrain metrics must account for every visible terrain point." % course.course_id
	)
	_assert_true(
		int(metrics.get("admitted_point_count", -1)) \
				+ int(metrics.get("excluded_point_count", -1)) \
				+ int(metrics.get("unadmitted_point_count", -1)) == admitted_points.size(),
		"%s diagnostic admission buckets must cover every visible terrain point." % course.course_id
	)


func _generated_legs(prepared: CannonGolfPreparedCourse) -> Array[CannonGolfGeneratedCourseLeg]:
	var result: Array[CannonGolfGeneratedCourseLeg] = []
	for source in prepared.legs:
		var leg := CannonGolfGeneratedCourseLeg.new()
		leg.goal_position = source.goal_position
		leg.goal_rim_y = source.goal_rim_y
		leg.goal_lip_y = source.goal_lip_y
		leg.launcher_position = source.launcher_position
		leg.shot_axis_yaw_degrees = source.shot_axis_yaw_degrees
		leg.frame_bounds = source.frame_bounds
		leg.corridor_admission = source.corridor_admission
		result.append(leg)
	return result


func _assert_leg_corridor_admission(
		prepared: CannonGolfPreparedCourse, course: CannonGolfCourseData
) -> void:
	for leg in prepared.legs:
		var metrics := leg.corridor_admission
		_assert_true(not metrics.is_empty(), "%s every leg needs corridor admission metrics." % course.course_id)
		_assert_true(float(metrics.get("point_count", 0)) > 0, "%s corridor must contain sampled terrain." % course.course_id)
		_assert_true(float(metrics.get("minimum_range_margin", -INF)) >= 8.0, "%s corridor range margin failed." % course.course_id)
		_assert_true(float(metrics.get("minimum_yaw_margin_degrees", -INF)) >= 8.0, "%s corridor yaw margin failed." % course.course_id)
		_assert_true(
			float(metrics.get("minimum_height_margin", -INF)) >= CannonGolfBallistics.REQUIRED_HEIGHT_MARGIN,
			"%s corridor height margin %.3f is below %.3f." % [
				course.course_id,
				float(metrics.get("minimum_height_margin", -INF)),
				CannonGolfBallistics.REQUIRED_HEIGHT_MARGIN,
			]
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
