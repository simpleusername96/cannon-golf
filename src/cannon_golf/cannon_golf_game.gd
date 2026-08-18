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

## Rest uses the physics callback's wall-clock delta. Cannon Golf applies its
## motion multiplier directly to ball parameters rather than to this timer.
const LOW_SPEED_FAILURE_SECONDS := 2.0
const NEARLY_STILL_LINEAR_SPEED := 0.34 * CannonGolfBallistics.MOTION_TIME_SCALE
const NEARLY_STILL_ANGULAR_SPEED := 1.1 * CannonGolfBallistics.MOTION_TIME_SCALE
## Fire stays unrestricted, but the single-threaded Web build must not retain an
## unbounded number of expensive rigid bodies against the course collision mesh.
const MAXIMUM_SIMULATED_BALLS := 4
const PLANNING_DRAG_THRESHOLD_PIXELS := 6.0

@export var initial_course_index := 0
var initial_prepared_course: CannonGolfPreparedCourse
## Set only by the offline physics certifier. It is deliberately not exported.
var initial_certification_candidate := false

@onready var _camera: Camera3D = %Camera
@onready var _sun: DirectionalLight3D = $Sun
@onready var _ground: MeshInstance3D = $OpenGround
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
var completed_goal_indices: Array[int] = []
var selected_launcher_goal_index := -1
## Retained only for offline per-leg certification compatibility.
var active_leg_index := 0
var last_launch_outcome: StringName = &""
var _active_balls: Array[CannonGolfBall] = []
var _live_shots: Dictionary = {}
var _next_ball_id := 1
var _planning_drag_active := false
var _planning_drag_button: MouseButton = MOUSE_BUTTON_NONE
var _planning_drag_committed := false
var _planning_drag_accumulated := Vector2.ZERO


func _ready() -> void:
	_hud.fire_requested.connect(fire)
	_hud.setup_changed.connect(_on_setup_changed)
	_hud.view_requested.connect(set_planning_view)
	_hud.launcher_source_requested.connect(select_launcher_source)
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
	_load_course(initial_course_index, initial_prepared_course)


func _exit_tree() -> void:
	_end_planning_drag()
	get_tree().paused = false


func _process(delta: float) -> void:
	if _planning_drag_active and not Input.is_mouse_button_pressed(_planning_drag_button):
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
	var goal_index := _goal_index_for_ball(ball, shot)
	var goal := _course_builder.goal_at(goal_index)
	if goal != null:
		shot.settlement_goal_index = goal_index
		shot.reset_low_speed()
		if not ball.settlement_drag_is_active() \
				and goal.motion_allows_settlement_drag(
					ball.linear_velocity,
					ball.angular_velocity
				):
			ball.set_settlement_drag(true)
		if goal.motion_is_safe(ball.linear_velocity, ball.angular_velocity):
			shot.settle_elapsed += delta
			if shot.settle_elapsed >= goal.settle_seconds:
				_confirm_goal(ball, goal_index)
		else:
			shot.reset_settlement_dwell()
	else:
		if ball.settlement_drag_is_active():
			ball.set_settlement_drag(false)
		# Rebounding out cancels only the current settlement attempt. The live
		# ball can later re-enter this plate or select another incomplete plate.
		shot.clear_settlement_candidate()
		var nearly_still := ball.has_reported_first_contact() \
				and ball.linear_velocity.length() < NEARLY_STILL_LINEAR_SPEED \
				and ball.angular_velocity.length() < NEARLY_STILL_ANGULAR_SPEED
		if ball.sleeping or nearly_still:
			shot.low_speed_elapsed += delta
			if shot.low_speed_elapsed >= LOW_SPEED_FAILURE_SECONDS:
				_fail_ball(ball, &"stopped_outside")
		else:
			shot.reset_low_speed()


func _goal_index_for_ball(ball: CannonGolfBall, shot: CannonGolfLiveShotState) -> int:
	if ball == null or shot == null:
		return -1
	if shot.settlement_goal_index >= 0 \
			and not completed_goal_indices.has(shot.settlement_goal_index):
		var candidate_goal := _course_builder.goal_at(shot.settlement_goal_index)
		return shot.settlement_goal_index if candidate_goal != null \
				and candidate_goal.contains_rebound_column(
					ball.global_position, CannonGolfBall.RADIUS
				) else -1
	for goal_index in range(_course_builder.goals.size()):
		if completed_goal_indices.has(goal_index):
			continue
		var candidate := _course_builder.goal_at(goal_index)
		if candidate != null and candidate.contains_ball(
			ball.global_position, CannonGolfBall.RADIUS
		):
			return goal_index
	return -1


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
		if mouse_button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if mouse_button.pressed:
				_begin_planning_drag(mouse_button.button_index)
				get_viewport().set_input_as_handled()
			elif _planning_drag_active and mouse_button.button_index == _planning_drag_button:
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
		var drag_relative := _committed_planning_drag_relative(mouse_motion.relative)
		if drag_relative.is_zero_approx():
			get_viewport().set_input_as_handled()
			return
		if _planning_drag_button == MOUSE_BUTTON_LEFT \
				and mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			orbit_planning(drag_relative)
		elif _planning_drag_button == MOUSE_BUTTON_RIGHT \
				and mouse_motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			pan_planning_drag(mouse_motion.position, drag_relative)
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
			set_planning_view(&"cannon")
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


func fire() -> bool:
	if launch_state == LaunchState.CLEARED:
		return false
	if _active_balls.size() >= MAXIMUM_SIMULATED_BALLS:
		_remove_live_ball(_active_balls.front())
	var ball := CannonGolfBall.new()
	ball.name = "ActiveGolfBall%04d" % _next_ball_id
	_next_ball_id += 1
	ball.configure(
		_course_builder.course.play_bounds,
		_course_builder.launcher.launch_origin(),
		_course_builder.launcher.launch_velocity()
	)
	ball.first_surface_contact.connect(_on_first_surface_contact)
	ball.launch_ended.connect(_on_ball_launch_ended)
	_ball_root.add_child(ball)
	_active_balls.append(ball)
	_live_shots[ball.get_instance_id()] = CannonGolfLiveShotState.new(
		ball,
		selected_launcher_goal_index,
		Vector3(
			_course_builder.launcher.horizontal_aim,
			_course_builder.launcher.elevation_degrees,
			_course_builder.launcher.power_percent
		)
	)
	current_ball = ball
	_camera_rig.follow(ball)
	_course_builder.launcher.set_cannon_view_active(false)
	_hud.set_camera_mode(&"follow")
	launch_state = LaunchState.FLYING
	last_launch_outcome = &""
	_refresh_hud_availability()
	_hud.hide_clear()
	return true


func reset_course() -> void:
	_end_planning_drag()
	get_tree().paused = false
	_hud.set_pause_visible(false)
	_load_course(course_index)


func retry_attempt() -> bool:
	if launch_state == LaunchState.CLEARED \
			or current_ball == null or not is_instance_valid(current_ball):
		return false
	var retry_ball := current_ball
	var retry_shot := _shot_state(retry_ball)
	if retry_shot == null:
		return false
	var retry_source := retry_shot.launcher_source_goal_index
	var retry_setup := retry_shot.launch_setup
	_remove_live_ball(retry_ball, true, false)
	if not _select_launcher_source(retry_source):
		return false
	_course_builder.launcher.set_setup(retry_setup.x, retry_setup.y, retry_setup.z)
	_hud.set_setup(retry_setup.x, retry_setup.y, retry_setup.z)
	last_launch_outcome = &""
	get_tree().paused = false
	_hud.set_pause_visible(false)
	return fire()


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
	_course_builder.launcher.set_cannon_view_active(view_mode == &"cannon")
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_camera_mode(&"planning")


func toggle_shot_camera() -> bool:
	if _camera_rig.camera_mode == &"follow":
		_camera_rig.return_to_planning()
		_course_builder.launcher.set_cannon_view_active(_camera_rig.view_mode == &"cannon")
		_hud.set_camera_mode(&"planning")
		return true
	if current_ball == null or not is_instance_valid(current_ball):
		return false
	_camera_rig.follow(current_ball)
	_course_builder.launcher.set_cannon_view_active(false)
	_hud.set_camera_mode(&"follow")
	return true


func return_to_planning_view() -> bool:
	if _camera_rig.camera_mode != &"follow":
		return false
	_camera_rig.return_to_planning(true)
	_course_builder.launcher.set_cannon_view_active(_camera_rig.view_mode == &"cannon")
	_hud.set_camera_mode(&"planning")
	return true


func pan_planning(screen_direction: Vector2) -> void:
	_activate_planning_camera()
	_camera_rig.pan(screen_direction)
	_snap_direct_planning_input()


func pan_planning_drag(screen_position: Vector2, relative: Vector2) -> bool:
	_activate_planning_camera()
	var changed := _camera_rig.pan_drag(screen_position, relative)
	if changed:
		_snap_direct_planning_input()
	return changed


func orbit_planning(relative: Vector2) -> bool:
	_activate_planning_camera()
	var changed := _camera_rig.orbit(relative)
	if changed:
		_snap_direct_planning_input()
	return changed


func zoom_planning(wheel_steps: float) -> bool:
	_activate_planning_camera()
	var changed := _camera_rig.zoom_by_steps(wheel_steps)
	if changed:
		_snap_direct_planning_input()
	return changed


func _snap_direct_planning_input() -> void:
	if _camera_rig.camera_mode == &"planning":
		_camera_rig.snap_to_planning()


func reset_planning_camera() -> void:
	_end_planning_drag()
	_camera_rig.reset_planning_view()
	_course_builder.launcher.set_cannon_view_active(_camera_rig.view_mode == &"cannon")
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_camera_mode(&"planning")


func _activate_planning_camera() -> void:
	if _camera_rig.camera_mode != &"follow":
		return
	_camera_rig.return_to_planning()
	_course_builder.launcher.set_cannon_view_active(_camera_rig.view_mode == &"cannon")
	_hud.set_camera_mode(&"planning")


func _begin_planning_drag(button: MouseButton) -> void:
	_planning_drag_active = true
	_planning_drag_button = button
	_planning_drag_committed = false
	_planning_drag_accumulated = Vector2.ZERO


func _end_planning_drag() -> void:
	if not _planning_drag_active:
		return
	_planning_drag_active = false
	_planning_drag_button = MOUSE_BUTTON_NONE
	_planning_drag_committed = false
	_planning_drag_accumulated = Vector2.ZERO
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _committed_planning_drag_relative(relative: Vector2) -> Vector2:
	if _planning_drag_committed:
		return relative
	_planning_drag_accumulated += relative
	if _planning_drag_accumulated.length() < PLANNING_DRAG_THRESHOLD_PIXELS:
		return Vector2.ZERO
	_planning_drag_committed = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	var committed_relative := _planning_drag_accumulated
	_planning_drag_accumulated = Vector2.ZERO
	return committed_relative


func _load_course(index: int, prepared: CannonGolfPreparedCourse = null) -> void:
	var courses := CannonGolfCourseCatalog.all_courses()
	course_index = clampi(index, 0, courses.size() - 1)
	_clear_balls()
	_clear_marks()
	var built := _course_builder.build_certification_candidate(
		courses[course_index], prepared
	) if initial_certification_candidate else _course_builder.build(
		courses[course_index], prepared
	)
	if not built:
		push_error("Cannon Golf could not build the selected course.")
		return
	active_leg_index = 0
	selected_launcher_goal_index = -1
	completed_goal_indices.clear()
	_course_builder.set_all_goals_available()
	_apply_world_envelope()
	_camera_rig.configure(
		_camera,
		_course_builder.course,
		_course_builder.prepared_course.local_bounds,
		Callable(_course_builder, "height_at_local"),
		_course_builder.presentation_bounds(),
		_course_builder.camera_collision_exclusions()
	)
	if _course_builder.prepared_course != null:
		_set_camera_context_for_launcher()
	launch_state = LaunchState.PLANNING
	last_launch_outcome = &""
	_hud.set_setup(
		_course_builder.launcher.horizontal_aim,
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_camera_mode(&"planning")
	_hud.set_level(course_index)
	_hud.set_goal_progress(completed_goal_indices.size(), _course_builder.leg_count())
	_sync_launcher_sources()
	_refresh_hud_availability()
	_hud.hide_clear()
	_hud.focus_fire()


## Starts one independently certified relay leg on the exact candidate terrain.
## Earlier legs are not replayed because every leg receives its own certificate.
func configure_certification_leg(index: int) -> bool:
	if not initial_certification_candidate or not _active_balls.is_empty() \
			or index < 0 or index >= _course_builder.leg_count():
		return false
	active_leg_index = index
	if not _course_builder.activate_leg(index):
		return false
	launch_state = LaunchState.PLANNING
	last_launch_outcome = &""
	_set_camera_context_for_leg(index)
	_hud.set_setup(
		_course_builder.launcher.horizontal_aim,
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)
	_hud.set_goal_progress(index, _course_builder.leg_count())
	_refresh_hud_availability()
	return true


func _clear_balls() -> void:
	for child in _ball_root.get_children():
		_ball_root.remove_child(child)
		child.free()
	current_ball = null
	completed_goal_indices.clear()
	_active_balls.clear()
	_live_shots.clear()
	_next_ball_id = 1


func _clear_marks() -> void:
	_impact_history.clear()


func _apply_world_envelope() -> void:
	var envelope := CannonGolfCourseWorldEnvelope.resolve(_course_builder.presentation_bounds())
	var center: Vector3 = envelope.ground_center
	var scale_factor := float(envelope.ground_scale)
	_ground.position = center
	_ground.scale = Vector3(scale_factor, 1.0, scale_factor)
	_camera.far = float(envelope.far_distance)
	_sun.directional_shadow_max_distance = float(envelope.far_distance)


func _on_setup_changed(horizontal: float, elevation: float, power: float) -> void:
	if launch_state == LaunchState.CLEARED:
		return
	_course_builder.launcher.set_setup(horizontal, elevation, power)
	_hud.set_setup(
		_course_builder.launcher.horizontal_aim,
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)


func _sync_cannon_camera_pose() -> void:
	var launcher := _course_builder.launcher
	if launcher == null:
		return
	_camera_rig.set_cannon_pose(
		launcher.cannon_perspective_anchor(),
		launcher.launch_direction(),
		launcher.yaw_degrees
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
	if launch_state == LaunchState.CLEARED:
		return
	_fail_ball(ball, reason)


func _fail_launch(reason: StringName) -> void:
	if current_ball == null or not is_instance_valid(current_ball):
		return
	_fail_ball(current_ball, reason)


func _fail_ball(ball: CannonGolfBall, reason: StringName) -> void:
	var shot := _shot_state(ball)
	if shot == null or shot.ending or launch_state == LaunchState.CLEARED:
		return
	ball.set_settlement_drag(false)
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


func _confirm_goal(ball: CannonGolfBall = null, goal_index: int = -1) -> void:
	var winning_ball := current_ball if ball == null else ball
	if winning_ball == null or _shot_state(winning_ball) == null \
			or launch_state == LaunchState.CLEARED:
		return
	var winning_shot := _shot_state(winning_ball)
	if goal_index < 0:
		goal_index = _goal_index_for_ball(winning_ball, winning_shot)
	if goal_index < 0 or completed_goal_indices.has(goal_index):
		return
	last_launch_outcome = &"confirmed"
	completed_goal_indices.append(goal_index)
	completed_goal_indices.sort()
	_course_builder.set_goal_completed(goal_index, true)
	_hud.set_goal_progress(completed_goal_indices.size(), _course_builder.leg_count())
	# Completion is goal-index state. Release the resolved ball after bookkeeping;
	# its first-contact mark remains owned independently by ImpactHistory.
	_remove_live_ball(winning_ball, true, false)
	# Restore the exact planning snapshot instead of flying toward the basin.
	_camera_rig.return_to_planning(true)
	_course_builder.launcher.set_cannon_view_active(
		_camera_rig.view_mode == &"cannon"
	)
	_hud.set_view(_camera_rig.view_mode)
	_hud.set_camera_mode(&"planning")
	if completed_goal_indices.size() < _course_builder.leg_count():
		_refresh_launch_state()
		_hud.hide_clear()
		_sync_launcher_sources()
		_refresh_hud_availability()
		_hud.focus_fire()
		return
	for live_ball in _active_balls:
		if live_ball != null and is_instance_valid(live_ball):
			live_ball.queue_free()
	_active_balls.clear()
	_live_shots.clear()
	current_ball = null
	launch_state = LaunchState.CLEARED
	_refresh_hud_availability()
	_hud.show_clear(
		_course_builder.course,
		course_index + 1 < CannonGolfCourseCatalog.all_courses().size()
	)


func _set_camera_context_for_leg(index: int) -> bool:
	if _course_builder.prepared_course == null or index < 0 \
			or index >= _course_builder.prepared_course.legs.size():
		return false
	return _camera_rig.set_planning_context(
		_course_builder.frame_bounds_for_leg(index),
		_course_builder.course.planning_focus,
		_course_builder.launcher.cannon_perspective_anchor(),
		_course_builder.launcher.launch_direction(),
		_course_builder.launcher.yaw_degrees
	)


func _set_camera_context_for_launcher() -> bool:
	return _camera_rig.set_planning_context(
		_course_builder.presentation_bounds(),
		_course_builder.course.content_bounds.get_center(),
		_course_builder.launcher.cannon_perspective_anchor(),
		_course_builder.launcher.launch_direction(),
		_course_builder.launcher.yaw_degrees
	)


func select_launcher_source(goal_index: int) -> bool:
	return _select_launcher_source(goal_index)


func _select_launcher_source(goal_index: int) -> bool:
	if launch_state == LaunchState.CLEARED or goal_index < -1 \
			or (goal_index >= 0 and not completed_goal_indices.has(goal_index)):
		return false
	var source_changed := selected_launcher_goal_index != goal_index
	if not _course_builder.select_launcher_source(goal_index):
		return false
	selected_launcher_goal_index = goal_index
	# Re-selecting the active source is part of quick retry, not a camera-preset
	# selection. Preserve the single planning-navigation state in that path.
	if source_changed:
		_sync_cannon_camera_pose()
	_course_builder.launcher.set_cannon_view_active(_camera_rig.view_mode == &"cannon")
	_hud.set_setup(
		_course_builder.launcher.horizontal_aim,
		_course_builder.launcher.elevation_degrees,
		_course_builder.launcher.power_percent
	)
	_sync_launcher_sources()
	return true


func _sync_launcher_sources() -> void:
	_hud.set_launcher_sources(completed_goal_indices, selected_launcher_goal_index)


func _update_camera(delta: float) -> void:
	_camera_rig.update(delta)


func active_ball_count() -> int:
	return _active_balls.size()


func active_balls() -> Array[CannonGolfBall]:
	return _active_balls.duplicate()


func can_fire() -> bool:
	return launch_state != LaunchState.CLEARED


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
		(ball as CannonGolfBall).set_settlement_drag(false)
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
	if launch_state == LaunchState.CLEARED:
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
		launch_state == LaunchState.CLEARED
	)


func impact_mark_count() -> int:
	return _impact_history.count()


func active_course() -> CannonGolfCourseData:
	return _course_builder.course


func completed_goal_count() -> int:
	return completed_goal_indices.size()
