extends SceneTree

const STAGE_LAYOUT_REPOSITORY_SCRIPT := preload("res://src/app/stage_layout_repository.gd")
const LAYOUT_TIMEOUT_MS := 45000

var _failed := false
var _failed_stage_ids: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var repository := STAGE_LAYOUT_REPOSITORY_SCRIPT.new()
	repository.name = "StageLayoutRepositoryUnderTest"
	root.add_child(repository)
	repository.layout_failed.connect(func(stage_id: StringName) -> void:
		_failed_stage_ids.append(stage_id)
	)
	var stages := StageCatalog.all_stages()
	_assert_true(stages.size() >= 5, "the baked catalog must expose five test stages")
	if _failed:
		await _finish(repository)
		return

	# Same-frame changes retain only the latest desire for each role. A selected
	# request starts beside a prefetch, then advances after the prior selection.
	var first_stage := stages[0]
	var second_stage := stages[1]
	var third_stage := stages[2]
	var fourth_stage := stages[3]
	_assert_true(not StageCatalog.get_layout_path(first_stage.stage_id).is_empty(), "stage 01 requires a baked layout path")
	_assert_true(not StageCatalog.get_layout_path(second_stage.stage_id).is_empty(), "stage 02 requires a baked layout path")
	if _failed:
		await _finish(repository)
		return
	repository.request_layout(first_stage, StageCatalog.get_layout_path(first_stage.stage_id), false)
	repository.request_layout(second_stage, StageCatalog.get_layout_path(second_stage.stage_id), true)
	repository.request_layout(third_stage, StageCatalog.get_layout_path(third_stage.stage_id), true)
	repository.request_layout(fourth_stage, StageCatalog.get_layout_path(fourth_stage.stage_id), true)
	_assert_true(repository.active_request_count() <= 2, "same-frame requests must retain at most one selected and one prefetch handle")
	_assert_true(repository.is_preparing(first_stage.stage_id), "prefetch must remain independently pending")
	_assert_true(repository.is_preparing(fourth_stage.stage_id), "latest selected desire must remain queued behind the active selection")
	_assert_true(await _wait_for_layout(repository, fourth_stage) != null, "latest queued selected baked layout must eventually hydrate")
	_assert_true(repository.active_request_count() <= 2, "completed race handling must preserve the two-handle bound")

	for index in range(4):
		var stage := stages[index]
		var path := StageCatalog.get_layout_path(stage.stage_id)
		_assert_true(not path.is_empty(), "catalog stage %s requires a baked layout path" % stage.stage_id)
		if path.is_empty():
			continue
		repository.request_layout(stage, path, true)
		var layout := await _wait_for_layout(repository, stage)
		_assert_true(layout != null and layout.matches_stage_identity(stage) and layout.is_runtime_ready(), "hydrated layout %s must be runtime-ready" % stage.stage_id)

	_assert_true(_failed_stage_ids.is_empty(), "valid baked artifacts must not emit repository failures")
	_assert_true(repository.cached_layout_count() == STAGE_LAYOUT_REPOSITORY_SCRIPT.MAX_CACHED_LAYOUTS, "hydrated immutable source cache must stay bounded to three entries")
	_assert_true(repository.ready_layout(first_stage) == null, "the least-recently-used source layout must be evicted after four stages")
	for index in range(1, 4):
		_assert_true(repository.ready_layout(stages[index]) != null, "the three newest hydrated source layouts must remain cached")

	# A baked artifact cannot be accepted for another stage identity. Retrying with
	# the catalog's canonical path is explicit and must hydrate that same stage.
	var retry_stage := stages[4]
	var retry_path := StageCatalog.get_layout_path(retry_stage.stage_id)
	repository.request_layout(retry_stage, StageCatalog.get_layout_path(first_stage.stage_id), true)
	_assert_true(await _wait_for_failure(retry_stage.stage_id), "a mismatched stage/path pair must fail closed")
	repository.request_layout(retry_stage, retry_path, true)
	_assert_true(await _wait_for_layout(repository, retry_stage) != null, "canonical-path retry must hydrate the requested stage")
	if not _failed:
		print("Stage layout repository passed: independent requests, validated hydration, failure, and 3-entry LRU.")
	await _finish(repository)


func _wait_for_layout(repository: Node, stage: StageData) -> GeneratedStageLayout:
	var deadline := Time.get_ticks_msec() + LAYOUT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		var layout: GeneratedStageLayout = repository.ready_layout(stage)
		if layout != null:
			return layout
		await process_frame
	return null


func _wait_for_failure(stage_id: StringName) -> bool:
	var deadline := Time.get_ticks_msec() + LAYOUT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if _failed_stage_ids.has(stage_id):
			return true
		await process_frame
	return false


func _finish(repository: Node) -> void:
	repository.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
