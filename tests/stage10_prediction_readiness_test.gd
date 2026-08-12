extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var game_state := root.get_node("/root/GameState") as GameState
	game_state.persistence_enabled = false
	game_state.select_stage(&"stage_10")
	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_10")
	_assert_true(gameplay != null, "Stage 10 baked fixture must load")
	if gameplay == null:
		quit(1)
		return
	root.add_child(gameplay)
	await physics_frame
	await process_frame
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var scheduler := gameplay.get_node(
		"TrajectoryPredictionScheduler"
	) as TrajectoryPredictionScheduler
	var actions := gameplay.get_node("HUD/HUDRoot/ActionButtons") as ActionButtons
	_assert_true(controller.begin_aiming(), "Stage 10 fixture must enter Aim View")
	await physics_frame
	var initial := controller.fire_readiness_snapshot()
	_assert_true(
		bool(initial.get("fireable", false)) \
				and not initial.has("prediction_status"),
		"legal Stage 10 aim must be fireable without waiting for preview"
	)
	var saw_pending := cannon.prediction_status() == &"pending"
	for _tick in range(80):
		await physics_frame
		var readiness := controller.fire_readiness_snapshot()
		_assert_true(
			bool(readiness.get("fireable", false)) \
					and String(readiness.get("reason_key", "")) == "ready",
			"advisory preview work must not alter Fire admission"
		)
		_assert_true(
			not actions.get_node("FireButton").disabled,
			"Fire button must stay enabled while the advisory preview updates"
		)
		_assert_true(
			scheduler.last_advance_step_count() \
					<= TrajectoryPredictionScheduler.MAXIMUM_STEPS_PER_TICK,
			"Stage 10 preview work must remain bounded"
		)
		saw_pending = saw_pending or cannon.prediction_status() == &"pending"
	_assert_true(saw_pending, "fixture must exercise a pending advisory preview state")
	gameplay.queue_free()
	await process_frame
	game_state.persistence_enabled = true
	if not _failed:
		print("Stage 10 readiness passed: advisory prediction never toggles Fire.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Stage 10 prediction readiness failed: %s" % message)
