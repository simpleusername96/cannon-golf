extends SceneTree

const PROJECTILE_RADIUS := 2.4
const COLLISION_MASK := 1

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.physics_ticks_per_second = 60
	var floor := _add_floor()
	await physics_frame
	await physics_frame
	_assert_collision_surface_contract(floor)
	_assert_non_collision_predictions_have_no_contact()
	if not _failed:
		print("Prediction projectile parity checks passed: deterministic sphere center/contact separation and collision identity at 60 Hz.")
	quit(1 if _failed else 0)


func _add_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = &"PredictionFloor"
	floor.collision_layer = COLLISION_MASK
	floor.set_meta(ContainmentSpec.CONTACT_OWNER_META, &"fixture/prediction_floor")
	var shape_node := CollisionShape3D.new()
	shape_node.set_meta(ContainmentSpec.CONTACT_SHAPE_META, &"fixture/prediction_floor_shape")
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 1.0, 40.0)
	shape_node.shape = shape
	floor.add_child(shape_node)
	root.add_child(floor)
	return floor


func _assert_collision_surface_contract(expected_floor: StaticBody3D) -> void:
	var first := _predict(Vector3(0.0, 8.0, 0.0), Vector3(0.0, -90.0, 0.0), AABB(Vector3(-100.0, -100.0, -100.0), Vector3(200.0, 200.0, 200.0)))
	var second := _predict(Vector3(0.0, 8.0, 0.0), Vector3(0.0, -90.0, 0.0), AABB(Vector3(-100.0, -100.0, -100.0), Vector3(200.0, 200.0, 200.0)))
	_assert_true(first.kind == TrajectoryPrediction.Kind.COLLISION, "sphere cast must report the floor collision")
	_assert_true(first.contact_point is Vector3, "collision prediction must expose a finite surface contact point")
	if not first.contact_point is Vector3:
		return
	var contact: Vector3 = first.contact_point as Vector3
	_assert_true(contact.is_finite(), "collision contact point must be finite")
	_assert_true(first.endpoint.distance_to(contact + first.normal * PROJECTILE_RADIUS) <= 0.001, "endpoint must be the sphere center one radius along the collision normal")
	_assert_true(absf(contact.y - 0.5) <= 0.001, "contact point must lie on the floor top face")
	_assert_true(first.collider == expected_floor, "first collision collider identity must stay unchanged")
	_assert_true(first.hit_identity != null and first.hit_identity.contact_owner_id == &"fixture/prediction_floor", "first collision owner identity must stay unchanged")
	_assert_true(second.kind == first.kind and second.endpoint.distance_to(first.endpoint) <= 0.0001, "60 Hz prediction center must be deterministic")
	_assert_true(second.contact_point is Vector3 and (second.contact_point as Vector3).distance_to(contact) <= 0.0001, "60 Hz prediction contact point must be deterministic")
	_assert_true(second.hit_identity != null and first.hit_identity != null and second.hit_identity.contact_owner_id == first.hit_identity.contact_owner_id, "first collision identity ordering must remain deterministic")


func _assert_non_collision_predictions_have_no_contact() -> void:
	var bounds_exit := _predict(Vector3(0.0, 20.0, 0.0), Vector3(100.0, 0.0, 0.0), AABB(Vector3(-1.0, -10.0, -1.0), Vector3(2.0, 40.0, 2.0)))
	_assert_true(bounds_exit.kind == TrajectoryPrediction.Kind.BOUNDS_EXIT, "fixture must leave the declared bounds")
	_assert_true(bounds_exit.contact_point == null, "bounds exit must not fabricate a contact point")
	var timeout := _predict(Vector3(0.0, 800.0, 0.0), Vector3.ZERO, AABB(Vector3(-100.0, -1000.0, -100.0), Vector3(200.0, 2000.0, 200.0)))
	_assert_true(timeout.kind == TrajectoryPrediction.Kind.TIMEOUT, "fixture must reach the bounded prediction timeout")
	_assert_true(timeout.contact_point == null, "timeout must not fabricate a contact point")


func _predict(origin: Vector3, velocity: Vector3, bounds: AABB) -> TrajectoryPrediction:
	return TrajectoryPredictor.predict_motion(
		root.get_world_3d().direct_space_state,
		origin,
		velocity,
		PROJECTILE_RADIUS,
		0.0,
		bounds,
		COLLISION_MASK
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Prediction projectile parity check failed: %s" % message)
