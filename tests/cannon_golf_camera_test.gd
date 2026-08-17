extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var catalog := CannonGolfCourseCatalog.all_courses()
	for index in [0, 3, 4, 9]:
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
			builder.launcher.cannon_perspective_anchor(), builder.launcher.launch_direction(),
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
		_assert_true(rig.pan_drag(Vector2.ZERO, Vector2(80.0, -30.0)), "Pan must move the view.")
		rig.snap_to_planning()
		_assert_true(not rig.planning_focus().is_equal_approx(old_focus), "Pan must move the overview pivot.")
		_assert_true(
			absf(rig.resolved_planning_distance() - pre_pan_distance) <= 0.05,
			"Pan must translate the overview without changing its framing distance."
		)
		_assert_camera_boom_clear(rig, camera, builder, "Panned overview")
		_assert_true(rig.orbit(Vector2(80.0, -30.0)), "Orbit must rotate the view.")
		rig.snap_to_planning()
		_assert_camera_boom_clear(rig, camera, builder, "Orbited overview")

		_assert_true(rig.set_view(&"cannon"), "Cannon perspective must be available.")
		rig.snap_to_planning()
		var camera_forward := -camera.global_transform.basis.z
		var expected_cannon_focus := rig.planning_focus()
		var cannon_screen_position := camera.unproject_position(expected_cannon_focus)
		var cannon_screen_ratio := cannon_screen_position \
				/ camera.get_viewport().get_visible_rect().size
		_assert_true(
			rig.resolved_planning_distance() >= 80.0 \
					and rig.resolved_planning_distance() <= 110.0 \
					and camera.global_position.y > builder.launcher.global_position.y \
					and cannon_screen_ratio.x >= 0.38 and cannon_screen_ratio.x <= 0.62 \
					and cannon_screen_ratio.y >= 0.38 and cannon_screen_ratio.y <= 0.62 \
					and rad_to_deg(camera_forward.angle_to(Vector3.DOWN)) >= 45.0 \
					and rad_to_deg(camera_forward.angle_to(
						(expected_cannon_focus - camera.global_position).normalized()
					)) < 0.1,
			"Cannon preset must be a centered medium-distance rear-upper terrain view: course=%d distance=%.2f screen=%s down=%.2f" % [
				index,
				rig.resolved_planning_distance(),
				cannon_screen_ratio,
				rad_to_deg(camera_forward.angle_to(Vector3.DOWN)),
			]
		)
		for vertical_sign in [-1.0, 1.0]:
			var previous_up := Vector3.ZERO
			for absolute_angle in [87.0, 88.0, 89.0, 90.0]:
				builder.launcher.set_setup(162.0, vertical_sign * absolute_angle, 50.0)
				_assert_true(
					rig.set_cannon_pose(
						builder.launcher.cannon_perspective_anchor(),
						builder.launcher.launch_direction(),
						builder.launcher.yaw_degrees
					),
					"Near-vertical cannon aim must provide a valid camera pose."
				)
				rig.snap_to_planning()
				camera_forward = -camera.global_transform.basis.z
				var camera_up := camera.global_transform.basis.y
				expected_cannon_focus = rig.planning_focus()
				_assert_true(
					camera.global_transform.basis.is_finite() \
							and rad_to_deg(
								camera_forward.angle_to(
									(expected_cannon_focus - camera.global_position).normalized()
								)
							) < 0.1,
					"Exact vertical cannon aim must retain a finite perspective basis."
				)
				if not previous_up.is_zero_approx():
					_assert_true(
						rad_to_deg(previous_up.angle_to(camera_up)) < 2.0,
						"Near-vertical cannon aim must not introduce a camera-roll jump."
					)
				previous_up = camera_up
		builder.launcher.set_setup(50.0, 90.0, 50.0)
		rig.set_cannon_pose(
			builder.launcher.cannon_perspective_anchor(),
			builder.launcher.launch_direction(),
			builder.launcher.yaw_degrees
		)
		rig.snap_to_planning()
		builder.launcher.set_setup(162.0, 90.0, 50.0)
		rig.set_cannon_pose(
			builder.launcher.cannon_perspective_anchor(),
			builder.launcher.launch_direction(),
			builder.launcher.yaw_degrees
		)
		rig.snap_to_planning()
		var vertical_reaim_up := camera.global_transform.basis.y
		builder.launcher.set_setup(162.0, 89.0, 50.0)
		rig.set_cannon_pose(
			builder.launcher.cannon_perspective_anchor(),
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
			builder.launcher.cannon_perspective_anchor(), builder.launcher.launch_direction(),
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
	await _assert_all_preview_courses_fit()
	await _assert_camera_preset_interaction()
	if not _failed:
		print("Cannon Golf overview, preview framing, preset interaction, and follow camera contract passed.")
	quit(1 if _failed else 0)


func _assert_all_preview_courses_fit() -> void:
	var preview := CannonGolfPreviewWorld.new()
	root.add_child(preview)
	await process_frame
	for index in range(CannonGolfCourseCatalog.level_count()):
		var course := CannonGolfCourseCatalog.course_at(index)
		var prepared := load(CannonGolfCourseCatalog.prepared_path_for(course)) \
				as CannonGolfPreparedCourse
		_assert_true(prepared != null and preview.show_course(index, prepared),
				"Every prepared course must build in the selection preview.")
		preview._camera_rig.snap_to_planning()
		_assert_true(
			TerrainCameraFramer.pose_fits_bounds(
				preview._builder.presentation_bounds(),
				preview._camera.global_position,
				preview._camera_rig.planning_focus(),
				preview._camera.fov,
				float(root.size.x) / float(root.size.y),
				1.0
			),
			"LV %d preview must retain a complete-course fit instead of collapsing close." \
					% (index + 1)
		)
	preview.queue_free()
	await process_frame


func _assert_camera_preset_interaction() -> void:
	var game := GAME_SCENE.instantiate() as CannonGolfGame
	game.initial_course_index = 0
	game.initial_prepared_course = load(
		CannonGolfCourseCatalog.prepared_path_for(CannonGolfCourseCatalog.course_at(0))
	) as CannonGolfPreparedCourse
	root.add_child(game)
	await process_frame
	var cannon_button := game._hud.get_node("%CannonButton") as Button
	var overview_button := game._hud.get_node("%ObliqueButton") as Button
	cannon_button.pressed.emit()
	_assert_true(game.planning_view == &"cannon" and cannon_button.button_pressed,
			"The Cannon button must select the Cannon preset.")
	overview_button.pressed.emit()
	_assert_true(game.planning_view == &"oblique" and overview_button.button_pressed,
			"The Overview button must leave Cannon and select Overview.")
	cannon_button.pressed.emit()
	var cannon_transform := game._camera.global_transform
	game._on_setup_changed(
		CannonGolfBallistics.MAXIMUM_HORIZONTAL_AIM,
		CannonGolfBallistics.MAXIMUM_ELEVATION_DEGREES,
		100.0
	)
	for _setup_frame in range(30):
		game._camera_rig.update(1.0 / 60.0)
	_assert_true(
		game.planning_view == &"cannon"
				and game._camera.global_transform.is_equal_approx(cannon_transform),
		"Aim, elevation, and power edits must not move the selected Cannon preset."
	)
	game._begin_planning_drag(MOUSE_BUTTON_LEFT)
	_assert_true(game.planning_view == &"cannon",
			"Pressing the world in Cannon view must not select Overview.")
	_assert_true(game._committed_planning_drag_relative(Vector2(2.0, 1.0)).is_zero_approx() \
			and game.planning_view == &"cannon",
			"Click jitter below the drag threshold must retain Cannon view.")
	game._end_planning_drag()
	var overview_pan := game.planning_pan
	var overview_zoom := game.planning_zoom
	var overview_orbit := game._camera_rig.orbit_degrees
	var authored_cannon_distance := game._camera_rig.resolved_planning_distance()
	_assert_true(game.orbit_planning(Vector2(40.0, 12.0)),
			"Left drag must orbit within Cannon exploration.")
	var immediate_orbit_transform := game._camera.global_transform
	_assert_true(
		not immediate_orbit_transform.is_equal_approx(cannon_transform),
		"Cannon orbit input must update the rendered camera in the same frame."
	)
	game.pan_planning(Vector2.RIGHT)
	_assert_true(game.pan_planning_drag(Vector2(640.0, 360.0), Vector2(-80.0, -24.0)),
			"Right drag must pan within Cannon exploration.")
	_assert_true(game.zoom_planning(1.0), "Wheel input must zoom within Cannon exploration.")
	_assert_true(
		game.planning_view == &"cannon" \
				and game._camera_rig.cannon_pan_offset.length() > 2.0 \
				and game._camera_rig.cannon_orbit_degrees.length() > 5.0 \
				and game._camera_rig.cannon_zoom > CannonGolfCourseCameraRig.DEFAULT_ZOOM \
				and game._camera_rig.resolved_planning_distance() \
						< authored_cannon_distance * 0.92 \
				and game.planning_pan.is_equal_approx(overview_pan) \
				and is_equal_approx(game.planning_zoom, overview_zoom) \
				and game._camera_rig.orbit_degrees.is_equal_approx(overview_orbit) \
				and not game._camera.global_transform.is_equal_approx(cannon_transform),
		"Cannon exploration must move locally without changing view or Overview state."
	)
	var explored_cannon_transform := game._camera.global_transform
	_assert_true(game.fire(), "Explored Cannon state must permit Fire.")
	_assert_true(game.return_to_planning_view(), "Tab return must restore explored Cannon.")
	_assert_true(
		game.planning_view == &"cannon" \
				and game._camera.global_transform.is_equal_approx(explored_cannon_transform),
		"Shot Follow return must restore the exact explored Cannon pose."
	)
	_assert_true(game.fire(), "Explored Cannon state must permit a reset from Shot Follow.")
	game.reset_planning_camera()
	_assert_true(
		game._camera_rig.camera_mode == &"planning" \
				and game.planning_view == &"cannon" \
				and game._camera_rig.cannon_pan_offset.is_zero_approx() \
				and is_equal_approx(
					game._camera_rig.cannon_zoom, CannonGolfCourseCameraRig.DEFAULT_ZOOM
				) \
				and game._camera_rig.cannon_orbit_degrees.is_zero_approx() \
				and game._camera.global_transform.is_equal_approx(cannon_transform),
		"Reset from Cannon Follow must restore its authored pose without selecting Overview."
	)
	game.orbit_planning(Vector2(-800.0, 10000.0))
	for _extreme_pan_step in range(8):
		game.pan_planning_drag(Vector2(640.0, 360.0), Vector2(-10000.0, 10000.0))
	game.zoom_planning(-100.0)
	var extreme_forward := -game._camera.global_transform.basis.z
	var extreme_focus := game._camera_rig.planning_focus()
	var course_span := maxf(
		game.active_course().content_bounds.size.x,
		game.active_course().content_bounds.size.z
	)
	_assert_true(
		game.planning_view == &"cannon" \
				and absf(game._camera_rig.cannon_orbit_degrees.x) > 160.0 \
				and game._camera_rig.cannon_orbit_degrees.x >= -180.0 \
				and game._camera_rig.cannon_orbit_degrees.x < 180.0 \
				and is_equal_approx(
					game._camera_rig.cannon_orbit_degrees.y,
					CannonGolfCourseCameraRig.CANNON_MAXIMUM_PITCH_ORBIT
				) \
				and is_equal_approx(
					game._camera_rig.cannon_zoom,
					CannonGolfCourseCameraRig.CANNON_MINIMUM_ZOOM
				) \
				and game.active_course().content_bounds.has_point(
					Vector3(extreme_focus.x, 0.0, extreme_focus.z)
				) \
				and rad_to_deg(extreme_forward.angle_to(Vector3.DOWN)) > 25.0 \
				and game._camera_rig.resolved_planning_distance() >= course_span,
		"Extreme Cannon input must wrap yaw, clamp pitch/dolly, and keep its interest in-course: orbit=%s zoom=%.2f focus=%s in_bounds=%s distance=%.2f down=%.2f" % [
			game._camera_rig.cannon_orbit_degrees,
			game._camera_rig.cannon_zoom,
			extreme_focus,
			game.active_course().content_bounds.has_point(Vector3(extreme_focus.x, 0.0, extreme_focus.z)),
			game._camera_rig.resolved_planning_distance(),
			rad_to_deg(extreme_forward.angle_to(Vector3.DOWN)),
		]
	)
	_assert_camera_boom_clear(
		game._camera_rig, game._camera, game._course_builder, "Extreme Cannon exploration"
	)
	overview_button.pressed.emit()
	_assert_true(game.planning_view == &"oblique",
			"Only an explicit Overview choice must select the overview preset.")
	game.queue_free()
	await process_frame


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
