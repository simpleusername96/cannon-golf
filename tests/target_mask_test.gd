extends SceneTree

const ROUTE_GRAPH_RESOLVER := preload("res://src/stage_generation/route_graph_resolver.gd")
const ROUTE_GRAPH_MOUNTAIN_SYNTHESIZER := preload(
	"res://src/stage_generation/route_graph_mountain_synthesizer.gd"
)
var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var stage: StageData = StageCatalog.get_stage(&"stage_01")
	_assert_true(stage != null, "the canonical Stage 01 catalog entry must load")
	if stage == null:
		quit(1)
		return
	var profile := stage.generation_profile
	var result := {}
	var elapsed_ms := 0.0
	var accepted_attempt := -2
	for attempt_index in range(profile.generation_contract.attempt_count):
		var attempt_seed := int((profile.base_seed + attempt_index * profile.generation_contract.attempt_seed_stride) & 0x7fffffff)
		var graph: GeneratedRouteGraph = ROUTE_GRAPH_RESOLVER.resolve(
			stage.stage_id,
			profile,
			attempt_seed
		)
		var mountain: Dictionary = ROUTE_GRAPH_MOUNTAIN_SYNTHESIZER.build(
			stage.stage_id,
			profile,
			graph,
			attempt_seed
		)
		var heights: PackedFloat32Array = mountain.get("heights", PackedFloat32Array())
		var footprint: PackedByteArray = mountain.get("footprint", PackedByteArray())
		var topology := TerrainTopTopology.build(
			profile.generation_contract.cell_count,
			profile.generation_contract.local_bounds,
			heights,
			footprint
		)
		var started_at := Time.get_ticks_usec()
		var candidate_result := TargetMaskRasterizer.build(
			graph,
			topology,
			profile.generation_contract,
			profile
		)
		var candidate_elapsed_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
		print("attempt=%d valid=%s ratio=%.6f mean=%.3f p95=%.3f max=%.3f core_p95=%.3f lip_max=%.3f elapsed_ms=%.1f" % [
			attempt_index,
			str(candidate_result.get("valid", false)),
			float(candidate_result.get("target_ratio", -1.0)),
			float(candidate_result.get("target_mean_slope", -1.0)),
			float(candidate_result.get("target_p95_slope", -1.0)),
			float(candidate_result.get("target_maximum_slope", -1.0)),
			float(candidate_result.get("route_core_p95_slope", -1.0)),
			float(candidate_result.get("corridor_lip_maximum_slope", -1.0)),
			candidate_elapsed_ms,
		])
		if bool(candidate_result.get("valid", false)):
			result = candidate_result
			elapsed_ms = candidate_elapsed_ms
			accepted_attempt = attempt_index
			break
		if attempt_index == profile.generation_contract.attempt_count - 1:
			_print_steep_sample_diagnostics(candidate_result, topology, graph, profile.generation_contract)
	print("First Descent target mask: valid=%s rejection=%s ratio=%.6f mean=%.3f p95=%.3f max=%.3f core_p95=%.3f lip_max=%.3f components=%d graph_nodes=%s checksum=%d elapsed_ms=%.1f" % [
		str(result.get("valid", false)),
		str(result.get("rejection", "missing")),
		float(result.get("target_ratio", -1.0)),
		float(result.get("target_mean_slope", -1.0)),
		float(result.get("target_p95_slope", -1.0)),
		float(result.get("target_maximum_slope", -1.0)),
		float(result.get("route_core_p95_slope", -1.0)),
		float(result.get("corridor_lip_maximum_slope", -1.0)),
		int(result.get("component_count", -1)),
		str(result.get("graph_nodes_reachable", false)),
		int(result.get("checksum", 0)),
		elapsed_ms,
	])
	_assert_true(accepted_attempt >= 0, "a deterministic Stage 1 attempt must pass the frozen target gates")
	_assert_true(bool(result.get("valid", false)), "the Stage 1 target mask must pass every frozen geometry gate")
	var target_ratio := float(result.get("target_ratio", -1.0))
	var target_mean_slope := float(result.get("target_mean_slope", INF))
	_assert_true(
		target_ratio >= profile.target_ratio_range.x \
				and target_ratio <= profile.target_ratio_range.y,
		"the final target ratio must stay inside the frozen profile range"
	)
	_assert_true(
		target_mean_slope >= profile.target_mean_slope_range.x \
				and target_mean_slope <= profile.target_mean_slope_range.y,
		"the exact triangle-plane mean slope must stay inside the frozen range"
	)
	# Slope fields are emitted as immutable QA metrics. Structural validity and
	# reachability decide admission; these guards catch corrupt/non-finite samples
	# without reintroducing the retired post-raster slope deletion policy.
	_assert_true(is_finite(float(result.get("target_p95_slope", INF))), "target p95 slope must be finite")
	_assert_true(is_finite(float(result.get("target_maximum_slope", INF))), "target maximum slope must be finite")
	_assert_true(is_finite(float(result.get("route_core_p95_slope", INF))), "route-core p95 slope must be finite")
	_assert_true(is_finite(float(result.get("corridor_lip_maximum_slope", INF))), "corridor-lip maximum slope must be finite")
	_assert_true(int(result.get("component_count", 0)) == 1, "the target footprint must be one component")
	_assert_true(bool(result.get("graph_nodes_reachable", false)), "the summit and route exit must share the target component")
	_assert_true(int(result.get("connected_target_count", 0)) == int(result.get("target_count", -1)), "every target texel must be connected")
	var bytes: PackedByteArray = result.get("bytes", PackedByteArray())
	_assert_true(bytes.size() == StageGenerationContract.REQUIRED_MASK_SIZE * StageGenerationContract.REQUIRED_MASK_SIZE, "the target mask must be exactly 512 x 512")
	_assert_true(TargetMaskRasterizer.byte_checksum(bytes) == int(result.get("checksum", 0)), "the reported target checksum must match the immutable bytes")
	quit(1 if _failed else 0)


func _print_steep_sample_diagnostics(
		result: Dictionary,
		topology: TerrainTopTopology,
		graph: GeneratedRouteGraph,
		contract: StageGenerationContract
) -> void:
	var mask: PackedByteArray = result.get("bytes", PackedByteArray())
	var histogram := PackedInt32Array()
	histogram.resize(10)
	var core_histogram := PackedInt32Array()
	core_histogram.resize(10)
	var steepest: Array[Dictionary] = []
	for pixel_y in range(contract.mask_size):
		for pixel_x in range(contract.mask_size):
			var index := pixel_y * contract.mask_size + pixel_x
			if mask[index] < 128:
				continue
			var point := Vector2(
				lerpf(contract.local_bounds.position.x, contract.local_bounds.end.x, (float(pixel_x) + 0.5) / contract.mask_size),
				lerpf(contract.local_bounds.position.y, contract.local_bounds.end.y, (float(pixel_y) + 0.5) / contract.mask_size)
			)
			var sample := topology.surface_sample_at_local(point.x, point.y, false)
			var slope := rad_to_deg(acos(clampf((sample.normal as Vector3).y, -1.0, 1.0)))
			histogram[clampi(floori(slope / 10.0), 0, 9)] += 1
			var nearest := graph.nearest_edge(point)
			var edge := nearest.get("edge") as GeneratedRouteEdge
			var distance := float(nearest.get("distance", INF))
			if edge != null and distance <= edge.width * 0.5:
				core_histogram[clampi(floori(slope / 10.0), 0, 9)] += 1
			if steepest.size() < 12 or slope > float(steepest[-1].slope):
				steepest.append({"slope": slope, "point": point, "distance": distance, "sample": sample})
				steepest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.slope) > float(b.slope))
				if steepest.size() > 12:
					steepest.pop_back()
	print("target slope histogram 0..90 by 10deg: %s" % str(histogram))
	print("core slope histogram 0..90 by 10deg: %s" % str(core_histogram))
	for item in steepest:
		var sample: Dictionary = item.sample
		var indices: Vector3i = sample.source_vertex_indices
		print("steep slope=%.3f xz=%s route_d=%.3f cell=%s tri=%d vertex_y=[%.3f, %.3f, %.3f]" % [
			float(item.slope), str(item.point), float(item.distance), str(sample.cell), int(sample.triangle),
			topology.vertex_at(indices.x).y, topology.vertex_at(indices.y).y, topology.vertex_at(indices.z).y,
		])


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Target mask check failed: %s" % message)
