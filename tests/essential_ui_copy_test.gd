extends SceneTree

const MAIN_MENU_SCENE := preload("res://scenes/ui/screens/main_menu.tscn")
const STAGE_SELECT_SCENE := preload("res://scenes/ui/screens/stage_select.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/screens/settings.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud/hud.tscn")
const ACTION_BUTTONS_SCENE := preload("res://scenes/ui/hud/action_buttons.tscn")
const RUN_STATUS_SCENE := preload("res://scenes/ui/hud/run_status_card.tscn")
const CAMERA_INTERACTION_SCENE := preload("res://scenes/ui/hud/camera_interaction_control.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	root.size = Vector2i(1280, 720)
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	var main_menu := MAIN_MENU_SCENE.instantiate()
	var stage_select := STAGE_SELECT_SCENE.instantiate()
	var settings := SETTINGS_SCENE.instantiate()
	var hud := HUD_SCENE.instantiate()
	root.add_child(main_menu)
	root.add_child(stage_select)
	root.add_child(settings)
	root.add_child(hud)
	await process_frame

	_assert_absent(main_menu, [
		"Root/BrandPanel/Margin/Content/Eyebrow",
		"Root/BrandPanel/Margin/Content/Subtitle",
	])
	_assert_present(main_menu, [
		"Root/BrandPanel/Margin/Content/Title",
		"Root/BrandPanel/Margin/Content/Play",
		"Root/BrandPanel/Margin/Content/StageSelect",
		"Root/BrandPanel/Margin/Content/Settings",
		"Root/BrandPanel/Margin/Content/Quit",
	])

	_assert_absent(stage_select, ["Root/Divider", "Root/PreviewPanel/Margin/Content/PreviewObjective"])
	_assert_present(stage_select, [
		"Root/Heading",
		"Root/CardsPanel/Margin/Content/Cards",
		"Root/PreviewPanel/Margin/Content/PreviewTitle",
		"Root/PreviewPanel/Margin/Content/PreviewStats",
		"Root/PreviewPanel/Margin/Content/PreviewBest",
		"Root/PreviewPanel/Margin/Content/Start",
	])

	_assert_absent(settings, [
		"SettingsRoot/Panel/Margin/Content/Header/Autosave",
		"SettingsRoot/Panel/Margin/Content/Columns/ColumnDivider",
		"SettingsRoot/Panel/Margin/Content/Columns/Display/LanguageNote",
	])
	_assert_present(settings, [
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/MasterGroup/Header/Icon",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/MasterGroup/Header/MasterValue",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/MasterGroup/Master",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/MusicGroup/Header/MusicValue",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/SfxGroup/Header/SfxValue",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/CameraRow/Icon",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/CameraRow/CameraShake",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/MotionRow/Icon",
		"SettingsRoot/Panel/Margin/Content/Columns/Audio/TrajectoryRow/Icon",
		"SettingsRoot/Panel/Margin/Content/Columns/Display/FullscreenRow/Icon",
		"SettingsRoot/Panel/Margin/Content/Columns/Display/Resolution",
		"SettingsRoot/Panel/Margin/Content/Columns/Display/Language",
		"SettingsRoot/Panel/Margin/Content/Footer/Defaults",
		"SettingsRoot/Panel/Margin/Content/Footer/Close",
	])

	var hud_root := hud.get_node("HUDRoot")
	_assert_absent(hud_root, [
		"BriefingPanel",
		"ContextLegend/Divider",
		"ResultPanel/Margin/Content/CoverageLabel",
		"ResultPanel/Margin/Content/CoverageExplanation",
	])
	_assert_present(hud_root, [
		"BriefingActions/Back",
		"BriefingActions/Start",
		"ResultPanel/Margin/Content/Target",
		"ResultPanel/Margin/Content/Retry",
		"ResultPanel/Margin/Content/Next",
		"ResultPanel/Margin/Content/Stages",
	])
	_assert_true(
		hud_root.find_children("*", "ShortcutHint", true, false).is_empty(),
		"normal UI must not retain outlined ShortcutHint keycaps"
	)

	await _assert_semantic_control_copy("ko")
	await _assert_semantic_control_copy("en")
	TranslationServer.set_locale(previous_locale)

	for node in [main_menu, stage_select, settings, hud]:
		node.queue_free()
	await process_frame
	if not _failed:
		print("Essential UI copy passed: normal screens contain only essential copy and one shortcut owner.")
	quit(1 if _failed else 0)


func _assert_semantic_control_copy(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var actions := ACTION_BUTTONS_SCENE.instantiate() as ActionButtons
	var status := RUN_STATUS_SCENE.instantiate() as RunStatusCard
	var interaction := CAMERA_INTERACTION_SCENE.instantiate() as CameraInteractionControl
	root.add_child(actions)
	root.add_child(status)
	root.add_child(interaction)
	await process_frame
	actions.set_fire_readiness({"fireable": true, "reason": tr("ui.fire")})
	actions.refresh_locale()
	status.refresh_locale()
	interaction.set_interaction_mode(CameraDirector.InteractionMode.AIM_LOCKED)
	_assert_true("Space" not in actions.get_node("FireButton").text, "%s Fire must not repeat Space" % locale)
	_assert_true(" F" not in status.get_node("Finish").text, "%s Finish must not repeat F" % locale)
	_assert_true("Tab" not in interaction.text, "%s mode control must not repeat Tab" % locale)
	_assert_true(not actions.get_node("FireButton").tooltip_text.is_empty(), "%s Fire must retain a tooltip" % locale)
	_assert_true(not status.get_node("Finish").tooltip_text.is_empty(), "%s Finish must retain a tooltip" % locale)
	_assert_true(not interaction.tooltip_text.is_empty(), "%s mode control must retain a tooltip" % locale)
	for node in [actions, status, interaction]:
		node.queue_free()
	await process_frame


func _assert_absent(parent: Node, paths: Array[String]) -> void:
	for path in paths:
		_assert_true(parent.get_node_or_null(path) == null, "%s must be absent" % path)


func _assert_present(parent: Node, paths: Array[String]) -> void:
	for path in paths:
		_assert_true(parent.get_node_or_null(path) != null, "%s must remain present" % path)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
