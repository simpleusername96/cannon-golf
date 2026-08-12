extends SceneTree

var _failed := false


func _initialize() -> void:
	var stage := StageCatalog.get_stage(&"stage_08")
	_assert(stage != null, "stage 08 must exist in the current catalog")
	if stage == null:
		quit(1)
		return
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	var layout := StageLayoutBakeCodec.hydrate(
		load(catalog.get_layout_path(stage.stage_id)) as BakedStageLayoutData,
		stage
	)
	_assert(
		layout != null and layout.is_runtime_ready(),
		"stage 08 persisted v10 layout must retain its runtime terrain contract"
	)
	if layout != null:
		var placements := layout.mechanism_placements
		var uphill_count := 0
		for placement in placements:
			if placement.mechanism_data.canonical_kind() == MechanismData.Kind.UPHILL_REBOUND \
					and not placement.uphill_tangent.is_zero_approx():
				uphill_count += 1
		_assert(
			placements.size() == stage.mechanism_loadout.size() and uphill_count == 1,
			"stage 08 must materialize one usable Uphill Rebound glyph: %s" % str(layout.metrics)
		)
	if not _failed:
		print("Stage 08 Uphill Rebound glyph contract passed")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
