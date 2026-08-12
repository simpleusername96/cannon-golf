extends SceneTree

const SETTINGS_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_settings.tscn")
const TEST_PATH := "user://cannon_golf_settings_phase1_test.json"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_file()
	var store := CannonGolfSettingsStore.new(TEST_PATH)
	var defaults := store.load_settings()
	var expected := [
		&"master_volume",
		&"music_volume",
		&"sfx_volume",
		&"reduced_motion",
		&"fullscreen",
		&"resolution",
		&"quality",
		&"language",
	]
	_assert(store.supported_keys() == expected, "settings store must expose only truthful Cannon Golf options")
	_assert(not defaults.has("trajectory_preview"), "settings must not expose trajectory prediction")
	_assert(not defaults.has("camera_shake"), "settings must not expose an unsupported camera toggle")

	_assert(store.update_setting(&"master_volume", 0.35), "master volume must update")
	_assert(store.update_setting(&"music_volume", 0.55), "music volume must update")
	_assert(store.update_setting(&"sfx_volume", 0.75), "sfx volume must update")
	_assert(store.update_setting(&"reduced_motion", true), "reduced motion must update")
	_assert(store.update_setting(&"fullscreen", true), "fullscreen must update")
	_assert(store.update_setting(&"resolution", "1600x900"), "resolution must update")
	_assert(store.update_setting(&"quality", "high"), "quality must update")
	_assert(store.update_setting(&"language", "en"), "language must update")
	_assert(not store.update_setting(&"coverage_metric", 0.5), "legacy coverage keys must be rejected")
	_assert(store.save_settings() == OK, "settings must save to the Cannon Golf path")

	var reloaded := CannonGolfSettingsStore.new(TEST_PATH)
	reloaded.load_settings()
	var values := reloaded.get_settings()
	_assert(is_equal_approx(float(values[&"master_volume"]), 0.35), "master volume must survive reload")
	_assert(is_equal_approx(float(values[&"music_volume"]), 0.55), "music volume must survive reload")
	_assert(is_equal_approx(float(values[&"sfx_volume"]), 0.75), "sfx volume must survive reload")
	_assert(bool(values[&"reduced_motion"]), "reduced motion must survive reload")
	_assert(bool(values[&"fullscreen"]), "fullscreen must survive reload")
	_assert(values[&"resolution"] == "1600x900", "resolution must survive reload")
	_assert(values[&"quality"] == "high", "quality must survive reload")
	_assert(values[&"language"] == "en", "language must survive reload")

	var settings := SETTINGS_SCENE.instantiate() as CannonGolfSettingsScreen
	root.add_child(settings)
	await process_frame
	settings.configure(reloaded)
	settings.open()
	_assert(settings.visible, "settings screen must open explicitly")
	_assert(settings.get_node("Panel/Margin/Content/Columns/Audio/MasterVolume") is HSlider, "settings must expose master volume")
	_assert(settings.get_node("Panel/Margin/Content/Columns/Display/Resolution") is OptionButton, "settings must expose resolution")
	_assert(settings.get_node("Panel/Margin/Content/Columns/Display/Quality") is OptionButton, "settings must expose quality")
	_assert(settings.get_node("Panel/Margin/Content/Columns/Display/Language") is OptionButton, "settings must expose language")
	for node in _all_descendants(settings):
		if node is Label or node is Button:
			var copy := String(node.text)
			for retired in ["페인트", "커버리지", "예측", "남은 샷", "별"]:
				_assert(not copy.contains(retired), "settings must not retain retired copy: %s" % retired)
	settings._language.select(0)
	settings._language.item_selected.emit(0)
	_assert(reloaded.get_settings()[&"language"] == "ko", "language selection must update the settings store")
	_assert(settings._title.text == "설정", "language selection must immediately refresh settings copy")

	settings.queue_free()
	await process_frame
	_remove_test_file()
	quit(1 if _failed else 0)


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _remove_test_file() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
