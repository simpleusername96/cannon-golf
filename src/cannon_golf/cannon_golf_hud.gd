class_name CannonGolfHUD
extends CanvasLayer

const STEP_HOLD_DELAY := 0.32
const STEP_HOLD_REPEAT := 0.08

signal fire_requested
signal retry_requested
signal setup_changed(horizontal_aim: float, elevation_degrees: float, power_percent: float)
signal view_requested(view_mode: StringName)
signal launcher_source_requested(goal_index: int)
signal follow_requested
signal camera_zoom_requested(wheel_steps: float)
signal camera_reset_requested
signal reset_requested
signal pause_requested
signal settings_requested
signal course_select_requested
signal main_menu_requested
signal result_primary_requested

@onready var _horizontal_value: Label = %HorizontalValue
@onready var _horizontal_slider: HSlider = %HorizontalSlider
@onready var _horizontal_decrease: Button = %HorizontalDecrease
@onready var _horizontal_increase: Button = %HorizontalIncrease
@onready var _elevation_value: Label = %ElevationValue
@onready var _elevation_slider: HSlider = %ElevationSlider
@onready var _elevation_decrease: Button = %ElevationDecrease
@onready var _elevation_increase: Button = %ElevationIncrease
@onready var _power_value: Label = %PowerValue
@onready var _power_slider: HSlider = %PowerSlider
@onready var _power_decrease: Button = %PowerDecrease
@onready var _power_increase: Button = %PowerIncrease
@onready var _oblique_button: Button = %ObliqueButton
@onready var _cannon_button: Button = %CannonButton
@onready var _follow_button: Button = %FollowButton
@onready var _zoom_in_button: Button = %ZoomInButton
@onready var _camera_reset_button: Button = %CameraResetButton
@onready var _zoom_out_button: Button = %ZoomOutButton
@onready var _shortcut_button: Button = %ShortcutButton
@onready var _shortcut_panel: PanelContainer = %ShortcutPanel
@onready var _shortcut_close_button: Button = %ShortcutCloseButton
@onready var _retry_button: Button = %RetryButton
@onready var _fire_button: Button = %FireButton
@onready var _pause_retry: Button = %PauseRetry
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _result_overlay: Control = %ResultOverlay
@onready var _result_title: Label = %ResultTitle
@onready var _result_primary: Button = %ResultPrimary
@onready var _goal_progress_label: Label = %GoalProgressLabel
@onready var _launcher_source_panel: PanelContainer = $Root/LauncherSource
@onready var _launcher_source_previous: Button = %LauncherSourcePrevious
@onready var _launcher_source_name: Label = %LauncherSourceName
@onready var _launcher_source_position: Label = %LauncherSourcePosition
@onready var _launcher_source_next: Button = %LauncherSourceNext
@onready var _aim_reticle: Control = %AimReticle

var _syncing := false
var _pause_suspended := false
var _active_shot_count := 0
var _cleared := false
var _planning_view: StringName = &"oblique"
var _camera_mode: StringName = &"planning"
var _language := "ko"
var _completed_goal_count := 0
var _total_goal_count := 1
var _level_index := 0
var _result_has_next := false
var _launcher_sources: Array[int] = [-1]
var _selected_launcher_source := -1
var _held_slider: HSlider
var _held_direction := 0.0
var _hold_elapsed := 0.0
var _next_hold_repeat := STEP_HOLD_DELAY


func _ready() -> void:
	_horizontal_slider.value_changed.connect(_on_setup_control_changed)
	_elevation_slider.value_changed.connect(_on_setup_control_changed)
	_power_slider.value_changed.connect(_on_setup_control_changed)
	_connect_step_button(_horizontal_decrease, _horizontal_slider, -1.0)
	_connect_step_button(_horizontal_increase, _horizontal_slider, 1.0)
	_connect_step_button(_elevation_decrease, _elevation_slider, -1.0)
	_connect_step_button(_elevation_increase, _elevation_slider, 1.0)
	_connect_step_button(_power_decrease, _power_slider, -1.0)
	_connect_step_button(_power_increase, _power_slider, 1.0)
	_oblique_button.pressed.connect(func() -> void: view_requested.emit(&"oblique"))
	_launcher_source_previous.pressed.connect(_step_launcher_source.bind(-1))
	_launcher_source_next.pressed.connect(_step_launcher_source.bind(1))
	_cannon_button.pressed.connect(func() -> void: view_requested.emit(&"cannon"))
	_follow_button.pressed.connect(func() -> void: follow_requested.emit())
	_zoom_in_button.pressed.connect(func() -> void: camera_zoom_requested.emit(1.0))
	_camera_reset_button.pressed.connect(func() -> void: camera_reset_requested.emit())
	_zoom_out_button.pressed.connect(func() -> void: camera_zoom_requested.emit(-1.0))
	_shortcut_button.pressed.connect(toggle_shortcut_panel)
	_shortcut_close_button.pressed.connect(set_shortcut_panel_visible.bind(false, true))
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
	_shortcut_panel.visible = false
	_install_focus_order()
	apply_language(_language)


func _process(delta: float) -> void:
	if _held_slider == null or is_zero_approx(_held_direction):
		return
	_hold_elapsed += delta
	while _hold_elapsed >= _next_hold_repeat:
		_step_slider(_held_slider, _held_direction)
		if not _can_step_slider(_held_slider, _held_direction):
			_end_step_hold()
			break
		_next_hold_repeat += STEP_HOLD_REPEAT


func set_setup(horizontal_aim: float, elevation_degrees: float, power_percent: float) -> void:
	_syncing = true
	_horizontal_slider.value = horizontal_aim
	_elevation_slider.value = elevation_degrees
	_power_slider.value = power_percent
	_syncing = false
	_update_setup_labels()
	_refresh_setup_button_states()


func set_launch_availability(active_shots: int, cleared: bool) -> void:
	_active_shot_count = maxi(active_shots, 0)
	_cleared = cleared
	_horizontal_slider.editable = not cleared
	_elevation_slider.editable = not cleared
	_power_slider.editable = not cleared
	if cleared:
		_end_step_hold()
	_fire_button.disabled = _cleared
	_retry_button.disabled = _cleared or _active_shot_count <= 0
	_pause_retry.disabled = _cleared or _active_shot_count <= 0
	_follow_button.disabled = _cleared or _active_shot_count <= 0
	_launcher_source_panel.visible = not _cleared
	_refresh_launcher_source_selector()
	_refresh_setup_button_states()


func set_goal_progress(completed_goal_count: int, total_goal_count: int) -> void:
	_total_goal_count = maxi(total_goal_count, 1)
	_completed_goal_count = clampi(completed_goal_count, 0, _total_goal_count)
	_update_goal_progress_copy()


func set_level(index: int) -> void:
	_level_index = clampi(index, 0, CannonGolfCourseCatalog.level_count() - 1)
	_update_goal_progress_copy()


func set_launcher_sources(completed_goal_indices: Array[int], selected_goal_index: int) -> void:
	_launcher_sources.clear()
	_launcher_sources.append(-1)
	for goal_index in completed_goal_indices:
		if goal_index >= 0 and not _launcher_sources.has(goal_index):
			_launcher_sources.append(goal_index)
	_launcher_sources.sort()
	# Sorting places Start (-1) first and keeps stable goal numbering.
	_selected_launcher_source = selected_goal_index \
			if _launcher_sources.has(selected_goal_index) else -1
	_refresh_launcher_source_selector()
	set_launch_availability(_active_shot_count, _cleared)


func set_view(view_mode: StringName) -> void:
	_planning_view = view_mode
	_refresh_camera_buttons()


func set_camera_mode(mode: StringName) -> void:
	_camera_mode = mode
	_refresh_camera_buttons()


func show_clear(course: CannonGolfCourseData, has_next: bool) -> void:
	_end_step_hold()
	set_shortcut_panel_visible(false)
	var resolved_index := CannonGolfCourseCatalog.index_of(course.course_id) if course != null else -1
	if resolved_index >= 0:
		_level_index = resolved_index
	_result_has_next = has_next
	_update_result_copy()
	_result_overlay.visible = true
	_result_primary.grab_focus.call_deferred()


func hide_clear() -> void:
	_result_overlay.visible = false


func focus_fire() -> void:
	_fire_button.grab_focus.call_deferred()


func set_pause_visible(visible: bool) -> void:
	_end_step_hold()
	if visible:
		set_shortcut_panel_visible(false)
	_pause_suspended = false
	_pause_overlay.visible = visible
	if visible:
		%Resume.grab_focus.call_deferred()


func set_pause_suspended(suspended: bool) -> void:
	_end_step_hold()
	set_shortcut_panel_visible(false)
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
	_set_icon_copy(_horizontal_decrease, "Decrease horizontal aim (Q)" if english else "좌우 조준 감소 (Q)")
	_set_icon_copy(_horizontal_increase, "Increase horizontal aim (E)" if english else "좌우 조준 증가 (E)")
	_set_icon_copy(_elevation_decrease, "Decrease elevation (S)" if english else "상하 조준 감소 (S)")
	_set_icon_copy(_elevation_increase, "Increase elevation (W)" if english else "상하 조준 증가 (W)")
	_set_icon_copy(_power_decrease, "Decrease power (A)" if english else "파워 감소 (A)")
	_set_icon_copy(_power_increase, "Increase power (D)" if english else "파워 증가 (D)")
	_fire_button.text = "FIRE" if english else "발사"
	_set_icon_copy(_fire_button, "Fire (Space)" if english else "발사 (Space)")
	_set_icon_copy(_oblique_button, "Overview (1)" if english else "전체 보기 (1)")
	_set_icon_copy(_cannon_button, "Cannon view (2)" if english else "대포 시점 (2)")
	_set_icon_copy(_zoom_in_button, "Zoom in (Wheel up)" if english else "확대 (휠 위)")
	_set_icon_copy(
		_camera_reset_button,
		"Reset view (Home) · Left-drag move · Right-drag orbit" if english \
				else "시점 원위치 (Home) · 왼쪽 드래그 이동 · 오른쪽 드래그 회전"
	)
	_set_icon_copy(_zoom_out_button, "Zoom out (Wheel down)" if english else "축소 (휠 아래)")
	_set_icon_copy(_shortcut_button, "Show controls" if english else "조작법 보기")
	_set_icon_copy(_shortcut_close_button, "Close controls" if english else "조작법 닫기")
	%ShortcutTitle.text = "CONTROLS" if english else "조작법"
	%ShortcutHorizontal.text = "Horizontal aim" if english else "좌우 조준"
	%ShortcutElevation.text = "Elevation" if english else "상하 조준"
	%ShortcutPower.text = "Power" if english else "파워"
	%ShortcutFire.text = "Fire" if english else "발사"
	%ShortcutPlanning.text = "Return to aim" if english else "조준으로 복귀"
	%ShortcutRetry.text = "Relaunch same setup" if english else "같은 설정 재발사"
	%ShortcutReset.text = "Restart level" if english else "레벨 다시 시작"
	%ShortcutView.text = "Overview / cannon view" if english else "전체 / 대포 시점"
	%DragKey.text = "L / R Drag" if english else "좌 / 우 드래그"
	%ShortcutDrag.text = "Move / orbit view" if english else "화면 이동 / 회전"
	%WheelKey.text = "Wheel" if english else "휠"
	%ShortcutWheel.text = "Zoom" if english else "확대 / 축소"
	%PanKey.text = "Arrows" if english else "방향키"
	%ShortcutPan.text = "Pan view" if english else "화면 이동"
	%ShortcutPause.text = "Pause" if english else "일시정지"
	_set_icon_copy(_retry_button, "Quick retry (R)" if english else "빠른 재발사 (R)")
	_set_icon_copy(%PauseButton, "Pause (Esc)" if english else "일시정지 (Esc)")
	%PauseTitle.text = "PAUSED" if english else "일시정지"
	%Resume.text = "RESUME" if english else "계속하기"
	_pause_retry.text = "RELAUNCH" if english else "같은 설정으로 재발사"
	%PauseReset.text = "RESTART LEVEL" if english else "레벨 다시 시작"
	%PauseSettings.text = "SETTINGS" if english else "설정"
	%PauseStages.text = "LEVEL SELECT" if english else "레벨 선택"
	%PauseMainMenu.text = "MAIN MENU" if english else "메인 메뉴"
	_update_goal_progress_copy()
	_update_result_copy()
	_refresh_launcher_source_selector()
	set_launch_availability(_active_shot_count, _cleared)
	_refresh_camera_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if _pause_suspended or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _shortcut_panel.visible:
			set_shortcut_panel_visible(false, true)
			return
		pause_requested.emit()


func _on_setup_control_changed(_value: float) -> void:
	_update_setup_labels()
	_refresh_setup_button_states()
	if not _syncing:
		setup_changed.emit(
			_horizontal_slider.value,
			_elevation_slider.value,
			_power_slider.value
		)


func _step_launcher_source(direction: int) -> void:
	if _cleared or direction == 0:
		return
	var current_index := _launcher_sources.find(_selected_launcher_source)
	var next_index := current_index + signi(direction)
	if current_index < 0 or next_index < 0 or next_index >= _launcher_sources.size():
		return
	launcher_source_requested.emit(_launcher_sources[next_index])


func _update_setup_labels() -> void:
	_horizontal_value.text = "%d" % int(roundf(_horizontal_slider.value))
	_elevation_value.text = "%d°" % int(roundf(_elevation_slider.value))
	_power_value.text = "%d%%" % int(roundf(_power_slider.value))


func _update_goal_progress_copy() -> void:
	var progress := ("GOALS %d / %d" if _language == "en" else "골 %d / %d") % [
		_completed_goal_count,
		_total_goal_count,
	]
	_goal_progress_label.text = "%s · %s" % [
		CannonGolfCourseCatalog.level_label(_level_index),
		progress,
	]


func _update_result_copy() -> void:
	if _result_title == null or _result_primary == null:
		return
	var english := _language == "en"
	var level := CannonGolfCourseCatalog.level_label(_level_index)
	_result_title.text = "%s COMPLETE" % level if english else "%s 완료" % level
	if _result_has_next:
		var next_level := CannonGolfCourseCatalog.level_label(_level_index + 1)
		_result_primary.text = "START %s" % next_level if english else "%s 시작" % next_level
	else:
		_result_primary.text = "REPLAY %s" % level if english else "%s 다시 하기" % level


func _refresh_launcher_source_selector() -> void:
	if _launcher_source_previous == null or _launcher_source_next == null:
		return
	var english := _language == "en"
	var selected_index := maxi(_launcher_sources.find(_selected_launcher_source), 0)
	var selected_goal := _launcher_sources[selected_index]
	_launcher_source_name.text = ("START" if english else "시작점") if selected_goal < 0 \
			else (("GOAL %d" if english else "골 %d") % (selected_goal + 1))
	_launcher_source_position.text = (
		("CANNON POSITION %d / %d" if english else "대포 위치 %d / %d") % [
			selected_index + 1,
			_launcher_sources.size(),
		]
	)
	_launcher_source_previous.disabled = _cleared or selected_index <= 0
	_launcher_source_next.disabled = _cleared or selected_index >= _launcher_sources.size() - 1
	_set_icon_copy(
		_launcher_source_previous,
		"Previous cannon position" if english else "이전 대포 위치"
	)
	_set_icon_copy(
		_launcher_source_next,
		"Next cannon position" if english else "다음 대포 위치"
	)


func _connect_step_button(button: Button, slider: HSlider, direction: float) -> void:
	button.button_down.connect(_begin_step_hold.bind(slider, direction))
	button.button_up.connect(_end_step_hold)


func _begin_step_hold(slider: HSlider, direction: float) -> void:
	_step_slider(slider, direction)
	if not _can_step_slider(slider, direction):
		return
	_held_slider = slider
	_held_direction = direction
	_hold_elapsed = 0.0
	_next_hold_repeat = STEP_HOLD_DELAY


func _end_step_hold() -> void:
	_held_slider = null
	_held_direction = 0.0


func _step_slider(slider: HSlider, direction: float) -> void:
	if slider == null or not slider.editable or _cleared:
		return
	if slider == _horizontal_slider:
		slider.value = CannonGolfBallistics.canonical_horizontal_aim(
			slider.value + direction * slider.step
		)
		return
	slider.value = clampf(
		slider.value + direction * slider.step,
		slider.min_value,
		slider.max_value
	)


func _can_step_slider(slider: HSlider, direction: float) -> bool:
	if slider == null or not slider.editable or _cleared:
		return false
	if slider == _horizontal_slider:
		return true
	if direction < 0.0:
		return slider.value > slider.min_value
	if direction > 0.0:
		return slider.value < slider.max_value
	return false


func _refresh_setup_button_states() -> void:
	_horizontal_decrease.disabled = _cleared
	_horizontal_increase.disabled = _cleared
	_elevation_decrease.disabled = _cleared or _elevation_slider.value <= _elevation_slider.min_value
	_elevation_increase.disabled = _cleared or _elevation_slider.value >= _elevation_slider.max_value
	_power_decrease.disabled = _cleared or _power_slider.value <= _power_slider.min_value
	_power_increase.disabled = _cleared or _power_slider.value >= _power_slider.max_value


func toggle_shortcut_panel() -> void:
	set_shortcut_panel_visible(not _shortcut_panel.visible)


func set_shortcut_panel_visible(visible: bool, restore_focus: bool = false) -> void:
	_shortcut_panel.visible = visible
	_shortcut_button.button_pressed = visible
	if visible:
		_shortcut_close_button.grab_focus.call_deferred()
	elif restore_focus:
		_shortcut_button.grab_focus.call_deferred()


func is_shortcut_panel_visible() -> bool:
	return _shortcut_panel.visible


func _refresh_camera_buttons() -> void:
	var following := _camera_mode == &"follow"
	_aim_reticle.visible = not following and _planning_view == &"cannon"
	_follow_button.button_pressed = following
	var english := _language == "en"
	_set_icon_copy(
		_follow_button,
		("Return to planning (Tab)" if english else "조준 시점으로 돌아가기 (Tab)")
				if following else ("Follow ball" if english else "공 따라가기")
	)
	_oblique_button.button_pressed = not following and _planning_view == &"oblique"
	_cannon_button.button_pressed = not following and _planning_view == &"cannon"


func _set_icon_copy(button: Button, accessible_copy: String) -> void:
	button.tooltip_text = accessible_copy
	button.set("accessibility_name", accessible_copy)


func _install_focus_order() -> void:
	var controls: Array[Control] = [
		_launcher_source_previous,
		_launcher_source_next,
		_horizontal_decrease,
		_horizontal_slider,
		_horizontal_increase,
		_elevation_decrease,
		_elevation_slider,
		_elevation_increase,
		_power_decrease,
		_power_slider,
		_power_increase,
		_zoom_in_button,
		_camera_reset_button,
		_zoom_out_button,
		_shortcut_button,
		_oblique_button,
		_cannon_button,
		_follow_button,
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
	_zoom_in_button.focus_neighbor_top = _zoom_out_button.get_path()
	_zoom_in_button.focus_neighbor_bottom = _camera_reset_button.get_path()
	_camera_reset_button.focus_neighbor_top = _zoom_in_button.get_path()
	_camera_reset_button.focus_neighbor_bottom = _zoom_out_button.get_path()
	_zoom_out_button.focus_neighbor_top = _camera_reset_button.get_path()
	_zoom_out_button.focus_neighbor_bottom = _shortcut_button.get_path()
	_shortcut_button.focus_neighbor_top = _zoom_out_button.get_path()
	_shortcut_button.focus_neighbor_bottom = _zoom_in_button.get_path()
	_shortcut_close_button.focus_next = _shortcut_button.get_path()
	_shortcut_close_button.focus_previous = _shortcut_button.get_path()
