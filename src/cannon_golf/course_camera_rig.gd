class_name CannonGolfCourseCameraRig
extends Node

const FOLLOW_OFFSET := Vector3(10.0, 6.5, 12.0)
const FRAME_MARGIN := 1.08

var view_mode: StringName = &"oblique"
var pan_offset := Vector3.ZERO
var zoom := 1.05

var _camera: Camera3D
var _course: CannonGolfCourseData


func configure(camera: Camera3D, course: CannonGolfCourseData) -> void:
	assert(camera != null and course != null and course.is_valid())
	_camera = camera
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_course = course
	view_mode = &"oblique"
	pan_offset = Vector3.ZERO
	zoom = 1.05
	snap_to_planning()


func set_view(next_view: StringName) -> bool:
	if next_view != &"oblique" and next_view != &"side":
		return false
	view_mode = next_view
	return true


func pan(screen_direction: Vector2) -> void:
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


func adjust_zoom(delta: float) -> void:
	zoom = clampf(zoom + delta, 1.0, 1.45)


func update(delta: float, follow_target: Node3D = null) -> void:
	if _camera == null or _course == null:
		return
	if follow_target != null and is_instance_valid(follow_target):
		var desired_position := follow_target.global_position + FOLLOW_OFFSET
		_camera.global_position = _camera.global_position.lerp(
			desired_position,
			1.0 - exp(-delta * 4.2)
		)
		_camera.look_at(follow_target.global_position + Vector3.UP * 0.4, Vector3.UP)
		return
	_apply_planning(delta)


func snap_to_planning() -> void:
	_apply_planning(1.0)


func _apply_planning(delta: float) -> void:
	if _camera == null or _course == null:
		return
	var focus := _course.planning_focus + pan_offset
	var base_offset := _course.side_offset if view_mode == &"side" else _course.oblique_offset
	var viewport_size := _camera.get_viewport().get_visible_rect().size
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
	var desired_position := focus + (framed_position - focus) * zoom
	if delta >= 0.999:
		_camera.global_position = desired_position
	else:
		_camera.global_position = _camera.global_position.lerp(
			desired_position,
			1.0 - exp(-delta * 5.5)
		)
	_camera.look_at(focus, Vector3.UP)
