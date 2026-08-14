extends SceneTree


func _initialize() -> void:
	var courses := CannonGolfCourseCatalog.all_courses()
	var expected_ids: Array[StringName] = [&"first_ridge", &"rising_bend", &"summit_saddle", &"deep_relay", &"linked_bowls", &"terraced_peak", &"u_valley", &"twin_peaks", &"basin_garden", &"alpine_complex"]
	var expected_counts := [1, 1, 2, 2, 3, 3, 4, 4, 5, 6]
	var expected_bands := [[0], [2], [2, 0], [0, 2], [2, 0, 1], [0, 2, 0], [2, 0, 2, 1], [0, 1, 0, 2], [2, 0, 1, 2, 0], [0, 2, 1, 2, 0, 2]]
	var expected_seed_centers := [1347223552, 1347223552, 1764827014, 1764827013, 1764827015, 1764827016, 1764827017, 1764827018, 1764827019, 1764827020]
	var expected_role_families := [&"first_ridge", &"rising_bend", &"summit_saddle", &"deep_relay", &"linked_bowls", &"terraced_peak", &"u_valley", &"twin_peaks", &"basin_garden", &"alpine_complex"]
	var expected_radius_ranges := [Vector2(12, 14), Vector2(12, 14), Vector2(10, 12), Vector2(10, 12), Vector2(8, 10), Vector2(8, 10), Vector2(8, 10), Vector2(8, 10), Vector2(8, 10), Vector2(8, 10)]
	_assert_true(courses.size() == 10, "Catalog must expose exactly ten courses.")
	for index in range(courses.size()):
		var course := courses[index]
		_assert_true(course != null and course.is_valid(), "Every catalog course must be valid.")
		_assert_true(course.course_id == expected_ids[index], "Catalog order must match the approved matrix.")
		_assert_true(course.leg_count() == expected_counts[index], "Course goal counts must match the approved matrix.")
		_assert_true(CannonGolfCourseCatalog.index_of(course.course_id) == index, "Catalog indexes must be stable.")
		_assert_true(CannonGolfCourseCatalog.prepared_path_for(course) == "res://resources/cannon_golf/prepared/%s.res" % course.course_id, "Prepared path must be canonical.")
		_assert_true(course.authoring_mode == CannonGolfCourseData.AUTHORING_CONSTRAINT_RECIPE, "Catalog courses must use constraint recipe authoring.")
		_assert_true(course.terrain_seed_window == Vector2i(expected_seed_centers[index] - 2, expected_seed_centers[index] + 2), "Recipe seed windows must stay within the retained seed plus or minus two.")
		_assert_true(course.cannon_position == Vector3.ZERO and course.goal_position == Vector3.ZERO, "Recipes must not serialize resolved launcher or goal positions.")
		_assert_true(Vector3(course.solution_horizontal_aim, course.solution_elevation_degrees, course.solution_power_percent) == Vector3(50, 50, 50), "Recipes must not serialize a legacy solution witness.")
		var roles: Dictionary = {}
		var previous_route_min := course.cannon_route_t
		for leg_index in range(course.leg_count()):
			var leg := course.leg_at(leg_index)
			_assert_true(leg != null and leg.is_valid_recipe() and leg.default_setup() == Vector3(50, 50, 50), "Every leg must have a valid recipe and neutral default setup.")
			_assert_true(leg.relative_rim_band == expected_bands[index][leg_index], "Recipe rim bands must match the approved sequence.")
			_assert_true(leg.route_interval.y <= previous_route_min - 0.02, "Recipe route intervals must preserve the ordered checkpoint gap.")
			var expected_lateral_range := Vector2(-7.5, 7.5) if course.course_id == &"deep_relay" else Vector2(-7, 7)
			_assert_true(leg.lateral_offset_range == expected_lateral_range, "Recipe lateral offset ranges must match the approved profile.")
			_assert_true(leg.bowl_radius_range == expected_radius_ranges[index] and leg.bowl_recess_depth_range == Vector2(3.5, 4.5) and leg.bowl_lip_height_range == Vector2(1.5, 2.5), "Recipe bowl dimensions must match the difficulty band and retain a raised wall above one ball diameter.")
			_assert_true(leg.goal_placement_offset == Vector2.ZERO and leg.direct_solution() == Vector3(50, 50, 50), "Recipes must not retain legacy placement or solution values.")
			_assert_true(leg.semantic_role.begins_with(expected_role_families[index]) and not roles.has(leg.semantic_role), "Recipe semantic roles must be unique and use the approved family.")
			roles[leg.semantic_role] = true
			previous_route_min = leg.route_interval.x
	_assert_true(CannonGolfCourseCatalog.index_of(&"missing") == -1, "Unknown course IDs must not resolve.")
	print("Cannon Golf ten-course catalog contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
