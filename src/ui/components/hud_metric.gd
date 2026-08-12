class_name HudMetric
extends VBoxContainer

## Presentational label/value pair. Its owner supplies all translated state.
@export var value_theme_type: StringName = &"HudValue"
var _caption_key := ""


func _ready() -> void:
	%Value.theme_type_variation = value_theme_type


func set_caption_key(key: String) -> void:
	_caption_key = key
	%Caption.text = tr(_caption_key)


func set_value(value: String) -> void:
	%Value.text = value


func refresh_locale() -> void:
	%Caption.text = tr(_caption_key)
