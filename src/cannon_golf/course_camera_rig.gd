class_name CannonGolfCourseCameraRig
extends Node

const FOLLOW_OFFSET := Vector3(10.0, 6.5, 12.0)
const CONFIRMED_FOLLOW_OFFSET := Vector3(11.0, 20.0, 16.0)
const FRAME_MARGIN := 1.08
const MODE_PLANNING: StringName = &"planning"
const MODE_FOLLOW: StringName = &"follow"
const DEFAULT_ZOOM := 1.05
const MINIMUM_ZOOM := 0.38
const MAXIMUM_ZOOM := 2.0
const ZOOM_FACTOR_PER_STEP := 0.78
const ORBIT_DEGREES_PER_PIXEL := Vector2(0.18, 0.14)
const MINIMUM_PITCH_DEGREES := 12.0
const MAXIMUM_PITCH_DEGREES := 78.0

var view_mode: StringName = &"oblique"
var camera_mode: StringName = MODE_PLANNING
var pan_offset := Vector3.ZERO
var zoom := DEFAULT_ZOOM
var orbit_degrees := Vector2.ZERO

var _camera: Camera3D
var _course: CannonGolfCourseData
var _follow_target: Node3D
var _follow_offset := FOLLOW_OFFSET
var _planning_position := Vector3.ZERO
var _planning_focus := Vector3.ZERO
var _planning_pose_dirty := true
var _planning_pose_builds := 0
var _planning_viewport_size := Vector2.ZERO
var _frame_bounds := AABB()
var _exploration_bounds := AABB()
var _base_planning_focus := Vector3.ZERO


func configure(camera: Camera3D, course: CannonGolfCourseData) -> void:
	assert(camera != null and course != null and course.is_valid())
	_camera = camera
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_course = course
	_frame_bounds = course.content_bounds
	_exploration_bounds = course.content_bounds
	_base_planning_focus = course.planning_focus
	view_mode = &"oblique"
	camera_mode = MODE_PLANNING
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_follow_target = null
	_follow_offset = FOLLOW_OFFSET
	_planning_pose_dirty = true
	_planning_pose_builds = 0
	snap_to_planning()


func set_view(next_view: StringName) -> bool:
	if next_view != &"oblique" and next_view != &"side":
		return false
	view_mode = next_view
	orbit_degrees = Vector2.ZERO
	_planning_pose_dirty = true
	return_to_planning()
	return true


func pan(screen_direction: Vector2) -> void:
	if _course == null:
		return
	var course_span := maxf(_course.content_bounds.size.x, _course.content_bounds.size.z)
	var scale := maxf(course_span * 0.02, 2.25) * zoom
	if view_mode == &"side":
		pan_offset += Vector3(0.0, screen_direction.y * scale, screen_direction.x * scale)
	else:
		pan_offset += Vector3(screen_direction.x * scale, 0.0, -screen_direction.y * scale)
	var horizontal_limit := course_span * 0.10
	var vertical_limit := maxf(_course.content_bounds.size.y * 0.18, 6.0)
	pan_offset.x = clampf(pan_offset.x, -horizontal_limit, horizontal_limit)
	pan_offset.y = clampf(pan_offset.y, -vertical_limit, vertical_limit)
	pan_offset.z = clampf(pan_offset.z, -horizontal_limit, horizontal_limit)
	_planning_pose_dirty = true


func zoom_by_steps(wheel_steps: float) -> bool:
	if _course == null or is_zero_approx(wheel_steps):
		return false
	var next_zoom := clampf(
		zoom * pow(ZOOM_FACTOR_PER_STEP, wheel_steps),
		MINIMUM_ZOOM,
		MAXIMUM_ZOOM
	)
	if is_equal_approx(next_zoom, zoom):
		return false
	zoom = next_zoom
	_planning_pose_dirty = true
	return true


func orbit(relative: Vector2) -> bool:
	if _course == null or relative.is_zero_approx():
		return false
	var base_offset := _course.side_offset if view_mode == &"side" else _course.oblique_offset
	var base_pitch := rad_to_deg(asin(clampf(base_offset.normalized().y, -1.0, 1.0)))
	orbit_degrees.x = wrapf(
		orbit_degrees.x - relative.x * ORBIT_DEGREES_PER_PIXEL.x,
		-180.0,
		180.0
	)
	var absolute_pitch := clampf(
		base_pitch + orbit_degrees.y + relative.y * ORBIT_DEGREES_PER_PIXEL.y,
		MINIMUM_PITCH_DEGREES,
		MAXIMUM_PITCH_DEGREES
	)
	orbit_degrees.y = absolute_pitch - base_pitch
	_planning_pose_dirty = true
	return true


func reset_planning_view() -> void:
	view_mode = &"oblique"
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_planning_pose_dirty = true
	return_to_planning()


func set_planning_context(frame_bounds: AABB, focus: Vector3) -> bool:
	if not frame_bounds.has_volume() or not focus.is_finite():
		return false
	_frame_bounds = frame_bounds
	_base_planning_focus = focus
	view_mode = &"oblique"
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_planning_pose_dirty = true
	return_to_planning(true)
	return true


func planning_focus() -> Vector3:
	return _base_planning_focus + pan_offset if _course != null else Vector3.ZERO


func follow(target: Node3D) -> bool:
	return _begin_follow(target, FOLLOW_OFFSET, false)


func follow_confirmed(target: Node3D) -> bool:
	return _begin_follow(target, CONFIRMED_FOLLOW_OFFSET, true)


func _begin_follow(target: Node3D, offset: Vector3, immediate: bool) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	_follow_target = target
	_follow_offset = offset
	camera_mode = MODE_FOLLOW
	if immediate:
		_apply_follow(1.0, true)
	return true


func return_to_planning(immediate: bool = false) -> void:
	_follow_target = null
	_follow_offset = FOLLOW_OFFSET
	camera_mode = MODE_PLANNING
	if immediate:
		snap_to_planning()


func is_following(target: Node3D = null) -> bool:
	if camera_mode != MODE_FOLLOW or _follow_target == null \
			or not is_instance_valid(_follow_target):
		return false
	return target == null or target == _follow_target


func follow_target() -> Node3D:
	return _follow_target if is_following() else null


func planning_pose_build_count() -> int:
	return _planning_pose_builds


func update(delta: float) -> void:
	if _camera == null or _course == null:
		return
	if camera_mode == MODE_FOLLOW:
		if _follow_target == null or not is_instance_valid(_follow_target) \
				or not _follow_target.is_inside_tree():
			return_to_planning()
			_apply_planning(delta)
			return
		_apply_follow(delta)
		return
	_apply_planning(delta)


func snap_to_planning() -> void:
	camera_mode = MODE_PLANNING
	_follow_target = null
	_follow_offset = FOLLOW_OFFSET
	_apply_planning(1.0)


func _apply_follow(delta: float, immediate: bool = false) -> void:
	if _camera == null or _follow_target == null or not is_instance_valid(_follow_target):
		return
	var focus := _follow_target.global_position if immediate \
			else _follow_target.get_global_transform_interpolated().origin
	var desired_position := focus + _follow_offset
	_camera.global_position = desired_position if immediate else _camera.global_position.lerp(
		desired_position,
		1.0 - exp(-delta * 4.2)
	)
	_camera.look_at(focus + Vector3.UP * 0.4, Vector3.UP)


func _apply_planning(delta: float) -> void:
	if _camera == null or _course == null:
		return
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if not viewport_size.is_equal_approx(_planning_viewport_size):
		_planning_pose_dirty = true
	if _planning_pose_dirty:
		_resolve_planning_pose(viewport_size)
	var desired_position := _planning_position
	if delta >= 0.999:
		_camera.global_position = desired_position
	else:
		_camera.global_position = _camera.global_position.lerp(
			desired_position,
			1.0 - exp(-delta * 5.5)
		)
	_camera.look_at(_planning_focus, Vector3.UP)


func _resolve_planning_pose(viewport_size: Vector2) -> void:
	var focus := _base_planning_focus + pan_offset
	var base_offset := _course.side_offset if view_mode == &"side" else _course.oblique_offset
	var base_direction := base_offset.normalized()
	var yaw := atan2(base_direction.x, base_direction.z) + deg_to_rad(orbit_degrees.x)
	var pitch := clampf(
		asin(clampf(base_direction.y, -1.0, 1.0)) + deg_to_rad(orbit_degrees.y),
		deg_to_rad(MINIMUM_PITCH_DEGREES),
		deg_to_rad(MAXIMUM_PITCH_DEGREES)
	)
	var cos_pitch := cos(pitch)
	var orbit_direction := Vector3(
		sin(yaw) * cos_pitch,
		sin(pitch),
		cos(yaw) * cos_pitch
	)
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var framing_bounds := _zoom_adjusted_frame_bounds()
	var framed_pose := TerrainCameraFramer.framed_pose_around(
		framing_bounds,
		focus,
		focus + orbit_direction * base_offset.length(),
		focus,
		_camera.fov,
		aspect,
		FRAME_MARGIN
	)
	var framed_position: Vector3 = framed_pose[0]
	var distance_scale := zoom
	if view_mode == &"oblique" and _frame_bounds != _exploration_bounds:
		distance_scale = lerpf(zoom, 1.0, _exploration_blend())
	_planning_position = focus + (framed_position - focus) * distance_scale
	_planning_focus = focus
	_planning_viewport_size = viewport_size
	_planning_pose_dirty = false
	_planning_pose_builds += 1


func _zoom_adjusted_frame_bounds() -> AABB:
	# Side view stays local to the active leg. The high-oblique view expands
	# continuously toward the complete course so maximum zoom-out is a reliable
	# map-inspection state instead of only a more distant leg view.
	if view_mode == &"side" or _frame_bounds == _exploration_bounds:
		return _frame_bounds
	var blend := _exploration_blend()
	return AABB(
		_frame_bounds.position.lerp(_exploration_bounds.position, blend),
		_frame_bounds.size.lerp(_exploration_bounds.size, blend)
	)


func _exploration_blend() -> float:
	return clampf(
		(zoom - DEFAULT_ZOOM) / (MAXIMUM_ZOOM - DEFAULT_ZOOM),
		0.0,
		1.0
	)
