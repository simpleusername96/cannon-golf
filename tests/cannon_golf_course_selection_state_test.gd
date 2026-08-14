extends SceneTree

const COURSE_SELECT_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_course_select.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var course_select := COURSE_SELECT_SCENE.instantiate() as CannonGolfCourseSelect
	root.add_child(course_select)
	await process_frame
	var starts: Array[int] = []
	course_select.start_requested.connect(func(index: int) -> void: starts.append(index))
	var cards := course_select.course_buttons()
	_assert(cards.size() == 10, "Course selection must expose ten catalog cards.")
	_assert(course_select.select_course(1), "A non-default course must be selectable.")
	await process_frame
	_assert(_pressed_count(cards) == 1, "Exactly one course card must remain pressed.")
	_assert(cards[1].has_focus(), "The selected course card must own keyboard focus.")

	course_select.set_course_preparation_state(CannonGolfCourseSelect.CoursePreparationState.PREPARING)
	_assert((course_select.get_node("%Start") as Button).disabled, "Preparing must disable Start.")
	_assert((course_select.get_node("%Start") as Button).text.contains("준비"), "Preparing copy must be truthful.")
	(course_select.get_node("%Start") as Button).emit_signal("pressed")
	_assert(starts.is_empty(), "Preparing must not emit a start request.")

	course_select.set_course_preparation_state(CannonGolfCourseSelect.CoursePreparationState.FAILED)
	_assert((course_select.get_node("%Start") as Button).disabled, "Preparation failure must disable Start.")
	_assert((course_select.get_node("%Start") as Button).text.contains("실패"), "Failure copy must be concise and local.")
	_assert(course_select.select_course(1), "Selecting the failed card again must permit a local retry.")
	_assert(_pressed_count(cards) == 1, "Retry must retain exactly one selected card.")

	course_select.set_course_preparation_state(CannonGolfCourseSelect.CoursePreparationState.READY)
	_assert(not (course_select.get_node("%Start") as Button).disabled, "Ready must enable Start.")
	(course_select.get_node("%Start") as Button).emit_signal("pressed")
	_assert(starts == [1], "Only a ready selection may emit its start request.")
	quit(1 if _failed else 0)


func _pressed_count(cards: Array[Button]) -> int:
	var count := 0
	for card in cards:
		if card.button_pressed:
			count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
