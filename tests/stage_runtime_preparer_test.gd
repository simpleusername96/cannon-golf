extends SceneTree

const LAYOUT_TIMEOUT_MS := 45000
const ARTIFACT_TIMEOUT_MS := 60000

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var repository := StageLayoutRepository.new()
	var preparer := StageRuntimePreparer.new()
	root.add_child(repository)
	root.add_child(preparer)
	var stages := StageCatalog.all_stages()
	_assert_true(stages.size() >= 4, "runtime preparation requires four catalog stages")
	var layouts: Array[GeneratedStageLayout] = []
	for index in range(4):
		layouts.append(await _load_layout(repository, stages[index]))
		_assert_true(layouts[index] != null, "stage %d baked layout must hydrate" % (index + 1))
	if _failed:
		await _finish([repository, preparer])
		return
	var runtime_copy := layouts[0].copy_for_runtime()
	_assert_true(
		runtime_copy != null and runtime_copy != layouts[0] and runtime_copy.is_runtime_ready(),
		"accepted layout copy must retain readiness while isolating the runtime wrapper"
	)
	if runtime_copy != null:
		_assert_true(
			runtime_copy.target_mask_checksum == layouts[0].target_mask_checksum \
					and runtime_copy.target_pixel_count() == layouts[0].target_pixel_count() \
					and runtime_copy.target_centroid_local_xz() \
							== layouts[0].target_centroid_local_xz(),
			"fast runtime copy must retain the verified target-mask caches"
		)

	var ready_ids: Array[StringName] = []
	var failed_ids: Array[StringName] = []
	var progress_frames: Dictionary = {}
	preparer.artifact_ready.connect(func(stage_id: StringName, _artifact: StageRuntimeArtifact) -> void:
		ready_ids.append(stage_id)
	)
	preparer.artifact_failed.connect(func(stage_id: StringName) -> void:
		failed_ids.append(stage_id)
	)
	preparer.artifact_progress.connect(func(stage_id: StringName, _phase: StringName, _progress: float) -> void:
		var frames: Dictionary = progress_frames.get(stage_id, {})
		frames[Engine.get_process_frames()] = true
		progress_frames[stage_id] = frames
	)

	preparer.request_artifact(stages[0], layouts[1], true)
	_assert_true(failed_ids.has(stages[0].stage_id), "mismatched stage/layout identity must fail closed")
	failed_ids.clear()

	# Replacing a selected request before its first process step must prevent the
	# obsolete identity from publishing any completion.
	preparer.request_artifact(stages[0], layouts[0], true)
	preparer.request_artifact(stages[1], layouts[1], true)
	var second := await _wait_for_artifact(preparer, stages[1])
	_assert_true(second != null, "latest selected stage must complete preparation")
	_assert_true(preparer.ready_artifact(stages[0]) == null, "cancelled selected stage must not enter the cache")
	_assert_true(not ready_ids.has(stages[0].stage_id), "cancelled selected stage must not emit ready")
	_assert_true(
		(progress_frames.get(stages[1].stage_id, {}) as Dictionary).size() >= 8,
		"cooperative preparation must yield across multiple rendered frames"
	)
	_assert_artifact(second, stages[1])
	_assert_true(
		preparer.geometry_job_start_count(stages[1].stage_id) == 1,
		"one stage identity must start exactly one canonical geometry job"
	)
	preparer.request_artifact(stages[2], layouts[2], false)
	_assert_true(preparer.is_preparing(stages[2].stage_id), "prefetch cancellation proof requires an active job")
	preparer.cancel_except(stages[1].stage_id)
	_assert_true(
		not preparer.is_preparing(stages[2].stage_id),
		"entering Gameplay must cancel obsolete selected and prefetch artifact jobs"
	)

	for index in [0, 2, 3]:
		preparer.request_artifact(stages[index], layouts[index], true)
		var artifact := await _wait_for_artifact(preparer, stages[index])
		_assert_true(artifact != null, "stage %d runtime artifact must complete" % (index + 1))
	_assert_true(
		preparer.cached_artifact_count() == StageRuntimePreparer.MAX_CACHED_ARTIFACTS,
		"runtime artifact LRU must stay bounded to three entries"
	)
	_assert_true(
		preparer.ready_artifact(stages[1]) == null,
		"least-recently-used runtime artifact must be evicted after a fourth identity"
	)

	var comparison_preparer := StageRuntimePreparer.new()
	root.add_child(comparison_preparer)
	comparison_preparer.request_artifact(stages[0], layouts[0], true)
	var original := preparer.ready_artifact(stages[0])
	var comparison := await _wait_for_artifact(comparison_preparer, stages[0])
	_assert_true(original != null and comparison != null, "determinism comparison artifacts must exist")
	if original != null and comparison != null:
		_assert_true(
			original.layout_checksum == comparison.layout_checksum \
					and original.geometry.top_vertex_count == comparison.geometry.top_vertex_count \
					and original.geometry.total_triangle_count() == comparison.geometry.total_triangle_count() \
					and original.paint_bootstrap.topology_cell_triangle_normals \
							== comparison.paint_bootstrap.topology_cell_triangle_normals \
					and TargetMaskRasterizer.byte_checksum(
						original.preview_paint_texture.get_image().get_data()
					) == TargetMaskRasterizer.byte_checksum(
						comparison.preview_paint_texture.get_image().get_data()
					),
			"same identity must produce deterministic geometry and paint artifacts"
		)

	if not _failed:
		print("Stage runtime preparer passed: identity, cancellation, yielding, determinism, and 3-entry LRU.")
	await _finish([repository, preparer, comparison_preparer])


func _load_layout(repository: StageLayoutRepository, stage: StageData) -> GeneratedStageLayout:
	repository.request_layout(stage, StageCatalog.get_layout_path(stage.stage_id), true)
	var deadline := Time.get_ticks_msec() + LAYOUT_TIMEOUT_MS
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
	var deadline := Time.get_ticks_msec() + ARTIFACT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		var artifact := preparer.ready_artifact(stage)
		if artifact != null:
			return artifact
		await process_frame
	return null


func _assert_artifact(artifact: StageRuntimeArtifact, stage: StageData) -> void:
	_assert_true(artifact != null and artifact.matches_stage(stage), "artifact must retain full stage identity")
	if artifact == null:
		return
	_assert_true(
		artifact.geometry.top_topology == artifact.runtime_layout.top_topology,
		"artifact geometry must retain the accepted canonical topology"
	)
	_assert_true(
		artifact.paint_bootstrap.target_mask_checksum == artifact.runtime_layout.target_mask_checksum,
		"prepared target data must retain the baked mask checksum"
	)
	_assert_true(
		artifact.decoration_placements.size() == artifact.runtime_layout.decoration_placements.size(),
		"artifact must carry validated dressing placement inputs"
	)


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
