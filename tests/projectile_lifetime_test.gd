extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")
const FIXTURE_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const PROJECTILE_DATA := preload("res://resources/projectiles/basic_paintball.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	await _assert_predicted_root_deadline(7.0, 7.5)
	await _assert_predicted_root_deadline(20.0, 13.0)
	await _assert_unmatched_and_bounds_deadlines()
	if not _failed:
		print("projectile_lifetime_test passed: matched terrain prediction protects root flight, unmatched misses retain six seconds, and bounds remain immediate.")
	quit(1 if _failed else 0)


func _assert_predicted_root_deadline(prediction_duration: float, expected_deadline: float) -> void:
	var game_state := root.get_node("/root/GameState") as GameState
	game_state.persistence_enabled = false
	game_state.select_stage(&"stage_01")
	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_01")
	_assert(gameplay != null, "lifetime fixture requires baked Stage 01")
	if gameplay == null:
		return
	root.add_child(gameplay)
	await physics_frame
	await physics_frame
	var controller := gameplay.get_node("StageController") as StageController
	var manager := gameplay.get_node("ProjectileManager") as ProjectileManager
	var cannon := gameplay.get_node("Cannon") as CannonController
	_assert(controller.begin_aiming(), "lifetime fixture must enter aiming")
	var context_key := StringName("lifetime-matching-context-%.1f" % prediction_duration)
	cannon.expect_prediction_context(context_key)
	cannon.set_prediction(
		_terrain_prediction(prediction_duration),
		cannon.aim_key(),
		context_key
	)
	_assert(controller.request_fire(), "a matching current terrain prediction must allow Fire")
	var roots := manager.active_projectiles()
	_assert(roots.size() == 1, "matched Fire must create one root")
	if roots.size() == 1:
		_assert(
			is_equal_approx(roots[0].never_contacted_deadline, expected_deadline),
			"matching terrain prediction must apply its grace without exceeding the hard maximum"
		)
	manager.cleanup()
	gameplay.queue_free()
	await physics_frame


func _assert_unmatched_and_bounds_deadlines() -> void:
	_assert(
		is_equal_approx(PROJECTILE_DATA.never_contacted_timeout, 6.0)
				and is_equal_approx(PROJECTILE_DATA.predicted_contact_grace, 0.5)
				and is_equal_approx(PROJECTILE_DATA.predicted_contact_hard_maximum, 13.0),
		"basic paintball must own the locked 6.0 s, 0.5 s, and 13.0 s lifetime tuning"
	)
	var host := Node3D.new()
	root.add_child(host)
	var surface := FIXTURE_SCENE.instantiate() as TerrainSurface
	host.add_child(surface)
	surface.configure(TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT))
	var manager := ProjectileManager.new()
	host.add_child(manager)
	manager.configure_terrain(surface)
	var data := PROJECTILE_DATA.duplicate() as ProjectileData
	data.never_contacted_timeout = 0.15
	data.predicted_contact_hard_maximum = 0.40
	await physics_frame
	await physics_frame
	var unmatched := manager.spawn_projectile(data, Vector3(60.0, 20.0, 0.0), Vector3.ZERO)
	_assert(unmatched != null, "unmatched lifetime fixture must spawn")
	if unmatched != null:
		_assert(
			is_equal_approx(unmatched.never_contacted_deadline, data.never_contacted_timeout),
			"an unmatched root must retain the ordinary resource timeout"
		)
	var bounded_stops: Array[StringName] = []
	manager.projectile_stopped.connect(func(_projectile: PaintProjectile, reason: StringName) -> void:
		bounded_stops.append(reason)
	)
	manager.stage_bounds = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var escaped := manager.spawn_projectile(data, Vector3(10.0, 10.0, 10.0), Vector3.ZERO)
	_assert(escaped != null, "bounds fixture must spawn")
	await physics_frame
	_assert(
		bounded_stops.has(ProjectileSettlementReason.ESCAPED_BOUNDS),
		"bounds exit must stop immediately despite any root deadline"
	)
	manager.cleanup()
	host.queue_free()
	await physics_frame


func _terrain_prediction(duration: float) -> TrajectoryPrediction:
	return TrajectoryPrediction.new(
		TrajectoryPrediction.Kind.COLLISION,
		Vector3.ZERO,
		PackedVector3Array(),
		duration,
		null,
		Vector3.UP,
		&"",
		TrajectoryHitIdentity.terrain_top(
			TerrainSurface.TOP_SHAPE_ID,
			0,
			Vector2i(0, 0),
			0,
			Vector3(1.0, 0.0, 0.0)
		)
	)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
