class_name TrajectoryHitIdentity
extends RefCounted

const TERRAIN_TOP_OWNER_ID := &"terrain/top"
const TERRAIN_TOP_SHAPE_ID := &"TerrainTopShape"

var contact_owner_id: StringName:
	get:
		return _contact_owner_id
var contact_shape_id: StringName:
	get:
		return _contact_shape_id
var body_shape_index: int:
	get:
		return _body_shape_index
var terrain_cell: Vector2i:
	get:
		return _terrain_cell
var terrain_triangle: int:
	get:
		return _terrain_triangle
var barycentric: Vector3:
	get:
		return _barycentric

var _contact_owner_id: StringName
var _contact_shape_id: StringName
var _body_shape_index: int
var _terrain_cell: Vector2i
var _terrain_triangle: int
var _barycentric: Vector3


func _init(
		owner_id: StringName = &"",
		shape_id: StringName = &"",
		physics_body_shape_index: int = -1,
		cell: Vector2i = Vector2i(-1, -1),
		triangle: int = -1,
		triangle_barycentric: Vector3 = Vector3.ZERO
) -> void:
	_contact_owner_id = owner_id
	_contact_shape_id = shape_id
	_body_shape_index = physics_body_shape_index
	_terrain_cell = cell
	_terrain_triangle = triangle
	_barycentric = triangle_barycentric


func is_valid() -> bool:
	if String(_contact_owner_id).is_empty() or String(_contact_shape_id).is_empty() \
			or _body_shape_index < 0:
		return false
	if _contact_owner_id != TERRAIN_TOP_OWNER_ID:
		return _terrain_cell == Vector2i(-1, -1) and _terrain_triangle == -1 \
				and _barycentric.is_zero_approx()
	return _terrain_cell.x >= 0 and _terrain_cell.y >= 0 \
			and _terrain_triangle in [0, 1] \
			and _barycentric.is_finite() \
			and _barycentric.x >= -0.0001 \
			and _barycentric.y >= -0.0001 \
			and _barycentric.z >= -0.0001 \
			and absf(_barycentric.x + _barycentric.y + _barycentric.z - 1.0) <= 0.0001


func stable_key() -> StringName:
	return StringName("%s|%s|%d|%d,%d|%d" % [
		String(_contact_owner_id), String(_contact_shape_id), _body_shape_index,
		_terrain_cell.x, _terrain_cell.y, _terrain_triangle,
	])


func has_same_surface_address(other: TrajectoryHitIdentity) -> bool:
	return other != null and _contact_owner_id == other.contact_owner_id \
			and _contact_shape_id == other.contact_shape_id \
			and _body_shape_index == other.body_shape_index \
			and _terrain_cell == other.terrain_cell \
			and _terrain_triangle == other.terrain_triangle


static func terrain_top(
		shape_id: StringName,
		physics_body_shape_index: int,
		cell: Vector2i,
		triangle: int,
		triangle_barycentric: Vector3
) -> TrajectoryHitIdentity:
	var identity := TrajectoryHitIdentity.new(
		TERRAIN_TOP_OWNER_ID,
		shape_id,
		physics_body_shape_index,
		cell,
		triangle,
		triangle_barycentric
	)
	if not identity.is_valid():
		return null
	return identity
