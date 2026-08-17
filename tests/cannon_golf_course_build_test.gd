extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	for course in CannonGolfCourseCatalog.all_courses():
		_assert_true(builder.build(course), "Every catalog course must build from its prepared artifact.")
		await process_frame
		_assert_true(builder.course != course and builder.course.course_id == course.course_id, "Builder must isolate authored runtime data while retaining identity.")
		_assert_true(builder.prepared_course != null and builder.prepared_course.is_valid_for(course), "Builder must retain the matching prepared artifact.")
		_assert_true(builder.launcher != null, "Built course must contain one launcher.")
		_assert_true(builder.goal != null, "Built course must contain one settlement goal.")
		_assert_true(builder.leg_count() == course.leg_count(), "Built course must expose every normalized course leg.")
		_assert_true(builder.goals.size() == course.leg_count(), "Built course must create one goal node per leg.")
		_assert_true(builder.terrain_body_count() == 1, "A course must expose one connected terrain body.")
		_assert_true(builder.terrain_body != null and builder.terrain_body.is_in_group(&"impact_mark_surface"), "Prepared terrain must retain impact-mark collision ownership.")
		_assert_true(builder.course.content_bounds.has_point(builder.course.cannon_position), "Content bounds must include the launcher.")
		_assert_true(builder.course.content_bounds.has_point(builder.course.goal_position), "Content bounds must include an authored goal.")
		_assert_true(
			builder.goal.find_children("*", "StaticBody3D", true, false).is_empty(),
			"Terrain-owned goals must not add floor or wall collision."
		)
		_assert_true(builder.get_node_or_null("Mechanisms") == null, "Fresh courses must not contain devices.")
		_assert_true(
			(builder.terrain_body.get_node("TerrainMesh") as MeshInstance3D).mesh \
					== builder.prepared_course.render_mesh,
			"Runtime terrain must use the prepared render mesh without rebuilding it."
		)
		var terrain_material := (
			builder.terrain_body.get_node("TerrainMesh") as MeshInstance3D
		).material_override as ShaderMaterial
		_assert_true(
			terrain_material != null \
					and int(terrain_material.get_shader_parameter(&"goal_region_count")) \
					== builder.goals.size(),
			"The terrain material must mark every generated scoring region."
		)
		var first_anchor := builder.launcher.position
		for goal_index in range(course.leg_count()):
			var goal_center := builder.goals[goal_index].position
			_assert_true(builder.select_launcher_source(goal_index), "Every goal center must be a valid builder source.")
			_assert_true(
				Vector2(builder.launcher.position.x, builder.launcher.position.z).is_equal_approx(
					Vector2(goal_center.x, goal_center.z)
				),
				"A selected goal source must center the reusable launcher."
			)
			_assert_true(builder.get_node_or_null("Launcher") == builder.launcher, "Source selection must not spawn another launcher.")
			_assert_true(
				builder.launcher.horizontal_aim == 50.0 \
						and builder.launcher.elevation_degrees == 50.0 \
						and builder.launcher.power_percent == 50.0,
				"Every newly selected source must use the canonical defaults."
			)
			if goal_index + 1 < builder.prepared_course.legs.size():
				_assert_true(
					is_equal_approx(
						builder.launcher.shot_axis_yaw_degrees,
						builder.prepared_course.legs[goal_index + 1].shot_axis_yaw_degrees
					),
					"A relay source must face its generated outgoing corridor."
				)
		if course.leg_count() > 1:
			_assert_true(not builder.launcher.position.is_equal_approx(first_anchor), "A multi-goal course must relocate its reusable launcher.")
		_assert_true(builder.select_launcher_source(-1), "Builder must restore the original source for the next build.")
	print("Cannon Golf prepared course-build contract passed for fifteen courses.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
