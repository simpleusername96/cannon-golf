class_name CannonGolfCourseSelect
extends Control

signal back_requested
signal start_requested(course_index: int)
signal selection_changed(course_index: int)

enum CoursePreparationState {
	PREPARING,
	READY,
	FAILED,
}

@onready var _course_list: VBoxContainer = $Scroll/CourseList
@onready var _scroll: ScrollContainer = $Scroll
@onready var _back: Button = %Back
@onready var _start: Button = %Start

var _selected_course_index := 0
var _courses: Array[CannonGolfCourseData] = []
var _course_buttons: Array[Button] = []
var _course_button_group := ButtonGroup.new()
var _language := "ko"
var _preparation_state := CoursePreparationState.PREPARING


func _ready() -> void:
	_courses = CannonGolfCourseCatalog.all_courses()
	_configure_thin_scrollbar()
	_build_course_buttons()
	_back.pressed.connect(func() -> void: back_requested.emit())
	_start.pressed.connect(_on_start_pressed)
	_refresh_all_copy()


func open() -> void:
	visible = true
	focus_primary()
	_ensure_selected_visible.call_deferred()


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
	var previous_index := _selected_course_index
	_selected_course_index = index
	_refresh_start_copy()
	if previous_index != index:
		_refresh_course_row(previous_index)
	_refresh_course_row(index)
	_course_buttons[index].grab_focus.call_deferred()
	_ensure_selected_visible.call_deferred()
	if emit_signal:
		selection_changed.emit(_selected_course_index)
	return true


func set_selected_course_index(index: int) -> bool:
	return select_course(index, false)


func apply_language(language: String) -> void:
	_language = language
	var english := language == "en"
	$Heading.text = "LEVEL SELECT" if english else "레벨 선택"
	_back.text = "←  BACK" if english else "←  뒤로"
	_refresh_all_copy()


func set_course_preparation_state(state: int) -> void:
	_preparation_state = state
	_refresh_start_copy()


func course_preparation_state() -> int:
	return _preparation_state


func _refresh_all_copy() -> void:
	_refresh_start_copy()
	for index in range(_course_buttons.size()):
		_refresh_course_row(index)


func _refresh_start_copy() -> void:
	if _courses.is_empty():
		_start.disabled = true
		return
	_start.disabled = _preparation_state != CoursePreparationState.READY
	if _preparation_state == CoursePreparationState.PREPARING:
		_start.text = "PREPARING…" if _language == "en" else "준비 중…"
	elif _preparation_state == CoursePreparationState.FAILED:
		_start.text = "PREPARATION FAILED" if _language == "en" else "준비 실패"
	else:
		_start.text = "START" if _language == "en" else "시작"
	_start.set("accessibility_name", _start.text)


func _refresh_course_row(index: int) -> void:
	if index < 0 or index >= _course_buttons.size():
		return
	var button := _course_buttons[index]
	var selected := _selected_course_index == index
	button.text = _course_label(index, selected)
	button.add_theme_font_size_override(&"font_size", 20 if selected else 18)
	button.set("accessibility_name", button.text)
	button.set_pressed_no_signal(selected)


func course_buttons() -> Array[Button]:
	return _course_buttons.duplicate()


func _build_course_buttons() -> void:
	for child in _course_list.get_children():
		child.queue_free()
	_course_buttons.clear()
	for index in range(_courses.size()):
		var button := Button.new()
		button.name = "Level%02d" % (index + 1)
		button.custom_minimum_size = Vector2(0.0, 62.0)
		button.theme_type_variation = &"CourseRowButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.toggle_mode = true
		button.button_group = _course_button_group
		button.pressed.connect(select_course.bind(index))
		_course_list.add_child(button)
		_course_buttons.append(button)
	_install_course_focus_order()


func _configure_thin_scrollbar() -> void:
	var bar := _scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 4.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.09, 0.145, 0.22, 0.08)
	track.content_margin_left = 1.0
	track.content_margin_right = 1.0
	track.corner_radius_top_left = 2
	track.corner_radius_top_right = 2
	track.corner_radius_bottom_right = 2
	track.corner_radius_bottom_left = 2
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.18, 0.24, 0.33, 0.42)
	grabber.content_margin_left = 1.0
	grabber.content_margin_right = 1.0
	grabber.corner_radius_top_left = 2
	grabber.corner_radius_top_right = 2
	grabber.corner_radius_bottom_right = 2
	grabber.corner_radius_bottom_left = 2
	var grabber_hover := grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(0.145, 0.518, 1.0, 0.72)
	bar.add_theme_stylebox_override(&"scroll", track)
	bar.add_theme_stylebox_override(&"grabber", grabber)
	bar.add_theme_stylebox_override(&"grabber_highlight", grabber_hover)
	bar.add_theme_stylebox_override(&"grabber_pressed", grabber_hover)


func _on_start_pressed() -> void:
	if _preparation_state == CoursePreparationState.READY:
		start_requested.emit(_selected_course_index)


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


func _course_label(index: int, selected: bool = false) -> String:
	var level := CannonGolfCourseCatalog.level_label(index)
	if not selected:
		return level
	var goals := _courses[index].leg_count()
	return "%s    %d GOALS" % [level, goals] if _language == "en" \
			else "%s    목표 %d개" % [level, goals]


func _ensure_selected_visible() -> void:
	if not is_inside_tree() or _selected_course_index < 0 \
			or _selected_course_index >= _course_buttons.size():
		return
	var selected := _course_buttons[_selected_course_index]
	var bar := _scroll.get_v_scroll_bar()
	var centered := selected.position.y + selected.size.y * 0.5 - _scroll.size.y * 0.5
	var maximum := maxf(bar.max_value - bar.page, 0.0)
	_scroll.scroll_vertical = roundi(clampf(centered, 0.0, maximum))
