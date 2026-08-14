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
			builder.launcher.first_person_eye_position(), builder.launcher.launch_direction()
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
		var old_focus := rig.planning_focus()
		_assert_true(rig.pan_drag(Vector2.ZERO, Vector2(80.0, -30.0)), "Left drag must pan.")
		_assert_true(rig.orbit(Vector2(80.0, -30.0)), "Right drag must orbit.")
		rig.snap_to_planning()
		_assert_true(not rig.planning_focus().is_equal_approx(old_focus), "Pan must move the overview pivot.")

		_assert_true(rig.set_view(&"cannon"), "Cannon first-person must be available.")
		rig.snap_to_planning()
		var camera_forward := -camera.global_transform.basis.z
		_assert_true(
			camera.global_position.distance_to(builder.launcher.first_person_eye_position()) < 0.01
					and rad_to_deg(camera_forward.angle_to(builder.launcher.launch_direction())) < 0.1,
			"Cannon view must use the exact launcher eye and launch direction."
		)
		var stored_view := rig.view_mode
		var target := RigidBody3D.new()
		target.position = builder.launcher.position + Vector3(0.0, 12.0, -20.0)
		target.linear_velocity = builder.launcher.launch_direction() * 20.0
		root.add_child(target)
		_assert_true(rig.follow(target), "Fire target must enter follow.")
		rig.update(1.0 / 60.0)
		rig.return_to_planning(true)
		_assert_true(rig.view_mode == stored_view, "Tab return must restore the prior view.")
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
