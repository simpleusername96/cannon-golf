class_name CannonGolfCourseSelect
extends Control

signal back_requested
signal start_requested(course_index: int)
signal selection_changed(course_index: int)

@onready var _course_one: Button = %CourseOne
@onready var _course_two: Button = %CourseTwo
@onready var _back: Button = %Back
@onready var _start: Button = %Start
@onready var _preview_title: Label = %PreviewTitle
@onready var _preview_brief: Label = %PreviewBrief
@onready var _preview_facts: Label = %PreviewFacts
@onready var _selection_hint: Label = %SelectionHint

var _selected_course_index := 0
var _courses: Array[CannonGolfCourseData] = []
var _language := "ko"


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
	_language = language
	var english := language == "en"
	$Heading.text = "COURSE SELECT" if english else "코스 선택"
	_back.text = "BACK" if english else "뒤로"
	_course_one.text = "QUIET SHELF" if english else "고요한 선반"
	_course_two.text = "RISING BEND" if english else "오르는 굽이"
	$CardsPanel/Margin/Cards/CourseOneHint.text = "01  ·  DIRECT SHOT" if english else "01  ·  직접 조준"
	$CardsPanel/Margin/Cards/CourseTwoHint.text = "02  ·  READ THE HEIGHT" if english else "02  ·  높이 차 읽기"
	$PreviewPanel/Margin/Content/PreviewCaption.text = "LIVE COURSE PREVIEW" if english else "실제 코스 미리 보기"
	_start.text = "START COURSE" if english else "코스 시작"
	_refresh_course_copy()


func _refresh_course_copy() -> void:
	if _courses.is_empty():
		_start.disabled = true
		return
	_start.disabled = false
	_course_one.button_pressed = _selected_course_index == 0
	_course_two.button_pressed = _selected_course_index == 1
	var course := _courses[_selected_course_index]
	var english := _language == "en"
	_preview_title.text = _english_course_name(course.course_id) if english else course.display_name
	_preview_brief.text = _english_course_brief(course.course_id) if english else course.short_brief
	_preview_facts.text = "ONE GOAL  ·  DIRECT AIM\nUNLIMITED RETRIES  ·  ANGLE & POWER" if english else "골 1개  ·  직접 조준\n고요한 재시도  ·  각도와 파워"
	_selection_hint.text = "Inspect the selected course, then start." if english else "선택한 코스를 살펴본 뒤 시작하세요."


func _english_course_name(course_id: StringName) -> String:
	return "RISING BEND" if course_id == &"rising_bend" else "QUIET SHELF"


func _english_course_brief(course_id: StringName) -> String:
	if course_id == &"rising_bend":
		return "A farther, higher goal. Use the side view to read the elevation."
	return "A wide first goal. Set angle and power for a safe landing."
