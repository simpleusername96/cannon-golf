class_name CannonGolfTrajectoryCourseGenerator
extends RefCounted

## Fast constructive authoring path: choose flight legs first, then build one
## connected heightfield below those flights. It performs no candidate beam or
## live-physics search.

const ALGORITHM_VERSION := 1
const CELL_COUNT := Vector2i(64, 96)
const LOCAL_BOUNDS := Rect2(Vector2(-105.0, -210.0), Vector2(210.0, 320.0))
const TERRAIN_SHADER := preload("res://src/cannon_golf/cannon_golf_terrain.gdshader")
const GOAL_RECESS := 4.0
const GOAL_LIP_HEIGHT := 1.6
const GOAL_OUTER_BLEND := 5.0
const CORRIDOR_HALF_WIDTH := 18.0
const CORRIDOR_CLEARANCE := 3.0
const LANDING_CENTER_CLEARANCE := 0.35
const START_SUPPORT_RADIUS := 9.0
const COURSE_DEADLINE_MSEC := 60000
const SETUP_TABLE := [
	Vector3(50.0, 30.0, 65.0),
	Vector3(50.0, 35.0, 70.0),
	Vector3(50.0, 40.0, 75.0),
]
const DELTA_TARGETS := [-12.0, 4.0, 16.0, -5.0, 10.0, 0.0]


static func build(course: CannonGolfCourseData, deadline_msec: int = 0) -> Dictionary:
	if course == null or not course.is_valid():
		return {}
	var started_msec := Time.get_ticks_msec()
	var deadline := deadline_msec if deadline_msec > 0 else started_msec + COURSE_DEADLINE_MSEC
	var course_index := CannonGolfCourseCatalog.index_of(course.course_id)
	if course_index < 0:
		return {}
	var plan := _plan_legs(course, course_index)
	if plan.is_empty() or _expired(deadline):
		return {}
	var heights := _build_heights(course, course_index, plan, deadline)
	if heights.is_empty() or _expired(deadline):
		return {}
	var footprint := PackedByteArray()
	footprint.resize(CELL_COUNT.x * CELL_COUNT.y)
	footprint.fill(1)
	var topology := TerrainTopTopology.build(CELL_COUNT, LOCAL_BOUNDS, heights, footprint)
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
	layout.cell_count = CELL_COUNT
	layout.local_bounds = LOCAL_BOUNDS
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


static func _plan_legs(course: CannonGolfCourseData, course_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lateral := 65.0 + float(course_index % 3) * 5.0
	var z_step := 43.0 + float(course_index % 2) * 4.0
	var launcher := Vector3(
		-lateral if course_index % 2 == 0 else lateral,
		4.05 + float(course_index % 3) * 2.0,
		82.0
	)
	for leg_index in range(course.leg_count()):
		var goal_x := -launcher.x
		var goal_z := 82.0 - float(leg_index + 1) * z_step
		var distance := Vector2(launcher.x, launcher.z).distance_to(Vector2(goal_x, goal_z))
		var goal_radius := clampf(
			10.0 + float((course_index + leg_index) % 2), 10.0, 11.0
		)
		var choice := _choose_setup(distance, goal_radius, course_index, leg_index)
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
			"rim_y": goal_floor_y + GOAL_RECESS,
			"lip_y": goal_floor_y + GOAL_RECESS + GOAL_LIP_HEIGHT,
			"yaw": yaw,
			"distance": distance,
			"setup": choice.setup,
			"near_clearance": choice.near_clearance,
			"default_separation": choice.default_separation,
		})
		launcher = goal + Vector3.UP * 0.05
	return result


static func _choose_setup(
		distance: float, goal_radius: float, course_index: int, leg_index: int
) -> Dictionary:
	var desired_delta := float(DELTA_TARGETS[(course_index + leg_index) % DELTA_TARGETS.size()])
	var best := {}
	var best_score := INF
	for setup_variant in SETUP_TABLE:
		var setup: Vector3 = setup_variant
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
			continue
		var near_clearance := near_height - center_height
		var required_clearance := GOAL_RECESS + GOAL_LIP_HEIGHT \
				+ CannonGolfBallistics.BALL_RADIUS + LANDING_CENTER_CLEARANCE
		var default_separation := absf(default_height - center_height) \
				if is_finite(default_height) else INF
		if near_clearance < required_clearance or default_separation < 6.0:
			continue
		var landing_delta := center_height - CannonGolfBallistics.BALL_RADIUS \
				- LANDING_CENTER_CLEARANCE
		var score := absf(landing_delta - desired_delta)
		if score < best_score:
			best_score = score
			best = {
				"setup": setup,
				"center_height": center_height,
				"near_clearance": near_clearance,
				"default_separation": default_separation,
			}
	return best


static func _build_heights(
		course: CannonGolfCourseData,
		course_index: int,
		plan: Array[Dictionary],
		deadline_msec: int
) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	var sample_size := CELL_COUNT + Vector2i.ONE
	heights.resize(sample_size.x * sample_size.y)
	var start_surface_y := float(plan[0].launcher.y) - 0.05
	for sample_z in range(sample_size.y):
		if _expired(deadline_msec):
			return PackedFloat32Array()
		var z := lerpf(
			LOCAL_BOUNDS.position.y, LOCAL_BOUNDS.end.y,
			float(sample_z) / float(CELL_COUNT.y)
		)
		for sample_x in range(sample_size.x):
			var x := lerpf(
				LOCAL_BOUNDS.position.x, LOCAL_BOUNDS.end.x,
				float(sample_x) / float(CELL_COUNT.x)
			)
			var point := Vector2(x, z)
			var height := _natural_height(course_index, course.terrain_seed_window.x, point)
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
			heights[sample_z * sample_size.x + sample_x] = height
	return heights


static func _natural_height(course_index: int, seed: int, point: Vector2) -> float:
	var phase := float(posmod(seed, 997)) * 0.013
	var base := 7.0 + sin(point.x * 0.055 + phase) * 4.0 \
			+ cos(point.y * 0.038 - phase * 0.7) * 5.0 \
			+ sin((point.x + point.y) * 0.027 + phase * 1.7) * 3.0
	var style := course_index % 5
	if style == 0:
		base += 38.0 * _gaussian(point, Vector2(-28.0, -65.0), Vector2(34.0, 82.0))
		base += 22.0 * _gaussian(point, Vector2(45.0, -145.0), Vector2(30.0, 52.0))
	elif style == 1:
		base += 34.0 * _gaussian(point, Vector2(-70.0, -80.0), Vector2(30.0, 95.0))
		base += 34.0 * _gaussian(point, Vector2(70.0, -80.0), Vector2(30.0, 95.0))
		base -= 13.0 * _gaussian(point, Vector2(0.0, -75.0), Vector2(46.0, 105.0))
	elif style == 2:
		base += 31.0 * _gaussian(point, Vector2(18.0, -95.0), Vector2(58.0, 78.0))
		base = roundf(base / 6.0) * 6.0
	elif style == 3:
		base += 45.0 * _gaussian(point, Vector2(-48.0, -82.0), Vector2(26.0, 42.0))
		base += 41.0 * _gaussian(point, Vector2(52.0, -130.0), Vector2(28.0, 46.0))
	else:
		base += 30.0 * _gaussian(point, Vector2(0.0, -110.0), Vector2(86.0, 120.0))
		base -= 24.0 * _gaussian(point, Vector2(0.0, -105.0), Vector2(40.0, 62.0))
	return base


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
	if distance >= radius + GOAL_OUTER_BLEND:
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
	var outer_t := _smoothstep((distance - radius) / GOAL_OUTER_BLEND)
	return lerpf(lip_y, height, outer_t)


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
		elapsed_msec: int
) -> CannonGolfGeneratedCourse:
	var result := CannonGolfGeneratedCourse.new()
	result.layout = layout
	result.geometry = geometry
	result.route_graph = route_graph
	result.source_route_graph = route_graph
	result.source_heights = heights
	result.source_footprint = footprint
	result.landform_metrics = {
		"algorithm_version": ALGORITHM_VERSION,
		"relief": _maximum_height(heights) - _minimum_height(heights),
		"style_index": CannonGolfCourseCatalog.index_of(course.course_id) % 5,
	}
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
				- GOAL_RECESS - GOAL_LIP_HEIGHT
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
		Vector3(LOCAL_BOUNDS.position.x, minimum_height, LOCAL_BOUNDS.position.y),
		Vector3(LOCAL_BOUNDS.size.x, maximum_height - minimum_height, LOCAL_BOUNDS.size.y)
	).grow(0.01)
	var expanded_play_bounds := result.content_bounds.grow(24.0)
	expanded_play_bounds.size.y += 150.0
	result.play_bounds = expanded_play_bounds
	if not result.is_valid():
		return null
	result.seal()
	return result


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
