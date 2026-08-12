extends SceneTree

const GAMEPLAY_PACE := preload("res://src/gameplay/gameplay_pace.gd")

var _failed := false


func _initialize() -> void:
	var original_scale := Engine.time_scale
	_assert_true(
		int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0))
				== GAMEPLAY_PACE.PHYSICS_TICKS_PER_WALL_SECOND,
		"project physics must remain fixed at 60 Hz"
	)
	GAMEPLAY_PACE.apply_active()
	_assert_true(is_equal_approx(Engine.time_scale, 2.0), "active board play must use time scale 2.0")
	_assert_true(
		is_equal_approx(TrajectoryPredictionJob.PHYSICS_STEP, 1.0 / 30.0),
		"prediction must use the scaled 60 Hz live simulation step"
	)
	_assert_true(
		is_equal_approx(
			TrajectoryPredictionJob.MAXIMUM_STEPS * TrajectoryPredictionJob.PHYSICS_STEP,
			GAMEPLAY_PACE.PREDICTION_HORIZON_SIMULATION_SECONDS
		),
		"scaled prediction must retain its 12-second simulation horizon"
	)
	_assert_true(
		CameraDirector.FOLLOW_IMPACT_HOLD_TICKS == 24 \
				and is_equal_approx(
					float(CameraDirector.FOLLOW_IMPACT_HOLD_TICKS)
							/ float(GAMEPLAY_PACE.PHYSICS_TICKS_PER_WALL_SECOND),
					0.4
				),
		"first-impact presentation must hold for 0.4 wall seconds"
	)
	_assert_true(
		StageProgressionData.duration_seconds_for(1) == 60 \
				and StageProgressionData.duration_seconds_for(11) == 90 \
				and StageProgressionData.duration_seconds_for(21) == 120,
		"difficulty tiers must use 60/90/120 wall-clock seconds"
	)
	GAMEPLAY_PACE.apply_normal()
	_assert_true(is_equal_approx(Engine.time_scale, 1.0), "non-active surfaces must restore normal time")
	Engine.time_scale = original_scale
	if not _failed:
		print("Gameplay pace passed: 2x active simulation, 60 Hz wall clock, and 60/90/120 tiers.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Gameplay pace check failed: %s" % message)
