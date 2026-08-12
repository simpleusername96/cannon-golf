class_name TerrainAimTarget
extends RefCounted

## Immutable canonical address of one playable terrain point selected for aiming.
var world_point: Vector3:
	get:
		return _world_point
var world_normal: Vector3:
	get:
		return _world_normal
var hit_identity: TrajectoryHitIdentity:
	get:
		return _hit_identity
var revision_key: StringName:
	get:
		return _revision_key

var _world_point: Vector3
var _world_normal: Vector3
var _hit_identity: TrajectoryHitIdentity
var _revision_key: StringName


func _init(
		point: Vector3,
		normal: Vector3,
		identity: TrajectoryHitIdentity
) -> void:
	assert(point.is_finite(), "Terrain aim target point must be finite.")
	assert(normal.is_finite() and normal.length_squared() > 0.0,
			"Terrain aim target normal must be finite and non-zero.")
	assert(identity != null and identity.is_valid() \
			and identity.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
			"Terrain aim target requires a valid terrain-top identity.")
	_world_point = point
	_world_normal = normal.normalized()
	_hit_identity = identity
	_revision_key = _stable_revision_key()


func _stable_revision_key() -> StringName:
	return StringName("%s|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f" % [
		String(_hit_identity.stable_key()),
		_world_point.x, _world_point.y, _world_point.z,
		_world_normal.x, _world_normal.y, _world_normal.z,
	])
