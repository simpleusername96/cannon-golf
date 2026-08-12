class_name GeneratedRouteEdge
extends RefCounted

var id: StringName:
	get:
		return _id
var from_node_id: StringName:
	get:
		return _from_node_id
var to_node_id: StringName:
	get:
		return _to_node_id
var route_index: int:
	get:
		return _route_index
var edge_index: int:
	get:
		return _edge_index
var role: int:
	get:
		return _role
var width: float:
	get:
		return _width

var _id: StringName
var _from_node_id: StringName
var _to_node_id: StringName
var _route_index: int
var _edge_index: int
var _role: int
var _width: float


func _init(
		edge_id: StringName = &"",
		edge_from_node_id: StringName = &"",
		edge_to_node_id: StringName = &"",
		edge_route_index: int = -1,
		edge_index_in_route: int = -1,
		edge_role: int = StageRouteProfile.Role.PRIMARY,
		edge_width: float = 0.0
) -> void:
	_id = edge_id
	_from_node_id = edge_from_node_id
	_to_node_id = edge_to_node_id
	_route_index = edge_route_index
	_edge_index = edge_index_in_route
	_role = edge_role
	_width = edge_width


func is_valid() -> bool:
	return not String(_id).is_empty() \
			and not String(_from_node_id).is_empty() \
			and not String(_to_node_id).is_empty() \
			and _from_node_id != _to_node_id \
			and _route_index >= 0 \
			and _edge_index >= 0 \
			and _role >= StageRouteProfile.Role.PRIMARY \
			and _role <= StageRouteProfile.Role.BUMPER \
			and is_finite(_width) \
			and _width > 0.0


func sort_key() -> Array:
	return [_route_index, _edge_index, String(_id)]


static func stable_id(
		stage_id: StringName,
		route: int,
		original_edge: int,
		split_suffix: StringName = &""
) -> StringName:
	var suffix := "" if String(split_suffix).is_empty() else "/%s" % String(split_suffix)
	return StringName("%s/route/%d/edge/%d%s" % [
		String(stage_id), route, original_edge, suffix,
	])
