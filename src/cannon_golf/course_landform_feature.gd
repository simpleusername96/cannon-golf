class_name CannonGolfCourseLandformFeature
extends Resource

## A bounded authored deformation applied to the connected sampled terrain.

enum Kind { PEAK, RIDGE, SADDLE, PLATEAU, VALLEY, BASIN, TERRACE }

@export var feature_id: StringName
@export var kind: Kind = Kind.PEAK
@export_range(0.02, 0.98, 0.01) var route_t := 0.5
@export var route_offset := Vector2.ZERO
@export_range(4.0, 80.0, 0.5) var radius := 20.0
@export_range(1.0, 60.0, 0.5) var amplitude := 12.0
@export_range(0.05, 1.0, 0.05) var flatness := 0.35


func is_valid() -> bool:
	return not feature_id.is_empty() and kind >= Kind.PEAK and kind <= Kind.TERRACE \
			and route_t > 0.0 and route_t < 1.0 and route_offset.is_finite() \
			and radius > 0.0 and amplitude > 0.0 and flatness > 0.0 and flatness <= 1.0
