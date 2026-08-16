extends SceneTree

const GENERATOR := preload("res://src/cannon_golf/trajectory_course_generator.gd")

var _failed := false


func _initialize() -> void:
	var previous_target := 0.0
	for course_index in range(CannonGolfCourseCatalog.all_courses().size()):
		var course := CannonGolfCourseCatalog.course_at(course_index)
		var product := GENERATOR.build(course)
		_assert_true(not product.is_empty(), "%s must satisfy its intrinsic terrain contracts." % course.course_id)
		if product.is_empty():
			continue
		var generated: CannonGolfGeneratedCourse = product.generated
		var layout := generated.layout
		var target := GENERATOR._minimum_required_relief(course, course_index)
		var relief := GENERATOR._maximum_height(layout.heights) - GENERATOR._minimum_height(layout.heights)
		_assert_true(target >= previous_target, "Catalog relief targets must not regress.")
		_assert_true(
			relief >= target * 0.82 and relief <= target + GENERATOR.MAXIMUM_RELIEF_MARGIN + 0.01,
			"%s relief must remain inside its semantic tier band." % course.course_id
		)
		_assert_true(
			generated.source_footprint.count(1) < generated.source_footprint.size(),
			"%s must retain an irregular active mountain footprint." % course.course_id
		)
		_assert_true(
			GENERATOR._footprint_is_connected(generated.source_footprint, layout.cell_count),
			"%s active mountain footprint must be connected." % course.course_id
		)
		previous_target = target
	print("Cannon Golf constrained terrain contracts passed for ten courses.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
