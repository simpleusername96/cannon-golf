class_name CannonGolfHUD
extends CanvasLayer

signal fire_requested
signal setup_changed(elevation_degrees: float, power_percent: float)
signal course_step_requested(step: int)
signal view_requested(view_mode: StringName)
signal reset_requested
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
@onready var _fire_button: Button = %FireButton
@onready var _result_overlay: Control = %ResultOverlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_body: Label = %ResultBody
@onready var _result_primary: Button = %ResultPrimary

var _syncing := false
var _course_index_value := 0
var _course_count := 1


func _ready() -> void:
	_elevation_slider.value_changed.connect(_on_setup_control_changed)
	_power_slider.value_changed.connect(_on_setup_control_changed)
	_previous_course.pressed.connect(func() -> void: course_step_requested.emit(-1))
	_next_course.pressed.connect(func() -> void: course_step_requested.emit(1))
	_oblique_button.pressed.connect(func() -> void: view_requested.emit(&"oblique"))
	_side_button.pressed.connect(func() -> void: view_requested.emit(&"side"))
	_reset_button.pressed.connect(func() -> void: reset_requested.emit())
	_fire_button.pressed.connect(func() -> void: fire_requested.emit())
	_result_primary.pressed.connect(func() -> void: result_primary_requested.emit())
	_result_overlay.visible = false


func set_course(course: CannonGolfCourseData, index: int, count: int) -> void:
	_course_index_value = index
	_course_count = count
	_course_index.text = "COURSE %02d  /  %02d" % [index + 1, count]
	_course_name.text = course.display_name
	_brief.text = course.short_brief
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
	_goal_progress.text = "골  1 / 1  완료" if complete else "골  0 / 1"


func set_feedback(message: String, strong: bool = false) -> void:
	_feedback.text = message
	_feedback.modulate = Color("2584FF") if strong else Color("29384B")


func set_busy(busy: bool) -> void:
	_elevation_slider.editable = not busy
	_power_slider.editable = not busy
	_previous_course.disabled = busy or _course_index_value <= 0
	_next_course.disabled = busy or _course_index_value >= _course_count - 1
	_fire_button.disabled = busy
	_fire_button.text = "비행 중" if busy else "발사"


func set_view(view_mode: StringName) -> void:
	_oblique_button.button_pressed = view_mode == &"oblique"
	_side_button.button_pressed = view_mode == &"side"


func show_clear(course: CannonGolfCourseData, has_next: bool) -> void:
	_result_title.text = "안전 착지"
	_result_body.text = "%s 코스를 완료했습니다.\n공은 골 안에 그대로 유지됩니다." % course.display_name
	_result_primary.text = "다음 코스" if has_next else "다시 하기"
	_result_overlay.visible = true
	_result_primary.grab_focus.call_deferred()


func hide_clear() -> void:
	_result_overlay.visible = false


func focus_fire() -> void:
	_fire_button.grab_focus.call_deferred()


func _on_setup_control_changed(_value: float) -> void:
	_update_setup_labels()
	if not _syncing:
		setup_changed.emit(_elevation_slider.value, _power_slider.value)


func _update_setup_labels() -> void:
	_elevation_value.text = "%d°" % int(roundf(_elevation_slider.value))
	_power_value.text = "%d%%" % int(roundf(_power_slider.value))
