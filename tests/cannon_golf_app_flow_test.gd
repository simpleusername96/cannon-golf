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
	_assert(
		(app.get_node("PreviewWorld") as CannonGolfPreviewWorld)._builder is CannonGolfCourseBuilder,
		"preview must own a prepared-course builder"
	)
	app.settings_store.update_setting(&"language", "en")
	_assert((app.get_node("ScreenLayer/MainMenu") as CannonGolfMainMenu)._play.text == "PLAY", "language changes must update the app shell")
	app.settings_store.update_setting(&"language", "ko")

	app.show_course_select(false)
	await process_frame
	var course_select := app.get_node("ScreenLayer/CourseSelect") as CannonGolfCourseSelect
	_assert(app.current_screen == CannonGolfApp.SCREEN_COURSE_SELECT, "course select must expose its screen state")
	var generation_count := CannonGolfCourseTerrainFactory.generation_build_count()
	_assert(course_select.select_course(1), "the second authored course must be selectable")
	await process_frame
	_assert(app.selected_course_index == 1, "course selection must remain zero-based")
	_assert(
		app.get_node("PreviewWorld").course_index != 1,
		"selection must retain the prior preview until the requested artifact is ready"
	)
	var relay_index := CannonGolfCourseCatalog.index_of(&"deep_relay")
	_assert(course_select.select_course(relay_index), "the relay course must be selectable")
	await process_frame
	_assert(app.selected_course_index == relay_index, "the relay course must retain its catalog index")
	_assert(
		CannonGolfCourseTerrainFactory.generation_build_count() == generation_count,
		"Course selection must not synchronously generate terrain."
	)
	var selected_course := CannonGolfCourseCatalog.course_at(relay_index)
	var prepared := await _wait_for_prepared(app, selected_course)
	_assert(prepared != null, "The selected course must receive a prepared artifact before Start.")
	_assert(not (course_select.get_node("%Start") as Button).disabled, "Only a ready artifact may enable Start.")
	_assert(app.get_node("PreviewWorld").course_index == relay_index, "Ready selection must update the live preview.")
	_assert(
		(app.get_node("PreviewWorld") as CannonGolfPreviewWorld)._builder.prepared_course == prepared,
		"Preview must consume the exact ready prepared artifact."
	)

	var game := app.start_selected_course(relay_index)
	await process_frame
	await process_frame
	await process_frame
	_assert(game != null and app.active_game == game, "starting a course must create the real Cannon Golf scene")
	_assert(app.current_screen == CannonGolfApp.SCREEN_GAMEPLAY, "starting a course must expose gameplay state")
	_assert(game.get_meta("initial_course_index") == relay_index, "initial course index must be recorded before the game is added")
	_assert(int(game.get("course_index")) == relay_index, "the selected course must be synchronized into the current game")
	_assert(
		game.initial_prepared_course == prepared,
		"App must inject the ready artifact before gameplay enters the tree."
	)

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


func _wait_for_prepared(
		app: CannonGolfApp, course: CannonGolfCourseData
) -> CannonGolfPreparedCourse:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		var prepared := app.course_artifact_repository.ready_course(course)
		if prepared != null:
			return prepared
		await process_frame
	return null
