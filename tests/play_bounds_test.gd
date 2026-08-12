extends SceneTree

var _failed := false


func _initialize() -> void:
	var spec := PlayBoundsSpec.new()
	_assert(spec.is_valid(), "open play bounds must satisfy their versioned contract")
	_assert(spec.bounds == PlayBoundsSpec.FIXED_BOUNDS, "prediction and live flight must share one fixed AABB")
	_assert(spec.supports_terrain(Rect2(Vector2(-140, -210), Vector2(280, 160)), -2.0), "Stage 30 terrain must fit the apron")
	_assert(not spec.supports_terrain(Rect2(Vector2(-200, -240), Vector2(400, 400)), -2.0), "out-of-domain terrain must fail closed")
	_assert(spec.bounds.has_point(Vector3.ZERO) and not spec.bounds.has_point(Vector3(0, 0, 200)), "bounds must distinguish inside from escaped flight")
	_assert(spec.checksum() == PlayBoundsSpec.new().checksum(), "play-bounds checksum must be deterministic")
	_assert(spec is RefCounted, "play bounds must be non-colliding data, not wall geometry")
	if not _failed:
		print("play_bounds_test passed: shared non-colliding open exit bounds")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
