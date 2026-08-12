class_name SeededStageGenerator
extends RefCounted

const ROUTE_GRAPH_RESOLVER := preload("res://src/stage_generation/route_graph_resolver.gd")
const ROUTE_GRAPH_MOUNTAIN_SYNTHESIZER := preload(
	"res://src/stage_generation/route_graph_mountain_synthesizer.gd"
)
const KEYED_STAGE_SAMPLER := preload("res://src/stage_generation/keyed_stage_sampler.gd")
const DECORATION_MODEL_CYCLE: Array[StringName] = [
	&"tree_pineSmallA", &"tree_pineSmallB", &"rock_smallA", &"tree_pineTallA", &"rock_largeA",
]


static func generate(
		profile: StageGenerationProfile,
		terrain_seed: int = 0,
		stage_data: StageData = null
) -> GeneratedStageLayout:
	if profile == null or not profile.is_valid():
		push_error("Stage generation profile is invalid.")
		return null
	var stage_id := stage_data.stage_id if stage_data != null \
			else StageGenerationProfile.stage_id_from_profile_id(profile.profile_id)
	var exact_seed := terrain_seed if terrain_seed != 0 else profile.base_seed
	if stage_data == null or exact_seed != StageProgressionData.CANONICAL_TERRAIN_SEED:
		push_error("Exact %s generation requires StageData and the canonical terrain seed." % StageGenerationContract.version_tag())
		return null
	var layout := _build_exact(stage_id, profile, exact_seed)
	if _validate(profile, layout) and _finalize_layout(profile, stage_data, layout):
		layout.reachability_certificate = stage_data.reachability_certificate
		return layout
	var failure_metrics := layout.metrics if layout != null else {"rejection": "route_graph"}
	push_error("Exact %s generation failed for %s: %s" % [StageGenerationContract.version_tag(), stage_id, str(failure_metrics)])
	return null


## Offline catalog-builder entry point. One exact identity either validates or
## fails; there is no candidate, attempt, or fallback path.
static func generate_exact(
		profile: StageGenerationProfile,
		terrain_seed: int = 0,
		stage_data: StageData = null
) -> GeneratedStageLayout:
	if profile == null or not profile.is_valid():
		push_error("Stage generation profile is invalid.")
		return null
	var stage_id := stage_data.stage_id if stage_data != null \
			else StageGenerationProfile.stage_id_from_profile_id(profile.profile_id)
	var exact_seed := terrain_seed if terrain_seed != 0 else profile.base_seed
	if stage_data == null or exact_seed != StageProgressionData.CANONICAL_TERRAIN_SEED:
		return null
	var layout := _build_exact(stage_id, profile, exact_seed)
	if not _validate(profile, layout):
		push_error("Exact %s structural generation failed for %s: %s" % [
			StageGenerationContract.version_tag(), stage_id,
			str(layout.metrics) if layout != null else "missing_layout",
		])
		return null
	if not _finalize_layout(profile, stage_data, layout):
		push_error("Exact %s layout finalization failed for %s: %s" % [
			StageGenerationContract.version_tag(), stage_id,
			str(layout.metrics),
		])
		return null
	return layout


static func _build_exact(
		stage_id: StringName,
		profile: StageGenerationProfile,
		terrain_seed: int
) -> GeneratedStageLayout:
	var graph: GeneratedRouteGraph = ROUTE_GRAPH_RESOLVER.resolve(stage_id, profile, terrain_seed)
	if graph == null:
		return null
	var contract := profile.generation_contract
	var mountain: Dictionary = ROUTE_GRAPH_MOUNTAIN_SYNTHESIZER.build(
		stage_id, profile, graph, terrain_seed
	)
	var heights: PackedFloat32Array = mountain.get("heights", PackedFloat32Array())
	var footprint: PackedByteArray = mountain.get("footprint", PackedByteArray())

	var layout := GeneratedStageLayout.new()
	layout.profile_id = profile.profile_id
	layout.profile_version = profile.profile_version
	layout.layout_version = contract.layout_version
	layout.terrain_seed = terrain_seed
	layout.cell_count = contract.cell_count
	layout.local_bounds = contract.local_bounds
	layout.heights = heights
	layout.install_footprint(footprint)
	layout.top_topology = TerrainTopTopology.build(
		layout.cell_count, layout.local_bounds, heights, footprint
	)
	layout.route_graph = graph
	layout.play_bounds = PlayBoundsSpec.new()
	layout.checksum = _height_checksum(heights)
	return layout


static func _validate(profile: StageGenerationProfile, layout: GeneratedStageLayout) -> bool:
	if layout == null or not layout.is_valid():
		return false
	var maximum_height := 0.0
	for height in layout.heights:
		if not is_finite(height):
			layout.metrics = {"rejection": "non_finite_height"}
			return false
		maximum_height = maxf(maximum_height, height)
	layout.metrics = {
		"maximum_height": maximum_height,
		"route_count": layout.route_graph.route_count(),
		"station_count": profile.generation_contract.route_station_z.size(),
		"ridge_count": profile.ridge_count,
		"basin_count": profile.basin_count,
		"pass_count": profile.pass_count,
		"undulation_amplitude": profile.undulation_amplitude,
		"route_width": profile.route_width,
	}
	if maximum_height < profile.accepted_height_range.x or maximum_height > profile.accepted_height_range.y:
		layout.metrics["rejection"] = "maximum_height"
		return false
	if not _validate_edges(layout):
		layout.metrics["rejection"] = "edge_height"
		return false
	if not _validate_routes(profile, layout):
		return false
	if not _validate_glyph_anchors(layout):
		layout.metrics["rejection"] = "mechanism_anchor"
		return false
	var footprint_ratio: float = ROUTE_GRAPH_MOUNTAIN_SYNTHESIZER.route_footprint_ratio(
		layout.route_graph, profile.generation_contract
	)
	layout.metrics["route_footprint_ratio"] = footprint_ratio
	if footprint_ratio < profile.target_ratio_range.x or footprint_ratio > profile.target_ratio_range.y:
		layout.metrics["rejection"] = "route_footprint_ratio"
		return false
	layout.metrics["top_triangles"] = layout.top_topology.triangle_count()
	layout.metrics["summit_triangle_count"] = layout.summit_triangle_ids().size()
	layout.metrics["summit_region_checksum"] = layout.summit_region_checksum()
	return true


static func _validate_edges(layout: GeneratedStageLayout) -> bool:
	var size := layout.sample_size()
	for x in range(size.x):
		if layout.heights[(size.y - 1) * size.x + x] > 0.01:
			return false
	for z in range(size.y):
		if layout.heights[z * size.x] > 0.01 or layout.heights[z * size.x + size.x - 1] > 0.01:
			return false
	return true


static func _validate_routes(profile: StageGenerationProfile, layout: GeneratedStageLayout) -> bool:
	var graph := layout.route_graph
	if graph.route_count() != profile.routes.size():
		layout.metrics["rejection"] = "route_count"
		return false
	var maximum_node_height := -INF
	for node in graph.nodes:
		maximum_node_height = maxf(maximum_node_height, node.position.y)
	if not is_equal_approx(maximum_node_height, profile.nominal_peak):
		layout.metrics["rejection"] = "graph_peak"
		return false
	var all_slopes := PackedFloat32Array()
	var reversal_counts := PackedInt32Array()
	for route_index in range(graph.route_count()):
		if graph.route_role(route_index) != profile.routes[route_index].role:
			layout.metrics["rejection"] = "route_role"
			return false
		var reversals := graph.route_reversal_count(route_index)
		reversal_counts.append(reversals)
		if reversals != profile.routes[route_index].reversal_count():
			layout.metrics["rejection"] = "route_reversals"
			return false
		for point in graph.route_nodes(route_index):
			var edge_distance := minf(
				minf(point.position.x - layout.local_bounds.position.x, layout.local_bounds.end.x - point.position.x),
				minf(point.position.z - layout.local_bounds.position.y, layout.local_bounds.end.y - point.position.z)
			)
			if edge_distance < profile.generation_contract.outer_band_width:
				layout.metrics["rejection"] = "route_edge_clearance"
				return false
		for edge in graph.route_edges(route_index):
			var start := graph.node_by_id(edge.from_node_id).position
			var finish := graph.node_by_id(edge.to_node_id).position
			var horizontal_distance := Vector2(start.x, start.z).distance_to(Vector2(finish.x, finish.z))
			all_slopes.append(rad_to_deg(atan(absf(finish.y - start.y) / maxf(horizontal_distance, 0.001))))
	if all_slopes.is_empty():
		layout.metrics["rejection"] = "route_slope_samples"
		return false
	all_slopes.sort()
	var p95_index := clampi(floori(float(all_slopes.size() - 1) * 0.95), 0, all_slopes.size() - 1)
	var maximum_slope := all_slopes[-1]
	var p95_slope := all_slopes[p95_index]
	layout.metrics["route_reversals"] = reversal_counts
	layout.metrics["maximum_route_slope"] = maximum_slope
	layout.metrics["p95_route_slope"] = p95_slope
	if p95_slope > profile.route_core_p95_slope_max:
		layout.metrics["rejection"] = "route_core_p95_slope"
		return false
	return true


static func _validate_glyph_anchors(layout: GeneratedStageLayout) -> bool:
	for pad in layout.route_graph.pad_nodes():
		# Pads are deterministic anchor metadata now, not physical platforms.
		# The glyph planner below validates the complete typed footprint, slope,
		# normal variation, and kind-specific witnesses on the real surface.
		if layout.surface_sample_at_local(pad.position.x, pad.position.z, false).is_empty():
			return false
	return true


static func _finalize_layout(
		profile: StageGenerationProfile,
		stage_data: StageData,
		layout: GeneratedStageLayout
) -> bool:
	var range_constraint: ProjectileRangeConstraint = null
	if stage_data != null:
		range_constraint = ProjectileRangeConstraint.new(stage_data)
		if not range_constraint.is_valid():
			layout.metrics["rejection"] = "projectile_range_configuration"
			layout.metrics["ballistic_rejection"] = range_constraint.configuration_rejection()
			return false
		if not stage_data.mechanism_loadout.is_empty():
			layout.mechanism_placements = MechanismPlacementGenerator.generate(stage_data, layout)
			if layout.mechanism_placements.size() != stage_data.mechanism_loadout.size():
				layout.metrics["rejection"] = "mechanism_placement"
				return false
	var target_result := TargetMaskRasterizer.build(
		layout.route_graph,
		layout.top_topology,
		profile.generation_contract,
		profile,
		range_constraint
	)
	for key in target_result:
		if key not in ["bytes", "checksum", "valid", "rejection"]:
			layout.metrics[key] = target_result[key]
	if not bool(target_result.get("valid", false)):
		layout.metrics["rejection"] = target_result.get("rejection", "target_mask")
		return false
	if range_constraint != null:
		var summit_result := range_constraint.evaluate_summit(layout)
		layout.metrics["ballistic_summit_sample_count"] = int(
			summit_result.get("summit_sample_count", 0)
		)
		layout.metrics["ballistic_summit_triangle_id"] = int(
			summit_result.get("summit_triangle_id", -1)
		)
		layout.metrics["ballistic_summit_range_margin"] = float(
			summit_result.get("range_margin", -INF)
		)
		layout.metrics["ballistic_summit_height_margin"] = float(
			summit_result.get("height_margin", -INF)
		)
		if not bool(summit_result.get("valid", false)):
			layout.metrics["rejection"] = "projectile_range_summit"
			layout.metrics["ballistic_rejection"] = summit_result.get(
				"rejection", &"unknown"
			)
			return false
	if not layout.install_target_mask(
		target_result.get("bytes", PackedByteArray()),
		int(target_result.get("checksum", 0))
	):
		layout.metrics["rejection"] = "target_mask_install"
		return false
	var total_target_surface_area := TargetSurfaceCoverage.total_target_surface_area(
		layout.target_mask,
		layout.top_topology,
		layout.local_bounds,
		StageGenerationContract.REQUIRED_MASK_SIZE
	)
	var target_surface_area_checksum := TargetSurfaceCoverage.metadata_checksum(
		TargetSurfaceCoverage.METRIC_VERSION,
		total_target_surface_area
	)
	if not layout.install_target_surface_coverage(
		TargetSurfaceCoverage.METRIC_VERSION,
		total_target_surface_area,
		target_surface_area_checksum
	):
		layout.metrics["rejection"] = "target_surface_coverage"
		return false
	if stage_data != null:
		layout.decoration_placements = _generate_decorations(stage_data, layout)
		layout.metrics["decoration_count"] = layout.decoration_placements.size()
	return true


static func _generate_decorations(stage_data: StageData, layout: GeneratedStageLayout) -> Array[DecorationPlacement]:
	var candidates: Array[Vector2] = []
	var sample_size := layout.sample_size()
	for z_index in range(2, sample_size.y - 2):
		var local_z := lerpf(layout.local_bounds.position.y, layout.local_bounds.end.y, float(z_index) / float(layout.cell_count.y))
		for x_index in range(2, sample_size.x - 2):
			var local_x := lerpf(layout.local_bounds.position.x, layout.local_bounds.end.x, float(x_index) / float(layout.cell_count.x))
			var sample := layout.surface_sample_at_local(local_x, local_z, false)
			if sample.is_empty():
				continue
			var sample_normal: Vector3 = sample.normal
			if sample_normal.y < cos(deg_to_rad(42.0)):
				continue
			var local_xz := Vector2(local_x, local_z)
			candidates.append(local_xz)
	var rng := RandomNumberGenerator.new()
	# Stage identity is part of the key so all stages can share one terrain seed
	# without sharing decoration placement.
	rng.seed = KEYED_STAGE_SAMPLER.fnv1a32(
		KEYED_STAGE_SAMPLER.versioned_key(stage_data.stage_id, layout.terrain_seed, "decorations")
	) & 0x7fffffff
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	var result: Array[DecorationPlacement] = []
	var requested_count := _decoration_count(stage_data.stage_number)
	var support_distance := stage_data.generation_profile.generation_contract.support_distance
	var target_mask := layout.target_mask
	for candidate in candidates:
		var model_id := DECORATION_MODEL_CYCLE[result.size() % DECORATION_MODEL_CYCLE.size()]
		var is_tree := String(model_id).begins_with("tree_")
		var scale_value := rng.randf_range(3.0, 4.5) if is_tree else rng.randf_range(2.0, 3.2)
		var visual_radius := _decoration_visual_radius(model_id, scale_value)
		if not _decoration_footprint_is_clear(
			layout,
			candidate,
			visual_radius,
			support_distance,
			target_mask
		):
			continue
		var separated := true
		for existing in result:
			var required_separation := visual_radius \
					+ _decoration_visual_radius(existing.model_id, existing.uniform_scale)
			if candidate.distance_to(existing.local_xz) < required_separation:
				separated = false
				break
		if not separated:
			continue
		result.append(DecorationPlacement.new(model_id, candidate, rng.randf_range(0.0, 360.0), scale_value))
		if result.size() >= requested_count:
			break
	return result


static func _decoration_visual_radius(model_id: StringName, uniform_scale: float) -> float:
	# Conservative XZ enclosing radii for the approved imported meshes. Keeping
	# this geometry contract beside placement avoids loading visual assets in the
	# deterministic generator.
	var base_radius := 0.36
	if model_id == &"tree_pineTallA":
		base_radius = 0.45
	elif model_id == &"rock_smallA":
		base_radius = 0.40
	elif model_id == &"rock_largeA":
		base_radius = 0.80
	return base_radius * uniform_scale + 0.5


static func _decoration_footprint_is_clear(
		layout: GeneratedStageLayout,
		center: Vector2,
		visual_radius: float,
		support_distance: float,
		target_mask: PackedByteArray
) -> bool:
	if not layout.local_bounds.grow(-visual_radius).has_point(center):
		return false
	var nearest := layout.route_graph.nearest_edge(center)
	var nearest_edge := nearest.get("edge") as GeneratedRouteEdge
	if nearest_edge != null and float(nearest.get("distance", INF)) \
			<= nearest_edge.width * 0.5 \
					+ minf(support_distance, 1.5) + visual_radius:
		return false
	for mechanism in layout.mechanism_placements:
		if mechanism == null or mechanism.mechanism_data == null:
			continue
		if center.distance_to(mechanism.local_xz) \
				<= mechanism.mechanism_data.glyph_radius \
						+ 2.0 + visual_radius:
			return false
	return _circle_is_outside_target_mask(
		layout,
		center,
		visual_radius,
		target_mask
	)


static func _circle_is_outside_target_mask(
		layout: GeneratedStageLayout,
		center: Vector2,
		radius: float,
		target_mask: PackedByteArray
) -> bool:
	if target_mask.is_empty():
		return false
	var mask_size := StageGenerationContract.REQUIRED_MASK_SIZE
	var pixel_size := layout.local_bounds.size / float(mask_size)
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
	var pixel_half_diagonal := pixel_size.length() * 0.5
	for pixel_y in range(minimum_pixel.y, maximum_pixel.y + 1):
		for pixel_x in range(minimum_pixel.x, maximum_pixel.x + 1):
			var pixel_center := layout.local_bounds.position + Vector2(
				(float(pixel_x) + 0.5) * pixel_size.x,
				(float(pixel_y) + 0.5) * pixel_size.y
			)
			if center.distance_to(pixel_center) <= radius + pixel_half_diagonal \
					and target_mask[pixel_y * mask_size + pixel_x] >= 128:
				return false
	return true


static func _decoration_count(stage_number: int) -> int:
	return 10 + roundi(22.0 * StageProgressionData.normalized_t(stage_number))


static func _height_checksum(heights: PackedFloat32Array) -> int:
	var hash: int = 2166136261
	for height in heights:
		var quantized := roundi(height * 1000.0)
		for shift in [0, 8, 16, 24]:
			hash = hash ^ ((quantized >> shift) & 0xff)
			hash = int((hash * 16777619) & 0xffffffff)
	return hash
