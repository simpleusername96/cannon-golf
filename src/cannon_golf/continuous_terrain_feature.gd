class_name CannonGolfContinuousTerrainFeature
extends RefCounted

## One compact semantic constraint in the continuous terrain source. Curves use
## a polyline spine with round caps; a one-point feature is radial.

enum Kind { RIDGE, VALLEY, SHELF, PEAK }

var kind: Kind = Kind.RIDGE
var control_points := PackedVector2Array()
var half_width := 1.0
var amplitude_ratio := 0.0
var end_amplitude_ratio := 0.0
var profile_power := 1.0


func configure(
		feature_kind: Kind,
		points: PackedVector2Array,
		width: float,
		start_amplitude_ratio: float,
		finish_amplitude_ratio: float,
		shape_power: float = 1.0
) -> RefCounted:
	kind = feature_kind
	control_points = points.duplicate()
	half_width = width
	amplitude_ratio = start_amplitude_ratio
	end_amplitude_ratio = finish_amplitude_ratio
	profile_power = shape_power
	return self


func is_valid() -> bool:
	if kind < Kind.RIDGE or kind > Kind.PEAK or control_points.is_empty() \
			or half_width <= 0.0 or profile_power <= 0.0 \
			or not is_finite(amplitude_ratio) or not is_finite(end_amplitude_ratio):
		return false
	for point in control_points:
		if not point.is_finite():
			return false
	return true


## Returns compact influence and normalized distance along the feature spine.
func influence_at(point: Vector2) -> Vector2:
	if not is_valid() or not point.is_finite():
		return Vector2.ZERO
	if control_points.size() == 1:
		return Vector2(_cross_section(point.distance_to(control_points[0])), 0.5)
	var total_length := 0.0
	var segment_lengths := PackedFloat32Array()
	for index in range(control_points.size() - 1):
		var segment_length := control_points[index].distance_to(control_points[index + 1])
		segment_lengths.append(segment_length)
		total_length += segment_length
	if total_length <= 0.0001:
		return Vector2(_cross_section(point.distance_to(control_points[0])), 0.5)
	var best_distance := INF
	var best_along := 0.0
	var traversed := 0.0
	for index in range(control_points.size() - 1):
		var start := control_points[index]
		var finish := control_points[index + 1]
		var delta := finish - start
		var length_squared := delta.length_squared()
		var segment_t := clampf((point - start).dot(delta) / length_squared, 0.0, 1.0) \
				if length_squared > 0.000001 else 0.0
		var distance := point.distance_to(start + delta * segment_t)
		if distance < best_distance:
			best_distance = distance
			best_along = (traversed + segment_lengths[index] * segment_t) / total_length
		traversed += segment_lengths[index]
	return Vector2(_cross_section(best_distance), clampf(best_along, 0.0, 1.0))


func amplitude_at(along_t: float) -> float:
	return lerpf(amplitude_ratio, end_amplitude_ratio, _smootherstep(along_t))


func _cross_section(distance: float) -> float:
	if distance >= half_width:
		return 0.0
	return pow(_smootherstep(1.0 - distance / half_width), profile_power)


static func _smootherstep(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * clamped * (clamped * (clamped * 6.0 - 15.0) + 10.0)
