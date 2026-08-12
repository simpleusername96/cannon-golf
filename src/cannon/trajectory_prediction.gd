class_name TrajectoryPrediction
extends RefCounted

enum Kind {
	COLLISION,
	BOUNDS_EXIT,
	TIMEOUT,
}

var kind: Kind:
	get:
		return _kind
var endpoint: Vector3:
	get:
		return _endpoint
var contact_point: Variant:
	get:
		return _contact_point
var sampled_points: PackedVector3Array:
	get:
		return _sampled_points.duplicate()
var duration: float:
	get:
		return _duration
var collider: Object:
	get:
		return _collider
var normal: Vector3:
	get:
		return _normal
var diagnostic: StringName:
	get:
		return _diagnostic
var hit_identity: TrajectoryHitIdentity:
	get:
		return _hit_identity

var _kind: Kind
var _endpoint: Vector3
var _contact_point: Variant = null
var _sampled_points: PackedVector3Array
var _duration: float
var _collider: Object
var _normal: Vector3
var _diagnostic: StringName
var _hit_identity: TrajectoryHitIdentity


func _init(
		prediction_kind: Kind = Kind.TIMEOUT,
		prediction_endpoint: Vector3 = Vector3.ZERO,
		prediction_points: PackedVector3Array = PackedVector3Array(),
		prediction_duration: float = 0.0,
		prediction_collider: Object = null,
		prediction_normal: Vector3 = Vector3.ZERO,
		prediction_diagnostic: StringName = &"",
		prediction_hit_identity: TrajectoryHitIdentity = null,
		prediction_contact_point: Variant = null
) -> void:
	_kind = prediction_kind
	_endpoint = prediction_endpoint
	_sampled_points = prediction_points.duplicate()
	_duration = maxf(prediction_duration, 0.0)
	_collider = prediction_collider
	_normal = prediction_normal.normalized() if not prediction_normal.is_zero_approx() else Vector3.ZERO
	_diagnostic = prediction_diagnostic
	_hit_identity = prediction_hit_identity
	_contact_point = prediction_contact_point if prediction_contact_point is Vector3 \
			and (prediction_contact_point as Vector3).is_finite() else null


func is_fireable() -> bool:
	return kind == Kind.COLLISION


func collision_contact_point() -> Vector3:
	assert(
		_kind == Kind.COLLISION and _contact_point is Vector3,
		"Only collision predictions expose a surface contact point."
	)
	return _contact_point as Vector3
