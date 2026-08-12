class_name UphillReboundNode
extends TerrainGlyphMechanism

var _uphill_tangent := Vector3.ZERO


func configure_uphill_tangent(tangent: Vector3) -> void:
	_uphill_tangent = tangent.normalized()
	set_glyph_world_directions(PackedVector3Array([_uphill_tangent]))


func configure_downstream_tangent(tangent: Vector3) -> void:
	# Compatibility decode for generated placements created before the rename.
	configure_uphill_tangent(tangent)


func displayed_uphill_tangent() -> Vector3:
	return _uphill_tangent


func displayed_downstream_tangent() -> Vector3:
	return _uphill_tangent


func _effect_can_activate(_projectile: PaintProjectile, contact: ProjectileContact) -> bool:
	return not _surface_uphill_tangent(contact.normal).is_zero_approx()


func _apply_effect(projectile: PaintProjectile, contact: ProjectileContact) -> bool:
	var desired_velocity := rebound_velocity_for(contact)
	if desired_velocity.is_zero_approx():
		return false
	projectile.queue_desired_velocity(desired_velocity, contact.physics_tick)
	return true


func rebound_velocity_for(contact: ProjectileContact) -> Vector3:
	if contact == null:
		return Vector3.ZERO
	var tangent := _surface_uphill_tangent(contact.normal)
	if tangent.is_zero_approx():
		return Vector3.ZERO
	var desired_speed := clampf(
		maxf(contact.incoming_velocity.length() * data.rebound_speed_multiplier, data.rebound_minimum_speed),
		data.rebound_minimum_speed,
		data.rebound_maximum_speed
	)
	var desired_direction := (tangent + contact.normal * data.rebound_lift_ratio).normalized()
	return desired_direction * desired_speed


func _surface_uphill_tangent(surface_normal: Vector3) -> Vector3:
	var tangent := _uphill_tangent - surface_normal * _uphill_tangent.dot(surface_normal)
	return tangent.normalized()
