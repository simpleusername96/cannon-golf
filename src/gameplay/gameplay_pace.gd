class_name GameplayPace
extends RefCounted

## Owns the fixed relationship between wall-clock physics callbacks and active
## simulation time. StageController deliberately owns the separate wall clock.

const NORMAL_TIME_SCALE := 1.0
const ACTIVE_TIME_SCALE := 2.0
const PHYSICS_TICKS_PER_WALL_SECOND := 60
const ACTIVE_SIMULATION_STEP_SECONDS := ACTIVE_TIME_SCALE / float(PHYSICS_TICKS_PER_WALL_SECOND)
const PREDICTION_HORIZON_SIMULATION_SECONDS := 12.0
const PREDICTION_MAXIMUM_STEPS := 360
const FOLLOW_IMPACT_HOLD_TICKS := 24
const DEBUG_SLOW_MOTION_RATIO := 0.35


static func apply_normal() -> void:
	Engine.time_scale = NORMAL_TIME_SCALE


static func apply_active() -> void:
	Engine.time_scale = ACTIVE_TIME_SCALE


static func apply_debug_slow_motion() -> void:
	Engine.time_scale = ACTIVE_TIME_SCALE * DEBUG_SLOW_MOTION_RATIO
