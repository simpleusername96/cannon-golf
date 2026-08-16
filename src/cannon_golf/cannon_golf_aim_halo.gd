class_name CannonGolfAimHalo
extends Node3D

## Partial world-space launch guide. It shows direction and early curvature,
## never a complete flight or predicted landing point.

const SAMPLE_STEP_SECONDS := 0.05
const MAXIMUM_GUIDE_SECONDS := 0.55
const MAXIMUM_PATH_LENGTH := 95.0
const FLOAT_HEIGHT := 12.0
const CURVE_RADIUS := 0.24
const CURVE_OVERLAP := 0.08
const ARROW_LENGTH := 9.0
const ARROW_RADIUS := 2.5
# Keep camera framing independent from an arbitrary player aim direction. The
# curve may extend beyond this legacy logical cue envelope at extreme bearings.
const RADIUS := 13.0
const PRESENTATION_TOP_HEIGHT := 31.0
const CANNON_PERSPECTIVE_SCALE := 0.32

var _elevation_degrees := 50.0
var _launch_direction := Vector3.FORWARD
var _launch_speed := CannonGolfBallistics.launch_speed(50.0)
var _curve_root: Node3D
var _direction_arrow: MeshInstance3D
var _sampled_points := PackedVector3Array()
var _sampled_duration := 0.0
var _sampled_path_length := 0.0
var _arrow_tangent := Vector3.FORWARD
var _guide_material: StandardMaterial3D
var _arrow_material: StandardMaterial3D


func _ready() -> void:
	_build_visuals()
	_rebuild_curve()


func set_angles(
		_yaw_degrees: float,
		elevation_degrees: float,
		launch_direction: Vector3,
		launch_speed: float
) -> void:
	_launch_direction = launch_direction.normalized()
	_launch_speed = maxf(launch_speed, 0.0)
	_elevation_degrees = clampf(
		elevation_degrees,
		CannonGolfBallistics.MINIMUM_ELEVATION_DEGREES,
		CannonGolfBallistics.MAXIMUM_ELEVATION_DEGREES
	)
	_rebuild_curve()


func indicated_elevation_degrees() -> float:
	return _elevation_degrees


func sampled_points() -> PackedVector3Array:
	return _sampled_points.duplicate()


func sampled_duration() -> float:
	return _sampled_duration


func sampled_path_length() -> float:
	return _sampled_path_length


func arrow_tangent() -> Vector3:
	return _arrow_tangent


func presentation_radius() -> float:
	return RADIUS


func presentation_top_height() -> float:
	return PRESENTATION_TOP_HEIGHT


func set_cannon_view_active(active: bool) -> void:
	visible = true
	scale = Vector3.ONE * CANNON_PERSPECTIVE_SCALE if active else Vector3.ONE


func _build_visuals() -> void:
	if _curve_root != null:
		return
	_guide_material = _material(Color("102A43"), false)
	_arrow_material = _material(Color("FFD05C"), true)
	_curve_root = Node3D.new()
	_curve_root.name = "AimCurve"
	add_child(_curve_root)
	_direction_arrow = MeshInstance3D.new()
	_direction_arrow.name = "DirectionArrow"
	var arrow_mesh := CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = ARROW_RADIUS
	arrow_mesh.height = ARROW_LENGTH
	arrow_mesh.radial_segments = 12
	arrow_mesh.rings = 1
	arrow_mesh.material = _arrow_material
	_direction_arrow.mesh = arrow_mesh
	_direction_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_direction_arrow)


func _rebuild_curve() -> void:
	if _curve_root == null:
		return
	for child in _curve_root.get_children():
		_curve_root.remove_child(child)
		child.free()
	_sampled_points = _build_capped_samples()
	_sampled_path_length = 0.0
	for index in range(1, _sampled_points.size()):
		var start := _sampled_points[index - 1]
		var finish := _sampled_points[index]
		var delta := finish - start
		if delta.length_squared() <= 0.000001:
			continue
		_sampled_path_length += delta.length()
		var segment := MeshInstance3D.new()
		segment.name = "CurveSegment%02d" % index
		var segment_mesh := CylinderMesh.new()
		segment_mesh.top_radius = CURVE_RADIUS
		segment_mesh.bottom_radius = CURVE_RADIUS
		segment_mesh.height = delta.length() + CURVE_OVERLAP
		segment_mesh.radial_segments = 6
		segment_mesh.rings = 1
		segment_mesh.material = _guide_material
		segment.mesh = segment_mesh
		segment.position = (start + finish) * 0.5
		segment.basis = _basis_with_up(delta.normalized())
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_curve_root.add_child(segment)
	if _sampled_points.size() < 2:
		_direction_arrow.visible = false
		return
	_arrow_tangent = (
		_sampled_points[-1] - _sampled_points[-2]
	).normalized()
	_direction_arrow.visible = true
	_direction_arrow.position = _sampled_points[-1] + _arrow_tangent * ARROW_LENGTH * 0.5
	_direction_arrow.basis = _basis_with_up(_arrow_tangent)


func _build_capped_samples() -> PackedVector3Array:
	# The cue floats above the launcher so every legal direction stays readable
	# from an aerial camera. Its curvature uses live motion, but its raised origin
	# makes clear that this is a direction guide rather than a landing prediction.
	var origin := Vector3.UP * FLOAT_HEIGHT
	var raw := CannonBallistics.sample_unobstructed(
		origin,
		_launch_direction * _launch_speed,
		Vector3.UP * CannonGolfBallistics.GRAVITY_Y,
		SAMPLE_STEP_SECONDS,
		MAXIMUM_GUIDE_SECONDS,
		CannonGolfBallistics.LINEAR_DAMP
	)
	var capped := PackedVector3Array()
	_sampled_duration = 0.0
	if raw.is_empty():
		return capped
	capped.append(raw[0])
	var collision_path_length := _first_collision_path_length(raw)
	var path_limit := minf(
		MAXIMUM_PATH_LENGTH,
		maxf(collision_path_length - ARROW_LENGTH, 2.0)
	) if is_finite(collision_path_length) else MAXIMUM_PATH_LENGTH
	var path_length := 0.0
	for index in range(1, raw.size()):
		var start := capped[-1]
		var finish := raw[index]
		var segment_length := start.distance_to(finish)
		var remaining := path_limit - path_length
		if segment_length > remaining:
			var fraction := remaining / maxf(segment_length, 0.000001)
			capped.append(start.lerp(finish, fraction))
			_sampled_duration = (
				float(index - 1) + fraction
			) * SAMPLE_STEP_SECONDS
			break
		capped.append(finish)
		path_length += segment_length
		_sampled_duration = float(index) * SAMPLE_STEP_SECONDS
		if path_length >= path_limit - 0.0001:
			break
	return capped


func _first_collision_path_length(points: PackedVector3Array) -> float:
	if not is_inside_tree() or points.size() < 2:
		return INF
	var space_state := get_world_3d().direct_space_state
	var traversed := 0.0
	for index in range(1, points.size()):
		var start := points[index - 1]
		var finish := points[index]
		var query := PhysicsRayQueryParameters3D.create(
			to_global(start),
			to_global(finish)
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			return traversed + to_global(start).distance_to(hit.position)
		traversed += start.distance_to(finish)
	return INF


func _basis_with_up(up_direction: Vector3) -> Basis:
	var up := up_direction.normalized()
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.92 \
			else Vector3.RIGHT
	var right := up.cross(reference).normalized()
	var forward := right.cross(up).normalized()
	return Basis(right, up, forward)


func _material(color: Color, no_depth_test: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = no_depth_test
	material.render_priority = 1 if no_depth_test else 0
	return material
