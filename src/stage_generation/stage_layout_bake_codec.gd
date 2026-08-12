class_name StageLayoutBakeCodec
extends RefCounted

## Schema-3 primitive transport. The SHA-256 feed has one explicit field order;
## it never delegates semantic bytes to Variant or Resource serialization.
static func bake(layout: GeneratedStageLayout, stage: StageData) -> BakedStageLayoutData:
	if layout == null or stage == null or not layout.is_runtime_ready():
		return null
	var data := BakedStageLayoutData.new()
	data.profile_id = layout.profile_id
	data.profile_version = layout.profile_version
	data.layout_version = layout.layout_version
	data.terrain_seed = layout.terrain_seed
	data.cell_count = layout.cell_count
	data.local_bounds = layout.local_bounds
	data.heights = layout.heights.duplicate()
	data.footprint = layout.footprint_cells_read_only()
	data.height_checksum = layout.checksum
	data.target_mask = layout.target_mask
	data.target_checksum = layout.target_mask_checksum
	data.coverage_metric_version = layout.coverage_metric_version
	data.total_target_surface_area = layout.total_target_surface_area
	data.target_surface_area_checksum = layout.target_surface_area_checksum
	data.play_bounds_checksum = layout.play_bounds.checksum()
	for node in layout.route_graph.nodes:
		data.route_node_ids.append(node.id)
		data.route_node_positions.append(node.position)
		data.route_node_route_indices.append(node.route_index)
		data.route_node_station_indices.append(node.station_index)
		data.route_node_kinds.append(node.kind)
		data.route_node_mechanism_kinds.append(node.mechanism_kind)
		data.route_node_pad_radii.append(node.pad_radius)
	for edge in layout.route_graph.edges:
		data.route_edge_ids.append(edge.id)
		data.route_edge_from_ids.append(edge.from_node_id)
		data.route_edge_to_ids.append(edge.to_node_id)
		data.route_edge_route_indices.append(edge.route_index)
		data.route_edge_indices.append(edge.edge_index)
		data.route_edge_roles.append(edge.role)
		data.route_edge_widths.append(edge.width)
	for loadout_index in range(layout.mechanism_placements.size()):
		var placement := layout.mechanism_placements[loadout_index]
		if placement == null or placement.mechanism_data == null \
				or loadout_index >= stage.mechanism_loadout.size() \
				or stage.mechanism_loadout[loadout_index] == null \
				or stage.mechanism_loadout[loadout_index].canonical_kind() \
						!= placement.mechanism_data.canonical_kind():
			return null
		data.mechanism_loadout_indices.append(loadout_index)
		data.mechanism_anchor_ids.append(placement.anchor_id)
		data.mechanism_local_xz.append(placement.local_xz)
		data.mechanism_transforms.append(placement.local_transform)
		data.mechanism_route_roles.append(placement.route_role)
		data.mechanism_route_indices.append(placement.route_index)
		data.mechanism_route_t.append(placement.route_t)
		data.mechanism_downstream_tangents.append(placement.downstream_tangent)
		data.mechanism_splitter_targets.append(placement.splitter_route_targets)
		data.mechanism_uphill_tangents.append(placement.uphill_tangent)
	data.placement_checksum = layout.placement_checksum()
	for decoration in layout.decoration_placements:
		data.decoration_model_ids.append(decoration.model_id)
		data.decoration_local_xz.append(decoration.local_xz)
		data.decoration_yaws.append(decoration.yaw_degrees)
		data.decoration_scales.append(decoration.uniform_scale)
	_store_witness(data, layout.generated_default_witness, false)
	_store_witness(data, layout.generated_summit_witness, true)
	if not _valid_payload(data):
		return null
	data.payload_sha256 = payload_sha256(data)
	return data if not data.payload_sha256.is_empty() else null


static func hydrate(data: BakedStageLayoutData, stage: StageData) -> GeneratedStageLayout:
	if data == null or stage == null or not _valid_payload(data):
		return null
	var expected_hash := payload_sha256(data)
	if expected_hash.is_empty() or data.payload_sha256 != expected_hash:
		return null
	var nodes: Array[GeneratedRouteNode] = []
	var edges: Array[GeneratedRouteEdge] = []
	for index in range(data.route_node_ids.size()):
		nodes.append(GeneratedRouteNode.new(data.route_node_ids[index], data.route_node_positions[index], data.route_node_route_indices[index], data.route_node_station_indices[index], data.route_node_kinds[index], data.route_node_mechanism_kinds[index], data.route_node_pad_radii[index]))
	for index in range(data.route_edge_ids.size()):
		edges.append(GeneratedRouteEdge.new(data.route_edge_ids[index], data.route_edge_from_ids[index], data.route_edge_to_ids[index], data.route_edge_route_indices[index], data.route_edge_indices[index], data.route_edge_roles[index], data.route_edge_widths[index]))
	var result := GeneratedStageLayout.new()
	result.profile_id = data.profile_id
	result.profile_version = data.profile_version
	result.layout_version = data.layout_version
	result.terrain_seed = data.terrain_seed
	result.cell_count = data.cell_count
	result.local_bounds = data.local_bounds
	result.heights = data.heights.duplicate()
	result.checksum = data.height_checksum
	result.metrics = {"maximum_height": _maximum_height(result.heights)}
	result.route_graph = GeneratedRouteGraph.new(nodes, edges)
	result.play_bounds = PlayBoundsSpec.new()
	result.top_topology = TerrainTopTopology.build(data.cell_count, data.local_bounds, data.heights, data.footprint)
	if result.top_topology == null or _height_checksum(result.heights) != data.height_checksum \
			or not result.install_footprint(data.footprint) \
			or not result.install_target_mask(data.target_mask, data.target_checksum) \
			or not result.install_target_surface_coverage(
				data.coverage_metric_version,
				data.total_target_surface_area,
				data.target_surface_area_checksum
			) \
			or result.play_bounds.checksum() != data.play_bounds_checksum:
		return null
	if not _hydrate_placements(result, data, stage):
		return null
	result.generated_default_witness = _load_witness(data, false)
	result.generated_summit_witness = _load_witness(data, true)
	# A supplied certificate is not transported as payload bytes. Retain the
	# stage-owned reference only when it validates against this hydrated layout.
	if stage.reachability_certificate != null:
		result.reachability_certificate = stage.reachability_certificate
	return result if result.matches_stage_identity(stage) and result.is_runtime_ready() else null


static func payload_sha256(data: BakedStageLayoutData) -> String:
	if data == null or not _semantic_fields_are_finite(data):
		return ""
	var feed := PackedByteArray()
	_append_i64(feed, data.schema_version)
	_append_string(feed, String(data.profile_id))
	_append_i64(feed, data.profile_version)
	_append_i64(feed, data.layout_version)
	_append_i64(feed, data.terrain_seed)
	_append_v2i(feed, data.cell_count)
	_append_rect(feed, data.local_bounds)
	_append_f32_array(feed, data.heights)
	_append_bytes(feed, data.footprint)
	_append_i64(feed, data.height_checksum)
	_append_bytes(feed, data.target_mask)
	_append_i64(feed, data.target_checksum)
	_append_i64(feed, data.coverage_metric_version)
	_append_f64(feed, data.total_target_surface_area)
	_append_i64(feed, data.target_surface_area_checksum)
	_append_string_array(feed, data.route_node_ids)
	_append_v3_array(feed, data.route_node_positions)
	_append_i32_array(feed, data.route_node_route_indices)
	_append_i32_array(feed, data.route_node_station_indices)
	_append_i32_array(feed, data.route_node_kinds)
	_append_i32_array(feed, data.route_node_mechanism_kinds)
	_append_float_array_as_f64(feed, data.route_node_pad_radii)
	_append_string_array(feed, data.route_edge_ids)
	_append_string_array(feed, data.route_edge_from_ids)
	_append_string_array(feed, data.route_edge_to_ids)
	_append_i32_array(feed, data.route_edge_route_indices)
	_append_i32_array(feed, data.route_edge_indices)
	_append_i32_array(feed, data.route_edge_roles)
	_append_float_array_as_f64(feed, data.route_edge_widths)
	_append_i64(feed, data.play_bounds_checksum)
	_append_i32_array(feed, data.mechanism_loadout_indices)
	_append_string_array(feed, data.mechanism_anchor_ids)
	_append_v2_array(feed, data.mechanism_local_xz)
	_append_transform_array(feed, data.mechanism_transforms)
	_append_i32_array(feed, data.mechanism_route_roles)
	_append_i32_array(feed, data.mechanism_route_indices)
	_append_float_array_as_f64(feed, data.mechanism_route_t)
	_append_v3_array(feed, data.mechanism_downstream_tangents)
	_append_v3_nested_array(feed, data.mechanism_splitter_targets)
	_append_v3_array(feed, data.mechanism_uphill_tangents)
	_append_i64(feed, data.placement_checksum)
	_append_string_array(feed, data.decoration_model_ids)
	_append_v2_array(feed, data.decoration_local_xz)
	_append_float_array_as_f64(feed, data.decoration_yaws)
	_append_float_array_as_f64(feed, data.decoration_scales)
	_append_witness(feed, data, false)
	_append_witness(feed, data, true)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(feed)
	return hash.finish().hex_encode()


static func _hydrate_placements(result: GeneratedStageLayout, data: BakedStageLayoutData, stage: StageData) -> bool:
	if data.mechanism_loadout_indices.size() != stage.mechanism_loadout.size():
		return false
	for index in range(data.mechanism_loadout_indices.size()):
		var loadout_index := data.mechanism_loadout_indices[index]
		if loadout_index != index or loadout_index >= stage.mechanism_loadout.size() \
				or stage.mechanism_loadout[loadout_index] == null:
			return false
		var placement := MechanismPlacement.new()
		placement.mechanism_data = stage.mechanism_loadout[loadout_index]
		placement.anchor_id = data.mechanism_anchor_ids[index]
		placement.local_xz = data.mechanism_local_xz[index]
		placement.local_transform = data.mechanism_transforms[index]
		placement.route_role = data.mechanism_route_roles[index]
		placement.route_index = data.mechanism_route_indices[index]
		placement.route_t = data.mechanism_route_t[index]
		placement.downstream_tangent = data.mechanism_downstream_tangents[index]
		placement.splitter_route_targets = data.mechanism_splitter_targets[index]
		placement.uphill_tangent = data.mechanism_uphill_tangents[index]
		result.mechanism_placements.append(placement)
	for index in range(data.decoration_model_ids.size()):
		result.decoration_placements.append(DecorationPlacement.new(data.decoration_model_ids[index], data.decoration_local_xz[index], data.decoration_yaws[index], data.decoration_scales[index]))
	return result.placement_checksum() == data.placement_checksum


static func _store_witness(data: BakedStageLayoutData, witness: StageEntryAimWitness, summit: bool) -> void:
	if witness == null:
		return
	var prefix := "summit_" if summit else "default_"
	data.set(prefix + "aim_yaw", witness.aim.yaw_degrees)
	data.set(prefix + "aim_elevation", witness.aim.elevation_degrees)
	# Baked witness power remains an integer-only catalog contract.
	data.set(prefix + "aim_power", int(witness.aim.power_percent))
	_store_identity(data, prefix + "predicted_", witness.predicted_identity)
	_store_identity(data, prefix + "physical_", witness.physical_identity)
	data.set(prefix + "predicted_local_impact", witness.predicted_local_impact)
	data.set(prefix + "physical_local_impact", witness.physical_local_impact)
	data.set(prefix + "target_local_point", witness.target_local_point)
	data.set(prefix + "target_pixel_index", witness.target_pixel_index)
	data.set(prefix + "summit_region_checksum", witness.summit_region_checksum)
	data.set(prefix + "distance_margin", witness.distance_margin)
	data.set(prefix + "range_margin", witness.range_margin)
	data.set(prefix + "height_margin", witness.height_margin)


static func _store_identity(data: BakedStageLayoutData, prefix: String, identity: TrajectoryHitIdentity) -> void:
	if identity == null:
		return
	data.set(prefix + "owner", identity.contact_owner_id)
	data.set(prefix + "shape", identity.contact_shape_id)
	data.set(prefix + "body_shape", identity.body_shape_index)
	data.set(prefix + "cell", identity.terrain_cell)
	data.set(prefix + "triangle", identity.terrain_triangle)
	data.set(prefix + "barycentric", identity.barycentric)


static func _load_witness(data: BakedStageLayoutData, summit: bool) -> StageEntryAimWitness:
	var prefix := "summit_" if summit else "default_"
	var witness := StageEntryAimWitness.new()
	witness.aim = AimTuple.new(float(data.get(prefix + "aim_yaw")), float(data.get(prefix + "aim_elevation")), int(data.get(prefix + "aim_power")))
	witness.predicted_identity = _load_identity(data, prefix + "predicted_")
	witness.physical_identity = _load_identity(data, prefix + "physical_")
	witness.predicted_local_impact = data.get(prefix + "predicted_local_impact")
	witness.physical_local_impact = data.get(prefix + "physical_local_impact")
	witness.target_local_point = data.get(prefix + "target_local_point")
	witness.target_pixel_index = int(data.get(prefix + "target_pixel_index"))
	witness.summit_region_checksum = int(data.get(prefix + "summit_region_checksum"))
	witness.distance_margin = float(data.get(prefix + "distance_margin"))
	witness.range_margin = float(data.get(prefix + "range_margin"))
	witness.height_margin = float(data.get(prefix + "height_margin"))
	return witness


static func _load_identity(data: BakedStageLayoutData, prefix: String) -> TrajectoryHitIdentity:
	return TrajectoryHitIdentity.new(data.get(prefix + "owner"), data.get(prefix + "shape"), int(data.get(prefix + "body_shape")), data.get(prefix + "cell"), int(data.get(prefix + "triangle")), data.get(prefix + "barycentric"))


static func _append_witness(feed: PackedByteArray, data: BakedStageLayoutData, summit: bool) -> void:
	var prefix := "summit_" if summit else "default_"
	_append_f64(feed, float(data.get(prefix + "aim_yaw")))
	_append_f64(feed, float(data.get(prefix + "aim_elevation")))
	_append_i64(feed, int(data.get(prefix + "aim_power")))
	_append_identity(feed, data, prefix + "predicted_")
	_append_identity(feed, data, prefix + "physical_")
	_append_v3(feed, data.get(prefix + "predicted_local_impact"))
	_append_v3(feed, data.get(prefix + "physical_local_impact"))
	_append_v3(feed, data.get(prefix + "target_local_point"))
	_append_i64(feed, int(data.get(prefix + "target_pixel_index")))
	_append_i64(feed, int(data.get(prefix + "summit_region_checksum")))
	_append_f64(feed, float(data.get(prefix + "distance_margin")))
	_append_f64(feed, float(data.get(prefix + "range_margin")))
	_append_f64(feed, float(data.get(prefix + "height_margin")))


static func _append_identity(feed: PackedByteArray, data: BakedStageLayoutData, prefix: String) -> void:
	_append_string(feed, String(data.get(prefix + "owner")))
	_append_string(feed, String(data.get(prefix + "shape")))
	_append_i64(feed, int(data.get(prefix + "body_shape")))
	_append_v2i(feed, data.get(prefix + "cell"))
	_append_i64(feed, int(data.get(prefix + "triangle")))
	_append_v3(feed, data.get(prefix + "barycentric"))


static func _valid_payload(data: BakedStageLayoutData) -> bool:
	if data.schema_version != BakedStageLayoutData.BAKED_LAYOUT_SCHEMA_VERSION \
			or data.cell_count.x <= 0 or data.cell_count.y <= 0 or not data.local_bounds.has_area() \
			or data.heights.size() != (data.cell_count.x + 1) * (data.cell_count.y + 1) \
			or data.footprint.size() != data.cell_count.x * data.cell_count.y \
			or data.target_mask.size() != StageGenerationContract.REQUIRED_MASK_SIZE * StageGenerationContract.REQUIRED_MASK_SIZE \
			or data.height_checksum == 0 or data.target_checksum == 0 \
			or not TargetSurfaceCoverage.metadata_is_valid(
				data.coverage_metric_version,
				data.total_target_surface_area,
				data.target_surface_area_checksum
			) \
			or data.terrain_seed != StageProgressionData.CANONICAL_TERRAIN_SEED \
			or data.play_bounds_checksum != PlayBoundsSpec.new().checksum() \
			or (not data.mechanism_loadout_indices.is_empty() and data.placement_checksum == 0) \
			or TargetMaskRasterizer.byte_checksum(data.target_mask) != data.target_checksum:
		return false
	var node_count := data.route_node_ids.size()
	var edge_count := data.route_edge_ids.size()
	var mechanism_count := data.mechanism_loadout_indices.size()
	var decoration_count := data.decoration_model_ids.size()
	return node_count > 0 and edge_count > 0 \
			and data.route_node_positions.size() == node_count and data.route_node_route_indices.size() == node_count \
			and data.route_node_station_indices.size() == node_count and data.route_node_kinds.size() == node_count \
			and data.route_node_mechanism_kinds.size() == node_count and data.route_node_pad_radii.size() == node_count \
			and data.route_edge_from_ids.size() == edge_count and data.route_edge_to_ids.size() == edge_count \
			and data.route_edge_route_indices.size() == edge_count and data.route_edge_indices.size() == edge_count \
			and data.route_edge_roles.size() == edge_count and data.route_edge_widths.size() == edge_count \
			and data.mechanism_anchor_ids.size() == mechanism_count and data.mechanism_local_xz.size() == mechanism_count \
			and data.mechanism_transforms.size() == mechanism_count and data.mechanism_route_roles.size() == mechanism_count \
			and data.mechanism_route_indices.size() == mechanism_count and data.mechanism_route_t.size() == mechanism_count \
			and data.mechanism_downstream_tangents.size() == mechanism_count and data.mechanism_splitter_targets.size() == mechanism_count \
			and data.mechanism_uphill_tangents.size() == mechanism_count and data.decoration_local_xz.size() == decoration_count \
			and data.decoration_yaws.size() == decoration_count and data.decoration_scales.size() == decoration_count \
			and _semantic_fields_are_finite(data) and _load_witness(data, false).is_valid() \
			and _load_witness(data, true).is_valid(true)


static func _semantic_fields_are_finite(data: BakedStageLayoutData) -> bool:
	if not data.local_bounds.position.is_finite() or not data.local_bounds.size.is_finite():
		return false
	if not is_finite(data.total_target_surface_area):
		return false
	for value in data.heights:
		if not is_finite(value): return false
	for value in data.route_node_positions: if not value.is_finite(): return false
	for value in data.route_node_pad_radii: if not is_finite(value): return false
	for value in data.route_edge_widths: if not is_finite(value): return false
	for value in data.mechanism_local_xz: if not value.is_finite(): return false
	for value in data.mechanism_transforms: if not _transform_is_finite(value): return false
	for value in data.mechanism_route_t: if not is_finite(value): return false
	for value in data.mechanism_downstream_tangents: if not value.is_finite(): return false
	for targets in data.mechanism_splitter_targets:
		for value in targets: if not value.is_finite(): return false
	for value in data.mechanism_uphill_tangents: if not value.is_finite(): return false
	for value in data.decoration_local_xz: if not value.is_finite(): return false
	for value in data.decoration_yaws: if not is_finite(value): return false
	for value in data.decoration_scales: if not is_finite(value): return false
	for summit in [false, true]:
		var witness := _load_witness(data, summit)
		if not witness.is_valid(summit): return false
	return true


static func _transform_is_finite(value: Transform3D) -> bool:
	return value.basis.x.is_finite() and value.basis.y.is_finite() \
			and value.basis.z.is_finite() and value.origin.is_finite()


static func _height_checksum(heights: PackedFloat32Array) -> int:
	var hash := 2166136261
	for height in heights:
		var quantized := roundi(height * 1000.0)
		for shift in [0, 8, 16, 24]:
			hash = hash ^ ((quantized >> shift) & 0xff)
			hash = int((hash * 16777619) & 0xffffffff)
	return hash


static func _maximum_height(heights: PackedFloat32Array) -> float:
	var result := -INF
	for height in heights:
		result = maxf(result, height)
	return result


static func _append_i64(feed: PackedByteArray, value: int) -> void:
	for shift in range(0, 64, 8):
		feed.append((value >> shift) & 0xff)
static func _append_f32(feed: PackedByteArray, value: float) -> void:
	var offset := feed.size()
	feed.resize(offset + 4)
	feed.encode_float(offset, 0.0 if value == 0.0 else value)
static func _append_f64(feed: PackedByteArray, value: float) -> void:
	var offset := feed.size()
	feed.resize(offset + 8)
	feed.encode_double(offset, 0.0 if value == 0.0 else value)
static func _append_string(feed: PackedByteArray, value: String) -> void:
	var bytes := value.to_utf8_buffer()
	_append_i64(feed, bytes.size())
	feed.append_array(bytes)
static func _append_bytes(feed: PackedByteArray, value: PackedByteArray) -> void:
	_append_i64(feed, value.size())
	feed.append_array(value)
static func _append_v2i(feed: PackedByteArray, value: Vector2i) -> void:
	_append_i64(feed, value.x)
	_append_i64(feed, value.y)
static func _append_v2(feed: PackedByteArray, value: Vector2) -> void:
	_append_f64(feed, value.x)
	_append_f64(feed, value.y)
static func _append_v3(feed: PackedByteArray, value: Vector3) -> void:
	_append_f64(feed, value.x)
	_append_f64(feed, value.y)
	_append_f64(feed, value.z)
static func _append_rect(feed: PackedByteArray, value: Rect2) -> void:
	_append_v2(feed, value.position)
	_append_v2(feed, value.size)
static func _append_transform(feed: PackedByteArray, value: Transform3D) -> void:
	_append_v3(feed, value.basis.x)
	_append_v3(feed, value.basis.y)
	_append_v3(feed, value.basis.z)
	_append_v3(feed, value.origin)
static func _append_i32_array(feed: PackedByteArray, values: PackedInt32Array) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_i64(feed, value)
static func _append_f32_array(feed: PackedByteArray, values: PackedFloat32Array) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_f32(feed, value)
static func _append_float_array_as_f64(feed: PackedByteArray, values: PackedFloat64Array) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_f64(feed, value)
static func _append_string_array(feed: PackedByteArray, values: Array[StringName]) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_string(feed, String(value))
static func _append_v2_array(feed: PackedByteArray, values: PackedVector2Array) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_v2(feed, value)
static func _append_v3_array(feed: PackedByteArray, values: PackedVector3Array) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_v3(feed, value)
static func _append_transform_array(feed: PackedByteArray, values: Array[Transform3D]) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_transform(feed, value)
static func _append_v3_nested_array(feed: PackedByteArray, values: Array[PackedVector3Array]) -> void:
	_append_i64(feed, values.size())
	for value in values:
		_append_v3_array(feed, value)
