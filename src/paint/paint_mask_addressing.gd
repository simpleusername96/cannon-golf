class_name PaintMaskAddressing
extends RefCounted


static func snap_uv_to_pixel(uv: Vector2, mask_size: int) -> Vector2i:
	if not uv.is_finite() or mask_size <= 0:
		return Vector2i(-1, -1)
	var pixel_center := uv * float(mask_size) - Vector2(0.5, 0.5)
	return Vector2i(
		clampi(floori(pixel_center.x + 0.5), 0, mask_size - 1),
		clampi(floori(pixel_center.y + 0.5), 0, mask_size - 1)
	)


static func candidate_sort_key(candidate: Vector2i, snapped: Vector2i) -> PackedInt32Array:
	var delta := candidate - snapped
	return PackedInt32Array([delta.length_squared(), candidate.y, candidate.x])
