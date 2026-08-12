extends SceneTree

var _failed := false


func _initialize() -> void:
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	for stage_id in [&"stage_01", &"stage_30"]:
		var stage := catalog.get_stage(stage_id)
		var baked := load(catalog.get_layout_path(stage_id)) as BakedStageLayoutData
		var layout := StageLayoutBakeCodec.hydrate(baked, stage)
		_assert(layout != null, "%s layout must hydrate" % stage_id)
		if layout == null:
			continue
		var front_local_z := -INF
		for point in layout.top_topology.canonical_vertices_read_only():
			front_local_z = maxf(front_local_z, point.z)
		var playable_front_world_z := stage.terrain_center.z + front_local_z
		var standoff := stage.cannon_transform.origin.z - playable_front_world_z
		_assert(standoff >= StageGenerationContract.FIXED_CANNON_STANDOFF,
				"%s cannon must be at least %.0f m from playable terrain; got %.3f" % [
					stage_id, StageGenerationContract.FIXED_CANNON_STANDOFF, standoff,
				])
		_assert(stage.cannon_transform.origin.is_finite(), "%s cannon transform must be persisted" % stage_id)
	if not _failed:
		print("stage_cannon_standoff_test passed: Stage 01/30 fixed cannon meets the shared standoff")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
