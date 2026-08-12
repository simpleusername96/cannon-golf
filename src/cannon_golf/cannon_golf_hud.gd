class_name CannonGolfHUD
extends CanvasLayer

signal fire_requested
signal retry_requested
signal setup_changed(elevation_degrees: float, power_percent: float)
signal course_step_requested(step: int)
signal view_requested(view_mode: StringName)
signal reset_requested
signal pause_requested
signal settings_requested
signal course_select_requested
signal main_menu_requested
signal result_primary_requested

@onready var _course_index: Label = %CourseIndex
@onready var _course_name: Label = %CourseName
@onready var _brief: Label = %Brief
@onready var _goal_progress: Label = %GoalProgress
@onready var _feedback: Label = %Feedback
@onready var _elevation_value: Label = %ElevationValue
@onready var _elevation_slider: HSlider = %ElevationSlider
@onready var _power_value: Label = %PowerValue
@onready var _power_slider: HSlider = %PowerSlider
@onready var _previous_course: Button = %PreviousCourse
@onready var _next_course: Button = %NextCourse
@onready var _oblique_button: Button = %ObliqueButton
@onready var _side_button: Button = %SideButton
@onready var _reset_button: Button = %ResetButton
@onready var _retry_button: Button = %RetryButton
@onready var _fire_button: Button = %FireButton
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _result_overlay: Control = %ResultOverlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_body: Label = %ResultBody
@onready var _result_primary: Button = %ResultPrimary

var _syncing := false
var _pause_suspended := false
var _course_index_value := 0
var _course_count := 1
var _course: CannonGolfCourseData
var _goal_complete := false
var _busy := false
var _language := "ko"


func _ready() -> void:
	_elevation_slider.value_changed.connect(_on_setup_control_changed)
	_power_slider.value_changed.connect(_on_setup_control_changed)
	_previous_course.pressed.connect(func() -> void: course_step_requested.emit(-1))
	_next_course.pressed.connect(func() -> void: course_step_requested.emit(1))
	_oblique_button.pressed.connect(func() -> void: view_requested.emit(&"oblique"))
	_side_button.pressed.connect(func() -> void: view_requested.emit(&"side"))
	_reset_button.pressed.connect(func() -> void: reset_requested.emit())
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	_fire_button.pressed.connect(func() -> void: fire_requested.emit())
	%PauseButton.pressed.connect(func() -> void: pause_requested.emit())
	%Resume.pressed.connect(func() -> void: pause_requested.emit())
	%PauseRetry.pressed.connect(func() -> void: retry_requested.emit())
	%PauseReset.pressed.connect(func() -> void: reset_requested.emit())
	%PauseSettings.pressed.connect(func() -> void: settings_requested.emit())
	%PauseStages.pressed.connect(func() -> void: course_select_requested.emit())
	%PauseMainMenu.pressed.connect(func() -> void: main_menu_requested.emit())
	_result_primary.pressed.connect(func() -> void: result_primary_requested.emit())
	_result_overlay.visible = false
	_pause_overlay.visible = false


func set_course(course: CannonGolfCourseData, index: int, count: int) -> void:
	_course = course
	_course_index_value = index
	_course_count = count
	_course_index.text = "COURSE %02d  /  %02d" % [index + 1, count]
	_course_name.text = _course_name_for(course)
	_brief.text = _course_brief_for(course)
	_previous_course.disabled = index <= 0
	_next_course.disabled = index >= count - 1
	set_goal_complete(false)


func set_setup(elevation_degrees: float, power_percent: float) -> void:
	_syncing = true
	_elevation_slider.value = elevation_degrees
	_power_slider.value = power_percent
	_syncing = false
	_update_setup_labels()


func set_goal_complete(complete: bool) -> void:
	_goal_complete = complete
	var english := _language == "en"
	_goal_progress.text = ("GOAL  1 / 1  COMPLETE" if english else "골  1 / 1  완료") if complete \
			else ("GOAL  0 / 1" if english else "골  0 / 1")


func set_feedback(message: String, strong: bool = false) -> void:
	_feedback.text = message
	_feedback.modulate = Color("2584FF") if strong else Color("29384B")


func set_busy(busy: bool) -> void:
	_busy = busy
	_elevation_slider.editable = not busy
	_power_slider.editable = not busy
	_previous_course.disabled = busy or _course_index_value <= 0
	_next_course.disabled = busy or _course_index_value >= _course_count - 1
	_fire_button.disabled = busy
	_fire_button.text = ("IN FLIGHT" if _language == "en" else "비행 중") if busy \
			else ("FIRE" if _language == "en" else "발사")


func set_view(view_mode: StringName) -> void:
	_oblique_button.button_pressed = view_mode == &"oblique"
	_side_button.button_pressed = view_mode == &"side"


func show_clear(course: CannonGolfCourseData, has_next: bool) -> void:
	var english := _language == "en"
	_result_title.text = "SAFE LANDING" if english else "안전 착지"
	_result_body.text = ("%s complete.\nThe ball remains safely in the goal." % _course_name_for(course)) if english \
			else ("%s 코스를 완료했습니다.\n공은 골 안에 그대로 유지됩니다." % course.display_name)
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
	%PreviousCourse.text = "PREVIOUS" if english else "이전 코스"
	%NextCourse.text = "NEXT" if english else "다음 코스"
	$Root/ViewPanel/Margin/Views/ViewLabel.text = "VIEW" if english else "시점"
	%ObliqueButton.text = "1  OVERVIEW" if english else "1  전체"
	%SideButton.text = "2  SIDE" if english else "2  측면"
	%RetryButton.text = "R  RELAUNCH" if english else "R  재발사"
	%PauseButton.text = "Esc  MENU" if english else "Esc  메뉴"
	%ResetButton.text = "Shift+R  RESET COURSE" if english else "Shift+R  코스 초기화"
	$Root/ActionPanel/Margin/Rows/Hint.text = "Space fire · 1/2 view · W/S angle · A/D power · Arrows explore · Wheel zoom" if english else "Space 발사 · 1/2 시점 · W/S 각도 · A/D 파워 · 방향키 탐색 · 휠 확대"
	$Root/SetupPanel/Margin/Rows/Title.text = "LAUNCH SETUP" if english else "발사 설정"
	$Root/SetupPanel/Margin/Rows/ElevationRow/Label.text = "ANGLE" if english else "고도각"
	$Root/SetupPanel/Margin/Rows/PowerRow/Label.text = "POWER" if english else "파워"
	$Root/PauseOverlay/Center/Panel/Margin/Rows/Title.text = "PAUSED" if english else "일시정지"
	%Resume.text = "RESUME" if english else "계속하기"
	%PauseRetry.text = "RELAUNCH WITH THIS SETUP" if english else "같은 설정으로 재발사"
	%PauseReset.text = "RESET COURSE" if english else "코스 초기화"
	%PauseSettings.text = "SETTINGS" if english else "설정"
	%PauseStages.text = "COURSE SELECT" if english else "코스 선택"
	%PauseMainMenu.text = "MAIN MENU" if english else "메인 메뉴"
	if _course != null:
		_course_name.text = _course_name_for(_course)
		_brief.text = _course_brief_for(_course)
	set_goal_complete(_goal_complete)
	set_busy(_busy)


func _course_name_for(course: CannonGolfCourseData) -> String:
	if _language != "en":
		return course.display_name
	return "RISING BEND" if course.course_id == &"rising_bend" else "QUIET SHELF"


func _course_brief_for(course: CannonGolfCourseData) -> String:
	if _language != "en":
		return course.short_brief
	if course.course_id == &"rising_bend":
		return "A farther, higher goal. Use the side view to read the elevation."
	return "A wide first goal. Set angle and power for a safe landing."


func _unhandled_input(event: InputEvent) -> void:
	if _pause_suspended or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		pause_requested.emit()


func _on_setup_control_changed(_value: float) -> void:
	_update_setup_labels()
	if not _syncing:
		setup_changed.emit(_elevation_slider.value, _power_slider.value)


func _update_setup_labels() -> void:
	_elevation_value.text = "%d°" % int(roundf(_elevation_slider.value))
	_power_value.text = "%d%%" % int(roundf(_power_slider.value))
