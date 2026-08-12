extends SceneTree

const PAINT_SHADER := preload("res://src/paint/terrain_paint.gdshader")
const PAINT_SURFACE_TUNING := preload("res://resources/paint/default_paint_surface_tuning.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var flat := _build_layout(&"flat")
	var paint_system := _configured_system(flat)
	var material := paint_system.get_meta(&"test_material") as ShaderMaterial
	_assert_true(material.get_shader_parameter(&"paint_mask") == paint_system.paint_texture(), "shader must bind the authoritative paint texture")
	_assert_true(material.get_shader_parameter(&"target_mask") == paint_system.target_texture(), "shader must bind the authoritative target texture")
	_assert_true(TargetMaskRasterizer.byte_checksum(paint_system.target_bytes_read_only()) == flat.target_mask_checksum, "PaintSystem target-byte copy must retain the layout checksum")
	_assert_true(paint_system.total_target_pixels() == 512 * 512, "full fixture mask must expose every pixel as target")
	_assert_true(paint_system.nontarget_texture() != null, "PaintSystem must expose the inverse non-target texture")
	var detached_target_bytes := paint_system.target_bytes_read_only()
	detached_target_bytes[0] = 0
	_assert_true(paint_system.target_bytes_read_only()[0] == 255, "returned target bytes must not mutate PaintSystem authority")

	var first_command := _radial_command(
		paint_system, 1, Vector3.ZERO, Vector3.UP, 4.0, RadialPaintMark.Kind.IMPACT
	)
	_assert_true(paint_system.queue_radial_paint_mark(first_command), "typed impact mark must enter the late queue")
	var first := paint_system.drain_pending_commands()
	var first_painted := paint_system.painted_target_pixels()
	_assert_true(int(first.written_pixel_count) > 0, "typed impact mark must write the authoritative mask")
	_assert_true(int(first.newly_painted_pixel_count) == first_painted, "threshold crossings must match authoritative coverage pixels")
	_assert_true(paint_system.coverage_percent() > 0.0, "typed impact mark must increase coverage")
	_assert_true(_visible_pixel_count(paint_system.paint_bytes_read_only()) == first_painted, "persistent visible pixels must equal painted target pixels")

	var overlap_command := _radial_command(
		paint_system, 2, Vector3.ZERO, Vector3.UP, 4.0, RadialPaintMark.Kind.IMPACT
	)
	_assert_true(paint_system.queue_radial_paint_mark(overlap_command), "a later overlapping mark must enter the queue")
	var overlap := paint_system.drain_pending_commands()
	_assert_true(int(overlap.newly_painted_pixel_count) == 0, "identical overlap must add zero coverage pixels")
	_assert_true(paint_system.painted_target_pixels() == first_painted, "overlap must not double-count coverage")
	paint_system.queue_free()

	var cliff := _build_layout(&"cliff")
	var cliff_paint := _configured_system(cliff)
	var cliff_command := _radial_command(
		cliff_paint, 1, Vector3(-2.0, 0.0, 0.0), Vector3.UP, 6.0,
		RadialPaintMark.Kind.IMPACT
	)
	_assert_true(cliff_paint.queue_radial_paint_mark(cliff_command), "cliff impact must enter the typed queue")
	var cliff_result := cliff_paint.drain_pending_commands()
	_assert_true(int(cliff_result.written_pixel_count) > 0, "near cliff face must paint its connected side")
	_assert_true(_painted_opposite_cliff_plateau(cliff_paint.paint_bytes_read_only()) == 0, "3D distance and connectivity must not paint the opposite cliff plateau")
	cliff_paint.queue_free()

	var slope := _build_layout(&"slope")
	var sweep_paint := _configured_system(slope)
	var from_point := Vector3(0.0, slope.height_at_local(0.0, -4.0), -4.0)
	var to_point := Vector3(0.0, slope.height_at_local(0.0, 4.0), 4.0)
	var sweep := _sweep_command(sweep_paint, 1, from_point, to_point, slope.normal_at_local(0.0, 0.0), 0.8)
	_assert_true(sweep_paint.queue_surface_paint_sweep(sweep), "typed surface sweep must enter the late queue")
	var swept := sweep_paint.drain_pending_commands()
	_assert_true(int(swept.written_pixel_count) > 0, "typed surface sweep must paint its measured contact interval")
	_assert_centerline_painted(sweep_paint, slope, -4.0, 4.0)
	_assert_true(sweep_paint.pending_work_count() == 0, "drain must leave no pending paint commands")
	sweep_paint.clear()
	_assert_true(is_zero_approx(sweep_paint.coverage_percent()), "clear must reset authoritative coverage")
	sweep_paint.queue_free()

	if not _failed:
		print("Phase 3 authoritative typed paint passed: radial overlap, cliff isolation, continuous sweep, and target-classified coverage.")
	quit(1 if _failed else 0)


func _configured_system(layout: GeneratedStageLayout) -> PaintSystem:
	var paint_system := PaintSystem.new()
	root.add_child(paint_system)
	var material := ShaderMaterial.new()
	material.shader = PAINT_SHADER
	paint_system.configure(
		layout.local_bounds, 0.0, material, Color(0.03, 0.38, 1.0), layout,
		PAINT_SURFACE_TUNING
	)
	var top_body := StaticBody3D.new()
	top_body.name = "AuthoritativeTopBody"
	paint_system.add_child(top_body)
	paint_system.configure_top_surface_identity(
		top_body.get_rid(),
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TrajectoryHitIdentity.TERRAIN_TOP_SHAPE_ID,
		0
	)
	paint_system.set_meta(&"test_material", material)
	return paint_system


func _radial_command(
		paint_system: PaintSystem,
		physics_tick: int,
		center: Vector3,
		normal: Vector3,
		radius: float,
		kind: RadialPaintMark.Kind
) -> RadialPaintMark:
	var identity := paint_system.authoritative_top_surface_identity()
	return RadialPaintMark.new(
		physics_tick, 0, 0, 0, center, normal, radius,
		identity.collider_rid, identity.contact_owner_id, identity.contact_shape_id,
		int(identity.collider_shape_index), kind
	)


func _sweep_command(
		paint_system: PaintSystem,
		physics_tick: int,
		from_point: Vector3,
		to_point: Vector3,
		normal: Vector3,
		radius: float
) -> SurfacePaintSweep:
	var identity := paint_system.authoritative_top_surface_identity()
	return SurfacePaintSweep.new(
		physics_tick, 0, 0, 0, from_point, to_point, normal, normal, radius,
		identity.collider_rid, identity.contact_owner_id, identity.contact_shape_id,
		int(identity.collider_shape_index), false
	)


func _assert_centerline_painted(
		paint_system: PaintSystem,
		layout: GeneratedStageLayout,
		from_z: float,
		to_z: float
) -> void:
	var bytes := paint_system.paint_bytes_read_only()
	for sample_index in range(17):
		var z := lerpf(from_z, to_z, float(sample_index) / 16.0)
		var uv := (Vector2(0.0, z) - layout.local_bounds.position) / layout.local_bounds.size
		var pixel := PaintMaskAddressing.snap_uv_to_pixel(uv, PaintSystem.MASK_SIZE)
		_assert_true(
			bytes[pixel.y * PaintSystem.MASK_SIZE + pixel.x] >= PAINT_SURFACE_TUNING.painted_threshold_byte,
			"continuous surface sweep must leave no blank centerline sample"
		)


func _build_layout(kind: StringName) -> GeneratedStageLayout:
	var layout := GeneratedStageLayout.new()
	layout.profile_id = &"paint_narrow_fixture"
	layout.profile_version = StageGenerationContract.CONTRACT_VERSION
	layout.layout_version = StageGenerationContract.CONTRACT_VERSION
	layout.terrain_seed = 1
	layout.cell_count = Vector2i(64, 64)
	layout.local_bounds = Rect2(Vector2(-32.0, -32.0), Vector2(64.0, 64.0))
	layout.heights.resize(65 * 65)
	for z_index in range(65):
		var z := -32.0 + float(z_index)
		for x_index in range(65):
			var x := -32.0 + float(x_index)
			var height := 0.0
			if kind == &"cliff" and x > 0.0:
				height = 8.0
			elif kind == &"slope":
				height = -0.08 * z + 3.0
			layout.heights[z_index * 65 + x_index] = height
	var active_cells := PackedByteArray()
	active_cells.resize(layout.cell_count.x * layout.cell_count.y)
	active_cells.fill(1)
	assert(layout.install_footprint(active_cells))
	layout.top_topology = TerrainTopTopology.build(
		layout.cell_count, layout.local_bounds, layout.heights, active_cells
	)
	var summit_id := GeneratedRouteNode.summit_id(&"paint_narrow_fixture")
	var exit_id := GeneratedRouteNode.route_node_id(&"paint_narrow_fixture", 0, 1)
	var summit := GeneratedRouteNode.new(
		summit_id, Vector3(0, 0, -20), -1, 0, GeneratedRouteNode.Kind.SUMMIT
	)
	var exit := GeneratedRouteNode.new(
		exit_id, Vector3(0, 0, 20), 0, 1, GeneratedRouteNode.Kind.EXIT
	)
	var edge := GeneratedRouteEdge.new(
		GeneratedRouteEdge.stable_id(&"paint_narrow_fixture", 0, 0),
		summit_id, exit_id, 0, 0, StageRouteProfile.Role.PRIMARY, 16.0
	)
	layout.route_graph = GeneratedRouteGraph.new([summit, exit], [edge])
	layout.play_bounds = PlayBoundsSpec.new()
	var target_mask := PackedByteArray()
	target_mask.resize(512 * 512)
	target_mask.fill(255)
	assert(
		TerrainTestFixtureFactory.install_target_mask_with_coverage(
			layout, target_mask
		)
	)
	return layout


func _visible_pixel_count(bytes: PackedByteArray) -> int:
	var count := 0
	for byte in bytes:
		if byte > 0:
			count += 1
	return count


func _painted_opposite_cliff_plateau(bytes: PackedByteArray) -> int:
	var count := 0
	for y in range(512):
		for x in range(264, 512):
			if bytes[y * 512 + x] > 0:
				count += 1
	return count


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Phase 3 paint check failed: %s" % message)
