extends SceneTree


func _initialize() -> void:
	var course_signatures := PackedInt64Array()
	for course in CannonGolfCourseCatalog.all_courses():
		var expected_graph := RouteGraphResolver.resolve(
			course.course_id, course.generation_profile, course.terrain_seed
		)
		var expected := RouteGraphMountainSynthesizer.build(
			course.course_id, course.generation_profile, expected_graph, course.terrain_seed
		)
		var first := CannonGolfCourseTerrainFactory.build(course)
		var second := CannonGolfCourseTerrainFactory.build(course)
		_assert_true(
			first.source_heights == expected.heights and first.source_footprint == expected.footprint,
			"%s must consume Paint Mountain's native mountain synthesis output." % course.course_id
		)
		_assert_true(
			first.source_heights == second.source_heights \
					and (first.layout as GeneratedStageLayout).heights == (second.layout as GeneratedStageLayout).heights,
			"%s generated terrain must be deterministic." % course.course_id
		)
		var layout := first.layout as GeneratedStageLayout
		var geometry := first.geometry as TerrainGeometry
		_assert_true(layout != null and layout.is_valid(), "Generated layout must be valid.")
		_assert_true(geometry != null and geometry.is_valid(), "Retained geometry factory must build valid geometry.")
		_assert_true(geometry.top_topology == layout.top_topology, "Render and collision must share one depressed topology.")
		_assert_true(geometry.render_mesh.get_surface_count() == 1, "Mountain must use one render surface.")
		_assert_true(geometry.top_shape is ConcavePolygonShape3D, "Mountain top must use triangle collision.")
		_assert_true(geometry.skirt_shape is ConcavePolygonShape3D, "Mountain shell must use triangle collision.")
		_assert_true(_goal_is_recessed(layout, first.goal_position, course.goal_radius), "Goal must be a depression in generated terrain.")
		course_signatures.append(_height_signature(first.source_heights))
	_assert_true(course_signatures[0] != course_signatures[1], "Course IDs must select distinct deterministic mountains.")
	print("Cannon Golf native Paint Mountain terrain contract passed for both courses.")
	quit(0)


func _goal_is_recessed(layout: GeneratedStageLayout, goal_position: Vector3, radius: float) -> bool:
	var center_height := layout.height_at_local(goal_position.x, goal_position.z)
	var highest_ring := -INF
	for step in range(24):
		var angle := TAU * float(step) / 24.0
		var xz := Vector2(goal_position.x, goal_position.z) + Vector2(sin(angle), cos(angle)) * (radius + 2.2)
		var sample := layout.surface_sample_at_local(xz.x, xz.y, false)
		if not sample.is_empty():
			highest_ring = maxf(highest_ring, float(sample.point.y))
	return is_finite(highest_ring) and highest_ring >= center_height + 0.55


func _height_signature(heights: PackedFloat32Array) -> int:
	var hash: int = 2166136261
	for index in range(0, heights.size(), 37):
		hash = int(((hash ^ roundi(heights[index] * 1000.0)) * 16777619) & 0xffffffff)
	return hash


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
