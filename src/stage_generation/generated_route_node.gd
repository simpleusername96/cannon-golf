class_name GeneratedRouteNode
extends RefCounted

enum Kind {
	SUMMIT,
	CORRIDOR,
	PAD,
	EXIT,
}

var id: StringName:
	get:
		return _id
var position: Vector3:
	get:
		return _position
var route_index: int:
	get:
		return _route_index
var station_index: int:
	get:
		return _station_index
var kind: Kind:
	get:
		return _kind
var mechanism_kind: int:
	get:
		return _mechanism_kind
var pad_radius: float:
	get:
		return _pad_radius

var _id: StringName
var _position: Vector3
var _route_index: int
var _station_index: int
var _kind: Kind
var _mechanism_kind: int
var _pad_radius: float


func _init(
		node_id: StringName = &"",
		node_position: Vector3 = Vector3.ZERO,
		node_route_index: int = -1,
		node_station_index: int = -1,
		node_kind: Kind = Kind.CORRIDOR,
		node_mechanism_kind: int = -1,
		node_pad_radius: float = 0.0
) -> void:
	_id = node_id
	_position = node_position
	_route_index = node_route_index
	_station_index = node_station_index
	_kind = node_kind
	_mechanism_kind = node_mechanism_kind
	_pad_radius = node_pad_radius


func is_valid() -> bool:
	if String(_id).is_empty() or not _position.is_finite() or _station_index < 0:
		return false
	if _kind < Kind.SUMMIT or _kind > Kind.EXIT:
		return false
	if _kind == Kind.SUMMIT:
		return _route_index == -1 and _station_index == 0 \
				and _mechanism_kind == -1 and is_zero_approx(_pad_radius)
	if _route_index < 0:
		return false
	if _kind == Kind.PAD:
		return _mechanism_kind >= 0 and _pad_radius > 0.0 and is_finite(_pad_radius)
	return _mechanism_kind == -1 and is_zero_approx(_pad_radius)


func sort_key() -> Array:
	return [_route_index, _station_index, int(_kind), String(_id)]


static func summit_id(stage_id: StringName) -> StringName:
	return StringName("%s/summit" % String(stage_id))


static func route_node_id(stage_id: StringName, route: int, station: int) -> StringName:
	return StringName("%s/route/%d/node/%d" % [String(stage_id), route, station])


static func pad_id(
		stage_id: StringName,
		route: int,
		original_edge: int,
		mechanism: int
) -> StringName:
	return StringName("%s/route/%d/edge/%d/pad/%d" % [
		String(stage_id), route, original_edge, mechanism,
	])
