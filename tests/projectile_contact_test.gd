extends SceneTree

const FIXTURE_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const CANNON_SCENE := preload("res://scenes/gameplay/cannon.tscn")
const PROJECTILE_DATA := preload("res://resources/projectiles/basic_paintball.tres")
const REPEATS := 20

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.physics_ticks_per_second = 60
	_assert_scale_contract()
	await _assert_cannon_ballistic_yaw_contract()
	await _run_fixture_case(
		&"flat", TerrainTestFixtureFactory.Kind.FLAT,
		Vector3(0, 10, 0), Vector3(0, -100, 0), Vector3.UP
	)
	await _run_fixture_case(
		&"ramp", TerrainTestFixtureFactory.Kind.RAMP,
		Vector3(0, TerrainTestFixtureFactory.ramp_height(0.0) + 10.0, 0),
		Vector3(0, -100, 0), Vector3(-tan(deg_to_rad(35.0)), 1.0, 0.0).normalized()
	)
	await _run_fixture_case(
		&"graze", TerrainTestFixtureFactory.Kind.FLAT,
		Vector3(-10, 1, 0), Vector3(80, -20, 0), Vector3.UP
	)
	var ridge_layout := TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FACETED)
	var ridge_xz := Vector2(0.7, 0.4)
	await _run_fixture_case(
		&"ridge", TerrainTestFixtureFactory.Kind.FACETED,
		Vector3(ridge_xz.x, ridge_layout.height_at_local(ridge_xz.x, ridge_xz.y) + 10.0, ridge_xz.y),
		Vector3(0, -100, 0), ridge_layout.normal_at_local(ridge_xz.x, ridge_xz.y)
	)
	await _run_fixture_case(
		&"skirt", TerrainTestFixtureFactory.Kind.FLAT,
		Vector3(20, -4, 0), Vector3(-100, 0, 0), Vector3.RIGHT
	)
	await _assert_recontact_debounce()
	await _assert_simultaneous_contacts()
	if not _failed:
		print("Projectile contact checks passed: 100 exact top/ramp/ridge/shell CCD contacts, separated recontact, and stable simultaneous-body ordering at 60 Hz.")
	quit(1 if _failed else 0)


func _assert_scale_contract() -> void:
	_assert_true(is_equal_approx(PROJECTILE_DATA.radius, 2.40), "physical projectile radius must be 2.40 m")
	_assert_true(is_equal_approx(PROJECTILE_DATA.minimum_launch_speed, 32.0), "minimum launch speed must be 32 m/s")
	_assert_true(is_equal_approx(PROJECTILE_DATA.maximum_launch_speed, 160.0), "maximum launch speed must be 160 m/s")
	_assert_true(is_equal_approx(PROJECTILE_DATA.launch_speed(0.0), 32.0), "zero power must map to 32 m/s")
	_assert_true(is_equal_approx(PROJECTILE_DATA.launch_speed(100.0), 160.0), "full power must map to 160 m/s")
	_assert_true(is_equal_approx(PROJECTILE_DATA.paint_footprint_radius, 2.80), "sweep paint radius must be 2.80 m")
	_assert_true(is_equal_approx(PROJECTILE_DATA.impact_paint_radius, 3.50), "impact paint radius must be 3.50 m")
	_assert_true(
		PROJECTILE_DATA.impact_paint_radius > PROJECTILE_DATA.paint_footprint_radius \
				and PROJECTILE_DATA.paint_footprint_radius > PROJECTILE_DATA.radius,
		"impact, sweep, and physical radii must keep the doubled middle proportion"
	)


func _assert_cannon_ballistic_yaw_contract() -> void:
	var cannon := CANNON_SCENE.instantiate() as CannonController
	root.add_child(cannon)
	await physics_frame
	for yaw in PackedFloat32Array([-45.0, -12.3, 0.0, 23.4, 45.0]):
		for elevation in PackedFloat32Array([10.0, 38.0, 68.0]):
			cannon.set_aim(yaw, elevation, 50.0)
			var elevation_pivot := cannon.get_node("YawPivot/ElevationPivot") as Node3D
			var visual_direction: Vector3 = -elevation_pivot.global_transform.basis.z.normalized()
			var ballistic_direction: Vector3 = CannonBallistics.launch_direction(yaw, elevation)
			var tangent_origin := cannon.get_muzzle_position() \
					+ ballistic_direction * PROJECTILE_DATA.radius
			_assert_true(
				visual_direction.dot(ballistic_direction) >= 0.999,
				"visual muzzle and ballistic launch direction must share yaw/elevation; yaw=%.1f elevation=%.1f visual=%s ballistic=%s" % [
					yaw, elevation, visual_direction, ballistic_direction
				]
			)
			_assert_true(
				Vector2(
					cannon.get_launch_origin().x,
					cannon.get_launch_origin().z
				).distance_to(Vector2(
					tangent_origin.x,
					tangent_origin.z
				)) <= 0.0001,
				"the projectile centre must spawn one radius beyond the muzzle in XZ"
			)
			_assert_true(
				cannon.get_launch_origin().y - PROJECTILE_DATA.radius \
						>= cannon.global_position.y \
								+ CannonBallistics.PLATFORM_Y_BELOW_CANNON_ROOT \
								+ CannonBallistics.PROJECTILE_PLATFORM_CLEARANCE \
								- 0.0001,
				"the projectile centre must keep the full sphere above the cannon platform"
			)
	cannon.queue_free()
	await physics_frame


func _run_fixture_case(
		case_name: StringName,
		kind: TerrainTestFixtureFactory.Kind,
		start: Vector3,
		velocity: Vector3,
		expected_normal: Vector3
) -> void:
	var surface := FIXTURE_SCENE.instantiate() as TerrainSurface
	root.add_child(surface)
	var layout := TerrainTestFixtureFactory.build_layout(kind)
	surface.configure(layout)
	var manager := ProjectileManager.new()
	root.add_child(manager)
	manager.configure_terrain(surface)
	await physics_frame
	await physics_frame
	for repeat_index in range(REPEATS):
		var result := await _fire_once(manager, start, velocity)
		_assert_true(result.has("contact"), "%s repeat %d must report a contact" % [case_name, repeat_index])
		if not result.has("contact"):
			continue
		var contact: ProjectileContact = result.contact
		var expected_collider := surface.get_node("TerrainShellBody") if case_name == &"skirt" else surface.get_node("TerrainTopBody")
		_assert_true(contact.collider == expected_collider, "%s must report exact collider identity" % case_name)
		_assert_true(contact.collider_instance_id == expected_collider.get_instance_id(), "%s collider ID must match object identity" % case_name)
		_assert_true(contact.collider_rid == expected_collider.get_rid(), "%s collider RID must match runtime identity" % case_name)
		_assert_true(contact.collider_shape_index == 0 and contact.local_shape_index == 0, "%s must report exact shape indices" % case_name)
		var expected_owner := TerrainSurface.SHELL_OWNER_ID if case_name == &"skirt" else TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID
		var expected_shape := TerrainSurface.SHELL_SHAPE_ID if case_name == &"skirt" else TerrainSurface.TOP_SHAPE_ID
		_assert_true(contact.contact_owner_id == expected_owner and contact.contact_shape_id == expected_shape, "%s must resolve stable owner/shape metadata" % case_name)
		_assert_true(contact.has_stable_identity(), "%s contact identity must be complete" % case_name)
		var measured_expected_normal := layout.normal_at_local(
			contact.world_position.x,
			contact.world_position.z
		) if case_name == &"ridge" else expected_normal
		_assert_true(contact.normal.dot(measured_expected_normal) >= 0.98, "%s contact normal must match its collision triangle; expected=%s got=%s dot=%.4f" % [case_name, measured_expected_normal, contact.normal, contact.normal.dot(measured_expected_normal)])
		_assert_true(_surface_error(case_name, contact.world_position) <= 0.05, "%s contact point must lie within 0.05 m of its known surface" % case_name)
		_assert_true(contact.impulse.length() > 0.0, "%s contact must report a physical impulse; got %s" % [case_name, contact.impulse])
		_assert_true(contact.incoming_velocity.distance_to(velocity) <= 4.5, "%s first contact must preserve the cached pre-contact velocity; expected %s, got %s" % [case_name, velocity, contact.incoming_velocity])
		_assert_true(contact.relative_normal_speed >= 7.5, "%s contact must report positive relative normal speed" % case_name)
		_assert_true(contact.is_first_contact, "%s first reported contact must be ordered first" % case_name)
		var center: Vector3 = contact.impact_center_position
		var reported_center: Vector3 = result.reported_center
		_assert_true(center.is_finite(), "%s measured projectile center must be finite" % case_name)
		_assert_true(
			center.distance_to(reported_center) <= 0.001,
			"%s contact must preserve the projectile's measured body center" % case_name
		)
	manager.cleanup()
	manager.queue_free()
	surface.queue_free()
	await physics_frame


func _fire_once(manager: ProjectileManager, start: Vector3, velocity: Vector3) -> Dictionary:
	var observed: Dictionary = {}
	var callback := func(projectile: PaintProjectile, contact: ProjectileContact) -> void:
		if not observed.is_empty():
			return
		observed["contact"] = contact
		observed["reported_center"] = projectile.global_position
		projectile.deactivate(&"contact_test")
	manager.projectile_contact_reported.connect(callback)
	var projectile := manager.spawn_projectile(PROJECTILE_DATA, start, velocity)
	_assert_true(projectile != null, "contact fixture must spawn a projectile")
	var frame_budget := 120
	while observed.is_empty() and frame_budget > 0:
		await physics_frame
		frame_budget -= 1
	if manager.projectile_contact_reported.is_connected(callback):
		manager.projectile_contact_reported.disconnect(callback)
	if projectile != null and is_instance_valid(projectile):
		projectile.deactivate(&"contact_test_timeout")
	await physics_frame
	return observed


func _assert_recontact_debounce() -> void:
	var surface := FIXTURE_SCENE.instantiate() as TerrainSurface
	root.add_child(surface)
	surface.configure(TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT))
	var manager := ProjectileManager.new()
	root.add_child(manager)
	manager.configure_terrain(surface)
	var bouncing_data := PROJECTILE_DATA.duplicate() as ProjectileData
	bouncing_data.bounce = 0.82
	var ticks := PackedInt32Array()
	var first_flags: Array[bool] = []
	manager.projectile_contact_reported.connect(func(projectile: PaintProjectile, contact: ProjectileContact) -> void:
		ticks.append(contact.physics_tick)
		first_flags.append(contact.is_first_contact)
		if ticks.size() >= 2:
			projectile.deactivate(&"recontact_test_complete")
	)
	manager.spawn_projectile(bouncing_data, Vector3(0, 5, 0), Vector3(0, -30, 0))
	var frame_budget := 300
	while ticks.size() < 2 and manager.active_count() > 0 and frame_budget > 0:
		await physics_frame
		frame_budget -= 1
	_assert_true(ticks.size() >= 2, "a separated bounce must begin contact again")
	if ticks.size() >= 2:
		_assert_true(ticks[1] - ticks[0] >= 3, "recontact must require two fully absent ticks")
		_assert_true(first_flags[0] and not first_flags[1], "only the projectile's first contact may carry first-contact=true")
	manager.cleanup()
	manager.queue_free()
	surface.queue_free()
	await physics_frame


func _assert_simultaneous_contacts() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var surface := FIXTURE_SCENE.instantiate() as TerrainSurface
	surface.position = Vector3(0.0, -100.0, 0.0)
	host.add_child(surface)
	surface.configure(TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT))
	var floor_body := _box_contact_body(
		host,
		&"FloorBody",
		&"fixture/a_floor",
		&"FloorShape",
		Vector3(0.0, 0.0, 0.0),
		Vector3(20.0, 1.0, 20.0)
	)
	var wall_body := _box_contact_body(
		host,
		&"WallBody",
		&"fixture/b_wall",
		&"WallShape",
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 20.0, 20.0)
	)
	var manager := ProjectileManager.new()
	host.add_child(manager)
	manager.configure_terrain(surface)
	await physics_frame
	await physics_frame
	var contacts: Array[ProjectileContact] = []
	var projectile := manager.spawn_projectile(
		PROJECTILE_DATA,
		Vector3(1.05, 1.05, 0.0),
		Vector3(-30.0, -30.0, 0.0)
	)
	manager.projectile_contact_reported.connect(func(reported: PaintProjectile, contact: ProjectileContact) -> void:
		if reported != projectile:
			return
		contacts.append(contact)
		if contacts.size() >= 2:
			reported.deactivate(&"simultaneous_contact_complete")
	)
	var budget := 120
	while contacts.size() < 2 and budget > 0:
		await physics_frame
		budget -= 1
	_assert_true(contacts.size() >= 2, "corner collision must report both begun bodies")
	if contacts.size() >= 2:
		_assert_true(contacts[0].physics_tick == contacts[1].physics_tick, "simultaneous contacts must share one physics tick")
		_assert_true(contacts[0].contact_owner_id == &"fixture/a_floor", "stable owner ID must order floor first")
		_assert_true(contacts[1].contact_owner_id == &"fixture/b_wall", "stable owner ID must order wall second")
		_assert_true(contacts[0].collider == floor_body and contacts[1].collider == wall_body, "ordered contact bodies must retain exact runtime identity")
	manager.cleanup()
	host.queue_free()
	await physics_frame


func _box_contact_body(
		parent: Node3D,
		body_name: StringName,
		owner_id: StringName,
		shape_id: StringName,
		body_position: Vector3,
		size: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = body_position
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta(PlayBoundsSpec.CONTACT_OWNER_META, owner_id)
	var shape_node := CollisionShape3D.new()
	shape_node.name = shape_id
	shape_node.set_meta(PlayBoundsSpec.CONTACT_SHAPE_META, shape_id)
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)
	return body


func _surface_error(case_name: StringName, point: Vector3) -> float:
	if case_name == &"ramp":
		var normal := Vector3(-tan(deg_to_rad(35.0)), 1.0, 0.0).normalized()
		return absf(normal.dot(point - Vector3(-15.0, 0.0, 0.0)))
	if case_name == &"skirt":
		return absf(point.x - 15.0)
	if case_name == &"ridge":
		var layout := TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FACETED)
		return absf(point.y - layout.height_at_local(point.x, point.z))
	return absf(point.y)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Projectile contact check failed: %s" % message)
