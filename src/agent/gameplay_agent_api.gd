class_name GameplayAgentApi
extends Node

signal gameplay_event(event_name: StringName, payload: Dictionary)

var _stage_data: StageData
var _generated_layout: GeneratedStageLayout
var _stage_controller: StageController
var _cannon: CannonController
var _paint_system: PaintSystem
var _projectile_manager: ProjectileManager
var _camera_director: CameraDirector
var _mechanisms: Array[TerrainGlyphMechanism] = []
var _previous_shot: Dictionary = {}


func configure(
		stage_data: StageData,
		stage_controller: StageController,
		cannon: CannonController,
		paint_system: PaintSystem,
		projectile_manager: ProjectileManager,
		camera_director: CameraDirector,
		mechanisms: Array[TerrainGlyphMechanism],
		generated_layout: GeneratedStageLayout = null
) -> void:
	_stage_data = stage_data
	_generated_layout = generated_layout
	_stage_controller = stage_controller
	_cannon = cannon
	_paint_system = paint_system
	_projectile_manager = projectile_manager
	_camera_director = camera_director
	_mechanisms = mechanisms
	if not _stage_controller.shot_fired.is_connected(_on_shot_fired):
		_stage_controller.shot_fired.connect(_on_shot_fired)
	if not _stage_controller.shot_observation_sealed.is_connected(_on_shot_observation_sealed):
		_stage_controller.shot_observation_sealed.connect(_on_shot_observation_sealed)
	if not _stage_controller.stage_finished.is_connected(_on_stage_finished):
		_stage_controller.stage_finished.connect(_on_stage_finished)
	if not _projectile_manager.projectile_contact_reported.is_connected(_on_projectile_contact_reported):
		_projectile_manager.projectile_contact_reported.connect(_on_projectile_contact_reported)


func _on_projectile_contact_reported(
		projectile: PaintProjectile,
		contact: ProjectileContact
) -> void:
	gameplay_event.emit(&"projectile_impacted", {
		"spawn_ordinal": projectile.spawn_ordinal,
		"position": contact.world_position,
		"normal": contact.normal,
		"speed": contact.relative_normal_speed,
		"impulse": contact.impulse,
		"impulse_was_measured": contact.impulse_was_measured,
		"contact_owner_id": String(contact.contact_owner_id),
		"contact_shape_id": String(contact.contact_shape_id),
		"local_shape_index": contact.local_shape_index,
		"collider_shape_index": contact.collider_shape_index,
		"physics_tick": contact.physics_tick,
		"source_event_index": contact.source_event_index,
	})


func get_observation() -> Dictionary:
	var mechanism_states: Array[Dictionary] = []
	for mechanism in _mechanisms:
		mechanism_states.append(mechanism.state_snapshot())
	var activity := _stage_controller.activity_snapshot()
	var active_shot_ids: PackedInt64Array = activity.get("active_shot_ids", PackedInt64Array())
	var aim_ready := _stage_controller.current_state == StageController.State.AIMING \
			and _cannon.input_enabled
	var fire_readiness := _stage_controller.fire_readiness_snapshot(StageController.ActionOrigin.AGENT)
	var projectile_activity := _projectile_activity_snapshot(activity)
	var terminal_pending := bool(activity.get("terminal_pending", false))
	return {
		"schema_version": AttemptObservation.SCHEMA_VERSION,
		"stage_id": String(_stage_data.stage_id),
		"terrain_seed": _generated_layout.terrain_seed if _generated_layout != null else 0,
		"height_grid_checksum": _generated_layout.checksum if _generated_layout != null else 0,
		"layout": _layout_metadata(),
		"coverage_metric_version": TargetSurfaceCoverage.METRIC_VERSION,
		"target_coverage": _stage_data.target_coverage,
		"current_coverage": _paint_system.coverage_percent(),
		"paint": {
			"pending_command_count": _paint_system.pending_work_count(),
			"last_drained_tick": _paint_system.last_drained_physics_tick(),
			"mask_checksum": _paint_system.paint_mask_checksum(),
		},
		"shots_remaining": _stage_controller.shots_remaining,
		"cannon": {
			"yaw": _cannon.yaw_degrees,
			"elevation": _cannon.elevation_degrees,
			"power": _cannon.power_percent,
		},
		"terrain_bounds": (
			_generated_layout.play_bounds.bounds
			if _generated_layout != null and _generated_layout.play_bounds != null
			else AABB()
		),
		"terrain_height_grid": _height_grid(13, 9),
		"mechanisms": mechanism_states,
		"clock": _stage_controller.clock_snapshot(),
		"result": _stage_controller.result_snapshot(),
		"projectiles": projectile_activity,
		"interaction": {
			"mode": _camera_director.interaction_mode_name(),
			"mode_id": int(_camera_director.current_interaction_mode),
			"aim_locked": _camera_director.aim_is_locked(),
		},
		"previous_shot": _previous_shot.duplicate(true),
		"sealed_shots": _sealed_shot_dictionaries(),
		"active_projectiles": int(projectile_activity.resident_count),
		"active_shot_families": active_shot_ids.size(),
		"active_shot_ids": active_shot_ids,
		"aim_ready": aim_ready,
		"fire_ready": bool(fire_readiness.get("fireable", false)),
		"fire_readiness": {
			"phase": fire_readiness.get("phase", ""),
			"editable": bool(fire_readiness.get("editable", false)),
			"canonical_aim_valid": bool(
				fire_readiness.get("canonical_aim_valid", false)
			),
			"active_root_count": int(fire_readiness.get("active_root_count", 0)),
			"fire_capacity": int(fire_readiness.get("fire_capacity", 0)),
			"shots_remaining": int(fire_readiness.get("shots_remaining", 0)),
			"terminal_pending": bool(fire_readiness.get("terminal_pending", false)),
			"fireable": bool(fire_readiness.get("fireable", false)),
			"reason_key": String(fire_readiness.get("reason_key", "ready")),
			"reason": fire_readiness.get("reason", ""),
		},
		"trajectory_preview": {
			"status": String(_cannon.prediction_status()),
			"aim_key": String(_cannon.prediction_aim_key()),
			"context_key": String(_cannon.prediction_key()),
		},
		"fire_capacity": int(activity.get("fire_capacity", 2)),
		"terminal_pending": terminal_pending,
		# Compatibility alias retained for one schema cycle; it now describes aim
		# readiness rather than implying that Fire has available capacity.
		"ready_for_action": aim_ready,
}


func _sealed_shot_dictionaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _stage_controller == null:
		return result
	for observation in _stage_controller.sealed_shot_observations():
		result.append(observation.to_dictionary())
	return result


func set_aim(yaw: float, elevation: float, power: float) -> bool:
	return _stage_controller.set_aim(yaw, elevation, power, StageController.ActionOrigin.AGENT)


func fire() -> bool:
	return _stage_controller.request_fire(StageController.ActionOrigin.AGENT)


func finish() -> bool:
	return _stage_controller.finish_stage(StageController.ActionOrigin.AGENT)


func restart() -> void:
	_stage_controller.restart(false, StageController.ActionOrigin.AGENT)


func change_interaction_mode(mode: CameraDirector.InteractionMode) -> bool:
	if mode not in [
		CameraDirector.InteractionMode.AIM_LOCKED,
		CameraDirector.InteractionMode.MAP_INSPECTION,
	]:
		return false
	if _stage_controller.current_state not in [
		StageController.State.BRIEFING,
		StageController.State.AIMING,
	]:
		return false
	return _camera_director.set_interaction_mode(mode)


func start_next_stage() -> bool:
	var next_id := StageCatalog.next_stage_id(_stage_data.stage_id)
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or next_id.is_empty() or not game_state.select_stage(next_id):
		return false
	gameplay_event.emit(&"next_stage_requested", {"stage_id": String(next_id)})
	return true


func notify_event(event_name: StringName, payload: Dictionary = {}) -> void:
	gameplay_event.emit(event_name, payload.duplicate(true))


func _on_shot_fired(order: int, yaw: float, elevation: float, power: float) -> void:
	_previous_shot = {"order": order, "yaw": yaw, "elevation": elevation, "power": power, "coverage_gain": 0.0}
	gameplay_event.emit(&"shot_started", _previous_shot.duplicate(true))


func _on_shot_observation_sealed(observation: ShotObservation) -> void:
	_previous_shot = observation.to_dictionary()
	gameplay_event.emit(&"shot_settled", _previous_shot.duplicate(true))


func _on_stage_finished(result: Dictionary) -> void:
	gameplay_event.emit(&"stage_finished", result.duplicate(true))


func _projectile_activity_snapshot(activity: Dictionary) -> Dictionary:
	var resident := _projectile_manager.active_projectiles()
	var airborne_count := 0
	var moving_on_terrain_count := 0
	var resting_count := 0
	for projectile in resident:
		match projectile.motion_state:
			PaintProjectile.MotionState.MOVING_AIRBORNE:
				airborne_count += 1
			PaintProjectile.MotionState.MOVING_ON_TERRAIN:
				moving_on_terrain_count += 1
			PaintProjectile.MotionState.RESTING_ON_TERRAIN:
				resting_count += 1
	return {
		"resident_count": resident.size(),
		"moving_count": airborne_count + moving_on_terrain_count,
		"resting_count": resting_count,
		"airborne_count": airborne_count,
		"moving_on_terrain_count": moving_on_terrain_count,
		"initial_flight_family_count": int(activity.get("active_root_count", 0)),
		"initial_flight_capacity": int(activity.get("fire_capacity", 0)),
	}


func _height_grid(columns: int, rows: int) -> Array[PackedFloat32Array]:
	var grid: Array[PackedFloat32Array] = []
	for row in range(rows):
		var values := PackedFloat32Array()
		var local_z := lerpf(-_stage_data.terrain_size.y * 0.5, _stage_data.terrain_size.y * 0.5, float(row) / float(rows - 1))
		for column in range(columns):
			var local_x := lerpf(-_stage_data.terrain_size.x * 0.5, _stage_data.terrain_size.x * 0.5, float(column) / float(columns - 1))
			values.append(
				_generated_layout.height_at_local(local_x, local_z)
				if _generated_layout != null
				else 0.0
			)
		grid.append(values)
	return grid


func _layout_metadata() -> Dictionary:
	if _generated_layout == null:
		return {}
	var certificate := _generated_layout.reachability_certificate
	var default_aim := _generated_layout.default_aim
	return {
		"profile_id": String(_generated_layout.profile_id),
		"profile_version": _generated_layout.profile_version,
		"target_mask_checksum": _generated_layout.target_mask_checksum,
		"coverage_metric_version": _generated_layout.coverage_metric_version,
		"total_target_surface_area": _generated_layout.total_target_surface_area,
		"target_surface_area_checksum": _generated_layout.target_surface_area_checksum,
		"reachability_checksum": (
			certificate.reachable_target_checksum
			if certificate != null and certificate.is_valid()
			else 0
		),
		"play_bounds_checksum": (
			_generated_layout.play_bounds.checksum()
			if _generated_layout.play_bounds != null
			else 0
		),
		"placement_checksum": _generated_layout.placement_checksum(),
		"generated_default_aim": {
			"yaw": default_aim.yaw_degrees,
			"elevation": default_aim.elevation_degrees,
			"power": default_aim.power_percent,
		} if default_aim != null else {},
	}
