class_name TerrainGeometryFactory
extends RefCounted

const DEFAULT_BASE_Y := -28.0
const MINIMUM_SKIRT_HEIGHT := 8.0


static func build(layout: GeneratedStageLayout, base_y: float = DEFAULT_BASE_Y) -> TerrainGeometry:
	var job := begin_build(layout, base_y)
	while not job.step(9223372036854775807):
		pass
	return job.result()


## Canonical progressive entry point. Runtime callers use the same geometry
## math as synchronous fixtures, but yield between each build phase.
static func begin_build(
		layout: GeneratedStageLayout,
		base_y: float = DEFAULT_BASE_Y
) -> TerrainGeometryBuildJob:
	return TerrainGeometryBuildJob.new(layout, base_y)


static func _append_top(
		topology: TerrainTopTopology,
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		colors: PackedColorArray,
		source_vertex_indices: PackedInt32Array,
		source_triangle_ids: PackedInt32Array
) -> void:
	var canonical_vertices := topology.canonical_vertices_read_only()
	var canonical_indices := topology.canonical_triangle_indices_read_only()
	for source_triangle_id in range(topology.triangle_count()):
		var corner_offset := source_triangle_id * 3
		var index_a := canonical_indices[corner_offset]
		var index_b := canonical_indices[corner_offset + 1]
		var index_c := canonical_indices[corner_offset + 2]
		var a := canonical_vertices[index_a]
		var b := canonical_vertices[index_b]
		var c := canonical_vertices[index_c]
		var upward_normal := (b - a).cross(c - a).normalized()
		# Godot renders clockwise triangle winding as the front face. Canonical
		# topology remains upward-wound for queries and collision, while the render
		# copy swaps its final corners and retains the canonical upward normal.
		_append_triangle(
			vertices,
			normals,
			uvs,
			colors,
			a,
			c,
			b,
			_uv_for(topology.local_bounds, a),
			_uv_for(topology.local_bounds, c),
			_uv_for(topology.local_bounds, b),
			true,
			upward_normal
		)
		source_vertex_indices.append_array(PackedInt32Array([index_a, index_c, index_b]))
		source_triangle_ids.append(source_triangle_id)


static func _append_skirts(
		topology: TerrainTopTopology,
		base_y: float,
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		colors: PackedColorArray
) -> void:
	var boundary_edges := topology.boundary_edges_read_only()
	for edge_offset in range(0, boundary_edges.size(), 2):
		var top_a := topology.vertex_at(boundary_edges[edge_offset])
		var top_b := topology.vertex_at(boundary_edges[edge_offset + 1])
		assert(
			minf(top_a.y, top_b.y) - base_y >= MINIMUM_SKIRT_HEIGHT,
			"Terrain boundary must retain the minimum visible skirt height."
		)
		_append_wall_quad(top_a, top_b, base_y, vertices, normals, uvs, colors)


static func _append_wall_quad(
		top_a: Vector3,
		top_b: Vector3,
		base_y: float,
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		colors: PackedColorArray
) -> void:
	var bottom_a := Vector3(top_a.x, base_y, top_a.z)
	var bottom_b := Vector3(top_b.x, base_y, top_b.z)
	_append_triangle(
		vertices, normals, uvs, colors,
		top_a, top_b, bottom_a, Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, false
	)
	_append_triangle(
		vertices, normals, uvs, colors,
		top_b, bottom_b, bottom_a, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN, false
	)


static func _append_bottom(
		topology: TerrainTopTopology,
		base_y: float,
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		colors: PackedColorArray
) -> void:
	var canonical_vertices := topology.canonical_vertices_read_only()
	var canonical_indices := topology.canonical_triangle_indices_read_only()
	for triangle_id in range(topology.triangle_count()):
		var offset := triangle_id * 3
		var source_a := canonical_vertices[canonical_indices[offset]]
		var source_b := canonical_vertices[canonical_indices[offset + 1]]
		var source_c := canonical_vertices[canonical_indices[offset + 2]]
		var a := Vector3(source_a.x, base_y, source_a.z)
		var b := Vector3(source_b.x, base_y, source_b.z)
		var c := Vector3(source_c.x, base_y, source_c.z)
		_append_triangle(
			vertices, normals, uvs, colors,
			a, c, b, Vector2.ZERO, Vector2.ONE, Vector2.RIGHT, false
		)


static func _append_triangle(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		colors: PackedColorArray,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		uv_a: Vector2,
		uv_b: Vector2,
		uv_c: Vector2,
		paintable: bool = true,
	normal_override: Vector3 = Vector3.ZERO
) -> void:
	var normal := normal_override.normalized() \
			if not normal_override.is_zero_approx() \
			else (b - a).cross(c - a).normalized()
	vertices.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	uvs.append_array(PackedVector2Array([uv_a, uv_b, uv_c]))
	var classification := _paintable_facet_color(a, b, c) if paintable else Color.BLACK
	colors.append_array(PackedColorArray([classification, classification, classification]))


static func _paintable_facet_color(a: Vector3, b: Vector3, c: Vector3) -> Color:
	var center := (a + b + c) / 3.0
	var facet_seed := sin(center.x * 12.9898 + center.z * 78.233) * 43758.5453
	var facet_tone := fposmod(facet_seed, 1.0)
	# Red remains the binary top/shell contract. Green carries a stable
	# per-triangle tone so the low-poly surface stays readable in bright light.
	return Color(1.0, facet_tone, 0.0, 1.0)


static func _uv_for(bounds: Rect2, vertex: Vector3) -> Vector2:
	return Vector2(
		(vertex.x - bounds.position.x) / bounds.size.x,
		(vertex.z - bounds.position.y) / bounds.size.y
	)
