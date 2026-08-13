extends SceneTree


func _initialize() -> void:
	_assert_true(
		is_equal_approx(CannonGolfBallistics.yaw_offset_degrees(50.0), 0.0),
		"Horizontal 50 must follow the generated shot axis."
	)
	_assert_true(
		is_equal_approx(CannonGolfBallistics.yaw_offset_degrees(0.0), -80.0) \
				and is_equal_approx(CannonGolfBallistics.yaw_offset_degrees(100.0), 80.0),
		"Horizontal endpoints must map to the full legal yaw fan."
	)
	_assert_true(
		CannonGolfBallistics.canonical_elevation(-10.0) == 10.0 \
				and CannonGolfBallistics.canonical_elevation(99.0) == 68.0 \
				and CannonGolfBallistics.canonical_power(-1.0) == 10.0 \
				and CannonGolfBallistics.canonical_power(101.0) == 100.0,
		"Vertical angle and power clamping must be stable."
	)
	var launcher := CannonGolfLauncher.new()
	root.add_child(launcher)
	launcher.position = Vector3(2.0, 1.0, 5.0)
	launcher.shot_axis_yaw_degrees = 7.0
	launcher.set_setup(63.0, 41.0, 62.0)
	var origin_a := launcher.launch_origin()
	var velocity_a := launcher.launch_velocity()
	var origin_b := launcher.launch_origin()
	var velocity_b := launcher.launch_velocity()
	_assert_true(origin_a.distance_to(origin_b) <= 0.000001, "Identical setup must keep the same origin.")
	_assert_true(velocity_a.distance_to(velocity_b) <= 0.000001, "Identical setup must keep the same velocity.")
	launcher.set_setup(63.0, 41.0, 78.0)
	_assert_true(launcher.launch_speed() > velocity_a.length(), "Higher power must increase launch speed.")
	_assert_true(launcher.launch_direction().is_normalized(), "Launch direction must be normalized.")
	print("Cannon Golf ballistics contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
