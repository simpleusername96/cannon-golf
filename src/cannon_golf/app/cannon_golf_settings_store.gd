class_name CannonGolfSettingsStore
extends RefCounted

## Small, product-owned settings persistence for the Cannon Golf shell.
## The store deliberately has no dependency on the retained Paint Mountain
## autoloads or their migration schema.

signal changed(settings: Dictionary)

const DEFAULT_PATH := "user://cannon_golf_settings.json"
const SUPPORTED_KEYS: Array[StringName] = [
	&"master_volume",
	&"music_volume",
	&"sfx_volume",
	&"reduced_motion",
	&"fullscreen",
	&"resolution",
	&"quality",
	&"language",
]
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080"]
const QUALITIES := ["low", "medium", "high"]
const LANGUAGES := ["ko", "en"]

var save_path: String
var _settings: Dictionary


func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path
	_settings = default_settings()


func default_settings() -> Dictionary:
	return {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.85,
		"reduced_motion": false,
		"fullscreen": false,
		"resolution": "1280x720",
		"quality": "medium",
		"language": "ko",
	}


func supported_keys() -> Array[StringName]:
	return SUPPORTED_KEYS.duplicate()


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func load_settings() -> Dictionary:
	_settings = default_settings()
	if not FileAccess.file_exists(save_path):
		return get_settings()
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return get_settings()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_settings = _sanitize(parsed)
	return get_settings()


func save_settings(values: Dictionary = {}) -> Error:
	if not values.is_empty():
		_settings = _sanitize(values)
	else:
		_settings = _sanitize(_settings)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_settings))
	file.flush()
	file.close()
	return OK


func reset_to_defaults() -> Dictionary:
	_settings = default_settings()
	changed.emit(get_settings())
	return get_settings()


func update_setting(key: StringName, value: Variant, persist: bool = false) -> bool:
	if not SUPPORTED_KEYS.has(key):
		return false
	var normalized: Variant = _normalize_value(key, value, _settings.get(key))
	if _settings.get(key) == normalized:
		return false
	_settings[key] = normalized
	changed.emit(get_settings())
	if persist:
		save_settings()
	return true


func set_setting(key: StringName, value: Variant) -> bool:
	return update_setting(key, value, false)


func apply_runtime(viewport: Viewport = null) -> void:
	for pair in [
		[&"Master", &"master_volume"],
		[&"Music", &"music_volume"],
		[&"SFX", &"sfx_volume"],
	]:
		var bus_index := AudioServer.get_bus_index(String(pair[0]))
		if bus_index >= 0:
			var linear := maxf(float(_settings[pair[1]]), 0.0001)
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))

	if viewport != null:
		viewport.scaling_3d_scale = _quality_scale(String(_settings[&"quality"]))
	if DisplayServer.get_name() != "headless":
		_apply_display()
	TranslationServer.set_locale(String(_settings[&"language"]))


func _apply_display() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN \
			if bool(_settings[&"fullscreen"]) \
			else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if not bool(_settings[&"fullscreen"]):
		var size := _parse_resolution(String(_settings[&"resolution"]))
		if size != Vector2i.ZERO:
			DisplayServer.window_set_size(size)


func _sanitize(raw: Dictionary) -> Dictionary:
	var result := default_settings()
	for key in SUPPORTED_KEYS:
		var string_key := String(key)
		var value: Variant = raw.get(key, raw.get(string_key, result[key]))
		result[key] = _normalize_value(key, value, result[key])
	return result


func _normalize_value(key: StringName, value: Variant, fallback: Variant) -> Variant:
	match key:
		&"master_volume", &"music_volume", &"sfx_volume":
			return clampf(float(value) if value is int or value is float else float(fallback), 0.0, 1.0)
		&"reduced_motion", &"fullscreen":
			return bool(value) if value is bool else bool(fallback)
		&"resolution":
			var resolution := String(value)
			return resolution if RESOLUTIONS.has(resolution) else fallback
		&"quality":
			var quality := String(value)
			return quality if QUALITIES.has(quality) else fallback
		&"language":
			var language := String(value)
			return language if LANGUAGES.has(language) else fallback
	return fallback


func _parse_resolution(value: String) -> Vector2i:
	var parts := value.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _quality_scale(value: String) -> float:
	match value:
		"low":
			return 0.75
		"high":
			return 1.15
	return 1.0
