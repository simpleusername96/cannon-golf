extends SceneTree

var _failed := false


func _initialize() -> void:
	_assert_explicit_sample_rejection()
	var payloads: Dictionary = {}
	for course in CannonGolfCourseCatalog.all_courses():
		var prepared := _prepared_for(course)
		_assert_true(prepared != null, "%s must have a valid prepared course." % course.course_id)
		if prepared == null:
			continue
		_assert_true(not payloads.has(prepared.payload_sha256), "Prepared terrain payloads must be distinct.")
		payloads[prepared.payload_sha256] = true
		_assert_prepared_terrain(prepared, course)
	print("Cannon Golf prepared terrain contracts passed for ten courses.")
	quit(1 if _failed else 0)


func _prepared_for(course: CannonGolfCourseData) -> CannonGolfPreparedCourse:
	var prepared := ResourceLoader.load(CannonGolfCourseCatalog.prepared_path_for(course)) \
			as CannonGolfPreparedCourse
	return prepared if prepared != null and prepared.is_valid_for(course) else null


func _assert_explicit_sample_rejection() -> void:
	var relay := CannonGolfCourseCatalog.course_at(CannonGolfCourseCatalog.index_of(&"deep_relay"))
	var contract := relay.generation_profile.generation_contract
	var heights := PackedFloat32Array()
	heights.resize((contract.cell_count.x + 1) * (contract.cell_count.y + 1))
	heights.fill(0.0)
	heights[0] = NAN
	var footprint := PackedByteArray()
	footprint.resize(contract.cell_count.x * contract.cell_count.y)
	footprint[0] = 1
	_assert_true(
		not CannonGolfCourseTerrainFactory._generated_samples_are_valid(
			{"heights": heights, "footprint": footprint}, contract
		),
		"Prepared-course materialization must reject non-finite synthesized terrain samples."
	)
	_assert_true(
		not CannonGolfCourseTerrainFactory._generated_samples_are_valid(
			{"heights": PackedFloat32Array(), "footprint": PackedByteArray()}, contract
		),
		"Prepared-course materialization must reject malformed synthesized terrain samples."
	)


func _assert_prepared_terrain(
		prepared: CannonGolfPreparedCourse, course: CannonGolfCourseData
) -> void:
	var contract := course.generation_profile.generation_contract
	var expected_bounds := Rect2(
		contract.local_bounds.position * course.terrain_horizontal_scale \
				+ Vector2(course.terrain_origin.x, course.terrain_origin.z),
		contract.local_bounds.size * course.terrain_horizontal_scale
	)
	_assert_true(prepared.cell_count == contract.cell_count, "Prepared terrain must preserve its authored grid.")
	_assert_true(prepared.local_bounds == expected_bounds, "Prepared terrain must preserve its authored extent.")
	_assert_true(
		prepared.top_triangle_count <= contract.maximum_top_triangle_count,
		"Prepared terrain must remain inside the top-triangle budget."
	)
	_assert_true(
		prepared.render_mesh.get_surface_count() == 1 and prepared.top_shape is ConcavePolygonShape3D \
				and prepared.skirt_shape is ConcavePolygonShape3D,
		"Prepared terrain must retain one render surface and triangle collision."
	)
	_assert_prepared_material(prepared, course)
	for leg_index in range(prepared.legs.size()):
		_assert_goal_basin(prepared, prepared.legs[leg_index], course.leg_at(leg_index))
	_assert_rim_bands(prepared)
	if course.course_id == &"deep_relay":
		_assert_true(prepared.relief() >= 80.0, "Deep Relay must retain at least 80m relief.")
		for leg in prepared.legs:
			_assert_true(
				leg.goal_rim_y - leg.launcher_position.y >= 25.0,
				"Every Deep Relay goal rim must rise at least 25m from its launcher."
			)
	if CannonGolfCourseCatalog.index_of(course.course_id) >= 4:
		_assert_true(prepared.relief() >= 80.0, "Late-course playable terrain must have at least 80m relief.")
	if prepared.legs.size() > 1:
		_assert_relay_launchers(prepared)
		_assert_true(
			int(prepared.union_range_metrics.get("excluded_point_count", 0)) > 0,
			"A relay must exclude its centered launch footprints from whole-terrain admission."
		)
	_assert_true(not prepared.union_range_metrics.is_empty(), "Prepared terrain must retain union admission metrics.")
	_assert_true(
		prepared.landform_metrics.size() == course.landform_features.size(),
		"Every authored semantic landform must retain a measured result."
	)
	if course.course_id != &"deep_relay" and prepared.legs.size() >= 3:
		var has_descending_leg := false
		for leg in prepared.legs:
			if leg.goal_rim_y < leg.launcher_position.y:
				has_descending_leg = true
				break
		_assert_true(
			has_descending_leg,
			"A multi-goal course must retain a descending leg instead of becoming monotonic."
		)


func _assert_prepared_material(
		prepared: CannonGolfPreparedCourse, course: CannonGolfCourseData
) -> void:
	var material := prepared.render_mesh.surface_get_material(0) as ShaderMaterial
	_assert_true(material != null, "Prepared terrain must retain a shader material.")
	if material == null:
		return
	_assert_true(
		material.get_shader_parameter(&"rock_color") == course.terrain_color,
		"Prepared terrain rock color must match its course palette."
	)
	_assert_true(
		material.get_shader_parameter(&"accent_color") == course.terrain_accent_color,
		"Prepared terrain accent color must match its course palette."
	)


func _assert_rim_bands(prepared: CannonGolfPreparedCourse) -> void:
	for left_index in range(prepared.legs.size()):
		for right_index in range(left_index + 1, prepared.legs.size()):
			var left := prepared.legs[left_index]
			var right := prepared.legs[right_index]
			if left.rim_elevation_band < right.rim_elevation_band:
				_assert_true(
					right.goal_rim_y - left.goal_rim_y >= 12.0,
					"Higher authored rim bands must be at least 12m above lower bands."
				)
			elif left.rim_elevation_band > right.rim_elevation_band:
				_assert_true(
					left.goal_rim_y - right.goal_rim_y >= 12.0,
					"Higher authored rim bands must be at least 12m above lower bands."
				)


func _assert_goal_basin(
		prepared: CannonGolfPreparedCourse,
		leg: CannonGolfPreparedCourseLeg,
		authored_leg: CannonGolfCourseLegData
) -> void:
	_assert_true(
		absf(prepared.height_at_local(leg.goal_position.x, leg.goal_position.z) - leg.goal_position.y) <= 0.08,
		"Prepared sampled surface must reproduce the sealed goal center."
	)
	_assert_true(
		leg.goal_radius >= authored_leg.bowl_radius_range.x and leg.goal_radius <= authored_leg.bowl_radius_range.y,
		"Prepared goal radius must stay inside the authored recipe range."
	)
	_assert_true(
		leg.goal_lip_y - leg.goal_position.y >= authored_leg.bowl_recess_depth_range.x \
				+ authored_leg.bowl_lip_height_range.x - 0.35,
		"Prepared goal center must remain substantially below its sealed retaining lip."
	)
	var nearest_sample_height := INF
	var samples_inside := 0
	for z_index in range(prepared.cell_count.y + 1):
		var z := lerpf(prepared.local_bounds.position.y, prepared.local_bounds.end.y, float(z_index) / prepared.cell_count.y)
		for x_index in range(prepared.cell_count.x + 1):
			var x := lerpf(prepared.local_bounds.position.x, prepared.local_bounds.end.x, float(x_index) / prepared.cell_count.x)
			if Vector2(x, z).distance_to(Vector2(leg.goal_position.x, leg.goal_position.z)) > leg.goal_radius:
				continue
			var height := prepared.heights[z_index * (prepared.cell_count.x + 1) + x_index]
			nearest_sample_height = minf(nearest_sample_height, height)
			samples_inside += 1
			_assert_true(height <= leg.goal_lip_y + 0.001, "Goal basin samples must stay at or below the retaining lip.")
	_assert_true(samples_inside >= 8, "Goal basin must contain enough sampled terrain.")
	_assert_true(
		leg.goal_position.y <= nearest_sample_height + 0.3,
		"Goal center must remain the lowest stable region of its basin."
	)


func _assert_relay_launchers(prepared: CannonGolfPreparedCourse) -> void:
	for index in range(1, prepared.legs.size()):
		var previous_goal := prepared.legs[index - 1].goal_position
		var launcher := prepared.legs[index].launcher_position
		_assert_true(
			Vector2(launcher.x, launcher.z).is_equal_approx(Vector2(previous_goal.x, previous_goal.z)) \
					and is_equal_approx(launcher.y, previous_goal.y + CannonGolfCourseTerrainFactory.RELAY_LAUNCH_SURFACE_OFFSET),
			"Each later relay launcher must sit at the exact prior-goal center."
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
