extends SceneTree

var _failed := false


func _initialize() -> void:
	var stage := StageCatalog.get_stage(&"stage_03")
	_assert(stage != null, "Stage 03 must exist in the active catalog")
	if stage == null:
		quit(1)
		return
	_assert(
		StageProgressionData.route_count_for(1) == 1 \
				and StageProgressionData.route_count_for(2) == 1 \
				and StageProgressionData.route_count_for(3) == 3 \
				and StageProgressionData.route_count_for(4) == 1,
		"only Stage 03 may be the early three-route tutorial"
	)
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	var layout := StageLayoutBakeCodec.hydrate(
		load(catalog.get_layout_path(stage.stage_id)) as BakedStageLayoutData,
		stage
	)
	_assert(layout != null and layout.is_runtime_ready(), "Stage 03 must hydrate its fixed v10 layout")
	if layout != null:
		var graph := layout.route_graph
		_assert(graph.route_count() == 3, "the fixed Stage 03 graph must retain all three routes")
		_assert(
			graph.route_index_for_role(StageRouteProfile.Role.SAFE) >= 0 \
					and graph.route_index_for_role(StageRouteProfile.Role.SPLITTER) >= 0 \
					and graph.route_index_for_role(StageRouteProfile.Role.BUMPER) >= 0,
			"Stage 03 must retain distinct SAFE, SPLITTER, and BUMPER route roles"
		)
		var splitter_pad := graph.pad_node_for_kind(MechanismData.Kind.SPLITTER)
		var uphill_pad := graph.pad_node_for_kind(MechanismData.Kind.UPHILL_REBOUND)
		_assert(
			splitter_pad != null \
					and graph.route_role(splitter_pad.route_index) == StageRouteProfile.Role.SPLITTER,
			"the Splitter glyph anchor must remain on the SPLITTER route"
		)
		_assert(
			uphill_pad != null \
					and graph.route_role(uphill_pad.route_index) == StageRouteProfile.Role.BUMPER,
			"the Uphill Rebound glyph anchor must remain on the BUMPER route"
		)
		_assert(
			layout.terrain_seed == StageProgressionData.CANONICAL_TERRAIN_SEED,
			"Stage 03 must use the fixed catalog-family seed"
		)
		_assert(
			layout.mechanism_placements.size() == stage.mechanism_loadout.size(),
			"Stage 03 must retain its complete glyph loadout"
		)
		for placement in layout.mechanism_placements:
			if placement.mechanism_data.canonical_kind() == MechanismData.Kind.SPLITTER:
				_assert(
					placement.splitter_route_targets.size() == 3,
					"Stage 03 Splitter must retain three route witnesses"
				)
	if not _failed:
		print("Stage 03 glyph route contract passed: fixed v10 graph and placement identities.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
