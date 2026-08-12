class_name DirectReachabilityCertificate
extends Resource

## Serializable proof that one accepted layout is directly reachable on the
## canonical human aim lattice. Serialized state stays primitive; AimTuple
## instances are reconstructed as immutable runtime views.

const CONTRACT_VERSION := StageGenerationContract.CONTRACT_VERSION

@export_storage var serialized_contract_version: int = CONTRACT_VERSION
@export_storage var serialized_stage_id: StringName
@export_storage var serialized_profile_version: int = CONTRACT_VERSION
@export_storage var serialized_terrain_seed: int = -1
@export_storage var serialized_height_checksum: int = 0
@export_storage var serialized_target_checksum: int = 0
@export_storage var serialized_placement_checksum: int = 0
@export_storage var serialized_play_bounds_checksum: int = 0
@export_storage var serialized_reachable_target_checksum: int = 0
@export_storage var serialized_predictor_reachability_checksum: int = 0
@export_storage var serialized_rigidbody_reachability_checksum: int = 0
@export_storage var serialized_witness_angle_tenths := PackedInt32Array()
@export_storage var serialized_witness_powers := PackedInt32Array()
@export_storage var serialized_target_witness_indices := PackedInt32Array()
@export_storage var serialized_minimum_distance_margins := PackedFloat32Array()
@export_storage var serialized_minimum_range_margins := PackedFloat32Array()
@export_storage var serialized_default_witness_index: int = -1
@export_storage var serialized_summit_region_checksum: int = 0
@export_storage var serialized_summit_triangle_ids := PackedInt32Array()
# Summit proof is intentionally independent from the centroid/default target
# witness table. A global summit may be outside the scoreable route mask.
@export_storage var serialized_summit_witness_angle_tenths := PackedInt32Array()
@export_storage var serialized_summit_witness_power: int = -1
# Kept for reads of an early in-memory draft; new certificates leave
# this at -1 and use the dedicated summit tuple above.
@export_storage var serialized_summit_witness_index: int = -1
@export_storage var serialized_summit_predictor_reachability_checksum: int = 0
@export_storage var serialized_summit_rigidbody_reachability_checksum: int = 0
@export_storage var serialized_summit_minimum_height_margin: float = 0.0

var stage_id: StringName:
	get:
		return serialized_stage_id
var profile_version: int:
	get:
		return serialized_profile_version
var terrain_seed: int:
	get:
		return serialized_terrain_seed
var height_checksum: int:
	get:
		return serialized_height_checksum
var target_checksum: int:
	get:
		return serialized_target_checksum
var placement_checksum: int:
	get:
		return serialized_placement_checksum
var play_bounds_checksum: int:
	get:
		return serialized_play_bounds_checksum
var reachable_target_checksum: int:
	get:
		return serialized_reachable_target_checksum
var predictor_reachability_checksum: int:
	get:
		return serialized_predictor_reachability_checksum
var rigidbody_reachability_checksum: int:
	get:
		return serialized_rigidbody_reachability_checksum
var target_witness_indices: PackedInt32Array:
	get:
		return serialized_target_witness_indices.duplicate()
var minimum_distance_margins: PackedFloat32Array:
	get:
		return serialized_minimum_distance_margins.duplicate()
var minimum_range_margins: PackedFloat32Array:
	get:
		return serialized_minimum_range_margins.duplicate()
var default_witness_index: int:
	get:
		return serialized_default_witness_index
var summit_region_checksum: int:
	get:
		return serialized_summit_region_checksum
var summit_triangle_ids: PackedInt32Array:
	get:
		return serialized_summit_triangle_ids.duplicate()
var summit_witness_index: int:
	get:
		return serialized_summit_witness_index
var summit_witness: AimTuple:
	get:
		if serialized_summit_witness_angle_tenths.size() == 2 \
				and serialized_summit_witness_power >= 0:
			return AimTuple.new(
				float(serialized_summit_witness_angle_tenths[0]) / 10.0,
				float(serialized_summit_witness_angle_tenths[1]) / 10.0,
				serialized_summit_witness_power
			)
		if serialized_summit_witness_index >= 0:
			return witness_at(serialized_summit_witness_index)
		return null
var summit_predictor_reachability_checksum: int:
	get:
		return serialized_summit_predictor_reachability_checksum
var summit_rigidbody_reachability_checksum: int:
	get:
		return serialized_summit_rigidbody_reachability_checksum
var summit_minimum_height_margin: float:
	get:
		return serialized_summit_minimum_height_margin
var default_aim: AimTuple:
	get:
		return witness_at(serialized_default_witness_index)
var witnesses: Array[AimTuple]:
	get:
		var result: Array[AimTuple] = []
		for index in range(witness_count()):
			result.append(witness_at(index))
		return result


static func create(
		certificate_stage_id: StringName,
		certificate_profile_version: int,
		certificate_terrain_seed: int,
		certificate_height_checksum: int,
		certificate_target_checksum: int,
		certificate_placement_checksum: int,
		certificate_play_bounds_checksum: int,
		certificate_reachable_target_checksum: int,
		certificate_predictor_reachability_checksum: int,
		certificate_rigidbody_reachability_checksum: int,
		certificate_witness_angle_tenths: PackedInt32Array,
		certificate_witness_powers: PackedInt32Array,
		certificate_target_witness_indices: PackedInt32Array,
		certificate_minimum_distance_margins: PackedFloat32Array,
		certificate_minimum_range_margins: PackedFloat32Array,
	certificate_default_witness_index: int,
	certificate_summit_region_checksum: int = 0,
	certificate_summit_triangle_ids: PackedInt32Array = PackedInt32Array(),
	certificate_summit_witness_index: int = -1,
	certificate_summit_predictor_reachability_checksum: int = 0,
	certificate_summit_rigidbody_reachability_checksum: int = 0,
	certificate_summit_minimum_height_margin: float = 0.0,
	certificate_summit_witness_angle_tenths: PackedInt32Array = PackedInt32Array(),
	certificate_summit_witness_power: int = -1
) -> DirectReachabilityCertificate:
	var certificate := DirectReachabilityCertificate.new()
	certificate.serialized_stage_id = certificate_stage_id
	certificate.serialized_profile_version = certificate_profile_version
	certificate.serialized_terrain_seed = certificate_terrain_seed
	certificate.serialized_height_checksum = certificate_height_checksum
	certificate.serialized_target_checksum = certificate_target_checksum
	certificate.serialized_placement_checksum = certificate_placement_checksum
	certificate.serialized_play_bounds_checksum = certificate_play_bounds_checksum
	certificate.serialized_reachable_target_checksum = certificate_reachable_target_checksum
	certificate.serialized_predictor_reachability_checksum = certificate_predictor_reachability_checksum
	certificate.serialized_rigidbody_reachability_checksum = certificate_rigidbody_reachability_checksum
	certificate.serialized_witness_angle_tenths = certificate_witness_angle_tenths.duplicate()
	certificate.serialized_witness_powers = certificate_witness_powers.duplicate()
	certificate.serialized_target_witness_indices = certificate_target_witness_indices.duplicate()
	certificate.serialized_minimum_distance_margins = certificate_minimum_distance_margins.duplicate()
	certificate.serialized_minimum_range_margins = certificate_minimum_range_margins.duplicate()
	certificate.serialized_default_witness_index = certificate_default_witness_index
	certificate.serialized_summit_region_checksum = certificate_summit_region_checksum
	certificate.serialized_summit_triangle_ids = certificate_summit_triangle_ids.duplicate()
	certificate.serialized_summit_witness_angle_tenths = certificate_summit_witness_angle_tenths.duplicate()
	certificate.serialized_summit_witness_power = certificate_summit_witness_power
	certificate.serialized_summit_witness_index = certificate_summit_witness_index
	certificate.serialized_summit_predictor_reachability_checksum = certificate_summit_predictor_reachability_checksum
	certificate.serialized_summit_rigidbody_reachability_checksum = certificate_summit_rigidbody_reachability_checksum
	certificate.serialized_summit_minimum_height_margin = certificate_summit_minimum_height_margin
	return certificate


func witness_count() -> int:
	return serialized_witness_powers.size()


func witness_at(index: int) -> AimTuple:
	if index < 0 or index >= witness_count() \
			or serialized_witness_angle_tenths.size() != witness_count() * 2:
		return null
	return AimTuple.new(
		float(serialized_witness_angle_tenths[index * 2]) / 10.0,
		float(serialized_witness_angle_tenths[index * 2 + 1]) / 10.0,
		serialized_witness_powers[index]
	)


func witness_angle_tenths_read_only() -> PackedInt32Array:
	return serialized_witness_angle_tenths.duplicate()


func witness_powers_read_only() -> PackedInt32Array:
	return serialized_witness_powers.duplicate()


func is_valid() -> bool:
	if serialized_contract_version != CONTRACT_VERSION \
			or String(serialized_stage_id).is_empty() \
			or serialized_profile_version != CONTRACT_VERSION \
			or serialized_terrain_seed < 0:
		return false
	if serialized_height_checksum == 0 or serialized_target_checksum == 0 \
			or serialized_placement_checksum == 0 or serialized_play_bounds_checksum == 0 \
			or serialized_reachable_target_checksum == 0 \
			or serialized_predictor_reachability_checksum == 0 \
			or serialized_rigidbody_reachability_checksum == 0:
		return false
	var count := witness_count()
	if count <= 0 or serialized_witness_angle_tenths.size() != count * 2 \
			or serialized_minimum_distance_margins.size() != count \
			or serialized_minimum_range_margins.size() != count \
			or serialized_target_witness_indices.is_empty() \
			or serialized_default_witness_index < 0 \
			or serialized_default_witness_index >= count:
		return false
	var summit_fields_present := serialized_summit_region_checksum != 0 \
			or not serialized_summit_triangle_ids.is_empty() \
			or not serialized_summit_witness_angle_tenths.is_empty() \
			or serialized_summit_witness_power >= 0 \
			or serialized_summit_witness_index >= 0 \
			or serialized_summit_predictor_reachability_checksum != 0 \
			or serialized_summit_rigidbody_reachability_checksum != 0
	if summit_fields_present:
		if serialized_summit_region_checksum == 0 \
				or serialized_summit_triangle_ids.is_empty() \
				or serialized_summit_witness_index >= count \
				or serialized_summit_predictor_reachability_checksum == 0 \
				or serialized_summit_rigidbody_reachability_checksum == 0 \
				or not is_finite(serialized_summit_minimum_height_margin) \
				or serialized_summit_minimum_height_margin < 0.0:
			return false
		var summit_aim := summit_witness
		if summit_aim == null or not summit_aim.is_valid():
			return false
		if serialized_summit_witness_angle_tenths.size() > 0 \
				and serialized_summit_witness_angle_tenths.size() != 2:
			return false
	var witness_keys: Dictionary = {}
	var witness_references := PackedInt32Array()
	witness_references.resize(count)
	for index in range(count):
		var witness := witness_at(index)
		if witness == null or not witness.is_valid() \
				or not is_finite(serialized_minimum_distance_margins[index]) \
				or not is_finite(serialized_minimum_range_margins[index]) \
				or serialized_minimum_distance_margins[index] < 0.0 \
				or serialized_minimum_range_margins[index] < 0.0:
			return false
		var key := witness.stable_key()
		if witness_keys.has(key):
			return false
		witness_keys[key] = true
	for witness_index in serialized_target_witness_indices:
		if witness_index < 0 or witness_index >= count:
			return false
		witness_references[witness_index] += 1
	for reference_count in witness_references:
		if reference_count <= 0:
			return false
	return true
