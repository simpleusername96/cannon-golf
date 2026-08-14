extends SceneTree

const APP_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_app.tscn")
const COURSE_SELECT_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_course_select.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var course_select := COURSE_SELECT_SCENE.instantiate() as CannonGolfCourseSelect
	root.add_child(course_select)
	await process_frame
	var generation_count := CannonGolfCourseTerrainFactory.generation_build_count()
	var selection_started := Time.get_ticks_usec()
	_assert(course_select.select_course(9), "The tenth course must be immediately selectable.")
	var selection_usec := Time.get_ticks_usec() - selection_started
	_assert(
		selection_usec < 16667,
		"A selection callback must return within one 60 Hz frame: %dus." % selection_usec
	)
	_assert(
		CannonGolfCourseTerrainFactory.generation_build_count() == generation_count,
		"A selection callback must not invoke terrain generation."
	)

	var app := APP_SCENE.instantiate() as CannonGolfApp
	root.add_child(app)
	await process_frame
	app.show_course_select(false)
	var app_selection_started := Time.get_ticks_usec()
	_assert(
		(app.get_node("ScreenLayer/CourseSelect") as CannonGolfCourseSelect).select_course(9),
		"The app must accept the latest selected course."
	)
	var app_selection_usec := Time.get_ticks_usec() - app_selection_started
	_assert(
		app_selection_usec < 16667,
		"The app selection request must return within one 60 Hz frame: %dus." % app_selection_usec
	)
	_assert(
		CannonGolfCourseTerrainFactory.generation_build_count() == generation_count,
		"The app selection request must never synchronously generate terrain."
	)
	_assert(
		(app.get_node("ScreenLayer/CourseSelect/Start") as Button).disabled,
		"Start must remain disabled until the latest artifact becomes ready."
	)
	while app.course_artifact_repository.active_request_count() > 0:
		await process_frame
	app.queue_free()
	course_select.queue_free()
	for _frame in range(3):
		await process_frame
	if not _failed:
		print("Cannon Golf prepared selection performance contract passed.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
