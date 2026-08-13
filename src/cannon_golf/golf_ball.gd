class_name CannonGolfBall
extends RigidBody3D

signal first_surface_contact(ball: CannonGolfBall, world_position: Vector3, world_normal: Vector3)
signal launch_ended(ball: CannonGolfBall, reason: StringName)

const RADIUS := CannonGolfBallistics.BALL_RADIUS
const MAXIMUM_FLIGHT_SECONDS := CannonGolfBallistics.MAXIMUM_FLIGHT_SECONDS
const ORDINARY_ANGULAR_DAMP := 0.42 * CannonGolfBallistics.MOTION_TIME_SCALE
const SETTLEMENT_LINEAR_DAMP := 0.60 * CannonGolfBallistics.MOTION_TIME_SCALE
const SETTLEMENT_ANGULAR_DAMP := 1.20 * CannonGolfBallistics.MOTION_TIME_SCALE

var play_bounds := AABB(Vector3(-50.0, -15.0, -90.0), Vector3(100.0, 70.0, 130.0))
var _elapsed := 0.0
var _first_contact_emitted := false
var _ended := false
var _settlement_drag_active := false


func _ready() -> void:
	mass = 1.2
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = CannonGolfBallistics.LINEAR_DAMP
	angular_damp = ORDINARY_ANGULAR_DAMP
	gravity_scale = pow(CannonGolfBallistics.MOTION_TIME_SCALE, 2.0)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 12
	can_sleep = true
	collision_layer = 2
	collision_mask = 1
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.42
	physics.friction = 0.72
	physics_material_override = physics
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	add_child(collision)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("2584FF")
	material.metallic = 0.16
	material.roughness = 0.24
	sphere.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "GolfBallMesh"
	mesh.mesh = sphere
	add_child(mesh)


func configure(bounds: AABB, origin: Vector3, velocity: Vector3) -> void:
	play_bounds = bounds
	position = origin
	linear_velocity = velocity


func _physics_process(delta: float) -> void:
	if _ended or freeze:
		return
	_elapsed += delta
	if not play_bounds.has_point(global_position):
		end_launch(&"out_of_bounds")
	elif _elapsed >= MAXIMUM_FLIGHT_SECONDS:
		end_launch(&"timeout")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _ended or _first_contact_emitted or state.get_contact_count() <= 0:
		return
	var selected_index := -1
	var selected_impulse := -1.0
	for index in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(index) as Node
		if collider == null or not collider.is_in_group(&"impact_mark_surface"):
			continue
		var impulse := state.get_contact_impulse(index).length_squared()
		if impulse > selected_impulse:
			selected_index = index
			selected_impulse = impulse
	if selected_index < 0:
		return
	_first_contact_emitted = true
	first_surface_contact.emit(
		self,
		state.get_contact_collider_position(selected_index),
		state.get_contact_local_normal(selected_index).normalized()
	)


func end_launch(reason: StringName) -> void:
	if _ended:
		return
	_ended = true
	launch_ended.emit(self, reason)


func set_settlement_drag(enabled: bool) -> void:
	_settlement_drag_active = enabled
	linear_damp = SETTLEMENT_LINEAR_DAMP if enabled else CannonGolfBallistics.LINEAR_DAMP
	angular_damp = SETTLEMENT_ANGULAR_DAMP if enabled else ORDINARY_ANGULAR_DAMP


func settlement_drag_is_active() -> bool:
	return _settlement_drag_active


func lock_as_confirmed() -> void:
	set_settlement_drag(false)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	collision_layer = 0
	collision_mask = 0


func has_reported_first_contact() -> bool:
	return _first_contact_emitted
