class_name CannonGolfCourseCameraRig
extends Node

const FOLLOW_OFFSET := Vector3(10.0, 6.5, 12.0)
const FRAME_MARGIN := 1.08
const MODE_PLANNING: StringName = &"planning"
const MODE_FOLLOW: StringName = &"follow"

var view_mode: StringName = &"oblique"
var camera_mode: StringName = MODE_PLANNING
var pan_offset := Vector3.ZERO
var zoom := 1.05

var _camera: Camera3D
var _course: CannonGolfCourseData
var _follow_target: Node3D
var _planning_position := Vector3.ZERO
var _planning_focus := Vector3.ZERO
var _planning_pose_dirty := true
var _planning_pose_builds := 0
var _planning_viewport_size := Vector2.ZERO


func configure(camera: Camera3D, course: CannonGolfCourseData) -> void:
	assert(camera != null and course != null and course.is_valid())
	_camera = camera
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_course = course
	view_mode = &"oblique"
	camera_mode = MODE_PLANNING
	pan_offset = Vector3.ZERO
	zoom = 1.05
	_follow_target = null
	_planning_pose_dirty = true
	_planning_pose_builds = 0
	snap_to_planning()


func set_view(next_view: StringName) -> bool:
	if next_view != &"oblique" and next_view != &"side":
		return false
	view_mode = next_view
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


func adjust_zoom(delta: float) -> void:
	zoom = clampf(zoom + delta, 1.0, 1.45)
	_planning_pose_dirty = true


func follow(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	_follow_target = target
	camera_mode = MODE_FOLLOW
	return true


func return_to_planning(immediate: bool = false) -> void:
	_follow_target = null
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
		var focus := _follow_target.get_global_transform_interpolated().origin
		var desired_position := focus + FOLLOW_OFFSET
		_camera.global_position = _camera.global_position.lerp(
			desired_position,
			1.0 - exp(-delta * 4.2)
		)
		_camera.look_at(focus + Vector3.UP * 0.4, Vector3.UP)
		return
	_apply_planning(delta)


func snap_to_planning() -> void:
	camera_mode = MODE_PLANNING
	_follow_target = null
	_apply_planning(1.0)


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
	var focus := _course.planning_focus + pan_offset
	var base_offset := _course.side_offset if view_mode == &"side" else _course.oblique_offset
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var framed_pose := TerrainCameraFramer.framed_pose_around(
		_course.content_bounds,
		focus,
		focus + base_offset,
		focus,
		_camera.fov,
		aspect,
		FRAME_MARGIN
	)
	var framed_position: Vector3 = framed_pose[0]
	_planning_position = focus + (framed_position - focus) * zoom
	_planning_focus = focus
	_planning_viewport_size = viewport_size
	_planning_pose_dirty = false
	_planning_pose_builds += 1
