extends SceneTree

const CANNON_SCENE := preload("res://scenes/gameplay/cannon.tscn")
const PREDICTION_SCHEDULER := preload(
	"res://src/cannon/trajectory_prediction_scheduler.gd"
)

var _failed := false
var _fake_compute_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cannon := CANNON_SCENE.instantiate() as CannonController
	var scheduler := PREDICTION_SCHEDULER.new()
	root.add_child(cannon)
	root.add_child(scheduler)
	await process_frame

	var roomy_bounds := AABB(
		Vector3(-10000.0, -10000.0, -10000.0),
		Vector3(20000.0, 20000.0, 20000.0)
	)
	_assert_true(
		scheduler.configure(cannon, roomy_bounds, _fake_job),
		"scheduler fixture must configure"
	)
	scheduler.set_consumers_enabled(true)
	scheduler._physics_process(1.0 / 60.0)
	_assert_true(
		_fake_compute_count == 1 and scheduler.active_job_count() == 1,
		"first enabled fixed tick must start exactly one prediction job"
	)
	_assert_true(
		scheduler.last_advance_step_count() \
				<= TrajectoryPredictionScheduler.MAXIMUM_STEPS_PER_TICK,
		"one fixed callback must never exceed the 12-step budget"
	)
	_assert_true(
		cannon.current_prediction() == null,
		"an incomplete job must not publish a partial arc"
	)
	_drive_until_publication(scheduler, cannon, 800)
	_assert_true(
		cannon.current_prediction() != null \
				and scheduler.prediction_publication_count() == 1,
		"one complete job must publish one atomic prediction"
	)

	var initial_context := scheduler.current_context_key()
	for _tick in range(10):
		scheduler.request_latest()
		scheduler._physics_process(1.0 / 60.0)
	_assert_true(
		_fake_compute_count == 1 and scheduler.current_context_key() == initial_context,
		"an unchanged aim must reuse the completed prediction"
	)

	# Continuous drag nominates only one newest context per twelve scheduler
	# ticks. Each nomination replaces obsolete active work instead of waiting.
	scheduler.set_aim_interaction_active(true)
	for tick in range(36):
		cannon.set_aim(float(tick + 1), 38.0, 68.0)
		scheduler.request_latest()
		scheduler._physics_process(1.0 / 60.0)
		_assert_true(
			scheduler.last_advance_step_count() \
					<= TrajectoryPredictionScheduler.MAXIMUM_STEPS_PER_TICK,
			"interactive refresh must retain the fixed-step budget"
		)
		_assert_true(
			scheduler.active_job_count() <= 1,
			"scheduler ownership must remain one active latest-context job"
		)
	_assert_true(
		_fake_compute_count <= 4,
		"thirty-six interactive ticks must nominate at most once per twelve ticks"
	)
	_assert_true(
		scheduler.discarded_job_count() > 0,
		"a newer nominated aim must discard obsolete active work"
	)
	scheduler.set_aim_interaction_active(false)
	scheduler._physics_process(1.0 / 60.0)
	var final_aim_key := cannon.aim_key()
	_drive_until_publication(scheduler, cannon, 800)
	_assert_true(
		cannon.prediction_aim_key() == final_aim_key,
		"release must immediately nominate and eventually publish only the latest aim"
	)

	_assert_true(
		scheduler.prediction_compute_count() == _fake_compute_count,
		"structural diagnostics must count only jobs actually started"
	)
	cannon.queue_free()
	scheduler.queue_free()
	await process_frame
	if not _failed:
		print("Prediction scheduler checks passed: 12-step/1 ms callbacks, obsolete-work replacement, and unchanged-aim reuse.")
	quit(1 if _failed else 0)


func _drive_until_publication(
		scheduler: TrajectoryPredictionScheduler,
		cannon: CannonController,
		maximum_ticks: int
) -> void:
	var expected := cannon.aim_key()
	for _tick in range(maximum_ticks):
		if cannon.prediction_aim_key() == expected \
				and cannon.prediction_matches_expected_context():
			return
		scheduler._physics_process(1.0 / 60.0)
		_assert_true(
			scheduler.last_advance_step_count() \
					<= TrajectoryPredictionScheduler.MAXIMUM_STEPS_PER_TICK,
			"every driven callback must stay inside the step budget"
		)
	_assert_true(false, "latest prediction must complete inside the bounded fixture window")


func _fake_job(
		cannon: CannonController,
		bounds: AABB
) -> TrajectoryPredictionJob:
	_fake_compute_count += 1
	return TrajectoryPredictionJob.create(
		cannon.get_world_3d().direct_space_state,
		cannon.get_launch_origin(),
		cannon.get_launch_velocity(),
		cannon.projectile_data.radius,
		cannon.projectile_data.linear_damp,
		bounds,
		TrajectoryPredictionJob.COLLISION_MASK,
		true
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Prediction scheduler check failed: %s" % message)
