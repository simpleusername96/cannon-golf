extends SceneTree

const FIXTURE_FACTORY := preload("res://tests/support/terrain_test_fixture_factory.gd")
const PAINT_SHADER := preload("res://src/paint/terrain_paint.gdshader")
const SURFACE_TUNING := preload("res://resources/paint/default_paint_surface_tuning.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var layout := FIXTURE_FACTORY.build_layout(FIXTURE_FACTORY.Kind.FLAT)
	var target_mask := PackedByteArray()
	target_mask.resize(PaintSystem.MASK_SIZE * PaintSystem.MASK_SIZE)
	target_mask.fill(255)
	_assert_true(
		FIXTURE_FACTORY.install_target_mask_with_coverage(layout, target_mask),
		"publication fixture must install metric-2 target metadata"
	)
	var body_rid := PhysicsServer3D.body_create()
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
		body_rid,
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID,
		0
	)
	var publications: Array[Dictionary] = []
	paint.coverage_changed.connect(func(value: float) -> void:
		publications.append({
			"coverage": value,
			"texture_batches": paint.texture_upload_batch_count(),
			"dirty": paint.dirty_region_read_only(),
		})
	)
	var point := Vector3(0.0, layout.height_at_local(0.0, 0.0), 0.0)
	var command := RadialPaintMark.new(
		1,
		0,
		0,
		0,
		point,
		layout.normal_at_local(0.0, 0.0),
		4.0,
		body_rid,
		TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		TerrainSurface.TOP_SHAPE_ID,
		0,
		RadialPaintMark.Kind.IMPACT
	)
	_assert_true(paint.queue_radial_paint_mark(command), "valid target paint must queue")
	paint.drain_pending_commands()
	_assert_true(
		paint.coverage_percent() > 0.0 and publications.is_empty(),
		"coverage must not publish ahead of its dirty paint texture"
	)
	paint.force_flush_paint_texture()
	_assert_true(publications.size() == 1, "one dirty texture batch must publish coverage once")
	if publications.size() == 1:
		_assert_true(
			int(publications[0].texture_batches) == 1 \
					and not (publications[0].dirty as Rect2i).has_area(),
			"coverage callback must observe the completed texture batch"
		)
		_assert_true(
			is_equal_approx(float(publications[0].coverage), paint.coverage_percent()),
			"published coverage must match the authoritative weighted numerator"
		)
	paint.free()
	PhysicsServer3D.free_rid(body_rid)
	if not _failed:
		print("Coverage publication checks passed: paint texture and weighted percentage publish together.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Coverage publication check failed: %s" % message)
