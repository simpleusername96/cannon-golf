extends SceneTree


func _initialize() -> void:
	_assert_true(
		is_equal_approx(CannonGolfBallistics.yaw_offset_degrees(50.0), 0.0),
		"Horizontal 50 must follow the generated shot axis."
	)
	_assert_true(
		is_equal_approx(CannonGolfBallistics.yaw_offset_degrees(0.0), -80.0) \
				and is_equal_approx(CannonGolfBallistics.yaw_offset_degrees(100.0), 80.0),
		"The established 0..100 setups must retain their prior yaw mapping."
	)
	_assert_true(
		CannonGolfBallistics.canonical_horizontal_aim(163.0) \
					== CannonGolfBallistics.MINIMUM_HORIZONTAL_AIM \
				and CannonGolfBallistics.canonical_horizontal_aim(-63.0) \
					== CannonGolfBallistics.MAXIMUM_HORIZONTAL_AIM \
				and CannonGolfBallistics.canonical_elevation(-99.0) == -90.0 \
				and CannonGolfBallistics.canonical_elevation(99.0) == 90.0 \
				and CannonGolfBallistics.canonical_power(-1.0) == 10.0 \
				and CannonGolfBallistics.canonical_power(101.0) == 100.0,
		"Horizontal aim must wrap through 360 degrees while elevation covers the full sphere."
	)
	_assert_true(
		is_equal_approx(CannonGolfBallistics.MINIMUM_SPEED, 56.0 * sqrt(1.5)) \
				and is_equal_approx(CannonGolfBallistics.MAXIMUM_SPEED, 240.0 * sqrt(1.5)),
		"Canonical launch-speed endpoints must apply the accepted four-times motion pace."
	)
	_assert_true(
		is_equal_approx(CannonGolfBallistics.ANALYTIC_STEP_SECONDS, 1.0 / 120.0) \
				and CannonGolfBallistics.MAXIMUM_STEPS == 600 \
				and is_equal_approx(
					CannonGolfBallistics.ANALYTIC_STEP_SECONDS
							* CannonGolfBallistics.MAXIMUM_STEPS,
					CannonGolfBallistics.MAXIMUM_FLIGHT_SECONDS
				),
		"The doubled live pace must preserve the prepared course-space analytic horizon."
	)
	_assert_authoring_recurrence_preserved()
	_assert_true(
		is_equal_approx(CannonGolfBallistics.BALL_RADIUS, 2.0) \
				and is_equal_approx(CannonGolfBallistics.BALL_RADIUS, CannonGolfBall.RADIUS),
		"Ballistics and the live rigid body must share the accepted 2.0 m radius."
	)
	_assert_true(
		is_equal_approx(CannonGolfBallistics.launch_speed(100.0), 240.0 * sqrt(1.5)) \
				and is_equal_approx(CannonGolfBallistics.launch_speed(10.0), 74.4 * sqrt(1.5)),
		"Legal power endpoint speed mapping must stay exact and canonical."
	)
	var launcher := CannonGolfLauncher.new()
	root.add_child(launcher)
	await process_frame
	launcher.position = Vector3(2.0, 1.0, 5.0)
	launcher.shot_axis_yaw_degrees = 7.0
	launcher.set_setup(63.0, 41.0, 62.0)
	var halo := launcher.get_node_or_null("AimHalo") as CannonGolfAimHalo
	var aim_curve := halo.get_node_or_null("AimCurve") as Node3D if halo != null else null
	var direction_arrow := halo.get_node_or_null("DirectionArrow") as MeshInstance3D \
			if halo != null else null
	_assert_true(
		halo != null and aim_curve != null and direction_arrow != null \
				and halo.get_node_or_null("YawRing") == null \
				and halo.get_node_or_null("ElevationArc") == null,
		"The aim guide must contain only the partial curve and connected arrow grammar."
	)
	var points := halo.sampled_points()
	var expected_local_origin := Vector3.UP * halo.FLOAT_HEIGHT
	_assert_true(
		points.size() >= 8 and points[0].is_equal_approx(expected_local_origin) \
				and halo.sampled_duration() <= halo.MAXIMUM_GUIDE_SECONDS + 0.0001 \
				and halo.sampled_path_length() > 32.0 \
				and halo.sampled_path_length() <= halo.MAXIMUM_PATH_LENGTH + 0.0001 \
				and halo.arrow_tangent().dot((points[-1] - points[-2]).normalized()) > 0.999,
		"The raised aim curve must stay partial and end in its motion tangent."
	)
	var arrow_material := direction_arrow.mesh.surface_get_material(0) as StandardMaterial3D
	var all_meshes: Array[MeshInstance3D] = [direction_arrow]
	var curve_material: StandardMaterial3D
	for child in aim_curve.get_children():
		var segment := child as MeshInstance3D
		all_meshes.append(segment)
		if curve_material == null:
			curve_material = segment.mesh.surface_get_material(0) as StandardMaterial3D
	_assert_true(
		curve_material != null \
				and curve_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and not curve_material.no_depth_test \
				and curve_material.albedo_color.get_luminance() < 0.18 \
				and arrow_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and arrow_material.no_depth_test,
		"The thin dark curve must depth-test while only the thick arrow bypasses depth."
	)
	var shadows_disabled := true
	for guide_mesh in all_meshes:
		shadows_disabled = shadows_disabled \
				and guide_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_assert_true(shadows_disabled, "Every aim-curve mesh must remain shadow-free.")
	launcher.set_cannon_view_active(true)
	_assert_true(
		halo.visible \
				and halo.scale.is_equal_approx(
					Vector3.ONE * CannonGolfAimHalo.CANNON_PERSPECTIVE_SCALE
				) \
				and launcher.get_node("LauncherVisualRoot").visible,
		"Cannon perspective must retain the cannon and a compact partial guide."
	)
	launcher.set_cannon_view_active(false)
	_assert_true(
		halo.visible and halo.position.is_zero_approx() and halo.scale.is_equal_approx(Vector3.ONE),
		"Returning to overview must restore the world-space aim curve."
	)
	launcher.set_setup(63.0, 90.0, 62.0)
	points = halo.sampled_points()
	_assert_true(
		points.size() >= 2 and points[-1].is_finite() \
				and (points[1] - points[0]).normalized().dot(launcher.launch_direction()) > 0.98,
		"Exact vertical aim must keep a finite curve with the correct initial direction."
	)
	launcher.set_setup(63.0, 41.0, 62.0)
	var origin_a := launcher.launch_origin()
	var velocity_a := launcher.launch_velocity()
	var origin_b := launcher.launch_origin()
	var velocity_b := launcher.launch_velocity()
	_assert_true(origin_a.distance_to(origin_b) <= 0.000001, "Identical setup must keep the same origin.")
	_assert_true(velocity_a.distance_to(velocity_b) <= 0.000001, "Identical setup must keep the same velocity.")
	_assert_true(
		is_equal_approx(velocity_a.length(), CannonGolfBallistics.launch_speed(62.0)),
		"The launcher must apply the four-times canonical speed exactly once."
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


func _assert_authoring_recurrence_preserved() -> void:
	var reference_scale := CannonGolfBallistics.COURSE_AUTHORING_TIME_SCALE
	var reference_cache := CannonBallistics.build_damped_motion_cache(
		0.10 * reference_scale,
		-9.8 * reference_scale * reference_scale,
		CannonGolfBallistics.PHYSICS_STEP_SECONDS,
		CannonGolfBallistics.MAXIMUM_STEPS
	)
	var current_cache := CannonGolfBallistics._damped_motion_cache()
	var reference_speed := CannonGolfBallistics.launch_speed(50.0) \
			* reference_scale / CannonGolfBallistics.MOTION_TIME_SCALE
	var current_speed := CannonGolfBallistics.launch_speed(50.0)
	var recurrence_matches := true
	for step_count in [1, 60, 300, CannonGolfBallistics.MAXIMUM_STEPS]:
		var reference_factor := float(reference_cache.horizontal_factors[step_count])
		var current_factor := float(current_cache.horizontal_factors[step_count])
		var reference_position := Vector2(
			reference_speed * reference_factor,
			reference_speed * reference_factor
					+ float(reference_cache.gravity_offsets[step_count])
		)
		var current_position := Vector2(
			current_speed * current_factor,
			current_speed * current_factor
					+ float(current_cache.gravity_offsets[step_count])
		)
		recurrence_matches = recurrence_matches \
				and reference_position.distance_to(current_position) <= 0.000001
	_assert_true(
		recurrence_matches,
		"Normalized analytics must reproduce the prepared course-authoring recurrence."
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
