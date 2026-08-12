class_name TerrainAimController
extends Node

## Owns the selected terrain target and commits the best approximate inverse
## solution immediately. Exact collision prediction only refines presentation.
signal target_state_changed(target: TerrainAimTarget, visual_state: StringName)

const REJECTED_PRESENTATION_SECONDS := 0.35

var _camera: Camera3D
var _terrain: TerrainSurface
var _cannon: CannonController
var _stage_controller: StageController
var _preview: TerrainTargetPreview
var _picker := TerrainScreenRayPicker.new()
var _selected_target: TerrainAimTarget
var _committed_target: TerrainAimTarget
var _branch: StringName = &""
var _preferred_constraint: StringName = &"target"
var _preferred_value := 0.0
var _next_request_revision := 0
var _queued_pointer_revision := -1
var _queued_pointer_settled := false
var _configured := false
var _user_selected := false
var _rejected_revision := -1
var _solve_request_count := 0
var _last_solve_elapsed_usec := 0


func configure(
		camera: Camera3D,
		terrain: TerrainSurface,
		cannon: CannonController,
		stage_controller: StageController,
		preview: TerrainTargetPreview
) -> bool:
	if (
		camera == null
		or terrain == null
		or cannon == null
		or stage_controller == null
		or preview == null
	):
		return false
	_camera = camera
	_terrain = terrain
	_cannon = cannon
	_stage_controller = stage_controller
	_preview = preview
	_branch = _branch_for_aim(_current_aim())
	if not _cannon.prediction_changed.is_connected(_on_prediction_changed):
		_cannon.prediction_changed.connect(_on_prediction_changed)
	_configured = true
	set_physics_process(true)
	_on_prediction_changed(_cannon.current_prediction())
	return true


func _physics_process(_delta: float) -> void:
	if not _configured or _picker.queued_request_revision() < 0:
		return
	var target := _picker.pick_latest_in_physics(_terrain)
	var consumed_revision := _picker.consumed_request_revision()
	var settled := (
		consumed_revision == _queued_pointer_revision
		and _queued_pointer_settled
	)
	if target != null:
		_user_selected = true
		_request_explicit_target(target)
	elif settled:
		_present_selected_state()


func queue_pointer_target(screen_position: Vector2, settled: bool = false) -> bool:
	if not _configured or not screen_position.is_finite():
		return false
	_next_request_revision += 1
	_queued_pointer_revision = _next_request_revision
	_queued_pointer_settled = settled
	return _picker.queue_latest(_camera, screen_position, _queued_pointer_revision)


func request_elevation_delta(delta_degrees: float) -> bool:
	if not _can_request_explicit_adjustment() or not is_finite(delta_degrees):
		return false
	var requested := AimTuple.snap_angle(clampf(
		_cannon.elevation_degrees + delta_degrees,
		AimTuple.MINIMUM_ELEVATION_DEGREES,
		AimTuple.MAXIMUM_ELEVATION_DEGREES
	))
	if is_equal_approx(requested, _cannon.elevation_degrees):
		return false
	var committed := _solve_and_commit(_selected_target, &"elevation", requested)
	if committed:
		_preferred_constraint = &"elevation"
		_preferred_value = requested
	return committed


func request_power_delta(delta_percent: float) -> bool:
	if not _can_request_explicit_adjustment() or not is_finite(delta_percent):
		return false
	var requested := AimTuple.snap_power(clampf(
		_cannon.power_percent + delta_percent,
		AimTuple.MINIMUM_POWER_PERCENT,
		AimTuple.MAXIMUM_POWER_PERCENT
	))
	if is_equal_approx(requested, _cannon.power_percent):
		return false
	var committed := _solve_and_commit(_selected_target, &"power", requested)
	if committed:
		_preferred_constraint = &"power"
		_preferred_value = requested
	return committed


func reset_for_restart() -> void:
	_rejected_revision = -1
	_picker.clear()
	_selected_target = null
	_committed_target = null
	_user_selected = false
	_branch = _branch_for_aim(_current_aim())
	_preferred_constraint = &"target"
	_preferred_value = 0.0
	if _preview != null:
		_preview.clear_target()
	target_state_changed.emit(null, TerrainTargetPreview.STATE_HIDDEN)


func selected_target() -> TerrainAimTarget:
	return _selected_target


func selected_target_state() -> StringName:
	return _preview.visual_state() if _preview != null else TerrainTargetPreview.STATE_HIDDEN


func solve_request_count() -> int:
	return _solve_request_count


func last_solve_elapsed_usec() -> int:
	return _last_solve_elapsed_usec


func _request_explicit_target(target: TerrainAimTarget) -> bool:
	if _selected_target != null and _selected_target.revision_key == target.revision_key:
		return true
	var committed := _solve_and_commit(target, &"target", 0.0)
	if committed:
		_preferred_constraint = &"target"
		_preferred_value = 0.0
	return committed


func _solve_and_commit(
		target: TerrainAimTarget,
		constraint: StringName,
		requested_value: float,
		present_rejection: bool = true
) -> bool:
	if target == null:
		return false
	_solve_request_count += 1
	var started_at := Time.get_ticks_usec()
	var candidates := TerrainAimSolver.nominate(
		_cannon,
		target,
		constraint,
		requested_value,
		_branch,
		_current_aim()
	)
	_last_solve_elapsed_usec = Time.get_ticks_usec() - started_at
	if candidates.is_empty():
		if present_rejection:
			_present_rejected_target(target)
		return false
	var aim := candidates[0].aim as AimTuple
	if aim == null or not _stage_controller.set_aim(
		aim.yaw_degrees,
		aim.elevation_degrees,
		aim.power_percent,
		StageController.ActionOrigin.HUMAN
	):
		if present_rejection:
			_present_rejected_target(target)
		return false
	_committed_target = target
	_selected_target = target
	_branch = _branch_for_aim(aim)
	_preview.present_target(
		target.world_point,
		target.world_normal,
		TerrainTargetPreview.STATE_SELECTED
	)
	target_state_changed.emit(target, TerrainTargetPreview.STATE_SELECTED)
	return true


func _present_rejected_target(target: TerrainAimTarget) -> void:
	_next_request_revision += 1
	var revision := _next_request_revision
	_rejected_revision = revision
	_selected_target = _committed_target
	_preview.present_target(
		target.world_point,
		target.world_normal,
		TerrainTargetPreview.STATE_REJECTED
	)
	target_state_changed.emit(target, TerrainTargetPreview.STATE_REJECTED)
	get_tree().create_timer(REJECTED_PRESENTATION_SECONDS).timeout.connect(
		_restore_preview_after_rejection.bind(revision)
	)


func _restore_preview_after_rejection(revision: int) -> void:
	if revision != _rejected_revision:
		return
	_rejected_revision = -1
	_present_selected_state()


func _on_prediction_changed(prediction: TrajectoryPrediction) -> void:
	if not _configured:
		return
	if (
		_selected_target == null
		and not _user_selected
		and _prediction_is_current_top(prediction)
	):
		_selected_target = TerrainAimTarget.new(
			prediction.collision_contact_point(), prediction.normal, prediction.hit_identity
		)
		_committed_target = _selected_target
		_branch = _branch_for_aim(_current_aim())
	_present_selected_state()


func _present_selected_state() -> void:
	if _selected_target == null:
		_preview.clear_target()
		target_state_changed.emit(null, TerrainTargetPreview.STATE_HIDDEN)
		return
	var prediction := _cannon.current_prediction()
	var state := (
		TerrainTargetPreview.STATE_CONFIRMED
		if (
			_prediction_is_current_top(prediction)
			and TerrainAimSolver.validates_target(
				prediction, _selected_target, _cannon.projectile_data.radius
			)
		)
		else TerrainTargetPreview.STATE_SELECTED
	)
	_preview.present_target(_selected_target.world_point, _selected_target.world_normal, state)
	target_state_changed.emit(_selected_target, state)


func _prediction_is_current_top(prediction: TrajectoryPrediction) -> bool:
	return (
		prediction != null
		and prediction.kind == TrajectoryPrediction.Kind.COLLISION
		and prediction.hit_identity != null
		and prediction.hit_identity.contact_owner_id
				== TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID
		and _cannon.prediction_matches_expected_context()
	)


func _can_request_explicit_adjustment() -> bool:
	return (
		_configured
		and _selected_target != null
		and _stage_controller.current_state == StageController.State.AIMING
		and _cannon.input_enabled
	)


func _current_aim() -> AimTuple:
	if _cannon == null:
		return null
	return AimTuple.new(
		_cannon.yaw_degrees, _cannon.elevation_degrees, _cannon.power_percent
	)


func _branch_for_aim(aim: AimTuple) -> StringName:
	if aim == null:
		return &"low"
	return (
		&"high"
		if aim.elevation_degrees
				>= TerrainAimSolver.BRANCH_SPLIT_ELEVATION_DEGREES
		else &"low"
	)
