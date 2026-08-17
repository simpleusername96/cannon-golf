extends SceneTree

## Narrow release smoke requested by the owner: the app scene starts and every
## catalog course loads and instantiates. It does not replay or certify shots.

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene_path := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	var main_scene := load(main_scene_path) as PackedScene
	_assert_true(main_scene != null, "The configured main scene must load.")
	if main_scene != null:
		var app := main_scene.instantiate()
		root.add_child(app)
		await process_frame
		await process_frame
		_assert_true(app.is_inside_tree(), "The configured main scene must enter the tree.")
		app.queue_free()
		await process_frame
	var courses := CannonGolfCourseCatalog.all_courses()
	_assert_true(courses.size() == 15, "The runtime catalog must contain fifteen courses.")
	for course in courses:
		var prepared := ResourceLoader.load(
			CannonGolfCourseCatalog.prepared_path_for(course), "", ResourceLoader.CACHE_MODE_IGNORE
		) as CannonGolfPreparedCourse
		_assert_true(
			prepared != null and prepared.is_valid_for(course),
			"Prepared course must match: %s" % course.course_id
		)
		if prepared == null or not prepared.is_valid_for(course):
			continue
		var builder := CannonGolfCourseBuilder.new()
		root.add_child(builder)
		_assert_true(builder.build(course, prepared), "Course must instantiate: %s" % course.course_id)
		_assert_true(
			builder.leg_count() == course.leg_count(),
			"Instantiated goal count must match: %s" % course.course_id
		)
		builder.queue_free()
		await process_frame
	if _failures.is_empty():
		print("Cannon Golf startup/catalog smoke passed for 15 courses.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
