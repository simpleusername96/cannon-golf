class_name CannonGolfCourseBuilder
extends Node3D

var course: CannonGolfCourseData
var launcher: CannonGolfLauncher
var goal: CannonGolfSettlementGoal


func build(selected_course: CannonGolfCourseData) -> void:
	assert(selected_course != null and selected_course.is_valid(), "Course builder requires valid data.")
	clear_course()
	course = selected_course
	for index in range(course.block_centers.size()):
		_add_terrain_block(
			index,
			course.block_centers[index],
			course.block_sizes[index],
			course.block_yaw_degrees[index]
		)
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
	launcher = null
	goal = null
	course = null


func terrain_body_count() -> int:
	var count := 0
	for child in get_children():
		if child is StaticBody3D and child.name.begins_with("TerrainBlock"):
			count += 1
	return count


func _add_terrain_block(index: int, center: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBlock%02d" % (index + 1)
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"impact_mark_surface")
	body.position = center
	body.rotation_degrees.y = yaw
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh_data := BoxMesh.new()
	mesh_data.size = size
	var color := course.terrain_color if index % 2 == 0 else course.terrain_accent_color
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_data.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "TerrainMesh"
	mesh.mesh = mesh_data
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh)
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.10
	physics.friction = 0.86
	body.physics_material_override = physics


func _add_dressing() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6E7C77")
	material.roughness = 1.0
	for index in range(7):
		var rock := MeshInstance3D.new()
		rock.name = "ScaleRock%02d" % (index + 1)
		var mesh := SphereMesh.new()
		mesh.radius = 0.55 + float(index % 3) * 0.14
		mesh.height = mesh.radius * 1.55
		mesh.radial_segments = 7
		mesh.rings = 4
		mesh.material = material
		rock.mesh = mesh
		var block_index := index % course.block_centers.size()
		var center := course.block_centers[block_index]
		var size := course.block_sizes[block_index]
		var side := -1.0 if index % 2 == 0 else 1.0
		rock.position = center + Vector3(
			side * (size.x * 0.42),
			size.y * 0.5 + mesh.radius * 0.6,
			(-0.28 + 0.09 * float(index)) * size.z
		)
		rock.scale = Vector3(1.0, 0.8, 1.12)
		add_child(rock)
