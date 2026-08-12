class_name AttemptObservation
extends RefCounted

const SCHEMA_VERSION := 3

const EVENT_AIM := "aim"
const EVENT_FIRE := "fire"
const EVENT_FINISH := "finish"
const EVENT_PROJECTILE_REST := "projectile_rest"
const EVENT_PROJECTILE_WAKE := "projectile_wake"
const EVENT_TERRAIN_RECOVERY := "terrain_recovery"
const EVENT_PROJECTILE_TERMINAL := "projectile_terminal"
const EVENT_MECHANISM_ACTIVATION := "mechanism_activation"
const EVENT_RESULT := "result"

var schema_version: int = SCHEMA_VERSION
var stage_id: StringName = &""
var coverage_metric_version: int = TargetSurfaceCoverage.METRIC_VERSION
var events: Array[Dictionary] = []
var shot_observations: Array[Dictionary] = []
var final_result: Dictionary = {}
var is_sealed: bool = false

var _recording_start_tick: int = 0
var _next_sequence: int = 0


func configure(
		requested_stage_id: StringName,
		recording_start_tick: int = -1
) -> bool:
	if String(requested_stage_id).is_empty():
		return false
	stage_id = requested_stage_id
	events.clear()
	shot_observations.clear()
	final_result.clear()
	is_sealed = false
	_recording_start_tick = recording_start_tick \
			if recording_start_tick >= 0 else Engine.get_physics_frames()
	_next_sequence = 0
	return true


func record_aim(
		yaw: float,
		elevation: float,
		power: float,
		physics_tick: int = -1
) -> bool:
	return _append_event({
		"kind": EVENT_AIM,
		"yaw": yaw,
		"elevation": elevation,
		"power": power,
	}, physics_tick)


func record_fire(shot_id: int, physics_tick: int = -1) -> bool:
	if shot_id <= 0:
		return false
	return _append_event({
		"kind": EVENT_FIRE,
		"shot_id": shot_id,
	}, physics_tick)


func record_finish(reason: StringName = &"manual", physics_tick: int = -1) -> bool:
	if String(reason).is_empty():
		return false
	return _append_event({
		"kind": EVENT_FINISH,
		"reason": String(reason),
	}, physics_tick)


func record_projectile_rest(
		shot_id: int,
		spawn_ordinal: int,
		physics_tick: int = -1
) -> bool:
	return _append_projectile_event(
		EVENT_PROJECTILE_REST, shot_id, spawn_ordinal, {}, physics_tick
	)


func record_projectile_wake(
		shot_id: int,
		spawn_ordinal: int,
		reason: StringName,
		physics_tick: int = -1
) -> bool:
	if String(reason).is_empty():
		return false
	return _append_projectile_event(
		EVENT_PROJECTILE_WAKE,
		shot_id,
		spawn_ordinal,
		{
			"reason": String(reason),
		},
		physics_tick
	)


func record_terrain_recovery(
		shot_id: int,
		spawn_ordinal: int,
		reason: StringName,
		physics_tick: int = -1
) -> bool:
	if String(reason).is_empty():
		return false
	return _append_projectile_event(
		EVENT_TERRAIN_RECOVERY,
		shot_id,
		spawn_ordinal,
		{"reason": String(reason)},
		physics_tick
	)


func record_projectile_terminal(
		shot_id: int,
		spawn_ordinal: int,
		reason: StringName,
		physics_tick: int = -1
) -> bool:
	if String(reason).is_empty():
		return false
	return _append_projectile_event(
		EVENT_PROJECTILE_TERMINAL,
		shot_id,
		spawn_ordinal,
		{"reason": String(reason)},
		physics_tick
	)


func record_mechanism_activation(
		shot_id: int,
		spawn_ordinal: int,
		mechanism_id: StringName,
		mechanism_kind: int,
		physics_tick: int = -1
) -> bool:
	if String(mechanism_id).is_empty() or mechanism_kind < 0:
		return false
	return _append_projectile_event(
		EVENT_MECHANISM_ACTIVATION,
		shot_id,
		spawn_ordinal,
		{
			"mechanism_id": String(mechanism_id),
			"mechanism_kind": mechanism_kind,
		},
		physics_tick
	)


func record_shot_observation(observation: ShotObservation) -> bool:
	if is_sealed or observation == null or not observation.is_sealed:
		return false
	var serialized: Variant = _json_safe_value(observation.to_dictionary())
	if not serialized is Dictionary or not _is_json_safe(serialized):
		return false
	shot_observations.append((serialized as Dictionary).duplicate(true))
	return true


func seal(
		result_reason: StringName,
		paint_mask_checksum: int,
		coverage: float,
		elapsed_ticks: int,
		physics_tick: int = -1
) -> bool:
	if is_sealed or String(result_reason).is_empty() \
			or paint_mask_checksum == 0 or not is_finite(coverage) \
			or coverage < 0.0 or coverage > 100.0 or elapsed_ticks < 0:
		return false
	var result := {
		"reason": String(result_reason),
		"paint_mask_checksum": paint_mask_checksum,
		"coverage": coverage,
		"coverage_metric_version": coverage_metric_version,
		"elapsed_ticks": elapsed_ticks,
	}
	if not _append_event(
		{
			"kind": EVENT_RESULT,
			"reason": result.reason,
			"paint_mask_checksum": paint_mask_checksum,
			"coverage": coverage,
			"coverage_metric_version": coverage_metric_version,
			"elapsed_ticks": elapsed_ticks,
		},
		physics_tick
	):
		return false
	var result_event: Dictionary = events.back()
	result["physics_tick"] = int(result_event.physics_tick)
	result["sequence"] = int(result_event.sequence)
	final_result = result
	is_sealed = true
	return true


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"stage_id": String(stage_id),
		"coverage_metric_version": coverage_metric_version,
		"events": events.duplicate(true),
		"shot_observations": shot_observations.duplicate(true),
		"final_result": final_result.duplicate(true),
		"is_sealed": is_sealed,
	}


func load_dictionary(data: Dictionary) -> bool:
	if not dictionary_is_valid(data):
		return false
	schema_version = int(data.schema_version)
	stage_id = StringName(String(data.stage_id))
	coverage_metric_version = int(data.coverage_metric_version)
	events.clear()
	for event in data.events:
		events.append((event as Dictionary).duplicate(true))
	shot_observations.clear()
	for observation in data.shot_observations:
		shot_observations.append((observation as Dictionary).duplicate(true))
	final_result = (data.final_result as Dictionary).duplicate(true)
	is_sealed = bool(data.is_sealed)
	_next_sequence = events.size()
	_recording_start_tick = Engine.get_physics_frames()
	return true


static func dictionary_is_valid(data: Dictionary) -> bool:
	if not _is_json_safe(data) or int(data.get("schema_version", -1)) != SCHEMA_VERSION \
			or String(data.get("stage_id", "")).is_empty() \
			or int(data.get("coverage_metric_version", -1)) \
					!= TargetSurfaceCoverage.METRIC_VERSION \
			or not data.get("events", []) is Array \
			or not data.get("shot_observations", []) is Array \
			or not data.get("final_result", {}) is Dictionary \
			or not data.has("is_sealed"):
		return false
	var previous_tick := -1
	var events_value: Array = data.events
	for index in range(events_value.size()):
		var event_value: Variant = events_value[index]
		if not event_value is Dictionary:
			return false
		var event: Dictionary = event_value
		if int(event.get("sequence", -1)) != index \
				or int(event.get("physics_tick", -1)) < previous_tick \
				or not _event_is_valid(event):
			return false
		previous_tick = int(event.physics_tick)
	for observation in data.shot_observations:
		if not observation is Dictionary \
				or int(observation.get("schema_version", -1)) != ShotObservation.SCHEMA_VERSION \
				or int(observation.get("coverage_metric_version", -1)) \
						!= TargetSurfaceCoverage.METRIC_VERSION \
				or not bool(observation.get("is_sealed", false)):
			return false
	var sealed := bool(data.is_sealed)
	var final: Dictionary = data.final_result
	if sealed:
		if final.is_empty() or events_value.is_empty() \
				or String(events_value.back().get("kind", "")) != EVENT_RESULT \
				or not _final_result_is_valid(final):
			return false
		var result_event: Dictionary = events_value.back()
		if String(final.reason) != String(result_event.get("reason", "")) \
				or int(final.paint_mask_checksum) \
						!= int(result_event.get("paint_mask_checksum", 0)) \
				or int(final.coverage_metric_version) \
						!= int(result_event.get("coverage_metric_version", -1)) \
				or not is_equal_approx(
					float(final.coverage), float(result_event.get("coverage", -1.0))
				) \
				or int(final.elapsed_ticks) != int(result_event.get("elapsed_ticks", -1)):
			return false
	elif not final.is_empty():
		return false
	return true


func _append_projectile_event(
		kind: String,
		shot_id: int,
		spawn_ordinal: int,
		extra_fields: Dictionary,
		physics_tick: int
) -> bool:
	if shot_id <= 0 or spawn_ordinal < 0:
		return false
	var fields := {
		"kind": kind,
		"shot_id": shot_id,
		"spawn_ordinal": spawn_ordinal,
	}
	fields.merge(extra_fields, true)
	return _append_event(fields, physics_tick)


func _append_event(fields: Dictionary, physics_tick: int) -> bool:
	if is_sealed:
		return false
	var event := fields.duplicate(true)
	event["physics_tick"] = _relative_tick(physics_tick)
	event["sequence"] = _next_sequence
	if not _event_is_valid(event):
		return false
	if not events.is_empty() \
			and int(event.physics_tick) < int(events.back().physics_tick):
		return false
	events.append(event)
	_next_sequence += 1
	return true


func _relative_tick(requested_tick: int) -> int:
	if requested_tick >= 0:
		return requested_tick
	return maxi(0, Engine.get_physics_frames() - _recording_start_tick)


static func _event_is_valid(event: Dictionary) -> bool:
	if int(event.get("physics_tick", -1)) < 0 or int(event.get("sequence", -1)) < 0:
		return false
	match String(event.get("kind", "")):
		EVENT_AIM:
			return _finite_number(event, "yaw") \
					and _finite_number(event, "elevation") \
					and _finite_number(event, "power")
		EVENT_FIRE:
			return int(event.get("shot_id", 0)) > 0
		EVENT_FINISH:
			return not String(event.get("reason", "")).is_empty()
		EVENT_PROJECTILE_REST:
			return _projectile_identity_is_valid(event)
		EVENT_PROJECTILE_WAKE:
			return _projectile_identity_is_valid(event) \
					and not String(event.get("reason", "")).is_empty()
		EVENT_TERRAIN_RECOVERY, EVENT_PROJECTILE_TERMINAL:
			return _projectile_identity_is_valid(event) \
					and not String(event.get("reason", "")).is_empty()
		EVENT_MECHANISM_ACTIVATION:
			return _projectile_identity_is_valid(event) \
					and not String(event.get("mechanism_id", "")).is_empty() \
					and int(event.get("mechanism_kind", -1)) >= 0
		EVENT_RESULT:
			return not String(event.get("reason", "")).is_empty() \
					and int(event.get("paint_mask_checksum", 0)) != 0 \
					and int(event.get("coverage_metric_version", -1)) \
							== TargetSurfaceCoverage.METRIC_VERSION \
					and _coverage_is_valid(event.get("coverage", -1.0)) \
					and int(event.get("elapsed_ticks", -1)) >= 0
		_:
			return false


static func _final_result_is_valid(result: Dictionary) -> bool:
	return not String(result.get("reason", "")).is_empty() \
			and int(result.get("paint_mask_checksum", 0)) != 0 \
			and int(result.get("coverage_metric_version", -1)) \
					== TargetSurfaceCoverage.METRIC_VERSION \
			and _coverage_is_valid(result.get("coverage", -1.0)) \
			and int(result.get("elapsed_ticks", -1)) >= 0 \
			and int(result.get("physics_tick", -1)) >= 0 \
			and int(result.get("sequence", -1)) >= 0


static func _projectile_identity_is_valid(event: Dictionary) -> bool:
	return int(event.get("shot_id", 0)) > 0 \
			and int(event.get("spawn_ordinal", -1)) >= 0


static func _finite_number(dictionary: Dictionary, key: String) -> bool:
	return dictionary.has(key) and is_finite(float(dictionary[key]))


static func _coverage_is_valid(value: Variant) -> bool:
	var coverage := float(value)
	return is_finite(coverage) and coverage >= 0.0 and coverage <= 100.0


static func _vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _vector_array_is_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not is_finite(float(component)):
			return false
	return true


static func _json_safe_value(value: Variant) -> Variant:
	if value is Vector3:
		return _vector3_array(value)
	if value is StringName:
		return String(value)
	if value is Dictionary:
		var converted := {}
		for key in value:
			converted[String(key)] = _json_safe_value(value[key])
		return converted
	if value is Array:
		var converted: Array = []
		for entry in value:
			converted.append(_json_safe_value(entry))
		return converted
	if value is PackedInt32Array or value is PackedInt64Array:
		return Array(value)
	return value


static func _is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for entry in value:
				if not _is_json_safe(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not key is String or not _is_json_safe(value[key]):
					return false
			return true
		_:
			return false
