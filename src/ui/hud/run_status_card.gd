class_name RunStatusCard
extends Control

signal finish_requested

var _shots_remaining := 0
var _maximum_shots := 0
var _remaining_seconds := 0.0
var _duration_seconds := 0.0
var _clock_started := false


func _ready() -> void:
	%Finish.pressed.connect(func() -> void: finish_requested.emit())
	var finish_shortcut := Shortcut.new()
	var finish_key := InputEventKey.new()
	finish_key.physical_keycode = KEY_F
	finish_shortcut.events = [finish_key]
	%Finish.shortcut = finish_shortcut
	refresh_locale()


func reset_for_stage(maximum_shots: int, duration_seconds: float) -> void:
	_maximum_shots = maxi(maximum_shots, 0)
	_shots_remaining = _maximum_shots
	_duration_seconds = maxf(duration_seconds, 0.0)
	_remaining_seconds = _duration_seconds
	_clock_started = false
	set_finish_available(false)
	_refresh_values()


func update_shots(remaining: int) -> void:
	_shots_remaining = maxi(remaining, 0)
	_refresh_shots()


func update_clock(snapshot: Dictionary) -> void:
	_clock_started = bool(snapshot.get("started", false))
	var ticks_per_second := maxi(int(snapshot.get("ticks_per_second", Engine.physics_ticks_per_second)), 1)
	var duration_ticks := maxi(int(snapshot.get("duration_ticks", 0)), 0)
	var remaining_ticks := maxi(int(snapshot.get("remaining_ticks", duration_ticks)), 0)
	if duration_ticks > 0:
		_duration_seconds = float(duration_ticks) / float(ticks_per_second)
		_remaining_seconds = float(remaining_ticks) / float(ticks_per_second)
	_refresh_clock()


func set_finish_available(available: bool) -> void:
	%Finish.disabled = not available
	%Finish.tooltip_text = tr("hud.finish_tooltip") if available else tr("hud.finish_disabled_tooltip")


func finish_is_available() -> bool:
	return not %Finish.disabled


func focus_finish() -> void:
	if finish_is_available():
		%Finish.grab_focus()


func refresh_locale() -> void:
	%TimeValue.tooltip_text = tr("hud.time")
	%ShotsValue.tooltip_text = tr("hud.shots")
	%Finish.text = tr("ui.finish")
	_refresh_values()
	set_finish_available(finish_is_available())


func _refresh_values() -> void:
	_refresh_clock()
	_refresh_shots()


func _refresh_clock() -> void:
	var shown_seconds := _remaining_seconds if _clock_started else _duration_seconds
	%TimeValue.text = _format_duration(shown_seconds) if shown_seconds > 0.0 else "--:--"
	%TimeValue.tooltip_text = tr("hud.timer_starts_on_first_shot") \
			if not _clock_started else tr("hud.time")


func _refresh_shots() -> void:
	%ShotsValue.text = "%d / %d" % [_shots_remaining, _maximum_shots]


func _format_duration(seconds: float) -> String:
	var total_seconds := maxi(ceili(seconds), 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
