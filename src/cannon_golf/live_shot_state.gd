class_name CannonGolfLiveShotState
extends RefCounted

## Per-ball attempt state. The game coordinates course-wide completion, while
## each live ball independently owns a revocable settlement candidate and its
## dwell timing.

var ball: CannonGolfBall
var settle_elapsed := 0.0
var low_speed_elapsed := 0.0
var settlement_goal_index := -1
var launcher_source_goal_index := -1
var launch_setup := Vector3(50.0, 50.0, 50.0)
var ending := false


func _init(
		live_ball: CannonGolfBall,
		source_goal_index: int = -1,
		setup: Vector3 = Vector3(50.0, 50.0, 50.0)
) -> void:
	assert(live_ball != null)
	ball = live_ball
	launcher_source_goal_index = source_goal_index
	launch_setup = setup


func clear_settlement_candidate() -> void:
	settlement_goal_index = -1
	settle_elapsed = 0.0


func reset_settlement_dwell() -> void:
	settle_elapsed = 0.0


func reset_low_speed() -> void:
	low_speed_elapsed = 0.0
