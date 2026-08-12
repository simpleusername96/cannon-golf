extends SceneTree

const V9_ROOT := "res://resources/generated_stage_catalogs/v9-b0eb55b3e366a7a92b1391a6acd0298bbc854d8c831e8ac57f9b5df5ab44c957"

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var previous := load("%s/catalog.tres" % V9_ROOT) as StageCatalogData
	var current := load("res://resources/stages/catalog.tres") as StageCatalogData
	_assert_true(previous != null and current != null, "both catalog generations must load")
	if previous == null or current == null:
		quit(1)
		return
	_assert_true(
		previous.stages.size() == StageProgressionData.STAGE_COUNT \
				and current.stages.size() == StageProgressionData.STAGE_COUNT,
		"v9 and v10 must both contain all thirty stages"
	)
	for index in range(mini(previous.stages.size(), current.stages.size())):
		_compare_stage(index, previous, current)
	_assert_current_witnesses(current)
	if not _failed:
		print("Generation v10 materialization passed: v9 terrain, target, route, and cannon identities are preserved; current glyph/decor placement and entry witnesses are valid.")
	quit(1 if _failed else 0)


func _compare_stage(index: int, previous: StageCatalogData, current: StageCatalogData) -> void:
	var stage_id := "stage_%02d" % (index + 1)
	var old_stage := previous.stages[index] as StageData
	var new_stage := current.stages[index] as StageData
	var old_layout := load("%s/layouts/%s_layout.res" % [V9_ROOT, stage_id]) \
			as BakedStageLayoutData
	var new_layout := load(current.layout_paths[index]) as BakedStageLayoutData
	_assert_true(
		old_stage != null and new_stage != null \
				and old_layout != null and new_layout != null,
		"%s resources must load" % stage_id
	)
	if old_stage == null or new_stage == null or old_layout == null or new_layout == null:
		return
	# Mechanism placement is intentionally version-local, and decoration may move
	# with it to preserve spacing. Both may change while the mountain, target,
	# routes, and cannon remain identical.
	var terrain_layout_equal := old_layout.terrain_seed == new_layout.terrain_seed \
			and old_layout.cell_count == new_layout.cell_count \
			and old_layout.local_bounds == new_layout.local_bounds \
			and old_layout.heights == new_layout.heights \
			and old_layout.footprint == new_layout.footprint \
			and old_layout.height_checksum == new_layout.height_checksum \
			and old_layout.target_mask == new_layout.target_mask \
			and old_layout.target_checksum == new_layout.target_checksum \
			and old_layout.route_node_ids == new_layout.route_node_ids \
			and old_layout.route_node_positions == new_layout.route_node_positions \
			and old_layout.route_edge_ids == new_layout.route_edge_ids \
			and old_layout.play_bounds_checksum == new_layout.play_bounds_checksum
	_assert_true(
		terrain_layout_equal,
		"%s v10 terrain, target, and route layout must match v9" % stage_id
	)
	_assert_true(
		new_layout.placement_checksum != 0 \
				and new_layout.mechanism_anchor_ids.size() == new_stage.mechanism_loadout.size() \
				and new_layout.mechanism_transforms.size() == new_stage.mechanism_loadout.size(),
		"%s must carry a complete current glyph placement" % stage_id
	)
	_assert_true(
		new_layout.decoration_model_ids.size() == new_layout.decoration_local_xz.size() \
				and new_layout.decoration_model_ids.size() == new_layout.decoration_yaws.size() \
				and new_layout.decoration_model_ids.size() == new_layout.decoration_scales.size(),
		"%s must carry a complete current decoration placement" % stage_id
	)
	_assert_true(
		old_stage.terrain_center.is_equal_approx(new_stage.terrain_center) \
				and old_stage.terrain_size.is_equal_approx(new_stage.terrain_size) \
				and old_stage.cannon_transform.is_equal_approx(new_stage.cannon_transform),
		"%s terrain and cannon transforms must match v9" % stage_id
	)
	_assert_true(
		new_layout.schema_version == BakedStageLayoutData.BAKED_LAYOUT_SCHEMA_VERSION \
				and TargetSurfaceCoverage.metadata_is_valid(
					new_layout.coverage_metric_version,
					new_layout.total_target_surface_area,
					new_layout.target_surface_area_checksum
				),
		"%s must add valid metric-2 metadata" % stage_id
	)
	var corrupt := new_layout.duplicate(true) as BakedStageLayoutData
	corrupt.total_target_surface_area += 1.0
	_assert_true(
		StageLayoutBakeCodec.hydrate(corrupt, new_stage) == null,
		"%s corrupt surface total must fail closed" % stage_id
	)


func _assert_current_witnesses(current: StageCatalogData) -> void:
	for index in range(current.stages.size()):
		var stage_id := "stage_%02d" % (index + 1)
		var baked := load(current.layout_paths[index]) as BakedStageLayoutData
		var layout := StageLayoutBakeCodec.hydrate(baked, current.stages[index]) \
				if baked != null else null
		_assert_true(
			layout != null \
					and layout.generated_default_witness != null \
					and layout.generated_default_witness.is_valid() \
					and layout.generated_summit_witness != null \
					and layout.generated_summit_witness.is_valid(true),
			"%s must carry valid bounded entry witnesses for the current projectile scale" % stage_id
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Generation v10 materialization failed: %s" % message)
