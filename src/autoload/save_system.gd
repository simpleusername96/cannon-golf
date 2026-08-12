extends Node

const SAVE_VERSION := 5
const DEFAULT_SAVE_PATH := "user://paint_mountain_save.json"


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"selected_stage_id": "stage_01",
		"coverage_metric_version": TargetSurfaceCoverage.METRIC_VERSION,
		"best_results": {},
		"legacy_best_results": {},
		"settings": {
			"master_volume": 0.8,
			"music_volume": 0.7,
			"sfx_volume": 0.85,
			"camera_shake": true,
			"reduced_motion": false,
			"trajectory_preview": true,
			"fullscreen": false,
			"resolution": "1920x1080",
			"quality": "medium",
			"language": "ko",
			"language_user_selected": false,
		},
	}


func load_data(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return default_data()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return default_data()
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	var parsed = parser.data
	if parse_error != OK or not parsed is Dictionary:
		_preserve_invalid(path)
		return default_data()
	if int(parsed.get("version", -1)) in [1, 2, 3, 4]:
		parsed = _migrate_to_v5(parsed)
	elif int(parsed.get("version", -1)) != SAVE_VERSION:
		_preserve_invalid(path)
		return default_data()
	return _merge_with_defaults(parsed)


func save_data(data: Dictionary, path: String = DEFAULT_SAVE_PATH) -> Error:
	var payload := _merge_with_defaults(data)
	payload["version"] = SAVE_VERSION
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(absolute_path):
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return backup_error
	var replace_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		return replace_error
	return OK


func _merge_with_defaults(data: Dictionary) -> Dictionary:
	var merged := default_data()
	merged["selected_stage_id"] = data.get("selected_stage_id", merged.selected_stage_id)
	var current_best: Dictionary = {}
	var legacy_best: Dictionary = Dictionary(
		data.get("legacy_best_results", {})
	).duplicate(true)
	var incoming_best: Dictionary = data.get("best_results", {})
	for stage_id in incoming_best:
		var entry: Variant = incoming_best[stage_id]
		if entry is Dictionary and int(entry.get("coverage_metric_version", -1)) \
				== TargetSurfaceCoverage.METRIC_VERSION:
			current_best[stage_id] = (entry as Dictionary).duplicate(true)
		elif not legacy_best.has(stage_id):
			legacy_best[stage_id] = entry
	merged["best_results"] = current_best
	merged["legacy_best_results"] = legacy_best
	var incoming_settings: Dictionary = data.get("settings", {})
	var settings: Dictionary = merged.settings
	for key in incoming_settings:
		if settings.has(key):
			settings[key] = incoming_settings[key]
	merged["settings"] = settings
	return merged


func _migrate_to_v5(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var source_version := int(migrated.get("version", -1))
	var migrated_settings: Dictionary = Dictionary(
		migrated.get("settings", {})
	).duplicate(true)
	if source_version in [1, 2]:
		migrated_settings["language"] = "ko"
		migrated_settings["language_user_selected"] = false
	migrated["settings"] = migrated_settings
	var selected := String(migrated.get("selected_stage_id", "stage_01"))
	match selected:
		"first_descent": selected = "stage_01"
		"burst_basin": selected = "stage_02"
		"split_ridge": selected = "stage_03"
	migrated["selected_stage_id"] = selected
	migrated["coverage_metric_version"] = TargetSurfaceCoverage.METRIC_VERSION
	migrated["legacy_best_results"] = Dictionary(
		migrated.get("legacy_best_results", migrated.get("best_results", {}))
	).duplicate(true)
	migrated["best_results"] = {}
	migrated["version"] = SAVE_VERSION
	return migrated


func _preserve_invalid(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var invalid_path := "%s.invalid-%s" % [absolute_path, timestamp]
	DirAccess.rename_absolute(absolute_path, invalid_path)
