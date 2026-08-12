class_name SurfacePaintSweep
extends RefCounted

const COMMAND_ORDER := 1

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
var from_point: Vector3:
	get:
		return _from_point
var to_point: Vector3:
	get:
		return _to_point
var from_normal: Vector3:
	get:
		return _from_normal
var to_normal: Vector3:
	get:
		return _to_normal
var footprint_radius: float:
	get:
		return _footprint_radius
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
var bridged_gap: bool:
	get:
		return _bridged_gap
var shot_id: int:
	get:
		return _shot_id

var _physics_tick: int
var _spawn_ordinal: int
var _source_event_index: int
var _sequence: int
var _from_point: Vector3
var _to_point: Vector3
var _from_normal: Vector3
var _to_normal: Vector3
var _footprint_radius: float
var _top_collider_rid: RID
var _contact_owner_id: StringName
var _contact_shape_id: StringName
var _collider_shape_index: int
var _bridged_gap: bool
var _shot_id: int


func _init(
		command_physics_tick: int = -1,
		command_spawn_ordinal: int = -1,
		command_source_event_index: int = -1,
		command_sequence: int = -1,
		command_from_point: Vector3 = Vector3.ZERO,
		command_to_point: Vector3 = Vector3.ZERO,
		command_from_normal: Vector3 = Vector3.ZERO,
		command_to_normal: Vector3 = Vector3.ZERO,
		command_footprint_radius: float = 0.0,
		command_top_collider_rid: RID = RID(),
		command_contact_owner_id: StringName = &"",
		command_contact_shape_id: StringName = &"",
		command_collider_shape_index: int = -1,
		command_bridged_gap: bool = false,
		command_shot_id: int = 1
) -> void:
	_physics_tick = command_physics_tick
	_spawn_ordinal = command_spawn_ordinal
	_source_event_index = command_source_event_index
	_sequence = command_sequence
	_from_point = command_from_point
	_to_point = command_to_point
	_from_normal = command_from_normal.normalized() if not command_from_normal.is_zero_approx() else Vector3.ZERO
	_to_normal = command_to_normal.normalized() if not command_to_normal.is_zero_approx() else Vector3.ZERO
	_footprint_radius = command_footprint_radius
	_top_collider_rid = command_top_collider_rid
	_contact_owner_id = command_contact_owner_id
	_contact_shape_id = command_contact_shape_id
	_collider_shape_index = command_collider_shape_index
	_bridged_gap = command_bridged_gap
	_shot_id = command_shot_id


func is_intent_valid() -> bool:
	return _physics_tick >= 0 and _spawn_ordinal >= 0 and _source_event_index >= 0 \
			and _shot_id > 0 \
			and _from_point.is_finite() and _to_point.is_finite() \
			and _from_normal.is_finite() and not _from_normal.is_zero_approx() \
			and _to_normal.is_finite() and not _to_normal.is_zero_approx() \
			and is_finite(_footprint_radius) and _footprint_radius > 0.0 \
			and _top_collider_rid.is_valid() \
			and not String(_contact_owner_id).is_empty() \
			and not String(_contact_shape_id).is_empty() \
			and _collider_shape_index >= 0


func is_valid() -> bool:
	return is_intent_valid() and _sequence >= 0


func queue_sort_key() -> Array:
	return [
		_physics_tick, _spawn_ordinal, _source_event_index, COMMAND_ORDER,
		String(_contact_owner_id), String(_contact_shape_id),
	]


func drain_sort_key() -> PackedInt64Array:
	return PackedInt64Array([_physics_tick, _spawn_ordinal, _sequence])


func with_sequence(assigned_sequence: int) -> SurfacePaintSweep:
	return SurfacePaintSweep.new(
		_physics_tick, _spawn_ordinal, _source_event_index, assigned_sequence,
		_from_point, _to_point, _from_normal, _to_normal, _footprint_radius,
		_top_collider_rid, _contact_owner_id, _contact_shape_id,
			_collider_shape_index, _bridged_gap, _shot_id
	)
