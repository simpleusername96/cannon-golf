extends SceneTree

const GAMEPLAY_SCENE := preload("res://scenes/gameplay/gameplay.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("/root/GameState") as GameState
	game_state.persistence_enabled = false
	game_state.initialize_from_data(root.get_node("/root/SaveSystem").default_data())
	game_state.select_stage(&"stage_01")
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	var prepared_stage := catalog.get_stage(&"stage_01")
	var prepared_layout := StageLayoutBakeCodec.hydrate(
		load(catalog.get_layout_path(prepared_stage.stage_id)) as BakedStageLayoutData,
		prepared_stage
	)
	var gameplay := GAMEPLAY_SCENE.instantiate()
	gameplay.prepare_stage(prepared_stage, prepared_layout)
	root.add_child(gameplay)
	await process_frame
	_assert(gameplay.get_node_or_null("OpenPlayEnvironment") is OpenPlayEnvironment, "gameplay must use the open environment")
	_assert(gameplay.get_node_or_null("BackstopEnvironment") == null, "gameplay must not contain a backstop")
	var hud := gameplay.get_node_or_null("HUD") as HUDController
	_assert(hud != null and hud.get_node_or_null("HUDRoot/ReturnToCannon") is Button, "HUD must expose a contextual return-to-cannon action")
	var translations := FileAccess.get_file_as_string("res://translations/ui.csv")
	_assert(translations.contains("hud.return_to_cannon") and translations.contains("Aim View") \
			and translations.contains("지도 보기"), "current camera vocabulary must be localized")
	_assert(not translations.contains("Aim Lock") and not translations.contains("Map Inspection"), "obsolete player-facing camera labels must be absent")
	var controller := gameplay.get_node("StageController") as StageController
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	var aim_input := gameplay.get_node("AimInputController") as AimInputController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var preview := gameplay.get_node("TrajectoryPreview") as TrajectoryPreview
	var hud_root := gameplay.get_node("HUD/HUDRoot") as Control
	_assert(controller.begin_aiming(), "the presentation contract must enter Aim View")
	var readiness_budget := 180
	while not bool(controller.fire_readiness_snapshot().get("fireable", false)) \
			and readiness_budget > 0:
		await physics_frame
		readiness_budget -= 1
	_assert(readiness_budget > 0 and controller.request_fire(), "the fixed default aim must fire")
	await process_frame
	var retained_aim := Vector3(cannon.yaw_degrees, cannon.elevation_degrees, cannon.power_percent)
	_assert(director.current_mode == CameraDirector.Mode.FOLLOW, "accepted Fire must enter Shot Follow")
	_assert(
		hud_root.get_node("ReturnToCannon").visible \
				and not hud_root.get_node("AimControls").visible \
				and not hud_root.get_node("ActionButtons").visible \
				and not hud_root.get_node("CameraInteractionControl").visible \
				and not preview.visible,
		"Shot Follow must show only the contextual return action, not aiming affordances"
	)
	_assert(
		not aim_input.adjust_elevation_button(1.0) \
				and Vector3(cannon.yaw_degrees, cannon.elevation_degrees, cannon.power_percent) \
						.is_equal_approx(retained_aim),
		"hidden Follow input must not alter the stored aim tuple"
	)
	var return_button := hud_root.get_node("ReturnToCannon") as Button
	return_button.pressed.emit()
	await process_frame
	_assert(
		director.current_mode == CameraDirector.Mode.AIMING \
				and not return_button.visible \
				and hud_root.get_node("AimControls").visible \
				and hud_root.get_node("ActionButtons").visible \
				and hud_root.get_node("CameraInteractionControl").visible \
				and preview.visible,
		"returning must restore the same aiming surface and preview"
	)
	readiness_budget = 180
	while not bool(controller.fire_readiness_snapshot().get("fireable", false)) \
			and readiness_budget > 0:
		await physics_frame
		readiness_budget -= 1
	_assert(readiness_budget > 0 and controller.request_fire(), "a second root must start another Follow")
	await process_frame
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	_assert(
		aim_input._handle_key(tab) and director.current_mode == CameraDirector.Mode.AIMING,
		"Tab must use the same camera-only return path"
	)
	_assert(
		Vector3(cannon.yaw_degrees, cannon.elevation_degrees, cannon.power_percent) \
				.is_equal_approx(retained_aim),
		"button and Tab return must preserve the exact stored aim"
	)
	for stage_id in [&"stage_01", &"stage_30"]:
		var stage := catalog.get_stage(stage_id)
		var layout := StageLayoutBakeCodec.hydrate(
			load(catalog.get_layout_path(stage_id)) as BakedStageLayoutData,
			stage
		)
		_assert(layout != null and layout.is_runtime_ready(), "%s must enter from its persisted fixed layout" % stage_id)
	gameplay.queue_free()
	await process_frame
	game_state.persistence_enabled = true
	if not _failed:
		print("phase7_user_qa_contract_test passed: current scene, copy, fixed layouts, and return action")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
