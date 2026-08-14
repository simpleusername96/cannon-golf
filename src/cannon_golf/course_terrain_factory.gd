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
const LANDFORM_FEATURE := preload("res://src/cannon_golf/course_landform_feature.gd")
const CANNON_FRONT_STANDOFF := 75.0
const LONGITUDINAL_CANNON_FRONT_STANDOFF := 50.0
const GOAL_BLEND_WIDTH := 5.0
const AUTHORED_RIM_BAND_STEP := 12.0
const TERRAIN_BASE_Y := -14.0
const PLAY_BOUNDS_HORIZONTAL_MARGIN := 20.0
const PLAY_BOUNDS_MAXIMUM_HEIGHT := 190.0
const RELAY_LAUNCH_ADMISSION_EXCLUSION_RADIUS := 30.0
const RELAY_LAUNCH_SURFACE_OFFSET := 0.05
const RELAY_CENTERED_UNION_HEIGHT_MARGIN := 0.0

static var _terrain_cache: Dictionary = {}
static var _generation_build_count := 0
static var _recipe_evaluation_cache: Dictionary = {}


static func build(course: CannonGolfCourseData) -> Variant:
	assert(course != null and course.is_valid(), "Terrain factory requires valid course data.")
	# Recipes have no exact goals and must be resolved offline before geometry exists.
	if course.is_constraint_recipe():
		return null
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


## Materializes only a sealed recipe plan through the established explicit-leg
## path. This adapter deliberately does not certify a physics solution.
static func build_resolved_plan(
		course: CannonGolfCourseData, plan: Variant, report_errors := false
) -> CannonGolfGeneratedCourse:
	if course == null or plan == null or not plan.is_valid_for(course):
		return null
	var working := course.duplicate(true) as CannonGolfCourseData
	working.authoring_mode = CannonGolfCourseData.AUTHORING_LEGACY_MIGRATION
	working.terrain_seed = plan.selected_seed
	var source_graph := RouteGraphResolver.resolve(working.course_id, working.generation_profile, working.terrain_seed)
	if source_graph == null or not source_graph.is_valid():
		return null
	var route_graph := _scaled_route_graph(source_graph, working)
	var exact_legs: Array[CannonGolfCourseLegData] = []
	for index in range(plan.legs.size()):
		var resolved = plan.legs[index]
		var authored := working.leg_at(index).duplicate(true) as CannonGolfCourseLegData
		if resolved.rim_elevation_band != authored.relative_rim_band:
			return null
		var route_position: Vector3 = route_graph.route_position(
			authored.route_index, resolved.selected_route_t
		)
		if not route_position.is_finite():
			return null
		authored.goal_route_t = resolved.selected_route_t
		authored.launcher_route_t = working.cannon_route_t
		authored.goal_placement_offset = Vector2(
			resolved.goal_position.x - route_position.x, resolved.goal_position.z - route_position.z
		)
		authored.rim_elevation_band = resolved.rim_elevation_band
		authored.goal_radius = resolved.bowl_radius
		authored.goal_recess_depth = resolved.bowl_recess_depth
		authored.goal_lip_height = resolved.bowl_lip_height
		exact_legs.append(authored)
	working.legs = exact_legs
	var target_rims := PackedFloat32Array()
	for resolved in plan.legs:
		target_rims.append(resolved.goal_rim_y)
	var generated := _build_explicit_uncached(working, true, target_rims, report_errors)
	if generated == null:
		return null
	for index in range(plan.legs.size()):
		var resolved = plan.legs[index]
		var materialized := generated.leg_at(index)
		if materialized == null or not materialized.goal_position.is_equal_approx(resolved.goal_position) \
				or not is_equal_approx(materialized.goal_rim_y, resolved.goal_rim_y) \
				or not is_equal_approx(materialized.goal_lip_y, resolved.goal_lip_y):
			return null
	return generated


## Reuses macro route/height samples per recipe+seed; no mesh or collision is
## built while analytic candidates are filtered.
static func evaluate_recipe_candidate(
		course: CannonGolfCourseData, seed: int, partial_legs: Array, candidate: Dictionary
) -> Dictionary:
	if course == null or not course.is_constraint_recipe() or not course.is_valid():
		return {}
	var context: Dictionary = _recipe_evaluation_context(course, seed)
	if context.is_empty():
		return {}
	var leg_index := partial_legs.size()
	var authored: CannonGolfCourseLegData = course.leg_at(leg_index)
	var route_graph: GeneratedRouteGraph = context.route_graph
	var route_position: Vector3 = route_graph.route_position(
		authored.route_index, float(candidate.route_t)
	)
	var tangent: Vector3 = route_graph.route_tangent(
		authored.route_index, float(candidate.route_t)
	)
	if not route_position.is_finite() or not tangent.is_finite():
		return {}
	var lateral: Vector2 = Vector2(-tangent.z, tangent.x).normalized() \
			* float(candidate.lateral_offset)
	var goal_xz: Vector2 = Vector2(route_position.x, route_position.z) + lateral
	var source_goal: Variant = _topology_position_at(context.topology, goal_xz)
	if source_goal == null:
		return {}
	var source_floor: Vector3 = source_goal
	var target_rim: float = float(context.band_base_rim_y) \
			+ float(authored.relative_rim_band) * AUTHORED_RIM_BAND_STEP
	var floor := Vector3(
		source_floor.x,
		target_rim - float(candidate.bowl_recess_depth),
		source_floor.z
	)
	var launcher: Vector3
	if partial_legs.is_empty():
		var route_launcher: Vector3 = route_graph.route_position(
			authored.route_index, course.cannon_route_t
		)
		var route_tangent: Vector3 = route_graph.route_tangent(
			authored.route_index, course.cannon_route_t
		)
		if not route_launcher.is_finite() or not route_tangent.is_finite():
			return {}
		var forward: Vector2 = Vector2(route_tangent.x, route_tangent.z).normalized()
		if forward.is_zero_approx():
			forward = Vector2.DOWN
		var standoff := _cannon_front_standoff(course)
		launcher = Vector3(route_launcher.x + forward.x * standoff, course.terrain_origin.y + 0.05, route_launcher.z + forward.y * standoff)
	else:
		launcher = partial_legs[partial_legs.size() - 1].goal_position + Vector3.UP * RELAY_LAUNCH_SURFACE_OFFSET
	var score := -absf(float(candidate.lateral_offset)) \
			- absf(floor.y - source_floor.y) * 0.1 \
			+ float(candidate.bowl_radius) * 0.03 \
			+ float(candidate.bowl_recess_depth) * 0.15 \
			- float(candidate.bowl_lip_height) * 0.10
	if course.leg_count() > 1 and leg_index == course.leg_count() - 1:
		var proxy_legs: Array[CannonGolfGeneratedCourseLeg] = []
		for prior in partial_legs:
			proxy_legs.append(_proxy_leg(prior.launcher_position, prior.goal_position))
		proxy_legs.append(_proxy_leg(launcher, floor))
		score += _recipe_union_proxy_score(context.topology, proxy_legs)
	return {
		"launcher_position": launcher,
		"goal_position": floor,
		"goal_rim_y": target_rim,
		"goal_lip_y": target_rim + float(candidate.bowl_lip_height),
		"terrain_adjustment": {
			"target_rim_y": target_rim,
			"center_height_delta": floor.y - source_floor.y,
		},
		"score": score,
	}

static func _proxy_leg(
		launcher: Vector3, goal: Vector3
) -> CannonGolfGeneratedCourseLeg:
	var leg := CannonGolfGeneratedCourseLeg.new()
	leg.launcher_position = launcher
	leg.goal_position = goal
	var delta := goal - launcher
	leg.shot_axis_yaw_degrees = rad_to_deg(atan2(delta.x, -delta.z))
	return leg


## Coarse source-topology coverage steers the four-plan beam away from obvious
## union-envelope dead ends. Final conditioned vertices still pass the exact
## exhaustive guard during materialization; this score is never acceptance.
static func _recipe_union_proxy_score(
		topology: TerrainTopTopology,
		legs: Array[CannonGolfGeneratedCourseLeg]
) -> float:
	if topology == null or not topology.is_valid() or legs.is_empty():
		return -INF
	var sample_size := topology.sample_size()
	var height_interval_cache := {}
	var uncovered_count := 0
	var minimum_yaw_margin := INF
	for sample_z in range(0, sample_size.y, 4):
		for sample_x in range(0, sample_size.x, 4):
			var point := Vector3(0.0, -INF, 0.0)
			for block_z in range(sample_z, mini(sample_z + 4, sample_size.y)):
				for block_x in range(sample_x, mini(sample_x + 4, sample_size.x)):
					var source_index := topology.sample_vertex_index(block_x, block_z)
					if source_index < 0:
						continue
					var candidate_point := topology.vertex_at(source_index)
					if candidate_point.y > point.y:
						point = candidate_point
			if not point.is_finite():
				continue
			if _is_relay_launch_exclusion(point, legs):
				continue
			var accepted := false
			for leg in legs:
				var admission := _admit_union_point(
					point, leg, RELAY_CENTERED_UNION_HEIGHT_MARGIN, height_interval_cache
				)
				if not bool(admission.passed):
					continue
				accepted = true
				minimum_yaw_margin = minf(
					minimum_yaw_margin, float(admission.yaw_margin_degrees)
				)
				break
			if not accepted:
				uncovered_count += 1
	if uncovered_count > 0:
		return -1000.0 * float(uncovered_count)
	return minf(minimum_yaw_margin, 80.0) * 0.01


static func _recipe_evaluation_context(course: CannonGolfCourseData, seed: int) -> Dictionary:
	var key := "%d|%d" % [course.get_instance_id(), seed]
	if _recipe_evaluation_cache.has(key):
		return _recipe_evaluation_cache[key]
	var profile := course.generation_profile
	var source_graph := RouteGraphResolver.resolve(course.course_id, profile, seed)
	if source_graph == null or not source_graph.is_valid():
		return {}
	var generated := RouteGraphMountainSynthesizer.build(course.course_id, profile, source_graph, seed)
	if not _generated_samples_are_valid(generated, profile.generation_contract):
		return {}
	var route_graph := _scaled_route_graph(source_graph, course)
	if route_graph == null or not route_graph.is_valid():
		return {}
	var bounds := Rect2(profile.generation_contract.local_bounds.position * course.terrain_horizontal_scale + Vector2(course.terrain_origin.x, course.terrain_origin.z), profile.generation_contract.local_bounds.size * course.terrain_horizontal_scale)
	var heights := _scaled_heights(generated.heights, course)
	var landform_metrics := _apply_landforms(
		heights, profile.generation_contract.cell_count, bounds, route_graph, course
	)
	if not course.landform_features.is_empty() and landform_metrics.is_empty():
		return {}
	var topology := TerrainTopTopology.build(
		profile.generation_contract.cell_count, bounds, heights, generated.footprint
	)
	if topology == null or not topology.is_valid():
		return {}
	var band_base_rim_y := _recipe_band_base(course, route_graph, topology)
	if not is_finite(band_base_rim_y):
		return {}
	var context := {
		"route_graph": route_graph,
		"topology": topology,
		"band_base_rim_y": band_base_rim_y,
	}
	_recipe_evaluation_cache[key] = context
	return context


## Chooses one shared L-band elevation that minimizes local center changes over
## every authored leg domain. M/H remain exact 12 m increments from this base,
## so alternating bands are physical constraints rather than display metadata.
static func _recipe_band_base(
		course: CannonGolfCourseData,
		route_graph: GeneratedRouteGraph,
		topology: TerrainTopTopology
) -> float:
	var anchors: Array[float] = []
	for leg_index in range(course.leg_count()):
		var leg := course.leg_at(leg_index)
		var route_values := PackedFloat32Array([
			(leg.route_interval.x + leg.route_interval.y) * 0.5,
			leg.route_interval.x,
			leg.route_interval.y,
		])
		var lateral_values := PackedFloat32Array([
			(leg.lateral_offset_range.x + leg.lateral_offset_range.y) * 0.5,
			leg.lateral_offset_range.x,
			leg.lateral_offset_range.y,
		])
		var representative_depth := (
			leg.bowl_recess_depth_range.x + leg.bowl_recess_depth_range.y
		) * 0.5
		for route_t in route_values:
			var route_position := route_graph.route_position(leg.route_index, route_t)
			var tangent := route_graph.route_tangent(leg.route_index, route_t)
			if not route_position.is_finite() or not tangent.is_finite():
				continue
			var normal := Vector2(-tangent.z, tangent.x).normalized()
			for lateral_offset in lateral_values:
				var xz := Vector2(route_position.x, route_position.z) \
						+ normal * lateral_offset
				var sampled: Variant = _topology_position_at(topology, xz)
				if sampled is Vector3 and (sampled as Vector3).is_finite():
					anchors.append(
						(sampled as Vector3).y + representative_depth
						- float(leg.relative_rim_band) * AUTHORED_RIM_BAND_STEP
					)
	if anchors.is_empty():
		return NAN
	anchors.sort()
	return anchors[anchors.size() / 2]


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
	var landform_metrics := _apply_landforms(heights, contract.cell_count, bounds, route_graph, course)
	if not course.landform_features.is_empty() and landform_metrics.is_empty():
		push_error("Course landform recipe failed measurable validation.")
		return {}
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
	landform_metrics = _measure_final_landforms(
		heights, contract.cell_count, bounds, route_graph, course, landform_metrics
	)
	if not course.landform_features.is_empty() and landform_metrics.is_empty():
		push_error("Final course terrain no longer satisfies its semantic landforms.")
		return {}
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
	if geometry == null or not geometry.is_valid() or geometry.render_mesh == null:
		push_error("Cannon Golf terrain geometry failed.")
		return {}
	_apply_material(geometry.render_mesh, course)

	var route_cannon := route_graph.route_position(0, course.cannon_route_t)
	var cannon_xz := Vector2(route_cannon.x, route_cannon.z)
	var route_tangent := route_graph.route_tangent(0, course.cannon_route_t)
	var forward_xz := Vector2(route_tangent.x, route_tangent.z).normalized()
	if forward_xz.is_zero_approx():
		forward_xz = Vector2.DOWN
	cannon_xz += forward_xz * _cannon_front_standoff(course)
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
		"landform_metrics": landform_metrics,
		"content_bounds": content_bounds,
		"play_bounds": AABB(play_minimum, play_maximum - play_minimum),
	}


static func _build_explicit_uncached(
		course: CannonGolfCourseData, resolved_materialization := false,
		target_rims := PackedFloat32Array(), report_errors := true
) -> CannonGolfGeneratedCourse:
	var profile := course.generation_profile
	var source_graph := RouteGraphResolver.resolve(course.course_id, profile, course.terrain_seed)
	if source_graph == null or not source_graph.is_valid():
		_report_explicit_failure("Longitudinal route generation failed.", report_errors)
		return null
	var generated := RouteGraphMountainSynthesizer.build(course.course_id, profile, source_graph, course.terrain_seed)
	if not _generated_samples_are_valid(generated, profile.generation_contract):
		_report_explicit_failure("Longitudinal terrain synthesis returned invalid sampled data.", report_errors)
		return null
	var route_graph := _scaled_route_graph(source_graph, course)
	if route_graph == null or not route_graph.is_valid() or route_graph.route_edges(0).is_empty():
		_report_explicit_failure("Longitudinal scaled route generation failed.", report_errors)
		return null
	var contract := profile.generation_contract
	var bounds := Rect2(
		contract.local_bounds.position * course.terrain_horizontal_scale
				+ Vector2(course.terrain_origin.x, course.terrain_origin.z),
		contract.local_bounds.size * course.terrain_horizontal_scale
	)
	var heights := _scaled_heights(generated.heights, course)
	var landform_metrics := _apply_landforms(heights, contract.cell_count, bounds, route_graph, course)
	if not course.landform_features.is_empty() and landform_metrics.is_empty():
		_report_explicit_failure("Explicit course landform recipe failed measurable validation.", report_errors)
		return null
	var preliminary := TerrainTopTopology.build(contract.cell_count, bounds, heights, generated.footprint)
	if preliminary == null or not preliminary.is_valid():
		_report_explicit_failure("Longitudinal preliminary topology failed.", report_errors)
		return null
	var authored_legs: Array[CannonGolfCourseLegData] = []
	var goal_xzs: Array[Vector2] = []
	for index in range(course.leg_count()):
		var authored := course.leg_at(index)
		if authored == null or not (authored.is_valid() or resolved_materialization \
				and _is_valid_resolved_materialization_leg(authored)):
			_report_explicit_failure("Longitudinal course contains an invalid authored leg.", report_errors)
			return null
		authored_legs.append(authored)
		var route_goal := route_graph.route_position(authored.route_index, authored.goal_route_t)
		if not route_goal.is_finite():
			_report_explicit_failure("Longitudinal goal route resolution failed.", report_errors)
			return null
		goal_xzs.append(Vector2(route_goal.x, route_goal.z) + authored.goal_placement_offset)
	if not _goal_regions_do_not_overlap(goal_xzs, authored_legs):
		_report_explicit_failure("Explicit goal influence regions overlap.", report_errors)
		return null
	if not _shape_authored_leg_corridors(
		heights, contract.cell_count, bounds, route_graph, course, goal_xzs, authored_legs
	):
		_report_explicit_failure("Explicit launcher-to-goal corridor shaping failed.", report_errors)
		return null
	# Corridor conditioning must happen first. Reapplying the exact rim band
	# afterward prevents the corridor from silently lowering the physical basin
	# below the sealed resolved-plan height.
	if not _shape_authored_rim_bands(
		heights, contract.cell_count, bounds, goal_xzs, authored_legs, target_rims
	):
		_report_explicit_failure("Explicit goal rim-band shaping failed.", report_errors)
		return null
	var source_rims := PackedFloat32Array()
	for index in range(authored_legs.size()):
		var source_rim: Variant = _carve_explicit_raised_lip_goal(
			heights, contract.cell_count, bounds, goal_xzs[index], authored_legs[index].goal_radius,
			authored_legs[index].goal_recess_depth, authored_legs[index].goal_lip_height
		)
		if source_rim == null:
			_report_explicit_failure("Longitudinal raised-lip goal has no terrain samples.", report_errors)
			return null
		source_rims.append(float(source_rim))
		if target_rims.size() == authored_legs.size() \
				and absf(float(source_rim) - target_rims[index]) > 0.01:
			_report_explicit_failure(
				"Resolved goal rim differs from the conditioned physical terrain.",
				report_errors
			)
			return null
	if not _rim_bands_match(source_rims, authored_legs):
		var requested_bands := PackedInt32Array()
		for authored_leg in authored_legs:
			requested_bands.append(authored_leg.rim_elevation_band)
		_report_explicit_failure(
			"Authored goal rims %s do not satisfy requested L/M/H bands %s for %s."
			% [source_rims, requested_bands, course.course_id], report_errors
		)
		return null
	landform_metrics = _measure_final_landforms(
		heights, contract.cell_count, bounds, route_graph, course, landform_metrics
	)
	if not course.landform_features.is_empty() and landform_metrics.is_empty():
		_report_explicit_failure("Final explicit terrain no longer satisfies its semantic landforms.", report_errors)
		return null
	var topology := TerrainTopTopology.build(contract.cell_count, bounds, heights, generated.footprint)
	if topology == null or not topology.is_valid():
		_report_explicit_failure("Longitudinal goal topology failed.", report_errors)
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
		_report_explicit_failure("Longitudinal generated layout failed validation.", report_errors)
		return null
	var geometry := TerrainGeometryFactory.build(layout, TERRAIN_BASE_Y)
	if geometry == null or not geometry.is_valid() or geometry.render_mesh == null:
		_report_explicit_failure("Longitudinal terrain geometry failed.", report_errors)
		return null
	_apply_material(geometry.render_mesh, course)
	var result := CannonGolfGeneratedCourse.new()
	result.layout = layout
	result.geometry = geometry
	result.route_graph = route_graph
	result.source_route_graph = source_graph
	result.source_heights = generated.heights
	result.source_footprint = generated.footprint
	result.landform_metrics = landform_metrics
	for index in range(authored_legs.size()):
		var authored := authored_legs[index]
		var leg := CannonGolfGeneratedCourseLeg.new()
		leg.goal_rim_y = target_rims[index] if target_rims.size() == authored_legs.size() else source_rims[index]
		leg.goal_lip_y = leg.goal_rim_y + authored.goal_lip_height
		var goal_position: Variant = _topology_position_at(topology, goal_xzs[index])
		var launcher_position: Variant = _explicit_launcher_position(
			course, topology, route_graph, authored, index, goal_xzs
		)
		if goal_position == null or launcher_position == null:
			_report_explicit_failure("Longitudinal leg surface resolution failed.", report_errors)
			return null
		var resolved_goal_position: Vector3 = Vector3(goal_xzs[index].x, leg.goal_rim_y - authored.goal_recess_depth, goal_xzs[index].y) if target_rims.size() == authored_legs.size() else goal_position
		var resolved_launcher_position: Vector3 = launcher_position
		if resolved_materialization and index > 0:
			resolved_launcher_position = result.leg_at(index - 1).goal_position + Vector3.UP * RELAY_LAUNCH_SURFACE_OFFSET
		leg.goal_position = resolved_goal_position
		leg.launcher_position = resolved_launcher_position
		var aim_delta := leg.goal_position - leg.launcher_position
		leg.shot_axis_yaw_degrees = rad_to_deg(atan2(aim_delta.x, -aim_delta.z))
		leg.corridor_admission = _validate_leg_corridor(topology, leg, report_errors)
		var frame_bounds: Variant = _bounds_for_explicit_points(PackedVector3Array([leg.launcher_position, leg.goal_position]))
		if leg.corridor_admission.is_empty() or frame_bounds == null:
			_report_explicit_failure("Longitudinal leg %d failed validation." % (index + 1), report_errors)
			return null
		var resolved_frame_bounds: AABB = frame_bounds
		leg.frame_bounds = resolved_frame_bounds.grow(30.0)
		if not leg.is_valid():
			_report_explicit_failure("Longitudinal leg %d is incomplete." % (index + 1), report_errors)
			return null
		result.add_leg(leg)
	if not _validate_relay_launcher_centers(result.legs):
		_report_explicit_failure("Longitudinal relay launcher centering failed.", report_errors)
		return null
	var admission_points := _terrain_admission_points(topology)
	if admission_points.is_empty():
		_report_explicit_failure("Longitudinal terrain has no admission points.", report_errors)
		return null
	result.admission_points = admission_points
	result.union_range_metrics = _validate_union_launch_envelope(
		admission_points, result.legs, report_errors
	)
	if result.union_range_metrics.is_empty():
		_report_explicit_failure("Longitudinal terrain failed union launch-envelope admission.", report_errors)
		return null
	var content_points := admission_points.duplicate()
	for leg in result.legs:
		content_points.append(leg.launcher_position)
		content_points.append(leg.goal_position)
	var content_bounds: Variant = _bounds_for_explicit_points(content_points)
	if content_bounds == null:
		_report_explicit_failure("Longitudinal terrain has no visible content bounds.", report_errors)
		return null
	var resolved_content_bounds: AABB = content_bounds
	result.content_bounds = resolved_content_bounds
	var play_minimum := result.content_bounds.position - Vector3(PLAY_BOUNDS_HORIZONTAL_MARGIN, 3.0, PLAY_BOUNDS_HORIZONTAL_MARGIN)
	var play_maximum := result.content_bounds.end + Vector3(PLAY_BOUNDS_HORIZONTAL_MARGIN, 0.0, PLAY_BOUNDS_HORIZONTAL_MARGIN)
	play_maximum.y = maxf(play_maximum.y, result.legs[0].launcher_position.y + PLAY_BOUNDS_MAXIMUM_HEIGHT)
	result.play_bounds = AABB(play_minimum, play_maximum - play_minimum)
	if not result.is_valid():
		_report_explicit_failure("Longitudinal generated course failed final validation.", report_errors)
		return null
	result.seal()
	if not result.is_sealed():
		_report_explicit_failure("Longitudinal generated course could not be sealed.", report_errors)
		return null
	return result


static func _report_explicit_failure(message: String, report_errors: bool) -> void:
	if report_errors:
		push_error(message)


## Resolved plans carry no solution witness. This internal check preserves the
## explicit terrain inputs without asking the materializer to fabricate one.
static func _is_valid_resolved_materialization_leg(leg: CannonGolfCourseLegData) -> bool:
	return leg.goal_route_t > 0.0 and leg.goal_route_t < 1.0 \
			and leg.launcher_route_t > leg.goal_route_t and leg.launcher_route_t <= 1.0 \
			and leg.route_index >= 0 and leg.goal_placement_offset.is_finite() \
			and leg.rim_elevation_band >= 0 and leg.rim_elevation_band <= 2 \
			and leg.goal_radius >= 3.5 and leg.goal_recess_depth > 0.0 \
			and leg.goal_lip_height >= 0.0


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
			leg.route_index, leg.goal_placement_offset, leg.rim_elevation_band, leg.feature_anchor,
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


static func _apply_landforms(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		route_graph: GeneratedRouteGraph,
		course: CannonGolfCourseData
) -> Dictionary:
	if course.landform_features.is_empty():
		return {}
	if route_graph == null or heights.size() != (cell_count.x + 1) * (cell_count.y + 1):
		return {}
	var metrics := {}
	var sample_size := cell_count + Vector2i.ONE
	for feature in course.landform_features:
		if feature == null or not feature.is_valid():
			return {}
		var route_point := route_graph.route_position(0, feature.route_t)
		if not route_point.is_finite():
			return {}
		var center: Vector2 = Vector2(route_point.x, route_point.z) + feature.route_offset
		var before_center := _height_sample_nearest(heights, cell_count, bounds, center)
		if not is_finite(before_center):
			return {}
		var signed_amplitude: float = feature.amplitude
		if feature.kind == LANDFORM_FEATURE.Kind.SADDLE \
				or feature.kind == LANDFORM_FEATURE.Kind.VALLEY \
				or feature.kind == LANDFORM_FEATURE.Kind.BASIN:
			signed_amplitude = -signed_amplitude
		for z_index in range(sample_size.y):
			var z := lerpf(bounds.position.y, bounds.end.y, float(z_index) / float(cell_count.y))
			for x_index in range(sample_size.x):
				var x := lerpf(bounds.position.x, bounds.end.x, float(x_index) / float(cell_count.x))
				var delta: Vector2 = Vector2(x, z) - center
				var distance: float = delta.length()
				if distance > feature.radius:
					continue
				var falloff: float = 1.0 - distance / feature.radius
				falloff = falloff * falloff * (3.0 - 2.0 * falloff)
				var index := z_index * sample_size.x + x_index
				if feature.kind == LANDFORM_FEATURE.Kind.RIDGE:
					falloff *= 1.0 - absf(delta.x) / feature.radius * 0.55
				elif feature.kind == LANDFORM_FEATURE.Kind.SADDLE:
					falloff *= absf(delta.x) / feature.radius
				elif feature.kind == LANDFORM_FEATURE.Kind.TERRACE \
						or feature.kind == LANDFORM_FEATURE.Kind.PLATEAU:
					falloff = 1.0 if distance <= feature.radius * feature.flatness else falloff
				heights[index] += signed_amplitude * maxf(0.0, falloff)
		var after_center := _height_sample_nearest(heights, cell_count, bounds, center)
		var center_delta := after_center - before_center
		if absf(center_delta) < feature.amplitude * 0.35:
			return {}
		var ring_delta := _landform_ring_delta(heights, cell_count, bounds, center, feature.radius, after_center)
		if not _landform_metric_is_valid(feature, center_delta, ring_delta):
			return {}
		metrics[feature.feature_id] = {
			"kind": feature.kind,
			"center_delta": center_delta,
			"center_vs_ring": ring_delta,
			"radius": feature.radius,
			"flatness": feature.flatness,
		}
	return metrics


static func _landform_ring_delta(heights: PackedFloat32Array, cell_count: Vector2i, bounds: Rect2, center: Vector2, radius: float, center_height: float) -> float:
	var ring_total := 0.0
	var count := 0
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var ring_height := _height_sample_nearest(heights, cell_count, bounds, center + direction * radius * 0.72)
		if is_finite(ring_height):
			ring_total += ring_height
			count += 1
	return center_height - ring_total / float(count) if count > 0 else NAN


static func _landform_metric_is_valid(feature: Resource, center_delta: float, center_vs_ring: float) -> bool:
	if not is_finite(center_vs_ring) or absf(center_delta) < feature.amplitude * 0.35:
		return false
	match feature.kind:
		LANDFORM_FEATURE.Kind.PEAK, LANDFORM_FEATURE.Kind.RIDGE:
			return center_vs_ring >= feature.amplitude * 0.08
		LANDFORM_FEATURE.Kind.VALLEY, LANDFORM_FEATURE.Kind.BASIN:
			return center_vs_ring <= -feature.amplitude * 0.08
		LANDFORM_FEATURE.Kind.SADDLE:
			return center_vs_ring <= feature.amplitude * 0.08
		LANDFORM_FEATURE.Kind.PLATEAU, LANDFORM_FEATURE.Kind.TERRACE:
			return absf(center_vs_ring) >= feature.amplitude * 0.05
	return false


## Re-measures the authored feature on the final height samples, after corridor
## shaping and goal carving. Initial deformation evidence is retained, but the
## baked metric and acceptance sign come from the geometry players receive.
static func _measure_final_landforms(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		route_graph: GeneratedRouteGraph,
		course: CannonGolfCourseData,
		initial_metrics: Dictionary
) -> Dictionary:
	if course.landform_features.is_empty():
		return {}
	if route_graph == null or initial_metrics.size() != course.landform_features.size():
		return {}
	var metrics := {}
	for feature in course.landform_features:
		if feature == null or not feature.is_valid() or not initial_metrics.has(feature.feature_id):
			return {}
		var route_point := route_graph.route_position(0, feature.route_t)
		if not route_point.is_finite():
			return {}
		var center: Vector2 = Vector2(route_point.x, route_point.z) + feature.route_offset
		var center_height := _height_sample_nearest(heights, cell_count, bounds, center)
		var center_vs_ring := _landform_ring_delta(
			heights, cell_count, bounds, center, feature.radius, center_height
		)
		var initial: Dictionary = initial_metrics[feature.feature_id]
		var center_delta := float(initial.get("center_delta", NAN))
		if not is_finite(center_height) \
				or not _landform_metric_is_valid(feature, center_delta, center_vs_ring):
			return {}
		metrics[feature.feature_id] = {
			"kind": feature.kind,
			"center_delta": center_delta,
			"center_height": center_height,
			"center_vs_ring": center_vs_ring,
			"radius": feature.radius,
			"flatness": feature.flatness,
		}
	return metrics


static func _rim_bands_match(rims: PackedFloat32Array, legs: Array[CannonGolfCourseLegData]) -> bool:
	if rims.size() != legs.size() or rims.is_empty():
		return false
	# A one-goal course has no within-course ordering to normalize. Its resolved
	# absolute target still comes from the shared L/M/H elevation formula.
	if rims.size() == 1:
		return true
	var minimum := INF
	var maximum := -INF
	for rim in rims:
		minimum = minf(minimum, rim)
		maximum = maxf(maximum, rim)
	var span := maximum - minimum
	for index in range(rims.size()):
		var normalized := 1 if span < 0.001 else clampi(roundi((rims[index] - minimum) / span * 2.0), 0, 2)
		if normalized != legs[index].rim_elevation_band:
			return false
	return true


static func _shape_authored_rim_bands(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		goal_xzs: Array[Vector2],
		legs: Array[CannonGolfCourseLegData],
		target_rims := PackedFloat32Array()
) -> bool:
	if goal_xzs.size() != legs.size() or (not target_rims.is_empty() and target_rims.size() != legs.size()):
		return false
	if goal_xzs.size() < 2 and target_rims.is_empty():
		return true
	var source_rims := PackedFloat32Array()
	var minimum := INF
	for index in range(goal_xzs.size()):
		var source_rim := _minimum_height_in_radius(
			heights, cell_count, bounds, goal_xzs[index], legs[index].goal_radius
		)
		if not is_finite(source_rim):
			return false
		source_rims.append(source_rim)
		minimum = minf(minimum, source_rim)
	# L/M/H is an authored physical input, not display-only metadata. Preserve
	# the course's naturally reachable low shelf while guaranteeing distinct
	# levels without lifting a target above the first launcher's upper envelope.
	var center := minimum + AUTHORED_RIM_BAND_STEP
	var half_span := AUTHORED_RIM_BAND_STEP
	var sample_size := cell_count + Vector2i.ONE
	for goal_index in range(goal_xzs.size()):
		var target_rim := target_rims[goal_index] if target_rims.size() == legs.size() else center + float(legs[goal_index].rim_elevation_band - 1) * half_span
		var outgoing_distance := goal_xzs[goal_index].distance_to(goal_xzs[goal_index + 1]) \
				if goal_index + 1 < goal_xzs.size() else 0.0
		# A completed goal is the next launcher. Keep enough level support around
		# that checkpoint for the guarded first quarter of a descending leg.
		var inner_radius := maxf(legs[goal_index].goal_radius, outgoing_distance * 0.28)
		var band_blend_width := maxf(GOAL_BLEND_WIDTH, outgoing_distance * 0.08)
		var outer_radius := inner_radius + band_blend_width
		for sample_z in range(sample_size.y):
			var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
			for sample_x in range(sample_size.x):
				var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
				var distance := Vector2(x, z).distance_to(goal_xzs[goal_index])
				if distance > outer_radius:
					continue
				var weight := 1.0
				if distance > inner_radius:
					var blend := (distance - inner_radius) / band_blend_width
					weight = 1.0 - blend * blend * (3.0 - 2.0 * blend)
				var height_index := sample_z * sample_size.x + sample_x
				heights[height_index] = lerpf(heights[height_index], target_rim, weight)
	return true


static func _minimum_height_in_radius(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		center: Vector2,
		radius: float
) -> float:
	var minimum := INF
	var sample_size := cell_count + Vector2i.ONE
	for sample_z in range(sample_size.y):
		var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
			if Vector2(x, z).distance_to(center) <= radius:
				minimum = minf(minimum, heights[sample_z * sample_size.x + sample_x])
	return minimum


static func _shape_authored_leg_corridors(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		route_graph: GeneratedRouteGraph,
		course: CannonGolfCourseData,
		goal_xzs: Array[Vector2],
		legs: Array[CannonGolfCourseLegData]
) -> bool:
	if route_graph == null or goal_xzs.size() != legs.size():
		return false
	var rim_heights := PackedFloat32Array()
	for index in range(goal_xzs.size()):
		var rim := _minimum_height_in_radius(
			heights, cell_count, bounds, goal_xzs[index], legs[index].goal_radius
		)
		if not is_finite(rim):
			return false
		rim_heights.append(rim)
	var sample_size := cell_count + Vector2i.ONE
	for leg_index in range(legs.size()):
		var start_xz: Vector2
		var start_y: float
		if leg_index == 0:
			var route_launcher := route_graph.route_position(
				legs[leg_index].route_index, legs[leg_index].launcher_route_t
			)
			var route_tangent := route_graph.route_tangent(
				legs[leg_index].route_index, legs[leg_index].launcher_route_t
			)
			if not route_launcher.is_finite() or not route_tangent.is_finite():
				return false
			var forward := Vector2(route_tangent.x, route_tangent.z).normalized()
			if forward.is_zero_approx():
				forward = Vector2.DOWN
			start_xz = Vector2(route_launcher.x, route_launcher.z) \
					+ forward * _cannon_front_standoff(course)
			start_y = course.terrain_origin.y
		else:
			start_xz = goal_xzs[leg_index - 1]
			start_y = rim_heights[leg_index - 1] - legs[leg_index - 1].goal_recess_depth
		var segment := goal_xzs[leg_index] - start_xz
		var segment_length := segment.length()
		if segment_length <= RELAY_LAUNCH_ADMISSION_EXCLUSION_RADIUS:
			return false
		var segment_length_squared := segment.length_squared()
		var target_y := rim_heights[leg_index]
		var corridor_half_width := maxf(legs[leg_index].goal_radius, 10.0)
		for sample_z in range(sample_size.y):
			var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
			for sample_x in range(sample_size.x):
				var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
				var point := Vector2(x, z)
				var t := (point - start_xz).dot(segment) / segment_length_squared
				if t < 0.0 or t > 1.0 or t * segment_length < RELAY_LAUNCH_ADMISSION_EXCLUSION_RADIUS:
					continue
				var distance := point.distance_to(start_xz + segment * t)
				if distance > corridor_half_width:
					continue
				var edge_t := clampf(distance / corridor_half_width, 0.0, 1.0)
				var weight := 1.0 - edge_t * edge_t * (3.0 - 2.0 * edge_t)
				var corridor_height := lerpf(start_y, target_y, t)
				var height_index := sample_z * sample_size.x + sample_x
				if heights[height_index] > corridor_height:
					heights[height_index] = lerpf(heights[height_index], corridor_height, weight)
	return true


static func _height_sample_nearest(
		heights: PackedFloat32Array, cell_count: Vector2i, bounds: Rect2, point: Vector2
) -> float:
	if not bounds.has_point(point):
		return NAN
	var x := clampi(roundi((point.x - bounds.position.x) / bounds.size.x * cell_count.x), 0, cell_count.x)
	var z := clampi(roundi((point.y - bounds.position.y) / bounds.size.y * cell_count.y), 0, cell_count.y)
	return heights[z * (cell_count.x + 1) + x]


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
				var outer_half := maxf((radius_ratio - 0.5) / 0.5, 0.0)
				var wall_profile := outer_half * outer_half
				heights[index] = source_rim_y - recess_depth \
						+ (recess_depth + lip_height) * wall_profile
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
				var outer_half := maxf((radius_ratio - 0.5) / 0.5, 0.0)
				var wall_profile := outer_half * outer_half
				heights[height_index] = source_rim_y - recess_depth \
						+ (recess_depth + lip_height) * wall_profile
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
		leg_index: int,
		goal_xzs: Array[Vector2]
) -> Variant:
	if topology == null or route_graph == null or leg == null \
			or leg_index < 0 or leg_index >= goal_xzs.size():
		return null
	if leg_index > 0:
		var previous_goal_surface: Variant = _topology_position_at(
			topology, goal_xzs[leg_index - 1]
		)
		if previous_goal_surface == null:
			return null
		var centered_position: Vector3 = previous_goal_surface
		centered_position.y += RELAY_LAUNCH_SURFACE_OFFSET
		return centered_position if centered_position.is_finite() else null
	var route_launcher := route_graph.route_position(leg.route_index, leg.launcher_route_t)
	if not route_launcher.is_finite():
		return null
	var launcher_xz := Vector2(route_launcher.x, route_launcher.z)
	if leg_index == 0:
		var route_tangent := route_graph.route_tangent(leg.route_index, leg.launcher_route_t)
		if not route_tangent.is_finite():
			return null
		var forward_xz := Vector2(route_tangent.x, route_tangent.z).normalized()
		if forward_xz.is_zero_approx():
			forward_xz = Vector2.DOWN
		launcher_xz += forward_xz * _cannon_front_standoff(course)
		var cannon_position := Vector3(launcher_xz.x, course.terrain_origin.y + 0.05, launcher_xz.y)
		return cannon_position if cannon_position.is_finite() else null
	var topology_position: Variant = _topology_position_at(topology, launcher_xz)
	if topology_position == null:
		return null
	var relay_position: Vector3 = topology_position
	return Vector3(relay_position.x, relay_position.y + 0.05, relay_position.z)


static func _cannon_front_standoff(course: CannonGolfCourseData) -> float:
	if course == null or course.generation_profile == null \
			or course.generation_profile.generation_contract == null:
		return CANNON_FRONT_STANDOFF
	return LONGITUDINAL_CANNON_FRONT_STANDOFF \
			if course.generation_profile.generation_contract.local_bounds.size.y >= 300.0 \
			else CANNON_FRONT_STANDOFF


static func _topology_position_at(topology: TerrainTopTopology, xz: Vector2) -> Variant:
	if topology == null or not xz.is_finite():
		return null
	var sample := topology.surface_sample_at_local(xz.x, xz.y, true)
	if sample.is_empty() or not (sample.get("point") is Vector3):
		return null
	var point: Vector3 = sample.point
	return point if point.is_finite() else null


static func _validate_leg_corridor(
		topology: TerrainTopTopology,
		leg: CannonGolfGeneratedCourseLeg,
		report_errors := true
) -> Dictionary:
	if topology == null or leg == null:
		return {}
	var points := PackedVector3Array()
	var leg_distance := Vector2(
		leg.launcher_position.x, leg.launcher_position.z
	).distance_to(Vector2(leg.goal_position.x, leg.goal_position.z))
	if leg_distance <= RELAY_LAUNCH_ADMISSION_EXCLUSION_RADIUS:
		return {}
	var minimum_t := maxf(
		0.25, (RELAY_LAUNCH_ADMISSION_EXCLUSION_RADIUS + 2.0) / leg_distance
	)
	for index in range(13):
		var t := lerpf(minimum_t, 1.0, float(index) / 12.0)
		var xz := Vector2(leg.launcher_position.x, leg.launcher_position.z).lerp(
			Vector2(leg.goal_position.x, leg.goal_position.z), t
		)
		var surface_y := topology.height_at_local(xz.x, xz.y)
		if not is_finite(surface_y):
			return {}
		points.append(Vector3(xz.x, surface_y, xz.y))
	return _validate_explicit_launch_envelope(
		points, leg.launcher_position, leg.shot_axis_yaw_degrees, report_errors
	)


static func _validate_union_launch_envelope(
		points: PackedVector3Array,
		legs: Array[CannonGolfGeneratedCourseLeg],
		report_errors := true
) -> Dictionary:
	if points.is_empty() or legs.is_empty():
		return {}
	var minimum_range_margin := INF
	var minimum_yaw_margin := INF
	var minimum_height_margin := INF
	var farthest_distance := 0.0
	var excluded_point_count := 0
	var height_interval_cache := {}
	for point in points:
		if _is_relay_launch_exclusion(point, legs):
			excluded_point_count += 1
			continue
		var accepted: Dictionary = {}
		var first_index := _nearest_leg_index(point, legs)
		for offset in range(legs.size()):
			var leg := legs[(first_index + offset) % legs.size()]
			var admission := _admit_union_point(
				point, leg, RELAY_CENTERED_UNION_HEIGHT_MARGIN, height_interval_cache
			)
			if bool(admission.passed):
				accepted = admission
				break
		if accepted.is_empty():
			var rejections: Array[Dictionary] = []
			for leg in legs:
				rejections.append(_admit_union_point(
					point, leg, RELAY_CENTERED_UNION_HEIGHT_MARGIN, height_interval_cache
				))
			if report_errors:
				push_error(
					"Relay terrain point %s is outside every launch envelope: %s"
					% [point, rejections]
				)
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
	var point_xz := Vector2(point.x, point.z)
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(legs.size()):
		var launcher := legs[index].launcher_position
		var distance := point_xz.distance_squared_to(Vector2(launcher.x, launcher.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


static func _admit_union_point(
		point: Vector3,
		leg: CannonGolfGeneratedCourseLeg,
		required_height_margin: float = CannonGolfBallistics.REQUIRED_HEIGHT_MARGIN,
		height_interval_cache: Dictionary = {}
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
	var relative_height := point.y - leg.launcher_position.y
	var distance_key := roundi(distance * 2.0)
	var sampled_key := "sampled:%d" % distance_key
	var sampled_interval := height_interval_cache.get(sampled_key, Vector2(INF, -INF)) as Vector2
	if not height_interval_cache.has(sampled_key):
		sampled_interval = CannonGolfBallistics.sampled_reachable_height_interval(distance)
		height_interval_cache[sampled_key] = sampled_interval
	var height_margin := minf(
		relative_height - sampled_interval.x,
		sampled_interval.y - relative_height
	) if sampled_interval.is_finite() and sampled_interval.x <= sampled_interval.y else -INF
	var resolved_interval := sampled_interval
	if height_margin < required_height_margin:
		var exact_key := "exact:%d" % distance_key
		resolved_interval = height_interval_cache.get(exact_key, Vector2(INF, -INF)) as Vector2
		if not height_interval_cache.has(exact_key):
			resolved_interval = CannonGolfBallistics.reachable_height_interval(distance)
			height_interval_cache[exact_key] = resolved_interval
		height_margin = minf(
			relative_height - resolved_interval.x,
			resolved_interval.y - relative_height
		) if resolved_interval.is_finite() and resolved_interval.x <= resolved_interval.y else -INF
	var in_front := absf(yaw_offset) < 90.0
	var yaw_valid := yaw_margin >= CannonGolfBallistics.REQUIRED_YAW_MARGIN_DEGREES
	var range_valid := range_margin >= CannonGolfBallistics.REQUIRED_RANGE_MARGIN
	var height_valid := height_margin >= required_height_margin
	return {
		"passed": in_front and yaw_valid and range_valid and height_valid,
		"in_front": in_front,
		"yaw_valid": yaw_valid,
		"range_valid": range_valid,
		"height_valid": height_valid,
		"distance": distance,
		"yaw_offset_degrees": yaw_offset,
		"relative_height": relative_height,
		"height_interval": resolved_interval,
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


static func _validate_relay_launcher_centers(
		legs: Array[CannonGolfGeneratedCourseLeg]
) -> bool:
	for index in range(1, legs.size()):
		var previous_goal := legs[index - 1].goal_position
		var launcher_position := legs[index].launcher_position
		if not Vector2(launcher_position.x, launcher_position.z).is_equal_approx(
			Vector2(previous_goal.x, previous_goal.z)
		) or not is_equal_approx(
			launcher_position.y, previous_goal.y + RELAY_LAUNCH_SURFACE_OFFSET
		):
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


static func _terrain_admission_points(
		topology: TerrainTopTopology, terrain_base_y: float = TERRAIN_BASE_Y
) -> PackedVector3Array:
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
		points.append(Vector3(top.x, terrain_base_y, top.z))
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
		shot_axis_yaw_degrees: float,
		report_errors := true
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
			if report_errors:
				push_error(
					"Explicit corridor point %s failed from launcher %s: %s"
					% [point, launcher_position, admission]
				)
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
