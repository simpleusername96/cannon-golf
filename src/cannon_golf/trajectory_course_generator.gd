class_name CannonGolfTrajectoryCourseGenerator
extends RefCounted

## Fast constructive authoring path: choose flight legs first, then build one
## connected heightfield below those flights. It performs no candidate beam or
## live-physics search.

const ALGORITHM_VERSION := 3
const TERRAIN_SHADER := preload("res://src/cannon_golf/cannon_golf_terrain.gdshader")
const GOAL_VISIBILITY_APRON := 14.0
const GOAL_APRON_MAXIMUM_RISE_PER_METRE := 0.45
const CORRIDOR_HALF_WIDTH := 18.0
const CORRIDOR_CLEARANCE := 3.0
const LANDING_CENTER_CLEARANCE := 0.35
const START_SUPPORT_RADIUS := 9.0
const COURSE_DEADLINE_MSEC := 60000
const SETUP_ELEVATIONS := [25.0, 28.0, 31.0, 34.0, 37.0, 40.0, 43.0, 46.0, 49.0, 52.0, 55.0]
const SETUP_POWERS := [50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0, 90.0, 95.0]
const DELTA_TARGETS := [-16.0, 8.0, 20.0, -10.0, 14.0, 2.0]
const DEEP_RELAY_MINIMUM_RELIEF := 80.0
const DEEP_RELAY_MINIMUM_RIM_RISE := 25.0
const LATE_COURSE_MINIMUM_RELIEF := 80.0
const RELIEF_BUILD_MARGIN := 12.0


static func build(course: CannonGolfCourseData, deadline_msec: int = 0) -> Dictionary:
	if course == null or not course.is_valid():
		return {}
	var started_msec := Time.get_ticks_msec()
	var deadline := deadline_msec if deadline_msec > 0 else started_msec + COURSE_DEADLINE_MSEC
	var course_index := CannonGolfCourseCatalog.index_of(course.course_id)
	if course_index < 0:
		return {}
	var contract = course.generation_profile.generation_contract
	var cell_count: Vector2i = contract.cell_count
	var local_bounds := Rect2(
		contract.local_bounds.position * course.terrain_horizontal_scale
				+ Vector2(course.terrain_origin.x, course.terrain_origin.z),
		contract.local_bounds.size * course.terrain_horizontal_scale
	)
	var plan := _plan_legs(course, course_index, local_bounds)
	if plan.is_empty() or _expired(deadline):
		return {}
	var heights := _build_heights(
		course, course_index, plan, cell_count, local_bounds, deadline
	)
	if heights.is_empty() or _expired(deadline) \
			or not _height_contracts_pass(course, course_index, plan, heights):
		return {}
	var footprint := PackedByteArray()
	footprint.resize(cell_count.x * cell_count.y)
	footprint.fill(1)
	var topology := TerrainTopTopology.build(cell_count, local_bounds, heights, footprint)
	if topology == null or not topology.is_valid() or _expired(deadline):
		return {}
	var route_graph := _build_route_graph(course.course_id, plan)
	if route_graph == null or not route_graph.is_valid():
		return {}
	var layout := GeneratedStageLayout.new()
	layout.profile_id = course.generation_profile.profile_id
	layout.profile_version = StageGenerationContract.CONTRACT_VERSION
	layout.layout_version = StageGenerationContract.CONTRACT_VERSION
	layout.terrain_seed = course.terrain_seed_window.x
	layout.cell_count = cell_count
	layout.local_bounds = local_bounds
	layout.heights = heights
	layout.top_topology = topology
	layout.route_graph = route_graph
	layout.play_bounds = PlayBoundsSpec.new()
	if not layout.install_footprint(footprint) or not layout.is_valid():
		return {}
	var minimum_height := _minimum_height(heights)
	var geometry := TerrainGeometryFactory.build(layout, minf(-34.0, minimum_height - 18.0))
	if geometry == null or not geometry.is_valid() or _expired(deadline):
		return {}
	_apply_material(geometry.render_mesh, course)
	var generated := _assemble_generated_course(
		course, plan, layout, geometry, route_graph, heights, footprint,
		cell_count, local_bounds,
		Time.get_ticks_msec() - started_msec
	)
	if generated == null or not generated.is_sealed() or _expired(deadline):
		return {}
	var intended_setups: Array[Vector3] = []
	for leg_data in plan:
		intended_setups.append(leg_data.setup as Vector3)
	return {
		"generated": generated,
		"intended_setups": intended_setups,
		"elapsed_msec": Time.get_ticks_msec() - started_msec,
	}


static func _plan_legs(
	course: CannonGolfCourseData, course_index: int, local_bounds: Rect2
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lateral := minf(
		65.0 + float(course_index % 3) * 5.0,
		local_bounds.size.x * 0.36
	)
	if course.course_id == &"deep_relay":
		lateral = minf(lateral, local_bounds.size.x * 0.285)
	var z_step := local_bounds.size.y / float(course.leg_count() + 1)
	var start_z := local_bounds.end.y - minf(18.0, local_bounds.size.y * 0.12)
	var launcher := Vector3(
		local_bounds.get_center().x + (-lateral if course_index % 2 == 0 else lateral),
		course.terrain_origin.y + 8.05 + float(course_index % 3) * 2.0,
		start_z
	)
	var initial_launcher_y := launcher.y
	for leg_index in range(course.leg_count()):
		var authored_leg := course.leg_at(leg_index)
		var goal_x := local_bounds.get_center().x * 2.0 - launcher.x
		var goal_z := start_z - float(leg_index + 1) * z_step
		var distance := Vector2(launcher.x, launcher.z).distance_to(Vector2(goal_x, goal_z))
		var goal_radius := (authored_leg.bowl_radius_range.x + authored_leg.bowl_radius_range.y) * 0.5
		var goal_recess := (authored_leg.bowl_recess_depth_range.x \
				+ authored_leg.bowl_recess_depth_range.y) * 0.5
		var goal_lip_height := (authored_leg.bowl_lip_height_range.x \
				+ authored_leg.bowl_lip_height_range.y) * 0.5
		var desired_landing_delta := _desired_landing_delta(
			course, authored_leg, launcher.y, initial_launcher_y, course_index, leg_index,
			goal_recess
		)
		var choice := _choose_setup(
			distance, goal_radius, goal_recess, goal_lip_height, desired_landing_delta
		)
		if choice.is_empty():
			return []
		var relative_center_height := float(choice.center_height)
		var goal_floor_y := launcher.y + relative_center_height \
				- CannonGolfBallistics.BALL_RADIUS - LANDING_CENTER_CLEARANCE
		var goal := Vector3(goal_x, goal_floor_y, goal_z)
		var delta := Vector2(goal.x - launcher.x, goal.z - launcher.z)
		var yaw := rad_to_deg(atan2(delta.x, -delta.y))
		result.append({
			"launcher": launcher,
			"goal": goal,
			"goal_radius": goal_radius,
			"rim_y": goal_floor_y + goal_recess,
			"lip_y": goal_floor_y + goal_recess + goal_lip_height,
			"goal_recess": goal_recess,
			"goal_lip_height": goal_lip_height,
			"rim_band": authored_leg.relative_rim_band,
			"yaw": yaw,
			"distance": distance,
			"setup": choice.setup,
			"near_clearance": choice.near_clearance,
			"default_separation": choice.default_separation,
		})
		launcher = goal + Vector3.UP * 0.05
	return result


static func _desired_landing_delta(
	course: CannonGolfCourseData,
	authored_leg: CannonGolfCourseLegData,
	launcher_y: float,
	initial_launcher_y: float,
	course_index: int,
	leg_index: int,
	goal_recess: float
) -> float:
	if course.course_id == &"deep_relay":
		return DEEP_RELAY_MINIMUM_RIM_RISE - goal_recess + 2.0
	var band_target_rim := initial_launcher_y \
			+ float(authored_leg.relative_rim_band - 1) * 20.0
	var band_delta := band_target_rim - launcher_y - goal_recess
	if course.leg_count() > 1:
		return band_delta
	var contour_delta := float(
		DELTA_TARGETS[(course_index + leg_index) % DELTA_TARGETS.size()]
	)
	return contour_delta


static func _choose_setup(
	distance: float,
	goal_radius: float,
	goal_recess: float,
	goal_lip_height: float,
	desired_delta: float
) -> Dictionary:
	var best := {}
	var best_score := INF
	for elevation in SETUP_ELEVATIONS:
		for power in SETUP_POWERS:
			var setup := Vector3(50.0, elevation, power)
			var candidate := _evaluate_setup(
				distance, goal_radius, goal_recess, goal_lip_height, setup
			)
			if candidate.is_empty():
				continue
			var score := absf(float(candidate.landing_delta) - desired_delta)
			if score < best_score:
				best_score = score
				best = candidate
	return best


static func _evaluate_setup(
	distance: float,
	goal_radius: float,
	goal_recess: float,
	goal_lip_height: float,
	setup: Vector3
) -> Dictionary:
	var center_height := CannonGolfBallistics.height_for_setup_at_distance(
		distance, setup.y, setup.z
	)
	var near_distance := distance - goal_radius - 2.0
	var near_height := CannonGolfBallistics.height_for_setup_at_distance(
		near_distance, setup.y, setup.z
	)
	var before := CannonGolfBallistics.height_for_setup_at_distance(
		distance - 1.0, setup.y, setup.z
	)
	var after := CannonGolfBallistics.height_for_setup_at_distance(
		distance + 1.0, setup.y, setup.z
	)
	var default_height := CannonGolfBallistics.height_for_setup_at_distance(
		distance, 50.0, 50.0
	)
	if not is_finite(center_height) \
			or not is_finite(near_height) or not is_finite(before) or not is_finite(after) \
			or after >= before:
		return {}
	var near_clearance := near_height - center_height
	var required_clearance := goal_recess + goal_lip_height \
			+ CannonGolfBallistics.BALL_RADIUS + LANDING_CENTER_CLEARANCE
	var default_separation := absf(default_height - center_height) \
			if is_finite(default_height) else INF
	if near_clearance < required_clearance or default_separation < 6.0:
		return {}
	var landing_delta := center_height - CannonGolfBallistics.BALL_RADIUS \
			- LANDING_CENTER_CLEARANCE
	return {
		"setup": setup,
		"center_height": center_height,
		"landing_delta": landing_delta,
		"near_clearance": near_clearance,
		"default_separation": default_separation,
	}


static func _build_heights(
		course: CannonGolfCourseData,
		course_index: int,
		plan: Array[Dictionary],
		cell_count: Vector2i,
		local_bounds: Rect2,
		deadline_msec: int
) -> PackedFloat32Array:
	var natural_heights := PackedFloat32Array()
	var sample_size := cell_count + Vector2i.ONE
	natural_heights.resize(sample_size.x * sample_size.y)
	for sample_z in range(sample_size.y):
		if _expired(deadline_msec):
			return PackedFloat32Array()
		var z := lerpf(
			local_bounds.position.y, local_bounds.end.y,
			float(sample_z) / float(cell_count.y)
		)
		for sample_x in range(sample_size.x):
			var x := lerpf(
				local_bounds.position.x, local_bounds.end.x,
				float(sample_x) / float(cell_count.x)
			)
			var point := Vector2(x, z)
			var height := _natural_height(
				course_index, course.terrain_seed_window.x, point, local_bounds
			)
			for feature_resource in course.landform_features:
				height = _apply_landform_height(
					height, point, local_bounds,
					feature_resource as CannonGolfCourseLandformFeature
				)
			natural_heights[sample_z * sample_size.x + sample_x] = height
	var natural_minimum := _minimum_height(natural_heights)
	var natural_relief := _maximum_height(natural_heights) - natural_minimum
	if natural_relief <= 0.0:
		return PackedFloat32Array()
	var required_relief := _minimum_required_relief(course, course_index)
	var relief_scale := maxf(1.0, (required_relief + RELIEF_BUILD_MARGIN) / natural_relief)
	var heights := natural_heights.duplicate()
	var start_surface_y := float(plan[0].launcher.y) - 0.05
	for sample_z in range(sample_size.y):
		if _expired(deadline_msec):
			return PackedFloat32Array()
		var z := lerpf(
			local_bounds.position.y, local_bounds.end.y,
			float(sample_z) / float(cell_count.y)
		)
		for sample_x in range(sample_size.x):
			var x := lerpf(
				local_bounds.position.x, local_bounds.end.x,
				float(sample_x) / float(cell_count.x)
			)
			var point := Vector2(x, z)
			var sample_index := sample_z * sample_size.x + sample_x
			var height := natural_minimum \
					+ (natural_heights[sample_index] - natural_minimum) * relief_scale
			for leg_data in plan:
				height = _protect_flight_corridor(height, point, leg_data)
			var start_xz := Vector2(plan[0].launcher.x, plan[0].launcher.z)
			var start_distance := point.distance_to(start_xz)
			if start_distance < START_SUPPORT_RADIUS:
				var support_inner := START_SUPPORT_RADIUS * 0.45
				height = start_surface_y if start_distance <= support_inner else lerpf(
					start_surface_y,
					height,
					_smoothstep(
						(start_distance - support_inner)
						/ (START_SUPPORT_RADIUS - support_inner)
					)
				)
			for leg_data in plan:
				height = _carve_goal(height, point, leg_data)
			heights[sample_index] = height
	return heights


static func _minimum_required_relief(course: CannonGolfCourseData, course_index: int) -> float:
	var profile_minimum := float(course.generation_profile.accepted_height_range.x)
	var vertical_progress := clampf(
		(course.terrain_vertical_scale - 0.45) / (1.35 - 0.45), 0.0, 1.0
	)
	var scale_minimum := lerpf(60.0, 80.0, vertical_progress)
	var required := maxf(profile_minimum, scale_minimum)
	if course.course_id == &"deep_relay" or course_index >= 4:
		required = maxf(required, LATE_COURSE_MINIMUM_RELIEF)
	return required


static func _height_contracts_pass(
	course: CannonGolfCourseData,
	course_index: int,
	plan: Array[Dictionary],
	heights: PackedFloat32Array
) -> bool:
	var relief := _maximum_height(heights) - _minimum_height(heights)
	if relief + 0.01 < _minimum_required_relief(course, course_index):
		return false
	if course.course_id == &"deep_relay":
		for leg_data in plan:
			if float(leg_data.rim_y) - float(leg_data.launcher.y) + 0.01 \
					< DEEP_RELAY_MINIMUM_RIM_RISE:
				return false
	elif plan.size() >= 3:
		var has_descending_leg := false
		for leg_data in plan:
			if float(leg_data.rim_y) < float(leg_data.launcher.y):
				has_descending_leg = true
				break
		if not has_descending_leg:
			return false
	for left_index in range(plan.size()):
		for right_index in range(left_index + 1, plan.size()):
			var left_band := int(plan[left_index].rim_band)
			var right_band := int(plan[right_index].rim_band)
			var left_rim := float(plan[left_index].rim_y)
			var right_rim := float(plan[right_index].rim_y)
			if left_band == right_band and absf(left_rim - right_rim) > 16.0:
				return false
			if left_band < right_band and right_rim - left_rim < 12.0:
				return false
			if left_band > right_band and left_rim - right_rim < 12.0:
				return false
	return true


static func _natural_height(
	course_index: int, seed: int, point: Vector2, local_bounds: Rect2
) -> float:
	var canonical_point := Vector2(
		(point.x - local_bounds.get_center().x) / local_bounds.size.x * 210.0,
		(point.y - local_bounds.get_center().y) / local_bounds.size.y * 320.0
	)
	var phase := float(posmod(seed, 997)) * 0.013
	var base := 7.0 + sin(canonical_point.x * 0.055 + phase) * 4.0 \
			+ cos(canonical_point.y * 0.038 - phase * 0.7) * 5.0 \
			+ sin((canonical_point.x + canonical_point.y) * 0.027 + phase * 1.7) * 3.0
	var style := course_index % 5
	if style == 0:
		base += 38.0 * _gaussian(canonical_point, Vector2(-28.0, -65.0), Vector2(34.0, 82.0))
		base += 22.0 * _gaussian(canonical_point, Vector2(45.0, -145.0), Vector2(30.0, 52.0))
	elif style == 1:
		base += 34.0 * _gaussian(canonical_point, Vector2(-70.0, -80.0), Vector2(30.0, 95.0))
		base += 34.0 * _gaussian(canonical_point, Vector2(70.0, -80.0), Vector2(30.0, 95.0))
		base -= 13.0 * _gaussian(canonical_point, Vector2(0.0, -75.0), Vector2(46.0, 105.0))
	elif style == 2:
		base += 31.0 * _gaussian(canonical_point, Vector2(18.0, -95.0), Vector2(58.0, 78.0))
		base = roundf(base / 6.0) * 6.0
	elif style == 3:
		base += 45.0 * _gaussian(canonical_point, Vector2(-48.0, -82.0), Vector2(26.0, 42.0))
		base += 41.0 * _gaussian(canonical_point, Vector2(52.0, -130.0), Vector2(28.0, 46.0))
	else:
		base += 30.0 * _gaussian(canonical_point, Vector2(0.0, -110.0), Vector2(86.0, 120.0))
		base -= 24.0 * _gaussian(canonical_point, Vector2(0.0, -105.0), Vector2(40.0, 62.0))
	return base


static func _apply_landform_height(
	height: float,
	point: Vector2,
	local_bounds: Rect2,
	feature: CannonGolfCourseLandformFeature
) -> float:
	if feature == null:
		return height
	var anchor := Vector2(
		local_bounds.get_center().x + feature.route_offset.x,
		lerpf(local_bounds.position.y, local_bounds.end.y, feature.route_t)
	)
	var radius := maxf(feature.radius, 1.0)
	var normalized_distance := point.distance_to(anchor) / radius
	if normalized_distance >= 1.0:
		return height
	var weight := _smoothstep(1.0 - normalized_distance)
	var amplitude := feature.amplitude
	match feature.kind:
		CannonGolfCourseLandformFeature.Kind.VALLEY, CannonGolfCourseLandformFeature.Kind.BASIN:
			return height - amplitude * weight
		CannonGolfCourseLandformFeature.Kind.SADDLE:
			var lateral := absf(point.x - anchor.x) / radius
			return height + amplitude * weight * (lateral * 2.0 - 0.65)
		CannonGolfCourseLandformFeature.Kind.PLATEAU:
			return height + amplitude * pow(weight, maxf(feature.flatness, 0.05))
		CannonGolfCourseLandformFeature.Kind.TERRACE:
			return height + roundf(amplitude * weight / 4.0) * 4.0
		_:
			return height + amplitude * weight


static func _protect_flight_corridor(
		height: float, point: Vector2, leg_data: Dictionary
) -> float:
	var start := Vector2(leg_data.launcher.x, leg_data.launcher.z)
	var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
	var delta := goal - start
	var length_squared := delta.length_squared()
	if length_squared <= 0.0:
		return height
	var t := clampf((point - start).dot(delta) / length_squared, 0.0, 1.0)
	if t <= 0.04 or t >= 0.90:
		return height
	var center := start + delta * t
	var lateral_distance := point.distance_to(center)
	if lateral_distance >= CORRIDOR_HALF_WIDTH:
		return height
	var setup: Vector3 = leg_data.setup
	var path_height := float(leg_data.launcher.y) \
			+ CannonGolfBallistics.height_for_setup_at_distance(
				float(leg_data.distance) * t, setup.y, setup.z
			)
	if not is_finite(path_height):
		return height
	var corridor_cap := path_height - CannonGolfBallistics.BALL_RADIUS \
			- CORRIDOR_CLEARANCE + lateral_distance * 0.16
	return minf(height, corridor_cap)


static func _carve_goal(height: float, point: Vector2, leg_data: Dictionary) -> float:
	var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
	var radius := float(leg_data.goal_radius)
	var distance := point.distance_to(goal)
	if distance >= radius + GOAL_VISIBILITY_APRON:
		return height
	var floor_y := float(leg_data.goal.y)
	var lip_y := float(leg_data.lip_y)
	if distance <= radius:
		var inner_radius := radius * 0.35
		if distance <= inner_radius:
			return floor_y
		return lerpf(
			floor_y,
			lip_y,
			_smoothstep((distance - inner_radius) / (radius - inner_radius))
		)
	var apron_distance := distance - radius
	var outer_t := _smoothstep(apron_distance / GOAL_VISIBILITY_APRON)
	var apron_cap := lip_y + apron_distance * GOAL_APRON_MAXIMUM_RISE_PER_METRE
	return lerpf(lip_y, minf(height, apron_cap), outer_t)


static func _build_route_graph(course_id: StringName, plan: Array[Dictionary]) -> GeneratedRouteGraph:
	var nodes: Array[GeneratedRouteNode] = []
	var edges: Array[GeneratedRouteEdge] = []
	var summit_id := GeneratedRouteNode.summit_id(course_id)
	var final_goal: Vector3 = plan[-1].goal
	nodes.append(GeneratedRouteNode.new(
		summit_id, final_goal, -1, 0, GeneratedRouteNode.Kind.SUMMIT
	))
	var previous_id := summit_id
	var station := 1
	for plan_index in range(plan.size() - 2, -1, -1):
		var node_id := GeneratedRouteNode.route_node_id(course_id, 0, station)
		var node_position: Vector3 = plan[plan_index].goal
		nodes.append(GeneratedRouteNode.new(
			node_id, node_position, 0, station, GeneratedRouteNode.Kind.CORRIDOR
		))
		edges.append(GeneratedRouteEdge.new(
			GeneratedRouteEdge.stable_id(course_id, 0, edges.size()),
			previous_id, node_id, 0, edges.size(), StageRouteProfile.Role.PRIMARY, 30.0
		))
		previous_id = node_id
		station += 1
	var exit_id := GeneratedRouteNode.route_node_id(course_id, 0, station)
	var start_launcher: Vector3 = plan[0].launcher
	nodes.append(GeneratedRouteNode.new(
		exit_id, start_launcher, 0, station, GeneratedRouteNode.Kind.EXIT
	))
	edges.append(GeneratedRouteEdge.new(
		GeneratedRouteEdge.stable_id(course_id, 0, edges.size()),
		previous_id, exit_id, 0, edges.size(), StageRouteProfile.Role.PRIMARY, 30.0
	))
	return GeneratedRouteGraph.new(nodes, edges)


static func _assemble_generated_course(
		course: CannonGolfCourseData,
		plan: Array[Dictionary],
		layout: GeneratedStageLayout,
		geometry: TerrainGeometry,
		route_graph: GeneratedRouteGraph,
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2,
	elapsed_msec: int
) -> CannonGolfGeneratedCourse:
	var result := CannonGolfGeneratedCourse.new()
	result.layout = layout
	result.geometry = geometry
	result.route_graph = route_graph
	result.source_route_graph = route_graph
	result.source_heights = heights
	result.source_footprint = footprint
	result.landform_metrics = _measure_landforms(
		course, heights, cell_count, local_bounds
	)
	var admission_points := PackedVector3Array()
	var minimum_range_margin := INF
	var minimum_height_margin := INF
	var farthest_distance := 0.0
	for index in range(plan.size()):
		var leg_data := plan[index]
		var leg := CannonGolfGeneratedCourseLeg.new()
		leg.goal_position = leg_data.goal
		leg.goal_rim_y = float(leg_data.rim_y)
		leg.goal_lip_y = float(leg_data.lip_y)
		leg.goal_radius = float(leg_data.goal_radius)
		leg.launcher_position = leg_data.launcher
		leg.shot_axis_yaw_degrees = float(leg_data.yaw)
		var leg_bounds := AABB(leg.launcher_position, Vector3(0.01, 0.01, 0.01))
		leg_bounds = leg_bounds.expand(leg.goal_position).grow(30.0)
		leg.frame_bounds = leg_bounds
		var range_margin := CannonGolfBallistics.maximum_horizontal_range() \
				- float(leg_data.distance)
		var height_margin := float(leg_data.near_clearance) \
				- float(leg_data.goal_recess) - float(leg_data.goal_lip_height)
		leg.corridor_admission = {
			"point_count": 16,
			"minimum_range_margin": range_margin,
			"minimum_yaw_margin_degrees": 80.0,
			"minimum_height_margin": height_margin,
			"farthest_distance": float(leg_data.distance),
		}
		result.add_leg(leg)
		admission_points.append(leg.launcher_position)
		admission_points.append(leg.goal_position)
		minimum_range_margin = minf(minimum_range_margin, range_margin)
		minimum_height_margin = minf(minimum_height_margin, height_margin)
		farthest_distance = maxf(farthest_distance, float(leg_data.distance))
	result.admission_points = admission_points
	result.union_range_metrics = {
		"point_count": admission_points.size(),
		"excluded_point_count": _count_relay_excluded_points(
			plan, cell_count, local_bounds
		),
		"minimum_range_margin": minimum_range_margin,
		"minimum_yaw_margin_degrees": 80.0,
		"minimum_height_margin": minimum_height_margin,
		"farthest_distance": farthest_distance,
		"generation_msec": elapsed_msec,
		"algorithm_version": ALGORITHM_VERSION,
	}
	var minimum_height := _minimum_height(heights)
	var maximum_height := _maximum_height(heights)
	result.content_bounds = AABB(
		Vector3(local_bounds.position.x, minimum_height, local_bounds.position.y),
		Vector3(local_bounds.size.x, maximum_height - minimum_height, local_bounds.size.y)
	).grow(0.01)
	var expanded_play_bounds := result.content_bounds.grow(24.0)
	expanded_play_bounds.size.y += 150.0
	result.play_bounds = expanded_play_bounds
	if not result.is_valid():
		return null
	result.seal()
	return result


static func _count_relay_excluded_points(
	plan: Array[Dictionary], cell_count: Vector2i, local_bounds: Rect2
) -> int:
	if plan.size() < 2:
		return 0
	var count := 0
	for sample_z in range(cell_count.y + 1):
		var z := lerpf(
			local_bounds.position.y, local_bounds.end.y,
			float(sample_z) / float(cell_count.y)
		)
		for sample_x in range(cell_count.x + 1):
			var x := lerpf(
				local_bounds.position.x, local_bounds.end.x,
				float(sample_x) / float(cell_count.x)
			)
			for leg_index in range(1, plan.size()):
				var launcher: Vector3 = plan[leg_index].launcher
				if Vector2(x, z).distance_to(Vector2(launcher.x, launcher.z)) <= 30.0:
					count += 1
					break
	return count


static func _measure_landforms(
	course: CannonGolfCourseData,
	heights: PackedFloat32Array,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> Dictionary:
	var metrics: Dictionary = {}
	var sample_size := cell_count + Vector2i.ONE
	for feature_resource in course.landform_features:
		var feature := feature_resource as CannonGolfCourseLandformFeature
		if feature == null:
			continue
		var anchor := Vector2(
			local_bounds.get_center().x + feature.route_offset.x,
			lerpf(local_bounds.position.y, local_bounds.end.y, feature.route_t)
		)
		var sample_x := clampi(
			roundi((anchor.x - local_bounds.position.x) / local_bounds.size.x * cell_count.x),
			0,
			cell_count.x
		)
		var sample_z := clampi(
			roundi((anchor.y - local_bounds.position.y) / local_bounds.size.y * cell_count.y),
			0,
			cell_count.y
		)
		metrics[feature.feature_id] = {
			"kind": feature.kind,
			"sample_height": heights[sample_z * sample_size.x + sample_x],
			"radius": feature.radius,
			"amplitude": feature.amplitude,
		}
	return metrics


static func _apply_material(mesh: ArrayMesh, course: CannonGolfCourseData) -> void:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter(&"rock_color", course.terrain_color)
	material.set_shader_parameter(&"accent_color", course.terrain_accent_color)
	material.set_shader_parameter(&"shell_color", course.terrain_accent_color.darkened(0.48))
	mesh.surface_set_material(0, material)


static func _gaussian(point: Vector2, center: Vector2, radius: Vector2) -> float:
	var delta := (point - center) / radius
	return exp(-0.5 * delta.length_squared())


static func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _minimum_height(heights: PackedFloat32Array) -> float:
	var value := INF
	for height in heights:
		value = minf(value, height)
	return value


static func _maximum_height(heights: PackedFloat32Array) -> float:
	var value := -INF
	for height in heights:
		value = maxf(value, height)
	return value


static func _expired(deadline_msec: int) -> bool:
	return Time.get_ticks_msec() >= deadline_msec
