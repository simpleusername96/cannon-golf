class_name BurstNode
extends TerrainGlyphMechanism


func _apply_effect(projectile: PaintProjectile, contact: ProjectileContact) -> bool:
	var world_xz := Vector2(global_position.x, global_position.z)
	var top_identity := _paint_system.authoritative_top_surface_identity()
	var intent := RadialPaintMark.new(
		contact.physics_tick,
		projectile.spawn_ordinal,
		contact.source_event_index,
		-1,
		_paint_system.terrain_surface_position(world_xz),
		_paint_system.terrain_surface_normal(world_xz),
		data.burst_radius,
		top_identity.collider_rid,
		top_identity.contact_owner_id,
		top_identity.contact_shape_id,
		int(top_identity.collider_shape_index),
		RadialPaintMark.Kind.BURST,
		projectile.shot_id
	)
	if not _projectile_manager.submit_radial_paint_intent(intent):
		push_error("Burst rejected a radial paint intent without stable contact ordering.")
		return false
	# TerrainMechanismResolver calls this only after ordinary contact paint has
	# been accepted. The queued Burst paint therefore survives this consumption.
	projectile.deactivate(ProjectileSettlementReason.CONSUMED)
	return true
