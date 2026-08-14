class_name CannonGolfPreparedCourseDressing
extends Resource

## Small immutable placement record; model loading remains the builder's edge I/O.

@export_storage var model_path := ""
@export_storage var position := Vector3.ZERO
@export_storage var yaw_degrees := 0.0
@export_storage var uniform_scale := 1.0
@export_storage var is_tree := false


func is_valid() -> bool:
	return model_path.begins_with("res://") and position.is_finite() \
			and is_finite(yaw_degrees) and is_finite(uniform_scale) \
			and uniform_scale > 0.0
