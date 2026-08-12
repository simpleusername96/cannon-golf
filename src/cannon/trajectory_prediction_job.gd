class_name TrajectoryPredictionJob
extends RefCounted

const GAMEPLAY_PACE := preload("res://src/gameplay/gameplay_pace.gd")

## Sole fixed-step prediction implementation. Runtime advances it cooperatively;
## offline callers drive the same job to completion.

const PHYSICS_STEP := GAMEPLAY_PACE.ACTIVE_SIMULATION_STEP_SECONDS
const MAXIMUM_STEPS := GAMEPLAY_PACE.PREDICTION_MAXIMUM_STEPS
const COLLISION_MASK := 1 | 4
const REST_PROBE_DISTANCE := 0.01

var _space_state: PhysicsDirectSpaceState3D
var _origin := Vector3.ZERO
var _projectile_radius := 0.0
var _linear_damp := 0.0
var _stage_bounds := AABB()
var _capture_sampled_points := true
var _points := PackedVector3Array()
var _position := Vector3.ZERO
var _velocity := Vector3.ZERO
var _gravity := Vector3.ZERO
var _query: PhysicsShapeQueryParameters3D
var _step_index := 0
var _prediction: TrajectoryPrediction


static func create(
		space_state: PhysicsDirectSpaceState3D,
		origin: Vector3,
		launch_velocity: Vector3,
		projectile_radius: float,
		linear_damp: float,
		stage_bounds: AABB,
		collision_mask: int = COLLISION_MASK,
		capture_sampled_points: bool = true
) -> TrajectoryPredictionJob:
	var job := TrajectoryPredictionJob.new()
	job._origin = origin
	job._position = origin
	job._velocity = launch_velocity
	job._projectile_radius = projectile_radius
	job._linear_damp = linear_damp
	job._stage_bounds = stage_bounds
	job._capture_sampled_points = capture_sampled_points
	job._points = PackedVector3Array([origin]) if capture_sampled_points \
			else PackedVector3Array()
	if space_state == null or projectile_radius <= 0.0:
		job._prediction = TrajectoryPrediction.new(
			TrajectoryPrediction.Kind.TIMEOUT,
			origin,
			PackedVector3Array([origin]),
			0.0,
			null,
			Vector3.ZERO,
			&"invalid_predictor_input"
		)
		return job
	job._space_state = space_state
	job._gravity = _gravity_vector()
	var shape := SphereShape3D.new()
	shape.radius = projectile_radius
	job._query = PhysicsShapeQueryParameters3D.new()
	job._query.shape = shape
	job._query.collision_mask = collision_mask
	job._query.collide_with_bodies = true
	job._query.collide_with_areas = false
	return job


static func completed(prediction: TrajectoryPrediction) -> TrajectoryPredictionJob:
	var job := TrajectoryPredictionJob.new()
	job._prediction = prediction
	return job


func advance(maximum_step_count: int) -> int:
	var processed := 0
	var budget := maxi(maximum_step_count, 0)
	while processed < budget and not is_complete():
		_advance_one_step()
		processed += 1
	return processed


func is_complete() -> bool:
	return _prediction != null


func completed_prediction() -> TrajectoryPrediction:
	return _prediction


func completed_step_count() -> int:
	return _step_index


func _advance_one_step() -> void:
	var step_index := _step_index
	_velocity *= maxf(1.0 - _linear_damp * PHYSICS_STEP, 0.0)
	_velocity += _gravity * PHYSICS_STEP
	var next_position := _position + _velocity * PHYSICS_STEP
	var motion := next_position - _position
	var bounds_fraction := _bounds_exit_fraction(
		_position, next_position, _stage_bounds
	)
	_query.transform = Transform3D(Basis.IDENTITY, _position)
	_query.motion = motion
	var fractions := _space_state.cast_motion(_query)
	var collision_fraction := 1.0
	if not fractions.is_empty():
		collision_fraction = clampf(float(fractions[0]), 0.0, 1.0)
	var probe_rest_info: Dictionary = {}
	# Preserve the recovered endpoint-rest parity behavior. Concave top faces can
	# report an overlapping sphere as a safe cast, while grazing casts can report
	# a hit before the exact endpoint has a real rigid-body rest contact.
	if collision_fraction >= 1.0:
		_query.transform = Transform3D(Basis.IDENTITY, next_position)
		_query.motion = Vector3.ZERO
		var candidate_rest_info := _space_state.get_rest_info(_query)
		if not candidate_rest_info.is_empty():
			var candidate_point: Vector3 = candidate_rest_info.get(
				"point", Vector3.INF
			)
			if candidate_point.is_finite() \
					and next_position.distance_to(candidate_point) \
					<= _projectile_radius + REST_PROBE_DISTANCE:
				probe_rest_info = candidate_rest_info
	elif bounds_fraction >= 1.0:
		_query.transform = Transform3D(Basis.IDENTITY, next_position)
		_query.motion = Vector3.ZERO
		var endpoint_rest_info := _space_state.get_rest_info(_query)
		if not endpoint_rest_info.is_empty():
			var endpoint_point: Vector3 = endpoint_rest_info.get("point", Vector3.INF)
			if endpoint_point.is_finite() \
					and next_position.distance_to(endpoint_point) \
					<= _projectile_radius + REST_PROBE_DISTANCE:
				probe_rest_info = endpoint_rest_info
	var has_collision := collision_fraction < 1.0 \
			and collision_fraction <= bounds_fraction
	if collision_fraction < 1.0 and probe_rest_info.is_empty():
		has_collision = false
	if not probe_rest_info.is_empty() and bounds_fraction >= 1.0:
		has_collision = true
	if has_collision:
		var motion_direction := motion.normalized()
		var rest_info: Dictionary = probe_rest_info
		if rest_info.is_empty():
			_query.transform.origin = _position + motion * collision_fraction \
					+ motion_direction * REST_PROBE_DISTANCE
			_query.motion = Vector3.ZERO
			rest_info = _space_state.get_rest_info(_query)
		if rest_info.is_empty():
			var failed_endpoint := _position + motion * collision_fraction
			if _capture_sampled_points:
				_points.append(failed_endpoint)
			_prediction = TrajectoryPrediction.new(
				TrajectoryPrediction.Kind.TIMEOUT,
				failed_endpoint,
				_points,
				(float(step_index) + collision_fraction) * PHYSICS_STEP,
				null,
				Vector3.ZERO,
				&"empty_rest_info_after_cast"
			)
			return
		var contact_point: Vector3 = rest_info.get(
			"point", _position + motion * collision_fraction
		)
		var normal: Vector3 = rest_info.get("normal", Vector3.ZERO)
		if not contact_point.is_finite() or normal.is_zero_approx():
			_prediction = TrajectoryPrediction.new(
				TrajectoryPrediction.Kind.TIMEOUT,
				_position + motion * collision_fraction,
				_points,
				(float(step_index) + collision_fraction) * PHYSICS_STEP,
				null,
				Vector3.ZERO,
				&"invalid_rest_contact"
			)
			return
		var endpoint := contact_point + normal.normalized() * _projectile_radius
		var collider_id := int(rest_info.get("collider_id", 0))
		var collider := instance_from_id(collider_id) if collider_id != 0 else null
		var hit_identity := _resolve_hit_identity(rest_info, collider, contact_point, normal)
		if _capture_sampled_points:
			_points.append(endpoint)
		_prediction = TrajectoryPrediction.new(
			TrajectoryPrediction.Kind.COLLISION,
			endpoint,
			_points,
			(float(step_index) + collision_fraction) * PHYSICS_STEP,
			collider,
			normal,
			&"" if hit_identity != null else &"missing_or_invalid_hit_identity",
			hit_identity,
			contact_point
		)
		return
	if bounds_fraction < 1.0:
		var exit_position := _position + motion * bounds_fraction
		if _capture_sampled_points:
			_points.append(exit_position)
		_prediction = TrajectoryPrediction.new(
			TrajectoryPrediction.Kind.BOUNDS_EXIT,
			exit_position,
			_points,
			(float(step_index) + bounds_fraction) * PHYSICS_STEP,
			null,
			Vector3.ZERO,
			&""
		)
		return
	_position = next_position
	if _capture_sampled_points:
		_points.append(_position)
	_step_index += 1
	if _step_index >= MAXIMUM_STEPS:
		_prediction = TrajectoryPrediction.new(
			TrajectoryPrediction.Kind.TIMEOUT,
			_position,
			_points,
			MAXIMUM_STEPS * PHYSICS_STEP,
			null,
			Vector3.ZERO,
			&"maximum_duration"
		)


static func _bounds_exit_fraction(
		start: Vector3, finish: Vector3, bounds: AABB
) -> float:
	if not bounds.has_point(start):
		return 0.0
	if bounds.has_point(finish):
		return 1.0
	var motion := finish - start
	var result := 1.0
	for axis in range(3):
		var component := motion[axis]
		if is_zero_approx(component):
			continue
		var boundary := bounds.position[axis] \
				if finish[axis] < bounds.position[axis] else bounds.end[axis]
		var fraction := (boundary - start[axis]) / component
		if fraction >= 0.0:
			result = minf(result, fraction)
	return clampf(result, 0.0, 1.0)


static func _gravity_vector() -> Vector3:
	var magnitude := float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8
	))
	var direction := Vector3(ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector", Vector3.DOWN
	))
	return direction.normalized() * magnitude


static func _resolve_hit_identity(
		rest_info: Dictionary,
		collider: Object,
		world_point: Vector3,
		world_normal: Vector3
) -> TrajectoryHitIdentity:
	var collision_object := collider as CollisionObject3D
	if collision_object == null:
		return null
	var body_shape_index := int(rest_info.get("shape", -1))
	if body_shape_index < 0:
		return null
	var owner_id := StringName(collision_object.get_meta(
		ContainmentSpec.CONTACT_OWNER_META, &""
	))
	var shape_id := _shape_contact_id(collision_object, body_shape_index)
	if String(owner_id).is_empty() or String(shape_id).is_empty():
		return null
	if owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
		var terrain_surface := _terrain_surface_for(collision_object)
		if terrain_surface == null:
			return null
		return terrain_surface.classify_top_hit(
			world_point, world_normal, shape_id, body_shape_index
		)
	var identity := TrajectoryHitIdentity.new(owner_id, shape_id, body_shape_index)
	return identity if identity.is_valid() else null


static func _shape_contact_id(
		collision_object: CollisionObject3D,
		body_shape_index: int
) -> StringName:
	var shape_owner_id := collision_object.shape_find_owner(body_shape_index)
	if shape_owner_id < 0:
		return &""
	var shape_owner := collision_object.shape_owner_get_owner(shape_owner_id)
	if shape_owner == null or not shape_owner.has_meta(
		ContainmentSpec.CONTACT_SHAPE_META
	):
		return &""
	return StringName(shape_owner.get_meta(ContainmentSpec.CONTACT_SHAPE_META, &""))


static func _terrain_surface_for(
		collision_object: CollisionObject3D
) -> TerrainSurface:
	var current := collision_object as Node
	while current != null:
		if current is TerrainSurface:
			return current as TerrainSurface
		current = current.get_parent()
	return null
