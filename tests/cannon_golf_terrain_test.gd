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
		_assert_goal_basin(layout, first, course)
		_assert_only_lowers_source(first, course)
		course_signatures.append(_height_signature(first.source_heights))
	_assert_true(course_signatures[0] != course_signatures[1], "Course IDs must select distinct deterministic mountains.")
	print("Cannon Golf native Paint Mountain terrain contract passed for both courses.")
	quit(0)


func _assert_goal_basin(
		layout: GeneratedStageLayout,
		generated: Dictionary,
		course: CannonGolfCourseData
) -> void:
	var center: Vector3 = generated.goal_position
	var rim_y := float(generated.goal_rim_y)
	var radial_samples: Array[Vector2] = []
	var seen: Dictionary = {}
	var topology := layout.top_topology
	for source_index in topology.canonical_triangle_indices_read_only():
		if seen.has(source_index):
			continue
		seen[source_index] = true
		var point := topology.vertex_at(source_index)
		var distance := Vector2(point.x - center.x, point.z - center.z).length()
		if distance <= course.goal_radius + 0.001:
			radial_samples.append(Vector2(distance, point.y))
			_assert_true(point.y <= rim_y + 0.001, "Every basin sample must be at or below the rim.")
	radial_samples.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	_assert_true(radial_samples.size() >= 8, "Goal basin must contain enough topology samples.")
	var minimum_sample_height := INF
	for index in range(radial_samples.size()):
		minimum_sample_height = minf(minimum_sample_height, radial_samples[index].y)
		if index == 0 or radial_samples[index].x - radial_samples[index - 1].x <= 0.02:
			continue
		_assert_true(
			radial_samples[index].y + 0.001 >= radial_samples[index - 1].y,
			"Basin height must not decrease from center toward rim."
		)
	var center_height := layout.height_at_local(center.x, center.z)
	_assert_true(center_height <= minimum_sample_height + 0.3, "Interpolated basin center must be the lowest region.")
	_assert_true(rim_y >= center_height + course.goal_recess_depth - 0.35, "Basin must preserve the configured depth.")


func _assert_only_lowers_source(generated: Dictionary, course: CannonGolfCourseData) -> void:
	var layout := generated.layout as GeneratedStageLayout
	var source: PackedFloat32Array = generated.source_heights
	for index in range(layout.heights.size()):
		var source_world_y := course.terrain_origin.y + source[index] * course.terrain_vertical_scale
		_assert_true(layout.heights[index] <= source_world_y + 0.001, "Goal carving may only lower generated source samples.")


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
