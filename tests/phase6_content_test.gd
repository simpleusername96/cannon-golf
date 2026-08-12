extends SceneTree

const TEST_SAVE_PATH := "user://paint_mountain_phase6_test.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_cleanup_test_saves()
	var save_system := root.get_node("/root/SaveSystem")
	var game_state := root.get_node("/root/GameState")
	var ids := StageCatalog.all_stage_ids()
	_assert_true(ids.size() == 30, "catalog must expose all thirty immediately selectable stages")
	_assert_true(ids[0] == &"stage_01" and ids[1] == &"stage_02" and ids[2] == &"stage_03", "catalog must retain canonical stage order")
	_assert_true(ids[29] == &"stage_30", "catalog must end at Stage 30")
	var first := StageCatalog.get_stage(&"stage_01")
	var burst := StageCatalog.get_stage(&"stage_02")
	var split := StageCatalog.get_stage(&"stage_03")
	var stage30 := StageCatalog.get_stage(&"stage_30")
	_assert_true(first != null and first.mechanism_loadout.is_empty(), "First Descent must have no mechanisms")
	_assert_true(burst != null and burst.mechanism_loadout.size() == 1 and burst.mechanism_loadout[0].kind == MechanismData.Kind.BURST, "Burst Basin must request one generated Burst")
	_assert_true(split != null and split.mechanism_loadout.size() == 2, "Split Ridge must request exactly two generated mechanisms")
	_assert_true(stage30 != null and stage30.maximum_shots >= 4 and stage30.target_coverage > first.target_coverage, "Stage 30 must be a gradual, playable progression endpoint")

	var sample_save: Dictionary = save_system.default_data()
	sample_save.selected_stage_id = "stage_30"
	sample_save.best_results = {
		"stage_01": {
			"coverage": 24.5,
			"stars": 2,
			"coverage_metric_version": TargetSurfaceCoverage.METRIC_VERSION,
		}
	}
	_assert_true(save_system.save_data(sample_save, TEST_SAVE_PATH) == OK, "versioned save must write atomically")
	var loaded: Dictionary = save_system.load_data(TEST_SAVE_PATH)
	_assert_true(String(loaded.selected_stage_id) == "stage_30", "selected stage must survive reload")
	var first_best: Dictionary = Dictionary(loaded.best_results).get("stage_01", {})
	_assert_true(is_equal_approx(float(first_best.get("coverage", 0.0)), 24.5), "best coverage must survive reload")
	_assert_true(not loaded.has("unlocked_stages"), "all-open progression must not persist a lock list")

	var invalid := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	invalid.store_string("{not-valid-json")
	invalid.close()
	var fallback: Dictionary = save_system.load_data(TEST_SAVE_PATH)
	_assert_true(String(fallback.selected_stage_id) == "stage_01", "invalid save must fall back to the first stage")
	game_state.initialize_from_data(save_system.default_data())
	_assert_true(game_state.unlocked_stages.size() == 30, "fresh state must open every stage")
	_assert_true(game_state.select_stage(&"first_descent") and game_state.selected_stage_id == &"stage_01", "legacy stage aliases must resolve to canonical IDs")
	_assert_true(game_state.select_stage(&"stage_30"), "Stage 30 must be selectable without clearing earlier stages")
	game_state.complete_stage(&"stage_30", 55.0, 2, false)
	_assert_true(game_state.select_stage(&"stage_04"), "completing a later stage must not close earlier catalog entries")

	if not _failed:
		print("Phase 6 content checks passed: canonical all-open stages, migrated aliases, current saves, and direct later-stage selection.")
	game_state.persistence_enabled = true
	_cleanup_test_saves()
	quit(1 if _failed else 0)


func _cleanup_test_saves() -> void:
	var user_directory := DirAccess.open("user://")
	if user_directory == null:
		return
	for file_name in user_directory.get_files():
		if file_name.begins_with("paint_mountain_phase6_content_test.json") or file_name.begins_with("paint_mountain_phase6_test.json"):
			user_directory.remove(file_name)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
