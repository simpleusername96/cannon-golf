extends SceneTree

const GENERATOR := preload("res://src/cannon_golf/trajectory_course_generator.gd")
const ROUTE_MOTIFS := preload("res://src/cannon_golf/course_route_motifs.gd")
const MINIMUM_LAUNCHER_TO_GOAL_SPACING := 100.0

var _failed := false


func _initialize() -> void:
	var route_signatures: Dictionary = {}
	var macro_names: Dictionary = {}
	var macro_signatures: Dictionary = {}
	var prepared_route_signatures: Dictionary = {}
	var prepared_shape_signatures: Dictionary = {}
	var courses := CannonGolfCourseCatalog.all_courses()
	for course_index in range(courses.size()):
		var course: CannonGolfCourseData = courses[course_index]
		_assert_true(
			ROUTE_MOTIFS.has_station_count(course_index, course.leg_count()),
			"%s route motif must own one launcher station and every goal station." % course.course_id
		)
		var local_bounds := _local_bounds_for(course)
		var plan := GENERATOR._plan_legs(course, course_index, local_bounds)
		_assert_true(
			plan.size() == course.leg_count(),
			"%s route motif must retain a constructible setup for every leg." % course.course_id
		)
		if plan.size() != course.leg_count():
			continue
		_assert_route_uses_authored_depths(plan, course, local_bounds)
		for leg_data in plan:
			_assert_true(
				float(leg_data.distance) >= MINIMUM_LAUNCHER_TO_GOAL_SPACING,
				"%s must keep every launcher-to-goal leg at least %.0f m apart." % [
					course.course_id, MINIMUM_LAUNCHER_TO_GOAL_SPACING,
				]
			)
		_assert_true(
			not _uses_legacy_mirrored_route(plan, local_bounds.get_center().x),
			"%s must not retain the catalog-wide mirrored zigzag." % course.course_id
		)
		var route_signature := _planned_route_signature(plan, local_bounds)
		_assert_unique(route_signatures, route_signature, course.course_id, "planned route")

		var macro_name := ROUTE_MOTIFS.macro_profile_name(course_index)
		_assert_true(not macro_name.is_empty(), "%s must own a named macro profile." % course.course_id)
		_assert_unique(macro_names, String(macro_name), course.course_id, "macro profile")
		var macro_signature := _generator_macro_signature(course_index)
		_assert_unique(macro_signatures, macro_signature, course.course_id, "macro height profile")

		var prepared := ResourceLoader.load(CannonGolfCourseCatalog.prepared_path_for(course)) \
				as CannonGolfPreparedCourse
		_assert_true(
			prepared != null and prepared.is_valid_for(course),
			"%s must retain a current prepared artifact." % course.course_id
		)
		if prepared == null or not prepared.is_valid_for(course):
			continue
		var prepared_algorithm_version := int(
			prepared.union_range_metrics.get("algorithm_version", -1)
		)
		_assert_true(
			prepared_algorithm_version == GENERATOR.ALGORITHM_VERSION,
			"%s prepared artifact algorithm version %d must match generator version %d." % [
				course.course_id, prepared_algorithm_version, GENERATOR.ALGORITHM_VERSION,
			]
		)
		_assert_true(
			_prepared_matches_plan(prepared, plan),
			"%s prepared route must match the current deterministic motif." % course.course_id
		)
		_assert_unique(
			prepared_route_signatures,
			_prepared_route_signature(prepared),
			course.course_id,
			"prepared route"
		)
		_assert_unique(
			prepared_shape_signatures,
			_prepared_shape_signature(prepared),
			course.course_id,
			"prepared macro shape"
		)
	print("Cannon Golf route and macro terrain variety contracts passed for fifteen courses.")
	quit(1 if _failed else 0)


func _local_bounds_for(course: CannonGolfCourseData) -> Rect2:
	var source := course.generation_profile.generation_contract.local_bounds
	return Rect2(
		source.position * course.terrain_horizontal_scale \
				+ Vector2(course.terrain_origin.x, course.terrain_origin.z),
		source.size * course.terrain_horizontal_scale
	)


func _assert_route_uses_authored_depths(
		plan: Array[Dictionary], course: CannonGolfCourseData, local_bounds: Rect2
) -> void:
	for leg_index in range(plan.size()):
		var interval := course.leg_at(leg_index).route_interval
		var route_t := inverse_lerp(
			local_bounds.position.y, local_bounds.end.y, float(plan[leg_index].goal.z)
		)
		_assert_true(
			route_t >= interval.x - 0.0001 and route_t <= interval.y + 0.0001,
			"%s leg %d must use its authored route interval." % [course.course_id, leg_index]
		)


func _uses_legacy_mirrored_route(plan: Array[Dictionary], center_x: float) -> bool:
	for leg_data in plan:
		var launcher_offset := float(leg_data.launcher.x) - center_x
		var goal_offset := float(leg_data.goal.x) - center_x
		if absf(launcher_offset + goal_offset) > 0.01:
			return false
	return true


func _planned_route_signature(plan: Array[Dictionary], bounds: Rect2) -> String:
	var offsets := PackedFloat32Array()
	var depths := PackedFloat32Array()
	offsets.append(float(plan[0].launcher.x) - bounds.get_center().x)
	depths.append(inverse_lerp(bounds.position.y, bounds.end.y, float(plan[0].launcher.z)))
	for leg_data in plan:
		offsets.append(float(leg_data.goal.x) - bounds.get_center().x)
		depths.append(inverse_lerp(bounds.position.y, bounds.end.y, float(leg_data.goal.z)))
	return _canonical_route_signature(offsets, depths)


func _prepared_route_signature(prepared: CannonGolfPreparedCourse) -> String:
	var offsets := PackedFloat32Array()
	var depths := PackedFloat32Array()
	offsets.append(prepared.legs[0].launcher_position.x - prepared.local_bounds.get_center().x)
	depths.append(inverse_lerp(
		prepared.local_bounds.position.y,
		prepared.local_bounds.end.y,
		prepared.legs[0].launcher_position.z
	))
	for leg in prepared.legs:
		offsets.append(leg.goal_position.x - prepared.local_bounds.get_center().x)
		depths.append(inverse_lerp(
			prepared.local_bounds.position.y, prepared.local_bounds.end.y, leg.goal_position.z
		))
	return _canonical_route_signature(offsets, depths)


func _canonical_route_signature(
		offsets: PackedFloat32Array, depths: PackedFloat32Array
) -> String:
	var maximum := 0.001
	for offset in offsets:
		maximum = maxf(maximum, absf(offset))
	var direct := PackedStringArray()
	var reflected := PackedStringArray()
	for index in range(offsets.size()):
		var normalized_lateral := roundi(offsets[index] / maximum * 100.0)
		var normalized_depth := roundi(depths[index] * 100.0)
		direct.append("%d:%d" % [normalized_lateral, normalized_depth])
		reflected.append("%d:%d" % [-normalized_lateral, normalized_depth])
	var direct_key := ",".join(direct)
	var reflected_key := ",".join(reflected)
	return direct_key if direct_key < reflected_key else reflected_key


func _generator_macro_signature(course_index: int) -> String:
	var canonical_bounds := Rect2(-105.0, -160.0, 210.0, 320.0)
	var samples := PackedStringArray()
	for z_fraction in [0.15, 0.35, 0.55, 0.75, 0.90]:
		for x_fraction in [0.15, 0.35, 0.50, 0.65, 0.85]:
			var point := Vector2(
				lerpf(canonical_bounds.position.x, canonical_bounds.end.x, x_fraction),
				lerpf(canonical_bounds.position.y, canonical_bounds.end.y, z_fraction)
			)
			samples.append(str(roundi(GENERATOR._natural_height(
				course_index, 0, point, canonical_bounds
			) * 4.0)))
	return ",".join(samples)


func _prepared_shape_signature(prepared: CannonGolfPreparedCourse) -> String:
	var blocks: Array = []
	for _block_index in range(12):
		blocks.append([])
	var sample_width := prepared.cell_count.x + 1
	var sample_height := prepared.cell_count.y + 1
	for z_index in range(sample_height):
		var block_z := mini(floori(float(z_index) * 4.0 / float(sample_height)), 3)
		for x_index in range(sample_width):
			var block_x := mini(floori(float(x_index) * 3.0 / float(sample_width)), 2)
			blocks[block_z * 3 + block_x].append(
				prepared.heights[z_index * sample_width + x_index]
			)
	var medians := PackedFloat32Array()
	for block in blocks:
		block.sort()
		medians.append(float(block[block.size() / 2]))
	var ranked := range(medians.size())
	ranked.sort_custom(func(left: int, right: int) -> bool:
		if is_equal_approx(medians[left], medians[right]):
			return left < right
		return medians[left] > medians[right]
	)
	var signature := PackedStringArray()
	for block_index in ranked:
		signature.append(str(block_index))
	var minimum_median := INF
	var maximum_median := -INF
	for median in medians:
		minimum_median = minf(minimum_median, median)
		maximum_median = maxf(maximum_median, median)
	var median_span := maxf(maximum_median - minimum_median, 0.001)
	var normalized_levels := PackedStringArray()
	for median in medians:
		# Five-percent bins retain broad relative height, without depending on
		# absolute course relief or serialized payload bytes.
		normalized_levels.append(str(roundi((median - minimum_median) / median_span * 20.0)))
	return "%s|%s" % [",".join(signature), ",".join(normalized_levels)]


func _prepared_matches_plan(
		prepared: CannonGolfPreparedCourse, plan: Array[Dictionary]
) -> bool:
	if prepared.legs.size() != plan.size():
		return false
	for leg_index in range(plan.size()):
		var leg := prepared.legs[leg_index]
		var planned := plan[leg_index]
		if not leg.launcher_position.is_equal_approx(planned.launcher) \
				or not leg.goal_position.is_equal_approx(planned.goal) \
				or not is_equal_approx(leg.goal_radius, float(planned.goal_radius)) \
				or not is_equal_approx(leg.goal_rim_y, float(planned.rim_y)) \
				or not is_equal_approx(leg.goal_lip_y, float(planned.lip_y)) \
				or leg.rim_elevation_band != int(planned.rim_band) \
				or not is_equal_approx(leg.shot_axis_yaw_degrees, float(planned.yaw)) \
				or not leg.intended_setup.is_equal_approx(planned.setup):
			return false
	return true


func _assert_unique(
		owners: Dictionary,
		signature: String,
		course_id: StringName,
		label: String
) -> void:
	_assert_true(
		not owners.has(signature),
		"%s %s duplicates %s." % [course_id, label, owners.get(signature, &"unknown")]
	)
	owners[signature] = course_id


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
