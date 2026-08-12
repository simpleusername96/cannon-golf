extends SceneTree

const TEST_PATH := "user://paint_mountain_save_v4_migration_test.json"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_checks()
	_cleanup()
	if not _failed:
		print("Save v4 migration checks passed: v3 preservation and strictly-better metadata.")
	quit(1 if _failed else 0)


func _run_checks() -> void:
	var save_system := root.get_node("/root/SaveSystem")
	var v3_data: Dictionary = save_system.default_data()
	v3_data["version"] = 3
	v3_data["best_results"] = {
		"stage_01": {"coverage": 42.5, "stars": 2},
	}
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	_assert(file != null, "v3 fixture must open")
	if file == null:
		return
	file.store_string(JSON.stringify(v3_data))
	file.close()

	var migrated: Dictionary = save_system.load_data(TEST_PATH)
	_assert(int(migrated.get("version", -1)) == 4, "v3 save must migrate to v4")
	var migrated_best: Dictionary = migrated.get("best_results", {}).get("stage_01", {})
	_assert(is_equal_approx(float(migrated_best.get("coverage", 0.0)), 42.5), "migration must preserve coverage")
	_assert(int(migrated_best.get("stars", 0)) == 2, "migration must preserve stars")

	var game_state := root.get_node("/root/GameState")
	game_state.persistence_enabled = false
	game_state.initialize_from_data(migrated)
	game_state.complete_stage(&"stage_01", 55.0, 3, false, {
		"elapsed_seconds": 31.25,
		"shots_used": 4,
		"finish_reason": "manual",
	})
	var improved: Dictionary = game_state.best_for(&"stage_01")
	_assert(is_equal_approx(float(improved.get("coverage", 0.0)), 55.0), "better coverage must replace the best result")
	_assert(Dictionary(improved.get("metadata", {})).get("finish_reason", "") == "manual", "better coverage must store result metadata")

	game_state.complete_stage(&"stage_01", 55.0, 3, false, {
		"elapsed_seconds": 10.0,
		"shots_used": 1,
		"finish_reason": "timeout",
	})
	var tied: Dictionary = game_state.best_for(&"stage_01")
	var tied_metadata: Dictionary = tied.get("metadata", {})
	_assert(is_equal_approx(float(tied_metadata.get("elapsed_seconds", 0.0)), 31.25), "equal coverage must preserve prior metadata")
	_assert(tied_metadata.get("finish_reason", "") == "manual", "metadata must not act as a score tie-breaker")

	game_state.complete_stage(&"stage_01", 40.0, 1, false, {
		"elapsed_seconds": 5.0,
		"shots_used": 1,
		"finish_reason": "manual",
	})
	var lower: Dictionary = game_state.best_for(&"stage_01")
	_assert(is_equal_approx(float(lower.get("coverage", 0.0)), 55.0), "lower coverage must preserve the best result")
	_assert(Dictionary(lower.get("metadata", {})).get("shots_used", 0) == 4, "lower coverage must preserve prior metadata")


func _cleanup() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(absolute_path + suffix):
			DirAccess.remove_absolute(absolute_path + suffix)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Save v4 migration check failed: %s" % message)
