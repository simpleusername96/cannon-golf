class_name CannonGolfGame
extends Node3D

signal navigation_requested(destination: StringName)

enum LaunchState {
	PLANNING,
	FLYING,
	SETTLING,
	RECOVERING,
	CLEARED,
}

const LOW_SPEED_FAILURE_SECONDS := 1.25
const MAXIMUM_LIVE_BALLS := 2

@export_range(0, 1, 1) var initial_course_index := 0

@onready var _camera: Camera3D = %Camera
@onready var _course_builder: CannonGolfCourseBuilder = %CourseBuilder
@onready var _ball_root: Node3D = %Balls
@onready var _impact_history: CannonGolfImpactHistory = %ImpactHistory
@onready var _camera_rig: CannonGolfCourseCameraRig = %CourseCameraRig
@onready var _hud: CannonGolfHUD = %CannonGolfHUD

var course_index := 0
var launch_state := LaunchState.PLANNING
var planning_view: StringName:
	get:
		return _camera_rig.view_mode
var planning_pan: Vector3:
	get:
		return _camera_rig.pan_offset
var planning_zoom: float:
	get:
		return _camera_rig.zoom
var current_ball: CannonGolfBall
var confirmed_ball: CannonGolfBall
var last_launch_outcome: StringName = &""
var _active_balls: Array[CannonGolfBall] = []
var _live_shots: Dictionary = {}
var _planning_drag_active := false


func _ready() -> void:
	_hud.fire_requested.connect(fire)
	_hud.setup_changed.connect(_on_setup_changed)
	_hud.view_requested.connect(set_planning_view)
	_hud.follow_requested.connect(toggle_shot_camera)
	_hud.camera_zoom_requested.connect(zoom_planning)
	_hud.camera_reset_requested.connect(reset_planning_camera)
	_hud.retry_requested.connect(retry_attempt)
	_hud.reset_requested.connect(reset_course)
	_hud.pause_requested.connect(toggle_pause)
	_hud.settings_requested.connect(_on_settings_requested)
	_hud.course_select_requested.connect(_request_navigation.bind(&"course_select"))
	_hud.main_menu_requested.connect(_request_navigation.bind(&"main_menu"))
	_hud.result_primary_requested.connect(_on_result_primary_requested)
	_load_course(initial_course_index)


func _exit_tree() -> void:
	_end_planning_drag()
	get_tree().paused = false


func _process(delta: float) -> void:
	if _planning_drag_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_planning_drag()
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	if launch_state == LaunchState.CLEARED:
		return
	for ball in _active_balls.duplicate():
		if ball == null or not is_instance_valid(ball):
			_remove_live_ball(ball, false)
			continue
		_update_live_ball(ball, delta)
		if launch_state == LaunchState.CLEARED:
			return
	_refresh_launch_state()


func _update_live_ball(ball: CannonGolfBall, delta: float) -> void:
	var shot := _shot_state(ball)
	if shot == null or shot.ending:
		return
	var goal := _course_builder.goal
	var inside := goal.contains_rebound_column(
		ball.global_position,
		CannonGolfBall.RADIUS
	) if shot.entered_goal else goal.contains_ball(
		ball.global_position,
		CannonGolfBall.RADIUS
	)
	if inside:
		shot.entered_goal = true
		shot.reset_low_speed()
		if goal.motion_is_safe(ball.linear_velocity, ball.angular_velocity):
			shot.settle_elapsed += delta
			if shot.settle_elapsed >= goal.settle_seconds:
				_confirm_goal(ball)
		else:
			shot.reset_settlement()
	elif shot.entered_goal:
		_fail_ball(ball, &"bounced_out")
	else:
		shot.reset_settlement()
		var nearly_still := ball.has_reported_first_contact() \
				and ball.linear_velocity.length() < 0.34 \
				and ball.angular_velocity.length() < 1.1
		if ball.sleeping or nearly_still:
			shot.low_speed_elapsed += delta
			if shot.low_speed_elapsed >= LOW_SPEED_FAILURE_SECONDS:
				_fail_ball(ball, &"stopped_outside")
		else:
			shot.reset_low_speed()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var pressed_key := key_event.keycode \
			if key_event.keycode != KEY_NONE else key_event.physical_keycode
	if pressed_key == KEY_TAB:
		if return_to_planning_view():
			get_viewport().set_input_as_handled()
		return
	if pressed_key == KEY_HOME:
		reset_planning_camera()
		get_viewport().set_input_as_handled()
		return
	if pressed_key != KEY_SPACE:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is Button and focus_owner.name != &"FireButton":
		return
	# Consume an accepted launch before GUI dispatch so the focused Fire button
	# cannot activate a second launch from the same physical Space press.
	if fire():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_begin_planning_drag()
				get_viewport().set_input_as_handled()
			elif _planning_drag_active:
				_end_planning_drag()
				get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_planning(1.0)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_planning(-1.0)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _planning_drag_active:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			orbit_planning(mouse_motion.relative)
		else:
			_end_planning_drag()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			set_planning_view(&"oblique")
		KEY_2:
			set_planning_view(&"side")
		KEY_R:
			if event.shift_pressed:
				reset_course()
			else:
				retry_attempt()
		KEY_Q:
			_adjust_setup(-1.0, 0.0, 0.0)
		KEY_E:
			_adjust_setup(1.0, 0.0, 0.0)
		KEY_W:
			_adjust_setup(0.0, 1.0, 0.0)
		KEY_S:
			_adjust_setup(0.0, -1.0, 0.0)
		KEY_D:
			_adjust_setup(0.0, 0.0, 1.0)
		KEY_A:
			_adjust_setup(0.0, 0.0, -1.0)
		KEY_LEFT:
			pan_planning(Vector2(-1.0, 0.0))
		KEY_RIGHT:
			pan_planning(Vector2(1.0, 0.0))
		KEY_UP:
			pan_planning(Vector2(0.0, 1.0))
		KEY_DOWN:
			pan_planning(Vector2(0.0, -1.0))


func fire(follow_new_shot: bool = true) -> bool:
	if confirmed_ball != null or _active_balls.size() >= MAXIMUM_LIVE_BALLS:
		return false
	var ball := CannonGolfBall.new()
	ball.name = "ActiveGolfBall%02d" % (_active_balls.size() + 1)
	ball.configure(
		_course_builder.course.play_bounds,
		_course_builder.launcher.launch_origin(),
		_course_builder.launcher.launch_velocity()
	)
	ball.first_surface_contact.connect(_on_first_surface_contact)
	ball.launch_ended.connect(_on_ball_launch_ended)
	_ball_root.add_child(ball)
	_active_balls.append(ball)
	_live_shots[ball.get_instance_id()] = CannonGolfLiveShotState.new(ball)
	current_ball = ball
	launch_state = LaunchState.FLYING
	last_launch_outcome = &""
	if follow_new_shot:
		_camera_rig.follow(ball)
		_hud.set_camera_mode(&"follow")
	else:
		_hud.set_camera_mode(&"planning")
	_refresh_hud_availability()
	_hud.hide_clear()
	return true


func reset_course() -> void:
	_end_planning_drag()
	get_tree().paused = false
	_hud.set_pause_visible(false)
	_load_course(course_index)


func retry_attempt() -> bool:
	if launch_state == LaunchState.CLEARED or confirmed_ball != null \
			or current_ball == null or not is_instance_valid(current_ball):
		return false
	var retry_ball := current_ball
	var keep_follow := _camera_rig.is_following(retry_ball)
	_remove_live_ball(retry_ball, true, false)
	last_launch_outcome = &""
	get_tree().paused = false
	_hud.set_pause_visible(false)
	return fire(keep_follow)


func toggle_pause() -> void:
	_end_planning_drag()
	if launch_state == LaunchState.CLEARED:
		return
	if get_tree().paused:
		get_tree().paused = false
		_hud.set_pause_visible(false)
		return
	get_tree().paused = true
	_hud.set_pause_visible(true)


func set_external_overlay_open(open: bool) -> void:
	_hud.set_pause_suspended(open)
	if open:
		get_tree().paused = true
	else:
		get_tree().paused = true
		_hud.set_pause_visible(true)


func focus_pause_settings() -> void:
	_hud.focus_pause_settings()


func apply_language(language: String) -> void:
	_hud.apply_language(language)


func set_planning_view(view_mode: StringName) -> void:
	if not _camera_rig.set_view(view_mode):
		return
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_camera_mode(&"planning")


func toggle_shot_camera() -> bool:
	if _camera_rig.camera_mode == &"follow":
		_camera_rig.return_to_planning()
		_hud.set_camera_mode(&"planning")
		return true
	if current_ball == null or not is_instance_valid(current_ball):
		return false
	_camera_rig.follow(current_ball)
	_hud.set_camera_mode(&"follow")
	return true


func return_to_planning_view() -> bool:
	if _camera_rig.camera_mode != &"follow":
		return false
	_camera_rig.return_to_planning()
	_hud.set_camera_mode(&"planning")
	return true


func pan_planning(screen_direction: Vector2) -> void:
	_activate_planning_camera()
	_camera_rig.pan(screen_direction)


func orbit_planning(relative: Vector2) -> bool:
	_activate_planning_camera()
	return _camera_rig.orbit(relative)


func zoom_planning(wheel_steps: float) -> bool:
	_activate_planning_camera()
	return _camera_rig.zoom_by_steps(wheel_steps)


func reset_planning_camera() -> void:
	_end_planning_drag()
	_camera_rig.reset_planning_view()
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_camera_mode(&"planning")


func _activate_planning_camera() -> void:
	if _camera_rig.camera_mode != &"follow":
		return
	_camera_rig.return_to_planning()
	_hud.set_camera_mode(&"planning")


func _begin_planning_drag() -> void:
	_activate_planning_camera()
	_planning_drag_active = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _end_planning_drag() -> void:
	if not _planning_drag_active:
		return
	_planning_drag_active = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _load_course(index: int) -> void:
	var courses := CannonGolfCourseCatalog.all_courses()
	course_index = clampi(index, 0, courses.size() - 1)
	_clear_balls()
	_clear_marks()
	_course_builder.build(courses[course_index])
	_camera_rig.configure(_camera, _course_builder.course)
	launch_state = LaunchState.PLANNING
	last_launch_outcome = &""
	_hud.set_setup(
		_course_builder.launcher.horizontal_aim,
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_camera_mode(&"planning")
	_refresh_hud_availability()
	_hud.hide_clear()
	_hud.focus_fire()


func _clear_balls() -> void:
	for child in _ball_root.get_children():
		_ball_root.remove_child(child)
		child.free()
	current_ball = null
	confirmed_ball = null
	_active_balls.clear()
	_live_shots.clear()


func _clear_marks() -> void:
	_impact_history.clear()


func _on_setup_changed(horizontal: float, elevation: float, power: float) -> void:
	if launch_state == LaunchState.CLEARED:
		return
	_course_builder.launcher.set_setup(horizontal, elevation, power)
	_hud.set_setup(
		_course_builder.launcher.horizontal_aim,
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)


func _adjust_setup(horizontal_delta: float, elevation_delta: float, power_delta: float) -> void:
	if launch_state == LaunchState.CLEARED:
		return
	var launcher := _course_builder.launcher
	launcher.set_setup(
		launcher.horizontal_aim + horizontal_delta,
		launcher.elevation_degrees + elevation_delta,
		launcher.power_percent + power_delta
	)
	_hud.set_setup(launcher.horizontal_aim, launcher.elevation_degrees, launcher.power_percent)


func _on_result_primary_requested() -> void:
	if launch_state != LaunchState.CLEARED:
		return
	if course_index + 1 < CannonGolfCourseCatalog.all_courses().size():
		_load_course(course_index + 1)
	else:
		_load_course(course_index)


func _on_settings_requested() -> void:
	_hud.set_pause_suspended(true)
	navigation_requested.emit(&"settings")


func _request_navigation(destination: StringName) -> void:
	get_tree().paused = false
	_hud.set_pause_visible(false)
	navigation_requested.emit(destination)


func _on_first_surface_contact(
		_ball: CannonGolfBall,
		world_position: Vector3,
		world_normal: Vector3
) -> void:
	_impact_history.stamp(world_position, world_normal)


func _on_ball_launch_ended(ball: CannonGolfBall, reason: StringName) -> void:
	if launch_state != LaunchState.CLEARED:
		_fail_ball(ball, reason)


func _fail_launch(reason: StringName) -> void:
	if current_ball == null or not is_instance_valid(current_ball):
		return
	_fail_ball(current_ball, reason)


func _fail_ball(ball: CannonGolfBall, reason: StringName) -> void:
	var shot := _shot_state(ball)
	if shot == null or shot.ending or launch_state == LaunchState.CLEARED:
		return
	shot.ending = true
	if ball == current_ball:
		launch_state = LaunchState.RECOVERING
	call_deferred("_finish_failed_ball", ball, reason)


func _finish_failed_ball(ball: CannonGolfBall, reason: StringName) -> void:
	if _shot_state(ball) == null:
		return
	last_launch_outcome = reason
	_remove_live_ball(ball)
	if can_fire():
		_hud.focus_fire()


func _confirm_goal(ball: CannonGolfBall = null) -> void:
	var winning_ball := current_ball if ball == null else ball
	if winning_ball == null or _shot_state(winning_ball) == null \
			or launch_state == LaunchState.CLEARED:
		return
	winning_ball.lock_as_confirmed()
	last_launch_outcome = &"confirmed"
	confirmed_ball = winning_ball
	for live_ball in _active_balls.duplicate():
		if live_ball != winning_ball and is_instance_valid(live_ball):
			live_ball.queue_free()
	_active_balls.clear()
	_live_shots.clear()
	current_ball = null
	launch_state = LaunchState.CLEARED
	_camera_rig.return_to_planning()
	_hud.set_camera_mode(&"planning")
	_refresh_hud_availability()
	_hud.show_clear(
		_course_builder.course,
		course_index + 1 < CannonGolfCourseCatalog.all_courses().size()
	)


func _update_camera(delta: float) -> void:
	_camera_rig.update(delta)


func active_ball_count() -> int:
	return _active_balls.size()


func active_balls() -> Array[CannonGolfBall]:
	return _active_balls.duplicate()


func can_fire() -> bool:
	return confirmed_ball == null and _active_balls.size() < MAXIMUM_LIVE_BALLS


func _shot_state(ball: CannonGolfBall) -> CannonGolfLiveShotState:
	if ball == null or not is_instance_valid(ball):
		return null
	return _live_shots.get(ball.get_instance_id()) as CannonGolfLiveShotState


func _remove_live_ball(
		ball: Variant,
		queue_ball: bool = true,
		update_camera: bool = true
) -> void:
	var ball_is_valid: bool = ball != null and is_instance_valid(ball)
	var followed_target: Node3D = _camera_rig.follow_target()
	var was_followed: bool = _camera_rig.camera_mode == &"follow" \
			and (followed_target == ball if followed_target != null else not ball_is_valid)
	if ball_is_valid:
		_live_shots.erase(ball.get_instance_id())
	for index in range(_active_balls.size() - 1, -1, -1):
		var active_ball := _active_balls[index]
		if active_ball == null or not is_instance_valid(active_ball) \
				or (ball_is_valid and active_ball == ball):
			_active_balls.remove_at(index)
	for shot_id in _live_shots.keys():
		var shot := _live_shots[shot_id] as CannonGolfLiveShotState
		if shot == null or shot.ball == null or not is_instance_valid(shot.ball):
			_live_shots.erase(shot_id)
	if queue_ball and ball_is_valid:
		ball.queue_free()
	if current_ball == null or not is_instance_valid(current_ball) \
			or not _active_balls.has(current_ball):
		current_ball = _active_balls.back() if not _active_balls.is_empty() else null
	if update_camera and was_followed:
		_camera_rig.return_to_planning()
		_hud.set_camera_mode(&"planning")
	_refresh_launch_state()
	_refresh_hud_availability()


func _refresh_launch_state() -> void:
	if confirmed_ball != null:
		launch_state = LaunchState.CLEARED
		return
	if current_ball == null or not is_instance_valid(current_ball):
		launch_state = LaunchState.PLANNING
		return
	var shot := _shot_state(current_ball)
	launch_state = LaunchState.SETTLING \
			if shot != null and shot.settle_elapsed > 0.0 \
			else LaunchState.FLYING


func _refresh_hud_availability() -> void:
	_hud.set_launch_availability(
		_active_balls.size(),
		MAXIMUM_LIVE_BALLS,
		confirmed_ball != null
	)


func impact_mark_count() -> int:
	return _impact_history.count()


func active_course() -> CannonGolfCourseData:
	return _course_builder.course
