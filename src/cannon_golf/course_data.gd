class_name CannonGolfCourseData
extends Resource

@export_category("Identity")
@export var course_id: StringName
@export var display_name: String
@export_multiline var short_brief: String

@export_category("Generated Terrain")
@export var generation_profile: StageGenerationProfile
@export var terrain_seed: int = StageProgressionData.CANONICAL_TERRAIN_SEED
@export_range(0.25, 1.0, 0.01) var terrain_horizontal_scale := 1.0
@export_range(0.08, 1.50, 0.01) var terrain_vertical_scale := 0.45
@export var terrain_origin := Vector3(0.0, -4.0, 0.0)
@export_range(0.05, 0.45, 0.01) var goal_route_t := 0.18
@export_range(0.7, 1.0, 0.01) var cannon_route_t := 1.0
@export_range(0.3, 5.0, 0.05) var goal_recess_depth := 3.5
@export var terrain_color := Color("9DA6A3")
@export var terrain_accent_color := Color("87938F")

@export_category("Ordered Relay Legs")
@export var legs: Array[CannonGolfCourseLegData] = []

@export_category("Play")
@export var cannon_position := Vector3.ZERO
@export_range(-180.0, 180.0, 0.1) var shot_axis_yaw_degrees := 0.0
@export var goal_position := Vector3(0.0, 0.0, -40.0)
@export_range(3.5, 14.0, 0.1) var goal_radius := 10.0
@export var play_bounds := AABB(Vector3(-50.0, -15.0, -90.0), Vector3(100.0, 70.0, 130.0))
@export var content_bounds := AABB(Vector3(-50.0, -15.0, -90.0), Vector3(100.0, 50.0, 130.0))

@export_category("Planning Cameras")
@export var planning_focus := Vector3(0.0, 2.0, -15.0)
@export var oblique_offset := Vector3(42.0, 37.0, 50.0)
@export var side_offset := Vector3(48.0, 13.0, 1.0)

@export_category("Launch Setup")
@export_range(0.0, 100.0, 1.0) var default_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var default_elevation_degrees := 50.0
@export_range(10.0, 100.0, 1.0) var default_power_percent := 50.0
@export_range(0.0, 100.0, 1.0) var solution_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var solution_elevation_degrees := 42.0
@export_range(10.0, 100.0, 1.0) var solution_power_percent := 55.0


func is_valid() -> bool:
	if course_id.is_empty() or display_name.strip_edges().is_empty():
		return false
	if generation_profile == null or not generation_profile.is_valid() \
			or terrain_seed == 0 or terrain_horizontal_scale <= 0.0 \
			or terrain_vertical_scale <= 0.0 or not terrain_origin.is_finite() \
			or goal_route_t <= 0.0 or goal_route_t >= cannon_route_t \
			or cannon_route_t > 1.0 or goal_recess_depth <= 0.0:
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


func _explicit_legs_are_valid() -> bool:
	if legs.size() < 2:
		return false
	var previous_goal_t := 1.0
	for index in range(legs.size()):
		var leg := legs[index]
		if leg == null or not leg.is_valid():
			return false
		if index == 0:
			if not is_equal_approx(leg.launcher_route_t, cannon_route_t):
				return false
		else:
			# Every relay anchor stays on the route segment from the completed goal
			# toward the incoming goal; route t decreases toward the summit.
			if leg.launcher_route_t >= previous_goal_t or leg.launcher_route_t <= leg.goal_route_t:
				return false
		if leg.goal_route_t >= previous_goal_t:
			return false
		previous_goal_t = leg.goal_route_t
	return true


func _launch_setup_is_valid(horizontal: float, elevation: float, power: float) -> bool:
	return is_finite(horizontal) and horizontal >= 0.0 and horizontal <= 100.0 \
			and is_equal_approx(horizontal, roundf(horizontal)) \
			and is_finite(elevation) and elevation >= 10.0 and elevation <= 68.0 \
			and is_equal_approx(elevation, roundf(elevation)) \
			and is_finite(power) and power >= 10.0 and power <= 100.0 \
			and is_equal_approx(power, roundf(power))
