class_name ActionButtons
extends Control

signal fire_requested


func _ready() -> void:
	%FireButton.pressed.connect(func() -> void: fire_requested.emit())
	refresh_locale()


func refresh_locale() -> void:
	%FireButton.text = tr("ui.fire")


func set_fire_readiness(snapshot: Dictionary) -> void:
	var enabled := bool(snapshot.get("fireable", false))
	%FireButton.disabled = not enabled
	var reason := String(snapshot.get("reason", tr("ui.fire")))
	%FireButton.tooltip_text = reason if not enabled else tr("ui.fire")
	%ReadinessLabel.text = reason if not enabled else ""
	%ReadinessLabel.visible = not enabled and not reason.is_empty()


func focus_fire() -> void:
	%FireButton.grab_focus()
