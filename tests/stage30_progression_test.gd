extends SceneTree

var _failed := false


func _initialize() -> void:
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	_assert(catalog != null and catalog.is_valid(), "current v10 catalog must be valid")
	if catalog == null:
		quit(1)
		return
	_assert(StageProgressionData.terrain_size_for(1) == Vector2(210, 120), "Stage 01 terrain must start at 210x120 m")
	_assert(StageProgressionData.terrain_size_for(30) == Vector2(280, 160), "Stage 30 terrain must end at 280x160 m")
	_assert(StageProgressionData.cell_count_for(1) == Vector2i(84, 48), "Stage 01 cell grid endpoint must match")
	_assert(StageProgressionData.cell_count_for(30) == Vector2i(96, 64), "Stage 30 cell grid endpoint must match")
	_assert(StageProgressionData.nominal_peak_for(1) == 64.0, "Stage 01 peak must be 64 m")
	_assert(StageProgressionData.nominal_peak_for(30) == 92.0, "Stage 30 peak must be 92 m")
	_assert(StageProgressionData.target_for(1) == 4.0 and StageProgressionData.target_for(30) == 10.0, "coverage endpoints must match the attainable scale baseline")
	_assert(
		StageProgressionData.target_for(10) == 8.5 \
				and StageProgressionData.target_for(11) == 8.5 \
				and StageProgressionData.target_for(15) == 8.5 \
				and StageProgressionData.target_for(16) == 9.0 \
				and StageProgressionData.target_for(20) == 9.0 \
				and StageProgressionData.target_for(21) == 9.5 \
				and StageProgressionData.target_for(25) == 9.5 \
				and StageProgressionData.target_for(26) == 10.0,
		"late clear targets must follow the shot-tier plateaus"
	)
	_assert(StageProgressionData.shots_for(1) == 4 and StageProgressionData.shots_for(30) == 7, "shot endpoints must remain locked")
	_assert(
		StageProgressionData.duration_seconds_for(1) == 60 \
				and StageProgressionData.duration_seconds_for(10) == 60 \
				and StageProgressionData.duration_seconds_for(11) == 90 \
				and StageProgressionData.duration_seconds_for(20) == 90 \
				and StageProgressionData.duration_seconds_for(21) == 120 \
				and StageProgressionData.duration_seconds_for(30) == 120,
		"duration tiers must remain 60/90/120 wall-clock seconds"
	)
	var previous_difficulty := -INF
	var profile_ids: Dictionary = {}
	for index in range(catalog.stages.size()):
		var stage := catalog.stages[index]
		var number := index + 1
		_assert(stage.stage_id == StringName("stage_%02d" % number), "stage IDs must be ordered")
		_assert(stage.stage_number == number and stage.stage_version == 10, "stage version and number must match v10")
		_assert(stage.terrain_seed == StageProgressionData.CANONICAL_TERRAIN_SEED, "%s must use the shared seed" % stage.stage_id)
		_assert(stage.terrain_size == StageProgressionData.terrain_size_for(number), "%s size must consume progression" % stage.stage_id)
		_assert(stage.generation_profile.nominal_peak == StageProgressionData.nominal_peak_for(number), "%s peak must consume progression" % stage.stage_id)
		_assert(stage.generation_profile.routes.size() == StageProgressionData.route_count_for(number), "%s route count must consume progression" % stage.stage_id)
		_assert(stage.mechanism_loadout.size() == StageProgressionData.mechanism_count_for(number), "%s mechanism count must consume progression" % stage.stage_id)
		_assert(stage.target_coverage == StageProgressionData.target_for(number), "%s clear target must consume progression" % stage.stage_id)
		_assert(
			stage.star_thresholds == Vector3(
				stage.target_coverage,
				stage.target_coverage + 2.5,
				stage.target_coverage + 5.0
			),
			"%s star thresholds must retain the clear/+2.5/+5.0 policy" % stage.stage_id
		)
		_assert(not profile_ids.has(stage.generation_profile.profile_id), "%s profile ID must be unique" % stage.stage_id)
		profile_ids[stage.generation_profile.profile_id] = true
		var difficulty := StageProgressionData.difficulty_score_for(number)
		_assert(difficulty >= previous_difficulty, "%s difficulty must not reverse" % stage.stage_id)
		previous_difficulty = difficulty
	_assert(catalog.get_stage(&"first_descent").stage_id == &"stage_01", "legacy Stage 01 alias must remain")
	_assert(catalog.get_stage(&"burst_basin").stage_id == &"stage_02", "legacy Stage 02 alias must remain")
	_assert(catalog.get_stage(&"split_ridge").stage_id == &"stage_03", "legacy Stage 03 alias must remain")
	if not _failed:
		print("stage30_progression_test passed: lower/wider v10 endpoints and thirty-stage ladder")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
