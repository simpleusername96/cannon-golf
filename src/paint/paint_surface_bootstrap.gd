class_name PaintSurfaceBootstrap
extends RefCounted

## Immutable stage-preparation data. PaintSystem remains the sole owner of the
## mutable paint mask, dirty regions, and coverage counters.
var layout_checksum: int = 0
var target_mask_checksum: int = 0
var world_bounds := Rect2()
var terrain_origin_y: float = 0.0
var painted_threshold_byte: int = 0
var target_bytes := PackedByteArray()
var target_image: Image
var target_texture: ImageTexture
var surface_column_cells := PackedInt32Array()
var surface_row_cells := PackedInt32Array()
var surface_column_fractions := PackedFloat32Array()
var surface_row_fractions := PackedFloat32Array()
var surface_world_x := PackedFloat32Array()
var surface_world_z := PackedFloat32Array()
var topology_cell_cache_states := PackedByteArray()
var topology_cell_triangle_vertices := PackedVector3Array()
var topology_cell_triangle_normals := PackedVector3Array()
var topology_cell_count := Vector2i.ZERO


func is_valid_for(
		layout: GeneratedStageLayout,
		expected_world_bounds: Rect2,
		expected_terrain_origin_y: float,
		tuning: PaintSurfaceTuning,
		mask_size: int
) -> bool:
	if layout == null or tuning == null or layout_checksum == 0 \
			or layout_checksum != layout.checksum \
			or target_mask_checksum != layout.target_mask_checksum \
			or world_bounds != expected_world_bounds \
			or not is_equal_approx(terrain_origin_y, expected_terrain_origin_y) \
			or painted_threshold_byte != tuning.painted_threshold_byte:
		return false
	var pixel_count := mask_size * mask_size
	var topology_cells := layout.top_topology.cell_count if layout.top_topology != null else Vector2i.ZERO
	var topology_cell_total := topology_cells.x * topology_cells.y
	return target_bytes.size() == pixel_count \
			and target_image != null and not target_image.is_empty() \
			and target_texture != null \
			and surface_column_cells.size() == mask_size \
			and surface_row_cells.size() == mask_size \
			and surface_column_fractions.size() == mask_size \
			and surface_row_fractions.size() == mask_size \
			and surface_world_x.size() == mask_size \
			and surface_world_z.size() == mask_size \
			and topology_cell_count == topology_cells \
			and topology_cell_cache_states.size() == topology_cell_total \
			and topology_cell_triangle_vertices.size() == topology_cell_total \
					* TerrainTopTopology.TRIANGLES_PER_CELL \
					* TerrainTopTopology.CORNERS_PER_TRIANGLE \
			and topology_cell_triangle_normals.size() == topology_cell_total \
					* TerrainTopTopology.TRIANGLES_PER_CELL
