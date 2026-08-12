class_name CannonGolfCourseTerrainFactory
extends RefCounted

## Cannon Golf adapter for Paint Mountain's canonical terrain pipeline.
##
## The retained route resolver and mountain synthesizer own the mountain form.
## This adapter only maps it into the smaller golf world and depresses one
## route-adjacent patch before the canonical topology and geometry are built.

const TERRAIN_SHADER := preload("res://src/cannon_golf/cannon_golf_terrain.gdshader")
const CANNON_FRONT_STANDOFF := 8.0
const GOAL_FLOOR_RATIO := 0.56
const GOAL_BLEND_WIDTH := 2.4
const TERRAIN_BASE_Y := -14.0


static func build(course: CannonGolfCourseData) -> Dictionary:
	assert(course != null and course.is_valid(), "Terrain factory requires valid course data.")
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
	var goal_surface_y := preliminary.height_at_local(goal_xz.x, goal_xz.y)
	var goal_floor_y := goal_surface_y - course.goal_recess_depth
	_depress_goal_samples(heights, contract.cell_count, bounds, goal_xz, goal_floor_y, course.goal_radius)
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
	var shot_yaw := rad_to_deg(atan2(aim_delta.x, -aim_delta.z))
	var play_minimum := Vector3(bounds.position.x - 12.0, TERRAIN_BASE_Y - 3.0, bounds.position.y - 12.0)
	var play_maximum := Vector3(bounds.end.x + 12.0, 34.0, maxf(bounds.end.y + 22.0, cannon_position.z + 12.0))
	return {
		"layout": layout,
		"geometry": geometry,
		"route_graph": route_graph,
		"source_route_graph": source_graph,
		"source_heights": generated.heights,
		"source_footprint": generated.footprint,
		"goal_position": goal_position,
		"goal_rim_y": goal_surface_y,
		"cannon_position": cannon_position,
		"shot_yaw_degrees": shot_yaw,
		"play_bounds": AABB(play_minimum, play_maximum - play_minimum),
	}


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


static func _depress_goal_samples(
		heights: PackedFloat32Array,
		cell_count: Vector2i,
		bounds: Rect2,
		goal_xz: Vector2,
		goal_floor_y: float,
		goal_radius: float
) -> void:
	var sample_size := cell_count + Vector2i.ONE
	var floor_radius := goal_radius * GOAL_FLOOR_RATIO
	var outer_radius := goal_radius + GOAL_BLEND_WIDTH
	for sample_z in range(sample_size.y):
		var z := lerpf(bounds.position.y, bounds.end.y, float(sample_z) / float(cell_count.y))
		for sample_x in range(sample_size.x):
			var x := lerpf(bounds.position.x, bounds.end.x, float(sample_x) / float(cell_count.x))
			var distance := Vector2(x, z).distance_to(goal_xz)
			if distance >= outer_radius:
				continue
			var index := sample_z * sample_size.x + sample_x
			if distance <= floor_radius:
				heights[index] = goal_floor_y
				continue
			var blend := (distance - floor_radius) / (outer_radius - floor_radius)
			var smooth_blend := blend * blend * (3.0 - 2.0 * blend)
			heights[index] = lerpf(goal_floor_y, heights[index], smooth_blend)


static func _apply_material(mesh: ArrayMesh, course: CannonGolfCourseData) -> void:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter(&"rock_color", course.terrain_color)
	material.set_shader_parameter(&"accent_color", course.terrain_accent_color)
	material.set_shader_parameter(&"shell_color", course.terrain_accent_color.darkened(0.48))
	mesh.surface_set_material(0, material)
