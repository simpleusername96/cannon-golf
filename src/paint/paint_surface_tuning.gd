class_name PaintSurfaceTuning
extends Resource

const CONTRACT_VERSION := 5

@export_range(1, 2048, 1) var mask_size: int = 512
@export_range(1, 255, 1) var painted_threshold_byte: int = 128
@export_range(0.0, 1.0, 0.01) var core_ratio: float = 0.85
@export_range(0, 8, 1) var maximum_bridge_ticks: int = 2
@export_range(0.0, 32.0, 0.1) var maximum_bridge_chord: float = 10.0
@export_range(0.01, 4.0, 0.01) var bridge_sample_spacing: float = 0.5
@export_range(0.0, 4.0, 0.01) var surface_clearance: float = 0.4
@export_range(0.0, 90.0, 0.1) var maximum_normal_delta_degrees: float = 30.0
@export_range(0.01, 8.0, 0.01) var verification_ray_span: float = 1.0


func is_valid() -> bool:
	return mask_size > 0 and painted_threshold_byte > 0 and painted_threshold_byte <= 255 \
			and core_ratio > 0.0 and core_ratio <= 1.0 \
			and maximum_bridge_ticks >= 0 \
			and is_finite(maximum_bridge_chord) and maximum_bridge_chord > 0.0 \
			and is_finite(bridge_sample_spacing) and bridge_sample_spacing > 0.0 \
			and bridge_sample_spacing <= maximum_bridge_chord \
			and is_finite(surface_clearance) and surface_clearance >= 0.0 \
			and is_finite(maximum_normal_delta_degrees) \
			and maximum_normal_delta_degrees > 0.0 \
			and maximum_normal_delta_degrees <= 90.0 \
			and is_finite(verification_ray_span) and verification_ray_span > 0.0
