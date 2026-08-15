extends SceneTree

var _ball: CannonGolfBall
var _contacts := 0
var _incoming_down_speed := 0.0
var _maximum_rebound_speed := 0.0
var _frames := 0
var _geometry_checked := false


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	floor.collision_mask = 0
	floor.add_to_group(&"impact_mark_surface")
	world.add_child(floor)
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 1.0, 20.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor.add_child(collision)
	_ball = CannonGolfBall.new()
	_ball.configure(AABB(Vector3(-15, -10, -15), Vector3(30, 35, 30)), Vector3(0, 8, 0), Vector3(0, -12, 0))
	_ball.first_surface_contact.connect(_on_contact)
	world.add_child(_ball)
	process_frame.connect(_on_frame)


func _on_contact(_contact_ball: CannonGolfBall, _position: Vector3, normal: Vector3) -> void:
	_contacts += 1
	_incoming_down_speed = maxf(_incoming_down_speed, 12.0)
	_assert_true(normal.dot(Vector3.UP) > 0.8, "Floor contact normal must point upward.")


func _on_frame() -> void:
	_frames += 1
	if not _geometry_checked:
		_geometry_checked = true
		var ball_shape := (_ball.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
		var ball_mesh := (_ball.get_node("GolfBallMesh") as MeshInstance3D).mesh as SphereMesh
		_assert_true(
			is_equal_approx(CannonGolfBall.RADIUS, 2.0) \
					and is_equal_approx(ball_shape.radius, CannonGolfBall.RADIUS) \
					and is_equal_approx(ball_mesh.radius, CannonGolfBall.RADIUS),
			"The live collider and rendered ball must share the accepted 2.0 m radius."
		)
		_assert_true(
			is_equal_approx(_ball.linear_damp, 0.20) \
					and is_equal_approx(_ball.angular_damp, 0.84) \
					and is_equal_approx(_ball.gravity_scale, 4.0) \
					and is_equal_approx(CannonGolfBall.MAXIMUM_FLIGHT_SECONDS, 15.0),
			"The live ball must apply temporal scaling and the fifteen-second no-contact guard."
		)
	if _contacts > 0 and is_instance_valid(_ball):
		_maximum_rebound_speed = maxf(_maximum_rebound_speed, _ball.linear_velocity.y)
	if _frames < 360:
		return
	_assert_true(_contacts == 1, "Ball must publish exactly one first contact.")
	_assert_true(_maximum_rebound_speed > 1.0, "Ordinary terrain must produce a visible rebound.")
	_assert_true(_maximum_rebound_speed < _incoming_down_speed, "Rebound must lose energy.")
	print("Cannon Golf rigid-body rebound contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
