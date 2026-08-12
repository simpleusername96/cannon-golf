extends SceneTree

const GAMEPLAY_SCENE := preload("res://scenes/gameplay/gameplay.tscn")
const TIMEOUT_MS := 60000

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var repository := StageLayoutRepository.new()
	var preparer := StageRuntimePreparer.new()
	root.add_child(repository)
	root.add_child(preparer)
	var stage := StageCatalog.all_stages()[0]
	var other_stage := StageCatalog.all_stages()[1]
	var layout := await _load_layout(repository, stage)
	_assert_true(layout != null, "prepared Gameplay test requires a hydrated layout")
	preparer.request_artifact(stage, layout, true)
	var artifact := await _wait_for_artifact(preparer, stage)
	_assert_true(artifact != null, "prepared Gameplay test requires a complete runtime artifact")
	if _failed:
		await _finish([repository, preparer])
		return

	var mismatch := GAMEPLAY_SCENE.instantiate()
	_assert_true(
		not mismatch.prepare_stage(other_stage, artifact),
		"Gameplay must reject an artifact from another full stage identity before tree entry"
	)
	mismatch.queue_free()

	var gameplay := GAMEPLAY_SCENE.instantiate()
	var prepared_ids: Array[StringName] = []
	var failed_ids: Array[StringName] = []
	_assert_true(gameplay.prepare_stage(stage, artifact), "Gameplay must accept the exact prepared artifact")
	gameplay.set_stage_presented(false)
	gameplay.stage_prepared.connect(func(stage_id: StringName) -> void:
		prepared_ids.append(stage_id)
	)
	gameplay.stage_preparation_failed.connect(func(stage_id: StringName) -> void:
		failed_ids.append(stage_id)
	)
	root.add_child(gameplay)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while prepared_ids.is_empty() and failed_ids.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_assert_true(failed_ids.is_empty(), "valid prepared Gameplay must not publish a preparation failure")
	_assert_true(prepared_ids == [stage.stage_id], "Gameplay must publish the exact prepared stage identity")
	_assert_true(gameplay.generated_layout() == artifact.runtime_layout, "Gameplay must bind the artifact runtime layout directly")
	var terrain_mesh := gameplay.get_node("TerrainSurface/TerrainMesh") as MeshInstance3D
	_assert_true(
		terrain_mesh.mesh == artifact.geometry.render_mesh,
		"Gameplay and preview artifact must share one immutable terrain mesh"
	)
	var paint := gameplay.get_node("PaintSystem") as PaintSystem
	_assert_true(
		paint._target_texture == artifact.paint_bootstrap.target_texture,
		"Gameplay must bind the prepared target texture instead of recreating it"
	)
	_assert_true(
		paint.target_bytes_read_only() == artifact.paint_bootstrap.target_bytes,
		"prepared target bytes must remain bit-identical in the live PaintSystem"
	)
	_assert_true(
		paint.nontarget_diagnostic_build_count() == 0,
		"normal prepared Gameplay must not build the 512-square debug-only inverse mask"
	)
	var controller := gameplay.get_node("StageController") as StageController
	_assert_true(not controller.actions_enabled(), "hidden prepared Gameplay must reject stage actions")
	_assert_true(not controller.begin_aiming(), "hidden prepared Gameplay must not advance from Briefing")
	_assert_true(not controller.run_has_started(), "hidden preparation must not start the stage clock")
	_assert_true(
		preparer.geometry_job_start_count(stage.stage_id) == 1,
		"Gameplay binding must not start a second terrain geometry job"
	)
	var dressing := gameplay.get_node("EnvironmentDressing")
	_assert_true(
		dressing.get_child_count() == artifact.decoration_placements.size(),
		"Gameplay dressing must consume the artifact's prepared placements and scenes"
	)

	gameplay.set_stage_presented(true)
	_assert_true(gameplay.visible and controller.actions_enabled(), "visibility handoff must activate the prepared stage immediately")
	_assert_true(
		(gameplay.get_node("HUD") as CanvasLayer).visible,
		"visibility handoff must reveal the already-configured HUD"
	)
	if not _failed:
		print("Prepared Gameplay entry passed: strict identity, resource reuse, hidden gate, and immediate handoff.")
	await _finish([gameplay, repository, preparer])


func _load_layout(repository: StageLayoutRepository, stage: StageData) -> GeneratedStageLayout:
	repository.request_layout(stage, StageCatalog.get_layout_path(stage.stage_id), true)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		var layout := repository.ready_layout(stage)
		if layout != null:
			return layout
		await process_frame
	return null


func _wait_for_artifact(
		preparer: StageRuntimePreparer,
		stage: StageData
) -> StageRuntimeArtifact:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		var artifact := preparer.ready_artifact(stage)
		if artifact != null:
			return artifact
		await process_frame
	return null


func _finish(nodes: Array) -> void:
	for node in nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
