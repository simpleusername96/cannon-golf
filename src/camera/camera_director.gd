class_name CameraDirector
extends Node

const GAMEPLAY_PACE := preload("res://src/gameplay/gameplay_pace.gd")

signal mode_changed(mode: int)
signal interaction_mode_changed(mode: int)

enum Mode {
	BRIEFING,
	AIMING,
	# Legacy presentation modes remain loadable for delivery fixtures, but normal
	# gameplay no longer exposes them.
	FOLLOW,
	WIDE,
	CANNON,
	RESULT,
}

enum InteractionMode {
	AIM_LOCKED,
	MAP_INSPECTION,
}

const CAMERA_CLEARANCE := 1.5
const CORRECTION_SMOOTH_TIME := 0.20
const AIM_SUMMIT_HEADROOM := 8.0
const AIM_SUMMIT_HEIGHT_TOLERANCE := 0.25
const PRESENTATION_FRAME_MARGIN := 1.04
const BRIEFING_SAFE_RECT := Rect2(0.09, 0.05, 0.82, 0.88)
const RESULT_SAFE_RECT := Rect2(0.06, 0.08, 0.64, 0.82)
const FOLLOW_IMPACT_HOLD_TICKS := GAMEPLAY_PACE.FOLLOW_IMPACT_HOLD_TICKS
const OCCLUSION_END_TOLERANCE := 0.25
const SAFETY_SOLVE_INTERVAL := 1.0 / 15.0
const DESIRED_POSE_EPSILON_SQUARED := 0.0025
const FOLLOW_DIRECTION := Vector3(18.0, 10.0, 24.0)
const INSPECTION_ORBIT_DEGREES_PER_PIXEL := Vector2(0.18, 0.14)
const INSPECTION_MIN_PITCH_DEGREES := 12.0
const INSPECTION_MAX_PITCH_DEGREES := 78.0
const INSPECTION_ZOOM_FACTOR := 0.90
const INSPECTION_CLEARANCE_SEARCH_STEPS := 20

var current_mode: Mode = Mode.AIMING
var current_interaction_mode: InteractionMode = InteractionMode.MAP_INSPECTION
var _camera: Camera3D
var _stage_data: StageData
var _projectile_manager: ProjectileManager
var _terrain_surface: TerrainSurface
var _cannon_controller: CannonController
var _desired_position := Vector3.ZERO
var _desired_focus := Vector3.ZERO
var _safe_position := Vector3.ZERO
var _safe_cached_focus := Vector3.ZERO
var _safe_source_position := Vector3.ZERO
var _safe_source_focus := Vector3.ZERO
var _safe_pose_valid := false
var _safe_pose_dirty := true
var _safety_solve_elapsed := SAFETY_SOLVE_INTERVAL
var _camera_velocity := Vector3.ZERO
var _shake_remaining: float = 0.0
var _shake_strength: float = 0.0
var _shake_phase: float = 0.0
var _computed_follow_position := Vector3.ZERO
var _computed_follow_focus := Vector3.ZERO
var _inspection_focus := Vector3.ZERO
var _inspection_yaw_radians := 0.0
var _inspection_pitch_radians := 0.0
var _inspection_distance := 100.0
var _inspection_min_distance := 30.0
var _inspection_max_distance := 280.0
var _inspection_pose_initialized := false
var _inspection_drag_active := false
var _aim_pose_key := ""
var _aim_pose: Array[Vector3] = []
var _aim_interest_points := PackedVector3Array()
var _aim_interest_build_count := 0
var _presentation_pose_cache: Dictionary = {}
var _presentation_points := PackedVector3Array()
var _presentation_points_checksum := 0
var _presentation_pose_build_count := 0
var _safety_solve_count := 0
var _follow_projectile: PaintProjectile
var _follow_impact_hold_ticks := 0
var _follow_impact_focus := Vector3.ZERO


func configure(
		camera: Camera3D,
		stage_data: StageData,
		projectile_manager: ProjectileManager,
		terrain_surface: TerrainSurface,
		cannon_controller: CannonController = null
) -> void:
	_camera = camera
	_stage_data = stage_data
	_projectile_manager = projectile_manager
	_terrain_surface = terrain_surface
	_cannon_controller = cannon_controller
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not _projectile_manager.shot_family_started.is_connected(_on_shot_family_started):
		_projectile_manager.shot_family_started.connect(_on_shot_family_started)
	if not _projectile_manager.projectile_contact_reported.is_connected(_on_projectile_contact_reported):
		_projectile_manager.projectile_contact_reported.connect(_on_projectile_contact_reported)
	set_mode(Mode.BRIEFING, true)


func _physics_process(delta: float) -> void:
	if _camera == null or _stage_data == null:
		return
	if current_mode == Mode.FOLLOW:
		_update_follow_state()
	_safety_solve_elapsed += delta
	if _safe_pose_dirty and (not _safe_pose_valid or _safety_solve_elapsed >= SAFETY_SOLVE_INTERVAL):
		_resolve_safe_pose()


func _process(delta: float) -> void:
	if _camera == null or _stage_data == null:
		return
	_update_rendered_camera(delta)
	_update_shake(delta)


func add_impact_shake(strength: float) -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and not bool(game_state.settings.get("camera_shake", true)):
		return
	_shake_strength = maxf(_shake_strength, clampf(strength, 0.0, 0.5))
	_shake_remaining = maxf(_shake_remaining, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_inspect_map():
		_inspection_drag_active = false
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_inspection_drag_active = true
			else:
				_inspection_drag_active = false
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_inspection(1.0)
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_inspection(-1.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _inspection_drag_active and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			orbit_inspection(motion.relative)
			get_viewport().set_input_as_handled()
		elif not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_inspection_drag_active = false


func set_mode(mode: Mode, immediate: bool = false) -> void:
	if _camera == null or _stage_data == null:
		return
	var changed_mode := current_mode != mode
	current_mode = mode
	if changed_mode:
		_safe_pose_valid = false
		_safe_pose_dirty = true
		_safety_solve_elapsed = SAFETY_SOLVE_INTERVAL
	if mode == Mode.BRIEFING:
		_initialize_inspection_pose(_bookmark_for(Mode.BRIEFING), true)
		_set_interaction_mode(InteractionMode.MAP_INSPECTION, immediate)
	elif mode == Mode.AIMING:
		_set_interaction_mode(InteractionMode.AIM_LOCKED, immediate)
	elif mode == Mode.FOLLOW:
		_update_follow_target()
	else:
		var bookmark := _bookmark_for(mode)
		_move_to(bookmark[0], bookmark[1], immediate)
	mode_changed.emit(current_mode)


func set_interaction_mode(mode: InteractionMode, immediate: bool = false) -> bool:
	if _camera == null or _stage_data == null:
		return false
	if current_mode not in [Mode.BRIEFING, Mode.AIMING]:
		return false
	if mode == InteractionMode.AIM_LOCKED and current_mode != Mode.AIMING:
		return false
	_set_interaction_mode(mode, immediate)
	return true


func toggle_interaction_mode() -> bool:
	if current_mode != Mode.AIMING:
		return false
	var next_mode := InteractionMode.MAP_INSPECTION \
			if current_interaction_mode == InteractionMode.AIM_LOCKED \
			else InteractionMode.AIM_LOCKED
	return set_interaction_mode(next_mode)


func interaction_mode_name() -> String:
	return InteractionMode.keys()[current_interaction_mode]


func aim_is_locked() -> bool:
	return current_interaction_mode == InteractionMode.AIM_LOCKED


func orbit_inspection(relative: Vector2) -> bool:
	if not _can_inspect_map() or relative.is_zero_approx():
		return false
	_inspection_yaw_radians = wrapf(
		_inspection_yaw_radians - deg_to_rad(relative.x * INSPECTION_ORBIT_DEGREES_PER_PIXEL.x),
		-PI,
		PI
	)
	_inspection_pitch_radians = clampf(
		_inspection_pitch_radians + deg_to_rad(relative.y * INSPECTION_ORBIT_DEGREES_PER_PIXEL.y),
		deg_to_rad(INSPECTION_MIN_PITCH_DEGREES),
		deg_to_rad(INSPECTION_MAX_PITCH_DEGREES)
	)
	_apply_inspection_orbit()
	return true


func zoom_inspection(wheel_steps: float) -> bool:
	if not _can_inspect_map() or is_zero_approx(wheel_steps):
		return false
	_inspection_distance = clampf(
		_inspection_distance * pow(INSPECTION_ZOOM_FACTOR, wheel_steps),
		_inspection_min_distance,
		_inspection_max_distance
	)
	_apply_inspection_orbit()
	return true


func inspection_distance() -> float:
	return _inspection_distance


func mode_name() -> String:
	return Mode.keys()[current_mode]


func set_briefing_offsets(yaw_degrees: float, zoom_distance: float) -> void:
	if current_mode != Mode.BRIEFING or not _inspection_pose_initialized:
		return
	var bookmark := _bookmark_for(Mode.BRIEFING)
	var base_offset := bookmark[0] - _inspection_focus
	var base_distance := maxf(base_offset.length(), 0.001)
	_inspection_yaw_radians = wrapf(
		atan2(base_offset.x, base_offset.z) + deg_to_rad(clampf(yaw_degrees, -22.0, 22.0)),
		-PI,
		PI
	)
	_inspection_pitch_radians = clampf(
		asin(clampf(base_offset.y / base_distance, -1.0, 1.0)),
		deg_to_rad(INSPECTION_MIN_PITCH_DEGREES),
		deg_to_rad(INSPECTION_MAX_PITCH_DEGREES)
	)
	_inspection_distance = clampf(
		base_distance + clampf(zoom_distance, -22.0, 28.0),
		_inspection_min_distance,
		_inspection_max_distance
	)
	_apply_inspection_orbit()


func camera_focus_position() -> Vector3:
	return _safe_cached_focus if _safe_pose_valid else _safe_focus(_desired_focus)


func return_to_aim_view(immediate: bool = false) -> bool:
	if current_mode != Mode.FOLLOW:
		return false
	_follow_projectile = null
	_follow_impact_hold_ticks = 0
	set_mode(Mode.AIMING, immediate)
	return true


func aiming_interest_build_count() -> int:
	return _aim_interest_build_count


func presentation_pose_build_count() -> int:
	return _presentation_pose_build_count


func safety_solve_count() -> int:
	return _safety_solve_count


func safe_position_for(desired: Vector3, focus: Vector3, terrain_focus: bool = false) -> Vector3:
	if _terrain_surface == null:
		return desired
	var candidate := desired
	if _terrain_surface.contains_world_xz(Vector2(candidate.x, candidate.z)):
		var surface := _terrain_surface.world_surface_point(Vector2(candidate.x, candidate.z))
		candidate.y = maxf(candidate.y, surface.y + CAMERA_CLEARANCE)
	for _attempt in range(8):
		var hit := _terrain_ray(candidate, focus)
		if hit.is_empty():
			break
		var hit_position: Vector3 = hit.position
		if terrain_focus and hit_position.distance_to(focus) <= OCCLUSION_END_TOLERANCE:
			break
		candidate.y += maxf(3.0, hit_position.distance_to(focus) * 0.28)
		if _terrain_surface.contains_world_xz(Vector2(candidate.x, candidate.z)):
			var raised_surface := _terrain_surface.world_surface_point(Vector2(candidate.x, candidate.z))
			candidate.y = maxf(candidate.y, raised_surface.y + CAMERA_CLEARANCE)
	if not view_ray_is_clear(candidate, focus, terrain_focus):
		# A direct overhead fallback is deterministic and cannot hide the focus behind another ridge.
		var vertical_distance := maxf(desired.distance_to(focus), 24.0)
		if current_mode == Mode.FOLLOW:
			vertical_distance = minf(vertical_distance, _stage_data.follow_camera_max_distance)
		candidate = focus + Vector3.UP * vertical_distance
		if _terrain_surface.contains_world_xz(Vector2(candidate.x, candidate.z)):
			var focus_surface := _terrain_surface.world_surface_point(Vector2(candidate.x, candidate.z))
			candidate.y = maxf(candidate.y, focus_surface.y + CAMERA_CLEARANCE)
	return candidate


func view_ray_is_clear(position: Vector3, focus: Vector3, terrain_focus: bool = false) -> bool:
	var hit := _terrain_ray(position, focus)
	return hit.is_empty() or (terrain_focus and Vector3(hit.position).distance_to(focus) <= OCCLUSION_END_TOLERANCE)


func _bookmark_for(mode: Mode) -> Array[Vector3]:
	var authored: Array[Vector3]
	match mode:
		Mode.BRIEFING:
			authored = [_stage_data.briefing_camera_position, _stage_data.briefing_camera_target]
		Mode.WIDE:
			authored = [_stage_data.wide_camera_position, _stage_data.wide_camera_target]
		Mode.RESULT:
			authored = [_stage_data.result_camera_position, _stage_data.result_camera_target]
		Mode.AIMING:
			authored = [_stage_data.aiming_camera_position, _stage_data.aiming_camera_target]
		Mode.CANNON:
			return [_stage_data.aiming_camera_position + Vector3(7.0, 2.0, 2.0), _stage_data.aiming_camera_target]
		_:
			authored = [_stage_data.aiming_camera_position, _stage_data.aiming_camera_target]
	if mode == Mode.AIMING:
		return _composed_aiming_bookmark(authored)
	if _terrain_surface == null or _camera == null:
		return authored
	if mode in [Mode.BRIEFING, Mode.RESULT]:
		return _presentation_bookmark(mode, authored)
	var bounds := _terrain_surface.render_world_aabb()
	if not bounds.has_volume():
		return authored
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / viewport_size.y if viewport_size.y > 0.0 else 16.0 / 9.0
	var frame_focus := bounds.get_center()
	if _terrain_surface.contains_world_xz(Vector2(frame_focus.x, frame_focus.z)):
		frame_focus = _terrain_surface.world_surface_point(Vector2(frame_focus.x, frame_focus.z)) \
				+ Vector3.UP * OCCLUSION_END_TOLERANCE
	return TerrainCameraFramer.framed_pose_around(
		bounds,
		frame_focus,
		authored[0],
		authored[1],
		_camera.fov,
		aspect_ratio
	)


func _presentation_bookmark(mode: Mode, authored: Array[Vector3]) -> Array[Vector3]:
	var points := _presentation_interest_points()
	if points.is_empty():
		return authored
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / viewport_size.y if viewport_size.y > 0.0 else 16.0 / 9.0
	var safe_rect := BRIEFING_SAFE_RECT if mode == Mode.BRIEFING else RESULT_SAFE_RECT
	var layout := _terrain_surface.layout_read_only()
	var checksum := layout.checksum if layout != null else 0
	var key := "%d|%d|%.4f|%.6f|%s|%s|%s" % [
		checksum,
		mode,
		_camera.fov,
		aspect_ratio,
		str(safe_rect),
		str(authored[0]),
		str(authored[1]),
	]
	if _presentation_pose_cache.has(key):
		var cached_pose: Array[Vector3] = _presentation_pose_cache[key]
		return cached_pose
	var framed: Array[Vector3]
	if mode == Mode.BRIEFING:
		# Interactive inspection must keep its optical center on the fixed terrain
		# pivot. Increase distance to respect the safe region instead of shifting it.
		framed = TerrainCameraFramer.framed_pose_around_points(
			points,
			_terrain_surface.visual_world_center(),
			authored[0],
			authored[1],
			_camera.fov,
			aspect_ratio,
			PRESENTATION_FRAME_MARGIN / minf(safe_rect.size.x, safe_rect.size.y)
		)
	else:
		framed = TerrainCameraFramer.framed_pose_in_normalized_rect(
			points,
			_points_center(points),
			authored[0],
			authored[1],
			_camera.fov,
			aspect_ratio,
			safe_rect,
			PRESENTATION_FRAME_MARGIN
		)
	if framed.is_empty():
		return authored
	var cached_pose: Array[Vector3] = [framed[0], framed[1]]
	_presentation_pose_cache[key] = cached_pose
	_presentation_pose_build_count += 1
	return cached_pose


func _presentation_interest_points() -> PackedVector3Array:
	if _terrain_surface == null:
		return PackedVector3Array()
	var layout := _terrain_surface.layout_read_only()
	var checksum := layout.checksum if layout != null else 0
	if checksum != 0 and checksum == _presentation_points_checksum \
			and not _presentation_points.is_empty():
		return _presentation_points
	_presentation_points = _terrain_surface.presentation_world_points()
	_presentation_points_checksum = checksum
	_presentation_pose_cache.clear()
	return _presentation_points


func _points_center(points: PackedVector3Array) -> Vector3:
	var bounds := AABB(points[0], Vector3.ZERO)
	for point_index in range(1, points.size()):
		bounds = bounds.expand(points[point_index])
	return bounds.get_center()


func _composed_aiming_bookmark(authored: Array[Vector3]) -> Array[Vector3]:
	if _terrain_surface == null or _camera == null:
		return authored
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / viewport_size.y if viewport_size.y > 0.0 else 16.0 / 9.0
	var layout := _terrain_surface.layout_read_only()
	var checksum := layout.checksum if layout != null else 0
	var cannon_transform := _cannon_controller.global_transform \
			if _cannon_controller != null else _stage_data.cannon_transform
	var key := "%d|%s|%.3f|%.6f" % [checksum, str(cannon_transform), _camera.fov, aspect_ratio]
	if key == _aim_pose_key and _aim_pose.size() == 2:
		return _aim_pose
	_aim_interest_points = _aiming_interest_points()
	_aim_interest_build_count += 1
	var composed := AimCameraComposer.compose(
		_aim_interest_points,
		_terrain_surface.render_world_aabb(),
		cannon_transform,
		_camera.fov,
		aspect_ratio
	)
	if composed.is_empty():
		return authored
	_aim_pose_key = key
	_aim_pose = [composed.position, composed.focus]
	return _aim_pose


func _aiming_interest_points() -> PackedVector3Array:
	if _terrain_surface == null:
		return PackedVector3Array()
	var interest := _terrain_surface.playable_top_world_points()
	if interest.is_empty():
		return interest
	var maximum_height := -INF
	for point in interest:
		maximum_height = maxf(maximum_height, point.y)
	var top_point_count := interest.size()
	for point_index in range(top_point_count):
		var point := interest[point_index]
		if point.y >= maximum_height - AIM_SUMMIT_HEIGHT_TOLERANCE:
			interest.append(point + Vector3.UP * AIM_SUMMIT_HEADROOM)
	var layout := _terrain_surface.layout_read_only()
	if layout != null:
		for summit in layout.summit_region(AIM_SUMMIT_HEIGHT_TOLERANCE):
			var summit_point := _terrain_surface.to_global(summit.point as Vector3)
			interest.append(summit_point)
			interest.append(summit_point + Vector3.UP * AIM_SUMMIT_HEADROOM)
	if _cannon_controller != null:
		interest.append(_cannon_controller.global_position)
		interest.append(_cannon_controller.get_launch_origin())
	return interest


func _move_to(position: Vector3, target: Vector3, immediate: bool) -> void:
	_set_desired_pose(position, target)
	if not immediate:
		return
	# An immediate presentation cut may originate from ready/input code. Apply
	# the requested pose now, then let the next fixed-physics callback resolve
	# terrain safety; direct-space queries never run from this call path.
	_camera.global_position = position
	_camera_velocity = Vector3.ZERO
	if not _camera.global_position.is_equal_approx(target):
		_look_at_focus(target)


func _set_interaction_mode(mode: InteractionMode, immediate: bool) -> void:
	var changed := current_interaction_mode != mode
	current_interaction_mode = mode
	_inspection_drag_active = false
	if mode == InteractionMode.AIM_LOCKED:
		if changed:
			# The direct inspection cache belongs to a different optical pivot.
			# Invalidate it before the next rendered frame so Aim View cannot
			# momentarily look back at the terrain-center orbit target.
			_safe_pose_valid = false
			_safe_pose_dirty = true
			_safety_solve_elapsed = SAFETY_SOLVE_INTERVAL
		var aiming_bookmark := _bookmark_for(Mode.AIMING)
		_move_to(aiming_bookmark[0], aiming_bookmark[1], immediate)
	else:
		if not _inspection_pose_initialized:
			_initialize_inspection_pose(_bookmark_for(Mode.WIDE), false)
		_apply_inspection_orbit(immediate)
	if changed:
		interaction_mode_changed.emit(current_interaction_mode)


func _initialize_inspection_pose(bookmark: Array[Vector3], force: bool) -> void:
	if _inspection_pose_initialized and not force:
		return
	var position := bookmark[0]
	_inspection_focus = _terrain_surface.visual_world_center()
	var offset := position - _inspection_focus
	_inspection_distance = maxf(offset.length(), 0.001)
	_inspection_yaw_radians = atan2(offset.x, offset.z)
	_inspection_pitch_radians = clampf(
		asin(clampf(offset.y / _inspection_distance, -1.0, 1.0)),
		deg_to_rad(INSPECTION_MIN_PITCH_DEGREES),
		deg_to_rad(INSPECTION_MAX_PITCH_DEGREES)
	)
	var span := maxf(_stage_data.terrain_size.x, _stage_data.terrain_size.y)
	_inspection_min_distance = maxf(30.0, minf(_stage_data.terrain_size.x, _stage_data.terrain_size.y) * 0.24)
	_inspection_max_distance = maxf(_inspection_distance, span * 1.4)
	_inspection_distance = clampf(_inspection_distance, _inspection_min_distance, _inspection_max_distance)
	_inspection_pose_initialized = true


func _apply_inspection_orbit(immediate: bool = false) -> void:
	if not _inspection_pose_initialized:
		return
	var horizontal_scale := cos(_inspection_pitch_radians) * _inspection_distance
	var offset := Vector3(
		sin(_inspection_yaw_radians) * horizontal_scale,
		sin(_inspection_pitch_radians) * _inspection_distance,
		cos(_inspection_yaw_radians) * horizontal_scale
	)
	_set_desired_pose(_inspection_focus + offset, _inspection_focus)
	_cache_inspection_pose()
	if immediate:
		_camera.global_position = _safe_position
		_camera_velocity = Vector3.ZERO
		_look_at_focus(_inspection_focus)


func _cache_inspection_pose() -> void:
	_safe_source_position = _desired_position
	_safe_source_focus = _inspection_focus
	_safe_cached_focus = _inspection_focus
	_safe_position = _safe_inspection_position(_desired_position)
	_safe_pose_valid = true
	_safe_pose_dirty = false
	_safety_solve_elapsed = 0.0


## Keeps terrain clearance by increasing radius on the selected spherical ray.
## It never changes the terrain pivot, yaw, or pitch.
func _safe_inspection_position(desired: Vector3) -> Vector3:
	var direction := (desired - _inspection_focus).normalized()
	if direction.is_zero_approx():
		return desired
	var requested_distance := clampf(
		desired.distance_to(_inspection_focus),
		_inspection_min_distance,
		_inspection_max_distance
	)
	var requested := _inspection_focus + direction * requested_distance
	if _inspection_position_has_clearance(requested):
		return requested
	var maximum := _inspection_focus + direction * _inspection_max_distance
	if not _inspection_position_has_clearance(maximum):
		return maximum
	var lower_distance := requested_distance
	var upper_distance := _inspection_max_distance
	for _step in range(INSPECTION_CLEARANCE_SEARCH_STEPS):
		var candidate_distance := (lower_distance + upper_distance) * 0.5
		var candidate := _inspection_focus + direction * candidate_distance
		if _inspection_position_has_clearance(candidate):
			upper_distance = candidate_distance
		else:
			lower_distance = candidate_distance
	return _inspection_focus + direction * upper_distance


func _inspection_position_has_clearance(position: Vector3) -> bool:
	if _terrain_surface == null \
			or not _terrain_surface.contains_world_xz(Vector2(position.x, position.z)):
		return true
	var surface := _terrain_surface.world_surface_point(Vector2(position.x, position.z))
	return position.y >= surface.y + CAMERA_CLEARANCE


func _can_inspect_map() -> bool:
	return _camera != null and _stage_data != null \
			and current_mode in [Mode.BRIEFING, Mode.AIMING] \
			and current_interaction_mode == InteractionMode.MAP_INSPECTION


func _update_follow_target() -> void:
	if not _compute_follow_pose(false, true):
		return
	_set_desired_pose(_computed_follow_position, _computed_follow_focus)


func _update_follow_state() -> void:
	if _follow_impact_hold_ticks > 0:
		_follow_impact_hold_ticks -= 1
		_computed_follow_focus = _follow_impact_focus
		_set_desired_pose(_computed_follow_position, _computed_follow_focus)
		if _follow_impact_hold_ticks == 0:
			return_to_aim_view()
		return
	if _follow_projectile == null or not is_instance_valid(_follow_projectile):
		return_to_aim_view()
		return
	_update_follow_target()


func _compute_follow_pose(use_interpolated_transform: bool, _update_latch: bool) -> bool:
	if _follow_projectile == null or not is_instance_valid(_follow_projectile):
		return false
	var focus := _follow_projectile.get_global_transform_interpolated().origin \
			if use_interpolated_transform else _follow_projectile.global_position
	_computed_follow_position = focus + FOLLOW_DIRECTION
	_computed_follow_focus = focus
	return true


func _on_shot_family_started(_shot_id: int, root_projectile: PaintProjectile) -> void:
	if root_projectile == null or not is_instance_valid(root_projectile):
		return
	_follow_projectile = root_projectile
	_follow_impact_hold_ticks = 0
	set_mode(Mode.FOLLOW)


func _on_projectile_contact_reported(
		projectile: PaintProjectile,
		contact: ProjectileContact
) -> void:
	if current_mode != Mode.FOLLOW or projectile != _follow_projectile \
			or _follow_impact_hold_ticks > 0:
		return
	if not _terrain_surface.is_top_collider(contact.collider) \
			and not _terrain_surface.is_skirt_collider(contact.collider):
		return
	_follow_impact_focus = contact.world_position
	_follow_impact_hold_ticks = FOLLOW_IMPACT_HOLD_TICKS
	if not _compute_follow_pose(false, false):
		_computed_follow_position = _follow_impact_focus + FOLLOW_DIRECTION
	_computed_follow_focus = _follow_impact_focus
	_set_desired_pose(_computed_follow_position, _computed_follow_focus)


func _update_rendered_camera(delta: float) -> void:
	if not _safe_pose_valid:
		return
	var target_position := _safe_position
	var target_focus := _safe_cached_focus
	if _can_inspect_map():
		_camera.global_position = target_position
		_camera_velocity = Vector3.ZERO
		if not target_position.is_equal_approx(target_focus):
			_look_at_focus(target_focus)
		return
	if current_mode == Mode.FOLLOW and _follow_impact_hold_ticks == 0 \
			and _compute_follow_pose(true, false):
		target_position = _computed_follow_position \
				+ (_safe_position - _safe_source_position)
		target_focus = _computed_follow_focus \
				+ (_safe_cached_focus - _safe_source_focus)
	var corrected := _smooth_damp(_camera.global_position, target_position, delta)
	_camera.global_position = corrected
	if not corrected.is_equal_approx(target_focus):
		_look_at_focus(target_focus)


func _set_desired_pose(position: Vector3, focus: Vector3) -> void:
	if _desired_position.distance_squared_to(position) <= DESIRED_POSE_EPSILON_SQUARED \
			and _desired_focus.distance_squared_to(focus) <= DESIRED_POSE_EPSILON_SQUARED:
		return
	_desired_position = position
	_desired_focus = focus
	_safe_pose_dirty = true
	if not _safe_pose_valid:
		_safety_solve_elapsed = SAFETY_SOLVE_INTERVAL


func _resolve_safe_pose() -> void:
	if _can_inspect_map():
		_cache_inspection_pose()
		return
	_safety_solve_count += 1
	_safe_source_position = _desired_position
	_safe_source_focus = _desired_focus
	var presentation_mode := current_mode in [Mode.BRIEFING, Mode.RESULT]
	_safe_cached_focus = _presentation_focus_on_view_ray(_desired_position, _desired_focus) \
			if presentation_mode else _safe_focus(_desired_focus)
	var terrain_focus := presentation_mode or _focus_is_terrain(_desired_focus)
	_safe_position = safe_position_for(
		_desired_position,
		_safe_cached_focus,
		terrain_focus
	)
	if _camera != null and not view_ray_is_clear(
		_camera.global_position,
		_safe_cached_focus,
		terrain_focus
	):
		# A smooth path between two safe poses can still sweep through a ridge.
		# Snap only when the current path is blocked; unobstructed transitions keep
		# their normal damping.
		_camera.global_position = _safe_position
		_camera_velocity = Vector3.ZERO
		if not _camera.global_position.is_equal_approx(_safe_cached_focus):
			_look_at_focus(_safe_cached_focus)
	_safe_pose_valid = true
	_safe_pose_dirty = false
	_safety_solve_elapsed = 0.0


func _presentation_focus_on_view_ray(position: Vector3, optical_focus: Vector3) -> Vector3:
	var hit := _terrain_ray(position, optical_focus)
	if hit.is_empty():
		return optical_focus
	var collider: Object = hit.get("collider")
	if not _terrain_surface.is_top_collider(collider) \
			and not _terrain_surface.is_skirt_collider(collider):
		return optical_focus
	return Vector3(hit.position)


func _safe_focus(focus: Vector3) -> Vector3:
	if _terrain_surface == null or not _terrain_surface.contains_world_xz(Vector2(focus.x, focus.z)):
		return focus
	var surface := _terrain_surface.world_surface_point(Vector2(focus.x, focus.z))
	if focus.y <= surface.y + OCCLUSION_END_TOLERANCE:
		return surface + Vector3.UP * OCCLUSION_END_TOLERANCE
	return focus


func _focus_is_terrain(focus: Vector3) -> bool:
	if _terrain_surface == null or not _terrain_surface.contains_world_xz(Vector2(focus.x, focus.z)):
		return false
	var surface := _terrain_surface.world_surface_point(Vector2(focus.x, focus.z))
	return focus.y <= surface.y + OCCLUSION_END_TOLERANCE


func _terrain_ray(from: Vector3, to: Vector3) -> Dictionary:
	if _camera == null or _terrain_surface == null or from.distance_squared_to(to) < 0.0001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return _camera.get_world_3d().direct_space_state.intersect_ray(query)


func _smooth_damp(current: Vector3, target: Vector3, delta: float) -> Vector3:
	var omega := 2.0 / CORRECTION_SMOOTH_TIME
	var x := omega * maxf(delta, 0.00001)
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - target
	var temporary := (_camera_velocity + omega * change) * delta
	_camera_velocity = (_camera_velocity - omega * temporary) * decay
	return target + (change + temporary) * decay


func _look_at_focus(focus: Vector3) -> void:
	var view_direction := (focus - _camera.global_position).normalized()
	var up := Vector3.FORWARD if absf(view_direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	_camera.look_at(focus, up)


func _update_shake(delta: float) -> void:
	if _camera == null:
		return
	if _shake_remaining <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	_shake_phase += delta * 48.0
	var fade := clampf(_shake_remaining / 0.2, 0.0, 1.0)
	_camera.h_offset = sin(_shake_phase * 1.7) * _shake_strength * fade
	_camera.v_offset = cos(_shake_phase * 2.3) * _shake_strength * fade
