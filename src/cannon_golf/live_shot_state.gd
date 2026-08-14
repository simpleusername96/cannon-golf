class_name CannonGolfLiveShotState
extends RefCounted

## Per-ball attempt state. The game coordinates course-wide completion, while
## each live ball independently owns goal entry and settlement timing.

var ball: CannonGolfBall
var settle_elapsed := 0.0
var low_speed_elapsed := 0.0
var entered_goal := false
var entered_goal_index := -1
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


func reset_settlement() -> void:
	settle_elapsed = 0.0


func reset_low_speed() -> void:
	low_speed_elapsed = 0.0
