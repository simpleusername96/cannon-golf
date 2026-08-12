class_name TargetMaskRasterizer
extends RefCounted

## Builds the immutable scoreable footprint from route geometry. Slope and
## ballistic difficulty never remove an included pixel; exact target structure
## and reachability are validated separately, and failures reject the candidate.

# The raster is sampled at roughly 0.4 m while the mountain can rise several
# metres between neighboring pixels on a steep face. A 6 m 3D step keeps those
# continuous faces one component without bridging an actual empty XZ gap.
const MAXIMUM_CONNECTED_STEP_METERS := 6.0
const NEIGHBOR_OFFSETS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


static func build(
		graph: GeneratedRouteGraph,
		topology: TerrainTopTopology,
		contract: StageGenerationContract,
		profile: StageGenerationProfile,
		range_constraint: ProjectileRangeConstraint = null
) -> Dictionary:
	if graph == null or not graph.is_valid() or topology == null \
			or not topology.is_valid() or contract == null or not contract.is_valid() \
			or profile == null or not profile.is_valid():
		return {"valid": false, "rejection": "invalid_input"}
	var pixel_count := contract.mask_size * contract.mask_size
	var target_mask := PackedByteArray()
	target_mask.resize(pixel_count)
	var surface_positions := PackedVector3Array()
	surface_positions.resize(pixel_count)
	var target_slopes := PackedFloat32Array()
	var route_core_slopes := PackedFloat32Array()
	var corridor_lip_slopes := PackedFloat32Array()
	var edge_starts := PackedVector2Array()
	var edge_deltas := PackedVector2Array()
	var core_radii := PackedFloat32Array()
	for edge in graph.edges:
		var from := graph.node_by_id(edge.from_node_id).position
		var to := graph.node_by_id(edge.to_node_id).position
		edge_starts.append(Vector2(from.x, from.z))
		edge_deltas.append(Vector2(to.x - from.x, to.z - from.z))
		core_radii.append(edge.width * 0.5)
	var pad_positions := PackedVector2Array()
	var pad_target_radii := PackedFloat32Array()
	for pad in graph.pad_nodes():
		pad_positions.append(Vector2(pad.position.x, pad.position.z))
		pad_target_radii.append(pad.pad_radius + 4.0)

	var target_count := 0
	var target_slope_sum := 0.0
	for pixel_y in range(contract.mask_size):
		for pixel_x in range(contract.mask_size):
			var local_xz := _pixel_center_local(Vector2i(pixel_x, pixel_y), contract)
			if _edge_distance(contract.local_bounds, local_xz) < contract.outer_band_width:
				continue
			var included := false
			var in_route_core := false
			var in_corridor_lip := false
			for edge_index in range(edge_starts.size()):
				var delta := edge_deltas[edge_index]
				var t := clampf(
					(local_xz - edge_starts[edge_index]).dot(delta) \
							/ maxf(delta.length_squared(), 0.000001),
					0.0,
					1.0
				)
				var distance := local_xz.distance_to(edge_starts[edge_index] + delta * t)
				var core_radius := core_radii[edge_index]
				included = included or distance <= core_radius \
						+ contract.target_shoulder_distance
				in_route_core = in_route_core or distance <= core_radius
				in_corridor_lip = in_corridor_lip or (
					distance >= core_radius \
							and distance <= core_radius + contract.bank_blend_distance
				)
			if not included:
				for pad_index in range(pad_positions.size()):
					if local_xz.distance_to(pad_positions[pad_index]) \
							<= pad_target_radii[pad_index]:
						included = true
						break
			if not included:
				continue
			var sample := topology.surface_sample_at_local(local_xz.x, local_xz.y, false)
			if sample.is_empty():
				return {"valid": false, "rejection": "surface_sample"}
			var pixel_index := pixel_y * contract.mask_size + pixel_x
			var surface_position: Vector3 = sample.point
			var surface_normal: Vector3 = sample.normal
			if range_constraint != null:
				var range_result := range_constraint.evaluate_local_surface(
					surface_position,
					surface_normal
				)
				if not bool(range_result.get("valid", false)):
					return {
						"valid": false,
						"rejection": "projectile_range",
						"ballistic_rejection": range_result.get("rejection", &"unknown"),
						"ballistic_failure_pixel": Vector2i(pixel_x, pixel_y),
						"ballistic_failure_local_xz": local_xz,
						"ballistic_failure_surface": surface_position,
						"ballistic_failure_details": range_result,
					}
			var slope := rad_to_deg(acos(clampf(surface_normal.y, -1.0, 1.0)))
			target_mask[pixel_index] = 255
			surface_positions[pixel_index] = surface_position
			target_slopes.append(slope)
			target_slope_sum += slope
			target_count += 1
			if in_route_core:
				route_core_slopes.append(slope)
			if in_corridor_lip:
				corridor_lip_slopes.append(slope)

	if target_count <= 0 or route_core_slopes.is_empty() or corridor_lip_slopes.is_empty():
		return {"valid": false, "rejection": "empty_target_samples"}
	var connectivity := _connectivity_metrics(
		target_mask,
		surface_positions,
		graph,
		contract
	)
	var target_ratio := float(target_count) / float(pixel_count)
	var target_mean_slope := target_slope_sum / float(target_count)
	var target_p95_slope := _percentile95(target_slopes)
	var target_maximum_slope := _maximum(target_slopes)
	var route_core_p95_slope := _percentile95(route_core_slopes)
	var corridor_lip_maximum_slope := _maximum(corridor_lip_slopes)
	# Slope distributions remain useful QA metrics, but they must not prevent a
	# structurally complete mountain from entering the runtime MVP.
	var structurally_ready := target_ratio >= profile.target_ratio_range.x \
			and target_ratio <= profile.target_ratio_range.y \
			and int(connectivity.component_count) == 1 \
			and bool(connectivity.graph_nodes_reachable)
	var result := {
		"valid": structurally_ready,
		"rejection": "" if structurally_ready else "target_structure",
		"bytes": target_mask,
		"checksum": byte_checksum(target_mask),
		"target_count": target_count,
		"target_ratio": target_ratio,
		"target_mean_slope": target_mean_slope,
		"target_p95_slope": target_p95_slope,
		"target_maximum_slope": target_maximum_slope,
		"route_core_p95_slope": route_core_p95_slope,
		"corridor_lip_maximum_slope": corridor_lip_maximum_slope,
		"component_count": connectivity.component_count,
		"connected_target_count": connectivity.connected_target_count,
		"graph_nodes_reachable": connectivity.graph_nodes_reachable,
	}
	if range_constraint != null:
		result.merge(range_constraint.target_metrics(), true)
	return result


static func byte_checksum(bytes: PackedByteArray) -> int:
	var hash: int = 2166136261
	for byte in bytes:
		hash = hash ^ byte
		hash = int((hash * 16777619) & 0xffffffff)
	return hash


static func _connectivity_metrics(
		target_mask: PackedByteArray,
		surface_positions: PackedVector3Array,
		graph: GeneratedRouteGraph,
		contract: StageGenerationContract
) -> Dictionary:
	var visited := PackedByteArray()
	visited.resize(target_mask.size())
	var component_count := 0
	var first_component_count := 0
	for seed in range(target_mask.size()):
		if target_mask[seed] < 128 or visited[seed] != 0:
			continue
		component_count += 1
		var component_size := _visit_component(
			seed,
			target_mask,
			surface_positions,
			visited,
			contract.mask_size
		)
		if component_count == 1:
			first_component_count = component_size
	var graph_nodes_reachable := component_count == 1
	if graph_nodes_reachable:
		for node in graph.nodes:
			var pixel := _local_to_pixel(Vector2(node.position.x, node.position.z), contract)
			var index := pixel.y * contract.mask_size + pixel.x
			if target_mask[index] < 128 or visited[index] == 0:
				graph_nodes_reachable = false
				break
	return {
		"component_count": component_count,
		"connected_target_count": first_component_count,
		"graph_nodes_reachable": graph_nodes_reachable,
	}


static func _visit_component(
		seed: int,
		target_mask: PackedByteArray,
		surface_positions: PackedVector3Array,
		visited: PackedByteArray,
		mask_size: int
) -> int:
	var queue := PackedInt32Array([seed])
	visited[seed] = 1
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		var point := Vector2i(current % mask_size, current / mask_size)
		for offset in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = point + offset
			if neighbor.x < 0 or neighbor.x >= mask_size \
					or neighbor.y < 0 or neighbor.y >= mask_size:
				continue
			var neighbor_index: int = neighbor.y * mask_size + neighbor.x
			if target_mask[neighbor_index] < 128 or visited[neighbor_index] != 0:
				continue
			if surface_positions[current].distance_to(surface_positions[neighbor_index]) \
					> MAXIMUM_CONNECTED_STEP_METERS:
				continue
			visited[neighbor_index] = 1
			queue.append(neighbor_index)
	return queue.size()


static func _pixel_center_local(pixel: Vector2i, contract: StageGenerationContract) -> Vector2:
	return Vector2(
		lerpf(
			contract.local_bounds.position.x,
			contract.local_bounds.end.x,
			(float(pixel.x) + 0.5) / float(contract.mask_size)
		),
		lerpf(
			contract.local_bounds.position.y,
			contract.local_bounds.end.y,
			(float(pixel.y) + 0.5) / float(contract.mask_size)
		)
	)


static func _local_to_pixel(local_xz: Vector2, contract: StageGenerationContract) -> Vector2i:
	var normalized := Vector2(
		(local_xz.x - contract.local_bounds.position.x) / contract.local_bounds.size.x,
		(local_xz.y - contract.local_bounds.position.y) / contract.local_bounds.size.y
	)
	return Vector2i(
		clampi(floori(normalized.x * contract.mask_size), 0, contract.mask_size - 1),
		clampi(floori(normalized.y * contract.mask_size), 0, contract.mask_size - 1)
	)


static func _percentile95(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return INF
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(floori(float(sorted.size() - 1) * 0.95), 0, sorted.size() - 1)]


static func _maximum(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return INF
	var result := -INF
	for value in values:
		result = maxf(result, value)
	return result


static func _edge_distance(bounds: Rect2, point: Vector2) -> float:
	return minf(
		minf(point.x - bounds.position.x, bounds.end.x - point.x),
		minf(point.y - bounds.position.y, bounds.end.y - point.y)
	)
