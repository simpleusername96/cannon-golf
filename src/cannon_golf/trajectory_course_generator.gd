class_name CannonGolfTrajectoryCourseGenerator
extends RefCounted

## Fast constructive authoring path: choose flight legs first, then build one
## connected heightfield below those flights. It performs no candidate beam or
## live-physics search.

const ALGORITHM_VERSION := 8
const TERRAIN_SHADER := preload("res://src/cannon_golf/cannon_golf_terrain.gdshader")
const PLATE_SUPPORT_DEPTH := 0.18
const PLATE_TERRAIN_SHOULDER := 16.0
const PLATE_SUPPORT_BLEND := 44.0
const PLATE_INCOMING_BLEND := 56.0
const PLATE_INCOMING_HALF_ANGLE := deg_to_rad(42.0)
const CORRIDOR_HALF_WIDTH := 18.0
const CORRIDOR_CLEARANCE := 3.0
const LANDING_CENTER_CLEARANCE := 0.35
const START_SUPPORT_INNER_RADIUS := 12.0
const START_SUPPORT_RADIUS := 42.0
const COURSE_DEADLINE_MSEC := 60000
const SETUP_ELEVATIONS := [25.0, 28.0, 31.0, 34.0, 37.0, 40.0, 43.0, 46.0, 49.0, 52.0, 55.0]
const SETUP_POWERS := [50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0, 90.0, 95.0]
const DELTA_TARGETS := [-16.0, 8.0, 20.0, -10.0, 14.0, 2.0]
const DEEP_RELAY_MINIMUM_RELIEF := 80.0
const DEEP_RELAY_MINIMUM_RIM_RISE := 25.0
const COURSE_MINIMUM_RELIEF := [60.0, 65.0, 80.0, 90.0, 100.0, 112.0, 124.0, 136.0, 148.0, 160.0]
const MAXIMUM_RELIEF_MARGIN := 16.0
const RELIEF_TARGET_MARGIN := 8.0
const MAXIMUM_ADJACENT_SLOPE_DEGREES := 60.0
const P95_ADJACENT_SLOPE_DEGREES := 42.0
const PROJECTED_ADJACENT_SLOPE_DEGREES := 24.0
const MAXIMUM_STEEP_SAMPLE_FRACTION := 0.03
const STEEP_SAMPLE_SLOPE_DEGREES := 45.0
const SURFACE_FILTER_PASSES := 8
const SURFACE_FILTER_BLEND := 0.42
const SLOPE_PROJECTION_PASSES := 96
const RELIEF_REBALANCE_PASSES := 8


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
			or not _height_contracts_pass(course, course_index, plan, heights, cell_count, local_bounds):
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
		var goal_recess := PLATE_SUPPORT_DEPTH
		var goal_lip_height := clampf(
			(authored_leg.bowl_lip_height_range.x + authored_leg.bowl_lip_height_range.y) * 0.5,
			0.9,
			1.3
		)
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
			"rim_y": goal_floor_y,
			"lip_y": goal_floor_y + goal_lip_height,
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
	var required_clearance := goal_recess + goal_lip_height + maxf(
		CannonGolfBallistics.BALL_RADIUS + LANDING_CENTER_CLEARANCE,
		CannonGolfBallistics.REQUIRED_HEIGHT_MARGIN
	)
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
	# Broad, readable goal shoulders replace part of the raw macro relief. Build
	# that bounded loss into the source landform instead of steepening the goal
	# neighborhoods after they have been flattened.
	# Normalize excess relief as well as insufficient relief. Horizontal expansion
	# alone cannot make a locally over-tall feature gentle.
	var target_relief := required_relief + RELIEF_TARGET_MARGIN
	var relief_scale := target_relief / natural_relief
	var heights := natural_heights.duplicate()
	var start_surface_y := float(plan[0].launcher.y) - 0.05
	var support_grid_margin := maxf(
		local_bounds.size.x / float(cell_count.x),
		local_bounds.size.y / float(cell_count.y)
	)
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
				height = start_surface_y if start_distance <= START_SUPPORT_INNER_RADIUS else lerpf(
					start_surface_y,
					height,
					_smoothstep(
						(start_distance - START_SUPPORT_INNER_RADIUS)
						/ (START_SUPPORT_RADIUS - START_SUPPORT_INNER_RADIUS)
					)
				)
			for leg_data in plan:
				height = _fit_goal_plate_support(height, point, leg_data, support_grid_margin)
			heights[sample_index] = height
	var constrained := _constrain_final_heights(heights, cell_count, local_bounds, plan, deadline_msec)
	return _restore_relief_band(
		constrained, cell_count, local_bounds, plan, required_relief, deadline_msec
	)


static func _minimum_required_relief(course: CannonGolfCourseData, course_index: int) -> float:
	if course_index < 0 or course_index >= COURSE_MINIMUM_RELIEF.size():
		return float(course.generation_profile.accepted_height_range.x)
	return maxf(
		float(course.generation_profile.accepted_height_range.x),
		float(COURSE_MINIMUM_RELIEF[course_index])
	)


static func _height_contracts_pass(
	course: CannonGolfCourseData,
	course_index: int,
	plan: Array[Dictionary],
	heights: PackedFloat32Array,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	var relief := _maximum_height(heights) - _minimum_height(heights)
	if relief + 0.01 < _minimum_required_relief(course, course_index):
		return false
	if relief > _minimum_required_relief(course, course_index) + MAXIMUM_RELIEF_MARGIN + 0.01:
		return false
	var slope_metrics := measure_slope_metrics(heights, cell_count, local_bounds)
	if float(slope_metrics.p95_degrees) > P95_ADJACENT_SLOPE_DEGREES + 0.01 \
			or float(slope_metrics.maximum_degrees) > MAXIMUM_ADJACENT_SLOPE_DEGREES + 0.01 \
			or float(slope_metrics.steep_fraction) > MAXIMUM_STEEP_SAMPLE_FRACTION + 0.0001:
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
		# Preserve a broad stepped character without quantizing adjacent samples.
		base += 3.0 * sin(canonical_point.x * 0.052 + canonical_point.y * 0.031)
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
	var horizontal_scale := local_bounds.size.x / 210.0
	var anchor := Vector2(
		local_bounds.get_center().x + feature.route_offset.x * horizontal_scale,
		lerpf(local_bounds.position.y, local_bounds.end.y, feature.route_t)
	)
	var radius := maxf(feature.radius * horizontal_scale, 1.0)
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
			return height + amplitude * _smoothstep(weight)
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


static func _fit_goal_plate_support(
	height: float, point: Vector2, leg_data: Dictionary, grid_margin: float = 0.0
) -> float:
	var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
	var radius := float(leg_data.goal_radius)
	var offset := point - goal
	var distance := offset.length()
	var launcher := Vector2(leg_data.launcher.x, leg_data.launcher.z)
	var incoming := (launcher - goal).normalized()
	var direction := offset.normalized() if distance > 0.001 else incoming
	var incoming_angle := acos(clampf(direction.dot(incoming), -1.0, 1.0))
	var blend_distance := PLATE_INCOMING_BLEND \
			if incoming_angle <= PLATE_INCOMING_HALF_ANGLE else PLATE_SUPPORT_BLEND
	# Include one largest grid spacing so continuous height lookup within the
	# authored shoulder never interpolates against a lower blend-region sample.
	var shoulder_edge := radius + PLATE_TERRAIN_SHOULDER + maxf(grid_margin, 0.0)
	if distance >= shoulder_edge + blend_distance:
		return height
	var support_y := float(leg_data.goal.y) - PLATE_SUPPORT_DEPTH
	if distance <= shoulder_edge:
		return support_y
	var blend_t := _smoothstep((distance - shoulder_edge) / blend_distance)
	return lerpf(support_y, height, blend_t)


static func _constrain_final_heights(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		local_bounds: Rect2,
		plan: Array[Dictionary],
		deadline_msec: int
) -> PackedFloat32Array:
	var result := heights.duplicate()
	var locked := _protected_support_samples(cell_count, local_bounds, plan)
	var support_grid_margin := maxf(
		local_bounds.size.x / float(cell_count.x),
		local_bounds.size.y / float(cell_count.y)
	)
	for pass_index in range(SURFACE_FILTER_PASSES):
		if _expired(deadline_msec):
			return PackedFloat32Array()
		result = _filter_unprotected_samples(result, cell_count, locked)
	for pass_index in range(SLOPE_PROJECTION_PASSES):
		if _expired(deadline_msec):
			return PackedFloat32Array()
		_project_adjacent_slopes(result, cell_count, local_bounds, locked)
	# Exact start and plate supports are physical contracts. They are restored only
	# after nearby samples have been relaxed, so filtering cannot erode their floors.
	for sample_z in range(cell_count.y + 1):
		var z := lerpf(local_bounds.position.y, local_bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(cell_count.x + 1):
			var sample_index := sample_z * (cell_count.x + 1) + sample_x
			if not locked[sample_index]:
				continue
			var x := lerpf(local_bounds.position.x, local_bounds.end.x, float(sample_x) / float(cell_count.x))
			var point := Vector2(x, z)
			var height := result[sample_index]
			var start_distance := point.distance_to(Vector2(plan[0].launcher.x, plan[0].launcher.z))
			if start_distance <= START_SUPPORT_INNER_RADIUS:
				height = float(plan[0].launcher.y) - 0.05
			for leg_data in plan:
				height = _fit_goal_plate_support(height, point, leg_data, support_grid_margin)
			result[sample_index] = height
	# Repeated final projections propagate restored support elevations through the
	# blend region without ever moving the physical support samples themselves.
	for pass_index in range(SLOPE_PROJECTION_PASSES):
		_project_adjacent_slopes(result, cell_count, local_bounds, locked)
	return result


static func _restore_relief_band(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		local_bounds: Rect2,
		plan: Array[Dictionary],
		minimum_relief: float,
		deadline_msec: int
) -> PackedFloat32Array:
	if heights.is_empty() or _expired(deadline_msec):
		return PackedFloat32Array()
	var minimum_height := _minimum_height(heights)
	var maximum_height := _maximum_height(heights)
	var current_relief := maximum_height - minimum_height
	var target_relief := clampf(current_relief, minimum_relief, minimum_relief + MAXIMUM_RELIEF_MARGIN)
	if is_equal_approx(current_relief, target_relief):
		return heights
	var locked := _protected_support_samples(cell_count, local_bounds, plan)
	var result := heights.duplicate()
	for rebalance_index in range(RELIEF_REBALANCE_PASSES):
		if _expired(deadline_msec):
			return PackedFloat32Array()
		minimum_height = _minimum_height(result)
		maximum_height = _maximum_height(result)
		current_relief = maximum_height - minimum_height
		if current_relief >= minimum_relief - 0.01 and current_relief <= minimum_relief + MAXIMUM_RELIEF_MARGIN + 0.01:
			break
		if current_relief > minimum_relief + MAXIMUM_RELIEF_MARGIN:
			var midpoint := (minimum_height + maximum_height) * 0.5
			var scale := (minimum_relief + MAXIMUM_RELIEF_MARGIN) / maxf(current_relief, 0.01)
			for index in range(result.size()):
				if not locked[index]:
					result[index] = midpoint + (result[index] - midpoint) * scale
		else:
			var missing_relief := minimum_relief - current_relief
			var width := cell_count.x + 1
			for z_index in range(cell_count.y + 1):
				var z_weight := float(z_index) / float(cell_count.y) * 2.0 - 1.0
				for x_index in range(cell_count.x + 1):
					var index := z_index * width + x_index
					if locked[index]:
						continue
					var x_weight := float(x_index) / float(cell_count.x) * 2.0 - 1.0
					# A course-scale diagonal bias restores macro relief across the
					# full heightfield, never by changing a start or goal support.
					result[index] += missing_relief * (x_weight + z_weight)
		for pass_index in range(SLOPE_PROJECTION_PASSES):
			_project_adjacent_slopes(result, cell_count, local_bounds, locked)
	return result


static func _protected_support_samples(
		cell_count: Vector2i, local_bounds: Rect2, plan: Array[Dictionary]
) -> PackedByteArray:
	var sample_size := cell_count + Vector2i.ONE
	var support_grid_margin := maxf(
		local_bounds.size.x / float(cell_count.x),
		local_bounds.size.y / float(cell_count.y)
	)
	var result := PackedByteArray()
	result.resize(sample_size.x * sample_size.y)
	for sample_z in range(sample_size.y):
		var z := lerpf(local_bounds.position.y, local_bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(local_bounds.position.x, local_bounds.end.x, float(sample_x) / float(cell_count.x))
			var point := Vector2(x, z)
			var is_protected := point.distance_to(Vector2(plan[0].launcher.x, plan[0].launcher.z)) \
					<= START_SUPPORT_INNER_RADIUS
			for leg_data in plan:
				if point.distance_to(Vector2(leg_data.goal.x, leg_data.goal.z)) \
						<= float(leg_data.goal_radius) + PLATE_TERRAIN_SHOULDER + support_grid_margin:
					is_protected = true
					break
			result[sample_z * sample_size.x + sample_x] = 1 if is_protected else 0
	return result


static func _filter_unprotected_samples(
		heights: PackedFloat32Array, cell_count: Vector2i, locked: PackedByteArray
) -> PackedFloat32Array:
	var sample_size := cell_count + Vector2i.ONE
	var result := heights.duplicate()
	for z_index in range(1, sample_size.y - 1):
		for x_index in range(1, sample_size.x - 1):
			var index := z_index * sample_size.x + x_index
			if locked[index]:
				continue
			var average := (heights[index - 1] + heights[index + 1] \
					+ heights[index - sample_size.x] + heights[index + sample_size.x]) * 0.25
			result[index] = lerpf(heights[index], average, SURFACE_FILTER_BLEND)
	return result


static func _project_adjacent_slopes(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		local_bounds: Rect2,
		locked: PackedByteArray
) -> void:
	var sample_size := cell_count + Vector2i.ONE
	var x_spacing := local_bounds.size.x / float(cell_count.x)
	var z_spacing := local_bounds.size.y / float(cell_count.y)
	var max_x_delta := tan(deg_to_rad(PROJECTED_ADJACENT_SLOPE_DEGREES)) * x_spacing
	var max_z_delta := tan(deg_to_rad(PROJECTED_ADJACENT_SLOPE_DEGREES)) * z_spacing
	for z_index in range(sample_size.y):
		for x_index in range(sample_size.x - 1):
			_project_slope_pair(heights, z_index * sample_size.x + x_index,
					z_index * sample_size.x + x_index + 1, max_x_delta, locked)
	for z_index in range(sample_size.y - 1):
		for x_index in range(sample_size.x):
			_project_slope_pair(heights, z_index * sample_size.x + x_index,
					(z_index + 1) * sample_size.x + x_index, max_z_delta, locked)
	# A vertical correction can disturb a horizontal neighbor. End on the more
	# densely sampled axis; repeated outer passes still converge the other axis.
	for z_index in range(sample_size.y):
		for x_index in range(sample_size.x - 1):
			_project_slope_pair(heights, z_index * sample_size.x + x_index,
					z_index * sample_size.x + x_index + 1, max_x_delta, locked)


static func _project_slope_pair(
		heights: PackedFloat32Array,
		left_index: int,
		right_index: int,
		maximum_delta: float,
		locked: PackedByteArray
) -> void:
	var difference := heights[right_index] - heights[left_index]
	if absf(difference) <= maximum_delta:
		return
	var lower_index := left_index if difference > 0.0 else right_index
	var higher_index := right_index if difference > 0.0 else left_index
	if locked[lower_index] and locked[higher_index]:
		return
	if locked[lower_index]:
		heights[higher_index] = heights[lower_index] + maximum_delta
	elif locked[higher_index]:
		heights[lower_index] = heights[higher_index] - maximum_delta
	else:
		var midpoint := (heights[lower_index] + heights[higher_index]) * 0.5
		heights[lower_index] = midpoint - maximum_delta * 0.5
		heights[higher_index] = midpoint + maximum_delta * 0.5


static func measure_slope_metrics(
		heights: PackedFloat32Array, cell_count: Vector2i, local_bounds: Rect2
) -> Dictionary:
	var sample_size := cell_count + Vector2i.ONE
	if heights.size() != sample_size.x * sample_size.y:
		return {}
	var x_spacing := local_bounds.size.x / float(cell_count.x)
	var z_spacing := local_bounds.size.y / float(cell_count.y)
	var degrees: Array[float] = []
	for z_index in range(sample_size.y):
		for x_index in range(sample_size.x - 1):
			degrees.append(rad_to_deg(atan(absf(
				heights[z_index * sample_size.x + x_index + 1] - heights[z_index * sample_size.x + x_index]
			) / x_spacing)))
	for z_index in range(sample_size.y - 1):
		for x_index in range(sample_size.x):
			degrees.append(rad_to_deg(atan(absf(
				heights[(z_index + 1) * sample_size.x + x_index] - heights[z_index * sample_size.x + x_index]
			) / z_spacing)))
	degrees.sort()
	if degrees.is_empty():
		return {}
	var steep_count := 0
	for degree in degrees:
		if degree > STEEP_SAMPLE_SLOPE_DEGREES:
			steep_count += 1
	var p95_index := clampi(ceili(float(degrees.size()) * 0.95) - 1, 0, degrees.size() - 1)
	return {
		"p95_degrees": degrees[p95_index],
		"maximum_degrees": degrees[-1],
		"steep_fraction": float(steep_count) / float(degrees.size()),
	}


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
	admission_points = CannonGolfCourseTerrainFactory._terrain_admission_points(layout.top_topology)
	if admission_points.is_empty():
		return null
	result.admission_points = admission_points
	result.union_range_metrics = _measure_union_admission(admission_points, result.legs)
	result.union_range_metrics["generation_msec"] = elapsed_msec
	result.union_range_metrics["algorithm_version"] = ALGORITHM_VERSION
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


static func _measure_union_admission(
		points: PackedVector3Array,
		legs: Array[CannonGolfGeneratedCourseLeg]
) -> Dictionary:
	var admitted_count := 0
	var excluded_count := 0
	var unadmitted_count := 0
	var minimum_range_margin := INF
	var minimum_yaw_margin := INF
	var minimum_height_margin := INF
	var farthest_distance := 0.0
	for point in points:
		if CannonGolfCourseTerrainFactory._is_relay_launch_exclusion(point, legs):
			excluded_count += 1
			continue
		var accepted: Dictionary = {}
		for leg in legs:
			var admission := CannonGolfCourseTerrainFactory._admit_union_point(
				point, leg, CannonGolfCourseTerrainFactory.RELAY_CENTERED_UNION_HEIGHT_MARGIN
			)
			if bool(admission.passed):
				accepted = admission
				break
		if accepted.is_empty():
			unadmitted_count += 1
			continue
		admitted_count += 1
		minimum_range_margin = minf(minimum_range_margin, float(accepted.range_margin))
		minimum_yaw_margin = minf(minimum_yaw_margin, float(accepted.yaw_margin_degrees))
		minimum_height_margin = minf(minimum_height_margin, float(accepted.height_margin))
		farthest_distance = maxf(farthest_distance, float(accepted.distance))
	return {
		"point_count": points.size(),
		"admitted_point_count": admitted_count,
		"excluded_point_count": excluded_count,
		"unadmitted_point_count": unadmitted_count,
		"minimum_range_margin": minimum_range_margin,
		"minimum_yaw_margin_degrees": minimum_yaw_margin,
		"minimum_height_margin": minimum_height_margin,
		"farthest_distance": farthest_distance,
	}


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
