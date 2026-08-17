extends SceneTree

const FAST_GENERATOR := preload("res://src/cannon_golf/trajectory_course_generator.gd")

var _failed := false


func _initialize() -> void:
	_assert_explicit_sample_rejection()
	var payloads: Dictionary = {}
	var expected_horizontal_scales := [
		1.50, 1.50, 1.58, 1.65, 1.73, 1.80, 1.92, 2.03, 2.13, 2.25,
		2.30, 2.35, 2.40, 2.45, 2.50,
	]
	var courses := CannonGolfCourseCatalog.all_courses()
	for course_index in range(courses.size()):
		var course := courses[course_index]
		_assert_true(
			is_equal_approx(course.terrain_horizontal_scale, expected_horizontal_scales[course_index]),
			"Course horizontal scales must retain the accepted gentler progression."
		)
		var prepared := _prepared_for(course)
		_assert_true(prepared != null, "%s must have a valid prepared course." % course.course_id)
		if prepared == null:
			continue
		_assert_true(not payloads.has(prepared.payload_sha256), "Prepared terrain payloads must be distinct.")
		payloads[prepared.payload_sha256] = true
		_assert_prepared_terrain(prepared, course)
	print("Cannon Golf prepared terrain contracts passed for fifteen courses.")
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
	_assert_true(
		prepared.local_bounds == FAST_GENERATOR._expanded_terrain_bounds(expected_bounds),
		"Prepared terrain must expand its terrain extent without lengthening the authored route."
	)
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
	_assert_true(
		prepared.footprint.count(1) < prepared.footprint.size(),
		"Prepared terrain must retain an irregular mountain footprint."
	)
	_assert_true(
		FAST_GENERATOR._footprint_is_connected(prepared.footprint, prepared.cell_count),
		"Prepared terrain footprint must be connected."
	)
	_assert_true(
		FAST_GENERATOR._active_terrain_area(
			prepared.footprint, prepared.cell_count, prepared.local_bounds
		) >= expected_bounds.get_area() * FAST_GENERATOR.MINIMUM_ACTIVE_AREA_RATIO,
		"Prepared terrain must meet the broader active-area contract."
	)
	_assert_true(
		FAST_GENERATOR._active_slopes_pass(
			prepared.heights, prepared.footprint, prepared.cell_count, prepared.local_bounds
		),
		"Prepared terrain must keep every active internal edge at or below 50 degrees."
	)
	for leg_index in range(prepared.legs.size()):
		_assert_goal_basin(prepared, prepared.legs[leg_index], course.leg_at(leg_index))
	if course.course_id == &"deep_relay":
		_assert_true(prepared.relief() >= 80.0, "Deep Relay must retain at least 80m relief.")
		for leg in prepared.legs:
			_assert_true(
				leg.goal_rim_y - leg.launcher_position.y >= 25.0,
				"Every Deep Relay goal rim must rise at least 25m from its launcher."
			)
	var course_index := CannonGolfCourseCatalog.index_of(course.course_id)
	_assert_true(
		prepared.relief() + 0.01 >= FAST_GENERATOR._minimum_required_relief(
			course, course_index
		) * 0.82,
		"Prepared terrain must meet its catalog-indexed relief target."
	)
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


func _assert_goal_basin(
		prepared: CannonGolfPreparedCourse,
		leg: CannonGolfPreparedCourseLeg,
		authored_leg: CannonGolfCourseLegData
) -> void:
	var floor_y := leg.goal_position.y
	var recess := leg.goal_rim_y - floor_y
	_assert_true(
		absf(prepared.height_at_local(leg.goal_position.x, leg.goal_position.z) - floor_y) <= 0.16,
		"The goal center must be the floor of its terrain basin."
	)
	_assert_true(
		leg.goal_radius >= authored_leg.bowl_radius_range.x and leg.goal_radius <= authored_leg.bowl_radius_range.y,
		"Prepared goal radius must stay inside the authored recipe range."
	)
	_assert_true(
		recess >= authored_leg.bowl_recess_depth_range.x \
				and recess <= authored_leg.bowl_recess_depth_range.y \
				and is_equal_approx(leg.goal_lip_y, leg.goal_rim_y),
		"The basin depth must remain authored and must not add a raised fence lip."
	)
	var directions: Array[Vector2] = [
		Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
	]
	for direction: Vector2 in directions:
		var middle_point := Vector2(leg.goal_position.x, leg.goal_position.z) \
				+ direction * (leg.goal_radius * 0.72)
		var shoulder_point := Vector2(leg.goal_position.x, leg.goal_position.z) \
				+ direction * (leg.goal_radius + FAST_GENERATOR.BASIN_SHOULDER_PADDING)
		var middle_height := prepared.height_at_local(middle_point.x, middle_point.y)
		var shoulder_height := prepared.height_at_local(shoulder_point.x, shoulder_point.y)
		_assert_true(
			middle_height >= floor_y - 0.16 and shoulder_height >= middle_height - 0.16,
			"%s goal basin must rise outward without a raised fence." % prepared.course_id
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
