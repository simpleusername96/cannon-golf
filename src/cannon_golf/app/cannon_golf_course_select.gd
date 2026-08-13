class_name CannonGolfCourseSelect
extends Control

signal back_requested
signal start_requested(course_index: int)
signal selection_changed(course_index: int)

@onready var _course_one: Button = %CourseOne
@onready var _course_two: Button = %CourseTwo
@onready var _back: Button = %Back
@onready var _start: Button = %Start

var _selected_course_index := 0
var _courses: Array[CannonGolfCourseData] = []


func _ready() -> void:
	_courses = CannonGolfCourseCatalog.all_courses()
	_course_one.pressed.connect(func() -> void: select_course(0))
	_course_two.pressed.connect(func() -> void: select_course(1))
	_back.pressed.connect(func() -> void: back_requested.emit())
	_start.pressed.connect(func() -> void: start_requested.emit(_selected_course_index))
	_refresh_course_copy()


func open() -> void:
	visible = true
	focus_primary()


func focus_primary() -> void:
	var button := _course_one if _selected_course_index == 0 else _course_two
	button.grab_focus.call_deferred()


func selected_course_index() -> int:
	return _selected_course_index


func select_course(index: int, emit_signal: bool = true) -> bool:
	if index < 0 or index >= _courses.size():
		return false
	_selected_course_index = index
	_refresh_course_copy()
	if emit_signal:
		selection_changed.emit(_selected_course_index)
	return true


func set_selected_course_index(index: int) -> bool:
	return select_course(index, false)


func apply_language(language: String) -> void:
	var english := language == "en"
	$Heading.text = "COURSE SELECT" if english else "코스 선택"
	_back.text = "BACK" if english else "뒤로"
	_course_one.text = "FIRST RIDGE" if english else "첫 능선"
	_course_two.text = "RISING BEND" if english else "오르는 굽이"
	_start.text = "START COURSE" if english else "코스 시작"
	_refresh_course_copy()


func _refresh_course_copy() -> void:
	if _courses.is_empty():
		_start.disabled = true
		return
	_start.disabled = false
	_course_one.button_pressed = _selected_course_index == 0
	_course_two.button_pressed = _selected_course_index == 1
