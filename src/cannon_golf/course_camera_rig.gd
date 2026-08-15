class_name CannonGolfCourseCameraRig
extends Node

const OverviewSolver := preload("res://src/cannon_golf/overview_camera_solver.gd")

const MODE_PLANNING: StringName = &"planning"
const MODE_FOLLOW: StringName = &"follow"
const DEFAULT_ZOOM := 0.0
const CLOSE_ZOOM := 10.0
const OVERVIEW_ZOOM := -6.0
const CLOSE_INSPECTION_DISTANCE := 28.0
const CLOSE_FOCUS_SURFACE_WEIGHT := 0.55
const CAMERA_TERRAIN_CLEARANCE := 1.25
const FOLLOW_DISTANCE := 18.0
const FOLLOW_HEIGHT := 8.0
const ORBIT_DEGREES_PER_PIXEL := Vector2(0.075, 0.06)
const PAN_RESPONSE := 0.30
const MAXIMUM_PAN_EVENT_SPAN_RATIO := 0.02
const ARROW_PAN_SPAN_RATIO := 0.01
const CANNON_FIELD_OF_VIEW := 70.0

var view_mode: StringName = &"oblique"
var camera_mode: StringName = MODE_PLANNING
var pan_offset := Vector3.ZERO
var zoom := DEFAULT_ZOOM
var orbit_degrees := Vector2.ZERO

var _camera: Camera3D
var _course: CannonGolfCourseData
var _follow_target: Node3D
var _frame_bounds := AABB()
var _exploration_bounds := AABB()
var _base_focus := Vector3.ZERO
var _terrain_bounds := Rect2()
var _height_sampler := Callable()
var _collision_exclusions: Array[RID] = []
var _cannon_eye := Vector3.ZERO
var _cannon_direction := Vector3.FORWARD
var _planning_position := Vector3.ZERO
var _planning_focus := Vector3.ZERO
var _rendered_focus := Vector3.ZERO
var _last_valid_position := Vector3.ZERO
var _pose_dirty := true
var _pose_builds := 0
var _viewport_size := Vector2.ZERO
var _default_fov := 48.0
var _return_snapshot := {}
var _follow_direction := Vector3.FORWARD


func configure(
		camera: Camera3D,
		course: CannonGolfCourseData,
		terrain_bounds: Rect2 = Rect2(),
		height_sampler: Callable = Callable(),
		presentation_bounds: AABB = AABB(),
		collision_exclusions: Array[RID] = []
) -> void:
	assert(camera != null and course != null and course.is_valid())
	_camera = camera
	_default_fov = camera.fov
	_course = course
	_frame_bounds = presentation_bounds if presentation_bounds.has_volume() else course.content_bounds
	_exploration_bounds = course.content_bounds
	_base_focus = course.planning_focus
	_terrain_bounds = terrain_bounds
	_height_sampler = height_sampler
	_collision_exclusions = collision_exclusions.duplicate()
	_cannon_eye = course.cannon_position + Vector3.UP * 2.55
	_cannon_direction = _yaw_forward(course.shot_axis_yaw_degrees)
	view_mode = &"oblique"
	camera_mode = MODE_PLANNING
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_follow_target = null
	_return_snapshot.clear()
	_rendered_focus = _base_focus
	_last_valid_position = camera.global_position
	_pose_dirty = true
	_pose_builds = 0
	_apply_fov()
	snap_to_planning()


func set_view(next_view: StringName) -> bool:
	if next_view != &"oblique" and next_view != &"cannon":
		return false
	if camera_mode == MODE_FOLLOW:
		_restore_snapshot()
		_follow_target = null
		camera_mode = MODE_PLANNING
	view_mode = next_view
	_apply_fov()
	_pose_dirty = true
	if next_view == &"cannon":
		snap_to_planning()
	return true


func set_planning_context(
		frame_bounds: AABB,
		focus: Vector3,
		cannon_eye: Vector3,
		cannon_direction: Vector3
) -> bool:
	if not frame_bounds.has_volume() or not focus.is_finite() or not cannon_eye.is_finite() \
			or not cannon_direction.is_finite() or cannon_direction.is_zero_approx():
		return false
	_frame_bounds = frame_bounds
	_base_focus = focus
	_cannon_eye = cannon_eye
	_cannon_direction = cannon_direction.normalized()
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_pose_dirty = true
	return_to_planning(true)
	return true


func set_cannon_pose(eye: Vector3, direction: Vector3) -> bool:
	if not eye.is_finite() or not direction.is_finite() or direction.is_zero_approx():
		return false
	_cannon_eye = eye
	_cannon_direction = direction.normalized()
	_pose_dirty = true
	return true


func set_cannon_yaw(world_yaw_degrees: float) -> bool:
	return set_cannon_pose(_cannon_eye, _yaw_forward(world_yaw_degrees))


func pan(screen_direction: Vector2) -> void:
	if _course == null:
		return
	var span := maxf(_course.content_bounds.size.x, _course.content_bounds.size.z)
	var scale := maxf(span * ARROW_PAN_SPAN_RATIO, 1.0) * pow(0.9, zoom)
	pan_offset += Vector3(screen_direction.x * scale, 0.0, -screen_direction.y * scale)
	_clamp_pan()
	_pose_dirty = true


func pan_drag(_screen_position: Vector2, relative: Vector2) -> bool:
	if _camera == null or relative.is_zero_approx():
		return false
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if _pose_dirty or not viewport_size.is_equal_approx(_viewport_size):
		_resolve_pose(viewport_size)
	var viewport_height := maxf(viewport_size.y, 1.0)
	# Use the requested boom, not the still-interpolating rendered camera. A drag
	# immediately after zoom must have close-view sensitivity, not stale overview sensitivity.
	var distance := maxf(_planning_position.distance_to(_planning_focus), 1.0)
	var units_per_pixel := 2.0 * distance * tan(deg_to_rad(_camera.fov) * 0.5) / viewport_height
	var right := _camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var delta := (-right * relative.x + forward * relative.y) * units_per_pixel * PAN_RESPONSE
	delta = delta.limit_length(maxf(_course.content_bounds.size.x, _course.content_bounds.size.z) * MAXIMUM_PAN_EVENT_SPAN_RATIO)
	if not delta.is_finite() or delta.is_zero_approx():
		return false
	pan_offset += delta
	_clamp_pan()
	_pose_dirty = true
	return true


func orbit(relative: Vector2) -> bool:
	if relative.is_zero_approx():
		return false
	orbit_degrees.x = wrapf(orbit_degrees.x - relative.x * ORBIT_DEGREES_PER_PIXEL.x, -180.0, 180.0)
	orbit_degrees.y = clampf(orbit_degrees.y + relative.y * ORBIT_DEGREES_PER_PIXEL.y, -30.0, 30.0)
	_pose_dirty = true
	return true


func zoom_by_steps(steps: float) -> bool:
	var next := clampf(zoom + steps, OVERVIEW_ZOOM, CLOSE_ZOOM)
	if is_equal_approx(next, zoom):
		return false
	zoom = next
	_pose_dirty = true
	return true


func reset_planning_view() -> void:
	view_mode = &"oblique"
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_pose_dirty = true
	return_to_planning(true)


func follow(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if camera_mode != MODE_FOLLOW:
		_return_snapshot = {"view": view_mode, "pan": pan_offset, "zoom": zoom, "orbit": orbit_degrees}
	_follow_target = target
	_follow_direction = _target_horizontal_direction(target, _cannon_direction)
	camera_mode = MODE_FOLLOW
	_camera.fov = _default_fov
	return true


func follow_confirmed(target: Node3D) -> bool:
	return follow(target)


func return_to_planning(immediate: bool = false) -> void:
	if camera_mode == MODE_FOLLOW:
		_restore_snapshot()
	_follow_target = null
	camera_mode = MODE_PLANNING
	_apply_fov()
	_pose_dirty = true
	if immediate:
		snap_to_planning()


func is_following(target: Node3D = null) -> bool:
	return camera_mode == MODE_FOLLOW and is_instance_valid(_follow_target) \
			and (target == null or target == _follow_target)


func follow_target() -> Node3D:
	return _follow_target if is_following() else null


func planning_focus() -> Vector3:
	var focus := _base_focus + pan_offset
	var height := _terrain_height(focus)
	if not is_finite(height):
		return focus
	var surface_focus_y := height + 2.0
	var overview_focus_y := maxf(focus.y, surface_focus_y)
	focus.y = lerpf(
		overview_focus_y,
		surface_focus_y,
		clampf(zoom / CLOSE_ZOOM, 0.0, 1.0) * CLOSE_FOCUS_SURFACE_WEIGHT
	)
	return _terrain_safe_position(focus)


func resolved_planning_distance() -> float:
	return _planning_position.distance_to(_planning_focus)


func planning_pose_build_count() -> int:
	return _pose_builds


func terrain_footprint_offsets() -> Array[Vector2]:
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		offsets.append(Vector2(sin(angle), cos(angle)) * OverviewSolver.BOOM_RADIUS)
	return offsets


func update(delta: float) -> void:
	if _camera == null or _course == null:
		return
	if camera_mode == MODE_FOLLOW:
		if not is_instance_valid(_follow_target) or not _follow_target.is_inside_tree():
			return_to_planning()
		else:
			_apply_follow(delta)
			return
	_apply_planning(delta)


func snap_to_planning() -> void:
	camera_mode = MODE_PLANNING
	_follow_target = null
	_apply_planning(1.0)


func _apply_planning(delta: float) -> void:
	var size := _camera.get_viewport().get_visible_rect().size
	if not size.is_equal_approx(_viewport_size):
		_pose_dirty = true
	if _pose_dirty:
		_resolve_pose(size)
	var weight := 1.0 if delta >= 0.999 else 1.0 - exp(-delta * 5.5)
	var candidate := _camera.global_position.lerp(_planning_position, weight)
	if view_mode == &"oblique":
		var next_focus := _rendered_focus.lerp(_planning_focus, weight)
		var boom_origin := _terrain_safe_position(next_focus)
		candidate = OverviewSolver.sweep_boom(
			_camera, boom_origin, candidate, _collision_exclusions, _last_valid_position
		)
		candidate = _validated_camera_position(candidate, _last_valid_position, boom_origin)
		_rendered_focus = boom_origin
	else:
		_rendered_focus = candidate + _cannon_direction * 20.0
	_last_valid_position = candidate
	_camera.global_position = candidate
	_camera.look_at(_rendered_focus, Vector3.UP)


func _resolve_pose(size: Vector2) -> void:
	if view_mode == &"cannon":
		_planning_position = _cannon_eye
		_planning_focus = _cannon_eye + _cannon_direction * 20.0
	else:
		_planning_focus = planning_focus()
		var pose := OverviewSolver.resolve_pose(
			_camera, _frame_bounds, _planning_focus, _terrain_safe_focus(_base_focus),
			_course.oblique_offset, orbit_degrees, zoom
		)
		_planning_position = pose[0]
		_planning_focus = pose[1]
	_viewport_size = size
	_pose_dirty = false
	_pose_builds += 1


func _apply_follow(delta: float) -> void:
	var focus := _follow_target.get_global_transform_interpolated().origin
	_follow_direction = _target_horizontal_direction(_follow_target, _follow_direction)
	var desired := focus - _follow_direction * FOLLOW_DISTANCE + Vector3.UP * FOLLOW_HEIGHT
	var weight := 1.0 - exp(-delta * 4.2)
	var next_focus := _rendered_focus.lerp(focus + Vector3.UP * 0.4, weight)
	var candidate := _camera.global_position.lerp(desired, weight)
	var boom_origin := _terrain_safe_position(focus + Vector3.UP * 2.0)
	candidate = OverviewSolver.sweep_boom(
		_camera, boom_origin, candidate,
		_collision_exclusions, _last_valid_position
	)
	candidate = _validated_camera_position(
		candidate, _last_valid_position, boom_origin
	)
	_last_valid_position = candidate
	_rendered_focus = next_focus
	_camera.global_position = candidate
	_camera.look_at(_rendered_focus, Vector3.UP)


func _restore_snapshot() -> void:
	if _return_snapshot.is_empty():
		return
	view_mode = _return_snapshot.get("view", &"oblique")
	pan_offset = _return_snapshot.get("pan", Vector3.ZERO)
	zoom = _return_snapshot.get("zoom", DEFAULT_ZOOM)
	orbit_degrees = _return_snapshot.get("orbit", Vector2.ZERO)
	_return_snapshot.clear()


func _clamp_pan() -> void:
	var focus := _base_focus + pan_offset
	focus.x = clampf(focus.x, _exploration_bounds.position.x, _exploration_bounds.end.x)
	focus.z = clampf(focus.z, _exploration_bounds.position.z, _exploration_bounds.end.z)
	pan_offset = focus - _base_focus


func _terrain_safe_focus(focus: Vector3) -> Vector3:
	var height := _terrain_height(focus)
	if is_finite(height):
		focus.y = maxf(focus.y, height + 2.0)
	return _terrain_safe_position(focus)


## Raises only enough to keep the existing boom-radius footprint above the
## connected heightfield. This is the fail-closed pivot for a blocked sweep.
func _terrain_safe_position(position: Vector3) -> Vector3:
	if not position.is_finite():
		return position
	for offset in terrain_footprint_offsets():
		var sample_position := position + Vector3(offset.x, 0.0, offset.y)
		var height := _terrain_height(sample_position)
		if is_finite(height):
			position.y = maxf(position.y, height + CAMERA_TERRAIN_CLEARANCE)
	return position


func _terrain_height(position: Vector3) -> float:
	if not _height_sampler.is_valid() or not _terrain_bounds.has_area() \
			or not _terrain_bounds.has_point(Vector2(position.x, position.z)):
		return -INF
	var sampled: Variant = _height_sampler.call(position.x, position.z)
	return float(sampled) if (sampled is float or sampled is int) and is_finite(float(sampled)) else -INF


func _validated_camera_position(
		candidate: Vector3, fallback: Vector3, safe_origin: Vector3
) -> Vector3:
	if _camera_position_is_terrain_safe(candidate):
		return candidate
	if _camera_position_is_terrain_safe(fallback):
		return fallback
	return _terrain_safe_position(safe_origin)


func _camera_position_is_terrain_safe(position: Vector3) -> bool:
	if not position.is_finite():
		return false
	for offset in terrain_footprint_offsets():
		var sample_position := position + Vector3(offset.x, 0.0, offset.y)
		var height := _terrain_height(sample_position)
		if is_finite(height) and position.y < height + CAMERA_TERRAIN_CLEARANCE:
			return false
	return true


func _target_horizontal_direction(target: Node3D, fallback: Vector3) -> Vector3:
	if target is RigidBody3D:
		var velocity: Vector3 = (target as RigidBody3D).linear_velocity
		velocity.y = 0.0
		if velocity.length() > 0.5:
			return velocity.normalized()
	var horizontal := Vector3(fallback.x, 0.0, fallback.z)
	return horizontal.normalized() if not horizontal.is_zero_approx() else Vector3.FORWARD


func _apply_fov() -> void:
	if _camera != null:
		_camera.fov = CANNON_FIELD_OF_VIEW if view_mode == &"cannon" else _default_fov


func _yaw_forward(yaw_degrees: float) -> Vector3:
	var yaw := deg_to_rad(yaw_degrees)
	return Vector3(sin(yaw), 0.0, -cos(yaw)).normalized()
