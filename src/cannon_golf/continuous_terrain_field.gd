class_name CannonGolfContinuousTerrainField
extends RefCounted

## Continuous authoring source compiled into the regular gameplay height grid.
## Features operate at macro scale; hard ballistics, camera, slope, and basin
## constraints remain later compiler stages in the course generator.

const FEATURE := preload("res://src/cannon_golf/continuous_terrain_feature.gd")

var local_bounds := Rect2()
var base_height := 0.0
var relief := 1.0
var seed_phase := 0.0

var _features: Array[RefCounted] = []


func add_feature(feature: RefCounted) -> bool:
	if feature == null or not feature.is_valid():
		return false
	_features.append(feature)
	return true


func feature_count() -> int:
	return _features.size()


func is_valid() -> bool:
	if local_bounds.size.x <= 0.0 or local_bounds.size.y <= 0.0 \
			or not is_finite(base_height) or not is_finite(relief) or relief <= 0.0 \
			or not is_finite(seed_phase) or _features.is_empty():
		return false
	for feature in _features:
		if feature == null or not feature.is_valid():
			return false
	return true


func sample(point: Vector2) -> float:
	if not is_valid() or not point.is_finite():
		return NAN
	var normalized := (point - local_bounds.position) / local_bounds.size
	# Two domain-scale waves prevent a sterile mathematical surface without
	# reintroducing cell-sized noise. Their wavelength follows the whole course.
	var macro_variation := (
		sin((normalized.x * 1.35 + normalized.y * 0.55) * TAU + seed_phase)
		+ cos((normalized.y * 1.10 - normalized.x * 0.40) * TAU - seed_phase * 0.73)
	) * relief * 0.012
	var height := base_height + relief * 0.055 + macro_variation
	for feature in _features:
		var influence: Vector2 = feature.influence_at(point)
		if influence.x <= 0.0:
			continue
		var feature_amplitude: float = feature.amplitude_at(influence.y)
		var displacement: float = relief * feature_amplitude * influence.x
		match feature.kind:
			FEATURE.Kind.VALLEY:
				height -= displacement
			FEATURE.Kind.SHELF:
				var shelf_height := base_height + relief * feature_amplitude
				height = lerpf(height, maxf(height, shelf_height), influence.x * 0.72)
			_:
				height += displacement
	return height
