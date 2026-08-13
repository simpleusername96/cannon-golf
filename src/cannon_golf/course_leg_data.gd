class_name CannonGolfCourseLegData
extends Resource

## Authored input for one ordered launcher-to-goal segment.

@export_range(0.01, 0.99, 0.01) var goal_route_t := 0.20
## Used by the first leg. Later relay launchers derive from the previous goal center.
@export_range(0.01, 1.0, 0.01) var launcher_route_t := 1.0
@export_range(3.5, 14.0, 0.1) var goal_radius := 10.0
@export_range(0.3, 8.0, 0.1) var goal_recess_depth := 4.5
@export_range(0.0, 4.0, 0.1) var goal_lip_height := 1.5
@export_range(0.0, 100.0, 1.0) var default_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var default_elevation_degrees := 50.0
@export_range(10.0, 100.0, 1.0) var default_power_percent := 50.0
@export_range(0.0, 100.0, 1.0) var solution_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var solution_elevation_degrees := 42.0
@export_range(10.0, 100.0, 1.0) var solution_power_percent := 55.0


func is_valid() -> bool:
	return goal_route_t > 0.0 and goal_route_t < 1.0 \
			and launcher_route_t > goal_route_t and launcher_route_t <= 1.0 \
			and goal_radius >= 3.5 and goal_recess_depth > 0.0 and goal_lip_height >= 0.0 \
			and _setup_is_valid(default_horizontal_aim, default_elevation_degrees, default_power_percent) \
			and _setup_is_valid(solution_horizontal_aim, solution_elevation_degrees, solution_power_percent) \
			and direct_solution() != Vector3(default_horizontal_aim, default_elevation_degrees, default_power_percent)


func default_setup() -> Vector3:
	return Vector3(default_horizontal_aim, default_elevation_degrees, default_power_percent)


func direct_solution() -> Vector3:
	return Vector3(solution_horizontal_aim, solution_elevation_degrees, solution_power_percent)


func _setup_is_valid(horizontal: float, elevation: float, power: float) -> bool:
	return is_finite(horizontal) and horizontal >= 0.0 and horizontal <= 100.0 \
			and is_equal_approx(horizontal, roundf(horizontal)) \
			and is_finite(elevation) and elevation >= 10.0 and elevation <= 68.0 \
			and is_equal_approx(elevation, roundf(elevation)) \
			and is_finite(power) and power >= 10.0 and power <= 100.0 \
			and is_equal_approx(power, roundf(power))
