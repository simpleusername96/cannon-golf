class_name GeneratedStageLayout
extends RefCounted

const CHECKSUM_OFFSET := 2166136261
const CHECKSUM_PRIME := 16777619

var profile_id: StringName
var profile_version: int
var layout_version: int
var terrain_seed: int
var cell_count: Vector2i
var local_bounds: Rect2
var heights: PackedFloat32Array
var top_topology: TerrainTopTopology
var route_graph: GeneratedRouteGraph
var play_bounds: PlayBoundsSpec
var reachability_certificate: DirectReachabilityCertificate
var generated_default_aim: AimTuple
var generated_default_witness: StageEntryAimWitness
var generated_summit_witness: StageEntryAimWitness
var generated_summit_aim: AimTuple:
	get:
		return generated_summit_witness.aim if generated_summit_witness != null \
				and generated_summit_witness.is_valid(true) else null
var metrics: Dictionary = {}
var checksum: int = 0
var mechanism_placements: Array[MechanismPlacement] = []
var decoration_placements: Array[DecorationPlacement] = []
var target_mask: PackedByteArray:
	get:
		return _target_mask.duplicate()
var target_mask_checksum: int:
	get:
		return _target_mask_checksum
var coverage_metric_version: int:
	get:
		return _coverage_metric_version
var total_target_surface_area: float:
	get:
		return _total_target_surface_area
var target_surface_area_checksum: int:
	get:
		return _target_surface_area_checksum
var default_aim: AimTuple:
	get:
		if reachability_certificate != null:
			return reachability_certificate.default_aim if is_certified() else null
		return generated_default_witness.aim if generated_default_witness != null \
				and generated_default_witness.is_valid() else generated_default_aim \
				if generated_default_aim != null and generated_default_aim.is_valid() else null

var _target_mask := PackedByteArray()
var _target_mask_checksum: int = 0
var _coverage_metric_version: int = 0
var _total_target_surface_area: float = 0.0
var _target_surface_area_checksum: int = 0
var _target_pixel_indices := PackedInt32Array()
var _target_centroid_local_xz := Vector2(INF, INF)
var _target_pixel_nearest_centroid: int = -1
var _footprint_cells := PackedByteArray()
# Accepted repository layouts are immutable for their process lifetime. Cache
# only a successful full readiness proof; an incomplete layout may still gain
# its build-time witnesses and be checked again.
var _runtime_readiness_verified := false


func sample_size() -> Vector2i:
	return cell_count + Vector2i.ONE


func is_valid() -> bool:
	var size := sample_size()
	return size.x > 1 and size.y > 1 and heights.size() == size.x * size.y \
			and profile_version == StageGenerationContract.CONTRACT_VERSION \
			and layout_version == StageGenerationContract.CONTRACT_VERSION \
			and has_valid_footprint() \
			and top_topology != null and top_topology.is_valid() \
			and top_topology.matches_height_grid(cell_count, local_bounds, heights) \
			and route_graph != null and route_graph.is_valid() \
			and play_bounds != null and play_bounds.is_valid()


func install_target_surface_coverage(
		metric_version: int,
		total_surface_area: float,
		area_checksum: int
) -> bool:
	if _coverage_metric_version != 0 \
			or not TargetSurfaceCoverage.metadata_is_valid(
				metric_version, total_surface_area, area_checksum
			):
		return false
	_coverage_metric_version = metric_version
	_total_target_surface_area = total_surface_area
	_target_surface_area_checksum = area_checksum
	return true


func has_valid_target_surface_coverage() -> bool:
	return has_valid_target_mask() \
			and TargetSurfaceCoverage.metadata_is_valid(
				_coverage_metric_version,
				_total_target_surface_area,
				_target_surface_area_checksum
			)


func install_target_mask(bytes: PackedByteArray, mask_checksum: int) -> bool:
	var required_pixel_count := StageGenerationContract.REQUIRED_MASK_SIZE \
			* StageGenerationContract.REQUIRED_MASK_SIZE
	if not _target_mask.is_empty() or bytes.size() != required_pixel_count \
			or mask_checksum == 0 or TargetMaskRasterizer.byte_checksum(bytes) != mask_checksum:
		return false
	_target_mask = bytes.duplicate()
	_target_mask_checksum = mask_checksum
	for pixel_index in range(_target_mask.size()):
		if _target_mask[pixel_index] >= 128:
			_target_pixel_indices.append(pixel_index)
	_cache_target_center()
	return true


func install_footprint(cells: PackedByteArray) -> bool:
	if not _footprint_cells.is_empty() or cells.size() != cell_count.x * cell_count.y:
		return false
	var active_count := 0
	for value in cells:
		if value != 0:
			active_count += 1
	if active_count <= 0:
		return false
	_footprint_cells = cells.duplicate()
	return true


func footprint_cells_read_only() -> PackedByteArray:
	return _footprint_cells.duplicate()


func has_valid_footprint() -> bool:
	if _footprint_cells.size() != cell_count.x * cell_count.y:
		return false
	for value in _footprint_cells:
		if value != 0:
			return true
	return false


func has_valid_target_mask() -> bool:
	var required_pixel_count := StageGenerationContract.REQUIRED_MASK_SIZE \
			* StageGenerationContract.REQUIRED_MASK_SIZE
	return _target_mask.size() == required_pixel_count \
			and _target_mask_checksum != 0 \
			and TargetMaskRasterizer.byte_checksum(_target_mask) == _target_mask_checksum


func is_certified() -> bool:
	if not is_valid() or not has_valid_target_mask() \
			or not has_valid_target_surface_coverage() \
			or reachability_certificate == null or not reachability_certificate.is_valid():
		return false
	# DirectReachabilityCertificate validates primitive witness indices but cannot
	# know this layout's target count. Keep the cross-resource cardinality check
	# here so a partial prefix can never be promoted to a complete proof.
	if reachability_certificate.target_witness_indices.size() != target_pixel_count():
		return false
	if reachability_certificate.minimum_distance_margins.size() \
			!= reachability_certificate.witness_count() \
			or reachability_certificate.minimum_range_margins.size() \
			!= reachability_certificate.witness_count():
		return false
	var summit_matches := true
	if reachability_certificate.summit_region_checksum != 0:
		summit_matches = reachability_certificate.summit_region_checksum == summit_region_checksum() \
				and reachability_certificate.summit_triangle_ids == summit_triangle_ids() \
				and reachability_certificate.summit_witness != null \
				and reachability_certificate.summit_witness.is_valid() \
				and reachability_certificate.summit_minimum_height_margin <= 1.0
	return summit_matches \
			and reachability_certificate.stage_id \
					== StageGenerationProfile.stage_id_from_profile_id(profile_id) \
			and reachability_certificate.profile_version == profile_version \
			and reachability_certificate.terrain_seed == terrain_seed \
			and reachability_certificate.height_checksum == checksum \
			and reachability_certificate.target_checksum == _target_mask_checksum \
			and reachability_certificate.placement_checksum == placement_checksum() \
			and reachability_certificate.play_bounds_checksum == play_bounds.checksum() \
			and reachability_certificate.reachable_target_checksum \
					== reachable_target_checksum(
						reachability_certificate.target_witness_indices
					) \
			and reachability_certificate.default_aim != null \
			and reachability_certificate.default_aim.is_valid()


func is_runtime_ready() -> bool:
	if _runtime_readiness_verified:
		return true
	if not is_valid() or not has_valid_target_mask() \
			or not has_valid_target_surface_coverage() \
			or not _default_witness_matches_layout() \
			or not _summit_witness_matches_layout():
		return false
	# A certificate remains optional. Once present, it is an authority and an
	# incomplete or stale proof must not silently fall back to generated witnesses.
	_runtime_readiness_verified = reachability_certificate == null or is_certified()
	return _runtime_readiness_verified


func runtime_readiness_diagnostic() -> Dictionary:
	return {
		"layout_valid": is_valid(),
		"target_valid": has_valid_target_mask(),
		"coverage_metadata_valid": has_valid_target_surface_coverage(),
		"default_matches": _default_witness_matches_layout(),
		"summit_matches": _summit_witness_matches_layout(),
		"certificate_valid": reachability_certificate == null or is_certified(),
	}


## Cheap identity check for already accepted process-lifetime caches. Generation
## performs structural and mask validation before a layout can enter that cache.
func matches_stage_identity(stage: StageData) -> bool:
	if stage == null or stage.generation_profile == null:
		return false
	var profile := stage.generation_profile
	var expected_seed := stage.terrain_seed if stage.terrain_seed != 0 else profile.base_seed
	return profile_id == profile.profile_id \
			and profile_version == profile.profile_version \
			and layout_version == profile.generation_contract.layout_version \
			and terrain_seed == expected_seed \
			and checksum != 0 \
			and target_mask_checksum != 0 \
			and has_valid_target_surface_coverage() \
			and route_graph != null \
			and route_graph.node_by_id(GeneratedRouteNode.summit_id(stage.stage_id)) != null


## Creates the active-scene view of an accepted layout. Large structural owners
## remain shared and read-only; mutable runtime annotations and packed masks are
## isolated so gameplay cannot change the preparer's retained source layout.
func copy_for_runtime() -> GeneratedStageLayout:
	if not is_runtime_ready():
		return null
	var result := GeneratedStageLayout.new()
	result.profile_id = profile_id
	result.profile_version = profile_version
	result.layout_version = layout_version
	result.terrain_seed = terrain_seed
	result.cell_count = cell_count
	result.local_bounds = local_bounds
	result.heights = heights.duplicate()
	result.top_topology = top_topology
	result.route_graph = route_graph
	result.play_bounds = play_bounds
	result.reachability_certificate = reachability_certificate
	result.generated_default_aim = generated_default_aim
	result.generated_default_witness = generated_default_witness.copy() \
			if generated_default_witness != null else null
	result.generated_summit_witness = generated_summit_witness.copy() \
			if generated_summit_witness != null else null
	result.metrics = metrics.duplicate(true)
	result.checksum = checksum
	for placement in mechanism_placements:
		result.mechanism_placements.append(placement)
	for placement in decoration_placements:
		result.decoration_placements.append(placement)
	# The source passed the full readiness proof above. Copy its private mask
	# caches directly so runtime isolation does not repeat the 512-square
	# checksum and target-index scan on the main thread.
	result._footprint_cells = _footprint_cells.duplicate()
	result._target_mask = _target_mask.duplicate()
	result._target_mask_checksum = _target_mask_checksum
	result._target_pixel_indices = _target_pixel_indices.duplicate()
	result._target_centroid_local_xz = _target_centroid_local_xz
	result._target_pixel_nearest_centroid = _target_pixel_nearest_centroid
	result._coverage_metric_version = _coverage_metric_version
	result._total_target_surface_area = _total_target_surface_area
	result._target_surface_area_checksum = _target_surface_area_checksum
	result._runtime_readiness_verified = true
	return result


func _default_witness_matches_layout() -> bool:
	if generated_default_witness == null or not generated_default_witness.is_valid():
		return false
	var pixel_index := generated_default_witness.target_pixel_index
	if pixel_index < 0 or pixel_index >= _target_mask.size() \
			or _target_mask[pixel_index] < 128:
		return false
	var identity := generated_default_witness.predicted_identity
	return identity != null \
			and identity.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			and identity.terrain_cell.x >= 0 and identity.terrain_cell.x < cell_count.x \
			and identity.terrain_cell.y >= 0 and identity.terrain_cell.y < cell_count.y \
			and identity.terrain_triangle in [0, 1] \
			and generated_default_witness.physical_identity != null \
			and generated_default_witness.contacts_are_compatible()


func _summit_witness_matches_layout() -> bool:
	if generated_summit_witness == null or not generated_summit_witness.is_valid(true):
		return false
	if generated_summit_witness.summit_region_checksum != summit_region_checksum():
		return false
	var region := summit_region()
	for sample in region:
		if _witness_matches_sample(generated_summit_witness, sample):
			return true
	return false


func _witness_matches_sample(witness: StageEntryAimWitness, sample: Dictionary) -> bool:
	var identity := witness.predicted_identity
	return identity != null and identity.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			and identity.terrain_cell == sample.cell and identity.terrain_triangle == int(sample.triangle) \
			and witness.physical_identity != null \
			and witness.contacts_are_compatible()


func target_centroid_local_xz() -> Vector2:
	if not has_valid_target_mask() or _target_pixel_indices.is_empty():
		return Vector2(INF, INF)
	return _target_centroid_local_xz


func target_pixel_count() -> int:
	return _target_pixel_indices.size()


## Returns stable top-surface witnesses for the highest visible summit band.
## Keeping the region on the canonical topology makes prediction, collision,
## and any future serialized certificate address the same triangle.
func summit_region(maximum_height_tolerance: float = 0.25) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if top_topology == null or not top_topology.is_valid():
		return result
	# This immutable snapshot is shared across the scan. Duplicating the full
	# vertex array once per triangle makes late-stage runtime validation quadratic.
	var vertices := top_topology.canonical_vertices_read_only()
	var maximum_height := -INF
	for vertex in vertices:
		maximum_height = maxf(maximum_height, vertex.y)
	var seen: Dictionary = {}
	for cell_z in range(cell_count.y):
		for cell_x in range(cell_count.x):
			var cell := Vector2i(cell_x, cell_z)
			if not top_topology.is_cell_active(cell):
				continue
			for triangle_in_cell in range(TerrainTopTopology.TRIANGLES_PER_CELL):
				var triangle_id := top_topology.source_triangle_id(cell, triangle_in_cell)
				if triangle_id < 0 or seen.has(triangle_id):
					continue
				var indices := top_topology.triangle_vertex_indices(cell, triangle_in_cell)
				var a := vertices[indices.x]
				var b := vertices[indices.y]
				var c := vertices[indices.z]
				if maxf(a.y, maxf(b.y, c.y)) < maximum_height - maximum_height_tolerance:
					continue
				seen[triangle_id] = true
				result.append({
					"triangle_id": triangle_id,
					"cell": cell,
					"triangle": triangle_in_cell,
					"point": (a + b + c) / 3.0,
					"normal": top_topology.triangle_normal(cell, triangle_in_cell),
					"maximum_height": maximum_height,
				})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.point.y) != float(b.point.y):
			return float(a.point.y) > float(b.point.y)
		return int(a.triangle_id) < int(b.triangle_id)
	)
	return result


func summit_sample() -> Dictionary:
	var region := summit_region()
	return region[0] if not region.is_empty() else {}


func summit_triangle_ids(maximum_height_tolerance: float = 0.25) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for sample in summit_region(maximum_height_tolerance):
		ids.append(int(sample.triangle_id))
	return ids


func summit_region_checksum(maximum_height_tolerance: float = 0.25) -> int:
	var ids := summit_triangle_ids(maximum_height_tolerance)
	if ids.is_empty():
		return 0
	var hash: int = CHECKSUM_OFFSET
	for triangle_id in ids:
		hash = _hash_int(hash, triangle_id)
	return hash


## Returns the exact topological sample at the target pixel whose center is
## nearest the target-mask centroid. The chosen pixel is cached when the
## immutable target mask is installed; the surface sample still comes from the
## layout's sole accepted terrain topology.
func target_sample_nearest_centroid() -> Dictionary:
	if not has_valid_target_mask() or _target_pixel_nearest_centroid < 0 \
			or top_topology == null:
		return {}
	var local_xz := _target_pixel_center_local(_target_pixel_nearest_centroid)
	var sample := top_topology.surface_sample_at_local(local_xz.x, local_xz.y, false)
	if sample.is_empty():
		return {}
	var mask_size := StageGenerationContract.REQUIRED_MASK_SIZE
	sample["target_pixel_index"] = _target_pixel_nearest_centroid
	sample["target_pixel"] = Vector2i(
		_target_pixel_nearest_centroid % mask_size,
		_target_pixel_nearest_centroid / mask_size
	)
	sample["local_xz"] = local_xz
	return sample


func is_target_local_xz(local_xz: Vector2) -> bool:
	if not has_valid_target_mask() or not local_bounds.has_point(local_xz):
		return false
	var normalized := (local_xz - local_bounds.position) / local_bounds.size
	var mask_size := StageGenerationContract.REQUIRED_MASK_SIZE
	var pixel := Vector2i(
		clampi(floori(normalized.x * mask_size), 0, mask_size - 1),
		clampi(floori(normalized.y * mask_size), 0, mask_size - 1)
	)
	return _target_mask[pixel.y * mask_size + pixel.x] >= 128


func placement_checksum() -> int:
	var hash := CHECKSUM_OFFSET
	hash = _hash_int(hash, mechanism_placements.size())
	for placement in mechanism_placements:
		if placement == null or placement.mechanism_data == null:
			return 0
		hash = _hash_int(hash, int(placement.mechanism_data.kind))
		hash = _hash_string_name(hash, placement.anchor_id)
		hash = _hash_int(hash, placement.route_index)
		hash = _hash_int(hash, int(placement.route_role))
		hash = _hash_int(hash, roundi(placement.route_t * 1000000.0))
		for component in [
			placement.local_transform.origin.x,
			placement.local_transform.origin.y,
			placement.local_transform.origin.z,
			placement.downstream_tangent.x,
			placement.downstream_tangent.y,
			placement.downstream_tangent.z,
		]:
			hash = _hash_int(hash, roundi(float(component) * 1000.0))
		hash = _hash_int(hash, placement.splitter_route_targets.size())
		for target in placement.splitter_route_targets:
			for component in [target.x, target.y, target.z]:
				hash = _hash_int(hash, roundi(float(component) * 1000.0))
		for component in [
			placement.uphill_tangent.x,
			placement.uphill_tangent.y,
			placement.uphill_tangent.z,
		]:
			hash = _hash_int(hash, roundi(float(component) * 1000.0))
	return hash


func reachable_target_checksum(target_witness_indices: PackedInt32Array) -> int:
	if target_witness_indices.size() != _target_pixel_indices.size():
		return 0
	var hash := CHECKSUM_OFFSET
	for target_index in range(_target_pixel_indices.size()):
		hash = _hash_int(hash, _target_pixel_indices[target_index])
		hash = _hash_int(hash, target_witness_indices[target_index])
	return hash


func height_at_local(local_x: float, local_z: float) -> float:
	return top_topology.height_at_local(local_x, local_z) if top_topology != null else 0.0


func normal_at_local(local_x: float, local_z: float) -> Vector3:
	return top_topology.normal_at_local(local_x, local_z) if top_topology != null else Vector3.UP


func surface_sample_at_local(local_x: float, local_z: float, clamp_to_bounds: bool = true) -> Dictionary:
	return top_topology.surface_sample_at_local(local_x, local_z, clamp_to_bounds) \
			if top_topology != null else {}


func _cache_target_center() -> void:
	_target_centroid_local_xz = Vector2(INF, INF)
	_target_pixel_nearest_centroid = -1
	if _target_pixel_indices.is_empty():
		return
	var sum := Vector2.ZERO
	for pixel_index in _target_pixel_indices:
		sum += _target_pixel_center_local(pixel_index)
	_target_centroid_local_xz = sum / float(_target_pixel_indices.size())
	var nearest_distance_squared := INF
	for pixel_index in _target_pixel_indices:
		var distance_squared := _target_pixel_center_local(pixel_index).distance_squared_to(
			_target_centroid_local_xz
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			_target_pixel_nearest_centroid = pixel_index


func _target_pixel_center_local(pixel_index: int) -> Vector2:
	var mask_size := StageGenerationContract.REQUIRED_MASK_SIZE
	var pixel := Vector2i(pixel_index % mask_size, pixel_index / mask_size)
	var normalized := Vector2(
		(float(pixel.x) + 0.5) / float(mask_size),
		(float(pixel.y) + 0.5) / float(mask_size)
	)
	return local_bounds.position + normalized * local_bounds.size


static func _hash_int(hash: int, value: int) -> int:
	for shift in [0, 8, 16, 24]:
		hash = hash ^ ((value >> shift) & 0xff)
		hash = int((hash * CHECKSUM_PRIME) & 0xffffffff)
	return hash


static func _hash_string_name(hash: int, value: StringName) -> int:
	var bytes := String(value).to_utf8_buffer()
	hash = _hash_int(hash, bytes.size())
	for byte in bytes:
		hash = hash ^ byte
		hash = int((hash * CHECKSUM_PRIME) & 0xffffffff)
	return hash
