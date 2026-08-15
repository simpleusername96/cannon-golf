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
	var halo := launcher.get_node_or_null("AimHalo")
	_assert_true(
		halo != null and halo.position.y >= 2.0,
		"The aim halo must float clearly above the scaled launcher base."
	)
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
	var yaw_tick := halo.get_node_or_null("YawTick") as MeshInstance3D
	var elevation_bead := halo.get_node_or_null("ElevationBead") as MeshInstance3D
	var yaw_ring := halo.get_node_or_null("YawRing") as MeshInstance3D
	var yaw_ring_accent := halo.get_node_or_null("YawRingAccent") as MeshInstance3D
	var elevation_arc := halo.get_node_or_null("ElevationArc") as Node3D
	var accent_material := yaw_tick.mesh.surface_get_material(0) as StandardMaterial3D
	var bead_material := elevation_bead.mesh.surface_get_material(0) as StandardMaterial3D
	var guide_material := yaw_ring.mesh.surface_get_material(0) as StandardMaterial3D
	var readability_material := yaw_ring_accent.mesh.surface_get_material(0) \
			as StandardMaterial3D
	var minimum_arc_height := INF
	for arc_child in elevation_arc.get_children():
		minimum_arc_height = minf(minimum_arc_height, (arc_child as MeshInstance3D).position.y)
	_assert_true(
		accent_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and accent_material.no_depth_test \
				and bead_material.no_depth_test \
				and guide_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and not guide_material.no_depth_test \
				and guide_material.albedo_color.get_luminance() < 0.12 \
				and readability_material.no_depth_test \
				and readability_material.albedo_color.get_luminance() < 0.12,
		"The halo must use a dark unshaded surface guide and compact no-depth active markers."
	)
	_assert_true(
		elevation_arc.get_child_count() >= 17 and minimum_arc_height > 0.0,
		"The complete dotted elevation scale must remain above the halo's horizontal plane."
	)
	var all_halo_meshes: Array[MeshInstance3D] = [
		yaw_ring, yaw_ring_accent, yaw_tick, elevation_bead,
	]
	for arc_child in elevation_arc.get_children():
		all_halo_meshes.append(arc_child as MeshInstance3D)
	var shadows_disabled := true
	for halo_mesh in all_halo_meshes:
		shadows_disabled = shadows_disabled \
				and halo_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_assert_true(
		shadows_disabled,
		"Every halo guide and active marker must remain shadow-free."
	)
	launcher.set_first_person_visuals_hidden(true)
	var cannon_eye_offset := launcher.first_person_eye_position() - launcher.global_position
	_assert_true(
		halo.visible and not launcher.get_node("LauncherVisualRoot").visible \
				and (halo.position - cannon_eye_offset).is_equal_approx(
					launcher.launch_direction() * halo.CANNON_FORWARD_DISTANCE
				) \
				and halo.scale.is_equal_approx(
					Vector3.ONE * halo.CANNON_PRESENTATION_SCALE
				),
		"Cannon first-person must place a compact halo ahead along the real launch direction."
	)
	launcher.set_first_person_visuals_hidden(false)
	_assert_true(
		halo.position.y == halo.FLOAT_HEIGHT and halo.scale.is_equal_approx(Vector3.ONE) \
				and yaw_tick.scale.is_equal_approx(Vector3.ONE) \
				and elevation_bead.scale.is_equal_approx(Vector3.ONE),
		"Returning to planning must restore ordinary world-space marker scale."
	)
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
