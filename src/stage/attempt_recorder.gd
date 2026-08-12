class_name AttemptRecorder
extends Node

var terrain_seed: int = 0
var _observation := AttemptObservation.new()


func start_attempt(
		stage_data: StageData,
		requested_terrain_seed: int
) -> bool:
	if stage_data == null:
		return false
	terrain_seed = requested_terrain_seed
	return _observation.configure(
		stage_data.stage_id,
		Engine.get_physics_frames()
	)


func record_aim(yaw: float, elevation: float, power: float) -> bool:
	return _observation.record_aim(yaw, elevation, power)


func record_fire(shot_id: int) -> bool:
	return _observation.record_fire(shot_id)


func record_finish(reason: StringName = &"manual") -> bool:
	return _observation.record_finish(reason)


func record_shot_observation(observation: ShotObservation) -> bool:
	return _observation.record_shot_observation(observation)


func store_final_result(result: Dictionary) -> bool:
	return _observation.seal(
		StringName(String(result.get("finish_reason", result.get("result_reason", "")))),
		int(result.get("paint_mask_checksum", 0)),
		float(result.get("coverage", -1.0)),
		int(result.get("elapsed_ticks", -1))
	)


func current_observation() -> AttemptObservation:
	return _observation


func export_log() -> Dictionary:
	var result := _observation.to_dictionary()
	result["terrain_seed"] = terrain_seed
	return result
