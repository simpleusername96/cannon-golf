extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var points := PackedVector3Array([
		Vector3(-12.0, -7.0, -5.0), Vector3(12.0, -7.0, -5.0),
		Vector3(-12.0, 9.0, -5.0), Vector3(12.0, 9.0, -5.0),
		Vector3(-12.0, -7.0, 5.0), Vector3(12.0, -7.0, 5.0),
		Vector3(-12.0, 9.0, 5.0), Vector3(12.0, 9.0, 5.0),
	])
	var authored_position := Vector3(38.0, 25.0, 52.0)
	var authored_focus := Vector3.ZERO
	for aspect in [16.0 / 9.0, 16.0 / 10.0]:
		for safe_rect in [
			Rect2(0.27, 0.07, 0.69, 0.79),
			Rect2(0.06, 0.08, 0.64, 0.82),
			Rect2(0.42, 0.10, 0.56, 0.82),
		]:
			var pose := TerrainCameraFramer.framed_pose_in_normalized_rect(
				points, Vector3.ZERO, authored_position, authored_focus,
				48.0, aspect, safe_rect, 1.04
			)
			_assert_true(pose.size() == 2, "safe-rect framing must return one pose")
			if pose.size() != 2:
				continue
			_assert_true(
				TerrainCameraFramer.pose_fits_points_in_normalized_rect(
					points, pose[0], pose[1], 48.0, aspect, safe_rect, 1.0
				),
				"framed points must fit their normalized safe rectangle"
			)
			var authored_forward := (authored_focus - authored_position).normalized()
			var framed_forward := (pose[1] - pose[0]).normalized()
			_assert_true(
				authored_forward.dot(framed_forward) > 0.9999,
				"safe-rect framing must preserve the authored view direction"
			)
	_assert_true(
		TerrainCameraFramer.framed_pose_in_normalized_rect(
			PackedVector3Array(), Vector3.ZERO, authored_position, authored_focus,
			48.0, 16.0 / 9.0, Rect2(0.0, 0.0, 1.0, 1.0)
		).is_empty(),
		"empty presentation points must be rejected"
	)
	_assert_true(
		TerrainCameraFramer.framed_pose_in_normalized_rect(
			points, Vector3.ZERO, authored_position, authored_focus,
			48.0, 16.0 / 9.0, Rect2(0.8, 0.1, 0.4, 0.8)
		).is_empty(),
		"safe rectangles outside the viewport must be rejected"
	)
	var non_finite_points := points.duplicate()
	non_finite_points.append(Vector3(NAN, 0.0, 0.0))
	_assert_true(
		TerrainCameraFramer.framed_pose_in_normalized_rect(
			non_finite_points, Vector3.ZERO, authored_position, authored_focus,
			48.0, 16.0 / 9.0, Rect2(0.0, 0.0, 1.0, 1.0)
		).is_empty(),
		"non-finite presentation points must be rejected"
	)
	_assert_true(
		TerrainCameraFramer.framed_pose_in_normalized_rect(
			points, Vector3.ZERO, Vector3(INF, 0.0, 0.0), authored_focus,
			48.0, 16.0 / 9.0, Rect2(0.0, 0.0, 1.0, 1.0)
		).is_empty(),
		"non-finite authored poses must be rejected"
	)
	if not _failed:
		print("terrain_camera_safe_rect_test passed: asymmetric presentation fits preserve view direction")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
