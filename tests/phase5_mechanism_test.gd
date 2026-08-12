extends SceneTree

const PROJECTILE_DATA: ProjectileData = preload("res://resources/projectiles/basic_paintball.tres")
const BURST_DATA: MechanismData = preload("res://resources/mechanisms/burst_node.tres")
const SPLITTER_DATA: MechanismData = preload("res://resources/mechanisms/splitter_node.tres")
const UPHILL_DATA: MechanismData = preload("res://resources/mechanisms/uphill_rebound_node.tres")
const PAINT_SURFACE_TUNING: PaintSurfaceTuning = preload("res://resources/paint/default_paint_surface_tuning.tres")
const TERRAIN_FIXTURE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const BURST_SCENE := preload("res://scenes/mechanisms/burst_node.tscn")
const SPLITTER_SCENE := preload("res://scenes/mechanisms/splitter_node.tscn")
const UPHILL_SCENE := preload("res://scenes/mechanisms/uphill_rebound_node.tscn")

var _failed := false
var _manager: ProjectileManager
var _paint: PaintSystem
var _terrain: TerrainSurface
var _top_body: StaticBody3D


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.physics_ticks_per_second = 60
	var test_root := Node3D.new()
	root.add_child(test_root)
	var layout := TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT)
	_install_target_mask(layout)
	_terrain = TERRAIN_FIXTURE.instantiate() as TerrainSurface
	test_root.add_child(_terrain)
	_terrain.configure(layout)
	_top_body = _terrain.get_node("TerrainTopBody") as StaticBody3D

	_manager = ProjectileManager.new()
	test_root.add_child(_manager)
	_manager.configure_terrain(_terrain)
	_manager.stage_bounds = AABB(Vector3(-24, -12, -24), Vector3(48, 48, 48))
	_paint = PaintSystem.new()
	test_root.add_child(_paint)
	_paint.configure(
		layout.local_bounds, 0.0, null, Color(0.03, 0.38, 1.0), layout,
		PAINT_SURFACE_TUNING
	)
	_paint.configure_top_surface_identity(
		_top_body.get_rid(),
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID,
		0
	)
	_manager.radial_paint_mark_ready.connect(_paint.queue_radial_paint_mark)

	var burst := _add_glyph(BURST_SCENE, BURST_DATA, Vector3(-8, 0, -8)) as BurstNode
	var splitter := _add_glyph(SPLITTER_SCENE, SPLITTER_DATA, Vector3(0, 0, 8)) as SplitterNode
	var split_targets := PackedVector3Array([
		Vector3(-9, 0, -12), Vector3(0, 0, -13), Vector3(9, 0, -12),
	])
	splitter.configure_route_targets(split_targets, Vector3(0, 0, -1))
	var uphill := _add_glyph(UPHILL_SCENE, UPHILL_DATA, Vector3(8, 0, -8)) as UphillReboundNode
	uphill.configure_uphill_tangent(Vector3(1, 0, 0))

	_assert_flat_query_only_contract(burst)
	_assert_flat_query_only_contract(splitter)
	_assert_flat_query_only_contract(uphill)
	_assert_true(splitter.glyph_world_directions().size() == 3, "Splitter glyph must expose its three launch spokes")
	_assert_true(uphill.glyph_world_directions().size() == 1, "Uphill glyph must expose one authoritative arrow")

	var glyphs: Array[TerrainGlyphMechanism] = [burst, splitter, uphill]
	var resolver := TerrainMechanismResolver.new()
	resolver.configure(_terrain, glyphs)
	await _assert_burst_order_and_consumption(resolver, burst)
	await _assert_splitter_routes_and_generation(resolver, splitter)
	await _assert_uphill_reentry_and_velocity(resolver, uphill)

	_manager.cleanup()
	test_root.queue_free()
	print("Phase 4 terrain glyph mechanisms passed")
	quit(1 if _failed else 0)


func _assert_burst_order_and_consumption(
		resolver: TerrainMechanismResolver,
		burst: BurstNode
) -> void:
	var projectile := _spawn_test_projectile(Vector3(-8, 4, -8))
	var contact := _top_contact(projectile, Vector3(-8, 0, -8), 10)
	_assert_true(
		resolver.resolve_after_base_paint(projectile, contact, false).is_empty(),
		"resolver must not activate before ordinary terrain paint is committed"
	)
	_assert_true(_submit_base_impact(projectile, contact), "base impact must be accepted before Burst")
	var order := PackedInt32Array()
	_manager.radial_paint_mark_ready.connect(func(mark: RadialPaintMark) -> void:
		if mark.spawn_ordinal == projectile.spawn_ordinal:
			order.append(mark.kind)
	)
	var activated := resolver.resolve_after_base_paint(projectile, contact, true)
	_assert_true(activated.size() == 1 and activated[0] == burst, "inside valid-top contact must activate Burst once")
	_assert_true(burst.is_spent(), "Burst must spend its one charge")
	_assert_true(projectile.terminal_reason == ProjectileSettlementReason.CONSUMED, "Burst must consume its incoming projectile")
	_assert_true(_manager.finalize_pending_paint_intents() == 2, "ordinary and Burst paint must both remain accepted after consumption")
	_assert_true(
		order == PackedInt32Array([RadialPaintMark.Kind.IMPACT, RadialPaintMark.Kind.BURST]),
		"canonical paint order must remain ordinary impact then Burst"
	)
	_assert_true(
		resolver.resolve_after_base_paint(projectile, contact, true).is_empty(),
		"spent/continuous overlap must not double-activate Burst"
	)
	await process_frame


func _assert_splitter_routes_and_generation(
		resolver: TerrainMechanismResolver,
		splitter: SplitterNode
) -> void:
	var projectile := _spawn_test_projectile(Vector3(0, 4, 8))
	var contact := _top_contact(projectile, Vector3(0, 0, 8), 20, Vector3(0, -28, -4))
	_assert_true(_submit_base_impact(projectile, contact), "Splitter base contact paint must be accepted")
	var activated := resolver.resolve_after_base_paint(projectile, contact, true)
	_assert_true(activated.size() == 1 and activated[0] == splitter, "Splitter valid-top entry must activate")
	var children := _manager.active_projectiles()
	_assert_true(children.size() == 3, "Splitter must replace one parent with exactly three children")
	for child in children:
		_assert_true(child.split_generation == 1, "Splitter children must carry the one allowed generation")
		_assert_true(
			is_equal_approx(child.physical_radius(), PROJECTILE_DATA.radius * SPLITTER_DATA.child_radius_multiplier),
			"split child scale must use the typed multiplier"
		)
	_assert_true(splitter.configured_route_targets().size() == 3, "Splitter effect must use the same three targets shown by its spokes")
	_manager.cleanup()
	await process_frame


func _assert_uphill_reentry_and_velocity(
		resolver: TerrainMechanismResolver,
		uphill: UphillReboundNode
) -> void:
	var activations := {"count": 0}
	uphill.mechanism_activated.connect(func(
			_mechanism: TerrainGlyphMechanism,
			_projectile: PaintProjectile,
			_kind: MechanismData.Kind
	) -> void:
		activations.count += 1
	)
	var projectile := _spawn_test_projectile(Vector3(8, 4, -8))
	var inside := _top_contact(projectile, Vector3(8, 0, -8), 30, Vector3(0, -24, 0))
	var outside := _top_contact(projectile, Vector3(0, 0, 0), 31, Vector3(0, -20, 0))
	var expected := uphill.rebound_velocity_for(inside)
	_assert_true(expected.dot(Vector3.RIGHT) > 0.0 and expected.y > 0.0, "rebound velocity must combine stored uphill tangent and lift")
	_assert_true(resolver.resolve_after_base_paint(projectile, inside, true).size() == 1, "Uphill Rebound must activate on entry")
	_assert_true(resolver.resolve_after_base_paint(projectile, inside, true).is_empty(), "continued overlap must not reactivate")
	resolver.resolve_after_base_paint(projectile, outside, true)
	uphill.cooldown_remaining = 0.0
	var reentry := _top_contact(projectile, Vector3(8, 0, -8), 32, Vector3(0, -20, 0))
	_assert_true(resolver.resolve_after_base_paint(projectile, reentry, true).size() == 1, "leaving and re-entering after cooldown may activate again")
	_assert_true(activations.count == 2, "resolver must emit once per distinct allowed footprint entry")
	_manager.cleanup()
	await process_frame


func _add_glyph(scene: PackedScene, data: MechanismData, position: Vector3) -> TerrainGlyphMechanism:
	var glyph := scene.instantiate() as TerrainGlyphMechanism
	glyph.data = data
	glyph.position = position
	glyph.configure(_manager, _paint, _terrain)
	root.add_child(glyph)
	return glyph


func _assert_flat_query_only_contract(glyph: TerrainGlyphMechanism) -> void:
	_assert_true(_find_physics_body(glyph) == null, "%s must have no projectile PhysicsBody3D" % glyph.name)
	var area := glyph.selection_footprint()
	var shape_node := glyph.selection_query_shape()
	var shape := shape_node.shape as CylinderShape3D
	_assert_true(area != null and area.collision_layer == 8 and area.collision_mask == 0, "%s selection must remain query-only" % glyph.name)
	_assert_true(shape != null and is_equal_approx(shape.radius, glyph.data.glyph_radius), "%s selection radius must come from typed glyph_radius" % glyph.name)
	var visual := glyph.get_node("GlyphVisual") as MeshInstance3D
	_assert_true(visual != null and visual.mesh != null, "%s must build a flat circular visual" % glyph.name)
	if visual != null and visual.mesh != null:
		var aabb := visual.mesh.get_aabb()
		_assert_true(aabb.size.x >= glyph.data.glyph_radius * 1.9 and aabb.size.z >= glyph.data.glyph_radius * 1.9, "%s visible ring must reach the typed footprint" % glyph.name)


func _find_physics_body(node: Node) -> PhysicsBody3D:
	for child in node.get_children():
		if child is PhysicsBody3D:
			return child
		var nested := _find_physics_body(child)
		if nested != null:
			return nested
	return null


func _spawn_test_projectile(origin: Vector3) -> PaintProjectile:
	var projectile := _manager.spawn_projectile(PROJECTILE_DATA, origin, Vector3.ZERO)
	_assert_true(projectile != null, "mechanism fixture must admit a root projectile")
	return projectile


func _top_contact(
		projectile: PaintProjectile,
		world_point: Vector3,
		tick: int,
		incoming_velocity: Vector3 = Vector3(0, -24, 0)
) -> ProjectileContact:
	var normal := _terrain.world_surface_normal(Vector2(world_point.x, world_point.z))
	var surface := _terrain.world_surface_point(Vector2(world_point.x, world_point.z))
	var contact := ProjectileContact.new(
		surface,
		normal,
		surface + normal * projectile.physical_radius(),
		0.0,
		incoming_velocity,
		absf(incoming_velocity.dot(normal)),
		Vector3.ZERO,
		_top_body,
		0,
		0,
		tick,
		true,
		true,
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID,
		_top_body.get_rid()
	)
	contact.assign_source_event_index(0)
	return contact


func _submit_base_impact(projectile: PaintProjectile, contact: ProjectileContact) -> bool:
	return _manager.submit_radial_paint_intent(RadialPaintMark.new(
		contact.physics_tick,
		projectile.spawn_ordinal,
		contact.source_event_index,
		-1,
		contact.world_position,
		contact.normal,
		PROJECTILE_DATA.impact_paint_radius,
		contact.collider_rid,
		contact.contact_owner_id,
		contact.contact_shape_id,
		contact.collider_shape_index,
		RadialPaintMark.Kind.IMPACT,
		projectile.shot_id
	))


func _install_target_mask(layout: GeneratedStageLayout) -> void:
	var target_mask := PackedByteArray()
	target_mask.resize(PaintSystem.MASK_SIZE * PaintSystem.MASK_SIZE)
	target_mask.fill(255)
	_assert_true(
		TerrainTestFixtureFactory.install_target_mask_with_coverage(layout, target_mask),
		"mechanism fixture target mask must install"
	)
	layout.checksum = 0x12345678
	layout.generated_default_aim = AimTuple.new(0.0, 38.0, 68)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Terrain glyph mechanism check failed: %s" % message)
