extends SceneTree

const TERRAIN_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _check_surface_fixture(TerrainTestFixtureFactory.Kind.FLAT, Vector2(-3.0, 2.0), "flat")
	await _check_surface_fixture(TerrainTestFixtureFactory.Kind.RAMP, Vector2(4.0, -2.0), "sloped")
	await _check_surface_fixture(TerrainTestFixtureFactory.Kind.FACETED, Vector2(0.0, 0.0), "triangle edge")
	await _check_rejections()
	if not _failed:
		print("terrain_aim_target_test passed: top-only terrain picks preserve canonical addresses and reject invalid contexts.")
	quit(1 if _failed else 0)


func _check_surface_fixture(kind: TerrainTestFixtureFactory.Kind, xz: Vector2, label: String) -> void:
	var fixture := await _make_fixture(kind)
	var terrain: TerrainSurface = fixture.terrain
	var point := terrain.world_surface_point(xz)
	var picked := _pick_at(fixture.picker, fixture.camera, terrain, point, 10)
	_assert(picked != null, "%s ray must select a top target" % label)
	if picked != null:
		_assert(picked.world_point.distance_to(point) < 0.02, "%s target must retain its hit point" % label)
		_assert(is_equal_approx(picked.world_normal.length(), 1.0), "%s target normal must normalize" % label)
		_assert(picked.hit_identity.is_valid() and picked.hit_identity.terrain_cell.x >= 0,
				"%s target must retain a canonical top address" % label)
		_assert(not String(picked.revision_key).is_empty(), "%s target must expose a stable revision key" % label)
		_assert(fixture.picker.consumed_request_revision() == 10,
				"%s target must retain the consumed input revision" % label)
		_assert(fixture.picker.pick_latest_in_physics(terrain) == null,
				"%s request must be consumed exactly once" % label)
	_fixture_free(fixture)


func _check_rejections() -> void:
	var fixture := await _make_fixture(TerrainTestFixtureFactory.Kind.FLAT)
	var terrain: TerrainSurface = fixture.terrain
	var point := terrain.world_surface_point(Vector2.ZERO)
	# The actual support-shell collider is a first hit from outside the mountain.
	var shell_point := terrain.to_global(Vector3(15.0, -5.0, 0.0))
	fixture.camera.global_position = terrain.to_global(Vector3(45.0, -5.0, 0.0))
	fixture.camera.look_at(shell_point, Vector3.UP)
	await physics_frame
	fixture.picker.queue_latest(fixture.camera, Vector2(root.size) * 0.5, 19)
	_assert(fixture.picker.pick_latest_in_physics(terrain) == null,
			"support shell first hit must reject")
	fixture.camera.global_position = Vector3(0.0, 45.0, 45.0)
	fixture.camera.look_at(point, Vector3.UP)
	await physics_frame
	# A first-hit mechanism body blocks the top; the picker never projects through it.
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	(collision.shape as BoxShape3D).size = Vector3(8.0, 8.0, 2.0)
	blocker.add_child(collision)
	fixture.host.add_child(blocker)
	blocker.global_position = fixture.camera.global_position.lerp(point, 0.5)
	await physics_frame
	_assert(_pick_at(fixture.picker, fixture.camera, terrain, point, 20) == null,
			"mechanism/foreign first hit must reject rather than project to terrain")
	blocker.queue_free()
	await physics_frame
	# Pointing at empty sky has no fabricated target.
	fixture.camera.look_at(fixture.camera.global_position + Vector3.UP, Vector3.FORWARD)
	var sky_screen := Vector2(root.size) * 0.5
	fixture.picker.queue_latest(fixture.camera, sky_screen, 21)
	_assert(fixture.picker.pick_latest_in_physics(terrain) == null, "sky ray must reject")
	# A queued camera pose is stale after any camera movement before physics consumption.
	fixture.camera.look_at(point, Vector3.UP)
	var screen: Vector2 = fixture.camera.unproject_position(point)
	fixture.picker.queue_latest(fixture.camera, screen, 22)
	fixture.camera.global_position += Vector3(0.1, 0.0, 0.0)
	_assert(fixture.picker.pick_latest_in_physics(terrain) == null, "stale camera context must reject")
	_fixture_free(fixture)


func _make_fixture(kind: TerrainTestFixtureFactory.Kind) -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var terrain := TERRAIN_SCENE.instantiate() as TerrainSurface
	host.add_child(terrain)
	terrain.configure(TerrainTestFixtureFactory.build_layout(kind))
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.global_position = Vector3(0.0, 45.0, 45.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.make_current()
	await physics_frame
	return {"host": host, "terrain": terrain, "camera": camera, "picker": TerrainScreenRayPicker.new()}


func _pick_at(picker: TerrainScreenRayPicker, camera: Camera3D, terrain: TerrainSurface, point: Vector3, revision: int) -> TerrainAimTarget:
	camera.look_at(point, Vector3.UP)
	var screen := camera.unproject_position(point)
	_assert(picker.queue_latest(camera, screen, revision), "finite current camera request must queue")
	return picker.pick_latest_in_physics(terrain)


func _fixture_free(fixture: Dictionary) -> void:
	(fixture.host as Node3D).queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("terrain_aim_target_test failed: %s" % message)
