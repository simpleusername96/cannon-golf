extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	root.size = Vector2i(1280, 720)
	var game_state := root.get_node("/root/GameState") as GameState
	game_state.persistence_enabled = false
	game_state.select_stage(&"stage_10")
	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_10")
	_assert_true(gameplay != null, "shortcut prompt fixture must load Stage 10")
	if gameplay == null:
		quit(1)
		return
	root.add_child(gameplay)
	await physics_frame
	await process_frame
	var controller := gameplay.get_node("StageController") as StageController
	var hud := gameplay.get_node("HUD") as HUDController
	var root_control := gameplay.get_node("HUD/HUDRoot") as Control
	_assert_true(controller.begin_aiming(), "shortcut fixture must enter Aim View")
	await process_frame
	var legend := root_control.get_node("ContextLegend") as ContextLegend
	_assert_true(
		legend.visible and legend.context_mode == ContextLegend.Mode.AIM,
		"Aim View must expose one shared Aim context legend"
	)
	_assert_legend_contains(legend, ["S/W", "Space", "F", "Tab", "Esc", "각도", "파워", "발사", "완료"])
	_assert_true(
		"Space" not in (root_control.get_node("ActionButtons/FireButton") as Button).text,
		"Fire control must leave Space to the context legend"
	)
	_assert_true(
		"F" not in (root_control.get_node("RunStatusCard/Finish") as Button).text,
		"Finish control must leave F to the context legend"
	)
	_assert_true(
		"Tab" not in (root_control.get_node("CameraInteractionControl") as Button).text,
		"camera mode control must leave Tab to the context legend"
	)
	_assert_true(
		(legend.get_node("Center/Items/PowerItem/Input") as TextureRect).texture != null,
		"Aim context must use the real mouse-wheel glyph"
	)
	_assert_true(
		root_control.get_node_or_null("AimControls/Content/YawHint") == null,
		"derived target yaw must not advertise unavailable A/D steering"
	)
	_assert_true(
		root_control.get_node_or_null("AimControls/Content/DirectionValue") == null \
				and root_control.get_node_or_null("AimControls/Content/DirectionCaption") == null,
		"target-derived yaw must not remain visible"
	)
	for detached_path in [
		"ActionButtons/FireButton/FireShortcut",
		"CameraInteractionControl/ModeShortcut",
		"RunStatusCard/Finish/FinishShortcut",
		"TopStatusBar/SettingsButton/SettingsShortcut",
		"AimControls/Content/AngleDecreaseHint",
		"AimControls/Content/AngleIncreaseHint",
		"AimControls/Content/PowerHint",
	]:
		_assert_true(
			root_control.get_node_or_null(detached_path) == null,
			"%s must not remain as a detached shortcut badge" % detached_path
		)
	_assert_true(
		root_control.get_node_or_null("FirstSessionHint") == null,
		"transient first-session prompt must not remain"
	)

	hud.set_interaction_mode(CameraDirector.InteractionMode.MAP_INSPECTION)
	_assert_true(
		root_control.get_node("CameraInteractionControl").visible \
				and not root_control.get_node("ActionButtons").visible,
		"Map View must keep its Tab control and hide aim-only actions"
	)
	_assert_true(
		legend.context_mode == ContextLegend.Mode.MAP \
				and not legend.get_node("Center/Items/AngleItem").visible \
				and not legend.get_node("Center/Items/FireItem").visible,
		"Map View must switch the shared legend instead of leaving Aim prompts"
	)
	hud.set_interaction_mode(CameraDirector.InteractionMode.AIM_LOCKED)
	hud.set_camera_mode(CameraDirector.Mode.FOLLOW)
	_assert_true(
		root_control.get_node("ReturnToCannon").visible \
				and not root_control.get_node("ActionButtons").visible \
				and legend.context_mode == ContextLegend.Mode.FOLLOW,
		"Shot Follow must show Return with Tab without aim prompts"
	)
	_assert_legend_contains(legend, ["Tab", "대포로 돌아가기", "Esc"])
	hud.set_camera_mode(CameraDirector.Mode.AIMING)
	_assert_true(
		controller.toggle_pause(), "Escape prompt fixture must enter pause"
	)
	await process_frame
	var pause_legend := root_control.get_node("PauseOverlay/ContextLegend") as ContextLegend
	_assert_true(
		pause_legend.visible and pause_legend.context_mode == ContextLegend.Mode.PAUSE,
		"Pause must use the same context legend primitive"
	)
	_assert_legend_contains(pause_legend, ["Esc", "계속"])
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	(root_control.get_node("PauseOverlay") as PauseOverlay)._unhandled_input(escape)
	await process_frame
	_assert_true(
		controller.current_state == StageController.State.AIMING,
		"Escape shown on Continue must resume the paused board"
	)

	var aim_before := Vector3(
		gameplay.get_node("Cannon").yaw_degrees,
		gameplay.get_node("Cannon").elevation_degrees,
		gameplay.get_node("Cannon").power_percent
	)
	var restart_key := InputEventKey.new()
	restart_key.keycode = KEY_R
	restart_key.physical_keycode = KEY_R
	restart_key.pressed = true
	gameplay._unhandled_input(restart_key)
	_assert_true(
		controller.current_state == StageController.State.AIMING \
				and Vector3(
					gameplay.get_node("Cannon").yaw_degrees,
					gameplay.get_node("Cannon").elevation_degrees,
					gameplay.get_node("Cannon").power_percent
				).is_equal_approx(aim_before),
		"hidden direct R restart must no longer act"
	)

	TranslationServer.set_locale("en")
	root.size = Vector2i(1920, 1080)
	hud._on_settings_changed(game_state.settings)
	await process_frame
	for path in [
		"ActionButtons/FireButton",
		"CameraInteractionControl",
		"TopStatusBar/SettingsButton",
		"AimControls",
		"ContextLegend",
	]:
		_assert_inside_viewport(root_control.get_node(path) as Control, path)
	gameplay.queue_free()
	await process_frame
	TranslationServer.set_locale("ko")
	game_state.persistence_enabled = true
	if not _failed:
		print("Shortcut prompts passed: one responsive context legend, F shortcut, pause resume, and no R restart.")
	quit(1 if _failed else 0)


func _assert_legend_contains(legend: ContextLegend, expected_values: Array[String]) -> void:
	var text_values: Array[String] = []
	for label in legend.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			text_values.append((label as Label).text)
	var joined := " ".join(text_values)
	for expected in expected_values:
		_assert_true(expected in joined, "context legend must expose '%s'" % expected)


func _assert_inside_viewport(control: Control, label: String) -> void:
	var viewport_size := root.get_viewport().get_visible_rect().size
	var rect := control.get_global_rect()
	_assert_true(
		rect.position.x >= 0.0 and rect.position.y >= 0.0 \
				and rect.end.x <= viewport_size.x and rect.end.y <= viewport_size.y,
		"%s must remain inside the supported viewport" % label
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Shortcut prompt check failed: %s" % message)
