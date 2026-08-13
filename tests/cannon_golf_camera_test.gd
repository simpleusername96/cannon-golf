extends SceneTree


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
			_assert_true(rig.set_view(view), "Planning view must be supported.")
			rig.adjust_zoom(-999.0)
			rig.snap_to_planning()
			_assert_fits(camera, builder.course, rig, "%s %s default" % [source_course.course_id, view])
			for _step in range(20):
				rig.pan(Vector2(1.0, 1.0))
			rig.snap_to_planning()
			_assert_fits(camera, builder.course, rig, "%s %s panned" % [source_course.course_id, view])
			rig.adjust_zoom(999.0)
			rig.snap_to_planning()
			_assert_fits(camera, builder.course, rig, "%s %s zoomed" % [source_course.course_id, view])
	print("Cannon Golf generated-content camera framing passed for both courses and planning views.")
	quit(0)


func _assert_fits(
		camera: Camera3D,
		course: CannonGolfCourseData,
		rig: CannonGolfCourseCameraRig,
		label: String
) -> void:
	var focus := course.planning_focus + rig.pan_offset
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


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
