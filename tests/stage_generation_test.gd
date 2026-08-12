extends SceneTree

var _failed := false


func _initialize() -> void:
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	_assert(catalog != null and catalog.is_valid(), "v10 catalog must load")
	if catalog == null:
		quit(1)
		return
	for stage_id in [&"stage_01", &"stage_15", &"stage_30"]:
		var stage := catalog.get_stage(stage_id)
		var path := catalog.get_layout_path(stage_id)
		var first_baked := load(path) as BakedStageLayoutData
		var first := StageLayoutBakeCodec.hydrate(first_baked, stage)
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var second_baked := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BakedStageLayoutData
		var second := StageLayoutBakeCodec.hydrate(second_baked, stage)
		_assert(first != null and second != null, "%s persisted layout must hydrate repeatedly" % stage_id)
		if first == null or second == null:
			continue
		_assert(first.terrain_seed == StageProgressionData.CANONICAL_TERRAIN_SEED, "%s must expose the canonical seed" % stage_id)
		_assert(first.checksum == second.checksum, "%s height checksum must repeat" % stage_id)
		_assert(first.target_mask_checksum == second.target_mask_checksum, "%s target checksum must repeat" % stage_id)
		_assert(first.placement_checksum() == second.placement_checksum(), "%s placement checksum must repeat" % stage_id)
		_assert(first.footprint_cells_read_only() == second.footprint_cells_read_only(), "%s footprint bytes must repeat" % stage_id)
		_assert(first.play_bounds != null and first.play_bounds.is_valid(), "%s must own open play bounds" % stage_id)
		_assert(first.route_graph.route_count() == stage.generation_profile.routes.size(), "%s route graph must match its profile" % stage_id)
		_assert(first.is_runtime_ready(), "%s fixed layout must be runtime-ready" % stage_id)
	if not _failed:
		print("stage_generation_test passed: persisted layout identity repeats without candidate search")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
