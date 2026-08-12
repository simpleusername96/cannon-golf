class_name TargetSurfaceCoverage
extends RefCounted

## Pure metric-2 rules for weighting an XZ-projected target texel by the
## physical area of its canonical playable-terrain triangle.

const METRIC_VERSION := 2
const CHECKSUM_OFFSET := 2166136261
const CHECKSUM_PRIME := 16777619
const AREA_QUANTIZATION := 1000000.0


static func projected_texel_area(local_bounds: Rect2, mask_size: int) -> float:
	if not local_bounds.has_area() or mask_size <= 0:
		return -1.0
	return local_bounds.size.x * local_bounds.size.y / float(mask_size * mask_size)


static func texel_surface_area(canonical_normal: Vector3, projected_area: float) -> float:
	if not canonical_normal.is_finite() or canonical_normal.is_zero_approx() \
			or not is_finite(projected_area) or projected_area <= 0.0:
		return -1.0
	var normal := canonical_normal.normalized()
	if normal.y <= 0.0:
		return -1.0
	return projected_area / normal.y


static func total_target_surface_area(
		target_mask: PackedByteArray,
		topology: TerrainTopTopology,
		local_bounds: Rect2,
		mask_size: int,
		painted_threshold_byte: int = 128
) -> float:
	if topology == null or not topology.is_valid() \
			or target_mask.size() != mask_size * mask_size:
		return -1.0
	var projected_area := projected_texel_area(local_bounds, mask_size)
	if projected_area <= 0.0:
		return -1.0
	var total := 0.0
	for pixel_index in range(target_mask.size()):
		if target_mask[pixel_index] < painted_threshold_byte:
			continue
		var pixel := Vector2i(pixel_index % mask_size, pixel_index / mask_size)
		var normalized := Vector2(
			(float(pixel.x) + 0.5) / float(mask_size),
			(float(pixel.y) + 0.5) / float(mask_size)
		)
		var local_xz := local_bounds.position + normalized * local_bounds.size
		var sample := topology.surface_sample_at_local(local_xz.x, local_xz.y, false)
		if sample.is_empty():
			return -1.0
		var weight := texel_surface_area(sample.normal, projected_area)
		if weight <= 0.0:
			return -1.0
		total += weight
	return total if is_finite(total) and total > 0.0 else -1.0


static func metadata_checksum(metric_version: int, total_surface_area: float) -> int:
	if metric_version != METRIC_VERSION or not is_finite(total_surface_area) \
			or total_surface_area <= 0.0:
		return 0
	var quantized := roundi(total_surface_area * AREA_QUANTIZATION)
	var hash: int = CHECKSUM_OFFSET
	for value in [metric_version, quantized]:
		for shift in range(0, 64, 8):
			hash = hash ^ ((value >> shift) & 0xff)
			hash = int((hash * CHECKSUM_PRIME) & 0xffffffff)
	return hash if hash != 0 else 1


static func metadata_is_valid(
		metric_version: int,
		total_surface_area: float,
		checksum: int
) -> bool:
	return metric_version == METRIC_VERSION \
			and checksum != 0 \
			and checksum == metadata_checksum(metric_version, total_surface_area)
