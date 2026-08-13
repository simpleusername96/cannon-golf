class_name CannonGolfCourseSelect
extends Control

signal back_requested
signal start_requested(course_index: int)
signal selection_changed(course_index: int)

@onready var _cards: VBoxContainer = $CardsPanel/Margin/Cards
@onready var _back: Button = %Back
@onready var _start: Button = %Start

var _selected_course_index := 0
var _courses: Array[CannonGolfCourseData] = []
var _course_buttons: Array[Button] = []
var _course_button_group := ButtonGroup.new()
var _language := "ko"


func _ready() -> void:
	_courses = CannonGolfCourseCatalog.all_courses()
	_build_course_buttons()
	_back.pressed.connect(func() -> void: back_requested.emit())
	_start.pressed.connect(func() -> void: start_requested.emit(_selected_course_index))
	_refresh_course_copy()


func open() -> void:
	visible = true
	focus_primary()


func focus_primary() -> void:
	if _selected_course_index >= 0 and _selected_course_index < _course_buttons.size():
		_course_buttons[_selected_course_index].grab_focus.call_deferred()
	else:
		_start.grab_focus.call_deferred()


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
	_start.text = "START COURSE" if english else "코스 시작"
	_refresh_course_copy()


func _refresh_course_copy() -> void:
	if _courses.is_empty():
		_start.disabled = true
		return
	_start.disabled = false
	for index in range(_course_buttons.size()):
		var button := _course_buttons[index]
		button.text = _course_label(_courses[index])
		button.set("accessibility_name", button.text)
		button.button_pressed = _selected_course_index == index


func course_buttons() -> Array[Button]:
	return _course_buttons.duplicate()


func _build_course_buttons() -> void:
	for child in _cards.get_children():
		child.queue_free()
	_course_buttons.clear()
	for index in range(_courses.size()):
		var button := Button.new()
		button.name = "Course%02d" % (index + 1)
		button.custom_minimum_size = Vector2(0.0, 68.0)
		button.theme_type_variation = &"QuietButton"
		button.toggle_mode = true
		button.button_group = _course_button_group
		button.pressed.connect(select_course.bind(index))
		_cards.add_child(button)
		_course_buttons.append(button)
	_install_course_focus_order()


func _install_course_focus_order() -> void:
	if _course_buttons.is_empty():
		return
	for index in range(_course_buttons.size()):
		var button := _course_buttons[index]
		var previous: Control = _back if index == 0 else _course_buttons[index - 1]
		var next: Control = _start if index == _course_buttons.size() - 1 \
				else _course_buttons[index + 1]
		button.focus_neighbor_top = previous.get_path()
		button.focus_previous = previous.get_path()
		button.focus_neighbor_bottom = next.get_path()
		button.focus_next = next.get_path()
	_back.focus_neighbor_bottom = _course_buttons[0].get_path()
	_back.focus_next = _course_buttons[0].get_path()
	_start.focus_neighbor_top = _course_buttons[-1].get_path()
	_start.focus_previous = _course_buttons[-1].get_path()


func _course_label(course: CannonGolfCourseData) -> String:
	if _language != "en":
		return course.display_name
	return String(course.course_id).replace("_", " ").to_upper()
