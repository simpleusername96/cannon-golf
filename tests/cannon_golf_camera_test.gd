extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var catalog := CannonGolfCourseCatalog.all_courses()
	for index in [0, 3, 9]:
		var builder := CannonGolfCourseBuilder.new()
		root.add_child(builder)
		_assert_true(builder.build(catalog[index]), "Course must build for camera coverage.")
		var camera := Camera3D.new()
		camera.fov = 48.0
		root.add_child(camera)
		var rig := CannonGolfCourseCameraRig.new()
		root.add_child(rig)
		rig.configure(
			camera, builder.course, builder.prepared_course.local_bounds,
			Callable(builder, "height_at_local"), builder.presentation_bounds(),
			builder.camera_collision_exclusions()
		)
		_assert_true(rig.set_planning_context(
			builder.presentation_bounds(), builder.course.content_bounds.get_center(),
			builder.launcher.first_person_eye_position(), builder.launcher.launch_direction(),
			builder.launcher.yaw_degrees
		), "Camera context must accept the launcher pose.")
		rig.snap_to_planning()
		_assert_true(camera.global_position.is_finite(), "Reset overview must be finite.")
		for _step in range(10):
			rig.zoom_by_steps(1.0)
		rig.snap_to_planning()
		_assert_true(
			absf(rig.resolved_planning_distance() - 28.0) <= 0.3,
			"Ten zoom steps must resolve the 28 m close view."
		)
		rig.reset_planning_view()
		for _step in range(6):
			rig.zoom_by_steps(-1.0)
			rig.snap_to_planning()
		_assert_true(camera.global_position.is_finite(), "Six zoom-out steps must stay finite.")
		rig.reset_planning_view()
		rig.zoom_by_steps(CannonGolfCourseCameraRig.CLOSE_ZOOM)
		var close_drag_start := rig.planning_focus()
		_assert_true(
			rig.pan_drag(Vector2.ZERO, Vector2(120.0, 0.0)),
			"A drag immediately after close zoom must pan."
		)
		var close_drag_distance := rig.planning_focus().distance_to(close_drag_start)
		_assert_true(
			close_drag_distance <= CannonGolfCourseCameraRig.CLOSE_INSPECTION_DISTANCE * 0.08,
			"Close-view drag sensitivity must use the requested zoom, not a stale overview pose."
		)
		rig.snap_to_planning()
		var pre_pan_distance := rig.resolved_planning_distance()
		var old_focus := rig.planning_focus()
		_assert_true(rig.pan_drag(Vector2.ZERO, Vector2(80.0, -30.0)), "Left drag must pan.")
		rig.snap_to_planning()
		_assert_true(not rig.planning_focus().is_equal_approx(old_focus), "Pan must move the overview pivot.")
		_assert_true(
			absf(rig.resolved_planning_distance() - pre_pan_distance) <= 0.05,
			"Pan must translate the overview without changing its framing distance."
		)
		_assert_camera_boom_clear(rig, camera, builder, "Panned overview")
		_assert_true(rig.orbit(Vector2(80.0, -30.0)), "Right drag must orbit.")
		rig.snap_to_planning()
		_assert_camera_boom_clear(rig, camera, builder, "Orbited overview")

		_assert_true(rig.set_view(&"cannon"), "Cannon first-person must be available.")
		rig.snap_to_planning()
		var camera_forward := -camera.global_transform.basis.z
		_assert_true(
			camera.global_position.distance_to(builder.launcher.first_person_eye_position()) < 0.01
					and rad_to_deg(camera_forward.angle_to(builder.launcher.launch_direction())) < 0.1,
			"Cannon view must use the exact launcher eye and launch direction."
		)
		for vertical_sign in [-1.0, 1.0]:
			var previous_up := Vector3.ZERO
			for absolute_angle in [87.0, 88.0, 89.0, 90.0]:
				builder.launcher.set_setup(162.0, vertical_sign * absolute_angle, 50.0)
				_assert_true(
					rig.set_cannon_pose(
						builder.launcher.first_person_eye_position(),
						builder.launcher.launch_direction(),
						builder.launcher.yaw_degrees
					),
					"Near-vertical cannon aim must provide a valid camera pose."
				)
				rig.snap_to_planning()
				camera_forward = -camera.global_transform.basis.z
				var camera_up := camera.global_transform.basis.y
				_assert_true(
					camera.global_transform.basis.is_finite() \
							and rad_to_deg(
								camera_forward.angle_to(builder.launcher.launch_direction())
							) < 0.1,
					"Exact vertical cannon aim must retain a finite, aligned camera basis."
				)
				if not previous_up.is_zero_approx():
					_assert_true(
						rad_to_deg(previous_up.angle_to(camera_up)) < 2.0,
						"Near-vertical cannon aim must not introduce a camera-roll jump."
					)
				previous_up = camera_up
		builder.launcher.set_setup(50.0, 90.0, 50.0)
		rig.set_cannon_pose(
			builder.launcher.first_person_eye_position(),
			builder.launcher.launch_direction(),
			builder.launcher.yaw_degrees
		)
		rig.snap_to_planning()
		builder.launcher.set_setup(162.0, 90.0, 50.0)
		rig.set_cannon_pose(
			builder.launcher.first_person_eye_position(),
			builder.launcher.launch_direction(),
			builder.launcher.yaw_degrees
		)
		rig.snap_to_planning()
		var vertical_reaim_up := camera.global_transform.basis.y
		builder.launcher.set_setup(162.0, 89.0, 50.0)
		rig.set_cannon_pose(
			builder.launcher.first_person_eye_position(),
			builder.launcher.launch_direction(),
			builder.launcher.yaw_degrees
		)
		rig.snap_to_planning()
		_assert_true(
			rad_to_deg(vertical_reaim_up.angle_to(camera.global_transform.basis.y)) < 2.0,
			"Yaw changes at exact vertical aim must remain continuous when pitch resumes."
		)
		builder.launcher.set_setup(50.0, 50.0, 50.0)
		rig.set_cannon_pose(
			builder.launcher.first_person_eye_position(), builder.launcher.launch_direction(),
			builder.launcher.yaw_degrees
		)
		rig.snap_to_planning()
		var stored_view := rig.view_mode
		var stored_transform := camera.global_transform
		var target := RigidBody3D.new()
		target.position = builder.launcher.position + Vector3(0.0, 12.0, -20.0)
		target.linear_velocity = builder.launcher.launch_direction() * 20.0
		root.add_child(target)
		_assert_true(rig.follow(target), "Fire target must enter follow.")
		for _follow_step in range(90):
			rig.update(1.0 / 60.0)
		var follow_distance := camera.global_position.distance_to(target.global_position)
		_assert_true(
			follow_distance >= 17.0 and follow_distance <= 23.0,
			"Shot follow must retain normal ball and terrain context."
		)
		_assert_camera_boom_clear(rig, camera, builder, "Shot follow")
		rig.return_to_planning(true)
		_assert_true(rig.view_mode == stored_view, "Tab return must restore the prior view.")
		_assert_true(
			camera.global_transform.is_equal_approx(stored_transform),
			"Tab return must restore the exact stored planning pose."
		)
		target.queue_free()
		builder.queue_free()
		camera.queue_free()
		rig.queue_free()
		await process_frame
	if not _failed:
		print("Cannon Golf overview, first-person, and follow camera contract passed.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _assert_camera_boom_clear(
		rig: CannonGolfCourseCameraRig,
		camera: Camera3D,
		builder: CannonGolfCourseBuilder,
		label: String
) -> void:
	var follow_target := rig.follow_target()
	var focus := rig.planning_focus() if follow_target == null \
			else follow_target.global_position + Vector3.UP * 2.0
	for step in range(25):
		var point := focus.lerp(camera.global_position, float(step) / 24.0)
		for offset in rig.terrain_footprint_offsets():
			var sample := point + Vector3(offset.x, 0.0, offset.y)
			if not builder.prepared_course.local_bounds.has_point(Vector2(sample.x, sample.z)):
				continue
			_assert_true(
				point.y + 0.05 >= builder.height_at_local(sample.x, sample.z) \
						+ CannonGolfOverviewCameraSolver.BOOM_RADIUS,
				"%s boom footprint must remain outside terrain." % label
			)
