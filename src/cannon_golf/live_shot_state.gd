class_name CannonGolfLiveShotState
extends RefCounted

## Per-ball attempt state. The game coordinates course-wide completion, while
## each live ball independently owns goal entry and settlement timing.

var ball: CannonGolfBall
var settle_elapsed := 0.0
var low_speed_elapsed := 0.0
var entered_goal := false
var ending := false


func _init(live_ball: CannonGolfBall) -> void:
	assert(live_ball != null)
	ball = live_ball


func reset_settlement() -> void:
	settle_elapsed = 0.0


func reset_low_speed() -> void:
	low_speed_elapsed = 0.0
