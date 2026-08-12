class_name RadialPaintMark
extends RefCounted

enum Kind {
	IMPACT,
	SETTLE,
	BURST,
}

var physics_tick: int:
	get:
		return _physics_tick
var spawn_ordinal: int:
	get:
		return _spawn_ordinal
var source_event_index: int:
	get:
		return _source_event_index
var sequence: int:
	get:
		return _sequence
var center: Vector3:
	get:
		return _center
var normal: Vector3:
	get:
		return _normal
var radius: float:
	get:
		return _radius
var top_collider_rid: RID:
	get:
		return _top_collider_rid
var contact_owner_id: StringName:
	get:
		return _contact_owner_id
var contact_shape_id: StringName:
	get:
		return _contact_shape_id
var collider_shape_index: int:
	get:
		return _collider_shape_index
var kind: Kind:
	get:
		return _kind
var shot_id: int:
	get:
		return _shot_id

var _physics_tick: int
var _spawn_ordinal: int
var _source_event_index: int
var _sequence: int
var _center: Vector3
var _normal: Vector3
var _radius: float
var _top_collider_rid: RID
var _contact_owner_id: StringName
var _contact_shape_id: StringName
var _collider_shape_index: int
var _kind: Kind
var _shot_id: int


func _init(
		command_physics_tick: int = -1,
		command_spawn_ordinal: int = -1,
		command_source_event_index: int = -1,
		command_sequence: int = -1,
		command_center: Vector3 = Vector3.ZERO,
		command_normal: Vector3 = Vector3.ZERO,
		command_radius: float = 0.0,
		command_top_collider_rid: RID = RID(),
		command_contact_owner_id: StringName = &"",
		command_contact_shape_id: StringName = &"",
		command_collider_shape_index: int = -1,
		command_kind: Kind = Kind.IMPACT,
		command_shot_id: int = 1
) -> void:
	_physics_tick = command_physics_tick
	_spawn_ordinal = command_spawn_ordinal
	_source_event_index = command_source_event_index
	_sequence = command_sequence
	_center = command_center
	_normal = command_normal.normalized() if not command_normal.is_zero_approx() else Vector3.ZERO
	_radius = command_radius
	_top_collider_rid = command_top_collider_rid
	_contact_owner_id = command_contact_owner_id
	_contact_shape_id = command_contact_shape_id
	_collider_shape_index = command_collider_shape_index
	_kind = command_kind
	_shot_id = command_shot_id


func is_intent_valid() -> bool:
	return _physics_tick >= 0 and _spawn_ordinal >= 0 and _source_event_index >= 0 \
			and _shot_id > 0 \
			and _center.is_finite() and _normal.is_finite() \
			and not _normal.is_zero_approx() and is_finite(_radius) and _radius > 0.0 \
			and _top_collider_rid.is_valid() \
			and not String(_contact_owner_id).is_empty() \
			and not String(_contact_shape_id).is_empty() \
			and _collider_shape_index >= 0 \
			and _kind >= Kind.IMPACT and _kind <= Kind.BURST


func is_valid() -> bool:
	return is_intent_valid() and _sequence >= 0


func command_order() -> int:
	match _kind:
		Kind.IMPACT:
			return 0
		Kind.BURST:
			return 2
		_:
			return 3


func queue_sort_key() -> Array:
	return [
		_physics_tick, _spawn_ordinal, _source_event_index, command_order(),
		String(_contact_owner_id), String(_contact_shape_id),
	]


func drain_sort_key() -> PackedInt64Array:
	return PackedInt64Array([_physics_tick, _spawn_ordinal, _sequence])


func with_sequence(assigned_sequence: int) -> RadialPaintMark:
	return RadialPaintMark.new(
		_physics_tick, _spawn_ordinal, _source_event_index, assigned_sequence,
		_center, _normal, _radius, _top_collider_rid, _contact_owner_id,
		_contact_shape_id, _collider_shape_index, _kind, _shot_id
	)
