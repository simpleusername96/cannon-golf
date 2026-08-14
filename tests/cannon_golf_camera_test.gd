extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.far = 520.0
	root.add_child(camera)
	var rig := CannonGolfCourseCameraRig.new()
	root.add_child(rig)
	for source_course in CannonGolfCourseCatalog.all_courses():
		builder.build(source_course)
		rig.configure(camera, builder.course)
		for view in [&"oblique", &"side"]:
			rig.reset_planning_view()
			_assert_true(rig.set_view(view), "Planning view must be supported.")
			rig.snap_to_planning()
			_assert_fits(camera, builder.course, rig, "%s %s default" % [source_course.course_id, view])
			var orbit_focus := rig.planning_focus()
			var position_before_orbit := camera.global_position
			_assert_true(rig.orbit(Vector2(72.0, -28.0)), "Planning orbit must accept a real drag delta.")
			rig.snap_to_planning()
			_assert_true(
				camera.global_position.distance_to(position_before_orbit) > 0.1,
				"Planning orbit must change camera position."
			)
			_assert_true(
				rig.planning_focus().is_equal_approx(orbit_focus),
				"Planning orbit must retain its fixed course focus."
			)
			_assert_fits(camera, builder.course, rig, "%s %s orbited" % [source_course.course_id, view])
			for _step in range(20):
				rig.pan(Vector2(1.0, 1.0))
			rig.snap_to_planning()
			_assert_true(
				rig.planning_focus().distance_to(orbit_focus) > 1.0,
				"Planning pan must move the camera focus across the course."
			)
			_assert_bounds_fit(
				camera,
				AABB(
					builder.course.content_bounds.position + rig.pan_offset,
					builder.course.content_bounds.size
				),
				rig.planning_focus(),
				"%s %s translated pan window" % [source_course.course_id, view]
			)
			var default_distance := camera.global_position.distance_to(rig.planning_focus())
			_assert_true(rig.zoom_by_steps(1.0), "One planning zoom step must move toward the course.")
			rig.snap_to_planning()
			var one_step_distance := camera.global_position.distance_to(rig.planning_focus())
			_assert_true(
				one_step_distance <= default_distance * 0.80,
				"One zoom-in step must reduce planning distance by at least 20 percent."
			)
			_assert_true(rig.zoom_by_steps(-1.0), "The inverse step must restore planning distance.")
			rig.snap_to_planning()
			_assert_true(
				is_equal_approx(
					camera.global_position.distance_to(rig.planning_focus()),
					default_distance
				),
				"One zoom-out step must reverse one zoom-in step."
			)
			_assert_true(rig.zoom_by_steps(100.0), "Planning zoom must move toward the course.")
			rig.snap_to_planning()
			var close_distance := camera.global_position.distance_to(rig.planning_focus())
			_assert_true(
				is_equal_approx(rig.zoom, CannonGolfCourseCameraRig.MINIMUM_ZOOM) \
						and close_distance < default_distance * 0.7 \
						and camera.global_position.is_finite(),
				"Planning zoom-in must be meaningful, bounded, and produce a valid pose."
			)
			_assert_true(rig.zoom_by_steps(-100.0), "Planning zoom must move away from the course.")
			rig.snap_to_planning()
			_assert_true(
				is_equal_approx(rig.zoom, CannonGolfCourseCameraRig.MAXIMUM_ZOOM) \
						and camera.global_position.distance_to(rig.planning_focus()) > default_distance,
				"Planning zoom-out must be bounded and visibly increase distance."
			)
			_assert_fits(camera, builder.course, rig, "%s %s zoomed" % [source_course.course_id, view])
		var stored_view := rig.view_mode
		var stored_pan := rig.pan_offset
		var stored_zoom := rig.zoom
		var stored_orbit := rig.orbit_degrees
		rig.snap_to_planning()
		var stored_position := camera.global_position
		var pose_builds := rig.planning_pose_build_count()
		for _frame in range(30):
			rig.update(1.0 / 60.0)
		_assert_true(
			rig.planning_pose_build_count() == pose_builds,
			"Unchanged planning frames must reuse the resolved pose."
		)

		var target := Node3D.new()
		target.position = builder.course.cannon_position + Vector3(0.0, 18.0, -35.0)
		root.add_child(target)
		_assert_true(rig.follow(target), "A valid live ball must enter Shot Follow.")
		rig.update(1.0 / 60.0)
		_assert_true(rig.is_following(target), "Shot Follow must retain its explicit target.")
		rig.return_to_planning(true)
		_assert_true(rig.camera_mode == &"planning", "Camera return must restore planning mode.")
		_assert_true(rig.view_mode == stored_view, "Camera return must retain overview/side choice.")
		_assert_true(rig.pan_offset.is_equal_approx(stored_pan), "Camera return must retain planning pan.")
		_assert_true(is_equal_approx(rig.zoom, stored_zoom), "Camera return must retain planning zoom.")
		_assert_true(rig.orbit_degrees.is_equal_approx(stored_orbit), "Camera return must retain planning orbit.")
		_assert_true(camera.global_position.is_equal_approx(stored_position), "Immediate camera return must restore the stored pose.")
		_assert_true(rig.follow(target), "The same live target may be followed again.")
		target.queue_free()
		await process_frame
		rig.update(1.0 / 60.0)
		_assert_true(rig.camera_mode == &"planning", "An ended follow target must fall back to planning.")
		rig.reset_planning_view()
		rig.snap_to_planning()
		_assert_true(
			rig.view_mode == &"oblique" and rig.pan_offset.is_zero_approx() \
					and is_equal_approx(rig.zoom, CannonGolfCourseCameraRig.DEFAULT_ZOOM) \
					and rig.orbit_degrees.is_zero_approx(),
			"Camera reset must restore the authored high-oblique planning view."
		)
		_assert_fits(camera, builder.course, rig, "%s reset" % source_course.course_id)
		if builder.prepared_course != null:
			_assert_true(
				rig.set_planning_context(builder.frame_bounds_for_leg(0), builder.course.planning_focus),
				"Relay planning must accept its active-leg frame."
			)
			_assert_bounds_fit(
				camera, builder.frame_bounds_for_leg(0), rig.planning_focus(),
				"%s active leg" % source_course.course_id
			)
			_assert_true(rig.zoom_by_steps(-100.0), "Relay overview must zoom to the course limit.")
			rig.snap_to_planning()
			_assert_bounds_fit(
				camera, builder.course.content_bounds, rig.planning_focus(),
				"%s full-course overview" % source_course.course_id
			)
	if not _failed:
		print("Cannon Golf generated-content planning and Shot Follow camera contract passed.")
	quit(1 if _failed else 0)


func _assert_fits(
		camera: Camera3D,
		course: CannonGolfCourseData,
		rig: CannonGolfCourseCameraRig,
		label: String
) -> void:
	var focus := rig.planning_focus()
	_assert_true(
		TerrainCameraFramer.pose_fits_bounds(
			course.content_bounds,
			camera.global_position,
			focus,
			camera.fov,
			1280.0 / 720.0,
			1.0
		),
		"Camera must fit generated content: %s." % label
	)


func _assert_bounds_fit(
		camera: Camera3D,
		bounds: AABB,
		focus: Vector3,
		label: String
) -> void:
	_assert_true(
		TerrainCameraFramer.pose_fits_bounds(
			bounds,
			camera.global_position,
			focus,
			camera.fov,
			1280.0 / 720.0,
			1.0
		),
		"Camera must fit requested bounds: %s." % label
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
