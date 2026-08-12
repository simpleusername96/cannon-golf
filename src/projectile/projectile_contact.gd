class_name ProjectileContact
extends RefCounted

var world_position: Vector3:
	get:
		return _world_position
var normal: Vector3:
	get:
		return _normal
var impact_center_position: Vector3:
	get:
		return _impact_center_position
var incoming_velocity: Vector3:
	get:
		return _incoming_velocity
var relative_normal_speed: float:
	get:
		return _relative_normal_speed
var impulse: Vector3:
	get:
		return _impulse
var impulse_was_measured: bool:
	get:
		return _impulse_was_measured
var contact_owner_id: StringName:
	get:
		return _contact_owner_id
var contact_shape_id: StringName:
	get:
		return _contact_shape_id
var collider: Object:
	get:
		return _collider
var collider_rid: RID:
	get:
		return _collider_rid
var collider_instance_id: int:
	get:
		return _collider_instance_id
var local_shape_index: int:
	get:
		return _local_shape_index
var collider_shape_index: int:
	get:
		return _collider_shape_index
var physics_tick: int:
	get:
		return _physics_tick
var source_event_index: int:
	get:
		return _source_event_index
var is_first_contact: bool:
	get:
		return _is_first_contact

var _world_position: Vector3
var _normal: Vector3
var _impact_center_position: Vector3
var _incoming_velocity: Vector3
var _relative_normal_speed: float
var _impulse: Vector3
var _impulse_was_measured: bool
var _contact_owner_id: StringName
var _contact_shape_id: StringName
var _collider: Object
var _collider_rid: RID
var _collider_instance_id: int
var _local_shape_index: int
var _collider_shape_index: int
var _physics_tick: int
var _source_event_index: int = -1
var _is_first_contact: bool
var _selection_distance_error: float


func _init(
		contact_world_position: Vector3 = Vector3.ZERO,
		contact_normal: Vector3 = Vector3.UP,
		contact_impact_center_position: Vector3 = Vector3.ZERO,
		contact_selection_distance_error: float = 0.0,
		contact_incoming_velocity: Vector3 = Vector3.ZERO,
		contact_relative_normal_speed: float = 0.0,
		contact_impulse: Vector3 = Vector3.ZERO,
		contact_collider: Object = null,
		contact_local_shape_index: int = -1,
		contact_collider_shape_index: int = -1,
		contact_physics_tick: int = 0,
		contact_is_first: bool = true,
		contact_impulse_was_measured: bool = false,
		contact_owner_id: StringName = &"",
		contact_shape_id: StringName = &"",
		contact_collider_rid: RID = RID()
) -> void:
	_world_position = contact_world_position
	_normal = contact_normal.normalized() if not contact_normal.is_zero_approx() else Vector3.UP
	_impact_center_position = contact_impact_center_position
	_selection_distance_error = maxf(contact_selection_distance_error, 0.0)
	_incoming_velocity = contact_incoming_velocity
	_relative_normal_speed = maxf(contact_relative_normal_speed, 0.0)
	_impulse = contact_impulse
	_impulse_was_measured = contact_impulse_was_measured
	_contact_owner_id = contact_owner_id
	_contact_shape_id = contact_shape_id
	_collider = contact_collider
	_collider_rid = contact_collider_rid
	if not _collider_rid.is_valid() and contact_collider is CollisionObject3D:
		_collider_rid = (contact_collider as CollisionObject3D).get_rid()
	_collider_instance_id = contact_collider.get_instance_id() if is_instance_valid(contact_collider) else 0
	_local_shape_index = contact_local_shape_index
	_collider_shape_index = contact_collider_shape_index
	_physics_tick = contact_physics_tick
	_is_first_contact = contact_is_first


func assign_source_event_index(event_index: int) -> void:
	assert(event_index >= 0, "Projectile contacts require a nonnegative stable event index.")
	assert(_source_event_index < 0, "Projectile contact event index may be assigned only once.")
	_source_event_index = event_index


func has_stable_identity() -> bool:
	return _collider_rid.is_valid() and not String(_contact_owner_id).is_empty() \
			and not String(_contact_shape_id).is_empty() \
			and _local_shape_index >= 0 and _collider_shape_index >= 0


func same_collider_shape(other: ProjectileContact) -> bool:
	return other != null and _collider_rid == other.collider_rid \
			and _contact_owner_id == other.contact_owner_id \
			and _contact_shape_id == other.contact_shape_id \
			and _collider_shape_index == other.collider_shape_index
