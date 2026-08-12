class_name CannonGolfSettlementGoal
extends Node3D

const RIM_SEGMENTS := 16
const FLOOR_THICKNESS := 0.28

var inner_radius := 5.5
var settle_seconds := 1.15
var maximum_linear_speed := 0.72
var maximum_angular_speed := 2.2


func configure(world_position: Vector3, radius: float) -> void:
	position = world_position
	inner_radius = radius


func _ready() -> void:
	_build_floor()
	_build_rim()
	_build_flag()


func contains_ball(ball_position: Vector3, ball_radius: float) -> bool:
	var origin := global_position if is_inside_tree() else position
	var local := ball_position - origin
	return _local_horizontal_contains(local, ball_radius) \
			and local.y >= -0.45 and local.y <= 3.2


func contains_rebound_column(ball_position: Vector3, ball_radius: float) -> bool:
	var origin := global_position if is_inside_tree() else position
	var local := ball_position - origin
	return _local_horizontal_contains(local, ball_radius) and local.y >= -0.45


func motion_is_safe(linear_velocity: Vector3, angular_velocity: Vector3) -> bool:
	return linear_velocity.length() <= maximum_linear_speed \
			and angular_velocity.length() <= maximum_angular_speed


func _local_horizontal_contains(local_position: Vector3, ball_radius: float) -> bool:
	return Vector2(local_position.x, local_position.z).length() \
			<= inner_radius - ball_radius * 0.35


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "GoalFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position.y = -FLOOR_THICKNESS * 0.5 + 0.04
	var floor_physics := PhysicsMaterial.new()
	floor_physics.friction = 1.0
	floor_physics.rough = true
	floor_physics.bounce = 0.72
	floor_physics.absorbent = true
	floor_body.physics_material_override = floor_physics
	add_child(floor_body)
	var shape := CylinderShape3D.new()
	shape.radius = inner_radius
	shape.height = FLOOR_THICKNESS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	var mesh_data := CylinderMesh.new()
	mesh_data.top_radius = inner_radius
	mesh_data.bottom_radius = inner_radius
	mesh_data.height = FLOOR_THICKNESS
	mesh_data.radial_segments = 32
	mesh_data.material = _material(Color("E7E0CB"), 0.0, 0.94)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_data
	floor_body.add_child(mesh)


func _build_rim() -> void:
	var rim_material := _material(Color("F6F2E7"), 0.04, 0.72)
	var rim_physics := PhysicsMaterial.new()
	rim_physics.friction = 0.94
	rim_physics.rough = true
	rim_physics.bounce = 0.35
	rim_physics.absorbent = true
	var segment_length := TAU * (inner_radius + 0.25) / float(RIM_SEGMENTS) * 1.08
	for index in range(RIM_SEGMENTS):
		var angle := TAU * float(index) / float(RIM_SEGMENTS)
		var body := StaticBody3D.new()
		body.name = "GoalRim%02d" % (index + 1)
		body.collision_layer = 1
		body.collision_mask = 0
		body.physics_material_override = rim_physics
		body.position = Vector3(
			sin(angle) * (inner_radius + 0.28),
			0.82,
			cos(angle) * (inner_radius + 0.28)
		)
		body.rotation.y = angle + PI * 0.5
		add_child(body)
		var size := Vector3(0.62, 1.64, segment_length)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var mesh_data := BoxMesh.new()
		mesh_data.size = size
		mesh_data.material = rim_material
		var mesh := MeshInstance3D.new()
		mesh.mesh = mesh_data
		body.add_child(mesh)


func _build_flag() -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.07
	pole_mesh.height = 6.2
	pole_mesh.radial_segments = 10
	pole_mesh.material = _material(Color("13243A"), 0.22, 0.44)
	pole.mesh = pole_mesh
	pole.position = Vector3(inner_radius * 0.72, 3.1, 0.0)
	add_child(pole)
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.9, 0.9, 0.08)
	flag_mesh.material = _material(Color("2584FF"), 0.08, 0.42)
	flag.mesh = flag_mesh
	flag.position = Vector3(inner_radius * 0.72 - 0.9, 5.55, 0.0)
	add_child(flag)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
