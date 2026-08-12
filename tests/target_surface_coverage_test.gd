extends SceneTree

const FIXTURE_FACTORY := preload("res://tests/support/terrain_test_fixture_factory.gd")
const MASK_SIZE := StageGenerationContract.REQUIRED_MASK_SIZE

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var sparse_mask := PackedByteArray()
	sparse_mask.resize(MASK_SIZE * MASK_SIZE)
	sparse_mask[100 * MASK_SIZE + 100] = 255
	sparse_mask[340 * MASK_SIZE + 410] = 255
	var flat := FIXTURE_FACTORY.build_layout(FIXTURE_FACTORY.Kind.FLAT)
	var projected := TargetSurfaceCoverage.projected_texel_area(
		flat.local_bounds, MASK_SIZE
	)
	var flat_total := TargetSurfaceCoverage.total_target_surface_area(
		sparse_mask, flat.top_topology, flat.local_bounds, MASK_SIZE
	)
	_assert_true(
		is_equal_approx(flat_total, projected * 2.0),
		"two flat target texels must equal two projected texel areas"
	)

	var ramp := FIXTURE_FACTORY.build_layout(FIXTURE_FACTORY.Kind.RAMP)
	var ramp_total := TargetSurfaceCoverage.total_target_surface_area(
		sparse_mask, ramp.top_topology, ramp.local_bounds, MASK_SIZE
	)
	var expected_ramp := projected * 2.0 / cos(deg_to_rad(35.0))
	_assert_true(
		is_equal_approx(ramp_total, expected_ramp),
		"slope weighting must recover physical surface area from XZ projection"
	)
	_assert_true(
		ramp_total > flat_total,
		"equal projected paint on a slope must represent more physical area"
	)

	var checksum := TargetSurfaceCoverage.metadata_checksum(
		TargetSurfaceCoverage.METRIC_VERSION, ramp_total
	)
	_assert_true(
		TargetSurfaceCoverage.metadata_is_valid(
			TargetSurfaceCoverage.METRIC_VERSION, ramp_total, checksum
		),
		"metric-2 metadata must validate its deterministic checksum"
	)
	_assert_true(
		not TargetSurfaceCoverage.metadata_is_valid(
			TargetSurfaceCoverage.METRIC_VERSION, ramp_total + 1.0, checksum
		),
		"changed total surface area must fail closed"
	)
	_assert_true(
		TargetSurfaceCoverage.texel_surface_area(Vector3.DOWN, projected) < 0.0,
		"a non-playable downward normal must fail instead of being clamped"
	)

	if not _failed:
		print("Target surface coverage checks passed: physical slope weighting and fail-closed metadata.")
	quit(1 if _failed else 0)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Target surface coverage check failed: %s" % message)
