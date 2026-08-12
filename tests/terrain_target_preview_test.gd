extends SceneTree

const TerrainTargetPreviewScript = preload("res://src/cannon/terrain_target_preview.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 20.0, 80.0)
	camera.current = true
	world.add_child(camera)
	var preview := TerrainTargetPreviewScript.new()
	world.add_child(preview)
	await process_frame

	_assert(
		preview.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON,
		"target movement must use physics interpolation"
	)
	_assert(not preview.visible, "target preview must start hidden")

	var point := Vector3(12.0, 6.0, -84.0)
	var normal := Vector3(0.2, 0.96, 0.18).normalized()
	preview.present_target(point, normal, TerrainTargetPreviewScript.STATE_SELECTED)
	_assert(preview.visible, "a selected target must show its surface ring")
	_assert(
		preview.global_position.is_equal_approx(point + normal * TerrainTargetPreviewScript.SURFACE_OFFSET),
		"the target marker must remain surface-bound with only a small depth offset"
	)
	_assert(
		preview.global_basis.y.normalized().is_equal_approx(normal),
		"the target marker must orient its face to the terrain normal"
	)
	_assert(
		(preview.get_node("SelectedRing") as MeshInstance3D).visible,
		"selected state must use a ring"
	)
	_assert(
		not (preview.get_node("PendingTicks") as Node3D).visible
				and not (preview.get_node("ConfirmedCenter") as MeshInstance3D).visible
				and not (preview.get_node("RejectedX") as Node3D).visible,
		"selected state must not claim pending, confirmed, or rejected status"
	)

	preview.set_visual_state(TerrainTargetPreviewScript.STATE_PENDING)
	_assert(
		(preview.get_node("PendingTicks") as Node3D).visible
				and not (preview.get_node("ConfirmedCenter") as MeshInstance3D).visible,
		"pending state must add shape-based ticks without a confirmed center"
	)
	preview.set_visual_state(TerrainTargetPreviewScript.STATE_CONFIRMED)
	_assert(
		(preview.get_node("ConfirmedCenter") as MeshInstance3D).visible
				and not (preview.get_node("PendingTicks") as Node3D).visible,
		"confirmed state must add a center treatment"
	)
	preview.set_visual_state(TerrainTargetPreviewScript.STATE_REJECTED)
	_assert(
		(preview.get_node("RejectedX") as Node3D).visible
				and not (preview.get_node("ConfirmedCenter") as MeshInstance3D).visible,
		"rejected state must use an X that does not depend on color"
	)

	for geometry in preview.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := geometry as MeshInstance3D
		var material := mesh_instance.mesh.material as StandardMaterial3D
		_assert(material != null and not material.no_depth_test,
				"every target shape must remain depth-tested")

	preview._process(1.0 / 60.0)
	_assert(
		preview.scale.x > 1.0 and preview.scale.x <= TerrainTargetPreviewScript.MAXIMUM_SCALE,
		"camera-distance scaling must keep distant targets readable inside its cap"
	)
	preview.clear_target()
	_assert(not preview.visible and not preview.is_processing(),
			"clearing the display must hide it and suspend idle work")

	world.queue_free()
	await process_frame
	if not _failed:
		print("Terrain target preview passed: surface pose, interpolated motion, shape states, depth, and distance scale.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Terrain target preview check failed: %s" % message)
