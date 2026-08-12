class_name CannonGolfCourseBuilder
extends Node3D

const TERRAIN_FACTORY := preload("res://src/cannon_golf/course_terrain_factory.gd")

var course: CannonGolfCourseData
var terrain_body: StaticBody3D
var launcher: CannonGolfLauncher
var goal: CannonGolfSettlementGoal


func build(selected_course: CannonGolfCourseData) -> void:
	assert(selected_course != null and selected_course.is_valid(), "Course builder requires valid data.")
	clear_course()
	course = selected_course
	var terrain: Dictionary = TERRAIN_FACTORY.build(course)
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
	var terrain_collision := CollisionShape3D.new()
	terrain_collision.name = "TerrainCollision"
	terrain_collision.shape = terrain["collision_shape"] as ConcavePolygonShape3D
	terrain_body.add_child(terrain_collision)
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	terrain_mesh.mesh = terrain["mesh"] as ArrayMesh
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_body.add_child(terrain_mesh)
	launcher = CannonGolfLauncher.new()
	launcher.name = "Launcher"
	launcher.configure(course)
	add_child(launcher)
	goal = CannonGolfSettlementGoal.new()
	goal.name = "SettlementGoal"
	goal.configure(course.goal_position, course.goal_radius)
	add_child(goal)
	_add_dressing()


func clear_course() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	terrain_body = null
	launcher = null
	goal = null
	course = null


func terrain_body_count() -> int:
	var count := 0
	for child in get_children():
		if child is StaticBody3D and child.name == "Terrain":
			count += 1
	return count


func _add_dressing() -> void:
	var placements := [
		{"model": "res://assets/nature/kenney/rock_smallA.glb", "block": 0, "side": -1.0, "depth": -0.22, "scale": 0.9},
		{"model": "res://assets/nature/kenney/tree_pineSmallA.glb", "block": 1, "side": 1.0, "depth": -0.28, "scale": 0.82},
		{"model": "res://assets/nature/kenney/rock_largeA.glb", "block": 2, "side": -1.0, "depth": 0.26, "scale": 0.72},
		{"model": "res://assets/nature/kenney/tree_pineSmallB.glb", "block": 3, "side": 1.0, "depth": 0.22, "scale": 0.78},
	]
	for index in range(placements.size()):
		var placement: Dictionary = placements[index]
		var model_path := String(placement["model"])
		var packed := load(model_path) as PackedScene
		if packed == null:
			continue
		var decoration := packed.instantiate() as Node3D
		if decoration == null:
			continue
		decoration.name = "NatureDressing%02d" % (index + 1)
		var block_index := int(placement["block"])
		var center := course.block_centers[block_index]
		var size := course.block_sizes[block_index]
		var yaw := deg_to_rad(course.block_yaw_degrees[block_index])
		var local_offset := Vector3(
			float(placement["side"]) * size.x * 0.72,
			-size.y * 0.5,
			float(placement["depth"]) * size.z
		)
		var world_offset := Basis(Vector3.UP, yaw) * local_offset
		decoration.position = center + world_offset + Vector3.UP * (size.y * 0.5)
		decoration.rotation.y = deg_to_rad(float(index * 37 - 18))
		decoration.scale = Vector3.ONE * float(placement["scale"])
		_apply_dressing_material(decoration, model_path.contains("tree_"))
		add_child(decoration)


func _apply_dressing_material(node: Node, is_tree: bool) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("40566A") if is_tree else Color("8F9696")
	material.roughness = 0.96
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).material_override = material
		_apply_dressing_material(child, is_tree)
