class_name ShotObservation
extends RefCounted

const SCHEMA_VERSION := 6

var schema_version: int = SCHEMA_VERSION
var shot_number: int = 0
var shot_id: int = 0
var commanded_yaw: float = 0.0
var commanded_elevation: float = 0.0
var commanded_power: float = 0.0
var contacts: Array[Dictionary] = []
var mechanism_activations: Array[Dictionary] = []
var child_spawns: Array[Dictionary] = []
var settlements: Array[Dictionary] = []
var first_terrain_contact: ProjectileContact
var first_mechanism_contact: ProjectileContact
var first_contact: ProjectileContact
var mechanism_activation_kinds := PackedInt32Array()
var spawned_child_count: int = 0
var peak_active_projectile_count: int = 0
var settlement_reason_counts: Dictionary = {}
var coverage_before: float = 0.0
var coverage_after: float = 0.0
var coverage_gain: float = 0.0
var coverage_metric_version: int = TargetSurfaceCoverage.METRIC_VERSION
var paint_command_count: int = 0
var paint_command_rejections: Array[Dictionary] = []
var paint_command_rejection_count: int = 0
var final_drain_tick: int = -1
var final_paint_mask_checksum: int = 0
var invalid_geometry_count: int = 0
# Read-only compatibility for diagnostics that have not yet moved to the
# explicit INVALID_GEOMETRY terminal reason.
var penetration_guard_count: int:
	get:
		return invalid_geometry_count
var is_sealed: bool = false


func configure(
		new_shot_number: int,
		yaw: float,
		elevation: float,
		power: float,
		before_coverage: float,
		new_shot_id: int = 0
) -> void:
	assert(not is_sealed, "A sealed shot observation cannot be configured.")
	shot_number = new_shot_number
	shot_id = new_shot_id
	commanded_yaw = yaw
	commanded_elevation = elevation
	commanded_power = power
	coverage_before = before_coverage


func record_contact(
		projectile_spawn_ordinal: int,
		contact: ProjectileContact,
		contact_category: StringName
) -> void:
	if is_sealed or contact == null:
		return
	contacts.append({
		"spawn_ordinal": projectile_spawn_ordinal,
		"physics_tick": contact.physics_tick,
		"source_event_index": contact.source_event_index,
		"category": String(contact_category),
		"contact_owner_id": String(contact.contact_owner_id),
		"contact_shape_id": String(contact.contact_shape_id),
		"local_shape_index": contact.local_shape_index,
		"collider_shape_index": contact.collider_shape_index,
		"point": contact.world_position,
		"normal": contact.normal,
		"impact_center": contact.impact_center_position,
		"incoming_velocity": contact.incoming_velocity,
		"relative_normal_speed": contact.relative_normal_speed,
		"impulse": contact.impulse,
		"impulse_was_measured": contact.impulse_was_measured,
		"is_first_contact": contact.is_first_contact,
	})
	if first_contact == null:
		first_contact = contact
	if contact_category == &"terrain" and first_terrain_contact == null:
		first_terrain_contact = contact
	elif contact_category == &"mechanism" and first_mechanism_contact == null:
		first_mechanism_contact = contact


func record_mechanism_activation(
		projectile_spawn_ordinal: int,
		mechanism_id: StringName,
		kind: int,
		physics_tick: int
) -> void:
	if is_sealed:
		return
	mechanism_activations.append({
		"spawn_ordinal": projectile_spawn_ordinal,
		"mechanism_id": String(mechanism_id),
		"kind": kind,
		"physics_tick": physics_tick,
	})
	mechanism_activation_kinds.append(kind)


func record_child_spawn(
		spawn_ordinal: int,
		split_generation: int,
		physics_tick: int,
		active_count: int
) -> void:
	if is_sealed:
		return
	child_spawns.append({
		"spawn_ordinal": spawn_ordinal,
		"split_generation": split_generation,
		"physics_tick": physics_tick,
	})
	spawned_child_count += 1
	peak_active_projectile_count = maxi(peak_active_projectile_count, active_count)


func record_settlement(
		projectile_spawn_ordinal: int,
		reason: StringName,
		physics_tick: int
) -> void:
	if is_sealed:
		return
	settlements.append({
		"spawn_ordinal": projectile_spawn_ordinal,
		"reason": String(reason),
		"physics_tick": physics_tick,
	})
	settlement_reason_counts[reason] = int(settlement_reason_counts.get(reason, 0)) + 1
	if reason == ProjectileSettlementReason.INVALID_GEOMETRY:
		invalid_geometry_count += 1


func record_paint_command(_command_physics_tick: int) -> void:
	if is_sealed:
		return
	paint_command_count += 1


func record_paint_command_rejection(command) -> void:
	if is_sealed:
		return
	var command_kind := "unknown"
	if command is RadialPaintMark:
		command_kind = "radial"
	elif command is SurfacePaintSweep:
		command_kind = "sweep"
	paint_command_rejections.append({
		"kind": command_kind,
		"physics_tick": int(command.physics_tick) if command != null else -1,
		"spawn_ordinal": int(command.spawn_ordinal) if command != null else -1,
		"sequence": int(command.sequence) if command != null else -1,
	})
	paint_command_rejection_count += 1


func record_paint_drain(last_drained_tick: int, paint_mask_checksum: int) -> void:
	if is_sealed:
		return
	final_drain_tick = maxi(final_drain_tick, last_drained_tick)
	final_paint_mask_checksum = paint_mask_checksum


func seal(
		final_coverage: float,
		last_drained_tick: int,
		paint_mask_checksum: int
) -> void:
	if is_sealed:
		return
	record_paint_drain(last_drained_tick, paint_mask_checksum)
	coverage_after = maxf(final_coverage, 0.0)
	coverage_gain = maxf(coverage_after - coverage_before, 0.0)
	is_sealed = true


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"shot_number": shot_number,
		"shot_id": shot_id,
		"commanded_aim": {
			"yaw": commanded_yaw,
			"elevation": commanded_elevation,
			"power": commanded_power,
		},
		"contacts": contacts.duplicate(true),
		"mechanism_activations": mechanism_activations.duplicate(true),
		"child_spawns": child_spawns.duplicate(true),
		"settlements": settlements.duplicate(true),
		"first_terrain_contact": _contact_dictionary(first_terrain_contact),
		"first_mechanism_contact": _contact_dictionary(first_mechanism_contact),
		"first_contact": _contact_dictionary(first_contact),
		"mechanism_activation_kinds": Array(mechanism_activation_kinds),
		"spawned_child_count": spawned_child_count,
		"peak_active_projectile_count": peak_active_projectile_count,
		"settlement_reason_counts": settlement_reason_counts.duplicate(true),
		"coverage_before": coverage_before,
		"coverage_after": coverage_after,
		"coverage_gain": coverage_gain,
		"coverage_metric_version": coverage_metric_version,
		"paint_command_count": paint_command_count,
		"paint_command_rejections": paint_command_rejections.duplicate(true),
		"paint_command_rejection_count": paint_command_rejection_count,
		"final_drain_tick": final_drain_tick,
		"final_paint_mask_checksum": final_paint_mask_checksum,
		"invalid_geometry_count": invalid_geometry_count,
		"is_sealed": is_sealed,
	}


func _contact_dictionary(contact: ProjectileContact) -> Dictionary:
	if contact == null:
		return {}
	return {
		"point": contact.world_position,
		"normal": contact.normal,
		"impact_center": contact.impact_center_position,
		"incoming_velocity": contact.incoming_velocity,
		"relative_normal_speed": contact.relative_normal_speed,
		"impulse": contact.impulse,
		"impulse_was_measured": contact.impulse_was_measured,
		"contact_owner_id": String(contact.contact_owner_id),
		"contact_shape_id": String(contact.contact_shape_id),
		"local_shape_index": contact.local_shape_index,
		"collider_shape_index": contact.collider_shape_index,
		"physics_tick": contact.physics_tick,
		"source_event_index": contact.source_event_index,
		"is_first_contact": contact.is_first_contact,
	}
