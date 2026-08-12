class_name CannonGolfCourseCameraRig
extends Node

const FOLLOW_OFFSET := Vector3(10.0, 6.5, 12.0)

var view_mode: StringName = &"oblique"
var pan_offset := Vector3.ZERO
var zoom := 1.16

var _camera: Camera3D
var _course: CannonGolfCourseData


func configure(camera: Camera3D, course: CannonGolfCourseData) -> void:
	assert(camera != null and course != null and course.is_valid())
	_camera = camera
	_course = course
	view_mode = &"oblique"
	pan_offset = Vector3.ZERO
	zoom = 1.16
	snap_to_planning()


func set_view(next_view: StringName) -> bool:
	if next_view != &"oblique" and next_view != &"side":
		return false
	view_mode = next_view
	return true


func pan(screen_direction: Vector2) -> void:
	var scale := 2.25 * zoom
	if view_mode == &"side":
		pan_offset += Vector3(0.0, screen_direction.y * scale, screen_direction.x * scale)
	else:
		pan_offset += Vector3(screen_direction.x * scale, 0.0, -screen_direction.y * scale)
	pan_offset.x = clampf(pan_offset.x, -12.0, 12.0)
	pan_offset.y = clampf(pan_offset.y, -6.0, 10.0)
	pan_offset.z = clampf(pan_offset.z, -16.0, 16.0)


func adjust_zoom(delta: float) -> void:
	zoom = clampf(zoom + delta, 0.72, 1.38)


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
	var desired_position := focus + base_offset * zoom
	if delta >= 0.999:
		_camera.global_position = desired_position
	else:
		_camera.global_position = _camera.global_position.lerp(
			desired_position,
			1.0 - exp(-delta * 5.5)
		)
	_camera.look_at(focus, Vector3.UP)
