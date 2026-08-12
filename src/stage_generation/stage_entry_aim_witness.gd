class_name StageEntryAimWitness
extends RefCounted

## Immutable bounded first-hit evidence baked with an accepted layout.
const TERRAIN_FACET_PARITY_TOLERANCE := 2.10

var aim: AimTuple
var predicted_identity: TrajectoryHitIdentity
var physical_identity: TrajectoryHitIdentity
var predicted_local_impact := Vector3.ZERO
var physical_local_impact := Vector3.ZERO
var target_local_point := Vector3.ZERO
var target_pixel_index := -1
var summit_region_checksum := 0
var distance_margin := 0.0
var range_margin := 0.0
var height_margin := 0.0

func is_valid(is_summit: bool = false) -> bool:
	if aim == null or not aim.is_valid() or predicted_identity == null or physical_identity == null \
			or not predicted_identity.is_valid() or not physical_identity.is_valid() \
			or not predicted_local_impact.is_finite() or not physical_local_impact.is_finite() \
			or not target_local_point.is_finite() or not is_finite(distance_margin) \
			or not is_finite(range_margin) or not is_finite(height_margin) \
			or distance_margin < 0.0 or range_margin < 0.0 or height_margin < 0.0:
		return false
	if not contacts_are_compatible():
		return false
	return summit_region_checksum != 0 and target_pixel_index == -1 if is_summit \
		else target_pixel_index >= 0 and summit_region_checksum == 0


func contacts_are_compatible() -> bool:
	if predicted_identity.has_same_surface_address(physical_identity):
		return true
	# A large rigid sphere can cross a faceted edge between fixed ticks. Both
	# results still identify the same canonical top body, and the tight endpoint
	# distance prevents an unrelated triangle from satisfying the witness.
	return predicted_identity.contact_owner_id \
				== TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			and physical_identity.contact_owner_id \
				== TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			and predicted_identity.contact_shape_id == physical_identity.contact_shape_id \
			and predicted_identity.body_shape_index == physical_identity.body_shape_index \
			and predicted_local_impact.distance_to(physical_local_impact) \
				<= TERRAIN_FACET_PARITY_TOLERANCE


## Copies the mutable wrapper while sharing only the immutable value objects.
## Runtime scenes must not be able to alter the repository's accepted witness.
func copy() -> StageEntryAimWitness:
	var result := StageEntryAimWitness.new()
	result.aim = aim
	result.predicted_identity = predicted_identity
	result.physical_identity = physical_identity
	result.predicted_local_impact = predicted_local_impact
	result.physical_local_impact = physical_local_impact
	result.target_local_point = target_local_point
	result.target_pixel_index = target_pixel_index
	result.summit_region_checksum = summit_region_checksum
	result.distance_margin = distance_margin
	result.range_margin = range_margin
	result.height_margin = height_margin
	return result
