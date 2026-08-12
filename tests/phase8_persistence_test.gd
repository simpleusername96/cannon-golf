extends SceneTree

const TEST_PATH := "user://paint_mountain_phase8_restart.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := "read"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
	var save_system := root.get_node("/root/SaveSystem")
	match mode:
		"write":
			var data: Dictionary = save_system.default_data()
			data.unlocked_stages = ["first_descent", "burst_basin", "split_ridge"]
			data.best_results = {"split_ridge": {
				"coverage": 77.921,
				"stars": 1,
				"coverage_metric_version": TargetSurfaceCoverage.METRIC_VERSION,
			}}
			data.settings.master_volume = 0.43
			data.settings.quality = "high"
			data.settings.language = "en"
			data.settings.language_user_selected = true
			var error: Error = save_system.save_data(data, TEST_PATH)
			print("Phase 8 persistence write: %s" % error_string(error))
			quit(0 if error == OK else 1)
		"cleanup":
			_cleanup()
			print("Phase 8 persistence fixture cleaned.")
			quit(0)
		_:
			var loaded: Dictionary = save_system.load_data(TEST_PATH)
			var passed: bool = not loaded.has("unlocked_stages") \
					and is_equal_approx(float(loaded.best_results.split_ridge.coverage), 77.921) \
					and int(loaded.best_results.split_ridge.coverage_metric_version) \
							== TargetSurfaceCoverage.METRIC_VERSION \
					and is_equal_approx(float(loaded.settings.master_volume), 0.43) \
					and loaded.settings.quality == "high" \
					and loaded.settings.language == "en" \
					and loaded.settings.language_user_selected
			if not passed:
				push_error("Cross-process save did not preserve metric-2 best result and settings.")
			else:
				print("Phase 8 persistence read passed across a fresh process.")
			quit(0 if passed else 1)


func _cleanup() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(absolute_path + suffix):
			DirAccess.remove_absolute(absolute_path + suffix)
