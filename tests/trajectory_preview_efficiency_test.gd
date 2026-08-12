extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var preview := TrajectoryPreview.new()
	root.add_child(preview)
	await process_frame

	var dots := preview.get_node_or_null("TrajectoryDots") as MultiMeshInstance3D
	_assert(dots != null and dots.multimesh != null, "trajectory dots must use one MultiMesh owner")
	_assert(
		preview.find_children("*", "MultiMeshInstance3D", true, false).size() == 1,
		"the preview must own exactly one batched dot instance"
	)
	_assert(
		preview.find_children("TrajectoryDot*", "MeshInstance3D", true, false).is_empty(),
		"the preview must not recreate one MeshInstance3D per dot"
	)
	_assert(
		dots.multimesh.instance_count == TrajectoryPreview.MAXIMUM_DOTS,
		"the batch must allocate the fixed 96-dot capacity once"
	)

	var points := PackedVector3Array()
	for index in range(180):
		var t := float(index) / 179.0
		points.append(Vector3(t * 180.0, sin(t * PI) * 42.0, -t * 120.0))
	var collision := TrajectoryPrediction.new(
		TrajectoryPrediction.Kind.COLLISION,
		points[points.size() - 1],
		points,
		3.0,
		null,
		Vector3.UP,
		&"",
		null,
		points[points.size() - 1] - Vector3.UP * 0.18
	)
	preview.set_prediction(collision)
	_assert(
		preview.visible_sample_count() > 1 \
				and preview.visible_sample_count() <= TrajectoryPreview.MAXIMUM_DOTS,
		"sampling must stay inside the fixed batch capacity"
	)
	_assert(
		dots.multimesh.visible_instance_count == preview.visible_sample_count(),
		"only sampled transforms may be visible"
	)
	_assert(dots.custom_aabb.has_volume(), "visible trajectory points must refresh one culling bound")
	_assert(preview.is_processing(), "a visible impact marker may keep presentation processing enabled")
	preview.set_prediction_status(&"pending")
	_assert(
		is_equal_approx(dots.transparency, 0.48),
		"pending prediction must retain the last complete arc at subdued opacity"
	)
	_assert(
		not (preview.get_node("ImpactMarker") as MeshInstance3D).visible,
		"pending prediction must hide the stale impact marker"
	)
	_assert(
		preview.get_node_or_null("PredictionStatus") == null,
		"normal pending prediction must not create calculation or updating text"
	)
	preview.set_prediction_status(&"fireable")
	_assert(
		is_zero_approx(dots.transparency),
		"current prediction must restore the complete arc opacity"
	)
	_assert(
		(preview.get_node("ImpactMarker") as MeshInstance3D).visible,
		"current collision prediction must restore its exact impact marker"
	)

	var bounds_exit := TrajectoryPrediction.new(
		TrajectoryPrediction.Kind.BOUNDS_EXIT,
		points[points.size() - 1],
		points,
		3.0
	)
	preview.set_prediction(bounds_exit)
	preview.set_prediction_status(&"pending")
	_assert(
		not (preview.get_node("BoundsExitMarker") as Node3D).visible,
		"pending prediction must hide the stale bounds-exit marker"
	)

	var dot_mesh_id: int = dots.multimesh.mesh.get_instance_id()
	var dot_material_id: int = dots.multimesh.mesh.material.get_instance_id()
	preview._process(1.0 / 60.0)
	preview._process(1.0 / 60.0)
	_assert(
		dots.multimesh.mesh.get_instance_id() == dot_mesh_id \
				and dots.multimesh.mesh.material.get_instance_id() == dot_material_id,
		"marker updates must reuse the existing dot mesh and material"
	)

	preview.visible = false
	await process_frame
	_assert(not preview.is_processing(), "a hidden preview must suspend idle presentation work")
	preview.visible = true
	preview.set_prediction(null)
	_assert(
		dots.multimesh.visible_instance_count == 0 and not preview.is_processing(),
		"clearing prediction must hide the batch and suspend processing"
	)

	preview.queue_free()
	await process_frame
	if not _failed:
		print("Trajectory preview efficiency passed: one 96-instance batch, bounded samples, reused resources, and suspended idle work.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Trajectory preview efficiency check failed: %s" % message)
