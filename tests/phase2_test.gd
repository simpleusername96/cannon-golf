extends SceneTree


func _initialize() -> void:
	var projectile_data := ProjectileData.new()
	var origin := Vector3(0.0, 1.5, 5.0)
	var velocity_a := CannonBallistics.launch_velocity(projectile_data, 8.0, 41.0, 72.0)
	var velocity_b := CannonBallistics.launch_velocity(projectile_data, 8.0, 41.0, 72.0)
	_assert_vector_close(velocity_a, velocity_b, 0.000001, "identical aim must produce identical launch velocity")
	var gravity := Vector3.DOWN * 9.8
	var samples_a := CannonBallistics.sample_unobstructed(origin, velocity_a, gravity, 0.1, 3.0)
	var samples_b := CannonBallistics.sample_unobstructed(origin, velocity_b, gravity, 0.1, 3.0)
	_assert_true(samples_a.size() == samples_b.size(), "trajectory sample counts must match")
	for index in range(samples_a.size()):
		_assert_vector_close(samples_a[index], samples_b[index], 0.000001, "trajectory samples must be deterministic")
	var terrain := TerrainGeometryFactory.build(TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT))
	_assert_true(terrain.is_valid() and terrain.render_mesh.get_surface_count() == 1, "terrain geometry must contain one closed render surface")
	_assert_true(projectile_data.launch_speed(100.0) > projectile_data.launch_speed(0.0), "power must increase launch speed")
	print("Phase 2 deterministic ballistics checks passed: %d samples." % samples_a.size())
	quit(0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _assert_vector_close(a: Vector3, b: Vector3, tolerance: float, message: String) -> void:
	_assert_true(a.distance_to(b) <= tolerance, message)
