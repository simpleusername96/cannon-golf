extends SceneTree

var _failed := false


func _initialize() -> void:
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	_assert(catalog != null and catalog.is_valid(), "v10 catalog must be valid and complete")
	if catalog == null:
		quit(1)
		return
	_assert(catalog.catalog_version == 10 and catalog.stages.size() == 30, "v10 catalog must contain thirty stages")
	_assert_partial_catalogs_fail_closed(catalog)
	var manifest_text := FileAccess.get_file_as_string(catalog.bundle_manifest_path)
	var manifest = JSON.parse_string(manifest_text)
	_assert(manifest is Dictionary, "v10 manifest must parse")
	_assert(not manifest_text.contains("accepted_seed") and not manifest_text.contains("candidate_index") \
			and not manifest_text.contains("generation_attempt") and not manifest_text.contains("fallback_seed"),
		"v10 manifest must not retain candidate or fallback identities")
	var payload_hashes: Dictionary = {}
	for index in range(catalog.stages.size()):
		var stage := catalog.stages[index]
		var baked := load(catalog.layout_paths[index]) as BakedStageLayoutData
		_assert(stage.terrain_seed == StageProgressionData.CANONICAL_TERRAIN_SEED, "%s must use the canonical terrain seed" % stage.stage_id)
		_assert(stage.generation_profile.base_seed == StageProgressionData.CANONICAL_TERRAIN_SEED, "%s profile must use the canonical terrain seed" % stage.stage_id)
		_assert(baked != null and baked.schema_version == 3, "%s must have a v10 baked payload" % stage.stage_id)
		if baked != null:
			_assert(baked.terrain_seed == StageProgressionData.CANONICAL_TERRAIN_SEED, "%s baked seed must be canonical" % stage.stage_id)
			_assert(baked.play_bounds_checksum == PlayBoundsSpec.new().checksum(), "%s must persist open play bounds" % stage.stage_id)
			_assert(not payload_hashes.has(baked.payload_sha256), "%s payload must be distinct" % stage.stage_id)
			_assert(
				TargetSurfaceCoverage.metadata_is_valid(
					baked.coverage_metric_version,
					baked.total_target_surface_area,
					baked.target_surface_area_checksum
				),
				"%s must persist metric-2 surface metadata" % stage.stage_id
			)
			payload_hashes[baked.payload_sha256] = true
	_assert(payload_hashes.size() == 30, "all thirty persisted mountains must have distinct payloads")
	for stage_id in [&"stage_01", &"stage_30"]:
		var stage := catalog.get_stage(stage_id)
		var baked := load(catalog.get_layout_path(stage_id)) as BakedStageLayoutData
		var layout := StageLayoutBakeCodec.hydrate(baked, stage)
		_assert(layout != null and layout.is_runtime_ready(), "%s fixed layout must hydrate without generation" % stage_id)
		if layout != null:
			var metrics := RouteGraphMountainSynthesizer.footprint_contract_metrics(
				layout.footprint_cells_read_only(), layout.cell_count
			)
			_assert(layout.has_valid_footprint(), "%s mountain footprint must be one independent connected mass" % stage_id)
			_assert(float(metrics.get("widest_span", 0)) / float(layout.cell_count.x) >= 0.72, "%s mountain must occupy at least 72%% of its width" % stage_id)
	if not _failed:
		print("fixed_mountain_catalog_test passed: one canonical seed, thirty distinct persisted v10 layouts")
	quit(1 if _failed else 0)


func _assert_partial_catalogs_fail_closed(catalog: StageCatalogData) -> void:
	for partial_count in [27, 28, 29]:
		var partial := catalog.duplicate(true) as StageCatalogData
		partial.stage_ids.resize(partial_count)
		partial.stages.resize(partial_count)
		partial.layout_paths.resize(partial_count)
		_assert(
			not partial.is_valid(false),
			"a %d-stage source catalog must fail closed" % partial_count
		)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
