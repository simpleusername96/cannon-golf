class_name CannonGolfHUD
extends CanvasLayer

signal fire_requested
signal retry_requested
signal setup_changed(horizontal_aim: float, elevation_degrees: float, power_percent: float)
signal view_requested(view_mode: StringName)
signal reset_requested
signal pause_requested
signal settings_requested
signal course_select_requested
signal main_menu_requested
signal result_primary_requested

@onready var _horizontal_value: Label = %HorizontalValue
@onready var _horizontal_slider: HSlider = %HorizontalSlider
@onready var _elevation_value: Label = %ElevationValue
@onready var _elevation_slider: HSlider = %ElevationSlider
@onready var _power_value: Label = %PowerValue
@onready var _power_slider: HSlider = %PowerSlider
@onready var _oblique_button: Button = %ObliqueButton
@onready var _side_button: Button = %SideButton
@onready var _retry_button: Button = %RetryButton
@onready var _fire_button: Button = %FireButton
@onready var _fire_label: Label = %FireLabel
@onready var _pause_retry: Button = %PauseRetry
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _result_overlay: Control = %ResultOverlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_primary: Button = %ResultPrimary

var _syncing := false
var _pause_suspended := false
var _busy := false
var _language := "ko"


func _ready() -> void:
	_horizontal_slider.value_changed.connect(_on_setup_control_changed)
	_elevation_slider.value_changed.connect(_on_setup_control_changed)
	_power_slider.value_changed.connect(_on_setup_control_changed)
	_oblique_button.pressed.connect(func() -> void: view_requested.emit(&"oblique"))
	_side_button.pressed.connect(func() -> void: view_requested.emit(&"side"))
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	_fire_button.pressed.connect(func() -> void: fire_requested.emit())
	%PauseButton.pressed.connect(func() -> void: pause_requested.emit())
	%Resume.pressed.connect(func() -> void: pause_requested.emit())
	_pause_retry.pressed.connect(func() -> void: retry_requested.emit())
	%PauseReset.pressed.connect(func() -> void: reset_requested.emit())
	%PauseSettings.pressed.connect(func() -> void: settings_requested.emit())
	%PauseStages.pressed.connect(func() -> void: course_select_requested.emit())
	%PauseMainMenu.pressed.connect(func() -> void: main_menu_requested.emit())
	_result_primary.pressed.connect(func() -> void: result_primary_requested.emit())
	_result_overlay.visible = false
	_pause_overlay.visible = false
	_install_focus_order()
	apply_language(_language)


func set_setup(horizontal_aim: float, elevation_degrees: float, power_percent: float) -> void:
	_syncing = true
	_horizontal_slider.value = horizontal_aim
	_elevation_slider.value = elevation_degrees
	_power_slider.value = power_percent
	_syncing = false
	_update_setup_labels()


func set_busy(busy: bool) -> void:
	_busy = busy
	_horizontal_slider.editable = not busy
	_elevation_slider.editable = not busy
	_power_slider.editable = not busy
	_fire_button.disabled = busy
	_fire_label.modulate = Color(1.0, 1.0, 1.0, 0.45 if busy else 1.0)
	_retry_button.disabled = not busy
	_pause_retry.disabled = not busy


func set_view(view_mode: StringName) -> void:
	_oblique_button.button_pressed = view_mode == &"oblique"
	_side_button.button_pressed = view_mode == &"side"


func show_clear(_course: CannonGolfCourseData, has_next: bool) -> void:
	var english := _language == "en"
	_result_title.text = "COMPLETE" if english else "완료"
	_result_primary.text = ("NEXT COURSE" if english else "다음 코스") if has_next \
			else ("PLAY AGAIN" if english else "다시 하기")
	_result_overlay.visible = true
	_result_primary.grab_focus.call_deferred()


func hide_clear() -> void:
	_result_overlay.visible = false


func focus_fire() -> void:
	_fire_button.grab_focus.call_deferred()


func set_pause_visible(visible: bool) -> void:
	_pause_suspended = false
	_pause_overlay.visible = visible
	if visible:
		%Resume.grab_focus.call_deferred()


func set_pause_suspended(suspended: bool) -> void:
	_pause_suspended = suspended
	_pause_overlay.visible = not suspended


func focus_pause_settings() -> void:
	%PauseSettings.grab_focus.call_deferred()


func apply_language(language: String) -> void:
	_language = language
	var english := language == "en"
	%HorizontalLabel.text = "H" if english else "좌우"
	%ElevationLabel.text = "V" if english else "상하"
	%PowerLabel.text = "PWR" if english else "파워"
	_fire_label.text = "FIRE" if english else "발사"
	_set_icon_copy(_fire_button, "Fire (Space)" if english else "발사 (Space)")
	_set_icon_copy(_oblique_button, "Overview (1)" if english else "전체 보기 (1)")
	_set_icon_copy(_side_button, "Side view (2)" if english else "측면 보기 (2)")
	_set_icon_copy(_retry_button, "Quick retry (R)" if english else "빠른 재발사 (R)")
	_set_icon_copy(%PauseButton, "Pause (Esc)" if english else "일시정지 (Esc)")
	%PauseTitle.text = "PAUSED" if english else "일시정지"
	%Resume.text = "RESUME" if english else "계속하기"
	_pause_retry.text = "RELAUNCH" if english else "같은 설정으로 재발사"
	%PauseReset.text = "RESET COURSE" if english else "코스 초기화"
	%PauseSettings.text = "SETTINGS" if english else "설정"
	%PauseStages.text = "COURSE SELECT" if english else "코스 선택"
	%PauseMainMenu.text = "MAIN MENU" if english else "메인 메뉴"
	set_busy(_busy)


func _unhandled_input(event: InputEvent) -> void:
	if _pause_suspended or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		pause_requested.emit()


func _on_setup_control_changed(_value: float) -> void:
	_update_setup_labels()
	if not _syncing:
		setup_changed.emit(
			_horizontal_slider.value,
			_elevation_slider.value,
			_power_slider.value
		)


func _update_setup_labels() -> void:
	_horizontal_value.text = "%d" % int(roundf(_horizontal_slider.value))
	_elevation_value.text = "%d°" % int(roundf(_elevation_slider.value))
	_power_value.text = "%d%%" % int(roundf(_power_slider.value))


func _set_icon_copy(button: Button, accessible_copy: String) -> void:
	button.tooltip_text = accessible_copy
	button.set("accessibility_name", accessible_copy)


func _install_focus_order() -> void:
	var controls: Array[Control] = [
		_horizontal_slider,
		_elevation_slider,
		_power_slider,
		_oblique_button,
		_side_button,
		_retry_button,
		%PauseButton,
		_fire_button,
	]
	for index in range(controls.size()):
		var control := controls[index]
		control.focus_neighbor_left = controls[posmod(index - 1, controls.size())].get_path()
		control.focus_previous = control.focus_neighbor_left
		control.focus_neighbor_right = controls[(index + 1) % controls.size()].get_path()
		control.focus_next = control.focus_neighbor_right
