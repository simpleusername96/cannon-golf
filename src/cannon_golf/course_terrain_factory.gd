class_name CannonGolfCourseTerrainFactory
extends RefCounted

## Cannon Golf adapter for Paint Mountain's canonical terrain pipeline.
##
## The retained route resolver and mountain synthesizer own the mountain form.
## This adapter preserves the original horizontal scale, carves one terrain
## basin, and admits the complete visible mountain through Cannon Golf's real
## launch envelope before canonical topology and geometry are exposed.

const TERRAIN_SHADER := preload("res://src/cannon_golf/cannon_golf_terrain.gdshader")
const CANNON_FRONT_STANDOFF := 75.0
const GOAL_BLEND_WIDTH := 5.0
const TERRAIN_BASE_Y := -14.0
const PLAY_BOUNDS_HORIZONTAL_MARGIN := 20.0
const PLAY_BOUNDS_MAXIMUM_HEIGHT := 190.0

static var _terrain_cache: Dictionary = {}
static var _generation_build_count := 0


static func build(course: CannonGolfCourseData) -> Dictionary:
	assert(course != null and course.is_valid(), "Terrain factory requires valid course data.")
	var cache_key := _cache_key(course)
	if _terrain_cache.has(cache_key):
		return (_terrain_cache[cache_key] as Dictionary).duplicate(false)
	var terrain := _build_uncached(course)
	_terrain_cache[cache_key] = terrain
	_generation_build_count += 1
	return terrain.duplicate(false)


static func generation_build_count() -> int:
	return _generation_build_count


static func cache_entry_count() -> int:
	return _terrain_cache.size()


static func _build_uncached(course: CannonGolfCourseData) -> Dictionary:
	var profile := course.generation_profile
	var source_graph := RouteGraphResolver.resolve(course.course_id, profile, course.terrain_seed)
	assert(source_graph != null and source_graph.is_valid(), "Paint Mountain route generation failed.")
	var generated := RouteGraphMountainSynthesizer.build(
		course.course_id, profile, source_graph, course.terrain_seed
	)
	var route_graph := _scaled_route_graph(source_graph, course)
	assert(route_graph.is_valid(), "Scaled Cannon Golf route graph failed.")
	var contract := profile.generation_contract
	var bounds := Rect2(
		contract.local_bounds.position * course.terrain_horizontal_scale
				+ Vector2(course.terrain_origin.x, course.terrain_origin.z),
		contract.local_bounds.size * course.terrain_horizontal_scale
	)
	var heights := _scaled_heights(generated.heights, course)
	var route_goal := route_graph.route_position(0, course.goal_route_t)
	var goal_xz := Vector2(route_goal.x, route_goal.z)
	var preliminary := TerrainTopTopology.build(
		contract.cell_count, bounds, heights, generated.footprint
	)
	assert(preliminary != null and preliminary.is_valid(), "Generated golf terrain topology failed.")
	var goal_rim_y := _carve_goal_basin(
		heights,
		contract.cell_count,
		bounds,
		goal_xz,
		course.goal_radius,
		course.goal_recess_depth
	)
	var topology := TerrainTopTopology.build(
		contract.cell_count, bounds, heights, generated.footprint
	)
	assert(topology != null and topology.is_valid(), "Depressed golf terrain topology failed.")

	var layout := GeneratedStageLayout.new()
	layout.profile_id = profile.profile_id
	layout.profile_version = profile.profile_version
	layout.layout_version = contract.layout_version
	layout.terrain_seed = course.terrain_seed
	layout.cell_count = contract.cell_count
	layout.local_bounds = bounds
	layout.heights = heights
	layout.top_topology = topology
	layout.route_graph = route_graph
	layout.play_bounds = PlayBoundsSpec.new()
	layout.install_footprint(generated.footprint)
	assert(layout.is_valid(), "Cannon Golf generated layout must satisfy the retained terrain contract.")
	var geometry := TerrainGeometryFactory.build(layout, TERRAIN_BASE_Y)
	assert(geometry != null and geometry.is_valid(), "Paint Mountain geometry construction failed.")
	_apply_material(geometry.render_mesh, course)

	var route_cannon := route_graph.route_position(0, course.cannon_route_t)
	var cannon_xz := Vector2(route_cannon.x, route_cannon.z)
	var route_tangent := route_graph.route_tangent(0, course.cannon_route_t)
	var forward_xz := Vector2(route_tangent.x, route_tangent.z).normalized()
	if forward_xz.is_zero_approx():
		forward_xz = Vector2.DOWN
	cannon_xz += forward_xz * CANNON_FRONT_STANDOFF
	var cannon_position := Vector3(cannon_xz.x, course.terrain_origin.y + 0.05, cannon_xz.y)
	var goal_position := Vector3(goal_xz.x, topology.height_at_local(goal_xz.x, goal_xz.y), goal_xz.y)
	var aim_delta := goal_position - cannon_position
	var shot_axis_yaw := rad_to_deg(atan2(aim_delta.x, -aim_delta.z))
	var admission_points := _terrain_admission_points(topology)
	var range_metrics := _validate_launch_envelope(
		admission_points, cannon_position, shot_axis_yaw
	)
	var content_points := admission_points.duplicate()
	content_points.append(cannon_position)
	content_points.append(goal_position)
	var content_bounds := _bounds_for_points(content_points)
	var play_minimum := content_bounds.position - Vector3(
		PLAY_BOUNDS_HORIZONTAL_MARGIN, 3.0, PLAY_BOUNDS_HORIZONTAL_MARGIN
	)
	var play_maximum := content_bounds.end + Vector3(
		PLAY_BOUNDS_HORIZONTAL_MARGIN, 0.0, PLAY_BOUNDS_HORIZONTAL_MARGIN
	)
	play_maximum.y = maxf(play_maximum.y, cannon_position.y + PLAY_BOUNDS_MAXIMUM_HEIGHT)
	return {
		"layout": layout,
		"geometry": geometry,
		"route_graph": route_graph,
		"source_route_graph": source_graph,
		"source_heights": generated.heights,
		"source_footprint": generated.footprint,
		"goal_position": goal_position,
		"goal_rim_y": goal_rim_y,
		"cannon_position": cannon_position,
		"shot_axis_yaw_degrees": shot_axis_yaw,
		"admission_points": admission_points,
		"range_metrics": range_metrics,
		"content_bounds": content_bounds,
		"play_bounds": AABB(play_minimum, play_maximum - play_minimum),
	}


static func _cache_key(course: CannonGolfCourseData) -> String:
	var profile := course.generation_profile
	var contract := profile.generation_contract
	var signature: Array[Variant] = [
		course.course_id,
		course.terrain_seed,
		course.terrain_horizontal_scale,
		course.terrain_vertical_scale,
		course.terrain_origin,
		course.goal_route_t,
		course.cannon_route_t,
		course.goal_recess_depth,
		course.goal_radius,
		course.terrain_color,
		course.terrain_accent_color,
		profile.profile_id,
		profile.profile_version,
		profile.base_seed,
		profile.nominal_peak,
		profile.accepted_height_range,
		profile.ridge_count,
		profile.basin_count,
		profile.pass_count,
		profile.undulation_amplitude,
		profile.route_width,
		profile.target_ratio_range,
		profile.target_mean_slope_range,
		profile.target_p95_slope_max,
		profile.target_maximum_slope,
		profile.route_core_p95_slope_max,
		profile.corridor_lip_maximum_slope,
		contract.generation_version,
		contract.profile_version,
		contract.layout_version,
		contract.cell_count,
		contract.local_bounds,
		contract.maximum_top_triangle_count,
		contract.cell_diagonal,
		contract.mask_size,
		contract.route_station_z,
		contract.maximum_station_x_delta,
		contract.outer_band_width,
		contract.terrace_step,
		contract.terrace_blend,
		contract.bank_blend_distance,
		contract.target_shoulder_distance,
		contract.support_distance,
		contract.noise_frequency,
		contract.noise_octaves,
		contract.noise_lacunarity,
		contract.noise_gain,
		contract.noise_amplitude,
	]
	for route in profile.routes:
		signature.append([
			route.role,
			route.endpoint_x,
			route.width,
			route.grade_signs,
			route.drop_range,
			route.rise_range,
			route.lateral_bend_range,
			route.mechanism_kind,
			route.mechanism_pad_t,
			route.mechanism_pad_radius,
			route.mechanism_kinds,
			route.mechanism_pad_ts,
			route.mechanism_pad_radii,
		])
	return var_to_str(signature)


static func _scaled_heights(source: PackedFloat32Array, course: CannonGolfCourseData) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(source.size())
	for index in range(source.size()):
		heights[index] = course.terrain_origin.y + source[index] * course.terrain_vertical_scale
	return heights


static func _scaled_route_graph(
		source: GeneratedRouteGraph,
		course: CannonGolfCourseData
) -> GeneratedRouteGraph:
	var nodes: Array[GeneratedRouteNode] = []
	for source_node in source.nodes:
		var source_position := source_node.position
		var position := Vector3(
			course.terrain_origin.x + source_position.x * course.terrain_horizontal_scale,
			course.terrain_origin.y + source_position.y * course.terrain_vertical_scale,
			course.terrain_origin.z + source_position.z * course.terrain_horizontal_scale
		)
		nodes.append(GeneratedRouteNode.new(
			source_node.id,
			position,
			source_node.route_index,
			source_node.station_index,
			source_node.kind,
			source_node.mechanism_kind,
			source_node.pad_radius * course.terrain_horizontal_scale
		))
	var edges: Array[GeneratedRouteEdge] = []
	for source_edge in source.edges:
		edges.append(GeneratedRouteEdge.new(
			source_edge.id,
			source_edge.from_node_id,
			source_edge.to_node_id,
			source_edge.route_index,
			source_edge.edge_index,
			source_edge.role,
			source_edge.width * course.terrain_horizontal_scale
		))
	return GeneratedRouteGraph.new(nodes, edges)


static func _carve_goal_basin(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		goal_xz: Vector2,
		goal_radius: float,
		goal_depth: float
) -> float:
	var sample_size := cell_count + Vector2i.ONE
	var rim_y := INF
	for sample_z in range(sample_size.y):
		var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
			if Vector2(x, z).distance_to(goal_xz) <= goal_radius:
				rim_y = minf(rim_y, heights[sample_z * sample_size.x + sample_x])
	assert(is_finite(rim_y), "Goal basin requires at least one source sample inside its radius.")
	var outer_radius := goal_radius + GOAL_BLEND_WIDTH
	for sample_z in range(sample_size.y):
		var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
			var distance := Vector2(x, z).distance_to(goal_xz)
			if distance > outer_radius:
				continue
			var index := sample_z * sample_size.x + sample_x
			var source_height := heights[index]
			if distance <= goal_radius:
				var radius_ratio := distance / goal_radius
				var basin_height := rim_y - goal_depth + goal_depth * radius_ratio * radius_ratio
				heights[index] = minf(source_height, basin_height)
				continue
			var blend := (distance - goal_radius) / GOAL_BLEND_WIDTH
			var smooth_blend := blend * blend * (3.0 - 2.0 * blend)
			heights[index] = minf(source_height, lerpf(rim_y, source_height, smooth_blend))
	return rim_y


static func _terrain_admission_points(topology: TerrainTopTopology) -> PackedVector3Array:
	var points := PackedVector3Array()
	var seen_top: Dictionary = {}
	for source_index in topology.canonical_triangle_indices_read_only():
		if seen_top.has(source_index):
			continue
		seen_top[source_index] = true
		points.append(topology.vertex_at(source_index))
	var seen_boundary: Dictionary = {}
	for source_index in topology.boundary_edges_read_only():
		if seen_boundary.has(source_index):
			continue
		seen_boundary[source_index] = true
		var top := topology.vertex_at(source_index)
		points.append(Vector3(top.x, TERRAIN_BASE_Y, top.z))
	return points


static func _validate_launch_envelope(
		points: PackedVector3Array,
		cannon_position: Vector3,
		shot_axis_yaw_degrees: float
) -> Dictionary:
	var minimum_range_margin := INF
	var minimum_yaw_margin := INF
	var minimum_height_margin := INF
	var farthest_distance := 0.0
	for point in points:
		var admission := CannonGolfBallistics.admit_world_point(
			point, cannon_position, shot_axis_yaw_degrees
		)
		assert(
			bool(admission.passed),
			"Generated terrain point %s failed launch-envelope admission: %s" % [point, admission]
		)
		minimum_range_margin = minf(minimum_range_margin, float(admission.range_margin))
		minimum_yaw_margin = minf(minimum_yaw_margin, float(admission.yaw_margin_degrees))
		minimum_height_margin = minf(minimum_height_margin, float(admission.height_margin))
		farthest_distance = maxf(farthest_distance, float(admission.distance))
	return {
		"point_count": points.size(),
		"minimum_range_margin": minimum_range_margin,
		"minimum_yaw_margin_degrees": minimum_yaw_margin,
		"minimum_height_margin": minimum_height_margin,
		"farthest_distance": farthest_distance,
	}


static func _bounds_for_points(points: PackedVector3Array) -> AABB:
	assert(not points.is_empty(), "Generated course bounds require visible content points.")
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	if bounds.size.y <= 0.0:
		bounds.size.y = 0.01
	# Godot AABB point containment excludes the maximum face. A centimetre of
	# framing slack keeps generated extrema truthfully inside the content bounds.
	return bounds.grow(0.01)


static func _apply_material(mesh: ArrayMesh, course: CannonGolfCourseData) -> void:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter(&"rock_color", course.terrain_color)
	material.set_shader_parameter(&"accent_color", course.terrain_accent_color)
	material.set_shader_parameter(&"shell_color", course.terrain_accent_color.darkened(0.48))
	mesh.surface_set_material(0, material)
