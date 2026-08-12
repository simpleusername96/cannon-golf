class_name TerrainTopTopology
extends RefCounted

## Owns the one canonical sampled top surface shared by queries, render, and collision.

const TRIANGLES_PER_CELL := 2
const CORNERS_PER_TRIANGLE := 3
const HIT_POSITION_EPSILON := 0.0001
const HIT_HEIGHT_TOLERANCE := 0.05
const HIT_NORMAL_TOLERANCE_DEGREES := 1.0
# A sphere's discrete physics manifold normal can deviate from the authored
# triangle normal at a faceted edge. The collider owner and height sample still
	# identify the canonical top surface, so allow that bounded manifold deviation
	# after the strict authored-normal comparison has been evaluated.
const PHYSICS_MANIFOLD_NORMAL_TOLERANCE_DEGREES := 35.0

var cell_count: Vector2i:
	get:
		return _cell_count
var local_bounds: Rect2:
	get:
		return _local_bounds

var _cell_count := Vector2i.ZERO
var _local_bounds := Rect2()
var _vertices := PackedVector3Array()
var _triangle_indices := PackedInt32Array()
var _triangle_normals := PackedVector3Array()
var _active_cells := PackedByteArray()
var _cell_triangle_ids := PackedInt32Array()
var _boundary_edges := PackedInt32Array()
var _grid_scale := Vector2.ZERO
var _is_initialized := false


static func build(
		grid_cell_count: Vector2i,
		bounds: Rect2,
		height_samples: PackedFloat32Array,
		active_cells: PackedByteArray = PackedByteArray()
) -> TerrainTopTopology:
	if grid_cell_count.x <= 0 or grid_cell_count.y <= 0 or not bounds.has_area():
		return null
	var sample_size := grid_cell_count + Vector2i.ONE
	if height_samples.size() != sample_size.x * sample_size.y:
		return null
	for height in height_samples:
		if not is_finite(height):
			return null
	var cell_total := grid_cell_count.x * grid_cell_count.y
	if active_cells.is_empty():
		active_cells.resize(cell_total)
		active_cells.fill(1)
	if active_cells.size() != cell_total:
		return null

	var topology := TerrainTopTopology.new()
	topology._cell_count = grid_cell_count
	topology._local_bounds = bounds
	topology._grid_scale = Vector2(grid_cell_count) / bounds.size
	topology._active_cells = active_cells.duplicate()
	topology._build_vertices(height_samples)
	topology._build_triangle_indices()
	topology._build_triangle_normals()
	topology._build_boundary_indices()
	if not topology._has_valid_structure():
		return null
	topology._is_initialized = true
	return topology


static func triangle_barycentric_for_cell_uv(local_uv: Vector2) -> Vector4:
	if not local_uv.is_finite() or local_uv.x < 0.0 or local_uv.x > 1.0 \
			or local_uv.y < 0.0 or local_uv.y > 1.0:
		return Vector4(-1.0, 0.0, 0.0, 0.0)
	if local_uv.x + local_uv.y <= 1.0:
		return Vector4(
			0.0,
			1.0 - local_uv.x - local_uv.y,
			local_uv.y,
			local_uv.x
		)
	return Vector4(
		1.0,
		1.0 - local_uv.y,
		1.0 - local_uv.x,
		local_uv.x + local_uv.y - 1.0
	)


func is_valid() -> bool:
	return _is_initialized


func _has_valid_structure() -> bool:
	var size := sample_size()
	if _cell_count.x <= 0 or _cell_count.y <= 0 or not _local_bounds.has_area():
		return false
	if _vertices.size() != size.x * size.y:
		return false
	if _triangle_indices.size() != triangle_count() * CORNERS_PER_TRIANGLE:
		return false
	if _triangle_normals.size() != triangle_count() or not _grid_scale.is_finite():
		return false
	if _active_cells.size() != _cell_count.x * _cell_count.y \
			or _cell_triangle_ids.size() != _active_cells.size() * TRIANGLES_PER_CELL:
		return false
	if _boundary_edges.size() < 6 or _boundary_edges.size() % 2 != 0:
		return false
	for vertex in _vertices:
		if not vertex.is_finite():
			return false
	return true


func sample_size() -> Vector2i:
	return _cell_count + Vector2i.ONE


func triangle_count() -> int:
	return _triangle_indices.size() / CORNERS_PER_TRIANGLE


func canonical_vertices_read_only() -> PackedVector3Array:
	return _vertices.duplicate()


func canonical_triangle_indices_read_only() -> PackedInt32Array:
	return _triangle_indices.duplicate()


func canonical_triangle_normals_read_only() -> PackedVector3Array:
	return _triangle_normals.duplicate()


func boundary_edges_read_only() -> PackedInt32Array:
	return _boundary_edges.duplicate()


func active_cells_read_only() -> PackedByteArray:
	return _active_cells.duplicate()


func expanded_triangle_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	faces.resize(_triangle_indices.size())
	for corner_index in range(_triangle_indices.size()):
		faces[corner_index] = _vertices[_triangle_indices[corner_index]]
	return faces


func vertex_at(source_vertex_index: int) -> Vector3:
	assert(source_vertex_index >= 0 and source_vertex_index < _vertices.size(), "Top vertex index is out of range.")
	return _vertices[source_vertex_index]


func sample_vertex_index(sample_x: int, sample_z: int) -> int:
	var size := sample_size()
	if sample_x < 0 or sample_x >= size.x or sample_z < 0 or sample_z >= size.y:
		return -1
	return sample_z * size.x + sample_x


func source_triangle_id(cell: Vector2i, triangle_in_cell: int) -> int:
	if not _is_valid_cell(cell) or triangle_in_cell < 0 or triangle_in_cell >= TRIANGLES_PER_CELL:
		return -1
	return _cell_triangle_ids[
		(cell.y * _cell_count.x + cell.x) * TRIANGLES_PER_CELL + triangle_in_cell
	]


func triangle_vertex_indices(cell: Vector2i, triangle_in_cell: int) -> Vector3i:
	var triangle_id := source_triangle_id(cell, triangle_in_cell)
	if triangle_id < 0:
		return Vector3i(-1, -1, -1)
	var offset := triangle_id * CORNERS_PER_TRIANGLE
	return Vector3i(
		_triangle_indices[offset],
		_triangle_indices[offset + 1],
		_triangle_indices[offset + 2]
	)


func triangle_normal(cell: Vector2i, triangle_in_cell: int) -> Vector3:
	var triangle_id := source_triangle_id(cell, triangle_in_cell)
	if triangle_id < 0:
		return Vector3.ZERO
	return _triangle_normals[triangle_id]


func surface_sample_at_local(
		local_x: float,
		local_z: float,
		clamp_to_bounds: bool = true
) -> Dictionary:
	if not is_finite(local_x) or not is_finite(local_z) or not _is_initialized:
		return {}
	var minimum := _local_bounds.position
	var maximum := _local_bounds.end
	if not clamp_to_bounds and (
			local_x < minimum.x - HIT_POSITION_EPSILON
			or local_x > maximum.x + HIT_POSITION_EPSILON
			or local_z < minimum.y - HIT_POSITION_EPSILON
			or local_z > maximum.y + HIT_POSITION_EPSILON
	):
		return {}
	var clamped_x := clampf(local_x, minimum.x, maximum.x)
	var clamped_z := clampf(local_z, minimum.y, maximum.y)
	var grid_x := (clamped_x - minimum.x) * _grid_scale.x
	var grid_z := (clamped_z - minimum.y) * _grid_scale.y
	var cell := Vector2i(
		mini(floori(grid_x), _cell_count.x - 1),
		mini(floori(grid_z), _cell_count.y - 1)
	)
	if not is_cell_active(cell):
		return {}
	var local_uv := Vector2(grid_x - float(cell.x), grid_z - float(cell.y))
	local_uv.x = clampf(local_uv.x, 0.0, 1.0)
	local_uv.y = clampf(local_uv.y, 0.0, 1.0)
	var address := triangle_barycentric_for_cell_uv(local_uv)
	var triangle_in_cell := int(address.x)
	var barycentric := Vector3(address.y, address.z, address.w)
	var triangle_id := source_triangle_id(cell, triangle_in_cell)
	if triangle_id < 0:
		return {}
	var corner_offset := triangle_id * CORNERS_PER_TRIANGLE
	var indices := Vector3i(
		_triangle_indices[corner_offset],
		_triangle_indices[corner_offset + 1],
		_triangle_indices[corner_offset + 2]
	)
	var point := _vertices[indices.x] * barycentric.x \
			+ _vertices[indices.y] * barycentric.y \
			+ _vertices[indices.z] * barycentric.z
	return {
		"cell": cell,
		"triangle": triangle_in_cell,
		"source_triangle_id": triangle_id,
		"source_vertex_indices": indices,
		"local_uv": local_uv,
		"barycentric": barycentric,
		"point": point,
		"normal": _triangle_normals[triangle_id],
	}


func classify_local_hit(
		local_point: Vector3,
		predicted_local_normal: Vector3
) -> Dictionary:
	if not local_point.is_finite() or not predicted_local_normal.is_finite() \
			or predicted_local_normal.is_zero_approx():
		return {}
	var sample := surface_sample_at_local(local_point.x, local_point.z, false)
	if sample.is_empty():
		return {}
	var reconstructed: Vector3 = sample.point
	if absf(reconstructed.y - local_point.y) > HIT_HEIGHT_TOLERANCE:
		return {}
	var expected_normal: Vector3 = sample.normal
	var normal_angle := rad_to_deg(acos(clampf(
		expected_normal.dot(predicted_local_normal.normalized()), -1.0, 1.0
	)))
	if normal_angle <= HIT_NORMAL_TOLERANCE_DEGREES:
		return sample
	if normal_angle > PHYSICS_MANIFOLD_NORMAL_TOLERANCE_DEGREES:
		return {}
	return sample


func height_at_local(local_x: float, local_z: float) -> float:
	var sample := surface_sample_at_local(local_x, local_z, true)
	return float(sample.point.y) if not sample.is_empty() else 0.0


func normal_at_local(local_x: float, local_z: float) -> Vector3:
	var sample := surface_sample_at_local(local_x, local_z, true)
	return sample.normal if not sample.is_empty() else Vector3.UP


func matches_height_grid(
		grid_cell_count: Vector2i,
		bounds: Rect2,
		height_samples: PackedFloat32Array
) -> bool:
	if grid_cell_count != _cell_count or bounds != _local_bounds or height_samples.size() != _vertices.size():
		return false
	for index in range(height_samples.size()):
		if not is_equal_approx(_vertices[index].y, height_samples[index]):
			return false
	return true


func is_cell_active(cell: Vector2i) -> bool:
	return _is_valid_cell(cell) and _active_cells[cell.y * _cell_count.x + cell.x] != 0


func _build_vertices(height_samples: PackedFloat32Array) -> void:
	var size := sample_size()
	_vertices.resize(height_samples.size())
	for sample_z in range(size.y):
		var local_z := lerpf(
			_local_bounds.position.y,
			_local_bounds.end.y,
			float(sample_z) / float(_cell_count.y)
		)
		for sample_x in range(size.x):
			var local_x := lerpf(
				_local_bounds.position.x,
				_local_bounds.end.x,
				float(sample_x) / float(_cell_count.x)
			)
			var source_index := sample_z * size.x + sample_x
			_vertices[source_index] = Vector3(local_x, height_samples[source_index], local_z)


func _build_triangle_indices() -> void:
	_triangle_indices = PackedInt32Array()
	_cell_triangle_ids.resize(_active_cells.size() * TRIANGLES_PER_CELL)
	_cell_triangle_ids.fill(-1)
	for cell_z in range(_cell_count.y):
		for cell_x in range(_cell_count.x):
			var cell := Vector2i(cell_x, cell_z)
			if not is_cell_active(cell):
				continue
			var p00 := sample_vertex_index(cell_x, cell_z)
			var p01 := sample_vertex_index(cell_x, cell_z + 1)
			var p10 := sample_vertex_index(cell_x + 1, cell_z)
			var p11 := sample_vertex_index(cell_x + 1, cell_z + 1)
			var cell_offset := (cell_z * _cell_count.x + cell_x) * TRIANGLES_PER_CELL
			_cell_triangle_ids[cell_offset] = triangle_count()
			_triangle_indices.append_array(PackedInt32Array([p00, p01, p10]))
			_cell_triangle_ids[cell_offset + 1] = triangle_count()
			_triangle_indices.append_array(PackedInt32Array([p10, p01, p11]))


func _build_triangle_normals() -> void:
	_triangle_normals.resize(triangle_count())
	for triangle_id in range(triangle_count()):
		var offset := triangle_id * CORNERS_PER_TRIANGLE
		var a := _vertices[_triangle_indices[offset]]
		var b := _vertices[_triangle_indices[offset + 1]]
		var c := _vertices[_triangle_indices[offset + 2]]
		_triangle_normals[triangle_id] = (b - a).cross(c - a).normalized()


func _build_boundary_indices() -> void:
	_boundary_edges = PackedInt32Array()
	for cell_z in range(_cell_count.y):
		for cell_x in range(_cell_count.x):
			var cell := Vector2i(cell_x, cell_z)
			if not is_cell_active(cell):
				continue
			var p00 := sample_vertex_index(cell_x, cell_z)
			var p01 := sample_vertex_index(cell_x, cell_z + 1)
			var p10 := sample_vertex_index(cell_x + 1, cell_z)
			var p11 := sample_vertex_index(cell_x + 1, cell_z + 1)
			_append_boundary_edge_if_exposed(cell + Vector2i(0, -1), p00, p10)
			_append_boundary_edge_if_exposed(cell + Vector2i(1, 0), p10, p11)
			_append_boundary_edge_if_exposed(cell + Vector2i(0, 1), p11, p01)
			_append_boundary_edge_if_exposed(cell + Vector2i(-1, 0), p01, p00)


func _append_boundary_edge_if_exposed(neighbor: Vector2i, first: int, second: int) -> void:
	if is_cell_active(neighbor):
		return
	_boundary_edges.append(first)
	_boundary_edges.append(second)


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _cell_count.x and cell.y >= 0 and cell.y < _cell_count.y
