class_name CannonGolfCourseData
extends Resource

const AUTHORING_LEGACY_MIGRATION := 0
const AUTHORING_CONSTRAINT_RECIPE := 1

@export_category("Identity")
@export var course_id: StringName
@export var display_name: String
@export_multiline var short_brief: String

@export_category("Authoring Boundary")
@export_enum("Legacy migration inputs", "Constraint recipe") var authoring_mode := AUTHORING_LEGACY_MIGRATION
## Inclusive seed range. The resolver selects one deterministic member.
@export var terrain_seed_window := Vector2i(1, 1)
@export var difficulty_targets: Dictionary = {}

@export_category("Generated Terrain")
@export var generation_profile: StageGenerationProfile
@export var terrain_seed: int = StageProgressionData.CANONICAL_TERRAIN_SEED
@export_range(0.25, 2.5, 0.01) var terrain_horizontal_scale := 1.0
@export_range(0.08, 1.50, 0.01) var terrain_vertical_scale := 0.45
@export var terrain_origin := Vector3(0.0, -4.0, 0.0)
@export_range(0.05, 0.45, 0.01) var goal_route_t := 0.18
@export_range(0.7, 1.0, 0.01) var cannon_route_t := 1.0
@export_range(0.3, 5.0, 0.05) var goal_recess_depth := 3.5
@export var terrain_color := Color("596661")
@export var terrain_accent_color := Color("47544F")

@export_category("Authored Goal Layout")
@export var legs: Array[CannonGolfCourseLegData] = []

@export_category("Semantic Landforms")
@export var landform_features: Array[Resource] = []

@export_category("Play")
@export var cannon_position := Vector3.ZERO
@export_range(-180.0, 180.0, 0.1) var shot_axis_yaw_degrees := 0.0
@export var goal_position := Vector3.ZERO
@export_range(3.5, 14.0, 0.1) var goal_radius := 10.0
@export_range(0, 2, 1) var legacy_rim_elevation_band := 1
@export var play_bounds := AABB(Vector3(-50.0, -15.0, -90.0), Vector3(100.0, 70.0, 130.0))
@export var content_bounds := AABB(Vector3(-50.0, -15.0, -90.0), Vector3(100.0, 50.0, 130.0))

@export_category("Planning Cameras")
@export var planning_focus := Vector3(0.0, 2.0, -15.0)
@export var oblique_offset := Vector3(30.0, 64.0, 55.0)
@export var side_offset := Vector3(48.0, 13.0, 1.0)

@export_category("Launch Setup")
@export_range(0.0, 100.0, 1.0) var default_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var default_elevation_degrees := 50.0
@export_range(10.0, 100.0, 1.0) var default_power_percent := 50.0
@export_range(0.0, 100.0, 1.0) var solution_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var solution_elevation_degrees := 50.0
@export_range(10.0, 100.0, 1.0) var solution_power_percent := 50.0

# Runtime-only projection marker. Authored recipe resources keep this false and
# must not contain exact positions; CourseBuilder sets it only on its duplicate
# after an identity-checked prepared artifact supplies those positions.
var is_prepared_runtime_projection := false


func is_valid() -> bool:
	if course_id.is_empty() or display_name.strip_edges().is_empty():
		return false
	if generation_profile == null or not generation_profile.is_valid() \
			or terrain_horizontal_scale <= 0.0 \
			or terrain_vertical_scale <= 0.0 or not terrain_origin.is_finite() \
			or goal_recess_depth <= 0.0:
		return false
	if is_constraint_recipe():
		return _recipe_is_valid()
	if terrain_seed == 0 or goal_route_t <= 0.0 or goal_route_t >= cannon_route_t \
			or cannon_route_t > 1.0:
		return false
	if not legs.is_empty():
		return _explicit_legs_are_valid()
	return cannon_position.is_finite() and goal_position.is_finite() \
			and is_finite(shot_axis_yaw_degrees) \
			and planning_focus.is_finite() and oblique_offset.is_finite() \
			and side_offset.is_finite() and goal_radius >= 3.5 \
			and play_bounds.has_volume() and content_bounds.has_volume() \
			and _launch_setup_is_valid(default_horizontal_aim, default_elevation_degrees, default_power_percent) \
			and _launch_setup_is_valid(solution_horizontal_aim, solution_elevation_degrees, solution_power_percent)


func direct_solution() -> Vector3:
	assert(legs.is_empty(), "direct_solution() is only valid for legacy one-goal courses.")
	return Vector3(solution_horizontal_aim, solution_elevation_degrees, solution_power_percent)


func leg_count() -> int:
	return legs.size() if not legs.is_empty() else 1


func leg_at(index: int) -> CannonGolfCourseLegData:
	if index < 0 or index >= leg_count():
		return null
	if not legs.is_empty():
		return legs[index]
	var legacy_leg := CannonGolfCourseLegData.new()
	legacy_leg.goal_route_t = goal_route_t
	legacy_leg.launcher_route_t = cannon_route_t
	legacy_leg.goal_radius = goal_radius
	legacy_leg.rim_elevation_band = legacy_rim_elevation_band
	legacy_leg.goal_recess_depth = goal_recess_depth
	legacy_leg.goal_lip_height = 0.0
	legacy_leg.default_horizontal_aim = default_horizontal_aim
	legacy_leg.default_elevation_degrees = default_elevation_degrees
	legacy_leg.default_power_percent = default_power_percent
	legacy_leg.solution_horizontal_aim = solution_horizontal_aim
	legacy_leg.solution_elevation_degrees = solution_elevation_degrees
	legacy_leg.solution_power_percent = solution_power_percent
	return legacy_leg


func solution_for_leg(index: int) -> Vector3:
	var leg := leg_at(index)
	assert(leg != null, "Course leg index must be valid.")
	return leg.direct_solution()


func has_explicit_legs() -> bool:
	return not legs.is_empty()


func is_constraint_recipe() -> bool:
	return authoring_mode == AUTHORING_CONSTRAINT_RECIPE


## Runtime callers must only receive a baked prepared artifact for this mode.
func requires_prepared_artifact() -> bool:
	return is_constraint_recipe()


func _recipe_is_valid() -> bool:
	if terrain_seed_window.x <= 0 or terrain_seed_window.y <= 0 \
			or terrain_seed_window.x > terrain_seed_window.y or legs.is_empty() \
			or terrain_seed_window.y - terrain_seed_window.x + 1 > 180 \
			or legs.size() > 6 \
			or not (_prepared_projection_is_valid() if is_prepared_runtime_projection \
					else _legacy_resolved_values_are_clear()) \
			or not _difficulty_targets_are_valid():
		return false
	var roles: Dictionary = {}
	var previous_route_min := cannon_route_t
	for leg in legs:
		if leg == null or not leg.is_valid_recipe() \
				or leg.route_index >= generation_profile.routes.size() \
				or leg.route_interval.y > previous_route_min - 0.02 \
				or roles.has(leg.semantic_role):
			return false
		roles[leg.semantic_role] = true
		previous_route_min = leg.route_interval.x
	var feature_ids: Dictionary = {}
	for feature in landform_features:
		if feature == null or not feature.is_valid() or feature_ids.has(feature.feature_id):
			return false
		feature_ids[feature.feature_id] = true
	return true


func _legacy_resolved_values_are_clear() -> bool:
	return cannon_position == Vector3.ZERO and goal_position == Vector3.ZERO \
			and _launch_setup_is_valid(default_horizontal_aim, default_elevation_degrees, default_power_percent) \
			and Vector3(default_horizontal_aim, default_elevation_degrees, default_power_percent) \
				== Vector3(50.0, 50.0, 50.0) \
			and Vector3(solution_horizontal_aim, solution_elevation_degrees, solution_power_percent) \
				== Vector3(50.0, 50.0, 50.0)


func _prepared_projection_is_valid() -> bool:
	return cannon_position.is_finite() and goal_position.is_finite() \
			and is_finite(shot_axis_yaw_degrees) and planning_focus.is_finite() \
			and oblique_offset.is_finite() and side_offset.is_finite() \
			and goal_radius >= 3.5 and play_bounds.has_volume() and content_bounds.has_volume() \
			and Vector3(default_horizontal_aim, default_elevation_degrees, default_power_percent) \
				== Vector3(50.0, 50.0, 50.0) \
			and Vector3(solution_horizontal_aim, solution_elevation_degrees, solution_power_percent) \
				== Vector3(50.0, 50.0, 50.0)


func _difficulty_targets_are_valid() -> bool:
	for key in difficulty_targets:
		var value: Variant = difficulty_targets[key]
		if str(key).is_empty() or not (value is int or value is float) \
				or not is_finite(float(value)) or float(value) < 0.0:
			return false
	return true


func _explicit_legs_are_valid() -> bool:
	if legs.is_empty() or legs.size() > 6:
		return false
	var goal_regions: Array[Vector2] = []
	var feature_ids: Dictionary = {}
	for feature in landform_features:
		if feature == null or not feature.is_valid() or feature_ids.has(feature.feature_id):
			return false
		feature_ids[feature.feature_id] = true
	for index in range(legs.size()):
		var leg := legs[index]
		if leg == null or not leg.is_valid():
			return false
		if index == 0:
			if not is_equal_approx(leg.launcher_route_t, cannon_route_t):
				return false
		if not leg.feature_anchor.is_empty() and not feature_ids.has(leg.feature_anchor):
			return false
		var region := Vector2(leg.goal_route_t, float(leg.route_index)) + leg.goal_placement_offset / 1000.0
		for prior in goal_regions:
			if region.distance_to(prior) < 0.01:
				return false
		goal_regions.append(region)
	return true


func landform_signature() -> String:
	var values := PackedStringArray()
	for feature in landform_features:
		if feature == null:
			return ""
		values.append("%s:%d:%s:%s:%s:%s:%s" % [
			feature.feature_id, feature.kind, String.num(feature.route_t, 6),
			"%s,%s" % [
				String.num(feature.route_offset.x, 6),
				String.num(feature.route_offset.y, 6),
			], String.num(feature.radius, 6),
			String.num(feature.amplitude, 6), String.num(feature.flatness, 6),
		])
	return ";".join(values)


func _launch_setup_is_valid(horizontal: float, elevation: float, power: float) -> bool:
	return is_finite(horizontal) and horizontal >= 0.0 and horizontal <= 100.0 \
			and is_equal_approx(horizontal, roundf(horizontal)) \
			and is_finite(elevation) and elevation >= 10.0 and elevation <= 68.0 \
			and is_equal_approx(elevation, roundf(elevation)) \
			and is_finite(power) and power >= 10.0 and power <= 100.0 \
			and is_equal_approx(power, roundf(power))
