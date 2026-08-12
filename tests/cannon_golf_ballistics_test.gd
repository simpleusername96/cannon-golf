extends SceneTree


func _initialize() -> void:
	var launcher := CannonGolfLauncher.new()
	root.add_child(launcher)
	launcher.position = Vector3(2.0, 1.0, 5.0)
	launcher.yaw_degrees = 7.0
	launcher.set_setup(41.0, 62.0)
	var origin_a := launcher.launch_origin()
	var velocity_a := launcher.launch_velocity()
	var origin_b := launcher.launch_origin()
	var velocity_b := launcher.launch_velocity()
	_assert_true(origin_a.distance_to(origin_b) <= 0.000001, "Identical setup must keep the same origin.")
	_assert_true(velocity_a.distance_to(velocity_b) <= 0.000001, "Identical setup must keep the same velocity.")
	launcher.set_setup(41.0, 78.0)
	_assert_true(launcher.launch_speed() > velocity_a.length(), "Higher power must increase launch speed.")
	_assert_true(launcher.launch_direction().is_normalized(), "Launch direction must be normalized.")
	print("Cannon Golf ballistics contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
