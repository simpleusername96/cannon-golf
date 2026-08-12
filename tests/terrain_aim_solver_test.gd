extends SceneTree

const CANNON_SCENE := preload("res://scenes/gameplay/cannon.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cannon := CANNON_SCENE.instantiate() as CannonController
	root.add_child(cannon)
	await process_frame
	var identity := TrajectoryHitIdentity.terrain_top(
		TrajectoryHitIdentity.TERRAIN_TOP_SHAPE_ID,
		0,
		Vector2i(4, 2),
		1,
		Vector3(0.2, 0.3, 0.5)
	)
	var target := TerrainAimTarget.new(
		Vector3(75.0, 0.0, -110.0),
		Vector3.UP,
		identity
	)
	var baseline := AimTuple.new(0.0, 38.0, 68.0)
	var started_at := Time.get_ticks_usec()
	var free := TerrainAimSolver.nominate(
		cannon, target, &"target", 0.0, &"low", baseline
	)
	var elapsed_usec := Time.get_ticks_usec() - started_at
	var repeated := TerrainAimSolver.nominate(
		cannon, target, &"target", 0.0, &"low", baseline
	)
	var high_branch := TerrainAimSolver.nominate(
		cannon,
		target,
		&"target",
		0.0,
		&"high",
		AimTuple.new(0.0, 58.0, 68.0),
	)
	var pinned_elevation := TerrainAimSolver.nominate(
		cannon, target, &"elevation", 38.0, &"low", baseline
	)
	var pinned_power := TerrainAimSolver.nominate(
		cannon, target, &"power", 68.0, &"high", baseline
	)
	_assert_true(
		not free.is_empty() and free.size() <= TerrainAimSolver.MAXIMUM_NOMINATIONS,
		"free target solve must nominate a bounded candidate set"
	)
	_assert_true(
		_candidate_keys(free) == _candidate_keys(repeated),
		"the same gravity context must nominate deterministically"
	)
	_assert_true(
		elapsed_usec < 16667,
		"one stride-%d approximate solve must finish inside a 60 Hz frame (%d usec)" % [
			TerrainAimSolver.NOMINATION_STEP_STRIDE,
			elapsed_usec,
		]
	)
	_assert_true(
		free.all(func(candidate: Dictionary) -> bool:
			return (candidate.aim as AimTuple).elevation_degrees \
					< TerrainAimSolver.BRANCH_SPLIT_ELEVATION_DEGREES),
		"low-branch nomination must stay on the low branch"
	)
	_assert_true(
		not high_branch.is_empty() \
				and high_branch.all(func(candidate: Dictionary) -> bool:
					return (candidate.aim as AimTuple).elevation_degrees \
							>= TerrainAimSolver.BRANCH_SPLIT_ELEVATION_DEGREES),
		"high-branch nomination must stay on the high branch"
	)
	_assert_true(
		not pinned_elevation.is_empty() \
				and (pinned_elevation[0].aim as AimTuple).elevation_degrees == 38.0,
		"pinned elevation must preserve the requested value"
	)
	_assert_true(
		not pinned_power.is_empty() \
				and (pinned_power[0].aim as AimTuple).power_percent == 68.0,
		"pinned power must preserve the requested value"
	)
	_assert_true(
		(free[0].aim as AimTuple).yaw_degrees > 0.0,
		"positive-X targets must nominate positive player yaw"
	)
	cannon.queue_free()
	await process_frame
	if not _failed:
		print("Terrain aim solver passed: deterministic bounded inversion completed in %d usec." % elapsed_usec)
	quit(1 if _failed else 0)


func _candidate_keys(candidates: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for candidate in candidates:
		result.append((candidate.aim as AimTuple).stable_key())
	return result


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Terrain aim solver check failed: %s" % message)
