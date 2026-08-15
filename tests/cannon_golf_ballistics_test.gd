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
	_assert_true(
		is_equal_approx(CannonGolfBallistics.MINIMUM_SPEED, 28.0 * sqrt(1.5)) \
				and is_equal_approx(CannonGolfBallistics.MAXIMUM_SPEED, 120.0 * sqrt(1.5)),
		"Canonical launch-speed endpoints must compensate for the 1.5x horizontal range."
	)
	_assert_true(
		is_equal_approx(CannonGolfBallistics.BALL_RADIUS, 2.0) \
				and is_equal_approx(CannonGolfBallistics.BALL_RADIUS, CannonGolfBall.RADIUS),
		"Ballistics and the live rigid body must share the accepted 2.0 m radius."
	)
	_assert_true(
		is_equal_approx(CannonGolfBallistics.launch_speed(100.0), 120.0 * sqrt(1.5)) \
				and is_equal_approx(CannonGolfBallistics.launch_speed(10.0), 37.2 * sqrt(1.5)),
		"Legal power endpoint speed mapping must stay exact and canonical."
	)
	var launcher := CannonGolfLauncher.new()
	root.add_child(launcher)
	await process_frame
	launcher.position = Vector3(2.0, 1.0, 5.0)
	launcher.shot_axis_yaw_degrees = 7.0
	launcher.set_setup(63.0, 41.0, 62.0)
	var halo := launcher.get_node_or_null("AimHalo")
	_assert_true(halo != null and halo.position.y > 0.0, "The aim halo must float above the base.")
	_assert_true(
		halo.get_node_or_null("YawTick") != null,
		"The aim halo must expose a compact perimeter yaw tick."
	)
	_assert_true(
		halo.get_node_or_null("ElevationArc") != null \
				and halo.get_node_or_null("ElevationBead") != null,
		"The aim halo must expose a dotted elevation arc and active bead."
	)
	_assert_true(
		halo.get_node_or_null("DirectionWedge") == null,
		"The aim halo must not restore the second-barrel direction wedge."
	)
	_assert_true(
		is_equal_approx(halo.rotation_degrees.y, -launcher.yaw_degrees) \
				and is_equal_approx(halo.indicated_elevation_degrees(), 41.0),
		"The halo must track both canonical launcher angles."
	)
	launcher.set_first_person_visuals_hidden(true)
	_assert_true(not halo.visible, "Cannon first-person must hide the world-space aim halo.")
	launcher.set_first_person_visuals_hidden(false)
	var origin_a := launcher.launch_origin()
	var velocity_a := launcher.launch_velocity()
	var origin_b := launcher.launch_origin()
	var velocity_b := launcher.launch_velocity()
	_assert_true(origin_a.distance_to(origin_b) <= 0.000001, "Identical setup must keep the same origin.")
	_assert_true(velocity_a.distance_to(velocity_b) <= 0.000001, "Identical setup must keep the same velocity.")
	_assert_true(
		is_equal_approx(velocity_a.length(), CannonGolfBallistics.launch_speed(62.0)),
		"The launcher must apply the doubled canonical speed exactly once."
	)
	launcher.set_setup(63.0, 41.0, 78.0)
	_assert_true(launcher.launch_speed() > velocity_a.length(), "Higher power must increase launch speed.")
	_assert_true(launcher.launch_direction().is_normalized(), "Launch direction must be normalized.")
	for distance in [30.0, 75.0, 120.0, 180.0, 240.0]:
		var exact_interval := CannonGolfBallistics.reachable_height_interval(distance)
		var sampled_interval := CannonGolfBallistics.sampled_reachable_height_interval(distance)
		_assert_true(
			exact_interval.is_finite() and sampled_interval.is_finite() \
					and sampled_interval.x >= exact_interval.x - 0.0001 \
					and sampled_interval.y <= exact_interval.y + 0.0001,
			"Sampled admission interval must remain a fail-closed subset at %.0fm." % distance
		)
	print("Cannon Golf ballistics contract passed.")
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
