class_name PlayBoundsSpec
extends RefCounted

## Versioned non-colliding limits shared by prediction, live projectiles, and
## baked-layout identity. This class never creates wall geometry.
const CONTRACT_VERSION := 1
const FIXED_BOUNDS := AABB(Vector3(-190.0, -32.0, -230.0), Vector3(380.0, 222.0, 330.0))
const FIXED_APRON_XZ_BOUNDS := Rect2(Vector2(-170.0, -225.0), Vector2(340.0, 320.0))
const FIXED_APRON_Y := -2.0
const FIXED_APRON_BOTTOM_Y := -6.0
const FIXED_COLLISION_LAYER := 1
const FIXED_COLLISION_MASK := 2

const CONTACT_OWNER_META := &"contact_owner_id"
const CONTACT_SHAPE_META := &"contact_shape_id"
const APRON_OWNER_ID := &"world/apron"
const APRON_SHAPE_ID := &"ApronShape"

var contract_version: int:
	get: return _contract_version
var bounds: AABB:
	get: return _bounds
var apron_xz_bounds: Rect2:
	get: return _apron_xz_bounds
var apron_y: float:
	get: return _apron_y
var apron_bottom_y: float:
	get: return _apron_bottom_y
var collision_layer: int:
	get: return _collision_layer
var collision_mask: int:
	get: return _collision_mask

var _contract_version: int
var _bounds: AABB
var _apron_xz_bounds: Rect2
var _apron_y: float
var _apron_bottom_y: float
var _collision_layer: int
var _collision_mask: int


func _init(
		version: int = CONTRACT_VERSION,
		play_bounds: AABB = FIXED_BOUNDS,
		apron_bounds: Rect2 = FIXED_APRON_XZ_BOUNDS,
		apron_top_y: float = FIXED_APRON_Y,
		apron_base_y: float = FIXED_APRON_BOTTOM_Y,
		layer: int = FIXED_COLLISION_LAYER,
		mask: int = FIXED_COLLISION_MASK
) -> void:
	_contract_version = version
	_bounds = play_bounds
	_apron_xz_bounds = apron_bounds
	_apron_y = apron_top_y
	_apron_bottom_y = apron_base_y
	_collision_layer = layer
	_collision_mask = mask


func is_valid() -> bool:
	return _contract_version == CONTRACT_VERSION \
			and _bounds == FIXED_BOUNDS \
			and _apron_xz_bounds == FIXED_APRON_XZ_BOUNDS \
			and is_equal_approx(_apron_y, FIXED_APRON_Y) \
			and is_equal_approx(_apron_bottom_y, FIXED_APRON_BOTTOM_Y) \
			and _collision_layer == FIXED_COLLISION_LAYER \
			and _collision_mask == FIXED_COLLISION_MASK \
			and _bounds.size.x > 0.0 and _bounds.size.y > 0.0 and _bounds.size.z > 0.0 \
			and _apron_xz_bounds.has_area() and _apron_bottom_y < _apron_y


func supports_terrain(terrain_xz_bounds: Rect2, terrain_world_base_y: float) -> bool:
	return is_valid() and terrain_xz_bounds.has_area() \
			and terrain_xz_bounds.position.is_finite() \
			and terrain_xz_bounds.size.is_finite() \
			and _apron_xz_bounds.encloses(terrain_xz_bounds) \
			and is_equal_approx(terrain_world_base_y, _apron_y)


func checksum() -> int:
	var values := PackedInt64Array([
		_contract_version,
		_quantize(_bounds.position.x), _quantize(_bounds.position.y), _quantize(_bounds.position.z),
		_quantize(_bounds.size.x), _quantize(_bounds.size.y), _quantize(_bounds.size.z),
		_quantize(_apron_xz_bounds.position.x), _quantize(_apron_xz_bounds.position.y),
		_quantize(_apron_xz_bounds.size.x), _quantize(_apron_xz_bounds.size.y),
		_quantize(_apron_y), _quantize(_apron_bottom_y),
		_collision_layer, _collision_mask,
	])
	var hash: int = 2166136261
	for value in values:
		for shift in range(0, 64, 8):
			hash = hash ^ int((value >> shift) & 0xff)
			hash = int((hash * 16777619) & 0xffffffff)
	return hash


static func _quantize(value: float) -> int:
	return roundi(value * 1000.0)
