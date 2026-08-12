class_name TerrainGeometryBuildJob
extends RefCounted

## Cooperative form of TerrainGeometryFactory.build(). Each call processes
## bounded triangle work; render/physics resource creation remains on the main
## thread in separate phases.
enum Phase {
	TOP,
	SKIRTS,
	BOTTOM,
	COMBINE_VERTICES,
	COMBINE_NORMALS,
	COMBINE_UVS,
	COMBINE_COLORS,
	MESH,
	TOP_SHAPE,
	SKIRT_SHAPE,
	FINALIZE,
	DONE,
}

var _layout: GeneratedStageLayout
var _topology: TerrainTopTopology
var _base_y: float
var _phase: Phase = Phase.TOP
var _triangle_cursor: int = 0
var _boundary_cursor: int = 0
var _canonical_vertices := PackedVector3Array()
var _canonical_indices := PackedInt32Array()
var _canonical_normals := PackedVector3Array()
var _boundary_edges := PackedInt32Array()
var _top_vertices := PackedVector3Array()
var _top_normals := PackedVector3Array()
var _top_uvs := PackedVector2Array()
var _top_colors := PackedColorArray()
var _top_source_vertices := PackedInt32Array()
var _top_source_triangles := PackedInt32Array()
var _top_collision_faces := PackedVector3Array()
var _shell_vertices := PackedVector3Array()
var _shell_normals := PackedVector3Array()
var _shell_uvs := PackedVector2Array()
var _shell_colors := PackedColorArray()
var _render_vertices := PackedVector3Array()
var _render_normals := PackedVector3Array()
var _render_uvs := PackedVector2Array()
var _render_colors := PackedColorArray()
var _render_mesh: ArrayMesh
var _top_shape: ConcavePolygonShape3D
var _skirt_shape: ConcavePolygonShape3D
var _result: TerrainGeometry
var _skirt_vertex_count: int = 0


func _init(
		layout: GeneratedStageLayout,
		base_y: float = TerrainGeometryFactory.DEFAULT_BASE_Y
) -> void:
	assert(layout != null and layout.is_valid(), "Terrain geometry job requires a valid layout.")
	_layout = layout
	_topology = layout.top_topology
	assert(_topology != null and _topology.is_valid(), "Terrain geometry job requires canonical topology.")
	_base_y = base_y
	_canonical_vertices = _topology.canonical_vertices_read_only()
	_canonical_indices = _topology.canonical_triangle_indices_read_only()
	_canonical_normals = _topology.canonical_triangle_normals_read_only()
	_boundary_edges = _topology.boundary_edges_read_only()
	_preallocate_output_arrays()


func step(budget_usec: int = 8000) -> bool:
	var started_at := Time.get_ticks_usec()
	var starting_phase := _phase
	while _phase != Phase.DONE and _phase == starting_phase:
		match _phase:
			Phase.TOP:
				_step_top()
			Phase.SKIRTS:
				_step_skirts()
			Phase.BOTTOM:
				_step_bottom()
			Phase.COMBINE_VERTICES:
				_render_vertices = _top_vertices.duplicate()
				_render_vertices.append_array(_shell_vertices)
				_phase = Phase.COMBINE_NORMALS
			Phase.COMBINE_NORMALS:
				_render_normals = _top_normals.duplicate()
				_render_normals.append_array(_shell_normals)
				_phase = Phase.COMBINE_UVS
			Phase.COMBINE_UVS:
				_render_uvs = _top_uvs.duplicate()
				_render_uvs.append_array(_shell_uvs)
				_phase = Phase.COMBINE_COLORS
			Phase.COMBINE_COLORS:
				_render_colors = _top_colors.duplicate()
				_render_colors.append_array(_shell_colors)
				_phase = Phase.MESH
			Phase.MESH:
				_create_mesh()
				_phase = Phase.TOP_SHAPE
			Phase.TOP_SHAPE:
				_top_shape = ConcavePolygonShape3D.new()
				_top_shape.backface_collision = true
				_top_shape.set_faces(_top_collision_faces)
				_phase = Phase.SKIRT_SHAPE
			Phase.SKIRT_SHAPE:
				_skirt_shape = ConcavePolygonShape3D.new()
				_skirt_shape.backface_collision = true
				_skirt_shape.set_faces(_shell_vertices)
				_phase = Phase.FINALIZE
			Phase.FINALIZE:
				_finalize()
				_phase = Phase.DONE
		if Time.get_ticks_usec() - started_at >= maxi(budget_usec, 1):
			break
	return _phase == Phase.DONE


func result() -> TerrainGeometry:
	return _result if _phase == Phase.DONE else null


func progress_fraction() -> float:
	return float(_phase) / float(Phase.DONE)


func _step_top() -> void:
	if _triangle_cursor >= _topology.triangle_count():
		_triangle_cursor = 0
		_phase = Phase.SKIRTS
		return
	var corner_offset := _triangle_cursor * TerrainTopTopology.CORNERS_PER_TRIANGLE
	var index_a := _canonical_indices[corner_offset]
	var index_b := _canonical_indices[corner_offset + 1]
	var index_c := _canonical_indices[corner_offset + 2]
	var a := _canonical_vertices[index_a]
	var b := _canonical_vertices[index_b]
	var c := _canonical_vertices[index_c]
	var upward_normal := _canonical_normals[_triangle_cursor]
	var classification := TerrainGeometryFactory._paintable_facet_color(a, b, c)
	_write_triangle(
		_top_vertices, _top_normals, _top_uvs, _top_colors, corner_offset,
		a, c, b,
		TerrainGeometryFactory._uv_for(_topology.local_bounds, a),
		TerrainGeometryFactory._uv_for(_topology.local_bounds, c),
		TerrainGeometryFactory._uv_for(_topology.local_bounds, b),
		upward_normal, classification
	)
	_top_source_vertices[corner_offset] = index_a
	_top_source_vertices[corner_offset + 1] = index_c
	_top_source_vertices[corner_offset + 2] = index_b
	_top_source_triangles[_triangle_cursor] = _triangle_cursor
	_top_collision_faces[corner_offset] = a
	_top_collision_faces[corner_offset + 1] = b
	_top_collision_faces[corner_offset + 2] = c
	_triangle_cursor += 1


func _step_skirts() -> void:
	if _boundary_cursor >= _boundary_edges.size():
		_phase = Phase.BOTTOM
		return
	var top_a := _topology.vertex_at(_boundary_edges[_boundary_cursor])
	var top_b := _topology.vertex_at(_boundary_edges[_boundary_cursor + 1])
	assert(
		minf(top_a.y, top_b.y) - _base_y >= TerrainGeometryFactory.MINIMUM_SKIRT_HEIGHT,
		"Terrain boundary must retain the minimum visible skirt height."
	)
	var bottom_a := Vector3(top_a.x, _base_y, top_a.z)
	var bottom_b := Vector3(top_b.x, _base_y, top_b.z)
	var vertex_offset := (_boundary_cursor / 2) * 6
	_write_triangle(
		_shell_vertices, _shell_normals, _shell_uvs, _shell_colors, vertex_offset,
		top_a, top_b, bottom_a,
		Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN,
		(top_b - top_a).cross(bottom_a - top_a).normalized(), Color.BLACK
	)
	_write_triangle(
		_shell_vertices, _shell_normals, _shell_uvs, _shell_colors, vertex_offset + 3,
		top_b, bottom_b, bottom_a,
		Vector2.RIGHT, Vector2.ONE, Vector2.DOWN,
		(bottom_b - top_b).cross(bottom_a - top_b).normalized(), Color.BLACK
	)
	_boundary_cursor += 2


func _step_bottom() -> void:
	if _triangle_cursor >= _topology.triangle_count():
		_phase = Phase.COMBINE_VERTICES
		return
	var offset := _triangle_cursor * TerrainTopTopology.CORNERS_PER_TRIANGLE
	var source_a := _canonical_vertices[_canonical_indices[offset]]
	var source_b := _canonical_vertices[_canonical_indices[offset + 1]]
	var source_c := _canonical_vertices[_canonical_indices[offset + 2]]
	var a := Vector3(source_a.x, _base_y, source_a.z)
	var b := Vector3(source_b.x, _base_y, source_b.z)
	var c := Vector3(source_c.x, _base_y, source_c.z)
	var vertex_offset := _skirt_vertex_count + _triangle_cursor * 3
	_write_triangle(
		_shell_vertices, _shell_normals, _shell_uvs, _shell_colors, vertex_offset,
		a, c, b, Vector2.ZERO, Vector2.ONE, Vector2.RIGHT,
		(c - a).cross(b - a).normalized(), Color.BLACK
	)
	_triangle_cursor += 1


func _preallocate_output_arrays() -> void:
	var top_corner_count := _topology.triangle_count() * TerrainTopTopology.CORNERS_PER_TRIANGLE
	_skirt_vertex_count = (_boundary_edges.size() / 2) * 6
	var shell_vertex_count := _skirt_vertex_count + top_corner_count
	_top_vertices.resize(top_corner_count)
	_top_normals.resize(top_corner_count)
	_top_uvs.resize(top_corner_count)
	_top_colors.resize(top_corner_count)
	_top_source_vertices.resize(top_corner_count)
	_top_source_triangles.resize(_topology.triangle_count())
	_top_collision_faces.resize(top_corner_count)
	_shell_vertices.resize(shell_vertex_count)
	_shell_normals.resize(shell_vertex_count)
	_shell_uvs.resize(shell_vertex_count)
	_shell_colors.resize(shell_vertex_count)


func _write_triangle(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		colors: PackedColorArray,
		offset: int,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		uv_a: Vector2,
		uv_b: Vector2,
		uv_c: Vector2,
		normal: Vector3,
		classification: Color
) -> void:
	vertices[offset] = a
	vertices[offset + 1] = b
	vertices[offset + 2] = c
	normals[offset] = normal
	normals[offset + 1] = normal
	normals[offset + 2] = normal
	uvs[offset] = uv_a
	uvs[offset + 1] = uv_b
	uvs[offset + 2] = uv_c
	colors[offset] = classification
	colors[offset + 1] = classification
	colors[offset + 2] = classification


func _create_mesh() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _render_vertices
	arrays[Mesh.ARRAY_NORMAL] = _render_normals
	arrays[Mesh.ARRAY_TEX_UV] = _render_uvs
	arrays[Mesh.ARRAY_COLOR] = _render_colors
	_render_mesh = ArrayMesh.new()
	_render_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _finalize() -> void:
	_result = TerrainGeometry.new()
	_result.render_mesh = _render_mesh
	_result.top_shape = _top_shape
	_result.skirt_shape = _skirt_shape
	_result.top_topology = _topology
	_result.local_bounds = _topology.local_bounds
	_result.base_y = _base_y
	_result.top_vertex_count = _top_vertices.size()
	_result.shell_vertex_count = _shell_vertices.size()
	_result.top_triangle_count = _topology.triangle_count()
	_result.skirt_triangle_count = _boundary_edges.size()
	_result.bottom_triangle_count = _topology.triangle_count()
	_result.top_render_source_vertex_indices = _top_source_vertices
	_result.top_render_source_triangle_ids = _top_source_triangles
