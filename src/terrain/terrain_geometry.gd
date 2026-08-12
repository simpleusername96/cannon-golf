class_name TerrainGeometry
extends RefCounted

var render_mesh: ArrayMesh
var top_shape: ConcavePolygonShape3D
var skirt_shape: ConcavePolygonShape3D
var top_topology: TerrainTopTopology
var local_bounds: Rect2
var base_y: float = -12.0
var top_vertex_count: int = 0
var shell_vertex_count: int = 0
var top_triangle_count: int = 0
var skirt_triangle_count: int = 0
var bottom_triangle_count: int = 0
var top_render_source_vertex_indices := PackedInt32Array()
var top_render_source_triangle_ids := PackedInt32Array()


func total_triangle_count() -> int:
	return top_triangle_count + skirt_triangle_count + bottom_triangle_count


func is_valid() -> bool:
	return render_mesh != null \
			and top_shape != null \
			and skirt_shape != null \
			and top_topology != null and top_topology.is_valid() \
			and local_bounds.has_area() \
			and top_triangle_count > 0 \
			and top_vertex_count == top_triangle_count * 3 \
			and top_render_source_vertex_indices.size() == top_vertex_count \
			and top_render_source_triangle_ids.size() == top_triangle_count \
			and skirt_triangle_count > 0 \
			and bottom_triangle_count == top_triangle_count
