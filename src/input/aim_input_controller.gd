class_name AimInputController
extends Node3D

signal aim_interaction_changed(active: bool)
signal target_pointer_requested(screen_position: Vector2, settled: bool)
signal elevation_step_requested(delta_degrees: float)
signal power_step_requested(delta_percent: float)

const KEYBOARD_ANGLE_STEP := 0.5
const BUTTON_ANGLE_STEP := 0.5
const BUTTON_POWER_STEP := 2.0
const WHEEL_POWER_STEP := 1.0
const HOLD_DELAY_SECONDS := 0.30
const HOLD_REPEAT_SECONDS := 0.08

var _cannon: CannonController
var _stage_controller: StageController
var _camera_director: CameraDirector
var _drag_active := false
var _held_keys: Dictionary = {}


func configure(
		cannon: CannonController,
		stage_controller: StageController,
		camera_director: CameraDirector
) -> void:
	_cannon = cannon
	_stage_controller = stage_controller
	_camera_director = camera_director


func _process(delta: float) -> void:
	if not _can_adjust_aim():
		_held_keys.clear()
		_end_drag()
		return
	if _drag_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()
	for keycode in _held_keys.keys():
		var held: Dictionary = _held_keys[keycode]
		held.elapsed = float(held.elapsed) + delta
		while float(held.elapsed) + 0.000001 >= float(held.next_repeat):
			_emit_elevation_step(float(held.direction) * KEYBOARD_ANGLE_STEP)
			held.next_repeat = float(held.next_repeat) + HOLD_REPEAT_SECONDS
		_held_keys[keycode] = held


func adjust_power(delta_percent: float) -> bool:
	if not _can_adjust_aim():
		return false
	power_step_requested.emit(delta_percent)
	return true


func adjust_power_button(direction: float) -> bool:
	return adjust_power(signf(direction) * BUTTON_POWER_STEP)


func adjust_elevation_button(direction: float) -> bool:
	if not _can_adjust_aim():
		return false
	_emit_elevation_step(signf(direction) * BUTTON_ANGLE_STEP)
	return true


func request_fire() -> bool:
	if not _can_adjust_aim():
		return false
	return _stage_controller.request_fire(StageController.ActionOrigin.HUMAN)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	var keycode := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	var consumed := _handle_key(key)
	if consumed and keycode in [KEY_TAB, KEY_SPACE]:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_adjust_aim():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_drag()
				target_pointer_requested.emit(button.position, false)
			elif _drag_active:
				target_pointer_requested.emit(button.position, true)
				_end_drag()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_power(WHEEL_POWER_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_power(-WHEEL_POWER_STEP)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _drag_active and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			target_pointer_requested.emit(motion.position, false)
		elif not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_end_drag()


func _handle_key(event: InputEventKey) -> bool:
	var keycode := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if keycode == KEY_TAB and event.pressed and not event.echo:
		if _stage_controller == null:
			return false
		if _camera_director != null and _camera_director.current_mode == CameraDirector.Mode.FOLLOW:
			return _camera_director.return_to_aim_view()
		return _stage_controller.current_state == StageController.State.AIMING \
				and _camera_director != null \
				and _camera_director.toggle_interaction_mode()
	if keycode == KEY_SPACE:
		# Secondary focused buttons retain native Space activation. Fire keeps its
		# one-press shortcut even when the primary button owns focus.
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is Button and focus_owner.name != &"FireButton":
			return false
		if event.pressed and not event.echo:
			return request_fire()
		return false
	var direction := _elevation_direction_for_key(keycode)
	if is_zero_approx(direction):
		return false
	if not event.pressed:
		_held_keys.erase(keycode)
		return false
	if event.echo or _held_keys.has(keycode) or not _can_adjust_aim():
		return false
	_emit_elevation_step(direction * KEYBOARD_ANGLE_STEP)
	_held_keys[keycode] = {
		"direction": direction,
		"elapsed": 0.0,
		"next_repeat": HOLD_DELAY_SECONDS,
	}
	return false


func _emit_elevation_step(delta_degrees: float) -> void:
	elevation_step_requested.emit(delta_degrees)


func _begin_drag() -> void:
	if _drag_active:
		return
	_drag_active = true
	aim_interaction_changed.emit(true)


func _end_drag() -> void:
	if not _drag_active:
		return
	_drag_active = false
	aim_interaction_changed.emit(false)


func _elevation_direction_for_key(keycode: Key) -> float:
	match keycode:
		KEY_W:
			return 1.0
		KEY_S:
			return -1.0
		_:
			return 0.0


func _can_adjust_aim() -> bool:
	return _cannon != null and _stage_controller != null \
			and _camera_director != null \
			and _camera_director.current_mode == CameraDirector.Mode.AIMING \
			and _camera_director.aim_is_locked() \
			and _cannon.input_enabled \
			and _stage_controller.current_state == StageController.State.AIMING
