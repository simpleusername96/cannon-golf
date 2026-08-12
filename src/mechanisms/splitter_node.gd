class_name SplitterNode
extends TerrainGlyphMechanism

var _route_targets := PackedVector3Array()
var _owning_route_downhill_tangent := Vector3.ZERO


func configure_route_targets(targets: PackedVector3Array, downhill_tangent: Vector3) -> void:
	_route_targets = targets.duplicate()
	_owning_route_downhill_tangent = downhill_tangent.normalized()
	var directions := PackedVector3Array()
	for target in _route_targets:
		directions.append((target - global_position).normalized())
	set_glyph_world_directions(directions)


func configured_route_targets() -> PackedVector3Array:
	return _route_targets.duplicate()


func _effect_can_activate(projectile: PaintProjectile, _contact: ProjectileContact) -> bool:
	return projectile.split_generation < data.maximum_split_generation \
			and _route_targets.size() == data.child_count \
			and not _owning_route_downhill_tangent.is_zero_approx() \
			and _projectile_manager.can_replace_resident_with_children(projectile, data.child_count)


func _apply_effect(projectile: PaintProjectile, contact: ProjectileContact) -> bool:
	var incoming_velocity := contact.incoming_velocity
	var speed := maxf(incoming_velocity.length() * data.child_speed_multiplier, data.child_minimum_route_speed)
	var parent_radius := projectile.physical_radius()
	var child_radius := parent_radius * data.child_radius_multiplier
	var fan_axis := contact.normal.cross(_owning_route_downhill_tangent).normalized()
	if fan_axis.is_zero_approx():
		fan_axis = global_basis.x.normalized()
	var normal_offset := parent_radius + child_radius + 0.05
	var lateral_spacing := child_radius * 2.0 + 0.10
	projectile.deactivate(ProjectileSettlementReason.CONSUMED)
	var spawned_children := 0
	for child_index in range(data.child_count):
		var origin := contact.world_position \
				+ contact.normal * normal_offset \
				+ fan_axis * float(child_index - 1) * lateral_spacing
		var target := _route_targets[child_index] + Vector3.UP * data.child_target_lift
		var direction := (target - origin).normalized()
		var child := _projectile_manager.spawn_projectile(
			projectile.projectile_data,
			origin,
			direction * speed,
			projectile.split_generation + 1,
			projectile.shot_id
		)
		if child == null:
			push_error("Accepted Splitter activation failed its pre-admitted resident capacity.")
			return false
		spawned_children += 1
	return spawned_children == data.child_count
