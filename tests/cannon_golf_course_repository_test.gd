extends SceneTree

var _ready_ids: Array[StringName] = []
var _failed_ids: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repository := CannonGolfCourseArtifactRepository.new()
	repository.course_ready.connect(func(course_id: StringName, _prepared: CannonGolfPreparedCourse) -> void: _ready_ids.append(course_id))
	repository.course_failed.connect(func(course_id: StringName) -> void: _failed_ids.append(course_id))
	root.add_child(repository)
	var first := CannonGolfCourseCatalog.course_at(0)
	_assert_true(not repository.request_course(first), "A cold request must prepare asynchronously.")
	_assert_true(await _wait_ready(repository, first), "The first prepared course must load.")
	_assert_true(repository.request_course(first), "A cached prepared course must be ready immediately.")

	_ready_ids.clear()
	var obsolete := CannonGolfCourseCatalog.course_at(4)
	var latest := CannonGolfCourseCatalog.course_at(5)
	repository.request_course(obsolete)
	repository.request_course(latest)
	_assert_true(await _wait_ready(repository, latest), "The latest queued course must load.")
	_assert_true(not _ready_ids.has(obsolete.course_id), "An obsolete completion must not publish readiness.")
	_assert_true(_ready_ids.has(latest.course_id), "The latest completion must publish readiness.")

	repository.prefetch_courses(CannonGolfCourseCatalog.all_courses())
	_assert_true(await _wait_catalog_ready(repository),
			"Background prefetch must warm every bounded catalog artifact.")
	_assert_true(repository.cached_course_count() == CannonGolfCourseCatalog.level_count(),
			"The prepared cache must retain the complete fifteen-course catalog.")
	_assert_true(_failed_ids.is_empty(), "Valid catalog resources must not publish load failure.")
	print("Cannon Golf prioritized request and catalog-prefetch contract passed.")
	quit(0)


func _wait_ready(
		repository: CannonGolfCourseArtifactRepository,
		course: CannonGolfCourseData
) -> bool:
	for _frame in range(600):
		if repository.ready_course(course) != null:
			return true
		await process_frame
	return false


func _wait_catalog_ready(repository: CannonGolfCourseArtifactRepository) -> bool:
	for _frame in range(1800):
		var all_ready := true
		for course in CannonGolfCourseCatalog.all_courses():
			if repository.ready_course(course) == null:
				all_ready = false
				break
		if all_ready:
			return true
		await process_frame
	return false


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
