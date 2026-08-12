extends SceneTree

const APP_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_app.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := APP_SCENE.instantiate() as CannonGolfApp
	root.add_child(app)
	await process_frame
	await process_frame

	_assert(app.current_screen == CannonGolfApp.SCREEN_MAIN_MENU, "app must open at the Cannon Golf main menu")
	_assert(app.get_node_or_null("ScreenLayer/MainMenu") is CannonGolfMainMenu, "main menu must be Cannon Golf-owned")
	_assert(app.get_node_or_null("ScreenLayer/CourseSelect") is CannonGolfCourseSelect, "course select must be Cannon Golf-owned")
	_assert(app.get_node_or_null("ScreenLayer/Settings") is CannonGolfSettingsScreen, "settings must be Cannon Golf-owned")
	_assert(app.get_node_or_null("PreviewWorld/PreviewCourseBuilder") is CannonGolfCourseBuilder, "preview must use the live course builder")
	app.settings_store.update_setting(&"language", "en")
	_assert((app.get_node("ScreenLayer/MainMenu") as CannonGolfMainMenu)._play.text == "PLAY", "language changes must update the app shell")
	app.settings_store.update_setting(&"language", "ko")

	app.show_course_select(false)
	await process_frame
	var course_select := app.get_node("ScreenLayer/CourseSelect") as CannonGolfCourseSelect
	_assert(app.current_screen == CannonGolfApp.SCREEN_COURSE_SELECT, "course select must expose its screen state")
	_assert(course_select.select_course(1), "the second authored course must be selectable")
	await process_frame
	_assert(app.selected_course_index == 1, "course selection must remain zero-based")
	_assert(app.get_node("PreviewWorld").course_index == 1, "selection must update the live preview")

	var game := app.start_selected_course(1)
	await process_frame
	await process_frame
	await process_frame
	_assert(game != null and app.active_game == game, "starting a course must create the real Cannon Golf scene")
	_assert(app.current_screen == CannonGolfApp.SCREEN_GAMEPLAY, "starting a course must expose gameplay state")
	_assert(game.get_meta("initial_course_index") == 1, "initial course index must be recorded before the game is added")
	_assert(int(game.get("course_index")) == 1, "the selected course must be synchronized into the current game")

	app.handle_game_navigation(&"settings")
	await process_frame
	_assert(app.current_screen == CannonGolfApp.SCREEN_SETTINGS, "game navigation must open settings")
	_assert(app.active_game == game, "settings from gameplay must keep the game instance")
	var settings := app.get_node("ScreenLayer/Settings") as CannonGolfSettingsScreen
	settings.close()
	await process_frame
	_assert(app.current_screen == CannonGolfApp.SCREEN_GAMEPLAY, "closing gameplay settings must return to gameplay")
	_assert(paused, "closing gameplay settings must return to the paused gameplay overlay")
	game.toggle_pause()
	_assert(not paused, "resume after gameplay settings must release scene-tree pause")

	app.handle_game_navigation(&"course_select")
	await process_frame
	_assert(app.current_screen == CannonGolfApp.SCREEN_COURSE_SELECT, "course-select navigation must reach course select")
	_assert(app.active_game == null, "leaving gameplay must release the game instance")

	app.show_main_menu(false)
	await process_frame
	_assert(app.current_screen == CannonGolfApp.SCREEN_MAIN_MENU, "course select must return to main menu")

	app.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
