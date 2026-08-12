extends SceneTree

const PROJECTILE_DATA: ProjectileData = preload("res://resources/projectiles/basic_paintball.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain := TerrainSurface.new()
	var manager := ProjectileManager.new()
	root.add_child(manager)
	manager.configure_terrain(terrain)
	var finished_shot_ids := PackedInt64Array()
	manager.shot_family_finished.connect(func(shot_id: int) -> void:
		finished_shot_ids.append(shot_id)
	)

	var first := manager.spawn_projectile(PROJECTILE_DATA, Vector3.ZERO, Vector3.FORWARD)
	var second := manager.spawn_projectile(PROJECTILE_DATA, Vector3.ZERO, Vector3.FORWARD)
	_assert(first != null and second != null, "two root families must be admitted")
	_assert(manager.active_root_count() == 2, "two moving roots must occupy both initial-flight slots")
	_assert(not manager.root_capacity_available(2), "a third root must wait while both families are in initial flight")
	_assert(
		manager.spawn_projectile(PROJECTILE_DATA, Vector3.ZERO, Vector3.FORWARD) == null,
		"the manager must reject a third initial root even when a caller bypasses StageController"
	)
	_assert(manager.active_count() == 2, "a rejected third root must not change resident state")
	_assert(
		manager.spawn_projectile(
			PROJECTILE_DATA,
			Vector3.ZERO,
			Vector3.FORWARD,
			0,
			first.shot_id
		) == null,
		"a caller-provided root ID must not merge two initial launches"
	)

	_mark_playable_top(first)
	_assert(manager.active_count() == 2, "first terrain traversal must keep the projectile resident")
	_assert(manager.active_root_count() == 1, "first terrain traversal must release only that family's Fire slot")
	_assert(finished_shot_ids.has(first.shot_id), "a one-body family must finish at its first playable-top traversal")
	first._set_motion_state(PaintProjectile.MotionState.RESTING_ON_TERRAIN)
	first._set_motion_state(PaintProjectile.MotionState.MOVING_ON_TERRAIN)
	_assert(manager.active_root_count() == 1, "continued resident motion must not reclaim an initial-flight slot")

	var third := manager.spawn_projectile(PROJECTILE_DATA, Vector3.ZERO, Vector3.FORWARD)
	_assert(third != null and manager.active_root_count() == 2, "a released slot must admit another root")

	var split_shot_id := second.shot_id
	second.deactivate(ProjectileSettlementReason.CONSUMED)
	var children: Array[PaintProjectile] = []
	for child_index in range(3):
		var child := manager.spawn_projectile(
			PROJECTILE_DATA,
			Vector3(float(child_index), 0.0, 0.0),
			Vector3.FORWARD,
			1,
			split_shot_id
		)
		_assert(child != null, "all three split children must retain their root family identity")
		if child != null:
			children.append(child)
		_assert(
			not finished_shot_ids.has(split_shot_id),
			"family completion must not occur between parent consumption and child admission"
		)
	await process_frame
	_assert(manager.active_root_count() == 1, "a consumed root must release its launch slot while children move")
	_assert(not finished_shot_ids.has(split_shot_id), "moving split children must keep the family observation unsettled")
	for child_index in range(children.size()):
		_mark_playable_top(children[child_index])
		_assert(
			finished_shot_ids.has(split_shot_id) == (child_index == children.size() - 1),
			"family completion must occur only after all three children traverse playable top"
		)
	_assert(manager.active_root_count() == 1, "family completion must not change an already released launch slot")
	_assert(finished_shot_ids.has(split_shot_id), "family completion must wait for its moving child to traverse terrain")

	third.deactivate(ProjectileSettlementReason.ESCAPED_BOUNDS)
	await process_frame
	_assert(manager.active_root_count() == 0, "a terminal root must permanently release its launch slot")
	_assert(manager.root_capacity_available(2), "a terminal root must make its capacity available")

	_assert(
		ProjectileManager.MAXIMUM_ACTIVE_PROJECTILES == 21 \
				and ProjectileManager.stage_resident_capacity_is_valid(7, [
					preload("res://resources/mechanisms/splitter_node.tres"),
				]) \
				and not ProjectileManager.stage_resident_capacity_is_valid(8, [
					preload("res://resources/mechanisms/splitter_node.tres"),
				]),
		"the current splitter policy must bound seven three-way roots within 21 residents"
	)
	manager.cleanup()
	await process_frame
	manager.queue_free()
	await process_frame
	terrain.free()
	if not _failed:
		print("Projectile family capacity checks passed: first terrain traversal releases Fire slots while residents continue moving.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Projectile family capacity check failed: %s" % message)


func _mark_playable_top(projectile: PaintProjectile) -> void:
	# The projectile emits this only after TerrainSurface validation in live play.
	# The manager's lifecycle boundary needs no contact payload beyond that fact.
	projectile._has_touched_playable_top = true
	projectile.valid_top_traversed.emit(projectile, null, true)
