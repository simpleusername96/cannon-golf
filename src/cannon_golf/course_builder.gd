class_name CannonGolfCourseBuilder
extends Node3D

const TERRAIN_FACTORY := preload("res://src/cannon_golf/course_terrain_factory.gd")

var course: CannonGolfCourseData
var terrain_body: StaticBody3D
var launcher: CannonGolfLauncher
var goal: CannonGolfSettlementGoal
var terrain_layout: GeneratedStageLayout
var terrain_geometry: TerrainGeometry


func build(selected_course: CannonGolfCourseData) -> void:
	assert(selected_course != null and selected_course.is_valid(), "Course builder requires valid data.")
	clear_course()
	# Generated positions are runtime data. Keep catalog resources immutable so
	# preview and gameplay builds cannot overwrite each other's course metadata.
	course = selected_course.duplicate(true) as CannonGolfCourseData
	var terrain: Dictionary = TERRAIN_FACTORY.build(course)
	terrain_layout = terrain.layout as GeneratedStageLayout
	terrain_geometry = terrain.geometry as TerrainGeometry
	_apply_generated_play_data(terrain)
	terrain_body = StaticBody3D.new()
	terrain_body.name = "Terrain"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0
	terrain_body.add_to_group(&"impact_mark_surface")
	var terrain_physics := PhysicsMaterial.new()
	terrain_physics.bounce = 0.10
	terrain_physics.friction = 0.86
	terrain_body.physics_material_override = terrain_physics
	add_child(terrain_body)
	var top_collision := CollisionShape3D.new()
	top_collision.name = "TerrainTopCollision"
	top_collision.shape = terrain_geometry.top_shape
	terrain_body.add_child(top_collision)
	var shell_collision := CollisionShape3D.new()
	shell_collision.name = "TerrainShellCollision"
	shell_collision.shape = terrain_geometry.skirt_shape
	terrain_body.add_child(shell_collision)
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	terrain_mesh.mesh = terrain_geometry.render_mesh
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_body.add_child(terrain_mesh)
	launcher = CannonGolfLauncher.new()
	launcher.name = "Launcher"
	launcher.configure(course)
	add_child(launcher)
	goal = CannonGolfSettlementGoal.new()
	goal.name = "SettlementGoal"
	goal.configure(course.goal_position, course.goal_radius, float(terrain.goal_rim_y))
	add_child(goal)
	_add_dressing()


func clear_course() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	terrain_body = null
	launcher = null
	goal = null
	terrain_layout = null
	terrain_geometry = null
	course = null


func terrain_body_count() -> int:
	var count := 0
	for child in get_children():
		if child is StaticBody3D and child.name == "Terrain":
			count += 1
	return count


func _apply_generated_play_data(terrain: Dictionary) -> void:
	course.cannon_position = terrain.cannon_position
	course.goal_position = terrain.goal_position
	course.shot_axis_yaw_degrees = float(terrain.shot_axis_yaw_degrees)
	course.play_bounds = terrain.play_bounds
	course.content_bounds = terrain.content_bounds
	course.planning_focus = course.cannon_position.lerp(course.goal_position, 0.5) + Vector3.UP * 2.0


func _add_dressing() -> void:
	var placements := [
		{"model": "res://assets/nature/kenney/rock_smallA.glb", "t": 0.78, "side": -1.0, "scale": 0.82},
		{"model": "res://assets/nature/kenney/tree_pineSmallA.glb", "t": 0.62, "side": 1.0, "scale": 0.72},
		{"model": "res://assets/nature/kenney/rock_largeA.glb", "t": 0.40, "side": -1.0, "scale": 0.68},
		{"model": "res://assets/nature/kenney/tree_pineSmallB.glb", "t": 0.27, "side": 1.0, "scale": 0.70},
	]
	var graph := terrain_layout.route_graph
	for index in range(placements.size()):
		var placement: Dictionary = placements[index]
		var packed := load(String(placement.model)) as PackedScene
		if packed == null:
			continue
		var decoration := packed.instantiate() as Node3D
		if decoration == null:
			continue
		var source_point := graph.route_position(0, float(placement.t))
		var source_tangent := graph.route_tangent(0, float(placement.t))
		var tangent := Vector2(source_tangent.x, source_tangent.z).normalized()
		var side := Vector2(-tangent.y, tangent.x) * float(placement.side) * 10.0
		var xz := Vector2(source_point.x, source_point.z) + side
		var surface_y := terrain_layout.height_at_local(xz.x, xz.y)
		decoration.name = "NatureDressing%02d" % (index + 1)
		decoration.position = Vector3(xz.x, surface_y, xz.y)
		decoration.rotation.y = deg_to_rad(float(index * 37 - 18))
		decoration.scale = Vector3.ONE * float(placement.scale)
		_apply_dressing_material(decoration, String(placement.model).contains("tree_"))
		add_child(decoration)


func _apply_dressing_material(node: Node, is_tree: bool) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("40566A") if is_tree else Color("8F9696")
	material.roughness = 0.96
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).material_override = material
		_apply_dressing_material(child, is_tree)
