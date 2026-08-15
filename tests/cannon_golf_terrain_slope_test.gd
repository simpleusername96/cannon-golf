extends SceneTree

const GENERATOR := preload("res://src/cannon_golf/trajectory_course_generator.gd")

var _failed := false


func _initialize() -> void:
	for course_index in range(CannonGolfCourseCatalog.all_courses().size()):
		var course := CannonGolfCourseCatalog.course_at(course_index)
		var product := GENERATOR.build(course)
		_assert_true(not product.is_empty(), "%s must generate a final terrain array." % course.course_id)
		if product.is_empty():
			continue
		var generated: CannonGolfGeneratedCourse = product.generated
		var layout := generated.layout
		var metrics := GENERATOR.measure_slope_metrics(
			layout.heights, layout.cell_count, layout.local_bounds
		)
		var target_relief := GENERATOR._minimum_required_relief(course, course_index)
		var relief := GENERATOR._maximum_height(layout.heights) - GENERATOR._minimum_height(layout.heights)
		_assert_true(
			relief >= target_relief - 0.01 and relief <= target_relief + GENERATOR.MAXIMUM_RELIEF_MARGIN + 0.01,
			"%s final relief must remain inside the accepted band." % course.course_id
		)
		_assert_true(
			float(metrics.p95_degrees) <= GENERATOR.P95_ADJACENT_SLOPE_DEGREES + 0.01
					and float(metrics.maximum_degrees) <= GENERATOR.MAXIMUM_ADJACENT_SLOPE_DEGREES + 0.01
					and float(metrics.steep_fraction) <= GENERATOR.MAXIMUM_STEEP_SAMPLE_FRACTION + 0.0001,
			"%s final terrain must satisfy the adjacent-sample slope contract." % course.course_id
		)
		_assert_goal_supports(generated)
	print("Cannon Golf in-memory terrain slope contracts passed for ten courses.")
	quit(1 if _failed else 0)
func _assert_goal_supports(generated: CannonGolfGeneratedCourse) -> void:
	var layout := generated.layout
	for leg in generated.legs:
		var support_y := leg.goal_position.y - GENERATOR.PLATE_SUPPORT_DEPTH
		var sample_x := clampi(roundi(
			(leg.goal_position.x - layout.local_bounds.position.x) / layout.local_bounds.size.x * layout.cell_count.x
		), 0, layout.cell_count.x)
		var sample_z := clampi(roundi(
			(leg.goal_position.z - layout.local_bounds.position.y) / layout.local_bounds.size.y * layout.cell_count.y
		), 0, layout.cell_count.y)
		var sampled_y := layout.heights[sample_z * (layout.cell_count.x + 1) + sample_x]
		_assert_true(
			absf(sampled_y - support_y) <= 0.08,
			"Final height array must retain the physical goal plate support."
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
