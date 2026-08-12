extends SceneTree

const FIXTURE_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const PROJECTILE_DATA := preload("res://resources/projectiles/basic_paintball.tres")
const SURFACE_TUNING := preload("res://resources/paint/default_paint_surface_tuning.tres")
const NORMAL_TERRAIN_PHYSICS_MATERIAL := preload(
	"res://resources/physics/normal_terrain_physics_material.tres"
)

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.physics_ticks_per_second = 60
	_assert_production_tuning()
	await _assert_manager_canonical_ordering()
	await _assert_bounded_rebound_and_recovery(false)
	await _assert_bounded_rebound_and_recovery(true)
	await _assert_gap_proof()
	await _assert_persistent_rest_and_wake()
	await _assert_embedding_recovery()
	await _assert_invalid_geometry_is_explicit()
	await _assert_never_contacted_timeout()
	if not _failed:
		print("Projectile lifecycle checks passed: contact recovery, persistent rest/wake, truthful miss cleanup, continuous paint, and canonical intent finalization.")
	quit(1 if _failed else 0)


func _assert_production_tuning() -> void:
	_assert_true(PROJECTILE_DATA.radius > 0.0, "production projectile must have a physical radius")
	_assert_true(PROJECTILE_DATA.mass > 0.0, "production projectile must have positive mass")
	_assert_true(
		is_zero_approx(NORMAL_TERRAIN_PHYSICS_MATERIAL.bounce) \
				and is_equal_approx(NORMAL_TERRAIN_PHYSICS_MATERIAL.friction, 1.0),
		"normal terrain must stay restitution-neutral so ProjectileData alone owns rebound tuning"
	)
	_assert_true(
		PROJECTILE_DATA.paint_footprint_radius >= PROJECTILE_DATA.radius,
		"continuous contact paint must remain at least as wide as the physical ball"
	)
	_assert_true(
		PROJECTILE_DATA.impact_paint_radius >= PROJECTILE_DATA.paint_footprint_radius,
		"the first-impact mark must not be narrower than continuous contact paint"
	)


func _assert_manager_canonical_ordering() -> void:
	var fixture := await _build_fixture(false)
	var host: Node3D = fixture.host
	var surface: TerrainSurface = fixture.surface
	var manager: ProjectileManager = fixture.manager
	var body := surface.get_node("TerrainTopBody") as StaticBody3D
	var point := surface.world_surface_point(Vector2.ZERO)
	var tick := Engine.get_physics_frames()
	var emitted: Array[RefCounted] = []
	manager.radial_paint_mark_ready.connect(func(command: RadialPaintMark) -> void: emitted.append(command))
	manager.surface_paint_sweep_ready.connect(func(command: SurfacePaintSweep) -> void: emitted.append(command))
	var sweep := SurfacePaintSweep.new(
		tick, 0, 0, -1, point, point + Vector3.RIGHT, Vector3.UP, Vector3.UP,
		PROJECTILE_DATA.paint_footprint_radius, body.get_rid(), TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID, 0, false
	)
	var later_ordinal_impact := RadialPaintMark.new(
		tick, 1, 0, -1, point, Vector3.UP, PROJECTILE_DATA.impact_paint_radius, body.get_rid(),
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID, TerrainSurface.TOP_SHAPE_ID,
		0, RadialPaintMark.Kind.IMPACT
	)
	var impact := RadialPaintMark.new(
		tick, 0, 0, -1, point, Vector3.UP, PROJECTILE_DATA.impact_paint_radius, body.get_rid(),
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID, TerrainSurface.TOP_SHAPE_ID,
		0, RadialPaintMark.Kind.IMPACT
	)
	_assert_true(manager.submit_surface_paint_intent(sweep), "valid sweep intent must queue")
	_assert_true(manager.submit_radial_paint_intent(later_ordinal_impact), "second ordinal intent must queue")
	_assert_true(manager.submit_radial_paint_intent(impact), "valid impact intent must queue")
	_assert_true(manager.finalize_pending_paint_intents() == 3, "explicit finalization must publish every accepted intent")
	_assert_true(manager.finalize_pending_paint_intents() == 0, "explicit finalization must be idempotent")
	_assert_true(emitted.size() == 3, "manager must canonicalize all three typed intents")
	if emitted.size() == 3:
		var emitted_impact := emitted[0] as RadialPaintMark
		var emitted_sweep := emitted[1] as SurfacePaintSweep
		var emitted_later := emitted[2] as RadialPaintMark
		_assert_true(emitted_impact != null and emitted_impact.kind == RadialPaintMark.Kind.IMPACT, "IMPACT must sort before SWEEP")
		_assert_true(emitted_sweep != null, "SWEEP must sort after IMPACT")
		_assert_true(emitted_later != null and emitted_later.spawn_ordinal == 1, "higher spawn ordinal must sort after ordinal zero")
		_assert_true(
			emitted_impact != null and emitted_sweep != null \
					and emitted_later != null \
					and emitted_impact.sequence == 0 and emitted_sweep.sequence == 1 \
					and emitted_later.sequence == 0,
			"sequence must increase independently per spawn ordinal"
		)
	_assert_true(manager.pending_intent_count() == 0, "completed-tick intent buffer must drain")
	await _dispose_fixture(host, manager, surface)


func _assert_bounded_rebound_and_recovery(on_ramp: bool) -> void:
	var fixture := await _build_fixture(on_ramp)
	var host: Node3D = fixture.host
	var surface: TerrainSurface = fixture.surface
	var manager: ProjectileManager = fixture.manager
	var top_body := surface.get_node("TerrainTopBody") as StaticBody3D
	var shell_body := surface.get_node("TerrainShellBody") as StaticBody3D
	_assert_true(
		top_body.physics_material_override == NORMAL_TERRAIN_PHYSICS_MATERIAL \
				and shell_body.physics_material_override == NORMAL_TERRAIN_PHYSICS_MATERIAL,
		"terrain top and shell must use the shared normal-terrain PhysicsMaterial"
	)
	var commands: Array[RefCounted] = []
	manager.radial_paint_mark_ready.connect(func(command: RadialPaintMark) -> void: commands.append(command))
	manager.surface_paint_sweep_ready.connect(func(command: SurfacePaintSweep) -> void: commands.append(command))
	var observed := {"first_contact": null}
	manager.projectile_contact_reported.connect(func(_projectile: PaintProjectile, contact: ProjectileContact) -> void:
		if observed.first_contact == null and contact.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
			observed.first_contact = contact
	)
	var local_start := Vector2(0.0, 0.0)
	var surface_y := surface.world_surface_point(local_start).y
	var projectile := manager.spawn_projectile(
		PROJECTILE_DATA,
		Vector3(local_start.x, surface_y + 6.0, local_start.y),
		Vector3(5.0, -30.0, 0.0)
	)
	_assert_true(projectile != null, "bounded-rebound fixture must spawn")
	var contact_budget := 120
	while observed.first_contact == null and contact_budget > 0:
		await physics_frame
		contact_budget -= 1
	var first_contact := observed.first_contact as ProjectileContact
	_assert_true(first_contact != null, "bounded-rebound fixture must contact target top")
	if first_contact == null:
		await _dispose_fixture(host, manager, surface)
		return
	var maximum_outgoing_normal_speed := 0.0
	var maximum_clearance := 0.0
	var recovered_with_sweep := false
	for _tick in range(45):
		await physics_frame
		if not is_instance_valid(projectile):
			break
		var world_xz := Vector2(projectile.global_position.x, projectile.global_position.z)
		var normal := surface.world_surface_normal(world_xz)
		maximum_outgoing_normal_speed = maxf(
			maximum_outgoing_normal_speed,
			projectile.linear_velocity.dot(normal)
		)
		maximum_clearance = maxf(
			maximum_clearance,
			projectile.global_position.y - surface.world_surface_point(world_xz).y \
					- projectile.physical_radius()
		)
		for command in commands:
			if command is SurfacePaintSweep:
				recovered_with_sweep = true
				break
		if recovered_with_sweep:
			break
	_assert_true(
		maximum_outgoing_normal_speed <= first_contact.relative_normal_speed * 0.10 + 0.12,
		"first rebound normal speed must stay at or below 10%%; incoming=%.3f outgoing=%.3f" \
				% [first_contact.relative_normal_speed, maximum_outgoing_normal_speed]
	)
	_assert_true(maximum_clearance <= 1.5, "normal terrain must not create a second arc above 1.5 m")
	_assert_true(recovered_with_sweep, "%s must recover sustained target contact within 0.75 s" % ("30-degree ramp" if on_ramp else "flat"))
	_assert_true(not commands.is_empty() and commands[0] is RadialPaintMark, "first target command must be an impact mark")
	if not commands.is_empty() and commands[0] is RadialPaintMark:
		var impact := commands[0] as RadialPaintMark
		_assert_true(impact.kind == RadialPaintMark.Kind.IMPACT and impact.sequence == 0, "first impact must receive sequence zero")
		_assert_true(impact.spawn_ordinal == 0 and impact.center.distance_to(first_contact.world_position) <= 0.001, "impact must use ordinal zero and the measured contact point")
	if is_instance_valid(projectile):
		projectile.deactivate(&"bounded_rebound_complete")
	await _dispose_fixture(host, manager, surface)


func _assert_gap_proof() -> void:
	var fixture := await _build_fixture(false)
	var host: Node3D = fixture.host
	var surface: TerrainSurface = fixture.surface
	var manager: ProjectileManager = fixture.manager
	var top_body := surface.get_node("TerrainTopBody") as StaticBody3D
	var from_point := surface.world_surface_point(Vector2(-2.0, 0.0))
	var to_point := surface.world_surface_point(Vector2(2.0, 0.0))
	var from_contact := _fixture_contact(top_body, from_point, 10)
	var to_contact := _fixture_contact(top_body, to_point, 13)
	var space_state := host.get_world_3d().direct_space_state
	_assert_true(
		SurfaceContactGapValidator.can_bridge(
			surface, SURFACE_TUNING, from_contact, to_contact, 2, space_state
		),
		"a same-top two-tick surface chord must pass the complete bridge proof"
	)
	var airborne_contact := _fixture_contact(top_body, to_point + Vector3.UP, 13)
	_assert_true(
		not SurfaceContactGapValidator.can_bridge(
			surface, SURFACE_TUNING, from_contact, airborne_contact, 2, space_state
		),
		"a chord more than 0.4 m above the reconstructed surface must stay blank"
	)
	var long_gap_contact := _fixture_contact(top_body, to_point, 14)
	_assert_true(
		not SurfaceContactGapValidator.can_bridge(
			surface, SURFACE_TUNING, from_contact, long_gap_contact, 3, space_state
		),
		"a three-tick missing-contact gap must stay blank"
	)
	await _dispose_fixture(host, manager, surface)


func _assert_persistent_rest_and_wake() -> void:
	var fixture := await _build_fixture(false)
	var host: Node3D = fixture.host
	var surface: TerrainSurface = fixture.surface
	var manager: ProjectileManager = fixture.manager
	var commands: Array[RefCounted] = []
	var stop_reasons: Array[StringName] = []
	manager.radial_paint_mark_ready.connect(func(command: RadialPaintMark) -> void: commands.append(command))
	manager.surface_paint_sweep_ready.connect(func(command: SurfacePaintSweep) -> void: commands.append(command))
	manager.projectile_stopped.connect(func(_projectile: PaintProjectile, reason: StringName) -> void: stop_reasons.append(reason))
	var surface_y := surface.world_surface_point(Vector2.ZERO).y
	var projectile := manager.spawn_projectile(
		PROJECTILE_DATA,
		Vector3(0.0, surface_y + 3.0, 0.0),
		Vector3(0.0, -12.0, 0.0)
	)
	var budget := 180
	while is_instance_valid(projectile) and not projectile.has_reached_playable_top() and budget > 0:
		await physics_frame
		budget -= 1
	_assert_true(is_instance_valid(projectile) and projectile.has_reached_playable_top(), "rest fixture must reach playable top")
	if not is_instance_valid(projectile):
		await _dispose_fixture(host, manager, surface)
		return
	projectile.linear_velocity = Vector3.ZERO
	projectile.angular_velocity = Vector3.ZERO
	projectile.sleeping = true
	for _tick in range(6):
		await physics_frame
	manager.finalize_pending_paint_intents()
	var command_count_at_rest := commands.size()
	for _tick in range(30):
		await physics_frame
	manager.finalize_pending_paint_intents()
	_assert_true(is_instance_valid(projectile) and manager.active_count() == 1, "a terrain-resting ball must remain resident")
	_assert_true(projectile.is_resting_on_terrain(), "natural sleep must map to reversible terrain rest")
	_assert_true(stop_reasons.is_empty(), "rest must not publish a terminal reason")
	_assert_true(commands.size() == command_count_at_rest, "stationary rest must not emit duplicate paint commands")

	var impact_count_before_wake := _radial_kind_count(commands, RadialPaintMark.Kind.IMPACT)
	var sweep_count_before_wake := _sweep_count(commands)
	projectile.sleeping = false
	projectile.linear_velocity = Vector3(8.0, 0.0, 0.0)
	budget = 180
	while is_instance_valid(projectile) and _sweep_count(commands) <= sweep_count_before_wake \
			and budget > 0:
		await physics_frame
		budget -= 1
	manager.finalize_pending_paint_intents()
	_assert_true(is_instance_valid(projectile), "a woken resident must continue as the same body")
	_assert_true(_sweep_count(commands) > sweep_count_before_wake, "measured travel after wake must resume sweep paint")
	_assert_true(
		_radial_kind_count(commands, RadialPaintMark.Kind.IMPACT) == impact_count_before_wake,
		"wake must seed a new sweep interval without a second impact blob"
	)
	await _dispose_fixture(host, manager, surface)


func _assert_embedding_recovery() -> void:
	var fixture := await _build_fixture(false)
	var host: Node3D = fixture.host
	var surface: TerrainSurface = fixture.surface
	var manager: ProjectileManager = fixture.manager
	var surface_point := surface.world_surface_point(Vector2.ZERO)
	var projectile := manager.spawn_projectile(
		PROJECTILE_DATA,
		surface_point - Vector3.UP * 0.4,
		Vector3(5.0, -2.0, 0.0)
	)
	for _tick in range(5):
		await physics_frame
	_assert_true(is_instance_valid(projectile), "an embedded valid-top ball must recover instead of disappearing")
	if is_instance_valid(projectile):
		var xz := Vector2(projectile.global_position.x, projectile.global_position.z)
		var normal := surface.world_surface_normal(xz)
		var clearance := (projectile.global_position - surface.world_surface_point(xz)).dot(normal)
		_assert_true(clearance > 0.0, "recovery must restore the center to the playable side of the surface")
		_assert_true(projectile.linear_velocity.dot(normal) >= -0.1, "recovery must remove inward normal motion")
		_assert_true(absf(projectile.linear_velocity.x) > 0.1, "recovery must preserve tangent motion")
	await _dispose_fixture(host, manager, surface)


func _assert_invalid_geometry_is_explicit() -> void:
	var fixture := await _build_fixture(false)
	var host: Node3D = fixture.host
	var surface: TerrainSurface = fixture.surface
	var manager: ProjectileManager = fixture.manager
	var collision := surface.get_node("TerrainTopBody/CollisionShape3D") as CollisionShape3D
	var invalid_shape := BoxShape3D.new()
	invalid_shape.size = Vector3(8.0, 1.0, 8.0)
	collision.shape = invalid_shape
	collision.position = Vector3(25.0, 0.0, 0.0)
	await physics_frame
	var stop_reasons: Array[StringName] = []
	manager.projectile_stopped.connect(func(_projectile: PaintProjectile, reason: StringName) -> void: stop_reasons.append(reason))
	manager.spawn_projectile(
		PROJECTILE_DATA,
		Vector3(25.0, 4.0, 0.0),
		Vector3(0.0, -12.0, 0.0)
	)
	var budget := 180
	while stop_reasons.is_empty() and budget > 0:
		await physics_frame
		budget -= 1
	_assert_true(
		stop_reasons.has(ProjectileSettlementReason.INVALID_GEOMETRY),
		"a repeated real-collider/topology mismatch must terminate with INVALID_GEOMETRY"
	)
	await _dispose_fixture(host, manager, surface)


func _assert_never_contacted_timeout() -> void:
	var fixture := await _build_fixture(false)
	var host: Node3D = fixture.host
	var surface: TerrainSurface = fixture.surface
	var manager: ProjectileManager = fixture.manager
	var miss_data := PROJECTILE_DATA.duplicate() as ProjectileData
	miss_data.never_contacted_timeout = 0.15
	var stop_reasons: Array[StringName] = []
	manager.projectile_stopped.connect(func(_projectile: PaintProjectile, reason: StringName) -> void: stop_reasons.append(reason))
	manager.spawn_projectile(miss_data, Vector3(60.0, 20.0, 0.0), Vector3.ZERO)
	var budget := 60
	while stop_reasons.is_empty() and budget > 0:
		await physics_frame
		budget -= 1
	_assert_true(
		stop_reasons.has(ProjectileSettlementReason.MISSED_TERRAIN),
		"a ball that never reaches playable top must use the resource-owned miss timeout"
	)
	await _dispose_fixture(host, manager, surface)


func _radial_kind_count(commands: Array[RefCounted], kind: int) -> int:
	var count := 0
	for command in commands:
		if command is RadialPaintMark and (command as RadialPaintMark).kind == kind:
			count += 1
	return count


func _sweep_count(commands: Array[RefCounted]) -> int:
	var count := 0
	for command in commands:
		if command is SurfacePaintSweep:
			count += 1
	return count


func _build_fixture(on_ramp: bool) -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var surface := FIXTURE_SCENE.instantiate() as TerrainSurface
	host.add_child(surface)
	var layout := TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT)
	if on_ramp:
		_apply_thirty_degree_ramp(layout)
	_install_full_target_mask(layout)
	surface.configure(layout)
	var manager := ProjectileManager.new()
	host.add_child(manager)
	manager.configure_terrain(surface, SURFACE_TUNING)
	await physics_frame
	await physics_frame
	return {"host": host, "surface": surface, "manager": manager}


func _apply_thirty_degree_ramp(layout: GeneratedStageLayout) -> void:
	var sample_size := layout.sample_size()
	for z_index in range(sample_size.y):
		for x_index in range(sample_size.x):
			var x := lerpf(
				layout.local_bounds.position.x,
				layout.local_bounds.end.x,
				float(x_index) / float(layout.cell_count.x)
			)
			layout.heights[z_index * sample_size.x + x_index] = tan(deg_to_rad(30.0)) \
					* (x - layout.local_bounds.position.x)
	layout.top_topology = TerrainTopTopology.build(layout.cell_count, layout.local_bounds, layout.heights)


func _install_full_target_mask(layout: GeneratedStageLayout) -> void:
	var target_mask := PackedByteArray()
	target_mask.resize(SURFACE_TUNING.mask_size * SURFACE_TUNING.mask_size)
	target_mask.fill(255)
	_assert_true(
		TerrainTestFixtureFactory.install_target_mask_with_coverage(layout, target_mask),
		"fixture target mask must install once"
	)


func _fixture_contact(body: StaticBody3D, point: Vector3, tick: int) -> ProjectileContact:
	return ProjectileContact.new(
		point,
		Vector3.UP,
		point + Vector3.UP * PROJECTILE_DATA.radius,
		0.0,
		Vector3.ZERO,
		0.0,
		Vector3.ZERO,
		body,
		0,
		0,
		tick,
		false,
		false,
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID,
		body.get_rid()
	)


func _dispose_fixture(host: Node3D, manager: ProjectileManager, surface: TerrainSurface) -> void:
	if is_instance_valid(manager):
		manager.cleanup()
	if is_instance_valid(surface):
		surface.queue_free()
	if is_instance_valid(host):
		host.queue_free()
	await physics_frame


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Projectile settling check failed: %s" % message)
