class_name TerrainGlyphMechanism
extends Node3D

signal mechanism_activated(
	mechanism: TerrainGlyphMechanism,
	projectile: PaintProjectile,
	kind: MechanismData.Kind
)
signal mechanism_selected(mechanism: TerrainGlyphMechanism)

const VISUAL_SURFACE_OFFSET := 0.045
const ICON_SURFACE_OFFSET := 0.018
const RING_SEGMENTS := 40
const BURST_MATERIAL := preload("res://resources/mechanisms/burst_glyph_material.tres")
const SPLITTER_MATERIAL := preload("res://resources/mechanisms/splitter_glyph_material.tres")
const UPHILL_MATERIAL := preload("res://resources/mechanisms/uphill_rebound_glyph_material.tres")

@export var data: MechanismData

var remaining_charges: int = 0
var cooldown_remaining: float = 0.0
var _projectile_manager: ProjectileManager
var _paint_system: PaintSystem
var _terrain_surface: TerrainSurface
var _visual_mesh: MeshInstance3D
var _selection_area: Area3D
var _selection_shape: CollisionShape3D
var _label: Label3D
var _glyph_world_directions := PackedVector3Array()
var _last_activation_tick_by_projectile: Dictionary = {}


func _ready() -> void:
	assert(data != null and data.is_valid(), "%s requires valid MechanismData." % name)
	_build_runtime_nodes()
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.settings_changed.connect(_on_settings_changed)
	reset_state()


func configure(
		projectile_manager: ProjectileManager,
		paint_system: PaintSystem,
		terrain_surface: TerrainSurface = null
) -> void:
	assert(projectile_manager != null and paint_system != null, "Glyph mechanisms require projectile and paint owners.")
	_projectile_manager = projectile_manager
	_paint_system = paint_system
	_terrain_surface = terrain_surface
	if is_node_ready():
		_rebuild_glyph_mesh()


func configure_surface(terrain_surface: TerrainSurface) -> void:
	_terrain_surface = terrain_surface
	if is_node_ready():
		_rebuild_glyph_mesh()


func glyph_radius() -> float:
	return data.glyph_radius if data != null else 0.0


func contains_world_contact(world_position: Vector3) -> bool:
	if data == null:
		return false
	var local := to_local(world_position)
	return Vector2(local.x, local.z).length_squared() <= data.glyph_radius * data.glyph_radius


func selection_footprint() -> Area3D:
	return _selection_area


func selection_query_shape() -> CollisionShape3D:
	return _selection_shape


func set_glyph_world_directions(directions: PackedVector3Array) -> void:
	_glyph_world_directions = directions.duplicate()
	if is_node_ready():
		_rebuild_glyph_mesh()


func glyph_world_directions() -> PackedVector3Array:
	return _glyph_world_directions.duplicate()


func activate_from_valid_top(projectile: PaintProjectile, contact: ProjectileContact) -> bool:
	if not can_activate_from_valid_top(projectile, contact):
		return false
	if not _apply_effect(projectile, contact):
		return false
	_last_activation_tick_by_projectile[projectile.get_instance_id()] = contact.physics_tick
	if data.has_finite_charges():
		remaining_charges -= 1
	cooldown_remaining = data.cooldown_seconds
	_update_visual_state()
	mechanism_activated.emit(self, projectile, data.canonical_kind())
	return true


func can_activate_from_valid_top(projectile: PaintProjectile, contact: ProjectileContact) -> bool:
	if projectile == null or not is_instance_valid(projectile) or contact == null:
		return false
	if _projectile_manager == null or _paint_system == null:
		return false
	if contact.contact_owner_id != TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
		return false
	if not contains_world_contact(contact.world_position):
		return false
	if cooldown_remaining > 0.0:
		return false
	if data.has_finite_charges() and remaining_charges <= 0:
		return false
	var projectile_id := projectile.get_instance_id()
	if int(_last_activation_tick_by_projectile.get(projectile_id, -1)) == contact.physics_tick:
		return false
	return _effect_can_activate(projectile, contact)


func struck(_projectile: PaintProjectile, _contact: ProjectileContact) -> bool:
	# The legacy direct path cannot prove that ordinary terrain paint committed.
	# It intentionally fails closed until its callers use TerrainMechanismResolver.
	return false


func can_strike(_projectile: PaintProjectile, _contact: ProjectileContact) -> bool:
	return false


func reset_state() -> void:
	if data == null:
		return
	remaining_charges = data.maximum_charges
	cooldown_remaining = 0.0
	_last_activation_tick_by_projectile.clear()
	_update_visual_state()


func is_spent() -> bool:
	return data != null and data.has_finite_charges() and remaining_charges <= 0


func state_snapshot() -> Dictionary:
	return {
		"kind": MechanismData.Kind.keys()[int(data.canonical_kind())],
		"display_name_key": data.display_name_key,
		"description_key": data.description_key,
		"position": global_position,
		"glyph_radius": glyph_radius(),
		"remaining_charges": remaining_charges,
		"cooldown": cooldown_remaining,
		"spent": is_spent(),
	}


func set_label_visible(value: bool) -> void:
	if _label != null:
		_label.visible = value


func selection_body() -> CollisionObject3D:
	return _selection_area


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func _effect_can_activate(_projectile: PaintProjectile, _contact: ProjectileContact) -> bool:
	return true


func _apply_effect(_projectile: PaintProjectile, _contact: ProjectileContact) -> bool:
	push_error("TerrainGlyphMechanism effect must be implemented by %s." % get_script().resource_path)
	return false


func _build_runtime_nodes() -> void:
	_visual_mesh = MeshInstance3D.new()
	_visual_mesh.name = "GlyphVisual"
	_visual_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual_mesh)

	_selection_area = Area3D.new()
	_selection_area.name = "SelectionArea"
	_selection_area.collision_layer = 8
	_selection_area.collision_mask = 0
	_selection_area.monitoring = false
	_selection_area.monitorable = false
	_selection_area.input_ray_pickable = true
	_selection_area.input_event.connect(_on_selection_input_event)
	add_child(_selection_area)

	_selection_shape = CollisionShape3D.new()
	_selection_shape.name = "GlyphFootprint"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = data.glyph_radius
	cylinder.height = 0.24
	_selection_shape.shape = cylinder
	_selection_shape.position = Vector3.UP * 0.08
	_selection_area.add_child(_selection_shape)

	_build_label()
	_rebuild_glyph_mesh()


func _rebuild_glyph_mesh() -> void:
	if _visual_mesh == null or data == null:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_ring(surface, data.glyph_radius * 0.78, data.glyph_radius, VISUAL_SURFACE_OFFSET)
	match data.canonical_kind():
		MechanismData.Kind.BURST:
			_append_ring(surface, data.glyph_radius * 0.13, data.glyph_radius * 0.24, VISUAL_SURFACE_OFFSET + ICON_SURFACE_OFFSET)
			for index in range(8):
				var direction := Vector2.from_angle(TAU * float(index) / 8.0)
				_append_ribbon(surface, direction * data.glyph_radius * 0.30, direction * data.glyph_radius * 0.66, data.glyph_radius * 0.075)
		MechanismData.Kind.SPLITTER:
			var directions := _resolved_icon_directions([
				Vector2.from_angle(-PI * 0.72),
				Vector2.from_angle(-PI * 0.50),
				Vector2.from_angle(-PI * 0.28),
			])
			for direction in directions:
				_append_arrow(surface, direction, data.glyph_radius * 0.18, data.glyph_radius * 0.68)
		MechanismData.Kind.UPHILL_REBOUND:
			var directions := _resolved_icon_directions([Vector2(0.0, -1.0)])
			_append_arrow(surface, directions[0], data.glyph_radius * 0.18, data.glyph_radius * 0.70)
	_visual_mesh.mesh = surface.commit()
	_visual_mesh.material_override = _glyph_material()
	_update_visual_state()


func _append_ring(surface: SurfaceTool, inner_radius: float, outer_radius: float, offset: float) -> void:
	for index in range(RING_SEGMENTS):
		var next := (index + 1) % RING_SEGMENTS
		var angle_a := TAU * float(index) / float(RING_SEGMENTS)
		var angle_b := TAU * float(next) / float(RING_SEGMENTS)
		var inner_a := _surface_local_point(Vector2.from_angle(angle_a) * inner_radius, offset)
		var outer_a := _surface_local_point(Vector2.from_angle(angle_a) * outer_radius, offset)
		var inner_b := _surface_local_point(Vector2.from_angle(angle_b) * inner_radius, offset)
		var outer_b := _surface_local_point(Vector2.from_angle(angle_b) * outer_radius, offset)
		_append_quad(surface, inner_a, outer_a, outer_b, inner_b)


func _append_ribbon(surface: SurfaceTool, start: Vector2, finish: Vector2, width: float) -> void:
	var direction := (finish - start).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	var offset := VISUAL_SURFACE_OFFSET + ICON_SURFACE_OFFSET
	_append_quad(
		surface,
		_surface_local_point(start - side, offset),
		_surface_local_point(finish - side, offset),
		_surface_local_point(finish + side, offset),
		_surface_local_point(start + side, offset)
	)


func _append_arrow(surface: SurfaceTool, direction: Vector2, start_radius: float, finish_radius: float) -> void:
	var normalized := direction.normalized()
	var start := normalized * start_radius
	var shaft_end := normalized * finish_radius * 0.72
	var tip := normalized * finish_radius
	var side := Vector2(-normalized.y, normalized.x)
	_append_ribbon(surface, start, shaft_end, data.glyph_radius * 0.09)
	var offset := VISUAL_SURFACE_OFFSET + ICON_SURFACE_OFFSET
	_append_triangle(
		surface,
		_surface_local_point(tip, offset),
		_surface_local_point(shaft_end + side * data.glyph_radius * 0.16, offset),
		_surface_local_point(shaft_end - side * data.glyph_radius * 0.16, offset)
	)


func _append_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_append_triangle(surface, a, b, c)
	_append_triangle(surface, a, c, d)


func _append_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	elif normal.dot(Vector3.UP) < 0.0:
		normal = -normal
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(point)


func _surface_local_point(local_xz: Vector2, offset: float) -> Vector3:
	var planar := Vector3(local_xz.x, 0.0, local_xz.y)
	if _terrain_surface == null or not is_inside_tree():
		return planar + Vector3.UP * offset
	var world_guess := to_global(planar)
	var world_xz := Vector2(world_guess.x, world_guess.z)
	if not _terrain_surface.contains_world_xz(world_xz):
		return planar + Vector3.UP * offset
	var world_point := _terrain_surface.world_surface_point(world_xz)
	var world_normal := _terrain_surface.world_surface_normal(world_xz)
	return to_local(world_point + world_normal * offset)


func _resolved_icon_directions(fallback: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for world_direction in _glyph_world_directions:
		var local_direction := global_basis.inverse() * world_direction
		var xz := Vector2(local_direction.x, local_direction.z).normalized()
		if not xz.is_zero_approx():
			result.append(xz)
	if result.size() != fallback.size():
		return fallback
	return result


func _glyph_material() -> Material:
	match data.canonical_kind():
		MechanismData.Kind.BURST:
			return BURST_MATERIAL
		MechanismData.Kind.SPLITTER:
			return SPLITTER_MATERIAL
		_:
			return UPHILL_MATERIAL


func _update_visual_state() -> void:
	if _visual_mesh != null:
		_visual_mesh.transparency = 0.55 if is_spent() else 0.0


func _on_settings_changed(_settings: Dictionary) -> void:
	if _label != null:
		_label.text = tr(String(data.display_name_key))


func _on_selection_input_event(
		_camera: Node,
		event: InputEvent,
		_event_position: Vector3,
		_normal: Vector3,
		_shape_index: int
) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		mechanism_selected.emit(self)


func _build_label() -> void:
	_label = Label3D.new()
	_label.name = "BriefingLabel"
	_label.text = tr(String(data.display_name_key))
	_label.font_size = 30
	_label.outline_size = 6
	_label.modulate = Color(0.95, 0.97, 1.0, 1.0)
	_label.outline_modulate = Color(0.04, 0.07, 0.12, 0.9)
	_label.position = Vector3.UP * 1.2
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.001
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)
