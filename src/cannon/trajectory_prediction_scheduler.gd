class_name TrajectoryPredictionScheduler
extends Node

## Owns one bounded advisory prediction job. New aim replaces
## obsolete work; prediction never gates StageController or terrain input.

const MAXIMUM_STEPS_PER_TICK := 12
const MAXIMUM_WORK_USEC_PER_TICK := 1000
const AIM_NOMINATION_INTERVAL_TICKS := 12
var _cannon: CannonController
var _bounds := AABB()
var _prediction_callback: Callable
var _consumers_enabled := false
var _aim_interaction_active := false
var _request_dirty := true
var _nominate_immediately := true
var _scheduler_tick := 0
var _last_nomination_tick := -AIM_NOMINATION_INTERVAL_TICKS
var _hold_physics_ticks := 0
var _current_context_key: StringName = &""
var _active_request: Dictionary = {}
var _active_job: TrajectoryPredictionJob
var _prediction_compute_count := 0
var _prediction_publication_count := 0
var _last_advance_step_count := 0
var _last_advance_elapsed_usec := 0
var _discarded_job_count := 0


func configure(
		cannon: CannonController,
		bounds: AABB,
		prediction_callback: Callable = Callable()
) -> bool:
	if (
		cannon == null
		or not bounds.has_volume()
	):
		return false
	_cannon = cannon
	_bounds = bounds
	_prediction_callback = prediction_callback
	_request_dirty = true
	_nominate_immediately = true
	set_physics_process(_consumers_enabled)
	return true


func request_latest(immediate: bool = false) -> void:
	if not immediate and _live_context_is_already_owned():
		return
	_request_dirty = true
	_nominate_immediately = (
		_nominate_immediately
		or immediate
		or not _aim_interaction_active
	)


func set_aim_interaction_active(active: bool) -> void:
	if _aim_interaction_active == active:
		return
	_aim_interaction_active = active
	if active:
		_request_dirty = true
	else:
		request_latest(true)


func set_consumers_enabled(enabled: bool) -> void:
	if _consumers_enabled == enabled:
		return
	_consumers_enabled = enabled
	set_physics_process(enabled)
	if enabled:
		request_latest(true)
	else:
		_active_job = null
		_active_request.clear()


func consumers_enabled() -> bool:
	return _consumers_enabled


func hold_refresh_for_seconds(duration_seconds: float) -> void:
	var ticks_per_second := maxi(Engine.physics_ticks_per_second, 1)
	_hold_physics_ticks = maxi(
		_hold_physics_ticks,
		ceili(maxf(duration_seconds, 0.0) * float(ticks_per_second))
	)
	request_latest(true)


func prediction_compute_count() -> int:
	return _prediction_compute_count


func prediction_publication_count() -> int:
	return _prediction_publication_count


func current_context_key() -> StringName:
	return _current_context_key


func active_job_count() -> int:
	return 1 if _active_job != null else 0


func last_advance_step_count() -> int:
	return _last_advance_step_count


func last_advance_elapsed_usec() -> int:
	return _last_advance_elapsed_usec


func discarded_job_count() -> int:
	return _discarded_job_count


func _physics_process(_delta: float) -> void:
	if _cannon == null or not _consumers_enabled:
		return
	_scheduler_tick += 1
	_last_advance_step_count = 0
	_last_advance_elapsed_usec = 0
	if _hold_physics_ticks > 0:
		_hold_physics_ticks -= 1
		return
	if _request_dirty and _nomination_is_due():
		_nominate_live_context()
	if _active_job != null:
		_advance_active_job()


func _advance_active_job() -> void:
	var started_at := Time.get_ticks_usec()
	while (
		_last_advance_step_count < MAXIMUM_STEPS_PER_TICK
		and not _active_job.is_complete()
	):
		_last_advance_step_count += _active_job.advance(1)
		if Time.get_ticks_usec() - started_at >= MAXIMUM_WORK_USEC_PER_TICK:
			break
	_last_advance_elapsed_usec = Time.get_ticks_usec() - started_at
	if _active_job.is_complete():
		_complete_active_job()


func _nomination_is_due() -> bool:
	return (
		_nominate_immediately
		or not _aim_interaction_active
		or _scheduler_tick - _last_nomination_tick >= AIM_NOMINATION_INTERVAL_TICKS
	)


func _nominate_live_context() -> void:
	var request := _capture_live_request()
	var context_key := request.context_key as StringName
	_current_context_key = context_key
	_last_nomination_tick = _scheduler_tick
	_request_dirty = false
	_nominate_immediately = false
	_cannon.expect_prediction_context(context_key)
	if _active_job != null:
		if StringName(_active_request.get("context_key", &"")) != context_key:
			_discarded_job_count += 1
			_active_job = null
			_active_request.clear()
			_start_job(request)
		return
	if (
		_cannon.prediction_key() == context_key
		and _cannon.prediction_matches_expected_context()
	):
		return
	_start_job(request)


func _capture_live_request() -> Dictionary:
	var aim_key := _cannon.aim_key()
	return {
		"context_key": build_context_key(aim_key),
		"aim_key": aim_key,
		"origin": _cannon.get_launch_origin(),
		"launch_velocity": _cannon.get_launch_velocity(),
		"projectile_radius": _cannon.projectile_data.radius,
		"linear_damp": _cannon.projectile_data.linear_damp,
	}


func _start_job(request: Dictionary) -> void:
	_active_request = request
	_prediction_compute_count += 1
	if _prediction_callback.is_valid():
		var result: Variant = _prediction_callback.call(
			_cannon,
			_bounds
		)
		if result is TrajectoryPredictionJob:
			_active_job = result as TrajectoryPredictionJob
		elif result is TrajectoryPrediction:
			_active_job = TrajectoryPredictionJob.completed(
				result as TrajectoryPrediction
			)
		else:
			_active_job = TrajectoryPredictionJob.create(
				null, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, _bounds
			)
		return
	_active_job = TrajectoryPredictionJob.create(
		_cannon.get_world_3d().direct_space_state,
		request.origin as Vector3,
		request.launch_velocity as Vector3,
		float(request.projectile_radius),
		float(request.linear_damp),
		_bounds,
		TrajectoryPredictionJob.COLLISION_MASK,
		true
	)


func _complete_active_job() -> void:
	var finished_request := _active_request.duplicate()
	var finished_job := _active_job
	_active_request.clear()
	_active_job = null
	var finished_key := StringName(finished_request.get("context_key", &""))
	var live_key := _live_context_key()
	if finished_key == live_key:
		var prediction := finished_job.completed_prediction()
		if prediction != null:
			_cannon.set_prediction(
				prediction,
				StringName(finished_request.aim_key),
				finished_key
			)
			_prediction_publication_count += 1
	else:
		_request_dirty = true


func _live_context_key() -> StringName:
	return build_context_key(_cannon.aim_key())


func _live_context_is_already_owned() -> bool:
	if _cannon == null or not _consumers_enabled:
		return false
	var live_key := _live_context_key()
	if live_key != _current_context_key:
		return false
	if (
		_active_job != null
		and StringName(_active_request.get("context_key", &"")) == live_key
	):
		return true
	return (
		_cannon.prediction_key() == live_key
		and _cannon.prediction_matches_expected_context()
	)


static func build_context_key(aim_key: StringName) -> StringName:
	return aim_key
