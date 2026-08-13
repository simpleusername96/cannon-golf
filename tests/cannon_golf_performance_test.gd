extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_preview_world.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var preview := PREVIEW_SCENE.instantiate() as CannonGolfPreviewWorld
	root.add_child(preview)
	await process_frame
	_assert_true(preview._builder.course == null, "Preview readiness must not build a hidden duplicate course.")
	_assert_true(preview.show_course(0), "Preview must build the selected course on demand.")
	var first_body := preview._builder.terrain_body
	var first_geometry := preview._builder.terrain_geometry
	var generated_after_first := CannonGolfCourseTerrainFactory.generation_build_count()
	_assert_true(preview.show_course(0), "The current preview course must remain selectable.")
	_assert_true(preview._builder.terrain_body == first_body, "Selecting the visible preview again must keep its scene nodes.")
	_assert_true(
		CannonGolfCourseTerrainFactory.generation_build_count() == generated_after_first,
		"Selecting the visible preview again must not regenerate terrain."
	)

	var second_builder := CannonGolfCourseBuilder.new()
	root.add_child(second_builder)
	second_builder.build(CannonGolfCourseCatalog.course_at(0))
	_assert_true(
		second_builder.terrain_geometry == first_geometry,
		"A gameplay builder must reuse the immutable deterministic terrain product."
	)
	_assert_true(second_builder.terrain_body != first_body, "Cached terrain must not share mutable scene nodes.")
	_assert_true(second_builder.course != preview._builder.course, "Cached terrain must not share mutable course resources.")
	_assert_true(
		CannonGolfCourseTerrainFactory.generation_build_count() == generated_after_first,
		"A second builder must consume the terrain cache without generation work."
	)
	var relay_builder := CannonGolfCourseBuilder.new()
	root.add_child(relay_builder)
	relay_builder.build(CannonGolfCourseCatalog.course_at(2))
	# Warm both owners, then compare medians so asset import, first-use shader
	# setup, and scheduler jitter do not decide the performance contract.
	CannonGolfCourseTerrainFactory._build_uncached(CannonGolfCourseCatalog.course_at(0))
	CannonGolfCourseTerrainFactory._build_explicit_uncached(CannonGolfCourseCatalog.course_at(2))
	var legacy_uncached_usec := _median_usec(_measure_uncached(false, 3))
	var relay_uncached_usec := _median_usec(_measure_uncached(true, 3))
	_assert_true(
		float(relay_uncached_usec) <= float(legacy_uncached_usec) * 3.0,
		"Longitudinal uncached build must remain within 3x legacy cost: %dus vs %dus." % [
			relay_uncached_usec, legacy_uncached_usec,
		]
	)
	var legacy_cached_usec := _median_usec(
		_measure_cached_factory(CannonGolfCourseCatalog.course_at(0), 300, 5)
	)
	var relay_cached_usec := _median_usec(
		_measure_cached_factory(CannonGolfCourseCatalog.course_at(2), 300, 5)
	)
	_assert_true(
		float(relay_cached_usec) <= float(legacy_cached_usec) * 1.25,
		"Longitudinal cached lookup must remain within 25%% of legacy: %dus vs %dus." % [
			relay_cached_usec, legacy_cached_usec,
		]
	)

	var camera := Camera3D.new()
	camera.fov = 48.0
	root.add_child(camera)
	var rig := CannonGolfCourseCameraRig.new()
	root.add_child(rig)
	rig.configure(camera, second_builder.course)
	var planning_builds := rig.planning_pose_build_count()
	for _frame in range(120):
		rig.update(1.0 / 60.0)
	_assert_true(
		rig.planning_pose_build_count() == planning_builds,
		"Unchanged render frames must not repeat planning-camera framing."
	)
	rig.zoom_by_steps(-1.0)
	rig.update(1.0 / 60.0)
	_assert_true(
		rig.planning_pose_build_count() == planning_builds + 1,
		"A changed planning input must invalidate framing exactly once."
	)
	rig.orbit(Vector2(12.0, -6.0))
	rig.update(1.0 / 60.0)
	_assert_true(
		rig.planning_pose_build_count() == planning_builds + 2,
		"One drag sample must invalidate planning framing exactly once."
	)
	for _frame in range(120):
		rig.update(1.0 / 60.0)
	_assert_true(
		rig.planning_pose_build_count() == planning_builds + 2,
		"A completed drag must not add unchanged-frame camera work."
	)
	if not _failed:
		print("Cannon Golf terrain and planning-camera performance contract passed.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _measure_uncached(explicit: bool, repetitions: int) -> Array[int]:
	var samples: Array[int] = []
	var course := CannonGolfCourseCatalog.course_at(2 if explicit else 0)
	for _repetition in range(repetitions):
		var started := Time.get_ticks_usec()
		if explicit:
			CannonGolfCourseTerrainFactory._build_explicit_uncached(course)
		else:
			CannonGolfCourseTerrainFactory._build_uncached(course)
		samples.append(Time.get_ticks_usec() - started)
	return samples


func _measure_cached_factory(
		course: CannonGolfCourseData, iterations: int, repetitions: int
) -> Array[int]:
	var samples: Array[int] = []
	CannonGolfCourseTerrainFactory.build(course)
	for _repetition in range(repetitions):
		var started := Time.get_ticks_usec()
		for _index in range(iterations):
			CannonGolfCourseTerrainFactory.build(course)
		samples.append(Time.get_ticks_usec() - started)
	return samples


func _median_usec(samples: Array[int]) -> int:
	samples.sort()
	return samples[samples.size() / 2]
