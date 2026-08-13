class_name CannonGolfGeneratedCourse
extends RefCounted

## Immutable geometry and admission product shared by preview and gameplay.

var layout: GeneratedStageLayout:
	get:
		return _copy_layout(_layout)
	set(value):
		_assert_writable()
		_layout = value
var geometry: TerrainGeometry:
	get:
		return _copy_geometry(_geometry)
	set(value):
		_assert_writable()
		_geometry = value
var route_graph: GeneratedRouteGraph:
	get:
		return _copy_route_graph(_route_graph)
	set(value):
		_assert_writable()
		_route_graph = _copy_route_graph(value)
var source_route_graph: GeneratedRouteGraph:
	get:
		return _copy_route_graph(_source_route_graph)
	set(value):
		_assert_writable()
		_source_route_graph = _copy_route_graph(value)
var source_heights: PackedFloat32Array:
	get:
		return _source_heights.duplicate()
	set(value):
		_assert_writable()
		_source_heights = value.duplicate()
var source_footprint: PackedByteArray:
	get:
		return _source_footprint.duplicate()
	set(value):
		_assert_writable()
		_source_footprint = value.duplicate()
var legs: Array[CannonGolfGeneratedCourseLeg]:
	get:
		return _legs.duplicate()
var admission_points := PackedVector3Array():
	get:
		return admission_points.duplicate()
	set(value):
		_assert_writable()
		admission_points = value.duplicate()
var union_range_metrics: Dictionary = {}:
	get:
		return union_range_metrics.duplicate(true)
	set(value):
		_assert_writable()
		union_range_metrics = value.duplicate(true)
var content_bounds := AABB():
	set(value):
		_assert_writable()
		content_bounds = value
var play_bounds := AABB():
	set(value):
		_assert_writable()
		play_bounds = value

var _sealed := false
var _legs: Array[CannonGolfGeneratedCourseLeg] = []
var _layout: GeneratedStageLayout
var _geometry: TerrainGeometry
var _route_graph: GeneratedRouteGraph
var _source_route_graph: GeneratedRouteGraph
var _source_heights := PackedFloat32Array()
var _source_footprint := PackedByteArray()


func add_leg(leg: CannonGolfGeneratedCourseLeg) -> void:
	_assert_writable()
	assert(leg != null and leg.is_valid(), "Generated course requires a complete leg.")
	_legs.append(leg)


func seal() -> void:
	assert(is_valid(), "Only complete generated course data may be sealed.")
	for leg in _legs:
		leg.seal()
	_sealed = true


func is_sealed() -> bool:
	return _sealed


func leg_count() -> int:
	return _legs.size()


func leg_at(index: int) -> CannonGolfGeneratedCourseLeg:
	if index < 0 or index >= _legs.size():
		return null
	return _legs[index]


func is_valid() -> bool:
	if _layout == null or _geometry == null or _route_graph == null or _legs.is_empty() \
			or admission_points.is_empty() or union_range_metrics.is_empty() \
			or not content_bounds.has_volume() or not play_bounds.has_volume():
		return false
	for leg in _legs:
		if leg == null or not leg.is_valid():
			return false
	return true


func _assert_writable() -> void:
	assert(not _sealed, "Generated course data is immutable after generation.")


func _copy_layout(source: GeneratedStageLayout) -> GeneratedStageLayout:
	if source == null:
		return null
	var result := GeneratedStageLayout.new()
	result.profile_id = source.profile_id
	result.profile_version = source.profile_version
	result.layout_version = source.layout_version
	result.terrain_seed = source.terrain_seed
	result.cell_count = source.cell_count
	result.local_bounds = source.local_bounds
	result.heights = source.heights.duplicate()
	result.top_topology = source.top_topology
	result.route_graph = _copy_route_graph(source.route_graph)
	result.play_bounds = PlayBoundsSpec.new(
		source.play_bounds.contract_version,
		source.play_bounds.bounds,
		source.play_bounds.apron_xz_bounds,
		source.play_bounds.apron_y,
		source.play_bounds.apron_bottom_y,
		source.play_bounds.collision_layer,
		source.play_bounds.collision_mask
	)
	result.install_footprint(source.footprint_cells_read_only())
	return result


func _copy_geometry(source: TerrainGeometry) -> TerrainGeometry:
	if source == null:
		return null
	var result := TerrainGeometry.new()
	result.render_mesh = source.render_mesh.duplicate(false) as ArrayMesh
	result.top_shape = source.top_shape.duplicate(false) as ConcavePolygonShape3D
	result.skirt_shape = source.skirt_shape.duplicate(false) as ConcavePolygonShape3D
	result.top_topology = source.top_topology
	result.local_bounds = source.local_bounds
	result.base_y = source.base_y
	result.top_vertex_count = source.top_vertex_count
	result.shell_vertex_count = source.shell_vertex_count
	result.top_triangle_count = source.top_triangle_count
	result.skirt_triangle_count = source.skirt_triangle_count
	result.bottom_triangle_count = source.bottom_triangle_count
	result.top_render_source_vertex_indices = source.top_render_source_vertex_indices.duplicate()
	result.top_render_source_triangle_ids = source.top_render_source_triangle_ids.duplicate()
	return result


func _copy_route_graph(source: GeneratedRouteGraph) -> GeneratedRouteGraph:
	if source == null:
		return null
	var nodes: Array[GeneratedRouteNode] = []
	for node in source.nodes:
		nodes.append(GeneratedRouteNode.new(
			node.id,
			node.position,
			node.route_index,
			node.station_index,
			node.kind,
			node.mechanism_kind,
			node.pad_radius
		))
	var edges: Array[GeneratedRouteEdge] = []
	for edge in source.edges:
		edges.append(GeneratedRouteEdge.new(
			edge.id,
			edge.from_node_id,
			edge.to_node_id,
			edge.route_index,
			edge.edge_index,
			edge.role,
			edge.width
		))
	return GeneratedRouteGraph.new(nodes, edges)
