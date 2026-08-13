extends SceneTree


func _initialize() -> void:
	_assert_explicit_sample_rejection()
	var course_signatures := PackedInt64Array()
	for course in CannonGolfCourseCatalog.all_courses():
		var expected_graph := RouteGraphResolver.resolve(
			course.course_id, course.generation_profile, course.terrain_seed
		)
		var expected := RouteGraphMountainSynthesizer.build(
			course.course_id, course.generation_profile, expected_graph, course.terrain_seed
		)
		var first: Variant = CannonGolfCourseTerrainFactory.build(course)
		var second: Variant = CannonGolfCourseTerrainFactory.build(course)
		if course.has_explicit_legs():
			_assert_true(first is CannonGolfGeneratedCourse and first == second, "Explicit courses must reuse immutable cached output.")
			_assert_relay_terrain(first as CannonGolfGeneratedCourse, course)
			_assert_route_graph_cache_isolation(
				first as CannonGolfGeneratedCourse, second as CannonGolfGeneratedCourse
			)
			continue
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
	print("Cannon Golf native and longitudinal terrain contracts passed.")
	quit(0)


func _assert_explicit_sample_rejection() -> void:
	var relay := CannonGolfCourseCatalog.course_at(2)
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
		"Explicit generation must reject non-finite synthesized terrain samples."
	)
	_assert_true(
		not CannonGolfCourseTerrainFactory._generated_samples_are_valid(
			{"heights": PackedFloat32Array(), "footprint": PackedByteArray()}, contract
		),
		"Explicit generation must reject malformed synthesized terrain samples."
	)


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


func _assert_relay_terrain(generated: CannonGolfGeneratedCourse, course: CannonGolfCourseData) -> void:
	_assert_true(
		generated.is_valid() and generated.is_sealed() and generated.leg_count() == 2,
		"Relay generation must return two sealed typed legs."
	)
	for leg in generated.legs:
		_assert_true(leg.is_sealed(), "Cached generated legs must be immutable after construction.")
	var copied_legs := generated.legs
	copied_legs.clear()
	var copied_points := generated.admission_points
	copied_points.clear()
	var copied_metrics := generated.union_range_metrics
	copied_metrics.clear()
	var copied_layout := generated.layout
	copied_layout.heights.clear()
	var copied_geometry := generated.geometry
	copied_geometry.top_triangle_count = 0
	_assert_true(
		generated.leg_count() == 2 and not generated.admission_points.is_empty() \
				and not generated.union_range_metrics.is_empty() \
				and generated.layout.heights.size() > 0 \
				and generated.geometry.top_triangle_count > 0,
		"Generated cache data must not be mutable through defensive views."
	)
	var layout := generated.layout
	_assert_true(layout.local_bounds.size.is_equal_approx(Vector2(210.0, 320.0)), "Relay extent must be exactly 210 x 320m.")
	_assert_true(layout.cell_count == Vector2i(84, 128), "Relay grid must be exactly 84 x 128 cells.")
	_assert_true(layout.top_topology.canonical_triangle_indices_read_only().size() <= 21504 * 3, "Relay top triangle budget must hold.")
	var lowest := INF
	var highest := -INF
	var seen: Dictionary = {}
	for source_index in layout.top_topology.canonical_triangle_indices_read_only():
		if seen.has(source_index):
			continue
		seen[source_index] = true
		var point := layout.top_topology.vertex_at(source_index)
		lowest = minf(lowest, point.y)
		highest = maxf(highest, point.y)
	_assert_true(highest - lowest >= 80.0, "Relay playable top must have at least 80m relief.")
	for index in range(generated.leg_count()):
		var leg := generated.leg_at(index)
		_assert_true(leg.goal_lip_y - leg.goal_position.y >= 5.6, "Relay goal center must sit below its raised lip.")
		_assert_true(leg.goal_lip_y - leg.launcher_position.y >= 25.0, "Each relay raised lip must rise 25m above its launcher.")
		_assert_true(not leg.corridor_admission.is_empty(), "Each relay leg requires corridor admission metrics.")
		if index > 0:
			var previous_goal := generated.leg_at(index - 1).goal_position
			_assert_true(
				Vector2(leg.launcher_position.x, leg.launcher_position.z).is_equal_approx(
					Vector2(previous_goal.x, previous_goal.z)
				) and is_equal_approx(
					leg.launcher_position.y,
					previous_goal.y + CannonGolfCourseTerrainFactory.RELAY_LAUNCH_SURFACE_OFFSET
				),
				"Each later relay launcher must sit at the exact prior-goal center."
			)
	_assert_true(not generated.union_range_metrics.is_empty(), "Relay requires union admission metrics.")
	_assert_true(int(generated.union_range_metrics.excluded_point_count) > 0, "Relay union admission must exclude the centered launch footprint.")


func _assert_route_graph_cache_isolation(
		first: CannonGolfGeneratedCourse, second: CannonGolfGeneratedCourse
) -> void:
	var route_view := first.route_graph
	var route_node := route_view.nodes[0]
	var route_edge := route_view.edges[0]
	var source_view := first.source_route_graph
	var source_node := source_view.nodes[0]
	var source_edge := source_view.edges[0]
	var expected_route_position := route_node.position
	var expected_route_width := route_edge.width
	var expected_source_position := source_node.position
	var expected_source_width := source_edge.width
	route_node._position += Vector3(1000.0, 1000.0, 1000.0)
	route_edge._width += 1000.0
	source_node._position += Vector3(1000.0, 1000.0, 1000.0)
	source_edge._width += 1000.0
	var later_route_view := second.route_graph
	var later_source_view := second.source_route_graph
	_assert_true(
		later_route_view.nodes[0].position.is_equal_approx(expected_route_position) \
				and is_equal_approx(later_route_view.edges[0].width, expected_route_width),
		"A consumer must not contaminate a later cached route-graph view."
	)
	_assert_true(
		later_source_view.nodes[0].position.is_equal_approx(expected_source_position) \
				and is_equal_approx(later_source_view.edges[0].width, expected_source_width),
		"A consumer must not contaminate a later cached source route-graph view."
	)


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
