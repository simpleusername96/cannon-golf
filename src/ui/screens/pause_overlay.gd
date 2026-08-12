class_name PauseOverlay
extends Control

signal resume_requested
signal restart_requested
signal settings_requested
signal stages_requested
signal main_menu_requested


func _ready() -> void:
	%Resume.pressed.connect(func() -> void: resume_requested.emit())
	%Restart.pressed.connect(func() -> void: restart_requested.emit())
	%Settings.pressed.connect(func() -> void: settings_requested.emit())
	%Stages.pressed.connect(func() -> void: stages_requested.emit())
	%MainMenu.pressed.connect(func() -> void: main_menu_requested.emit())


func focus_resume() -> void:
	%Resume.grab_focus()


func focus_settings() -> void:
	%Settings.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if event is InputEventKey and event.echo:
		return
	get_viewport().set_input_as_handled()
	resume_requested.emit()
