class_name CannonGolfPreparedCourseLeg
extends Resource

## Immutable baked result for one ordered launcher-to-goal checkpoint.

@export_storage var route_index := 0
@export_storage var rim_elevation_band := 1
@export_storage var feature_anchor: StringName
@export_storage var goal_position := Vector3.ZERO
@export_storage var goal_radius := 0.0
@export_storage var goal_rim_y := 0.0
@export_storage var goal_lip_y := 0.0
@export_storage var launcher_position := Vector3.ZERO
@export_storage var shot_axis_yaw_degrees := 0.0
@export_storage var frame_bounds := AABB()
@export_storage var corridor_admission: Dictionary = {}
@export_storage var intended_setup := Vector3.ZERO
@export_storage var certified_setup := Vector3.ZERO
@export_storage var center_success_count := 0
@export_storage var neighbor_successes: Dictionary = {}
@export_storage var axis_pass_evidence: Dictionary = {}
@export_storage var default_attempt_count := 0
@export_storage var default_success_count := 0
@export_storage var settlement_time_seconds := 0.0
@export_storage var robustness_margins: Dictionary = {}


func is_valid() -> bool:
	return route_index >= 0 and rim_elevation_band >= 0 and rim_elevation_band <= 2 \
			and goal_position.is_finite() and launcher_position.is_finite() \
			and is_finite(goal_radius) and goal_radius >= 3.5 \
			and is_finite(goal_rim_y) and is_finite(goal_lip_y) \
			and goal_lip_y > goal_position.y \
			and is_finite(shot_axis_yaw_degrees) and frame_bounds.has_volume() \
			and _admission_is_valid()


func _admission_is_valid() -> bool:
	for key in [
		"point_count", "minimum_range_margin", "minimum_yaw_margin_degrees",
		"minimum_height_margin", "farthest_distance",
	]:
		if not corridor_admission.has(key):
			return false
	var count := int(corridor_admission["point_count"])
	return count > 0 \
			and is_finite(float(corridor_admission["minimum_range_margin"])) \
			and is_finite(float(corridor_admission["minimum_yaw_margin_degrees"])) \
			and is_finite(float(corridor_admission["minimum_height_margin"])) \
			and is_finite(float(corridor_admission["farthest_distance"]))


func has_complete_certificate() -> bool:
	if not _setup_is_valid(certified_setup) or center_success_count != 2 \
			or default_attempt_count != 2 or default_success_count != 0 \
			or not is_finite(settlement_time_seconds) \
			or settlement_time_seconds <= 0.0:
		return false
	var neighbor_total := 0
	for axis in [&"horizontal", &"elevation", &"power"]:
		var successes := int(neighbor_successes.get(axis, 0))
		if successes < 1 or successes > 2 \
				or not axis_pass_evidence.has(axis) \
				or not _finite_metric_dictionary(axis_pass_evidence[axis]) \
				or not robustness_margins.has(axis) \
				or not is_finite(float(robustness_margins[axis])):
			return false
		neighbor_total += successes
	return neighbor_total >= 4


func has_any_certificate_data() -> bool:
	return not certified_setup.is_zero_approx() or center_success_count != 0 \
			or not neighbor_successes.is_empty() or not axis_pass_evidence.is_empty() \
			or default_attempt_count != 0 or default_success_count != 0 \
			or not is_zero_approx(settlement_time_seconds) \
			or not robustness_margins.is_empty()


func has_valid_intended_setup() -> bool:
	return _setup_is_valid(intended_setup)


func _setup_is_valid(setup: Vector3) -> bool:
	return setup.is_finite() and setup.x >= 0.0 and setup.x <= 100.0 \
			and is_equal_approx(setup.x, roundf(setup.x)) \
			and setup.y >= 10.0 and setup.y <= 68.0 \
			and is_equal_approx(setup.y, roundf(setup.y)) \
			and setup.z >= 10.0 and setup.z <= 100.0 \
			and is_equal_approx(setup.z, roundf(setup.z))


func _finite_metric_dictionary(value: Variant) -> bool:
	if not (value is Dictionary) or (value as Dictionary).is_empty():
		return false
	for metric in value.values():
		if not (metric is float or metric is int) or not is_finite(float(metric)):
			return false
	return true
