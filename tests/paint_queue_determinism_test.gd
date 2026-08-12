extends SceneTree

const FIXTURE_FACTORY := preload("res://tests/support/terrain_test_fixture_factory.gd")
const PAINT_SHADER := preload("res://src/paint/terrain_paint.gdshader")
const SURFACE_TUNING := preload("res://resources/paint/default_paint_surface_tuning.tres")

var _failed := false
var _top_body_rid := RID()


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_top_body_rid = PhysicsServer3D.body_create()
	var flat := _configured_system(FIXTURE_FACTORY.Kind.FLAT)
	_assert_queue_order_and_dirty_batch(flat)
	flat.clear()
	_assert_width_and_centerline(flat, 4.0, 8.0, "flat parent")
	flat.clear()
	_assert_width_and_centerline(flat, 3.12, 6.24, "flat child")
	flat.clear()
	_assert_gap_and_overlap_rules(flat)
	flat.free()

	var ramp := _configured_system(FIXTURE_FACTORY.Kind.RAMP)
	_assert_width_and_centerline(ramp, 4.0, 8.0, "ramp parent")
	ramp.free()

	var partial_target_mask := PackedByteArray()
	partial_target_mask.resize(PaintSystem.MASK_SIZE * PaintSystem.MASK_SIZE)
	partial_target_mask.fill(255)
	for pixel_y in range(PaintSystem.MASK_SIZE):
		for pixel_x in range(246, 266):
			partial_target_mask[pixel_y * PaintSystem.MASK_SIZE + pixel_x] = 0
	var partial_target := _configured_system(FIXTURE_FACTORY.Kind.FLAT, partial_target_mask)
	_assert_target_mask_classifies_coverage_without_clipping_paint(partial_target)
	partial_target.free()

	var disconnected_layout := _build_disconnected_layout()
	var disconnected_mask := _paintable_top_mask(disconnected_layout)
	var disconnected := _configured_layout(disconnected_layout, disconnected_mask)
	_assert_disconnected_sweep_falls_back_to_endpoints(disconnected)
	disconnected.free()

	PhysicsServer3D.free_rid(_top_body_rid)
	if not _failed:
		print("Task 1.4 paint queue passed: ordered late drain, continuous 3D footprints, target-classified coverage, geometry gap rules, checksum, and one upload batch.")
	quit(1 if _failed else 0)


func _assert_queue_order_and_dirty_batch(paint: PaintSystem) -> void:
	var layout := paint.generated_layout_read_only()
	var applied: Array[Vector3i] = []
	var drained := {"tick": -1, "count": -1, "checksum": 0}
	paint.paint_command_applied.connect(func(command, _written: int, _newly: int) -> void:
		applied.append(Vector3i(command.physics_tick, command.spawn_ordinal, command.sequence))
	)
	paint.paint_commands_drained.connect(func(tick: int, count: int, checksum: int) -> void:
		drained.tick = tick
		drained.count = count
		drained.checksum = checksum
	)
	var impact := _radial(layout, 8, 0, 0, Vector2(0.0, -4.0), 4.0)
	var sweep := _sweep(layout, 9, 0, 1, Vector2(0.0, -4.0), Vector2(0.0, 4.0), 4.0)
	_assert_true(paint.queue_surface_paint_sweep(sweep), "valid sweep must enter the late queue")
	_assert_true(paint.queue_radial_paint_mark(impact), "valid radial mark must enter the late queue")
	_assert_true(not paint.queue_radial_paint_mark(impact), "duplicate tick/ordinal/sequence must be rejected")
	var wrong_rid := PhysicsServer3D.body_create()
	var wrong_body := RadialPaintMark.new(
		10, 0, 0, 2, impact.center, impact.normal, 4.0, wrong_rid,
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID, TerrainSurface.TOP_SHAPE_ID, 0,
		RadialPaintMark.Kind.IMPACT
	)
	_assert_true(not paint.queue_radial_paint_mark(wrong_body), "a different collider RID must not paint terrain")
	PhysicsServer3D.free_rid(wrong_rid)
	_assert_true(paint.pending_work_count() == 2, "only the two unique authoritative commands may remain queued")
	var result := paint.drain_pending_commands()
	_assert_true(applied == [Vector3i(8, 0, 0), Vector3i(9, 0, 1)], "drain must sort by physics tick, spawn ordinal, then sequence")
	_assert_true(int(result.command_count) == 2 and int(result.last_drained_physics_tick) == 9, "one drain must cover both sorted commands through tick 9")
	_assert_true(int(drained.tick) == 9 and int(drained.count) == 2, "drain signal must expose its covered tick and command count")
	_assert_true(int(drained.checksum) == paint.paint_mask_checksum(), "drain signal checksum must match the authoritative incremental mask checksum")
	_assert_true(paint.texture_upload_batch_count() == 0 and paint.dirty_region_read_only().has_area(), "drain must batch dirty bytes without an immediate texture upload")
	var persistent_texture := paint.paint_texture()
	paint.flush_pending()
	_assert_true(paint.texture_upload_batch_count() == 1, "flush must upload all dirty commands in one batch")
	_assert_true(
		paint.paint_texture() == persistent_texture,
		"forced flush must update the persistent runtime texture without allocation or rebinding"
	)
	_assert_coverage_matches_threshold_bytes(paint)


func _assert_width_and_centerline(
		paint: PaintSystem,
		radius: float,
		expected_width: float,
		label: String
) -> void:
	var layout := paint.generated_layout_read_only()
	var command := _sweep(layout, 1, 0, 0, Vector2(0.0, -8.0), Vector2(0.0, 8.0), radius)
	_assert_true(paint.queue_surface_paint_sweep(command), "%s sweep must queue" % label)
	paint.drain_pending_commands()
	var bytes := paint.paint_bytes_read_only()
	var center_pixel := _world_to_pixel(Vector2.ZERO, layout.local_bounds)
	var first_x := -1
	var last_x := -1
	for pixel_x in range(PaintSystem.MASK_SIZE):
		if bytes[center_pixel.y * PaintSystem.MASK_SIZE + pixel_x] >= SURFACE_TUNING.painted_threshold_byte:
			if first_x < 0:
				first_x = pixel_x
			last_x = pixel_x
	_assert_true(first_x >= 0 and last_x >= first_x, "%s must paint a measurable tangent cross-section" % label)
	if first_x >= 0:
		var first_xz := _pixel_center_world(Vector2i(first_x, center_pixel.y), layout.local_bounds)
		var last_xz := _pixel_center_world(Vector2i(last_x, center_pixel.y), layout.local_bounds)
		var first_point := Vector3(first_xz.x, layout.height_at_local(first_xz.x, first_xz.y), first_xz.y)
		var last_point := Vector3(last_xz.x, layout.height_at_local(last_xz.x, last_xz.y), last_xz.y)
		var measured_width := first_point.distance_to(last_point)
		_assert_true(absf(measured_width - expected_width) <= 0.5, "%s tangent width %.3f must be %.2f +/- 0.5 m" % [label, measured_width, expected_width])
	for pixel_y in range(_world_to_pixel(Vector2(0.0, -8.0), layout.local_bounds).y, _world_to_pixel(Vector2(0.0, 8.0), layout.local_bounds).y + 1):
		var index := pixel_y * PaintSystem.MASK_SIZE + center_pixel.x
		_assert_true(bytes[index] >= SURFACE_TUNING.painted_threshold_byte, "%s continuous sweep must leave no blank centerline texel" % label)
	_assert_coverage_matches_threshold_bytes(paint)


func _assert_gap_and_overlap_rules(paint: PaintSystem) -> void:
	var layout := paint.generated_layout_read_only()
	var bridged := _sweep(layout, 1, 0, 0, Vector2(0.0, -7.0), Vector2(0.0, 7.0), 4.0, true)
	_assert_true(paint.queue_surface_paint_sweep(bridged), "producer-proven two-tick bridge must queue")
	paint.drain_pending_commands()
	var center := _world_to_pixel(Vector2.ZERO, layout.local_bounds)
	_assert_true(paint.paint_bytes_read_only()[center.y * PaintSystem.MASK_SIZE + center.x] >= SURFACE_TUNING.painted_threshold_byte, "a proven micro-gap sweep must remain continuous")

	paint.clear()
	var left := _radial(layout, 1, 0, 0, Vector2(0.0, -9.0), 4.0)
	var right := _radial(layout, 1, 1, 0, Vector2(0.0, 9.0), 4.0)
	_assert_true(paint.queue_radial_paint_mark(right) and paint.queue_radial_paint_mark(left), "two recontact marks must queue")
	paint.drain_pending_commands()
	_assert_true(paint.paint_bytes_read_only()[center.y * PaintSystem.MASK_SIZE + center.x] == 0, "a real airborne hop with no sweep command must stay blank")

	paint.clear()
	var first := _radial(layout, 1, 0, 0, Vector2.ZERO, 4.0)
	paint.queue_radial_paint_mark(first)
	paint.drain_pending_commands()
	var painted_once := paint.painted_target_pixels()
	var checksum_once := paint.paint_mask_checksum()
	var overlap := _radial(layout, 2, 0, 1, Vector2.ZERO, 4.0)
	paint.queue_radial_paint_mark(overlap)
	var second_result := paint.drain_pending_commands()
	_assert_true(paint.painted_target_pixels() == painted_once and int(second_result.newly_painted_pixel_count) == 0, "overlap must count each target texel exactly once")
	_assert_true(paint.paint_mask_checksum() == checksum_once, "bytewise max overlap must leave the authoritative checksum unchanged")
	_assert_coverage_matches_threshold_bytes(paint)


func _assert_disconnected_sweep_falls_back_to_endpoints(paint: PaintSystem) -> void:
	var layout := paint.generated_layout_read_only()
	var command := _sweep(layout, 1, 0, 0, Vector2(-10.0, 0.0), Vector2(10.0, 0.0), 2.0)
	_assert_true(paint.queue_surface_paint_sweep(command), "disconnected sweep command remains a valid measured intent")
	paint.drain_pending_commands()
	var bytes := paint.paint_bytes_read_only()
	var left_endpoint := _world_to_pixel(Vector2(-10.0, 0.0), layout.local_bounds)
	var right_endpoint := _world_to_pixel(Vector2(10.0, 0.0), layout.local_bounds)
	var untraversed_left_segment := _world_to_pixel(Vector2(-5.0, 0.0), layout.local_bounds)
	_assert_true(bytes[left_endpoint.y * PaintSystem.MASK_SIZE + left_endpoint.x] >= SURFACE_TUNING.painted_threshold_byte, "disconnected sweep must preserve its valid left endpoint disc")
	_assert_true(bytes[right_endpoint.y * PaintSystem.MASK_SIZE + right_endpoint.x] >= SURFACE_TUNING.painted_threshold_byte, "disconnected sweep must preserve its valid right endpoint disc")
	_assert_true(bytes[untraversed_left_segment.y * PaintSystem.MASK_SIZE + untraversed_left_segment.x] == 0, "disconnected endpoints must not authorize the intervening chord")
	_assert_coverage_matches_threshold_bytes(paint)


func _assert_target_mask_classifies_coverage_without_clipping_paint(paint: PaintSystem) -> void:
	var layout := paint.generated_layout_read_only()
	var command := _sweep(layout, 1, 0, 0, Vector2(-10.0, 0.0), Vector2(10.0, 0.0), 2.0)
	_assert_true(paint.queue_surface_paint_sweep(command), "partial-target sweep must queue")
	var result := paint.drain_pending_commands()
	var bytes := paint.paint_bytes_read_only()
	var target := paint.target_bytes_read_only()
	var nontarget_center := _world_to_pixel(Vector2.ZERO, layout.local_bounds)
	var target_segment := _world_to_pixel(Vector2(-5.0, 0.0), layout.local_bounds)
	var nontarget_index := nontarget_center.y * PaintSystem.MASK_SIZE + nontarget_center.x
	var target_index := target_segment.y * PaintSystem.MASK_SIZE + target_segment.x
	_assert_true(target[nontarget_index] == 0, "partial-target fixture center must be outside scoreable coverage")
	_assert_true(bytes[nontarget_index] >= SURFACE_TUNING.painted_threshold_byte, "valid non-target mountain top traversed by a sweep must retain visible paint")
	_assert_true(target[target_index] >= SURFACE_TUNING.painted_threshold_byte and bytes[target_index] >= SURFACE_TUNING.painted_threshold_byte, "the same sweep must paint its target segment")
	_assert_true(paint.persistent_nontarget_pixel_count() > 0, "partial-target sweep must persist a material non-target paint region")
	_assert_true(int(result.written_pixel_count) > int(result.newly_painted_pixel_count), "non-target paint writes must not increment scoreable coverage")
	_assert_coverage_matches_threshold_bytes(paint)


func _configured_system(kind: int, target_mask: PackedByteArray = PackedByteArray()) -> PaintSystem:
	var layout: GeneratedStageLayout = FIXTURE_FACTORY.build_layout(kind)
	layout.profile_version = StageGenerationContract.CONTRACT_VERSION
	layout.layout_version = StageGenerationContract.CONTRACT_VERSION
	if not layout.has_valid_footprint():
		var full_footprint := PackedByteArray()
		full_footprint.resize(layout.cell_count.x * layout.cell_count.y)
		full_footprint.fill(1)
		assert(layout.install_footprint(full_footprint))
	return _configured_layout(layout, target_mask)


func _configured_layout(
		layout: GeneratedStageLayout,
		target_mask: PackedByteArray = PackedByteArray()
) -> PaintSystem:
	var installed_mask := target_mask
	if installed_mask.is_empty():
		installed_mask.resize(PaintSystem.MASK_SIZE * PaintSystem.MASK_SIZE)
		installed_mask.fill(255)
	assert(FIXTURE_FACTORY.install_target_mask_with_coverage(layout, installed_mask))
	var paint := PaintSystem.new()
	root.add_child(paint)
	var material := ShaderMaterial.new()
	material.shader = PAINT_SHADER
	paint.configure(
		layout.local_bounds,
		0.0,
		material,
		Color(0.03, 0.38, 1.0),
		layout,
		SURFACE_TUNING
	)
	paint.configure_top_surface_identity(
		_top_body_rid,
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID,
		0
	)
	_assert_true(material.get_shader_parameter(&"paint_mask") == paint.paint_texture(), "terrain shader must sample PaintSystem's authoritative texture")
	_assert_true(material.get_shader_parameter(&"target_mask") == paint.target_texture(), "terrain shader must sample PaintSystem's immutable target mask")
	return paint


func _build_disconnected_layout() -> GeneratedStageLayout:
	var source: GeneratedStageLayout = FIXTURE_FACTORY.build_layout(FIXTURE_FACTORY.Kind.FLAT)
	var layout := GeneratedStageLayout.new()
	layout.profile_id = source.profile_id
	layout.profile_version = StageGenerationContract.CONTRACT_VERSION
	layout.layout_version = StageGenerationContract.CONTRACT_VERSION
	layout.terrain_seed = source.terrain_seed
	layout.cell_count = source.cell_count
	layout.local_bounds = source.local_bounds
	layout.heights = source.heights.duplicate()
	layout.route_graph = source.route_graph
	layout.play_bounds = source.play_bounds
	var active_cells := PackedByteArray()
	active_cells.resize(layout.cell_count.x * layout.cell_count.y)
	active_cells.fill(1)
	for cell_y in range(layout.cell_count.y):
		for cell_x in range(5, 7):
			active_cells[cell_y * layout.cell_count.x + cell_x] = 0
	assert(layout.install_footprint(active_cells))
	layout.top_topology = TerrainTopTopology.build(
		layout.cell_count, layout.local_bounds, layout.heights, active_cells
	)
	return layout


func _paintable_top_mask(layout: GeneratedStageLayout) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(PaintSystem.MASK_SIZE * PaintSystem.MASK_SIZE)
	for pixel_y in range(PaintSystem.MASK_SIZE):
		for pixel_x in range(PaintSystem.MASK_SIZE):
			var local_xz := _pixel_center_world(Vector2i(pixel_x, pixel_y), layout.local_bounds)
			if not layout.surface_sample_at_local(local_xz.x, local_xz.y, false).is_empty():
				mask[pixel_y * PaintSystem.MASK_SIZE + pixel_x] = 255
	return mask


func _radial(
		layout: GeneratedStageLayout,
		tick: int,
		ordinal: int,
		sequence: int,
		local_xz: Vector2,
		radius: float
) -> RadialPaintMark:
	var point := Vector3(local_xz.x, layout.height_at_local(local_xz.x, local_xz.y), local_xz.y)
	return RadialPaintMark.new(
		tick, ordinal, 0, sequence, point,
		layout.normal_at_local(local_xz.x, local_xz.y), radius, _top_body_rid,
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID, TerrainSurface.TOP_SHAPE_ID, 0,
		RadialPaintMark.Kind.IMPACT
	)


func _sweep(
		layout: GeneratedStageLayout,
		tick: int,
		ordinal: int,
		sequence: int,
		from_xz: Vector2,
		to_xz: Vector2,
		radius: float,
		bridged_gap: bool = false
) -> SurfacePaintSweep:
	var from_point := Vector3(from_xz.x, layout.height_at_local(from_xz.x, from_xz.y), from_xz.y)
	var to_point := Vector3(to_xz.x, layout.height_at_local(to_xz.x, to_xz.y), to_xz.y)
	return SurfacePaintSweep.new(
		tick, ordinal, 0, sequence, from_point, to_point,
		layout.normal_at_local(from_xz.x, from_xz.y),
		layout.normal_at_local(to_xz.x, to_xz.y),
		radius, _top_body_rid, TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID, 0, bridged_gap
	)


func _assert_coverage_matches_threshold_bytes(paint: PaintSystem) -> void:
	var bytes := paint.paint_bytes_read_only()
	var target := paint.target_bytes_read_only()
	var counted := 0
	for index in range(bytes.size()):
		if target[index] >= SURFACE_TUNING.painted_threshold_byte \
				and bytes[index] >= SURFACE_TUNING.painted_threshold_byte:
			counted += 1
	_assert_true(counted == paint.painted_target_pixels(), "incremental coverage count must equal thresholded authoritative bytes")
	var expected_percent := 100.0 * float(counted) / float(paint.total_target_pixels())
	_assert_true(is_equal_approx(expected_percent, paint.coverage_percent()), "coverage percentage must derive from the same thresholded target bytes")


func _world_to_pixel(world_xz: Vector2, bounds: Rect2) -> Vector2i:
	return PaintMaskAddressing.snap_uv_to_pixel((world_xz - bounds.position) / bounds.size, PaintSystem.MASK_SIZE)


func _pixel_center_world(pixel: Vector2i, bounds: Rect2) -> Vector2:
	return bounds.position + Vector2(
		(float(pixel.x) + 0.5) / float(PaintSystem.MASK_SIZE),
		(float(pixel.y) + 0.5) / float(PaintSystem.MASK_SIZE)
	) * bounds.size


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Task 1.4 paint check failed: %s" % message)
