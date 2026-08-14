class_name CannonGolfApp
extends Node

signal screen_changed(screen: StringName)
signal course_started(course_index: int)

const SCREEN_MAIN_MENU := &"main_menu"
const SCREEN_COURSE_SELECT := &"course_select"
const SCREEN_SETTINGS := &"settings"
const SCREEN_GAMEPLAY := &"gameplay"

const MAIN_MENU_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_main_menu.tscn")
const COURSE_SELECT_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_course_select.tscn")
const SETTINGS_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_settings.tscn")
const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")

@onready var _preview_world: CannonGolfPreviewWorld = %PreviewWorld
@onready var _screen_layer: CanvasLayer = %ScreenLayer
@onready var _transition: ColorRect = %Transition

var current_screen: StringName = SCREEN_MAIN_MENU
var selected_course_index := 0
var active_game: Node3D
var settings_store: CannonGolfSettingsStore
var course_artifact_repository: CannonGolfCourseArtifactRepository

var _main_menu: CannonGolfMainMenu
var _course_select: CannonGolfCourseSelect
var _settings: CannonGolfSettingsScreen
var _settings_return_screen := SCREEN_MAIN_MENU
var _settings_return_gameplay := false


func _ready() -> void:
	settings_store = CannonGolfSettingsStore.new()
	settings_store.load_settings()
	settings_store.changed.connect(_on_settings_changed)
	settings_store.apply_runtime(get_viewport())
	course_artifact_repository = CannonGolfCourseArtifactRepository.new()
	course_artifact_repository.name = "CourseArtifactRepository"
	add_child(course_artifact_repository)
	course_artifact_repository.course_ready.connect(_on_prepared_course_ready)
	course_artifact_repository.course_failed.connect(_on_prepared_course_failed)
	_create_screens()
	_apply_language(String(settings_store.get_settings()[&"language"]))
	show_main_menu(false)
	_request_selected_course(selected_course_index)


func _create_screens() -> void:
	_main_menu = MAIN_MENU_SCENE.instantiate() as CannonGolfMainMenu
	_main_menu.name = "MainMenu"
	_screen_layer.add_child(_main_menu)
	_main_menu.play_requested.connect(start_selected_course)
	_main_menu.course_select_requested.connect(show_course_select)
	_main_menu.settings_requested.connect(func() -> void: show_settings(SCREEN_MAIN_MENU))
	_main_menu.quit_requested.connect(_quit_requested)

	_course_select = COURSE_SELECT_SCENE.instantiate() as CannonGolfCourseSelect
	_course_select.name = "CourseSelect"
	_screen_layer.add_child(_course_select)
	_course_select.back_requested.connect(show_main_menu)
	_course_select.start_requested.connect(start_selected_course)
	_course_select.selection_changed.connect(_on_course_selection_changed)

	_settings = SETTINGS_SCENE.instantiate() as CannonGolfSettingsScreen
	_settings.name = "Settings"
	_screen_layer.add_child(_settings)
	_settings.configure(settings_store)
	_settings.close_requested.connect(_on_settings_closed)


func show_main_menu(animate: bool = true) -> void:
	_remove_active_game()
	_hide_screens()
	_preview_world.set_preview_visible(true)
	_main_menu.visible = true
	_main_menu.begin_passive_focus_session()
	_set_screen(SCREEN_MAIN_MENU, animate)
	_main_menu.focus_primary()


func show_course_select(animate: bool = true) -> void:
	_remove_active_game()
	_hide_screens()
	_preview_world.set_preview_visible(true)
	_course_select.set_selected_course_index(selected_course_index)
	_request_selected_course(selected_course_index)
	_course_select.visible = true
	_set_screen(SCREEN_COURSE_SELECT, animate)
	_course_select.focus_primary()


func show_settings(return_to: StringName = SCREEN_MAIN_MENU) -> void:
	_settings_return_screen = return_to
	_settings_return_gameplay = return_to == SCREEN_GAMEPLAY and active_game != null
	if _settings_return_gameplay:
		_call_game_overlay(true)
	else:
		_main_menu.visible = false
		_course_select.visible = false
	_settings.open()
	_set_screen(SCREEN_SETTINGS, true)


func start_selected_course(index: int = -1) -> Node3D:
	if index >= 0:
		selected_course_index = index
	var course := CannonGolfCourseCatalog.course_at(selected_course_index)
	if course == null:
		return null
	var prepared := course_artifact_repository.ready_course(course)
	if prepared == null:
		_request_selected_course(selected_course_index)
		return null
	_course_select.set_selected_course_index(selected_course_index)
	_remove_active_game()
	_hide_screens()
	_preview_world.set_preview_visible(false)

	var game := GAME_SCENE.instantiate() as Node3D
	if game == null:
		return null
	game.set_meta(&"initial_course_index", selected_course_index)
	if _has_property(game, &"initial_course_index"):
		game.set(&"initial_course_index", selected_course_index)
	if _has_property(game, &"initial_prepared_course"):
		game.set(&"initial_prepared_course", prepared)
	if game.has_signal(&"navigation_requested"):
		game.connect(&"navigation_requested", Callable(self, &"_on_game_navigation"))
	add_child(game)
	active_game = game
	if game.has_method(&"apply_language"):
		game.call(&"apply_language", String(settings_store.get_settings()[&"language"]))
	_set_screen(SCREEN_GAMEPLAY, true)
	course_started.emit(selected_course_index)
	return game


func handle_game_navigation(destination: StringName) -> void:
	_on_game_navigation(destination)


func _on_game_navigation(destination: StringName) -> void:
	match destination:
		&"settings":
			show_settings(SCREEN_GAMEPLAY)
		&"course_select":
			show_course_select()
		&"main_menu":
			show_main_menu()


func _on_course_selection_changed(index: int) -> void:
	selected_course_index = index
	_request_selected_course(index)


func _request_selected_course(index: int) -> void:
	var course := CannonGolfCourseCatalog.course_at(index)
	if course == null or course_artifact_repository == null:
		return
	var prepared := course_artifact_repository.ready_course(course)
	if prepared != null:
		_on_prepared_course_ready(course.course_id, prepared)
		return
	_course_select.set_course_preparation_state(
		CannonGolfCourseSelect.CoursePreparationState.PREPARING
	)
	course_artifact_repository.request_course(course)


func _on_prepared_course_ready(
		course_id: StringName, prepared: CannonGolfPreparedCourse
) -> void:
	var course := CannonGolfCourseCatalog.course_at(selected_course_index)
	if course == null or course.course_id != course_id or not prepared.is_valid_for(course):
		return
	_course_select.set_course_preparation_state(
		CannonGolfCourseSelect.CoursePreparationState.READY
	)
	if _preview_world.visible:
		_preview_world.show_course(selected_course_index, prepared)


func _on_prepared_course_failed(course_id: StringName) -> void:
	var course := CannonGolfCourseCatalog.course_at(selected_course_index)
	if course == null or course.course_id != course_id:
		return
	_course_select.set_course_preparation_state(
		CannonGolfCourseSelect.CoursePreparationState.FAILED
	)


func _on_settings_closed() -> void:
	if _settings_return_gameplay and active_game != null and is_instance_valid(active_game):
		_settings.visible = false
		_call_game_overlay(false)
		_set_screen(SCREEN_GAMEPLAY, false)
		if active_game.has_method(&"focus_pause_settings"):
			active_game.call_deferred(&"focus_pause_settings")
		return
	if _settings_return_screen == SCREEN_COURSE_SELECT:
		show_course_select(false)
	else:
		show_main_menu(false)


func _on_settings_changed(values: Dictionary) -> void:
	if settings_store == null:
		return
	settings_store.apply_runtime(get_viewport())
	_apply_language(String(values[&"language"]))


func _apply_language(language: String) -> void:
	if _main_menu != null:
		_main_menu.apply_language(language)
	if _course_select != null:
		_course_select.apply_language(language)
	if active_game != null and is_instance_valid(active_game) \
			and active_game.has_method(&"apply_language"):
		active_game.call(&"apply_language", language)


func _call_game_overlay(open: bool) -> void:
	if active_game != null and is_instance_valid(active_game) \
			and active_game.has_method(&"set_external_overlay_open"):
		active_game.call(&"set_external_overlay_open", open)


func _remove_active_game() -> void:
	if active_game == null or not is_instance_valid(active_game):
		return
	_call_game_overlay(false)
	get_tree().paused = false
	active_game.queue_free()
	active_game = null


func _hide_screens() -> void:
	_main_menu.visible = false
	_course_select.visible = false
	_settings.visible = false


func _set_screen(next_screen: StringName, animate: bool) -> void:
	current_screen = next_screen
	screen_changed.emit(next_screen)
	if animate:
		_flash_transition()


func _flash_transition() -> void:
	if settings_store != null and bool(settings_store.get_settings()[&"reduced_motion"]):
		return
	_transition.visible = true
	_transition.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_transition, ^"modulate:a", 0.14, 0.04)
	tween.tween_property(_transition, ^"modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void: _transition.visible = false)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return true
	return false


func _quit_requested() -> void:
	get_tree().quit()
