extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.time_scale = 2.0
	var game_state := root.get_node("/root/GameState")
	game_state.persistence_enabled = false
	game_state.initialize_from_data(root.get_node("/root/SaveSystem").default_data())
	_assert_true(game_state.select_stage(&"first_descent"), "production First Descent must be selectable")
	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_01")
	root.add_child(gameplay)
	await physics_frame
	await physics_frame
	var controller: StageController = gameplay.get_node("StageController")
	var cannon: CannonController = gameplay.get_node("Cannon")
	var manager: ProjectileManager = gameplay.get_node("ProjectileManager")
	var paint_system: PaintSystem = gameplay.get_node("PaintSystem")
	var observed := {
		"applied_count": 0,
		"radial_count": 0,
		"impact_count": 0,
		"sweep_count": 0,
		"written_pixels": 0,
		"newly_painted_pixels": 0,
		"impact_radii": PackedFloat32Array(),
		"sweep_radii": PackedFloat32Array(),
		"last_drained_tick": -1,
		"paint_checksum": 0,
	}
	manager.radial_paint_mark_ready.connect(
		func(command: RadialPaintMark) -> void:
			observed.radial_count += 1
			if command.kind == RadialPaintMark.Kind.IMPACT:
				observed.impact_count += 1
				observed.impact_radii.append(command.radius)
	)
	manager.surface_paint_sweep_ready.connect(
		func(command: SurfacePaintSweep) -> void:
			observed.sweep_count += 1
			observed.sweep_radii.append(command.footprint_radius)
	)
	paint_system.paint_command_applied.connect(
		func(_command, written_pixel_count: int, newly_painted_pixel_count: int) -> void:
			observed.applied_count += 1
			observed.written_pixels += written_pixel_count
			observed.newly_painted_pixels += newly_painted_pixel_count
	)
	paint_system.paint_commands_drained.connect(
		func(last_drained_physics_tick: int, _command_count: int, paint_mask_checksum: int) -> void:
			observed.last_drained_tick = last_drained_physics_tick
			observed.paint_checksum = paint_mask_checksum
	)
	_assert_true(controller.begin_aiming(), "production stage must enter aiming")
	_assert_true(cannon.is_aim_valid(), "runtime default aim must own a valid first impact")
	_assert_true(controller.request_fire(), "production stage must accept its runtime default shot")
	var active := manager.active_projectiles()
	_assert_true(active.size() == 1, "accepted fire must spawn exactly one projectile")
	if not active.is_empty():
		_assert_true(active[0].spawn_ordinal == 0, "shot parent must receive stable spawn ordinal zero")
	var frame_budget := 60 * 12
	while (observed.impact_count == 0 or observed.sweep_count == 0 \
			or observed.newly_painted_pixels == 0) and frame_budget > 0:
		await physics_frame
		frame_budget -= 1
	for projectile in manager.active_projectiles():
		projectile.sleeping = true
	await physics_frame
	manager.finalize_pending_paint_intents()
	paint_system.flush_pending()
	_assert_true(manager.active_count() > 0, "a valid-top projectile must remain resident until stage cleanup")
	_assert_true(manager.pending_intent_count() == 0, "explicit paint finalization must leave no uncanonicalized intent")
	_assert_true(observed.applied_count > 0, "physical target contacts must apply typed paint commands")
	_assert_true(observed.impact_count > 0, "first target contact must emit an impact mark")
	_assert_true(observed.sweep_count > 0, "sustained target contact must emit continuous surface sweeps")
	for radius in observed.impact_radii:
		_assert_true(is_equal_approx(radius, cannon.projectile_data.impact_paint_radius), "impact radius must remain fixed for the whole shot")
	for radius in observed.sweep_radii:
		_assert_true(is_equal_approx(radius, cannon.projectile_data.paint_footprint_radius), "parent sweep footprint must remain fixed for the whole shot")
	_assert_true(observed.last_drained_tick >= 0, "paint commands must cross the late fixed-physics drain boundary")
	_assert_true(observed.paint_checksum == paint_system.paint_mask_checksum(), "drained checksum must match PaintSystem authority")
	_assert_true(observed.written_pixels > 0 and observed.newly_painted_pixels > 0, "typed commands must write and cross the authoritative threshold")
	_assert_true(paint_system.coverage_percent() > 0.0, "projectile commands must increase authoritative coverage")
	if not _failed:
		print(
			"Phase 3 projectile-paint integration passed: %d applied, %d impact, %d sweep, persistent resident, %.4f%% coverage." % [
				observed.applied_count,
				observed.impact_count,
				observed.sweep_count,
				paint_system.coverage_percent(),
			]
		)
	Engine.time_scale = 1.0
	game_state.persistence_enabled = true
	gameplay.queue_free()
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
