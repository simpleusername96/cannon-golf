extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.persistence_enabled = false
	game_state.select_stage(&"stage_01")
	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_01")
	_assert_true(gameplay != null, "shot feedback requires the baked Stage 01 layout")
	if gameplay == null:
		quit(1)
		return
	root.add_child(gameplay)
	await physics_frame
	await process_frame
	var controller: StageController = gameplay.get_node("StageController")
	var hud: HUDController = gameplay.get_node("HUD")
	var hud_root: Control = gameplay.get_node("HUD/HUDRoot")
	_assert_true(controller.begin_aiming(), "feedback fixture must enter aiming")
	await process_frame
	_assert_true(
		hud_root.get_node_or_null("FirstSessionHint") == null,
		"obsolete four-second help must be removed after persistent prompts exist"
	)
	var fire := hud_root.get_node("ActionButtons/FireButton") as Button
	var aim_controls := hud_root.get_node("AimControls") as Control
	var coverage_panel := hud_root.get_node("CoverageMeter") as Control
	_assert_true(
		not fire.get_global_rect().intersects(aim_controls.get_global_rect()) \
				and not fire.get_global_rect().intersects(coverage_panel.get_global_rect()) \
				and hud_root.get_node_or_null("ContextLine") == null,
		"sparse aim instruments must not overlap Fire or coverage"
	)
	var power_decrease := hud_root.get_node("AimControls/Content/PowerDecrease") as Button
	var power_increase := hud_root.get_node("AimControls/Content/PowerIncrease") as Button
	_assert_true(power_decrease.tooltip_text == "파워 2% 낮추기" and power_increase.tooltip_text == "파워 2% 높이기", "power controls must expose localized tooltips")
	_assert_true(power_decrease.get_theme_color("icon_normal_color").is_equal_approx(Color("172538")), "power glyphs must use the navy icon tint")
	hud.update_aim(-7.5, 41.0, 72.0)
	_assert_true(
		hud_root.get_node_or_null("AimControls/Content/DirectionValue") == null \
				and "41.0°" in hud_root.get_node("AimControls/Content/ElevationValue").text,
		"aim instruments must omit yaw and expose target-preserving elevation"
	)
	var interaction_control := hud_root.get_node("CameraInteractionControl") as CameraInteractionControl
	_assert_true(
		interaction_control != null and interaction_control.visible \
				and interaction_control.custom_minimum_size.y >= 40.0,
		"Aiming must expose one focusable interaction-mode control"
	)
	_assert_true(
		hud_root.get_node_or_null("ObservationControls") == null \
				and not interaction_control.text.contains("추적") \
				and not interaction_control.text.contains("대포"),
		"normal gameplay must not expose camera presets, speed, or Pause strips"
	)
	hud.set_interaction_mode(CameraDirector.InteractionMode.MAP_INSPECTION)
	_assert_true(
		interaction_control.visible and interaction_control.text.begins_with("지도 보기") \
				and not hud_root.get_node("AimControls").visible \
				and not hud_root.get_node("ActionButtons").visible,
		"Map Inspection must use its direct label and hide aim-only actions"
	)
	hud.set_interaction_mode(CameraDirector.InteractionMode.AIM_LOCKED)
	_assert_true(
		interaction_control.text.begins_with("조준") \
				and hud_root.get_node("AimControls").visible \
				and hud_root.get_node("ActionButtons").visible,
		"Aim Lock must restore aim and Fire controls"
	)
	var coverage: CoverageMeter = hud_root.get_node("CoverageMeter")
	hud.update_coverage(2.0)
	await process_frame
	_assert_true(
		is_equal_approx(coverage.progress.max_value, 100.0)
		and is_equal_approx(coverage.progress.value, 2.0)
		and coverage.target_label.text == "%s %.0f%%" % [
			tr("hud.target"), gameplay.stage_data.target_coverage,
		]
		and coverage.target_label.get_global_rect().get_center().y \
				> coverage.target_line.get_global_rect().get_center().y
		and coverage.target_label.get_global_rect().get_center().y \
				- coverage.target_line.get_global_rect().get_center().y <= 28.0,
		"coverage must place the numeric goal just below its authoritative rail marker (label=%s line=%s)" % [
			coverage.target_label.get_global_rect(),
			coverage.target_line.get_global_rect(),
		]
	)
	var observation := ShotObservation.new()
	observation.configure(1, -7.5, 41.0, 72.0, 12.0)
	observation.record_mechanism_activation(
		0,
		&"Splitter",
		MechanismData.Kind.SPLITTER,
		Engine.get_physics_frames()
	)
	for ordinal in range(1, 4):
		observation.record_child_spawn(ordinal, 1, Engine.get_physics_frames(), 3)
	observation.seal(20.4, -1, 0x12345678)
	_assert_true(
		hud_root.get_node_or_null("ShotSummary") == null \
				and hud_root.get_node_or_null("MechanismInfoCard") == null,
		"passive shot and mechanism message UI must be absent without replacement nodes"
	)
	_assert_true(
		observation.is_sealed \
				and observation.mechanism_activations.size() == 1 \
				and observation.spawned_child_count == 3 \
				and is_equal_approx(observation.coverage_gain, 8.4),
		"removing message consumers must preserve sealed shot and mechanism facts"
	)
	var shader_source := FileAccess.get_file_as_string("res://src/paint/terrain_paint.gdshader")
	_assert_true(not shader_source.contains("EMISSION"), "terrain shader must not write emission")
	_assert_true(shader_source.contains("mix(0.88, 0.24, painted)"), "terrain shader must bind 0.88 dry and 0.24 painted roughness")
	gameplay.queue_free()
	await process_frame
	game_state.persistence_enabled = true
	if not _failed:
		print("Shot feedback passed: sparse controls, target truth, quiet HUD, and retained observation facts.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true
