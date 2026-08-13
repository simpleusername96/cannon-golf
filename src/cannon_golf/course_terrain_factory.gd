class_name CannonGolfCourseTerrainFactory
extends RefCounted

## Cannon Golf adapter for Paint Mountain's canonical terrain pipeline.
##
## The retained route resolver and mountain synthesizer own the mountain form.
## This adapter preserves the legacy one-basin branch and adds explicit ordered
## legs as a separate generated product. Both paths deform the canonical sampled
## top before collision/render geometry and validate the applicable real launch
## envelopes before exposing runtime data.

const TERRAIN_SHADER := preload("res://src/cannon_golf/cannon_golf_terrain.gdshader")
const CANNON_FRONT_STANDOFF := 75.0
const GOAL_BLEND_WIDTH := 5.0
const TERRAIN_BASE_Y := -14.0
const PLAY_BOUNDS_HORIZONTAL_MARGIN := 20.0
const PLAY_BOUNDS_MAXIMUM_HEIGHT := 190.0
const RELAY_LAUNCH_ADMISSION_EXCLUSION_RADIUS := 30.0
const LAUNCHER_BASE_RADIUS := 1.95
const RELAY_ANCHOR_CLEARANCE := LAUNCHER_BASE_RADIUS + 1.0

static var _terrain_cache: Dictionary = {}
static var _generation_build_count := 0


static func build(course: CannonGolfCourseData) -> Variant:
	assert(course != null and course.is_valid(), "Terrain factory requires valid course data.")
	var cache_key := _cache_key(course)
	if _terrain_cache.has(cache_key):
		var cached: Variant = _terrain_cache[cache_key]
		return cached.duplicate(false) if cached is Dictionary else cached
	var terrain: Variant = _build_explicit_uncached(course) if course.has_explicit_legs() else _build_uncached(course)
	if terrain == null:
		return null
	_terrain_cache[cache_key] = terrain
	_generation_build_count += 1
	return terrain.duplicate(false) if terrain is Dictionary else terrain


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


static func _build_explicit_uncached(course: CannonGolfCourseData) -> CannonGolfGeneratedCourse:
	var profile := course.generation_profile
	var source_graph := RouteGraphResolver.resolve(course.course_id, profile, course.terrain_seed)
	if source_graph == null or not source_graph.is_valid():
		push_error("Longitudinal route generation failed.")
		return null
	var generated := RouteGraphMountainSynthesizer.build(course.course_id, profile, source_graph, course.terrain_seed)
	if not _generated_samples_are_valid(generated, profile.generation_contract):
		push_error("Longitudinal terrain synthesis returned invalid sampled data.")
		return null
	var route_graph := _scaled_route_graph(source_graph, course)
	if route_graph == null or not route_graph.is_valid() or route_graph.route_edges(0).is_empty():
		push_error("Longitudinal scaled route generation failed.")
		return null
	var contract := profile.generation_contract
	var bounds := Rect2(
		contract.local_bounds.position * course.terrain_horizontal_scale
				+ Vector2(course.terrain_origin.x, course.terrain_origin.z),
		contract.local_bounds.size * course.terrain_horizontal_scale
	)
	var heights := _scaled_heights(generated.heights, course)
	var preliminary := TerrainTopTopology.build(contract.cell_count, bounds, heights, generated.footprint)
	if preliminary == null or not preliminary.is_valid():
		push_error("Longitudinal preliminary topology failed.")
		return null
	var authored_legs: Array[CannonGolfCourseLegData] = []
	var goal_xzs: Array[Vector2] = []
	for index in range(course.leg_count()):
		var authored := course.leg_at(index)
		if authored == null or not authored.is_valid():
			push_error("Longitudinal course contains an invalid authored leg.")
			return null
		authored_legs.append(authored)
		var route_goal := route_graph.route_position(0, authored.goal_route_t)
		if not route_goal.is_finite():
			push_error("Longitudinal goal route resolution failed.")
			return null
		goal_xzs.append(Vector2(route_goal.x, route_goal.z))
	if not _goal_regions_do_not_overlap(goal_xzs, authored_legs):
		push_error("Explicit goal influence regions overlap.")
		return null
	var source_rims := PackedFloat32Array()
	for index in range(authored_legs.size()):
		var source_rim: Variant = _carve_explicit_raised_lip_goal(
			heights, contract.cell_count, bounds, goal_xzs[index], authored_legs[index].goal_radius,
			authored_legs[index].goal_recess_depth, authored_legs[index].goal_lip_height
		)
		if source_rim == null:
			push_error("Longitudinal raised-lip goal has no terrain samples.")
			return null
		source_rims.append(float(source_rim))
	var topology := TerrainTopTopology.build(contract.cell_count, bounds, heights, generated.footprint)
	if topology == null or not topology.is_valid():
		push_error("Longitudinal goal topology failed.")
		return null
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
	if not layout.is_valid():
		push_error("Longitudinal generated layout failed validation.")
		return null
	var geometry := TerrainGeometryFactory.build(layout, TERRAIN_BASE_Y)
	if geometry == null or not geometry.is_valid() or geometry.render_mesh == null:
		push_error("Longitudinal terrain geometry failed.")
		return null
	_apply_material(geometry.render_mesh, course)
	var result := CannonGolfGeneratedCourse.new()
	result.layout = layout
	result.geometry = geometry
	result.route_graph = route_graph
	result.source_route_graph = source_graph
	result.source_heights = generated.heights
	result.source_footprint = generated.footprint
	for index in range(authored_legs.size()):
		var authored := authored_legs[index]
		var leg := CannonGolfGeneratedCourseLeg.new()
		leg.goal_rim_y = source_rims[index]
		leg.goal_lip_y = source_rims[index] + authored.goal_lip_height
		var goal_position: Variant = _topology_position_at(topology, goal_xzs[index])
		var launcher_position: Variant = _explicit_launcher_position(course, topology, route_graph, authored, index)
		if goal_position == null or launcher_position == null:
			push_error("Longitudinal leg surface resolution failed.")
			return null
		var resolved_goal_position: Vector3 = goal_position
		var resolved_launcher_position: Vector3 = launcher_position
		leg.goal_position = resolved_goal_position
		leg.launcher_position = resolved_launcher_position
		var aim_delta := leg.goal_position - leg.launcher_position
		leg.shot_axis_yaw_degrees = rad_to_deg(atan2(aim_delta.x, -aim_delta.z))
		leg.corridor_admission = _validate_leg_corridor(topology, leg)
		var frame_bounds: Variant = _bounds_for_explicit_points(PackedVector3Array([leg.launcher_position, leg.goal_position]))
		if leg.corridor_admission.is_empty() or frame_bounds == null \
				or leg.goal_lip_y - leg.launcher_position.y < 25.0:
			push_error("Longitudinal leg %d failed validation." % (index + 1))
			return null
		var resolved_frame_bounds: AABB = frame_bounds
		leg.frame_bounds = resolved_frame_bounds.grow(30.0)
		if not leg.is_valid():
			push_error("Longitudinal leg %d is incomplete." % (index + 1))
			return null
		result.add_leg(leg)
	if not _validate_relay_anchor_clearance(result.legs, authored_legs):
		push_error("Longitudinal relay launcher clearance failed.")
		return null
	var admission_points := _terrain_admission_points(topology)
	if admission_points.is_empty():
		push_error("Longitudinal terrain has no admission points.")
		return null
	result.admission_points = admission_points
	result.union_range_metrics = _validate_union_launch_envelope(admission_points, result.legs)
	if result.union_range_metrics.is_empty():
		push_error("Longitudinal terrain failed union launch-envelope admission.")
		return null
	var content_points := admission_points.duplicate()
	for leg in result.legs:
		content_points.append(leg.launcher_position)
		content_points.append(leg.goal_position)
	var content_bounds: Variant = _bounds_for_explicit_points(content_points)
	if content_bounds == null:
		push_error("Longitudinal terrain has no visible content bounds.")
		return null
	var resolved_content_bounds: AABB = content_bounds
	result.content_bounds = resolved_content_bounds
	var play_minimum := result.content_bounds.position - Vector3(PLAY_BOUNDS_HORIZONTAL_MARGIN, 3.0, PLAY_BOUNDS_HORIZONTAL_MARGIN)
	var play_maximum := result.content_bounds.end + Vector3(PLAY_BOUNDS_HORIZONTAL_MARGIN, 0.0, PLAY_BOUNDS_HORIZONTAL_MARGIN)
	play_maximum.y = maxf(play_maximum.y, result.legs[0].launcher_position.y + PLAY_BOUNDS_MAXIMUM_HEIGHT)
	result.play_bounds = AABB(play_minimum, play_maximum - play_minimum)
	if _playable_top_relief(topology) < 80.0 or not result.is_valid():
		push_error("Longitudinal generated course failed final validation.")
		return null
	result.seal()
	if not result.is_sealed():
		push_error("Longitudinal generated course could not be sealed.")
		return null
	return result


static func _generated_samples_are_valid(
		generated: Dictionary, contract: StageGenerationContract
) -> bool:
	if generated.is_empty() or contract == null:
		return false
	var heights: Variant = generated.get("heights")
	var footprint: Variant = generated.get("footprint")
	if not heights is PackedFloat32Array or not footprint is PackedByteArray:
		return false
	var typed_heights := heights as PackedFloat32Array
	var typed_footprint := footprint as PackedByteArray
	if typed_heights.size() != (contract.cell_count.x + 1) * (contract.cell_count.y + 1) \
			or typed_footprint.size() != contract.cell_count.x * contract.cell_count.y:
		return false
	for height in typed_heights:
		if not is_finite(height):
			return false
	return typed_footprint.count(1) > 0


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
		_explicit_leg_signature(course),
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


static func _explicit_leg_signature(course: CannonGolfCourseData) -> Array[Variant]:
	var signature: Array[Variant] = []
	for index in range(course.leg_count()):
		var leg := course.leg_at(index)
		signature.append([
			leg.goal_route_t, leg.launcher_route_t, leg.goal_radius,
			leg.goal_recess_depth, leg.goal_lip_height, leg.default_setup(), leg.direct_solution(),
		])
	return signature


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


static func _carve_raised_lip_goal(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		goal_xz: Vector2,
		goal_radius: float,
		recess_depth: float,
		lip_height: float
) -> float:
	var sample_size := cell_count + Vector2i.ONE
	var source_rim_y := INF
	for sample_z in range(sample_size.y):
		var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
			if Vector2(x, z).distance_to(goal_xz) <= goal_radius:
				source_rim_y = minf(source_rim_y, heights[sample_z * sample_size.x + sample_x])
	assert(is_finite(source_rim_y), "Raised-lip goal requires source samples inside its radius.")
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
				heights[index] = source_rim_y - recess_depth + (recess_depth + lip_height) * radius_ratio * radius_ratio
				continue
			var blend := (distance - goal_radius) / GOAL_BLEND_WIDTH
			var smooth_blend := blend * blend * (3.0 - 2.0 * blend)
			heights[index] = lerpf(source_rim_y + lip_height, source_height, smooth_blend)
	return source_rim_y


static func _carve_explicit_raised_lip_goal(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		goal_xz: Vector2,
		goal_radius: float,
		recess_depth: float,
		lip_height: float
) -> Variant:
	var sample_size := cell_count + Vector2i.ONE
	var source_rim_y := INF
	for sample_z in range(sample_size.y):
		var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
			if Vector2(x, z).distance_to(goal_xz) <= goal_radius:
				source_rim_y = minf(source_rim_y, heights[sample_z * sample_size.x + sample_x])
	if not is_finite(source_rim_y):
		return null
	var outer_radius := goal_radius + GOAL_BLEND_WIDTH
	for sample_z in range(sample_size.y):
		var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
			var distance := Vector2(x, z).distance_to(goal_xz)
			if distance > outer_radius:
				continue
			var height_index := sample_z * sample_size.x + sample_x
			var source_height := heights[height_index]
			if distance <= goal_radius:
				var radius_ratio := distance / goal_radius
				heights[height_index] = source_rim_y - recess_depth + (recess_depth + lip_height) * radius_ratio * radius_ratio
				continue
			var blend := (distance - goal_radius) / GOAL_BLEND_WIDTH
			var smooth_blend := blend * blend * (3.0 - 2.0 * blend)
			heights[height_index] = lerpf(source_rim_y + lip_height, source_height, smooth_blend)
	return source_rim_y


static func _goal_regions_do_not_overlap(
		goal_xzs: Array[Vector2], authored_legs: Array[CannonGolfCourseLegData]
) -> bool:
	for first_index in range(goal_xzs.size()):
		for second_index in range(first_index + 1, goal_xzs.size()):
			var minimum_distance := authored_legs[first_index].goal_radius \
					+ authored_legs[second_index].goal_radius + GOAL_BLEND_WIDTH * 2.0
			if goal_xzs[first_index].distance_to(goal_xzs[second_index]) <= minimum_distance:
				return false
	return true


static func _explicit_launcher_position(
		course: CannonGolfCourseData,
		topology: TerrainTopTopology,
		route_graph: GeneratedRouteGraph,
		leg: CannonGolfCourseLegData,
		leg_index: int
) -> Variant:
	if topology == null or route_graph == null or leg == null:
		return null
	var route_launcher := route_graph.route_position(0, leg.launcher_route_t)
	if not route_launcher.is_finite():
		return null
	var launcher_xz := Vector2(route_launcher.x, route_launcher.z)
	if leg_index == 0:
		var route_tangent := route_graph.route_tangent(0, leg.launcher_route_t)
		if not route_tangent.is_finite():
			return null
		var forward_xz := Vector2(route_tangent.x, route_tangent.z).normalized()
		if forward_xz.is_zero_approx():
			forward_xz = Vector2.DOWN
		launcher_xz += forward_xz * CANNON_FRONT_STANDOFF
		var cannon_position := Vector3(launcher_xz.x, course.terrain_origin.y + 0.05, launcher_xz.y)
		return cannon_position if cannon_position.is_finite() else null
	var topology_position: Variant = _topology_position_at(topology, launcher_xz)
	if topology_position == null:
		return null
	var relay_position: Vector3 = topology_position
	return Vector3(relay_position.x, relay_position.y + 0.05, relay_position.z)


static func _topology_position_at(topology: TerrainTopTopology, xz: Vector2) -> Variant:
	if topology == null or not xz.is_finite():
		return null
	var sample := topology.surface_sample_at_local(xz.x, xz.y, true)
	if sample.is_empty() or not (sample.get("point") is Vector3):
		return null
	var point: Vector3 = sample.point
	return point if point.is_finite() else null


static func _validate_leg_corridor(
		topology: TerrainTopTopology, leg: CannonGolfGeneratedCourseLeg
) -> Dictionary:
	if topology == null or leg == null:
		return {}
	var points := PackedVector3Array()
	for index in range(4, 17):
		var t := float(index) / 16.0
		var xz := Vector2(leg.launcher_position.x, leg.launcher_position.z).lerp(
			Vector2(leg.goal_position.x, leg.goal_position.z), t
		)
		var surface_y := topology.height_at_local(xz.x, xz.y)
		if not is_finite(surface_y):
			return {}
		points.append(Vector3(xz.x, surface_y, xz.y))
	return _validate_explicit_launch_envelope(points, leg.launcher_position, leg.shot_axis_yaw_degrees)


static func _validate_union_launch_envelope(
		points: PackedVector3Array, legs: Array[CannonGolfGeneratedCourseLeg]
) -> Dictionary:
	if points.is_empty() or legs.is_empty():
		return {}
	var minimum_range_margin := INF
	var minimum_yaw_margin := INF
	var minimum_height_margin := INF
	var farthest_distance := 0.0
	var excluded_point_count := 0
	for point in points:
		if _is_relay_launch_exclusion(point, legs):
			excluded_point_count += 1
			continue
		var accepted: Dictionary = {}
		var first_index := _nearest_leg_index(point, legs)
		for offset in range(legs.size()):
			var leg := legs[(first_index + offset) % legs.size()]
			var admission := _admit_union_point(point, leg)
			if bool(admission.passed):
				accepted = admission
				break
		if accepted.is_empty():
			return {}
		minimum_range_margin = minf(minimum_range_margin, float(accepted.range_margin))
		minimum_yaw_margin = minf(minimum_yaw_margin, float(accepted.yaw_margin_degrees))
		minimum_height_margin = minf(minimum_height_margin, float(accepted.height_margin))
		farthest_distance = maxf(farthest_distance, float(accepted.distance))
	return {
		"point_count": points.size(),
		"minimum_range_margin": minimum_range_margin,
		"minimum_yaw_margin_degrees": minimum_yaw_margin,
		"minimum_height_margin": minimum_height_margin,
		"farthest_distance": farthest_distance,
		"excluded_point_count": excluded_point_count,
	}


static func _nearest_leg_index(
		point: Vector3, legs: Array[CannonGolfGeneratedCourseLeg]
) -> int:
	if legs.size() != 2:
		return 0
	var first := legs[0]
	var second := legs[1]
	var point_xz := Vector2(point.x, point.z)
	var first_distance := point_xz.distance_squared_to(Vector2(
		first.launcher_position.x, first.launcher_position.z
	))
	var second_distance := point_xz.distance_squared_to(Vector2(
		second.launcher_position.x, second.launcher_position.z
	))
	return 1 if second_distance < first_distance else 0


static func _admit_union_point(
		point: Vector3, leg: CannonGolfGeneratedCourseLeg
) -> Dictionary:
	var horizontal_delta := Vector2(
		point.x - leg.launcher_position.x,
		point.z - leg.launcher_position.z
	)
	var distance := horizontal_delta.length()
	var bearing := rad_to_deg(atan2(horizontal_delta.x, -horizontal_delta.y))
	var yaw_offset := wrapf(bearing - leg.shot_axis_yaw_degrees, -180.0, 180.0)
	var yaw_margin := CannonGolfBallistics.MAXIMUM_YAW_OFFSET_DEGREES - absf(yaw_offset)
	var range_margin := CannonGolfBallistics.maximum_horizontal_range() - distance
	if absf(yaw_offset) >= 90.0 \
			or yaw_margin < CannonGolfBallistics.REQUIRED_YAW_MARGIN_DEGREES \
			or range_margin < CannonGolfBallistics.REQUIRED_RANGE_MARGIN:
		return CannonGolfBallistics.admit_world_point(
			point, leg.launcher_position, leg.shot_axis_yaw_degrees
		)
	var relative_height := point.y - leg.launcher_position.y
	var sampled_interval := CannonGolfBallistics.sampled_reachable_height_interval(distance)
	var height_margin := minf(
		relative_height - sampled_interval.x,
		sampled_interval.y - relative_height
	) if sampled_interval.is_finite() and sampled_interval.x <= sampled_interval.y else -INF
	if height_margin < CannonGolfBallistics.REQUIRED_HEIGHT_MARGIN:
		return CannonGolfBallistics.admit_world_point(
			point, leg.launcher_position, leg.shot_axis_yaw_degrees
		)
	return {
		"passed": true,
		"in_front": true,
		"yaw_valid": true,
		"range_valid": true,
		"height_valid": true,
		"distance": distance,
		"yaw_offset_degrees": yaw_offset,
		"relative_height": relative_height,
		"height_interval": sampled_interval,
		"yaw_margin_degrees": yaw_margin,
		"range_margin": range_margin,
		"height_margin": height_margin,
	}


static func _is_relay_launch_exclusion(
		point: Vector3, legs: Array[CannonGolfGeneratedCourseLeg]
) -> bool:
	for index in range(1, legs.size()):
		var launcher := legs[index].launcher_position
		if Vector2(point.x, point.z).distance_to(Vector2(launcher.x, launcher.z)) <= RELAY_LAUNCH_ADMISSION_EXCLUSION_RADIUS:
			return true
	return false


static func _validate_relay_anchor_clearance(
		legs: Array[CannonGolfGeneratedCourseLeg], authored_legs: Array[CannonGolfCourseLegData]
) -> bool:
	if legs.size() != authored_legs.size():
		return false
	for index in range(1, legs.size()):
		var previous_goal := legs[index - 1].goal_position
		var anchor := legs[index].launcher_position
		var clearance := Vector2(previous_goal.x, previous_goal.z).distance_to(Vector2(anchor.x, anchor.z))
		var required_clearance := authored_legs[index - 1].goal_radius + RELAY_ANCHOR_CLEARANCE
		if clearance < required_clearance:
			return false
	return true


static func _playable_top_relief(topology: TerrainTopTopology) -> float:
	var lowest := INF
	var highest := -INF
	var seen: Dictionary = {}
	for source_index in topology.canonical_triangle_indices_read_only():
		if seen.has(source_index):
			continue
		seen[source_index] = true
		var point := topology.vertex_at(source_index)
		lowest = minf(lowest, point.y)
		highest = maxf(highest, point.y)
	return highest - lowest


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


static func _validate_explicit_launch_envelope(
		points: PackedVector3Array,
		launcher_position: Vector3,
		shot_axis_yaw_degrees: float
) -> Dictionary:
	if points.is_empty() or not launcher_position.is_finite() or not is_finite(shot_axis_yaw_degrees):
		return {}
	var minimum_range_margin := INF
	var minimum_yaw_margin := INF
	var minimum_height_margin := INF
	var farthest_distance := 0.0
	for point in points:
		if not point.is_finite():
			return {}
		var admission := CannonGolfBallistics.admit_world_point(
			point, launcher_position, shot_axis_yaw_degrees
		)
		if not bool(admission.passed):
			return {}
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


static func _bounds_for_explicit_points(points: PackedVector3Array) -> Variant:
	if points.is_empty() or not points[0].is_finite():
		return null
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		if not point.is_finite():
			return null
		bounds = bounds.expand(point)
	if bounds.size.y <= 0.0:
		bounds.size.y = 0.01
	return bounds.grow(0.01)


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
