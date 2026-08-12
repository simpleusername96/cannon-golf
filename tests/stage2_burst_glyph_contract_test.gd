extends SceneTree

var _failed := false


func _initialize() -> void:
	var stage := StageCatalog.get_stage(&"stage_02")
	_assert(stage != null, "stage 02 must exist in the current catalog")
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
		"stage 02 persisted v10 layout must retain its runtime terrain contract"
	)
	if layout != null:
		var placements := layout.mechanism_placements
		_assert(
			placements.size() == 1
					and placements[0].mechanism_data.canonical_kind() == MechanismData.Kind.BURST,
			"stage 02 must materialize one usable Burst glyph: %s" % str(layout.metrics)
		)
	if not _failed:
		print("Stage 02 Burst glyph contract passed")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
