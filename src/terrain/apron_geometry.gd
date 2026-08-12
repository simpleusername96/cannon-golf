class_name ApronGeometry
extends RefCounted

var render_mesh: ArrayMesh
var collision_shape: ConcavePolygonShape3D
var collision_faces := PackedVector3Array()
var top_vertex_count: int = 0
var top_triangle_count: int = 0
var total_triangle_count: int = 0
var top_xz_bounds := Rect2()
var minimum_top_y: float = INF
var terrain_join_gap: float = INF


func is_valid() -> bool:
	return render_mesh != null \
			and collision_shape != null \
			and not collision_faces.is_empty() \
			and collision_faces.size() == total_triangle_count * 3 \
			and top_vertex_count == top_triangle_count * 3 \
			and top_triangle_count > 0 \
			and total_triangle_count > top_triangle_count \
			and top_xz_bounds.has_area() \
			and is_finite(minimum_top_y) \
			and is_finite(terrain_join_gap)
