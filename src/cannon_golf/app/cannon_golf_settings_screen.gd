class_name CannonGolfSettingsScreen
extends Control

signal close_requested

@onready var _master: HSlider = %MasterVolume
@onready var _music: HSlider = %MusicVolume
@onready var _sfx: HSlider = %SfxVolume
@onready var _reduced_motion: CheckButton = %ReducedMotion
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _resolution: OptionButton = %Resolution
@onready var _quality: OptionButton = %Quality
@onready var _language: OptionButton = %Language
@onready var _defaults: Button = %RestoreDefaults
@onready var _close: Button = %Close
@onready var _title: Label = %Title
@onready var _master_label: Label = %MasterLabel
@onready var _music_label: Label = %MusicLabel
@onready var _sfx_label: Label = %SfxLabel
@onready var _motion_label: Label = %MotionLabel
@onready var _fullscreen_label: Label = %FullscreenLabel
@onready var _resolution_label: Label = %ResolutionLabel
@onready var _quality_label: Label = %QualityLabel
@onready var _language_label: Label = %LanguageLabel

var _store: CannonGolfSettingsStore
var _syncing := false


func _ready() -> void:
	_master.value_changed.connect(func(value: float) -> void: _store_value(&"master_volume", value / 100.0))
	_music.value_changed.connect(func(value: float) -> void: _store_value(&"music_volume", value / 100.0))
	_sfx.value_changed.connect(func(value: float) -> void: _store_value(&"sfx_volume", value / 100.0))
	_reduced_motion.toggled.connect(func(value: bool) -> void: _store_value(&"reduced_motion", value))
	_fullscreen.toggled.connect(func(value: bool) -> void: _store_value(&"fullscreen", value))
	_resolution.item_selected.connect(func(index: int) -> void: _store_option(&"resolution", String(_resolution.get_item_metadata(index))))
	_quality.item_selected.connect(func(index: int) -> void: _store_option(&"quality", String(_quality.get_item_metadata(index))))
	_language.item_selected.connect(func(index: int) -> void: _store_option(&"language", String(_language.get_item_metadata(index))))
	_defaults.pressed.connect(_restore_defaults)
	_close.pressed.connect(_close_screen)
	_build_options()
	visible = false


func configure(store: CannonGolfSettingsStore) -> void:
	_store = store
	_sync_from_store()


func open() -> void:
	if _store == null:
		return
	_sync_from_store()
	visible = true
	_close.grab_focus.call_deferred()


func close() -> void:
	_close_screen()


func _build_options() -> void:
	_resolution.clear()
	for value in CannonGolfSettingsStore.RESOLUTIONS:
		_resolution.add_item(value)
		_resolution.set_item_metadata(_resolution.item_count - 1, value)
	_quality.clear()
	for value in CannonGolfSettingsStore.QUALITIES:
		_quality.add_item(_quality_label_for(value))
		_quality.set_item_metadata(_quality.item_count - 1, value)
	_language.clear()
	_language.add_item("한국어")
	_language.set_item_metadata(0, "ko")
	_language.add_item("English")
	_language.set_item_metadata(1, "en")


func _sync_from_store() -> void:
	if _store == null:
		return
	_syncing = true
	var values := _store.get_settings()
	_master.value = float(values[&"master_volume"]) * 100.0
	_music.value = float(values[&"music_volume"]) * 100.0
	_sfx.value = float(values[&"sfx_volume"]) * 100.0
	_reduced_motion.button_pressed = bool(values[&"reduced_motion"])
	_fullscreen.button_pressed = bool(values[&"fullscreen"])
	_select_by_id(_resolution, String(values[&"resolution"]))
	_select_by_id(_quality, String(values[&"quality"]))
	_select_by_id(_language, String(values[&"language"]))
	_syncing = false
	_apply_language(String(values[&"language"]))


func _store_value(key: StringName, value: Variant) -> void:
	if _syncing or _store == null:
		return
	_store.update_setting(key, value)
	_store.save_settings()


func _store_option(key: StringName, value: String) -> void:
	if key == &"language":
		_apply_language(value)
	_store_value(key, value)


func _restore_defaults() -> void:
	if _store == null:
		return
	_store.reset_to_defaults()
	_store.save_settings()
	_sync_from_store()


func _select_by_id(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			return


func _apply_language(language: String) -> void:
	var english := language == "en"
	_title.text = "Settings" if english else "설정"
	$Panel/Margin/Content/Columns/Audio/AudioHeading.text = "AUDIO" if english else "소리"
	$Panel/Margin/Content/Columns/Display/DisplayHeading.text = "DISPLAY" if english else "화면"
	_master_label.text = "Master" if english else "전체 음량"
	_music_label.text = "Music" if english else "음악"
	_sfx_label.text = "Effects" if english else "효과음"
	_motion_label.text = "Reduced motion" if english else "동작 줄이기"
	_fullscreen_label.text = "Fullscreen" if english else "전체 화면"
	_resolution_label.text = "Resolution" if english else "해상도"
	_quality_label.text = "Quality" if english else "품질"
	_language_label.text = "Language" if english else "언어"
	_reduced_motion.text = "ON" if english else "사용"
	_fullscreen.text = "ON" if english else "사용"
	_defaults.text = "Restore defaults" if english else "기본값 복원"
	_close.text = "Close" if english else "닫기"
	for index in range(_quality.item_count):
		_quality.set_item_text(index, _quality_label_for(String(_quality.get_item_metadata(index)), english))


func _quality_label_for(value: String, english: bool = false) -> String:
	match value:
		"low":
			return "Low" if english else "낮음"
		"high":
			return "High" if english else "높음"
	return "Medium" if english else "중간"


func _close_screen() -> void:
	if not visible:
		return
	visible = false
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_screen()
