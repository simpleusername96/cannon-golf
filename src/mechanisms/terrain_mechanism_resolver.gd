class_name TerrainMechanismResolver
extends RefCounted

signal mechanism_resolved(
	mechanism: TerrainGlyphMechanism,
	projectile: PaintProjectile,
	contact: ProjectileContact
)

var _terrain_surface: TerrainSurface
var _glyphs: Array[TerrainGlyphMechanism] = []
var _inside_glyphs_by_projectile: Dictionary = {}


func configure(
		terrain_surface: TerrainSurface,
		glyphs: Array[TerrainGlyphMechanism] = []
) -> void:
	assert(terrain_surface != null, "TerrainMechanismResolver requires TerrainSurface.")
	_terrain_surface = terrain_surface
	_glyphs.clear()
	for glyph in glyphs:
		register_glyph(glyph)
	_inside_glyphs_by_projectile.clear()


func register_glyph(glyph: TerrainGlyphMechanism) -> void:
	assert(glyph != null, "Cannot register a null terrain glyph.")
	if _glyphs.has(glyph):
		return
	_glyphs.append(glyph)
	glyph.configure_surface(_terrain_surface)
	_glyphs.sort_custom(_glyph_less)


func unregister_glyph(glyph: TerrainGlyphMechanism) -> void:
	_glyphs.erase(glyph)
	for projectile_id in _inside_glyphs_by_projectile.keys():
		var inside: Dictionary = _inside_glyphs_by_projectile[projectile_id]
		inside.erase(glyph.get_instance_id())
		_inside_glyphs_by_projectile[projectile_id] = inside


## The caller must invoke this only after the contact's ordinary terrain paint
## is already accepted or known to be covered by the current paint interval.
## That explicit boolean prevents Burst from consuming a ball before base paint.
func resolve_after_base_paint(
		projectile: PaintProjectile,
		contact: ProjectileContact,
		base_paint_committed: bool
) -> Array[TerrainGlyphMechanism]:
	var activated: Array[TerrainGlyphMechanism] = []
	if not base_paint_committed or not _is_authoritative_valid_top(contact):
		return activated
	if projectile == null or not is_instance_valid(projectile):
		return activated
	_prune_invalid_glyphs()
	var projectile_id := projectile.get_instance_id()
	var previous_inside: Dictionary = _inside_glyphs_by_projectile.get(projectile_id, {})
	var current_inside: Dictionary = {}
	for glyph in _glyphs:
		if not glyph.contains_world_contact(contact.world_position):
			continue
		var glyph_id := glyph.get_instance_id()
		current_inside[glyph_id] = true
		if previous_inside.has(glyph_id):
			continue
		if glyph.activate_from_valid_top(projectile, contact):
			activated.append(glyph)
			mechanism_resolved.emit(glyph, projectile, contact)
			if not is_instance_valid(projectile) or not String(projectile.terminal_reason).is_empty():
				break
	_inside_glyphs_by_projectile[projectile_id] = current_inside
	return activated


func clear_projectile(projectile: PaintProjectile) -> void:
	if projectile != null:
		_inside_glyphs_by_projectile.erase(projectile.get_instance_id())


func clear_all() -> void:
	_inside_glyphs_by_projectile.clear()


func registered_glyphs() -> Array[TerrainGlyphMechanism]:
	_prune_invalid_glyphs()
	return _glyphs.duplicate()


func _is_authoritative_valid_top(contact: ProjectileContact) -> bool:
	if _terrain_surface == null or contact == null:
		return false
	if contact.contact_owner_id != TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			or contact.contact_shape_id != TerrainSurface.TOP_SHAPE_ID:
		return false
	if not _terrain_surface.is_top_collider(contact.collider):
		return false
	return _terrain_surface.classify_top_physics_hit(
		contact.world_position,
		contact.contact_shape_id,
		contact.collider_shape_index
	) != null


func _prune_invalid_glyphs() -> void:
	for index in range(_glyphs.size() - 1, -1, -1):
		if not is_instance_valid(_glyphs[index]):
			_glyphs.remove_at(index)


func _glyph_less(a: TerrainGlyphMechanism, b: TerrainGlyphMechanism) -> bool:
	var a_kind := int(a.data.canonical_kind())
	var b_kind := int(b.data.canonical_kind())
	if a_kind != b_kind:
		return a_kind < b_kind
	if not a.global_position.is_equal_approx(b.global_position):
		if not is_equal_approx(a.global_position.z, b.global_position.z):
			return a.global_position.z < b.global_position.z
		return a.global_position.x < b.global_position.x
	return a.get_instance_id() < b.get_instance_id()
