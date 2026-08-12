extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_assert_visual_radius_contract()
	if "--asset-bounds-only" in OS.get_cmdline_user_args():
		quit(1 if _failed else 0)
		return
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	var stages: Array[StageData] = [catalog.get_stage(&"stage_01")]
	for stage in stages:
		var baked := load(catalog.get_layout_path(stage.stage_id)) as BakedStageLayoutData
		var layout := StageLayoutBakeCodec.hydrate(baked, stage)
		var repeated := StageLayoutBakeCodec.hydrate(baked, stage)
		_assert_true(layout != null and repeated != null, "%s requires a finalized deterministic layout" % stage.stage_id)
		if layout == null or repeated == null:
			continue
		var decorations := layout.decoration_placements
		var target_before := layout.target_mask
		var expected_count: int = [10, 14, 18][stage.stage_number - 1]
		_assert_true(decorations.size() == expected_count, "%s must place %d decorations, got %d" % [stage.stage_id, expected_count, decorations.size()])
		_assert_true(repeated.decoration_placements.size() == decorations.size(), "%s decoration count must repeat" % stage.stage_id)
		for index in range(decorations.size()):
			var decoration: DecorationPlacement = decorations[index]
			var repeated_decoration: DecorationPlacement = repeated.decoration_placements[index]
			_assert_true(layout.local_bounds.has_point(decoration.local_xz), "decoration must remain on the non-target terrain top")
			_assert_true(layout.normal_at_local(decoration.local_xz.x, decoration.local_xz.y).y >= cos(deg_to_rad(42.0)), "decoration slope must pass")
			_assert_true(decoration.model_id == repeated_decoration.model_id and decoration.local_xz.is_equal_approx(repeated_decoration.local_xz), "%s decorations must be deterministic" % stage.stage_id)
			var nearest := layout.route_graph.nearest_edge(decoration.local_xz)
			_assert_true(nearest.edge is GeneratedRouteEdge, "%s decoration query must resolve through the immutable graph" % stage.stage_id)
			var radius := _visual_radius(decoration)
			var edge := nearest.edge as GeneratedRouteEdge
			_assert_true(
				float(nearest.distance) > edge.width * 0.5 \
						+ minf(
							stage.generation_profile.generation_contract.support_distance,
							1.5
						) + radius,
				"%s decoration visual bounds must preserve the authored route clearance" % stage.stage_id
			)
			_assert_true(_visual_circle_is_outside_target(layout, decoration.local_xz, radius), "%s decoration visual bounds must stay outside the target mask" % stage.stage_id)
			for prior_index in range(index):
				var prior: DecorationPlacement = decorations[prior_index]
				_assert_true(decoration.local_xz.distance_to(prior.local_xz) >= radius + _visual_radius(prior), "decoration visual bounds must preserve spacing")
		_assert_true(target_before == layout.target_mask, "%s decorations must not cut target-mask holes" % stage.stage_id)
		print("%s decorations=%d terrain_seed=%d" % [stage.stage_id, decorations.size(), layout.terrain_seed])
	quit(1 if _failed else 0)


func _assert_visual_radius_contract() -> void:
	for model_id in EnvironmentDressing.MODEL_PATHS:
		var packed := load(EnvironmentDressing.MODEL_PATHS[model_id]) as PackedScene
		_assert_true(packed != null, "%s approved decoration asset must load" % model_id)
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		root.add_child(instance)
		var measured_radius := _measured_xz_radius(instance, instance)
		var unit_placement := DecorationPlacement.new(model_id, Vector2.ZERO, 0.0, 1.0)
		var configured_radius := _visual_radius(unit_placement) - 0.5
		_assert_true(
			configured_radius + 0.0001 >= measured_radius,
			"%s configured XZ radius %.3f must enclose measured visual radius %.3f" % [
				model_id, configured_radius, measured_radius,
			]
		)
		instance.free()


func _measured_xz_radius(node: Node, root_node: Node3D) -> float:
	var result := 0.0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var local_corner := bounds.position + Vector3(
				bounds.size.x if (corner_index & 1) != 0 else 0.0,
				bounds.size.y if (corner_index & 2) != 0 else 0.0,
				bounds.size.z if (corner_index & 4) != 0 else 0.0
			)
			var root_corner := root_node.to_local(mesh_instance.to_global(local_corner))
			result = maxf(result, Vector2(root_corner.x, root_corner.z).length())
	for child in node.get_children():
		result = maxf(result, _measured_xz_radius(child, root_node))
	return result


func _visual_radius(decoration: DecorationPlacement) -> float:
	var base_radius := 0.36
	if decoration.model_id == &"tree_pineTallA":
		base_radius = 0.45
	elif decoration.model_id == &"rock_smallA":
		base_radius = 0.40
	elif decoration.model_id == &"rock_largeA":
		base_radius = 0.80
	return base_radius * decoration.uniform_scale + 0.5


func _visual_circle_is_outside_target(
		layout: GeneratedStageLayout,
		center: Vector2,
		radius: float
) -> bool:
	var mask := layout.target_mask
	var mask_size := StageGenerationContract.REQUIRED_MASK_SIZE
	var pixel_size := layout.local_bounds.size / float(mask_size)
	var pixel_half_diagonal := pixel_size.length() * 0.5
	var minimum := center - Vector2.ONE * radius
	var maximum := center + Vector2.ONE * radius
	var minimum_pixel := Vector2i(
		clampi(floori((minimum.x - layout.local_bounds.position.x) / pixel_size.x), 0, mask_size - 1),
		clampi(floori((minimum.y - layout.local_bounds.position.y) / pixel_size.y), 0, mask_size - 1)
	)
	var maximum_pixel := Vector2i(
		clampi(floori((maximum.x - layout.local_bounds.position.x) / pixel_size.x), 0, mask_size - 1),
		clampi(floori((maximum.y - layout.local_bounds.position.y) / pixel_size.y), 0, mask_size - 1)
	)
	for pixel_y in range(minimum_pixel.y, maximum_pixel.y + 1):
		for pixel_x in range(minimum_pixel.x, maximum_pixel.x + 1):
			if mask[pixel_y * mask_size + pixel_x] < 128:
				continue
			var pixel_center := layout.local_bounds.position + Vector2(
				(float(pixel_x) + 0.5) * pixel_size.x,
				(float(pixel_y) + 0.5) * pixel_size.y
			)
			if center.distance_to(pixel_center) <= radius + pixel_half_diagonal:
				return false
	return true


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Decoration placement check failed: %s" % message)
