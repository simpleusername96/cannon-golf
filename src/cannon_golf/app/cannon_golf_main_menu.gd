class_name CannonGolfMainMenu
extends Control

signal play_requested
signal course_select_requested
signal settings_requested
signal quit_requested

@onready var _play: Button = %Play
@onready var _course_select: Button = %CourseSelect
@onready var _settings: Button = %Settings
@onready var _quit: Button = %Quit


func _ready() -> void:
	_play.pressed.connect(func() -> void: play_requested.emit())
	_course_select.pressed.connect(_emit_course_select)
	_settings.pressed.connect(func() -> void: settings_requested.emit())
	_quit.pressed.connect(func() -> void: quit_requested.emit())


func focus_primary() -> void:
	_play.grab_focus.call_deferred()


func begin_passive_focus_session() -> void:
	if get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_get_focus_owner().release_focus()


func apply_language(language: String) -> void:
	var english := language == "en"
	_play.text = "PLAY" if english else "플레이"
	_course_select.text = "LEVEL SELECT" if english else "레벨 선택"
	_settings.text = "SETTINGS" if english else "설정"
	_quit.text = "QUIT" if english else "종료"


func _emit_course_select() -> void:
	course_select_requested.emit()
