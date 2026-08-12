extends SceneTree

const APP_SCENE := preload("res://scenes/app/app.tscn")
const TIMEOUT_MSEC := 60_000

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var game_state := root.get_node("/root/GameState") as GameState
	game_state.persistence_enabled = false
	var data: Dictionary = root.get_node("/root/SaveSystem").default_data()
	data.unlocked_stages = StageCatalog.all_stages().map(
		func(stage: StageData) -> String: return String(stage.stage_id)
	)
	data.selected_stage_id = "stage_01"
	game_state.initialize_from_data(data)

	var app := APP_SCENE.instantiate() as AppRoot
	root.add_child(app)
	await process_frame
	await process_frame
	app._show_stage_select()
	await process_frame

	var stage_select := app.get_node("StageSelect") as StageSelectScreen
	var requested_stage := StageCatalog.get_stage(&"stage_02")
	stage_select._cards[1].pressed.emit()
	_assert_true(
		stage_select.selected_stage_id() == requested_stage.stage_id,
		"the real Stage Select card must own the new local selection"
	)
	_assert_true(
		game_state.selected_stage_id == &"stage_01",
		"selecting a card must not commit GameState before Start"
	)

	var ready_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - ready_started < TIMEOUT_MSEC:
		if app._prepared_gameplay_matches(requested_stage) \
				and not stage_select._start_button.disabled:
			break
		await process_frame
	var ready_elapsed := Time.get_ticks_msec() - ready_started
	_assert_true(
		app._prepared_gameplay_matches(requested_stage),
		"the latest uncommitted Stage Select choice must prepare matching hidden Gameplay"
	)
	_assert_true(
		not stage_select._start_button.disabled,
		"Start must become enabled when the locally selected stage is prepared"
	)
	_assert_true(
		game_state.selected_stage_id == &"stage_01",
		"background readiness must still leave GameState unchanged before Start"
	)

	if not stage_select._start_button.disabled:
		stage_select._start_button.pressed.emit()
	var gameplay := await _wait_for_active_stage(app, requested_stage.stage_id)
	_assert_true(gameplay != null, "Start must enter the stage chosen on the card")
	_assert_true(
		game_state.selected_stage_id == requested_stage.stage_id,
		"entering the prepared stage must commit the selected stage"
	)
	if not _failed:
		print(
			"Stage selection readiness passed: local selection prepared in %d ms and entered immediately."
			% ready_elapsed
		)

	game_state.persistence_enabled = true
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if _failed else 0)


func _wait_for_active_stage(app: AppRoot, stage_id: StringName) -> Node3D:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var gameplay := app.get_node_or_null("ActiveGameplay") as Node3D
		var active_stage := gameplay.get("stage_data") as StageData \
				if gameplay != null and not gameplay.is_queued_for_deletion() else null
		if active_stage != null and active_stage.stage_id == stage_id:
			return gameplay
		await process_frame
	return null


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
