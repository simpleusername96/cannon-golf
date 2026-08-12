class_name CoverageMeter
extends Control

@onready var progress: ProgressBar = %Progress
@onready var coverage_caption: TextureRect = %CoverageCaption
@onready var value_label: Label = %CoverageValue
@onready var target_label: Label = %TargetValue
@onready var target_line: HSeparator = %TargetLine
var _target := 0.0


func configure(target: float) -> void:
	_target = clampf(target, 0.0, 100.0)
	tooltip_text = tr("hud.coverage_tooltip")
	coverage_caption.tooltip_text = tr("hud.coverage")
	coverage_caption.accessibility_name = tr("hud.coverage")
	target_label.text = "%s %.0f%%" % [tr("hud.target"), _target]
	var target_y := progress.position.y + progress.size.y * (1.0 - _target / 100.0)
	target_line.position.y = target_y - target_line.size.y * 0.5
	# Keep the numeric goal under its rail tick so the hairline never strikes
	# through localized copy at larger desktop scales.
	target_label.position.y = clampf(
		target_y + 6.0,
		progress.position.y + 4.0,
		size.y - target_label.size.y
	)
	update_coverage(0.0)


func update_coverage(coverage: float) -> void:
	var absolute_coverage := clampf(coverage, 0.0, 100.0)
	progress.value = absolute_coverage
	value_label.text = "%.1f%%" % absolute_coverage


func refresh_locale() -> void:
	configure(_target)
