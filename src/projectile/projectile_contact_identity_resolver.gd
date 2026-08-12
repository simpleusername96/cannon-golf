class_name ProjectileContactIdentityResolver
extends RefCounted

## Resolves runtime shape indices to the stable gameplay contact identity.
## Missing or duplicated shape metadata is rejected instead of being inferred
## from process-local node or RID values.


static func resolve(collider: Object, collider_shape_index: int) -> Dictionary:
	var collision_object := collider as CollisionObject3D
	if collision_object == null or collider_shape_index < 0:
		return _invalid(&"missing_collision_object")
	var owner_id := StringName(collision_object.get_meta(
		PlayBoundsSpec.CONTACT_OWNER_META,
		&""
	))
	if String(owner_id).is_empty():
		return _invalid(&"missing_contact_owner_id")
	var shape_owner_index := collision_object.shape_find_owner(collider_shape_index)
	if shape_owner_index < 0:
		return _invalid(&"missing_shape_owner")
	var shape_owner := collision_object.shape_owner_get_owner(shape_owner_index)
	if shape_owner == null or not shape_owner.has_meta(PlayBoundsSpec.CONTACT_SHAPE_META):
		return _invalid(&"missing_contact_shape_id")
	var shape_id := StringName(shape_owner.get_meta(PlayBoundsSpec.CONTACT_SHAPE_META, &""))
	if String(shape_id).is_empty():
		return _invalid(&"empty_contact_shape_id")
	var matching_shape_ids := 0
	for candidate_owner_index in collision_object.get_shape_owners():
		var candidate_owner := collision_object.shape_owner_get_owner(candidate_owner_index)
		if candidate_owner == null or not candidate_owner.has_meta(PlayBoundsSpec.CONTACT_SHAPE_META):
			continue
		if StringName(candidate_owner.get_meta(PlayBoundsSpec.CONTACT_SHAPE_META, &"")) == shape_id:
			matching_shape_ids += 1
	if matching_shape_ids != 1:
		return _invalid(&"duplicate_contact_shape_id")
	return {
		"valid": true,
		"owner_id": owner_id,
		"shape_id": shape_id,
	}


static func _invalid(reason: StringName) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
	}
