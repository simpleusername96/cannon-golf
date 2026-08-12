class_name StageRuntimeArtifact
extends RefCounted

## Immutable bridge between AppRoot preparation, menu preview, and Gameplay.
## It intentionally contains no live Nodes, materials, paint state, or rules.
var stage_id: StringName = &""
var stage_version: int = 0
var profile_id: StringName = &""
var profile_version: int = 0
var terrain_seed: int = 0
var layout_checksum: int = 0
var paint_color := Color.TRANSPARENT
var runtime_layout: GeneratedStageLayout
var geometry: TerrainGeometry
var playable_local_points := PackedVector3Array()
var presentation_local_points := PackedVector3Array()
var paint_bootstrap: PaintSurfaceBootstrap
var preview_paint_texture: ImageTexture
var decoration_placements: Array[DecorationPlacement] = []
var decoration_scenes: Dictionary = {}
var decoration_checksum: int = 0


func install_identity(stage: StageData, layout: GeneratedStageLayout) -> bool:
	if stage == null or stage.generation_profile == null or layout == null \
			or not layout.matches_stage_identity(stage) or layout.checksum == 0:
		return false
	stage_id = stage.stage_id
	stage_version = stage.stage_version
	profile_id = stage.generation_profile.profile_id
	profile_version = stage.generation_profile.profile_version
	terrain_seed = stage.terrain_seed
	layout_checksum = layout.checksum
	paint_color = stage.paint_color
	return true


func matches_stage(stage: StageData) -> bool:
	return stage != null and stage.generation_profile != null \
			and stage_id == stage.stage_id \
			and stage_version == stage.stage_version \
			and profile_id == stage.generation_profile.profile_id \
			and profile_version == stage.generation_profile.profile_version \
			and terrain_seed == stage.terrain_seed \
			and paint_color == stage.paint_color \
			and layout_checksum != 0 \
			and runtime_layout != null \
			and runtime_layout.checksum == layout_checksum \
			and runtime_layout.matches_stage_identity(stage)


func is_complete_for(stage: StageData, tuning: PaintSurfaceTuning, mask_size: int) -> bool:
	return matches_stage(stage) \
			and runtime_layout.is_runtime_ready() \
			and _geometry_matches_layout() \
			and not playable_local_points.is_empty() \
			and not presentation_local_points.is_empty() \
			and _dressing_matches_layout() \
			and paint_bootstrap != null \
			and paint_bootstrap.is_valid_for(
				runtime_layout,
				stage.paint_world_bounds(),
				stage.terrain_center.y,
				tuning,
				mask_size
			) \
			and preview_paint_texture != null


func _geometry_matches_layout() -> bool:
	return geometry != null and geometry.is_valid() \
			and geometry.top_topology == runtime_layout.top_topology \
			and geometry.local_bounds == runtime_layout.local_bounds \
			and is_equal_approx(geometry.base_y, TerrainGeometryFactory.DEFAULT_BASE_Y) \
			and geometry.top_triangle_count == runtime_layout.top_topology.triangle_count() \
			and geometry.bottom_triangle_count == geometry.top_triangle_count


func _dressing_matches_layout() -> bool:
	if decoration_checksum == 0 \
			or decoration_checksum != checksum_decorations(runtime_layout.decoration_placements) \
			or decoration_placements.size() != runtime_layout.decoration_placements.size():
		return false
	for placement in decoration_placements:
		if placement == null or not decoration_scenes.get(placement.model_id) is PackedScene:
			return false
	return true


static func checksum_decorations(placements: Array[DecorationPlacement]) -> int:
	var parts := PackedStringArray([str(placements.size())])
	for placement in placements:
		if placement == null:
			return 0
		parts.append("%s|%.3f|%.3f|%.3f|%.3f" % [
			placement.model_id,
			placement.local_xz.x,
			placement.local_xz.y,
			placement.yaw_degrees,
			placement.uniform_scale,
		])
	var value := "\n".join(parts).hash()
	return value if value != 0 else 1
