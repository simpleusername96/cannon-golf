class_name GeneratedRouteGraph
extends RefCounted

var nodes: Array[GeneratedRouteNode]:
	get:
		return _nodes.duplicate()
var edges: Array[GeneratedRouteEdge]:
	get:
		return _edges.duplicate()

var _nodes: Array[GeneratedRouteNode] = []
var _edges: Array[GeneratedRouteEdge] = []
var _node_index_by_id: Dictionary = {}
var _edge_index_by_id: Dictionary = {}
var _edge_indices_by_route: Dictionary = {}
var _has_unique_ids: bool = true


func _init(
		graph_nodes: Array[GeneratedRouteNode] = [],
		graph_edges: Array[GeneratedRouteEdge] = []
) -> void:
	for node in graph_nodes:
		_nodes.append(node)
	for edge in graph_edges:
		_edges.append(edge)
	_build_indices()


func is_valid() -> bool:
	if _nodes.is_empty() or _edges.is_empty() or not _has_unique_ids:
		return false
	var summit_count := 0
	var summit_id: StringName
	for node in _nodes:
		if node == null or not node.is_valid():
			return false
		if node.kind == GeneratedRouteNode.Kind.SUMMIT:
			summit_count += 1
			summit_id = node.id
	for edge in _edges:
		if edge == null or not edge.is_valid():
			return false
		if not _node_index_by_id.has(edge.from_node_id) \
				or not _node_index_by_id.has(edge.to_node_id):
			return false
	if summit_count != 1:
		return false
	var reference_counts: Dictionary = {}
	for route_index in range(route_count()):
		var route := route_edges(route_index)
		if route.is_empty():
			return false
		if route[0].from_node_id != summit_id \
				or node_by_id(route[-1].to_node_id).kind != GeneratedRouteNode.Kind.EXIT:
			return false
		var route_role := route[0].role
		var route_width := route[0].width
		for edge_index in range(route.size()):
			var edge := route[edge_index]
			if edge.edge_index != edge_index or edge.role != route_role \
					or not is_equal_approx(edge.width, route_width):
				return false
			if edge_index > 0 and route[edge_index - 1].to_node_id != edge.from_node_id:
				return false
			var from_node := node_by_id(edge.from_node_id)
			var to_node := node_by_id(edge.to_node_id)
			if (from_node.kind != GeneratedRouteNode.Kind.SUMMIT \
					and from_node.route_index != route_index) \
					or to_node.route_index != route_index:
				return false
			reference_counts[edge.from_node_id] = int(reference_counts.get(edge.from_node_id, 0)) + 1
			reference_counts[edge.to_node_id] = int(reference_counts.get(edge.to_node_id, 0)) + 1
	if _edge_indices_by_route.size() != route_count():
		return false
	for node in _nodes:
		var expected_references := route_count() if node.kind == GeneratedRouteNode.Kind.SUMMIT else 1
		if node.kind == GeneratedRouteNode.Kind.CORRIDOR or node.kind == GeneratedRouteNode.Kind.PAD:
			expected_references = 2
		if int(reference_counts.get(node.id, 0)) != expected_references:
			return false
	return true


func node_index(node_id: StringName) -> int:
	return int(_node_index_by_id.get(node_id, -1))


func edge_index(edge_id: StringName) -> int:
	return int(_edge_index_by_id.get(edge_id, -1))


func node_by_id(node_id: StringName) -> GeneratedRouteNode:
	var index := node_index(node_id)
	return _nodes[index] if index >= 0 else null


func edge_by_id(edge_id: StringName) -> GeneratedRouteEdge:
	var index := edge_index(edge_id)
	return _edges[index] if index >= 0 else null


func node_index_map() -> Dictionary:
	return _node_index_by_id.duplicate()


func edge_index_map() -> Dictionary:
	return _edge_index_by_id.duplicate()


func route_count() -> int:
	var count := 0
	for key in _edge_indices_by_route:
		count = maxi(count, int(key) + 1)
	return count


func route_edges(route_index: int) -> Array[GeneratedRouteEdge]:
	var result: Array[GeneratedRouteEdge] = []
	for edge_index in _edge_indices_by_route.get(route_index, PackedInt32Array()):
		result.append(_edges[edge_index])
	return result


func route_nodes(route_index: int) -> Array[GeneratedRouteNode]:
	var route := route_edges(route_index)
	var result: Array[GeneratedRouteNode] = []
	if route.is_empty():
		return result
	result.append(node_by_id(route[0].from_node_id))
	for edge in route:
		result.append(node_by_id(edge.to_node_id))
	return result


func route_role(route_index: int) -> int:
	var route := route_edges(route_index)
	return route[0].role if not route.is_empty() else -1


func route_width(route_index: int) -> float:
	var route := route_edges(route_index)
	return route[0].width if not route.is_empty() else 0.0


func route_index_for_role(role: int) -> int:
	for route_index in range(route_count()):
		if route_role(route_index) == role:
			return route_index
	return -1


func pad_nodes() -> Array[GeneratedRouteNode]:
	var result: Array[GeneratedRouteNode] = []
	for node in _nodes:
		if node.kind == GeneratedRouteNode.Kind.PAD:
			result.append(node)
	return result


func pad_node_for_kind(mechanism_kind: int) -> GeneratedRouteNode:
	for node in _nodes:
		if node.kind == GeneratedRouteNode.Kind.PAD and node.mechanism_kind == mechanism_kind:
			return node
	return null


func pad_nodes_for_kind(mechanism_kind: int) -> Array[GeneratedRouteNode]:
	var result: Array[GeneratedRouteNode] = []
	for node in _nodes:
		if node.kind == GeneratedRouteNode.Kind.PAD and node.mechanism_kind == mechanism_kind:
			result.append(node)
	return result


func route_position(route_index: int, normalized_arc_position: float) -> Vector3:
	var route := route_edges(route_index)
	if route.is_empty():
		return Vector3.ZERO
	var lengths := PackedFloat32Array()
	var total_length := 0.0
	for edge in route:
		var from := node_by_id(edge.from_node_id).position
		var to := node_by_id(edge.to_node_id).position
		var length := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
		lengths.append(length)
		total_length += length
	if total_length <= 0.0:
		return node_by_id(route[0].from_node_id).position
	var requested_length := clampf(normalized_arc_position, 0.0, 1.0) * total_length
	var traversed := 0.0
	for index in range(route.size()):
		var segment_end := traversed + lengths[index]
		if requested_length <= segment_end or index == route.size() - 1:
			var local_t := (requested_length - traversed) / maxf(lengths[index], 0.000001)
			return node_by_id(route[index].from_node_id).position.lerp(
				node_by_id(route[index].to_node_id).position,
				clampf(local_t, 0.0, 1.0)
			)
		traversed = segment_end
	return node_by_id(route[-1].to_node_id).position


func route_tangent(route_index: int, normalized_arc_position: float, sample_delta: float = 0.02) -> Vector3:
	var before := route_position(route_index, maxf(0.0, normalized_arc_position - sample_delta))
	var after := route_position(route_index, minf(1.0, normalized_arc_position + sample_delta))
	return Vector3(after.x - before.x, 0.0, after.z - before.z).normalized()


func route_normalized_t_for_node(route_index: int, node_id: StringName) -> float:
	var route := route_edges(route_index)
	if route.is_empty():
		return -1.0
	var total_length := 0.0
	var distance_to_node := -1.0
	if route[0].from_node_id == node_id:
		distance_to_node = 0.0
	for edge in route:
		var from := node_by_id(edge.from_node_id).position
		var to := node_by_id(edge.to_node_id).position
		var length := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
		total_length += length
		if edge.to_node_id == node_id:
			distance_to_node = total_length
	if distance_to_node < 0.0 or total_length <= 0.0:
		return -1.0
	return distance_to_node / total_length


func nearest_edge(local_xz: Vector2) -> Dictionary:
	var best_distance := INF
	var best_edge: GeneratedRouteEdge
	var best_t := 0.0
	var best_position := Vector3.ZERO
	for edge in _edges:
		var from := node_by_id(edge.from_node_id).position
		var to := node_by_id(edge.to_node_id).position
		var from_xz := Vector2(from.x, from.z)
		var to_xz := Vector2(to.x, to.z)
		var delta := to_xz - from_xz
		var length_squared := delta.length_squared()
		var t := clampf((local_xz - from_xz).dot(delta) / maxf(length_squared, 0.000001), 0.0, 1.0)
		var closest := from_xz.lerp(to_xz, t)
		var distance := local_xz.distance_to(closest)
		if distance < best_distance:
			best_distance = distance
			best_edge = edge
			best_t = t
			best_position = from.lerp(to, t)
	return {
		"distance": best_distance,
		"edge": best_edge,
		"route_index": best_edge.route_index if best_edge != null else -1,
		"edge_index": best_edge.edge_index if best_edge != null else -1,
		"edge_t": best_t,
		"position": best_position,
	}


func route_reversal_count(route_index: int) -> int:
	var route := route_edges(route_index)
	var previous_sign := 0
	var reversals := 0
	for edge in route:
		var delta := node_by_id(edge.to_node_id).position.y - node_by_id(edge.from_node_id).position.y
		if is_zero_approx(delta):
			continue
		var current_sign := 1 if delta > 0.0 else -1
		if previous_sign != 0 and current_sign != previous_sign:
			reversals += 1
		previous_sign = current_sign
	return reversals


func _build_indices() -> void:
	for index in range(_nodes.size()):
		var node := _nodes[index]
		if node == null or _node_index_by_id.has(node.id):
			_has_unique_ids = false
			continue
		_node_index_by_id[node.id] = index
	for index in range(_edges.size()):
		var edge := _edges[index]
		if edge == null or _edge_index_by_id.has(edge.id):
			_has_unique_ids = false
			continue
		_edge_index_by_id[edge.id] = index
		if not _edge_indices_by_route.has(edge.route_index):
			_edge_indices_by_route[edge.route_index] = PackedInt32Array()
		var route_indices: PackedInt32Array = _edge_indices_by_route[edge.route_index]
		route_indices.append(index)
		_edge_indices_by_route[edge.route_index] = route_indices
