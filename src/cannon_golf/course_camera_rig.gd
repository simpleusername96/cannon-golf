class_name CannonGolfCourseCameraRig
extends Node

const FOLLOW_OFFSET := Vector3(10.0, 6.5, 12.0)
const CONFIRMED_FOLLOW_OFFSET := Vector3(11.0, 20.0, 16.0)
const FRAME_MARGIN := 1.18
const MODE_PLANNING: StringName = &"planning"
const MODE_FOLLOW: StringName = &"follow"
const DEFAULT_ZOOM := 1.05
const MINIMUM_ZOOM := 0.38
const MAXIMUM_ZOOM := 2.0
const ZOOM_FACTOR_PER_STEP := 0.90
const ORBIT_DEGREES_PER_PIXEL := Vector2(0.10, 0.08)
const MINIMUM_PITCH_DEGREES := 12.0
const MAXIMUM_PITCH_DEGREES := 78.0
const PAN_RESPONSE := 0.45
const MAXIMUM_PAN_EVENT_SPAN_RATIO := 0.02
const ARROW_PAN_SPAN_RATIO := 0.01
const FOCUS_TERRAIN_CLEARANCE := 1.5
const CAMERA_TERRAIN_CLEARANCE := 2.0
const CANNON_TERRAIN_CLEARANCE := 2.5
const CANNON_REAR_OFFSET := 7.0
const CANNON_HEIGHT_OFFSET := 5.5
const CANNON_FOCUS_FORWARD := 12.0
const CANNON_FOCUS_HEIGHT := 3.5
const CANNON_FIELD_OF_VIEW := 64.0

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
var _terrain_bounds := Rect2()
var _height_sampler := Callable()
var _cannon_launcher_position := Vector3.ZERO
var _cannon_yaw_degrees := 0.0
var _default_field_of_view := 48.0


func configure(
		camera: Camera3D,
		course: CannonGolfCourseData,
		terrain_bounds: Rect2 = Rect2(),
		height_sampler: Callable = Callable()
) -> void:
	assert(camera != null and course != null and course.is_valid())
	if _camera == null or _camera != camera:
		_default_field_of_view = camera.fov
	_camera = camera
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_course = course
	_frame_bounds = course.content_bounds
	_exploration_bounds = course.content_bounds
	_base_planning_focus = course.planning_focus
	_terrain_bounds = terrain_bounds
	_height_sampler = height_sampler
	_cannon_launcher_position = course.cannon_position
	_cannon_yaw_degrees = course.shot_axis_yaw_degrees
	view_mode = &"oblique"
	camera_mode = MODE_PLANNING
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_follow_target = null
	_follow_offset = FOLLOW_OFFSET
	_planning_pose_dirty = true
	_planning_pose_builds = 0
	_apply_planning_field_of_view()
	snap_to_planning()


func set_view(next_view: StringName) -> bool:
	if next_view != &"oblique" and next_view != &"cannon":
		return false
	view_mode = next_view
	_apply_planning_field_of_view()
	orbit_degrees = Vector2.ZERO
	_planning_pose_dirty = true
	return_to_planning()
	return true


func pan(screen_direction: Vector2) -> void:
	if _course == null:
		return
	var course_span := maxf(_course.content_bounds.size.x, _course.content_bounds.size.z)
	var scale := maxf(course_span * ARROW_PAN_SPAN_RATIO, 1.0) * zoom
	pan_offset += Vector3(screen_direction.x * scale, 0.0, -screen_direction.y * scale)
	_clamp_pan_to_exploration()
	_planning_pose_dirty = true


func pan_drag(_screen_position: Vector2, relative: Vector2) -> bool:
	if _camera == null or _course == null or relative.is_zero_approx():
		return false
	var viewport_height := maxf(_camera.get_viewport().get_visible_rect().size.y, 1.0)
	var focus_distance := maxf(_camera.global_position.distance_to(planning_focus()), 1.0)
	var world_units_per_pixel := 2.0 * focus_distance \
			* tan(deg_to_rad(_camera.fov) * 0.5) / viewport_height
	var camera_right := _camera.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var camera_forward := -_camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var world_delta := (-camera_right * relative.x + camera_forward * relative.y) \
			* world_units_per_pixel * PAN_RESPONSE
	var course_span := maxf(_course.content_bounds.size.x, _course.content_bounds.size.z)
	world_delta = world_delta.limit_length(course_span * MAXIMUM_PAN_EVENT_SPAN_RATIO)
	if not world_delta.is_finite() or world_delta.is_zero_approx():
		return false
	var previous_pan := pan_offset
	pan_offset += world_delta
	_clamp_pan_to_exploration()
	if pan_offset.is_equal_approx(previous_pan):
		return false
	_planning_pose_dirty = true
	return true


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
	var base_offset := _base_offset_for_view()
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
	_apply_planning_field_of_view()
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_planning_pose_dirty = true
	return_to_planning()


func set_planning_context(
		frame_bounds: AABB,
		focus: Vector3,
		launcher_position: Vector3 = Vector3.ZERO,
		shot_axis_yaw_degrees: float = 0.0
) -> bool:
	if not frame_bounds.has_volume() or not focus.is_finite() \
			or not launcher_position.is_finite() or not is_finite(shot_axis_yaw_degrees):
		return false
	_frame_bounds = frame_bounds
	_base_planning_focus = focus
	_cannon_launcher_position = launcher_position
	_cannon_yaw_degrees = shot_axis_yaw_degrees
	view_mode = &"oblique"
	_apply_planning_field_of_view()
	pan_offset = Vector3.ZERO
	zoom = DEFAULT_ZOOM
	orbit_degrees = Vector2.ZERO
	_planning_pose_dirty = true
	return_to_planning(true)
	return true


func planning_focus() -> Vector3:
	return _effective_planning_focus() if _course != null else Vector3.ZERO


## Keeps the local cannon view aligned with the player's current horizontal aim.
func set_cannon_yaw(world_yaw_degrees: float) -> bool:
	if not is_finite(world_yaw_degrees):
		return false
	_cannon_yaw_degrees = world_yaw_degrees
	_planning_pose_dirty = true
	return true


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
	_camera.fov = _default_field_of_view
	if immediate:
		_apply_follow(1.0, true)
	return true


func return_to_planning(immediate: bool = false) -> void:
	_follow_target = null
	_follow_offset = FOLLOW_OFFSET
	camera_mode = MODE_PLANNING
	_apply_planning_field_of_view()
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
	var candidate_position := desired_position
	if delta >= 0.999:
		candidate_position = desired_position
	else:
		candidate_position = _camera.global_position.lerp(
			desired_position,
			1.0 - exp(-delta * 5.5)
		)
	_camera.global_position = _terrain_safe_camera_position(candidate_position)
	var look_direction := (_planning_focus - _camera.global_position).normalized()
	var look_up := Vector3.FORWARD if absf(look_direction.dot(Vector3.UP)) > 0.98 \
			else Vector3.UP
	_camera.look_at(_planning_focus, look_up)


func _resolve_planning_pose(viewport_size: Vector2) -> void:
	var focus := _terrain_safe_focus(_effective_planning_focus())
	var base_offset := _base_offset_for_view()
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
	if view_mode == &"cannon":
		_planning_position = focus + orbit_direction * base_offset.length() * zoom
		_planning_focus = focus
		_planning_viewport_size = viewport_size
		_planning_pose_dirty = false
		_planning_pose_builds += 1
		return
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
	var shifted_frame := AABB(_frame_bounds.position + pan_offset, _frame_bounds.size)
	if view_mode == &"cannon":
		return shifted_frame
	# Panning translates the local inspection window. Zooming out blends that
	# window back to the complete course, so the maximum overview remains a
	# reliable way to recover context without discarding the stored pan.
	var blend := _exploration_blend()
	return AABB(
		shifted_frame.position.lerp(_exploration_bounds.position, blend),
		shifted_frame.size.lerp(_exploration_bounds.size, blend)
	)


func _exploration_blend() -> float:
	return clampf(
		(zoom - DEFAULT_ZOOM) / (MAXIMUM_ZOOM - DEFAULT_ZOOM),
		0.0,
		1.0
	)


func _clamp_pan_to_exploration() -> void:
	if not _exploration_bounds.has_volume():
		return
	var base_focus := _cannon_focus() if view_mode == &"cannon" else _base_planning_focus
	var focus := base_focus + pan_offset
	focus.x = clampf(focus.x, _exploration_bounds.position.x, _exploration_bounds.end.x)
	focus.y = clampf(focus.y, _exploration_bounds.position.y, _exploration_bounds.end.y)
	focus.z = clampf(focus.z, _exploration_bounds.position.z, _exploration_bounds.end.z)
	pan_offset = focus - base_focus


func _effective_planning_focus() -> Vector3:
	var base_focus := _cannon_focus() if view_mode == &"cannon" else _base_planning_focus
	var user_focus := base_focus + pan_offset
	if view_mode == &"cannon":
		return user_focus
	return user_focus.lerp(_exploration_bounds.get_center(), _exploration_blend())


func _base_offset_for_view() -> Vector3:
	if view_mode != &"cannon":
		return _course.oblique_offset
	return _cannon_camera_position() - _cannon_focus()


func _cannon_camera_position() -> Vector3:
	var position := _cannon_launcher_position - _shot_forward() * CANNON_REAR_OFFSET
	# The launcher and every unlocked source have a prepared support shoulder.
	# Sampling the whole nearby skyline lifted this view above unrelated peaks and
	# turned it into another overview. Keep the camera on that local shoulder;
	# the final terrain-clearance pass still prevents clipping.
	position.y = _cannon_launcher_position.y + CANNON_HEIGHT_OFFSET
	return position


func _cannon_focus() -> Vector3:
	return _cannon_launcher_position + _shot_forward() * CANNON_FOCUS_FORWARD \
			+ Vector3.UP * CANNON_FOCUS_HEIGHT


func _shot_forward() -> Vector3:
	var yaw := deg_to_rad(_cannon_yaw_degrees)
	return Vector3(sin(yaw), 0.0, -cos(yaw)).normalized()


func _terrain_safe_focus(focus: Vector3) -> Vector3:
	var surface_y := _terrain_height(focus)
	if not is_finite(surface_y):
		return focus
	focus.y = maxf(focus.y, surface_y + FOCUS_TERRAIN_CLEARANCE)
	return focus


func _terrain_safe_camera_position(desired: Vector3) -> Vector3:
	if not desired.is_finite() or not _height_sampler.is_valid():
		return desired
	var clearance := CANNON_TERRAIN_CLEARANCE if view_mode == &"cannon" \
			else CAMERA_TERRAIN_CLEARANCE
	return _lift_above_terrain(desired, clearance)


func _lift_above_terrain(position: Vector3, clearance: float) -> Vector3:
	var surface_y := _terrain_height(position)
	if is_finite(surface_y):
		position.y = maxf(position.y, surface_y + clearance)
	return position


func _terrain_height(position: Vector3) -> float:
	if not _height_sampler.is_valid() or not _terrain_bounds.has_area() \
			or not _terrain_bounds.has_point(Vector2(position.x, position.z)):
		return -INF
	var sampled: Variant = _height_sampler.call(position.x, position.z)
	if sampled is float or sampled is int:
		var height := float(sampled)
		return height if is_finite(height) else -INF
	return -INF


func _apply_planning_field_of_view() -> void:
	if _camera != null:
		_camera.fov = CANNON_FIELD_OF_VIEW if view_mode == &"cannon" \
				else _default_field_of_view
