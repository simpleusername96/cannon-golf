class_name CannonGolfCourseLegData
extends Resource

## Authored input for one stable goal identity and its construction segment.

## Legacy exact fields below remain migration inputs. Constraint recipes use only
## the bounded fields in the Constraint Recipe section.

@export_range(0.01, 0.99, 0.01) var goal_route_t := 0.20
## Route and local lateral/longitudinal placement are explicit so goals need not
## be monotonically arranged. Array order does not impose completion order.
@export_range(0, 7, 1) var route_index := 0
@export var goal_placement_offset := Vector2.ZERO
## Low / middle / high authored rim band. The factory records the generated rim.
@export_range(0, 2, 1) var rim_elevation_band := 1
@export var feature_anchor: StringName
## Used by the first leg. Later relay launchers derive from the previous goal center.
@export_range(0.01, 1.0, 0.01) var launcher_route_t := 1.0
@export_range(3.5, 14.0, 0.1) var goal_radius := 10.0
@export_range(0.3, 8.0, 0.1) var goal_recess_depth := 4.5
@export_range(0.0, 4.0, 0.1) var goal_lip_height := 1.5
@export_range(0.0, 100.0, 1.0) var default_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var default_elevation_degrees := 50.0
@export_range(10.0, 100.0, 1.0) var default_power_percent := 50.0
@export_range(0.0, 100.0, 1.0) var solution_horizontal_aim := 50.0
@export_range(10.0, 68.0, 1.0) var solution_elevation_degrees := 50.0
@export_range(10.0, 100.0, 1.0) var solution_power_percent := 50.0

@export_category("Constraint Recipe")
## Inclusive route-distance interval selected by the offline resolver.
@export var route_interval := Vector2(0.15, 0.25)
## Inclusive local lateral-offset interval in metres.
@export var lateral_offset_range := Vector2(-8.0, 8.0)
## Low / middle / high relative rim band requested by the author.
@export_range(0, 2, 1) var relative_rim_band := 1
@export var bowl_radius_range := Vector2(5.0, 10.0)
@export var bowl_recess_depth_range := Vector2(2.0, 5.0)
@export var bowl_lip_height_range := Vector2(0.0, 2.0)
@export var semantic_role: StringName


func is_valid() -> bool:
	return goal_route_t > 0.0 and goal_route_t < 1.0 \
			and launcher_route_t > goal_route_t and launcher_route_t <= 1.0 \
			and route_index >= 0 and goal_placement_offset.is_finite() \
			and rim_elevation_band >= 0 and rim_elevation_band <= 2 \
			and goal_radius >= 3.5 and goal_recess_depth > 0.0 and goal_lip_height >= 0.0 \
			and _setup_is_valid(default_horizontal_aim, default_elevation_degrees, default_power_percent) \
			and _setup_is_valid(solution_horizontal_aim, solution_elevation_degrees, solution_power_percent) \
			and direct_solution() != Vector3(default_horizontal_aim, default_elevation_degrees, default_power_percent)


func is_valid_recipe() -> bool:
	return route_index >= 0 and _finite_interval(route_interval, 0.01, 0.99) \
			and _finite_interval(lateral_offset_range) \
			and relative_rim_band >= 0 and relative_rim_band <= 2 \
			and _finite_interval(bowl_radius_range, 3.5) \
			and _finite_interval(bowl_recess_depth_range, 0.01) \
			and _finite_interval(bowl_lip_height_range, 0.0) \
			and not semantic_role.is_empty() \
			and default_setup() == Vector3(50.0, 50.0, 50.0) \
			and goal_placement_offset == Vector2.ZERO and feature_anchor.is_empty() \
			and _legacy_witness_is_clear()


func _legacy_witness_is_clear() -> bool:
	return direct_solution() == Vector3(50.0, 50.0, 50.0)


func _finite_interval(interval: Vector2, lower_bound := -INF, upper_bound := INF) -> bool:
	return interval.is_finite() and interval.x >= lower_bound and interval.y <= upper_bound \
			and interval.x <= interval.y


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
