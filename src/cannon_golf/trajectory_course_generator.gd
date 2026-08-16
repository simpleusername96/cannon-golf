class_name CannonGolfTrajectoryCourseGenerator
extends RefCounted

## Fast constructive authoring path: choose flight legs first, then build one
## connected heightfield below those flights. It performs no candidate beam or
## live-physics search.

const ALGORITHM_VERSION := 12
const TERRAIN_SHADER := preload("res://src/cannon_golf/cannon_golf_terrain.gdshader")
const FEATURE_GRAPH_BUILDER := preload("res://src/cannon_golf/terrain_feature_graph_builder.gd")
const TERRAIN_EXTENT_SCALE := 1.35
const MINIMUM_ACTIVE_AREA_RATIO := 1.08
const MAXIMUM_INTERNAL_SLOPE_DEGREES := 50.0
const SLOPE_PROJECTION_PASSES := 12
const BASIN_FLOOR_RADIUS_RATIO := 0.45
const BASIN_SHOULDER_PADDING := 12.0
const BASIN_OUTER_BLEND := 22.0
const CORRIDOR_HALF_WIDTH := 34.0
const CORRIDOR_CLEARANCE := 2.25
const CORRIDOR_CONSTRUCTION_MARGIN := 2.5
const LANDING_CENTER_CLEARANCE := 0.35
const START_SUPPORT_INNER_RADIUS := 12.0
const START_SUPPORT_RADIUS := 42.0
const FOOTPRINT_ROUTE_RADIUS := 48.0
const FOOTPRINT_STATION_RADIUS := 54.0
const CAMERA_FLAG_HEIGHT := 15.0
const CAMERA_LINE_SAMPLE_COUNT := 48
const CAMERA_LINE_CLEARANCE := 1.5
const CAMERA_CHANNEL_HALF_WIDTH := 16.0
const CAMERA_CHANNEL_MARGIN := 1.0
const CAMERA_BOOM_RADIUS := 1.25
const CAMERA_BOOM_CLEARANCE := 0.5
const CAMERA_BOOM_CHANNEL_HALF_WIDTH := 18.0
const MAXIMUM_ACTIVE_ASPECT := 2.4
const GOAL_CREST_SAMPLE_DISTANCE := 52.0
const GOAL_CREST_PROMINENCE := 6.0
const GOAL_PEAK_CORE_RADIUS := 60.0
const GOAL_RIDGE_CORE_HALF_LENGTH := 72.0
const GOAL_RIDGE_CORE_HALF_WIDTH := 58.0
const GOAL_LANDFORM_BLEND_WIDTH := 30.0
const COURSE_DEADLINE_MSEC := 60000
const SETUP_ELEVATIONS := [25.0, 28.0, 31.0, 34.0, 37.0, 40.0, 43.0, 46.0, 49.0, 52.0, 55.0]
const SETUP_POWERS := [50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0, 90.0, 95.0]
const DEEP_RELAY_MINIMUM_RELIEF := 80.0
const DEEP_RELAY_MINIMUM_RIM_RISE := 25.0
const COURSE_MINIMUM_RELIEF := [72.0, 82.0, 96.0, 116.0, 132.0, 150.0, 170.0, 194.0, 220.0, 250.0]
const MAXIMUM_RELIEF_MARGIN := 45.0
const RELIEF_TARGET_MARGIN := 12.0
const STEEP_SAMPLE_SLOPE_DEGREES := 45.0


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
	var authored_bounds := Rect2(
		contract.local_bounds.position * course.terrain_horizontal_scale
				+ Vector2(course.terrain_origin.x, course.terrain_origin.z),
		contract.local_bounds.size * course.terrain_horizontal_scale
	)
	var local_bounds := _expanded_terrain_bounds(authored_bounds)
	var plan := _plan_legs(course, course_index, authored_bounds)
	if plan.is_empty() or _expired(deadline):
		return {}
	var heights := _build_heights(
		course, course_index, plan, cell_count, local_bounds, deadline
	)
	var footprint := _build_footprint(course, course_index, plan, cell_count, local_bounds)
	heights = _protect_overview_sightlines(
		course, plan, heights, footprint, cell_count, local_bounds
	)
	heights = _restore_goal_basin_cores(heights, plan, cell_count, local_bounds)
	heights = _protect_overview_boom(
		course, heights, footprint, cell_count, local_bounds
	)
	heights = _limit_internal_slopes(
		heights, footprint, cell_count, local_bounds
	)
	heights = _restore_goal_basins_with_slope_envelope(
		heights, footprint, plan, cell_count, local_bounds
	)
	for _projection_pass in range(3):
		heights = _protect_overview_boom(
			course, heights, footprint, cell_count, local_bounds
		)
		heights = _limit_internal_slopes(
			heights, footprint, cell_count, local_bounds
		)
	if heights.is_empty() or footprint.is_empty() or _expired(deadline) \
			or not _height_contracts_pass(
				course, course_index, plan, heights, footprint, cell_count, local_bounds,
				authored_bounds
			):
		return {}
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
	var geometry := TerrainGeometryFactory.build(
		layout, minf(-34.0, minimum_height - 18.0), true
	)
	if geometry == null or not geometry.is_valid() or _expired(deadline):
		return {}
	_apply_material(geometry.render_mesh, course)
	var generated := _assemble_generated_course(
		course, plan, layout, geometry, route_graph, heights, footprint,
		cell_count, local_bounds
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


static func _expanded_terrain_bounds(authored_bounds: Rect2) -> Rect2:
	var expanded_size := authored_bounds.size * TERRAIN_EXTENT_SCALE
	return Rect2(authored_bounds.get_center() - expanded_size * 0.5, expanded_size)


static func _plan_legs(
	course: CannonGolfCourseData, course_index: int, local_bounds: Rect2
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not CannonGolfCourseRouteMotifs.has_station_count(course_index, course.leg_count()):
		return result
	var lateral := minf(
		65.0 + float(course_index % 3) * 5.0,
		local_bounds.size.x * 0.36
	)
	if course.course_id == &"deep_relay":
		lateral = minf(lateral, local_bounds.size.x * 0.285)
	var start_z := local_bounds.end.y - minf(18.0, local_bounds.size.y * 0.12)
	var launcher := Vector3(
		local_bounds.get_center().x + lateral \
				* CannonGolfCourseRouteMotifs.station_multiplier(course_index, 0),
		course.terrain_origin.y + 8.05 + float(course_index % 3) * 2.0,
		start_z
	)
	var initial_launcher_y := launcher.y
	for leg_index in range(course.leg_count()):
		var authored_leg := course.leg_at(leg_index)
		var goal_x := local_bounds.get_center().x + lateral \
				* CannonGolfCourseRouteMotifs.station_multiplier(course_index, leg_index + 1)
		var goal_radius := (authored_leg.bowl_radius_range.x + authored_leg.bowl_radius_range.y) * 0.5
		var goal_recess := (
			authored_leg.bowl_recess_depth_range.x
			+ authored_leg.bowl_recess_depth_range.y
		) * 0.5
		var goal_lip_height := 0.0
		var desired_landing_delta := _desired_landing_delta(
			course, authored_leg, launcher.y, initial_launcher_y, course_index, leg_index,
			goal_recess
		)
		var route_choice := _choose_route_setup(
			authored_leg,
			leg_index > 0 or (
				course.course_id != &"deep_relay" and authored_leg.relative_rim_band == 0
			),
			launcher, goal_x, local_bounds, goal_radius,
			goal_recess, goal_lip_height, desired_landing_delta
		)
		if route_choice.is_empty():
			return []
		var goal_z := float(route_choice.goal_z)
		var distance := float(route_choice.distance)
		var choice: Dictionary = route_choice.setup_choice
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
			"lip_y": goal_floor_y + goal_recess,
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


static func _choose_route_setup(
		authored_leg: CannonGolfCourseLegData,
		allow_interval_endpoints: bool,
		launcher: Vector3,
		goal_x: float,
		local_bounds: Rect2,
		goal_radius: float,
		goal_recess: float,
		goal_lip_height: float,
		desired_landing_delta: float
) -> Dictionary:
	var midpoint := (authored_leg.route_interval.x + authored_leg.route_interval.y) * 0.5
	var route_candidates := PackedFloat32Array([midpoint])
	if allow_interval_endpoints:
		route_candidates.append(authored_leg.route_interval.x)
		route_candidates.append(authored_leg.route_interval.y)
	var result := {}
	var best_score := INF
	for route_t in route_candidates:
		var goal_z := lerpf(local_bounds.position.y, local_bounds.end.y, route_t)
		var goal_point := Vector2(goal_x, goal_z)
		var distance := Vector2(launcher.x, launcher.z).distance_to(goal_point)
		var setup_choice := _choose_setup(
			distance, goal_radius, goal_recess, goal_lip_height, desired_landing_delta
		)
		if setup_choice.is_empty():
			continue
		var score := absf(float(setup_choice.landing_delta) - desired_landing_delta)
		if score >= best_score:
			continue
		best_score = score
		result = {
			"route_t": route_t,
			"goal_z": goal_z,
			"distance": distance,
			"setup_choice": setup_choice,
		}
	return result


static func _desired_landing_delta(
	course: CannonGolfCourseData,
	_authored_leg: CannonGolfCourseLegData,
	launcher_y: float,
	initial_launcher_y: float,
	course_index: int,
	leg_index: int,
	goal_recess: float
) -> float:
	var target_rim_y := initial_launcher_y \
			+ _minimum_required_relief(course, course_index) \
			* _goal_rim_height_ratio(course.leg_count(), leg_index)
	return target_rim_y - launcher_y - goal_recess


static func _goal_rim_height_ratio(leg_count: int, leg_index: int) -> float:
	var ratios: PackedFloat32Array
	match leg_count:
		1:
			ratios = PackedFloat32Array([0.55])
		2:
			ratios = PackedFloat32Array([0.30, 0.55])
		3:
			ratios = PackedFloat32Array([0.26, 0.54, 0.84])
		4:
			ratios = PackedFloat32Array([0.22, 0.48, 0.38, 0.80])
		5:
			ratios = PackedFloat32Array([0.20, 0.42, 0.34, 0.64, 0.88])
		_:
			ratios = PackedFloat32Array([0.18, 0.38, 0.30, 0.55, 0.74, 0.90])
	return ratios[clampi(leg_index, 0, ratios.size() - 1)]


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
	var near_distance := distance - goal_radius - BASIN_SHOULDER_PADDING - BASIN_OUTER_BLEND
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
	var required_relief := _minimum_required_relief(course, course_index)
	var target_relief := required_relief + RELIEF_TARGET_MARGIN
	var relief_base_y := course.terrain_origin.y + 1.0
	var terrain_field: RefCounted = FEATURE_GRAPH_BUILDER.build(
		course, course_index, plan, local_bounds, relief_base_y, target_relief
	)
	if terrain_field == null or not terrain_field.is_valid():
		return PackedFloat32Array()
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
			natural_heights[sample_z * sample_size.x + sample_x] = terrain_field.sample(point)
	var natural_minimum := _minimum_height(natural_heights)
	var natural_relief := _maximum_height(natural_heights) - natural_minimum
	if natural_relief <= 0.0:
		return PackedFloat32Array()
	var relief_scale := target_relief / natural_relief
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
			var height := relief_base_y \
					+ (natural_heights[sample_index] - natural_minimum) * relief_scale
			height = _fit_nearest_goal_landform(height, point, plan)
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
				height = _fit_goal_basin(height, point, leg_data)
			heights[sample_index] = height
	return heights


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
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2,
	authored_bounds: Rect2
) -> bool:
	var relief := _maximum_height(heights) - _minimum_height(heights)
	if relief + 0.01 < _minimum_required_relief(course, course_index) * 0.82:
		return false
	if relief > _minimum_required_relief(course, course_index) + MAXIMUM_RELIEF_MARGIN + 0.01:
		return false
	if _active_terrain_area(footprint, cell_count, local_bounds) + 0.01 \
			< authored_bounds.get_area() * MINIMUM_ACTIVE_AREA_RATIO:
		return false
	if not _active_slopes_pass(heights, footprint, cell_count, local_bounds) \
			or not _footprint_is_connected(footprint, cell_count) \
			or not _protected_points_are_active(plan, footprint, cell_count, local_bounds) \
			or not _goal_basins_pass(plan, heights, cell_count, local_bounds) \
			or not _goal_landforms_pass(plan, heights, cell_count, local_bounds) \
			or not _ballistic_corridors_pass(plan, heights, footprint, cell_count, local_bounds) \
			or not _overview_boom_passes(
				course, heights, footprint, cell_count, local_bounds
			) \
			or not _camera_contracts_pass(
				course, plan, heights, footprint, cell_count, local_bounds
			):
		return false
	if course.course_id == &"deep_relay":
		for leg_data in plan:
			if float(leg_data.rim_y) - float(leg_data.launcher.y) + 0.01 \
					< DEEP_RELAY_MINIMUM_RIM_RISE:
				return false
	return true


## Compatibility probe for existing variety diagnostics. The live generator
## uses the continuous curve field, because route stations are its constraints.
static func _natural_height(
	course_index: int, seed: int, point: Vector2, local_bounds: Rect2
) -> float:
	var phase := float(posmod(seed, 997)) * 0.017
	var tier := _progression_tier(course_index)
	var normalized := Vector2(
		(point.x - local_bounds.position.x) / local_bounds.size.x,
		(point.y - local_bounds.position.y) / local_bounds.size.y
	)
	return sin((normalized.x * 2.0 + normalized.y) * PI + phase) * 7.0 \
			+ cos((normalized.y * 3.0 - normalized.x) * PI - phase) * 4.0 \
			+ float(course_index + tier * 3)


static func _progression_tier(course_index: int) -> int:
	return 0 if course_index <= 2 else (1 if course_index <= 6 else 2)


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
			- CORRIDOR_CLEARANCE - CORRIDOR_CONSTRUCTION_MARGIN
	var protected_height := minf(height, corridor_cap)
	return lerpf(
		height,
		protected_height,
		_smootherstep(1.0 - lateral_distance / CORRIDOR_HALF_WIDTH)
	)


static func _fit_goal_basin(
	height: float, point: Vector2, leg_data: Dictionary
) -> float:
	var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
	var radius := float(leg_data.goal_radius)
	var distance := point.distance_to(goal)
	var floor_radius := maxf(radius * BASIN_FLOOR_RADIUS_RATIO, 3.5)
	var shoulder_radius := radius + BASIN_SHOULDER_PADDING
	var outer_radius := shoulder_radius + BASIN_OUTER_BLEND
	if distance >= outer_radius:
		return height
	var floor_y := float(leg_data.goal.y)
	var shoulder_y := float(leg_data.rim_y)
	if distance <= floor_radius:
		return floor_y
	if distance <= shoulder_radius:
		return lerpf(
			floor_y,
			shoulder_y,
			_smootherstep((distance - floor_radius) / (shoulder_radius - floor_radius))
		)
	return lerpf(
		shoulder_y,
		height,
		_smootherstep((distance - shoulder_radius) / BASIN_OUTER_BLEND)
	)


## Assigns the basin's surrounding macro landform before the shallow scoring
## recess is carved. A final goal caps a summit; relay goals sit on a crest that
## follows the incoming route axis and descends across it.
static func _fit_goal_landform(
	height: float,
	point: Vector2,
	leg_data: Dictionary,
	is_peak: bool
) -> float:
	var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
	var relative := point - goal
	var rim_y := float(leg_data.rim_y)
	if is_peak:
		var distance := relative.length()
		var outer_radius := GOAL_PEAK_CORE_RADIUS + GOAL_LANDFORM_BLEND_WIDTH
		if distance >= outer_radius:
			return height
		var target := rim_y - 12.0 * _smootherstep(
			minf(distance / GOAL_CREST_SAMPLE_DISTANCE, 1.0)
		)
		var blend := 1.0 if distance <= GOAL_PEAK_CORE_RADIUS else \
				_smootherstep(1.0 - (
					distance - GOAL_PEAK_CORE_RADIUS
				) / GOAL_LANDFORM_BLEND_WIDTH)
		return lerpf(height, target, blend)

	var route_direction := Vector2(
		float(leg_data.goal.x) - float(leg_data.launcher.x),
		float(leg_data.goal.z) - float(leg_data.launcher.z)
	).normalized()
	if route_direction.is_zero_approx():
		return height
	var cross_direction := Vector2(-route_direction.y, route_direction.x)
	var along := relative.dot(route_direction)
	var cross := relative.dot(cross_direction)
	var core_address := maxf(
		absf(along) / GOAL_RIDGE_CORE_HALF_LENGTH,
		absf(cross) / GOAL_RIDGE_CORE_HALF_WIDTH
	)
	var outer_address := maxf(
		absf(along) / (GOAL_RIDGE_CORE_HALF_LENGTH + GOAL_LANDFORM_BLEND_WIDTH),
		absf(cross) / (GOAL_RIDGE_CORE_HALF_WIDTH + GOAL_LANDFORM_BLEND_WIDTH)
	)
	if outer_address >= 1.0:
		return height
	var transverse_drop := 12.0 * _smootherstep(
		minf(absf(cross) / GOAL_CREST_SAMPLE_DISTANCE, 1.0)
	)
	var longitudinal_drop := 2.0 * _smootherstep(
		minf(absf(along) / GOAL_CREST_SAMPLE_DISTANCE, 1.0)
	)
	var target := rim_y - transverse_drop - longitudinal_drop
	var blend := 1.0 if core_address <= 1.0 else \
			_smootherstep(1.0 - (outer_address - 0.70) / 0.30)
	return lerpf(height, target, blend)


static func _fit_nearest_goal_landform(
	height: float, point: Vector2, plan: Array[Dictionary]
) -> float:
	var nearest_index := _nearest_goal_index(point, plan)
	if nearest_index < 0:
		return height
	return _fit_goal_landform(
		height, point, plan[nearest_index], nearest_index == plan.size() - 1
	)


static func _nearest_goal_index(
	point: Vector2, plan: Array[Dictionary]
) -> int:
	var nearest_index := -1
	var nearest_distance := INF
	for leg_index in range(plan.size()):
		var leg_data: Dictionary = plan[leg_index]
		var distance := point.distance_to(Vector2(leg_data.goal.x, leg_data.goal.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = leg_index
	return nearest_index


static func _restore_goal_basin_cores(
	heights: PackedFloat32Array,
	plan: Array[Dictionary],
	cell_count: Vector2i,
	local_bounds: Rect2
) -> PackedFloat32Array:
	var result := heights.duplicate()
	var width := cell_count.x + 1
	var grid_margin := maxf(
		local_bounds.size.x / float(cell_count.x),
		local_bounds.size.y / float(cell_count.y)
	) * 1.5
	for sample_z in range(cell_count.y + 1):
		var z := lerpf(local_bounds.position.y, local_bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(cell_count.x + 1):
			var x := lerpf(local_bounds.position.x, local_bounds.end.x, float(sample_x) / float(cell_count.x))
			var point := Vector2(x, z)
			var sample_index := sample_z * width + sample_x
			for leg_data in plan:
				var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
				var distance := point.distance_to(goal)
				var floor_radius := maxf(float(leg_data.goal_radius) * BASIN_FLOOR_RADIUS_RATIO, 3.5)
				var shoulder_radius := float(leg_data.goal_radius) + BASIN_SHOULDER_PADDING
				if distance > shoulder_radius + grid_margin:
					continue
				if distance <= floor_radius:
					result[sample_index] = float(leg_data.goal.y)
				elif distance <= shoulder_radius:
					result[sample_index] = lerpf(
						float(leg_data.goal.y),
						float(leg_data.rim_y),
						_smootherstep((distance - floor_radius) / (shoulder_radius - floor_radius))
					)
				else:
					result[sample_index] = float(leg_data.rim_y)
	return result


## Restores every scoring recess after global slope projection, then raises only
## the newly over-steep lower neighbors. The input already satisfies the global
## angle contract, so this pass preserves each basin and adds only the gradual
## supporting slope required by its generated elevation.
static func _restore_goal_basins_with_slope_envelope(
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	plan: Array[Dictionary],
	cell_count: Vector2i,
	local_bounds: Rect2
) -> PackedFloat32Array:
	var result := _restore_goal_basin_cores(heights, plan, cell_count, local_bounds)
	var active_samples := _active_sample_mask(footprint, cell_count)
	var width := cell_count.x + 1
	var height := cell_count.y + 1
	var tangent := tan(deg_to_rad(MAXIMUM_INTERNAL_SLOPE_DEGREES))
	var x_limit := local_bounds.size.x / float(cell_count.x) * tangent
	var z_limit := local_bounds.size.y / float(cell_count.y) * tangent
	for _pass_index in range(width + height):
		var maximum_change := 0.0
		for sample_z in range(height):
			for sample_x in range(1, width):
				maximum_change = maxf(maximum_change, _raise_low_slope_pair(
					result, active_samples,
					sample_z * width + sample_x - 1,
					sample_z * width + sample_x, x_limit
				))
			for sample_x in range(width - 2, -1, -1):
				maximum_change = maxf(maximum_change, _raise_low_slope_pair(
					result, active_samples,
					sample_z * width + sample_x + 1,
					sample_z * width + sample_x, x_limit
				))
		for sample_x in range(width):
			for sample_z in range(1, height):
				maximum_change = maxf(maximum_change, _raise_low_slope_pair(
					result, active_samples,
					(sample_z - 1) * width + sample_x,
					sample_z * width + sample_x, z_limit
				))
			for sample_z in range(height - 2, -1, -1):
				maximum_change = maxf(maximum_change, _raise_low_slope_pair(
					result, active_samples,
					(sample_z + 1) * width + sample_x,
					sample_z * width + sample_x, z_limit
				))
		if maximum_change <= 0.001:
			break
	return result


static func _raise_low_slope_pair(
	heights: PackedFloat32Array,
	active_samples: PackedByteArray,
	left_index: int,
	right_index: int,
	maximum_delta: float
) -> float:
	if active_samples[left_index] == 0 or active_samples[right_index] == 0:
		return 0.0
	var difference := heights[right_index] - heights[left_index]
	if absf(difference) <= maximum_delta:
		return 0.0
	var change := absf(difference) - maximum_delta
	if difference > 0.0:
		heights[left_index] += change
	else:
		heights[right_index] += change
	return change


static func _build_footprint(
	course: CannonGolfCourseData,
	course_index: int,
	plan: Array[Dictionary],
	cell_count: Vector2i,
	local_bounds: Rect2
) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(cell_count.x * cell_count.y)
	var tier := _progression_tier(course_index)
	var landmarks := FEATURE_GRAPH_BUILDER.landmark_specs(
		course, course_index, plan, local_bounds
	)
	var phase := float(posmod(course.terrain_seed_window.x, 997)) * 0.017
	for cell_z in range(cell_count.y):
		var z := lerpf(local_bounds.position.y, local_bounds.end.y, (float(cell_z) + 0.5) / float(cell_count.y))
		for cell_x in range(cell_count.x):
			var x := lerpf(local_bounds.position.x, local_bounds.end.x, (float(cell_x) + 0.5) / float(cell_count.x))
			var point := Vector2(x, z)
			var normalized := (point - local_bounds.get_center()) / Vector2(
				local_bounds.size.x * 0.48,
				local_bounds.size.y * 0.46
			)
			var island_angle := atan2(normalized.y, normalized.x)
			var island_limit := 1.0 + sin(island_angle * 5.0 + phase) * 0.055 \
					+ cos(island_angle * 3.0 - phase) * 0.035
			var station_radius := FOOTPRINT_STATION_RADIUS + float(tier) * 10.0
			var active := normalized.length() <= island_limit \
					or point.distance_to(Vector2(plan[0].launcher.x, plan[0].launcher.z)) \
					<= station_radius
			for leg_data in plan:
				var start := Vector2(leg_data.launcher.x, leg_data.launcher.z)
				var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
				var route_radius := FOOTPRINT_ROUTE_RADIUS + 10.0 + float(tier) * 10.0
				if float(_segment_address(point, start, goal).distance) <= route_radius \
						or point.distance_to(goal) <= maxf(
							station_radius,
							float(leg_data.goal_radius) + BASIN_SHOULDER_PADDING + BASIN_OUTER_BLEND + 4.0
						):
					active = true
					break
			if not active:
				for landmark in landmarks:
					if _compact_ellipse(
						point,
						landmark.anchor,
						Vector2.ONE * float(landmark.width) * 0.98
					) > 0.0:
						active = true
						break
			result[cell_z * cell_count.x + cell_x] = 1 if active else 0
	return result


static func _active_terrain_area(
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> float:
	if footprint.size() != cell_count.x * cell_count.y:
		return 0.0
	return float(footprint.count(1)) \
			* local_bounds.size.x / float(cell_count.x) \
			* local_bounds.size.y / float(cell_count.y)


static func _active_sample_mask(
	footprint: PackedByteArray, cell_count: Vector2i
) -> PackedByteArray:
	var width := cell_count.x + 1
	var result := PackedByteArray()
	result.resize(width * (cell_count.y + 1))
	for cell_z in range(cell_count.y):
		for cell_x in range(cell_count.x):
			if footprint[cell_z * cell_count.x + cell_x] == 0:
				continue
			result[cell_z * width + cell_x] = 1
			result[cell_z * width + cell_x + 1] = 1
			result[(cell_z + 1) * width + cell_x] = 1
			result[(cell_z + 1) * width + cell_x + 1] = 1
	return result


## Lowers only the higher endpoint of an over-steep active edge. This retains
## all flight/camera upper bounds and uses the expanded footprint, rather than
## reducing the catalog's relief target, to provide enough horizontal run.
static func _limit_internal_slopes(
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> PackedFloat32Array:
	var result := heights.duplicate()
	var active_samples := _active_sample_mask(footprint, cell_count)
	var width := cell_count.x + 1
	var height := cell_count.y + 1
	var tangent := tan(deg_to_rad(MAXIMUM_INTERNAL_SLOPE_DEGREES))
	var x_limit := local_bounds.size.x / float(cell_count.x) * tangent
	var z_limit := local_bounds.size.y / float(cell_count.y) * tangent
	for _pass_index in range(SLOPE_PROJECTION_PASSES):
		var maximum_change := 0.0
		for z in range(height):
			for x in range(1, width):
				maximum_change = maxf(maximum_change, _lower_steep_pair(
					result, active_samples, z * width + x - 1, z * width + x, x_limit
				))
			for x in range(width - 2, -1, -1):
				maximum_change = maxf(maximum_change, _lower_steep_pair(
					result, active_samples, z * width + x + 1, z * width + x, x_limit
				))
		for x in range(width):
			for z in range(1, height):
				maximum_change = maxf(maximum_change, _lower_steep_pair(
					result, active_samples, (z - 1) * width + x, z * width + x, z_limit
				))
			for z in range(height - 2, -1, -1):
				maximum_change = maxf(maximum_change, _lower_steep_pair(
					result, active_samples, (z + 1) * width + x, z * width + x, z_limit
				))
		if maximum_change <= 0.001:
			break
	return result


static func _lower_steep_pair(
	heights: PackedFloat32Array,
	active_samples: PackedByteArray,
	left_index: int,
	right_index: int,
	maximum_delta: float
) -> float:
	if active_samples[left_index] == 0 or active_samples[right_index] == 0:
		return 0.0
	var difference := heights[right_index] - heights[left_index]
	if absf(difference) <= maximum_delta:
		return 0.0
	var change := absf(difference) - maximum_delta
	if difference > 0.0:
		heights[right_index] -= change
	else:
		heights[left_index] -= change
	return change


static func _active_slopes_pass(
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	var active_samples := _active_sample_mask(footprint, cell_count)
	var width := cell_count.x + 1
	var height := cell_count.y + 1
	var tangent := tan(deg_to_rad(MAXIMUM_INTERNAL_SLOPE_DEGREES))
	var x_limit := local_bounds.size.x / float(cell_count.x) * tangent + 0.01
	var z_limit := local_bounds.size.y / float(cell_count.y) * tangent + 0.01
	for z in range(height):
		for x in range(width - 1):
			var left := z * width + x
			if active_samples[left] != 0 and active_samples[left + 1] != 0 \
					and absf(heights[left + 1] - heights[left]) > x_limit:
				return false
	for z in range(height - 1):
		for x in range(width):
			var top := z * width + x
			if active_samples[top] != 0 and active_samples[top + width] != 0 \
					and absf(heights[top + width] - heights[top]) > z_limit:
				return false
	return true


static func _goal_landforms_pass(
	plan: Array[Dictionary],
	heights: PackedFloat32Array,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	for leg_index in range(plan.size()):
		var leg_data: Dictionary = plan[leg_index]
		var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
		var rim_y := float(leg_data.rim_y)
		var is_peak := leg_index == plan.size() - 1
		var summit_passes := true
		for direction_index in range(8):
			var direction := Vector2.from_angle(TAU * float(direction_index) / 8.0)
			if _sample_height(
				heights, cell_count, local_bounds,
				goal + direction * GOAL_CREST_SAMPLE_DISTANCE
			) > rim_y - GOAL_CREST_PROMINENCE + 0.75:
				summit_passes = false
				break
		if is_peak:
			if not summit_passes:
				return false
			continue
		if summit_passes:
			continue
		var route_direction := Vector2(
			float(leg_data.goal.x) - float(leg_data.launcher.x),
			float(leg_data.goal.z) - float(leg_data.launcher.z)
		).normalized()
		if route_direction.is_zero_approx():
			return false
		var cross_direction := Vector2(-route_direction.y, route_direction.x)
		var along_heights := PackedFloat32Array()
		var cross_heights := PackedFloat32Array()
		for sign_value in [-1.0, 1.0]:
			var sign_float: float = sign_value
			along_heights.append(_sample_height(
				heights, cell_count, local_bounds,
				goal + route_direction * GOAL_CREST_SAMPLE_DISTANCE * sign_float
			))
			cross_heights.append(_sample_height(
				heights, cell_count, local_bounds,
				goal + cross_direction * GOAL_CREST_SAMPLE_DISTANCE * sign_float
			))
		var along_crest_height := maxf(along_heights[0], along_heights[1])
		var cross_crest_height := maxf(cross_heights[0], cross_heights[1])
		if absf(along_crest_height - cross_crest_height) \
				< GOAL_CREST_PROMINENCE - 0.75:
			return false
	return true


static func _footprint_is_connected(footprint: PackedByteArray, cell_count: Vector2i) -> bool:
	var first := footprint.find(1)
	if first < 0:
		return false
	var visited := PackedByteArray()
	visited.resize(footprint.size())
	var queue := PackedInt32Array([first])
	visited[first] = 1
	var cursor := 0
	var visited_count := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		visited_count += 1
		var x := index % cell_count.x
		var z: int = index / cell_count.x
		for raw_neighbor in [
			Vector2i(x - 1, z), Vector2i(x + 1, z),
			Vector2i(x, z - 1), Vector2i(x, z + 1),
		]:
			var neighbor: Vector2i = raw_neighbor
			if neighbor.x < 0 or neighbor.x >= cell_count.x \
					or neighbor.y < 0 or neighbor.y >= cell_count.y:
				continue
			var neighbor_index: int = neighbor.y * cell_count.x + neighbor.x
			if footprint[neighbor_index] == 0 or visited[neighbor_index] != 0:
				continue
			visited[neighbor_index] = 1
			queue.append(neighbor_index)
	return visited_count == footprint.count(1)


static func _protected_points_are_active(
	plan: Array[Dictionary],
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	if not _point_is_active(
		Vector2(plan[0].launcher.x, plan[0].launcher.z), footprint, cell_count, local_bounds
	):
		return false
	for leg_data in plan:
		if not _point_is_active(
			Vector2(leg_data.goal.x, leg_data.goal.z), footprint, cell_count, local_bounds
		):
			return false
	return true


static func _goal_basins_pass(
	plan: Array[Dictionary],
	heights: PackedFloat32Array,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	for leg_data in plan:
		var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
		var floor_y := float(leg_data.goal.y)
		var shoulder_y := float(leg_data.rim_y)
		if absf(_sample_height(heights, cell_count, local_bounds, goal) - floor_y) > 0.16:
			return false
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var previous := floor_y
			for ratio in [0.35, 0.65, 1.0]:
				var radius := lerpf(
					maxf(float(leg_data.goal_radius) * BASIN_FLOOR_RADIUS_RATIO, 3.5),
					float(leg_data.goal_radius) + BASIN_SHOULDER_PADDING,
					ratio
				)
				var sampled := _sample_height(
					heights, cell_count, local_bounds, goal + direction * radius
				)
				if sampled + 0.35 < previous or sampled > shoulder_y + 1.0:
					return false
				previous = sampled
	return true


static func _ballistic_corridors_pass(
	plan: Array[Dictionary],
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	for leg_data in plan:
		var start := Vector2(leg_data.launcher.x, leg_data.launcher.z)
		var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
		var setup: Vector3 = leg_data.setup
		for sample_index in range(2, 23):
			var t := float(sample_index) / 25.0
			var point := start.lerp(goal, t)
			if not _point_is_active(point, footprint, cell_count, local_bounds):
				continue
			var path_y := float(leg_data.launcher.y) \
					+ CannonGolfBallistics.height_for_setup_at_distance(
						float(leg_data.distance) * t, setup.y, setup.z
					)
			var terrain_y := _sample_height(heights, cell_count, local_bounds, point)
			if terrain_y + CannonGolfBallistics.BALL_RADIUS + CORRIDOR_CLEARANCE > path_y:
				return false
	return true


static func _protect_overview_sightlines(
	course: CannonGolfCourseData,
	plan: Array[Dictionary],
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> PackedFloat32Array:
	var result := heights.duplicate()
	var width := cell_count.x + 1
	# Two fixed passes let the fitted viewpoint settle after an optional landmark
	# is lowered. This is construction, not render-driven retry or search.
	for _pass_index in range(2):
		var content := _active_content_bounds(result, footprint, cell_count, local_bounds)
		var direction := course.oblique_offset.normalized()
		var span := maxf(content.size.x, content.size.z)
		var distance := maxf(maxf(span * 1.45, content.size.y * 2.1), 140.0)
		var camera := content.get_center() + direction * distance
		var camera_xz := Vector2(camera.x, camera.z)
		for sample_z in range(cell_count.y + 1):
			var z := lerpf(local_bounds.position.y, local_bounds.end.y, float(sample_z) / float(cell_count.y))
			for sample_x in range(cell_count.x + 1):
				var x := lerpf(local_bounds.position.x, local_bounds.end.x, float(sample_x) / float(cell_count.x))
				var point := Vector2(x, z)
				if not _point_is_active(point, footprint, cell_count, local_bounds):
					continue
				var inside_goal_basin := false
				for protected_leg in plan:
					if point.distance_to(Vector2(protected_leg.goal.x, protected_leg.goal.z)) \
							<= float(protected_leg.goal_radius) + BASIN_SHOULDER_PADDING:
						inside_goal_basin = true
						break
				if inside_goal_basin:
					continue
				var sample_index := sample_z * width + sample_x
				var capped_height := result[sample_index]
				for leg_data in plan:
					var target: Vector3 = leg_data.goal
					target.y += CAMERA_FLAG_HEIGHT
					var address := _segment_address(
						point, camera_xz, Vector2(target.x, target.z)
					)
					var route_t := float(address.t)
					var lateral := float(address.distance)
					if route_t <= 0.02 or route_t >= 0.995 \
							or lateral >= CAMERA_CHANNEL_HALF_WIDTH:
						continue
					var line_y := lerpf(camera.y, target.y, route_t)
					var cap := line_y - CAMERA_LINE_CLEARANCE - CAMERA_CHANNEL_MARGIN
					var protected_height := minf(capped_height, cap)
					capped_height = lerpf(
						capped_height,
						protected_height,
						_smootherstep(1.0 - lateral / CAMERA_CHANNEL_HALF_WIDTH)
					)
				result[sample_index] = capped_height
	return result


## Opens a broad valley at the reset pivot and a rising channel toward the
## authored oblique camera. The runtime spring arm can then leave the pivot
## without starting against a mountain face or collapsing to a near view.
static func _protect_overview_boom(
	course: CannonGolfCourseData,
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> PackedFloat32Array:
	var content := _active_content_bounds(heights, footprint, cell_count, local_bounds)
	var direction_3d := course.oblique_offset.normalized()
	var direction := Vector2(direction_3d.x, direction_3d.z)
	if not content.has_volume() or direction.is_zero_approx() or direction_3d.y <= 0.01:
		return heights
	direction = direction.normalized()
	var focus := Vector2(content.get_center().x, content.get_center().z)
	var focus_y := _camera_safe_focus_y(
		heights, cell_count, local_bounds, focus, content.get_center().y
	)
	var rise_per_horizontal := direction_3d.y \
			/ maxf(Vector2(direction_3d.x, direction_3d.z).length(), 0.01)
	var result := heights.duplicate()
	var width := cell_count.x + 1
	for sample_z in range(cell_count.y + 1):
		var z := lerpf(local_bounds.position.y, local_bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(cell_count.x + 1):
			var x := lerpf(local_bounds.position.x, local_bounds.end.x, float(sample_x) / float(cell_count.x))
			var point := Vector2(x, z)
			if not _point_is_active(point, footprint, cell_count, local_bounds):
				continue
			var relative := point - focus
			var along := relative.dot(direction)
			var lateral := absf(relative.cross(direction))
			var cap := INF
			var blend := 0.0
			if along >= 0.0 and lateral < CAMERA_BOOM_CHANNEL_HALF_WIDTH:
				var boom_cap := focus_y + along * rise_per_horizontal \
						- CAMERA_BOOM_RADIUS - CAMERA_BOOM_CLEARANCE
				cap = minf(cap, boom_cap)
				blend = maxf(
					blend,
					_smootherstep(1.0 - lateral / CAMERA_BOOM_CHANNEL_HALF_WIDTH)
				)
			if is_finite(cap):
				var index := sample_z * width + sample_x
				result[index] = lerpf(result[index], minf(result[index], cap), blend)
	return result


static func _overview_boom_passes(
	course: CannonGolfCourseData,
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	var content := _active_content_bounds(heights, footprint, cell_count, local_bounds)
	var direction_3d := course.oblique_offset.normalized()
	var horizontal := Vector2(direction_3d.x, direction_3d.z)
	if not content.has_volume() or horizontal.is_zero_approx() or direction_3d.y <= 0.01:
		return false
	horizontal = horizontal.normalized()
	var focus := Vector2(content.get_center().x, content.get_center().z)
	var origin_y := _camera_safe_focus_y(
		heights, cell_count, local_bounds, focus, content.get_center().y
	)
	var rise_per_horizontal := direction_3d.y \
			/ maxf(Vector2(direction_3d.x, direction_3d.z).length(), 0.01)
	var distance := maxf(content.size.x, content.size.z)
	for sample_index in range(13):
		var along := distance * float(sample_index) / 12.0
		var center := focus + horizontal * along
		var line_y := origin_y + along * rise_per_horizontal
		for raw_side in [-1.0, 0.0, 1.0]:
			var side: float = raw_side
			var point: Vector2 = center + Vector2(-horizontal.y, horizontal.x) \
					* CAMERA_BOOM_RADIUS * side
			if not _point_is_active(point, footprint, cell_count, local_bounds):
				continue
			if _sample_height(heights, cell_count, local_bounds, point) \
					+ CAMERA_BOOM_RADIUS + 0.25 >= line_y:
				return false
	return true


## Mirrors the runtime camera rig's terrain-safe planning pivot: start above the
## focus surface, then include the swept sphere's eight-point footprint.
static func _camera_safe_focus_y(
	heights: PackedFloat32Array,
	cell_count: Vector2i,
	local_bounds: Rect2,
	focus: Vector2,
	base_y: float
) -> float:
	var result := maxf(
		base_y, _sample_height(heights, cell_count, local_bounds, focus) + 2.0
	)
	for sample_index in range(8):
		var angle := TAU * float(sample_index) / 8.0
		var offset := Vector2(sin(angle), cos(angle)) * CAMERA_BOOM_RADIUS
		result = maxf(
			result,
			_sample_height(heights, cell_count, local_bounds, focus + offset) \
					+ CAMERA_BOOM_RADIUS + 0.30
		)
	return result


static func _camera_contracts_pass(
	course: CannonGolfCourseData,
	plan: Array[Dictionary],
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	var content := _active_content_bounds(heights, footprint, cell_count, local_bounds)
	if not content.has_volume():
		return false
	var horizontal_min := maxf(minf(content.size.x, content.size.z), 0.01)
	if maxf(content.size.x, content.size.z) / horizontal_min > MAXIMUM_ACTIVE_ASPECT:
		return false
	var direction := course.oblique_offset.normalized()
	if direction.is_zero_approx():
		return false
	var span := maxf(content.size.x, content.size.z)
	var distance := maxf(maxf(span * 1.45, content.size.y * 2.1), 140.0)
	var focus := content.get_center()
	var camera := focus + direction * distance
	for leg_data in plan:
		var target := leg_data.goal as Vector3
		target.y += CAMERA_FLAG_HEIGHT
		for sample_index in range(1, CAMERA_LINE_SAMPLE_COUNT):
			var t := float(sample_index) / float(CAMERA_LINE_SAMPLE_COUNT)
			var line_point := camera.lerp(target, t)
			var xz := Vector2(line_point.x, line_point.z)
			if not _point_is_active(xz, footprint, cell_count, local_bounds):
				continue
			var terrain_y := _sample_height(heights, cell_count, local_bounds, xz)
			if terrain_y + CAMERA_LINE_CLEARANCE >= line_point.y:
				return false
	return true


static func _active_content_bounds(
	heights: PackedFloat32Array,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var width := cell_count.x + 1
	for cell_z in range(cell_count.y):
		for cell_x in range(cell_count.x):
			if footprint[cell_z * cell_count.x + cell_x] == 0:
				continue
			for corner in [Vector2i(cell_x, cell_z), Vector2i(cell_x + 1, cell_z),
					Vector2i(cell_x, cell_z + 1), Vector2i(cell_x + 1, cell_z + 1)]:
				var point := Vector3(
					lerpf(local_bounds.position.x, local_bounds.end.x, float(corner.x) / float(cell_count.x)),
					heights[corner.y * width + corner.x],
					lerpf(local_bounds.position.y, local_bounds.end.y, float(corner.y) / float(cell_count.y))
				)
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum).grow(0.01) if minimum.is_finite() else AABB()


static func _sample_height(
	heights: PackedFloat32Array,
	cell_count: Vector2i,
	local_bounds: Rect2,
	point: Vector2
) -> float:
	var grid := Vector2(
		clampf((point.x - local_bounds.position.x) / local_bounds.size.x, 0.0, 1.0) * cell_count.x,
		clampf((point.y - local_bounds.position.y) / local_bounds.size.y, 0.0, 1.0) * cell_count.y
	)
	var x0 := mini(floori(grid.x), cell_count.x - 1)
	var z0 := mini(floori(grid.y), cell_count.y - 1)
	var uv := Vector2(grid.x - float(x0), grid.y - float(z0))
	var width := cell_count.x + 1
	var h00 := heights[z0 * width + x0]
	var h10 := heights[z0 * width + x0 + 1]
	var h01 := heights[(z0 + 1) * width + x0]
	var h11 := heights[(z0 + 1) * width + x0 + 1]
	return lerpf(lerpf(h00, h10, uv.x), lerpf(h01, h11, uv.x), uv.y)


static func _point_is_active(
	point: Vector2,
	footprint: PackedByteArray,
	cell_count: Vector2i,
	local_bounds: Rect2
) -> bool:
	if not local_bounds.has_point(point):
		return false
	var x := clampi(floori((point.x - local_bounds.position.x) / local_bounds.size.x * cell_count.x), 0, cell_count.x - 1)
	var z := clampi(floori((point.y - local_bounds.position.y) / local_bounds.size.y * cell_count.y), 0, cell_count.y - 1)
	return footprint[z * cell_count.x + x] != 0


static func _segment_address(point: Vector2, start: Vector2, end: Vector2) -> Dictionary:
	var delta := end - start
	var length_squared := delta.length_squared()
	var t := clampf((point - start).dot(delta) / length_squared, 0.0, 1.0) \
			if length_squared > 0.0001 else 0.0
	var closest := start + delta * t
	return {"t": t, "distance": point.distance_to(closest)}


static func _compact_ellipse(point: Vector2, center: Vector2, radius: Vector2) -> float:
	var safe_radius := Vector2(maxf(radius.x, 0.01), maxf(radius.y, 0.01))
	var normalized := (point - center) / safe_radius
	return _smootherstep(1.0 - normalized.length())


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
	local_bounds: Rect2
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
				- float(leg_data.goal_recess)
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
	var union_range_metrics := _measure_union_admission(admission_points, result.legs)
	# Persist only deterministic provenance; elapsed build time belongs to the
	# transient build result and would make identical artifacts hash differently.
	union_range_metrics["algorithm_version"] = ALGORITHM_VERSION
	result.union_range_metrics = union_range_metrics
	result.content_bounds = _active_content_bounds(
		heights, footprint, cell_count, local_bounds
	)
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


static func _smootherstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


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
