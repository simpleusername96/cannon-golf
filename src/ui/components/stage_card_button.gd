class_name StageCardButton
extends Button

@onready var _number_label: Label = %Number
@onready var _name_label: Label = %StageName
@onready var _facts_label: Label = %Facts
@onready var _selected_mark: TextureRect = %SelectedMark


func present(
		stage_number: int,
		stage_name: String,
		target_label: String,
		target_coverage: float,
		best_label: String,
		best_coverage: float,
		selected: bool
) -> void:
	_number_label.text = "%02d" % stage_number
	_name_label.text = stage_name
	_facts_label.text = "%s %.1f%%  ·  %s %.1f%%" % [
		target_label,
		target_coverage,
		best_label,
		best_coverage,
	]
	# Keep the native Button text as its accessibility/focus name. The shared
	# card variation makes this aggregate string visually transparent while the
	# child labels own the approved hierarchy.
	text = "%02d %s\n%s" % [stage_number, stage_name, _facts_label.text]
	set_selected(selected)


func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)
	_selected_mark.visible = selected
	_number_label.theme_type_variation = &"StageCardNumberSelected" if selected \
			else &"StageCardNumber"
