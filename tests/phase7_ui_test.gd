extends SceneTree

const APP_SCENE := preload("res://scenes/app/app.tscn")

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.persistence_enabled = false
	var unlocked: Dictionary = root.get_node("/root/SaveSystem").default_data()
	unlocked.unlocked_stages = ["first_descent", "burst_basin", "split_ridge"]
	unlocked.selected_stage_id = "stage_02"
	game_state.initialize_from_data(unlocked)
	var app := APP_SCENE.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var main_menu: MainMenuScreen = app.get_node("MainMenu")
	var stage_select: StageSelectScreen = app.get_node("StageSelect")
	var settings: SettingsScreen = app.get_node("Settings")
	_assert_true(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "UI must use the 1280x720 logical viewport")
	_assert_theme_contract()
	_assert_true(main_menu.visible and not stage_select.visible and not settings.visible, "app must open on a separate main-menu screen")
	_assert_main_menu_focus_startup(main_menu)
	await _assert_main_preview_safe(app, main_menu, &"stage_02")
	app._set_catalog_load_failed()
	await process_frame
	var retry_load := main_menu.get_node("Root/BrandPanel/Margin/Content/Play") as Button
	_assert_true(
		not retry_load.disabled and retry_load.text == "다시 불러오기",
		"a missing catalog must expose an enabled retry action instead of endless loading"
	)

	app._show_stage_select()
	await process_frame
	_assert_true(stage_select.visible and not main_menu.visible, "stage select must replace the main menu")
	app._set_catalog_load_failed()
	await process_frame
	var stage_retry := stage_select._start_button
	_assert_true(
		not stage_retry.disabled and stage_retry.text == "다시 불러오기",
		"a missing catalog on Stage Select must expose an enabled localized retry action"
	)
	for card in stage_select._cards:
		_assert_true(not card.disabled, "unlocked stage cards must be keyboard-selectable")
	_assert_true(stage_select._page_label.text == "1-8 / 30", "stage select must show the inclusive first-page range")
	stage_select.set_page_for_capture(1)
	_assert_true(stage_select._page_label.text == "9-16 / 30", "stage select must show the inclusive second-page range")
	stage_select.set_page_for_capture(3)
	_assert_true(stage_select._page_label.text == "25-30 / 30", "stage select must show the inclusive final-page range")
	_assert_true(stage_select._next_page.disabled and not stage_select._previous_page.disabled, "page edge controls must disable only the unavailable direction")
	stage_select.set_page_for_capture(0)
	stage_select._cards[1].pressed.emit()
	_assert_true(stage_select.selected_stage_id() == &"stage_02" and stage_select._cards[1].button_pressed, "stage selection must expose a visible selected state")

	app._show_settings(&"stage_select")
	await process_frame
	_assert_true(settings.visible and not stage_select.visible, "settings must be a separate full-screen interface")
	settings.visible = false
	settings.close_requested.emit()
	await process_frame
	_assert_true(stage_select.visible, "closing settings must return to its calling screen")

	app._start_stage(&"first_descent")
	var gameplay := await _wait_for_child(app, ^"ActiveGameplay")
	_assert_true(gameplay != null, "stage start must complete after asynchronous layout preparation")
	if gameplay == null:
		game_state.persistence_enabled = true
		app.queue_free()
		await process_frame
		quit(1)
		return
	var controller: StageController = gameplay.get_node("StageController")
	var hud_root := gameplay.get_node("HUD/HUDRoot") as Control
	var next_stage_id := StageCatalog.next_stage_id(&"stage_01")
	_assert_true(
		not app._layout_repository.is_preparing(next_stage_id),
		"active Gameplay must not compete with next-stage layout preparation"
	)
	_assert_true(
		not app._runtime_preparer.is_preparing(next_stage_id),
		"active Gameplay must not compete with next-stage artifact preparation"
	)
	_assert_true(controller.current_state == StageController.State.BRIEFING, "stage start must enter the separate briefing interface")
	_assert_true(hud_root.get_node("BriefingActions").visible, "briefing action lane must be visible before aiming")
	_assert_true(
		(hud_root.get_node("BriefingActions/Back") as Button).text == tr("ui.back") \
				and (hud_root.get_node("BriefingActions/Start") as Button).text \
						== tr("ui.start_aiming"),
		"briefing actions must resolve their visible locale without renderer-dependent key translation"
	)
	for mechanism in gameplay.get_node("Mechanisms").get_children():
		var label := mechanism.get_node_or_null("BriefingLabel") as Label3D
		_assert_true(mechanism.visible, "%s glyph geometry must remain visible in briefing" % mechanism.name)
		_assert_true(label != null and not label.visible, "%s briefing text label must stay hidden" % mechanism.name)
	_assert_true(controller.begin_aiming(), "UI flow test must enter aiming")
	await process_frame
	_assert_aiming_hud_contract(hud_root)
	_assert_true(controller.toggle_pause(), "pause must be reachable from gameplay")
	var pause_overlay := hud_root.get_node("PauseOverlay") as Control
	_assert_true(pause_overlay.visible, "pause overlay must expose its own screen")
	_assert_true(pause_overlay.get_node_or_null("Center/Panel/Margin/Column/Restart") is Button, "Restart must remain available from the paused menu")
	app._on_gameplay_navigation(&"settings")
	await process_frame
	_assert_true(settings.visible, "paused gameplay must be able to open full settings")
	_assert_true(not pause_overlay.visible, "Settings must suspend the Pause presentation instead of stacking scrims")
	_assert_true(controller.current_state == StageController.State.PAUSED and paused, "opening Settings must preserve the paused stage and tree")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	settings._unhandled_input(cancel)
	await process_frame
	await process_frame
	_assert_true(pause_overlay.visible, "closing Settings must restore the Pause presentation")
	_assert_true(controller.current_state == StageController.State.PAUSED and paused, "closing Settings must not resume the stage or tree")
	_assert_true(pause_overlay.get_node("Center/Panel/Margin/Column/Settings").has_focus(), "Settings close must restore focus to Pause Settings")
	var shots_before_blocked_fire := controller.shots_remaining
	_assert_true(not controller.request_fire() and controller.shots_remaining == shots_before_blocked_fire, "the paused child-modal flow must keep gameplay input blocked")
	controller.toggle_pause()
	controller.force_finish_debug()
	await process_frame
	_assert_true(hud_root.get_node("ResultPanel").visible, "terminal coverage snapshot must show the result interface")
	_assert_true(hud_root.get_node("ResultPanel").size.x <= 1280.0 * 0.35, "result panel must use no more than 35 percent of the viewport width")
	var result_content := hud_root.get_node("ResultPanel/Margin/Content")
	_assert_true(result_content.get_node("Retry") is Button, "result must expose retry as a real button")
	_assert_true(result_content.get_node("Target") is Label, "result must retain the authoritative target fact")

	app._on_gameplay_navigation(&"stage_select")
	await process_frame
	_assert_true(stage_select.visible and app.get_node_or_null("ActiveGameplay") == null, "stage select navigation must cleanly leave gameplay")
	if not _failed:
		print("Phase 7 UI flow passed: menu, stage select, settings, briefing, pause, result, and clean navigation.")
	game_state.persistence_enabled = true
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if _failed else 0)


func _wait_for_child(parent: Node, path: NodePath, timeout_ms: int = 60000) -> Node:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var child := parent.get_node_or_null(path)
		if child != null:
			return child
		await create_timer(0.01).timeout
	return null


func _assert_main_preview_safe(
	app: AppRoot,
	main_menu: MainMenuScreen,
	expected_stage_id: StringName
) -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline \
			and app._active_preview_stage_id != expected_stage_id:
		await process_frame
	_assert_true(
		app._active_preview_stage_id == expected_stage_id,
		"Main Menu preview must resolve the currently selected stage artifact"
	)
	if app._active_preview_stage_id != expected_stage_id:
		return
	var stage := StageCatalog.get_stage(expected_stage_id)
	var artifact: StageRuntimeArtifact = app._runtime_preparer.ready_artifact(stage)
	_assert_true(artifact != null, "Main Menu preview must reuse the typed runtime artifact")
	if artifact == null:
		return
	var local_points := artifact.presentation_local_points
	var world_points := PackedVector3Array()
	for local_point in local_points:
		world_points.append(app._preview_mountain.to_global(local_point))
	var camera := app._preview_camera
	var focus := camera.global_position - camera.global_transform.basis.z * 10.0
	_assert_true(
		TerrainCameraFramer.pose_fits_points_in_normalized_rect(
			world_points,
			camera.global_position,
			focus,
			camera.fov,
			16.0 / 9.0,
			AppRoot.PREVIEW_SAFE_RECT
		),
		"Main Menu preview landmarks must remain inside the right-side safe region"
	)
	var preview_boundary := 1280.0 * AppRoot.PREVIEW_SAFE_RECT.position.x
	for action_name in ["Play", "StageSelect", "Settings", "Quit"]:
		var action := main_menu.get_node("Root/BrandPanel/Margin/Content/%s" % action_name) as Button
		_assert_true(
			action.get_global_rect().end.x <= preview_boundary,
			"Main Menu action column must not overlap the preview safe region"
		)


func _assert_main_menu_focus_startup(main_menu: MainMenuScreen) -> void:
	var play := main_menu.get_node("Root/BrandPanel/Margin/Content/Play") as Button
	var stage_select := main_menu.get_node("Root/BrandPanel/Margin/Content/StageSelect") as Button
	var settings := main_menu.get_node("Root/BrandPanel/Margin/Content/Settings") as Button
	_assert_true(
		not play.has_focus() and not stage_select.has_focus() and not settings.has_focus(),
		"passive Main Menu launch must not show a keyboard focus ring"
	)
	main_menu.set_play_preparation_state(false)
	main_menu._unhandled_key_input(_keyboard_navigation_event())
	_assert_true(stage_select.has_focus(), "first keyboard navigation while loading must focus Stage Select")
	main_menu.set_play_preparation_state(true)
	_assert_true(play.has_focus(), "Play readiness must replace only the loading fallback focus")
	main_menu.begin_passive_focus_session()
	main_menu.set_play_preparation_state(false)
	main_menu._unhandled_key_input(_keyboard_navigation_event())
	main_menu._input(_keyboard_navigation_event())
	settings.grab_focus()
	stage_select.grab_focus()
	main_menu.set_play_preparation_state(true)
	_assert_true(
		stage_select.has_focus(),
		"Play readiness must preserve a later focus choice even after returning to Stage Select"
	)
	main_menu.set_play_preparation_state(false, true)
	_assert_true(not play.disabled, "load failure must retain its reachable retry action")


func _keyboard_navigation_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.pressed = true
	return event


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true


func _assert_theme_contract() -> void:
	var theme: Theme = load("res://resources/ui/paint_mountain_theme.tres")
	_assert_true(theme.default_font_size == 16, "theme body type must be at least 16px")
	var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	var routine_button := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var primary := theme.get_stylebox("normal", "PrimaryButton") as StyleBoxTexture
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	var debug_panel := theme.get_stylebox("panel", "DebugPanel") as StyleBoxFlat
	_assert_true(panel != null and panel.corner_radius_top_left == 14, "shared panels must use the quiet 14px radius token")
	_assert_true(routine_button != null and routine_button.corner_radius_top_left == 10, "routine actions must use the flat quiet button token")
	_assert_true(primary != null and primary.texture != null, "primary actions must use the shared textured button asset")
	_assert_true(focus.border_width_left == 2 and focus.border_color.is_equal_approx(Color("70aaff")), "keyboard focus must use the 2px focus token")
	_assert_true(debug_panel != null and debug_panel.corner_radius_top_left == 10, "debug panel style must remain theme-owned")
	_assert_true(not theme.is_type_variation(&"HudKeycapPanel", &"PanelContainer"), "obsolete outlined shortcut keycaps must be absent")
	_assert_true(theme.is_type_variation(&"StageCardButton", &"Button"), "stage selection must use a semantic card role")
	_assert_true(theme.is_type_variation(&"SettingsSwitchRow", &"CheckButton"), "settings switches must use the shared unboxed row role")
	_assert_true(
		theme.get_icon(&"checked", &"SettingsSwitchRow") != null \
				and theme.get_icon(&"unchecked", &"SettingsSwitchRow") != null,
		"settings switches must use the approved full-size checked and unchecked assets"
	)
	_assert_true(
		theme.get_stylebox(&"slider", &"HSlider") != null \
				and theme.get_stylebox(&"grabber_area", &"HSlider") != null \
				and theme.get_icon(&"grabber", &"HSlider") != null,
		"settings sliders must use the shared rail, fill, and grabber assets"
	)
	for variation in [
		&"HudCaption", &"HudBody", &"HudSection", &"HudValue", &"HudMetric", &"HudLegend", &"ScreenTitle",
		&"StageCardNumber", &"StageCardName", &"StageCardFacts", &"StagePreviewFacts", &"StagePreviewBest",
		&"SettingsLabel", &"SettingsValue", &"ResultTitle", &"ResultCoverage", &"ResultTarget",
		&"ResultGrade", &"ResultFact", &"ResultMetadata",
	]:
		_assert_true(theme.is_type_variation(variation, &"Label"), "%s must be a shared Label variation" % variation)
	for variation in [&"HudModeButton", &"HudIconButton", &"HudFinishButton", &"PrimaryButton"]:
		_assert_true(theme.is_type_variation(variation, &"Button"), "%s must be a shared Button variation" % variation)
	var caption_font := theme.get_font(&"font", &"HudCaption") as FontVariation
	var section_font := theme.get_font(&"font", &"HudSection") as FontVariation
	var title_font := theme.get_font(&"font", &"ScreenTitle") as FontVariation
	_assert_true(caption_font != null and int(caption_font.variation_opentype.get("weight", 0)) == 500, "HUD captions must use Theme-owned Pretendard weight 500")
	_assert_true(section_font != null and int(section_font.variation_opentype.get("weight", 0)) == 600, "HUD sections must use Theme-owned Pretendard weight 600")
	_assert_true(title_font != null and int(title_font.variation_opentype.get("weight", 0)) == 700, "screen titles must use Theme-owned Pretendard weight 700")


func _assert_aiming_hud_contract(hud_root: Control) -> void:
	_assert_true(
		hud_root.get_node_or_null("ShotSummary") == null \
				and hud_root.get_node_or_null("MechanismInfoCard") == null,
		"normal gameplay must not contain passive shot or mechanism message cards"
	)
	var rendered_hud_rect := hud_root.get_global_rect()
	var logical_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	)
	# Headless canvas-items/expand can report a square expanded root. Authored HUD
	# offsets and the delivery contract use the fixed logical 1280x720 rectangle.
	var hud_rect := Rect2(rendered_hud_rect.position, logical_size)
	var hud_center := hud_rect.get_center()
	var coverage := hud_root.get_node("CoverageMeter") as CoverageMeter
	var coverage_value := coverage.get_node_or_null("CoverageValue") as Label
	var target_value := coverage.get_node_or_null("TargetValue") as Label
	var progress := coverage.get_node_or_null("Progress") as ProgressBar
	_assert_true(hud_root.get_node_or_null("TopStatusBar/TargetChip") == null, "the left coverage meter must be the sole target owner")
	_assert_true(coverage_value != null and target_value != null, "the left coverage meter must own both current and target values")
	_assert_true(progress != null and progress.fill_mode == ProgressBar.FILL_BOTTOM_TO_TOP, "the coverage rail must fill from bottom to top")
	_assert_true(coverage.is_visible_in_tree() and coverage.get_global_rect().get_center().x < hud_center.x, "the coverage meter must remain on the left during aiming")

	var actions := hud_root.get_node("ActionButtons") as ActionButtons
	var fire := actions.get_node_or_null("FireButton") as Button
	var fire_rect := fire.get_global_rect()
	_assert_true(actions.find_children("*", "Button", true, false).size() == 1, "Fire must be the sole aiming action")
	_assert_true(actions.find_child("Restart", true, false) == null, "Restart must be absent from the aiming actions")
	_assert_true(fire.is_visible_in_tree(), "Fire must remain visible while aiming")
	_assert_true(
		fire_rect.get_center().x > hud_rect.position.x + hud_rect.size.x * 0.35 \
				and fire_rect.get_center().x < hud_rect.position.x + hud_rect.size.x * 0.65,
		"Fire must remain horizontally centered in the aiming action area"
	)
	_assert_true(
		fire_rect.position.y >= hud_rect.position.y + hud_rect.size.y * 0.75,
		"Fire must remain in the lower aiming action area: fire_y=%.1f hud_y=%.1f hud_h=%.1f" % [
			fire_rect.position.y, hud_rect.position.y, hud_rect.size.y,
		]
	)
	_assert_true(not (hud_root.get_node("PauseOverlay") as Control).visible, "the paused-menu Restart must stay hidden during aiming")

	var status := hud_root.get_node("RunStatusCard") as RunStatusCard
	var settings := hud_root.get_node("TopStatusBar/SettingsButton") as Button
	var status_rect := status.get_global_rect()
	var settings_rect := settings.get_global_rect()
	_assert_true(
		status_rect.get_center().x > hud_center.x and status_rect.size == Vector2(284.0, 52.0),
		"run state must stay a 284x52 shallow borderless instrument row"
	)
	_assert_true(status.get_child_count() == 5, "run status must expose only time, shots, and Finish")
	var shots := status.get_node("ShotsValue") as Label
	var finish := status.get_node("Finish") as Button
	_assert_true(
		finish.get_global_rect().position.x >= shots.get_global_rect().end.x,
		"Finish must immediately follow the shot count"
	)
	_assert_true(settings_rect.get_center().x > hud_center.x and settings_rect.get_center().y < hud_center.y, "settings must stay in the upper-right")
	_assert_true(not settings_rect.intersects(status_rect), "settings must not overlap the status instruments")
	for control in [coverage, fire, status, settings]:
		_assert_true(hud_rect.encloses(control.get_global_rect()), "%s must remain inside the logical HUD bounds" % control.name)
