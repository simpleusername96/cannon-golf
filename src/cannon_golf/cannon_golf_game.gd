class_name CannonGolfGame
extends Node3D

enum LaunchState {
	PLANNING,
	FLYING,
	SETTLING,
	RECOVERING,
	CLEARED,
}

const LOW_SPEED_FAILURE_SECONDS := 1.25

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
var _settle_elapsed := 0.0
var _low_speed_elapsed := 0.0
var _entered_goal := false
var _failure_pending := false


func _ready() -> void:
	_hud.fire_requested.connect(fire)
	_hud.setup_changed.connect(_on_setup_changed)
	_hud.course_step_requested.connect(_on_course_step_requested)
	_hud.view_requested.connect(set_planning_view)
	_hud.reset_requested.connect(reset_course)
	_hud.result_primary_requested.connect(_on_result_primary_requested)
	_load_course(0)


func _process(delta: float) -> void:
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	if current_ball == null or not is_instance_valid(current_ball) \
			or launch_state == LaunchState.RECOVERING \
			or launch_state == LaunchState.CLEARED:
		return
	var goal := _course_builder.goal
	var inside := goal.contains_rebound_column(
		current_ball.global_position,
		CannonGolfBall.RADIUS
	) if _entered_goal else goal.contains_ball(
		current_ball.global_position,
		CannonGolfBall.RADIUS
	)
	if inside:
		_entered_goal = true
		_low_speed_elapsed = 0.0
		if goal.motion_is_safe(current_ball.linear_velocity, current_ball.angular_velocity):
			launch_state = LaunchState.SETTLING
			_settle_elapsed += delta
			_hud.set_feedback("골 안에서 안전 착지를 확인하는 중...", true)
			if _settle_elapsed >= goal.settle_seconds:
				_confirm_goal()
		else:
			launch_state = LaunchState.FLYING
			_settle_elapsed = 0.0
	elif _entered_goal:
		_fail_launch(&"bounced_out")
	else:
		_settle_elapsed = 0.0
		var nearly_still := current_ball.has_reported_first_contact() \
				and current_ball.linear_velocity.length() < 0.34 \
				and current_ball.angular_velocity.length() < 1.1
		if current_ball.sleeping or nearly_still:
			_low_speed_elapsed += delta
			if _low_speed_elapsed >= LOW_SPEED_FAILURE_SECONDS:
				_fail_launch(&"stopped_outside")
		else:
			_low_speed_elapsed = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_rig.adjust_zoom(-0.08)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_rig.adjust_zoom(0.08)
			get_viewport().set_input_as_handled()
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			fire()
		KEY_1:
			set_planning_view(&"oblique")
		KEY_2:
			set_planning_view(&"side")
		KEY_R:
			reset_course()
		KEY_W:
			_adjust_setup(1.0, 0.0)
		KEY_S:
			_adjust_setup(-1.0, 0.0)
		KEY_D:
			_adjust_setup(0.0, 1.0)
		KEY_A:
			_adjust_setup(0.0, -1.0)
		KEY_LEFT:
			pan_planning(Vector2(-1.0, 0.0))
		KEY_RIGHT:
			pan_planning(Vector2(1.0, 0.0))
		KEY_UP:
			pan_planning(Vector2(0.0, 1.0))
		KEY_DOWN:
			pan_planning(Vector2(0.0, -1.0))


func fire() -> bool:
	if launch_state != LaunchState.PLANNING or current_ball != null \
			or confirmed_ball != null:
		return false
	current_ball = CannonGolfBall.new()
	current_ball.name = "ActiveGolfBall"
	current_ball.configure(
		_course_builder.course.play_bounds,
		_course_builder.launcher.launch_origin(),
		_course_builder.launcher.launch_velocity()
	)
	current_ball.first_surface_contact.connect(_on_first_surface_contact)
	current_ball.launch_ended.connect(_on_ball_launch_ended)
	_ball_root.add_child(current_ball)
	launch_state = LaunchState.FLYING
	_settle_elapsed = 0.0
	_low_speed_elapsed = 0.0
	_entered_goal = false
	_failure_pending = false
	last_launch_outcome = &""
	_hud.set_busy(true)
	_hud.hide_clear()
	_hud.set_feedback("공을 따라가는 중...", true)
	return true


func reset_course() -> void:
	_load_course(course_index)


func set_planning_view(view_mode: StringName) -> void:
	if not _camera_rig.set_view(view_mode):
		return
	_hud.set_view(_camera_rig.view_mode)
	if launch_state == LaunchState.PLANNING or launch_state == LaunchState.CLEARED:
		_camera_rig.snap_to_planning()


func pan_planning(screen_direction: Vector2) -> void:
	_camera_rig.pan(screen_direction)


func _load_course(index: int) -> void:
	var courses := CannonGolfCourseCatalog.all_courses()
	course_index = clampi(index, 0, courses.size() - 1)
	_clear_balls()
	_clear_marks()
	_course_builder.build(courses[course_index])
	_camera_rig.configure(_camera, _course_builder.course)
	launch_state = LaunchState.PLANNING
	_settle_elapsed = 0.0
	_low_speed_elapsed = 0.0
	_entered_goal = false
	_failure_pending = false
	last_launch_outcome = &""
	_hud.set_course(_course_builder.course, course_index, courses.size())
	_hud.set_setup(
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_busy(false)
	_hud.hide_clear()
	_hud.set_feedback("각도와 파워를 조절한 뒤 발사하세요.")
	_hud.focus_fire()


func _clear_balls() -> void:
	for child in _ball_root.get_children():
		_ball_root.remove_child(child)
		child.free()
	current_ball = null
	confirmed_ball = null


func _clear_marks() -> void:
	_impact_history.clear()


func _on_setup_changed(elevation: float, power: float) -> void:
	if launch_state != LaunchState.PLANNING:
		return
	_course_builder.launcher.set_setup(elevation, power)
	_hud.set_setup(
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)


func _adjust_setup(elevation_delta: float, power_delta: float) -> void:
	if launch_state != LaunchState.PLANNING:
		return
	var launcher := _course_builder.launcher
	launcher.set_setup(
		launcher.elevation_degrees + elevation_delta,
		launcher.power_percent + power_delta
	)
	_hud.set_setup(launcher.elevation_degrees, launcher.power_percent)


func _on_course_step_requested(step: int) -> void:
	if launch_state == LaunchState.FLYING or launch_state == LaunchState.SETTLING:
		return
	_load_course(course_index + step)


func _on_result_primary_requested() -> void:
	if launch_state != LaunchState.CLEARED:
		return
	if course_index + 1 < CannonGolfCourseCatalog.all_courses().size():
		_load_course(course_index + 1)
	else:
		_load_course(course_index)


func _on_first_surface_contact(
		_ball: CannonGolfBall,
		world_position: Vector3,
		world_normal: Vector3
) -> void:
	_impact_history.stamp(world_position, world_normal)


func _on_ball_launch_ended(ball: CannonGolfBall, reason: StringName) -> void:
	if ball == current_ball and launch_state != LaunchState.CLEARED:
		_fail_launch(reason)


func _fail_launch(reason: StringName) -> void:
	if _failure_pending or launch_state == LaunchState.CLEARED:
		return
	_failure_pending = true
	launch_state = LaunchState.RECOVERING
	call_deferred("_finish_failed_launch", reason)


func _finish_failed_launch(reason: StringName) -> void:
	last_launch_outcome = reason
	if current_ball != null and is_instance_valid(current_ball):
		current_ball.queue_free()
	current_ball = null
	launch_state = LaunchState.PLANNING
	_failure_pending = false
	var message := "골에서 튕겨 나왔습니다. 다시 조정해 보세요."
	if reason == &"stopped_outside":
		message = "골 밖에 멈췄습니다. 다시 조정해 보세요."
	elif reason == &"out_of_bounds":
		message = "코스 밖으로 나갔습니다. 다시 조정해 보세요."
	elif reason == &"timeout":
		message = "공이 안정되지 않았습니다. 다시 조정해 보세요."
	_hud.set_busy(false)
	_hud.set_feedback(message)
	_hud.focus_fire()


func _confirm_goal() -> void:
	if current_ball == null or launch_state == LaunchState.CLEARED:
		return
	current_ball.lock_as_confirmed()
	last_launch_outcome = &"confirmed"
	confirmed_ball = current_ball
	current_ball = null
	launch_state = LaunchState.CLEARED
	_hud.set_busy(true)
	_hud.set_goal_complete(true)
	_hud.set_feedback("안전 착지 완료", true)
	_hud.show_clear(
		_course_builder.course,
		course_index + 1 < CannonGolfCourseCatalog.all_courses().size()
	)


func _update_camera(delta: float) -> void:
	if current_ball != null and is_instance_valid(current_ball) \
			and (launch_state == LaunchState.FLYING or launch_state == LaunchState.SETTLING):
		_camera_rig.update(delta, current_ball)
	else:
		_camera_rig.update(delta)


func impact_mark_count() -> int:
	return _impact_history.count()


func active_course() -> CannonGolfCourseData:
	return _course_builder.course
