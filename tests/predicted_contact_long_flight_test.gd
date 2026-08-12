extends SceneTree

const FIXTURE_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const PROJECTILE_DATA := preload("res://resources/projectiles/basic_paintball.tres")
const GAMEPLAY_PACE := preload("res://src/gameplay/gameplay_pace.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_time_scale := Engine.time_scale
	GAMEPLAY_PACE.apply_active()
	var host := Node3D.new()
	root.add_child(host)
	var terrain := FIXTURE_SCENE.instantiate() as TerrainSurface
	host.add_child(terrain)
	terrain.configure(TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT))
	var manager := ProjectileManager.new()
	host.add_child(manager)
	manager.configure_terrain(terrain)
	manager.stage_bounds = AABB(Vector3(-100.0, -200.0, -100.0), Vector3(200.0, 440.0, 200.0))
	await physics_frame
	var data := PROJECTILE_DATA.duplicate() as ProjectileData
	var origin := Vector3(0.0, 120.0, 0.0)
	var prediction := TrajectoryPredictor.predict_motion(host.get_world_3d().direct_space_state,
		origin, Vector3.ZERO, data.radius, data.linear_damp, manager.stage_bounds)
	_assert(prediction.kind == TrajectoryPrediction.Kind.COLLISION \
			and prediction.hit_identity != null \
			and prediction.hit_identity.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			and prediction.duration > 6.0 and prediction.duration < 12.0,
		"vertical fixture must predict a terrain-top contact after six seconds")
	if prediction.kind != TrajectoryPrediction.Kind.COLLISION:
		manager.cleanup()
		host.queue_free()
		await process_frame
		Engine.time_scale = original_time_scale
		quit(1)
		return
	var contacts: Array[ProjectileContact] = []
	var stop_reasons: Array[StringName] = []
	manager.projectile_contact_reported.connect(
		func(_p: PaintProjectile, contact: ProjectileContact) -> void: contacts.append(contact)
	)
	manager.projectile_stopped.connect(
		func(_p: PaintProjectile, reason: StringName) -> void: stop_reasons.append(reason)
	)
	var spawn_tick := Engine.get_physics_frames()
	var root_projectile := manager.spawn_projectile(data, origin, Vector3.ZERO, 0, 0,
		prediction.duration + data.predicted_contact_grace)
	_assert(root_projectile != null and root_projectile.never_contacted_deadline > 6.0,
		"matching prediction must protect the root beyond the ordinary deadline")
	for _tick in range(600):
		await physics_frame
		if not contacts.is_empty(): break
	_assert(not contacts.is_empty(), "protected live root must reach terrain after six seconds")
	if not contacts.is_empty():
		var live_simulation_seconds := float(contacts[0].physics_tick - spawn_tick) \
				/ float(Engine.physics_ticks_per_second) * Engine.time_scale
		_assert(live_simulation_seconds > data.never_contacted_timeout \
				and live_simulation_seconds <= root_projectile.never_contacted_deadline \
						+ TrajectoryPredictionJob.PHYSICS_STEP,
			"live top contact must occur after six simulation seconds and before the protected deadline")
		_assert(contacts[0].world_position.distance_to(prediction.collision_contact_point()) <= 0.2,
			"live first top contact must match predicted contact")
		_assert(contacts[0].is_first_contact and root_projectile.terminal_reason != ProjectileSettlementReason.MISSED_TERRAIN,
			"long-flight root must not terminate as an ordinary miss before contact")
	var stops_before_miss := stop_reasons.size()
	var miss := manager.spawn_projectile(data, Vector3(50.0, 20.0, 0.0), Vector3.ZERO)
	var miss_spawned := miss != null
	for _miss_tick in range(370):
		await physics_frame
		if stop_reasons.size() > stops_before_miss:
			break
	_assert(miss_spawned and stop_reasons.size() > stops_before_miss \
			and stop_reasons.back() == ProjectileSettlementReason.MISSED_TERRAIN,
		"unmatched in-bounds root must retain ordinary miss termination")
	manager.stage_bounds = AABB(Vector3(-100.0, -20.0, -100.0), Vector3(200.0, 260.0, 200.0))
	var stops_before_escape := stop_reasons.size()
	var escaped := manager.spawn_projectile(data, Vector3(200.0, 20.0, 0.0), Vector3.ZERO)
	var escaped_spawned := escaped != null
	await physics_frame
	await process_frame
	_assert(escaped_spawned and stop_reasons.size() > stops_before_escape \
			and stop_reasons.back() == ProjectileSettlementReason.ESCAPED_BOUNDS,
		"bounds exit must remain immediate")
	manager.cleanup()
	host.queue_free()
	await process_frame
	var active_time_scale := Engine.time_scale
	Engine.time_scale = original_time_scale
	if not _failed:
		var live_seconds := float(contacts[0].physics_tick - spawn_tick) \
				/ float(Engine.physics_ticks_per_second) * active_time_scale
		print("Long-flight parity passed: predicted %.3fs, live contact %.3fs, protected terminal=terrain_contact, unmatched terminal=%s, bounds terminal=%s." % [
			prediction.duration, live_seconds, ProjectileSettlementReason.MISSED_TERRAIN,
			ProjectileSettlementReason.ESCAPED_BOUNDS,
		])
	quit(1 if _failed else 0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Long-flight parity failed: %s" % message)
