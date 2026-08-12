class_name CannonGolfCourseData
extends Resource

@export_category("Identity")
@export var course_id: StringName
@export var display_name: String
@export_multiline var short_brief: String

@export_category("Terrain Blocks")
@export var block_centers: PackedVector3Array
@export var block_sizes: PackedVector3Array
@export var block_yaw_degrees: PackedFloat32Array
@export var terrain_color := Color("9DA6A3")
@export var terrain_accent_color := Color("87938F")

@export_category("Play")
@export var cannon_position := Vector3.ZERO
@export_range(-80.0, 80.0, 0.1) var shot_yaw_degrees := 0.0
@export var goal_position := Vector3(0.0, 0.0, -40.0)
@export_range(3.5, 8.0, 0.1) var goal_radius := 5.5
@export var play_bounds := AABB(Vector3(-50.0, -15.0, -90.0), Vector3(100.0, 70.0, 130.0))

@export_category("Planning Cameras")
@export var planning_focus := Vector3(0.0, 2.0, -15.0)
@export var oblique_offset := Vector3(42.0, 37.0, 50.0)
@export var side_offset := Vector3(48.0, 13.0, 1.0)

@export_category("Launch Setup")
@export_range(10.0, 68.0, 1.0) var default_elevation_degrees := 42.0
@export_range(10.0, 100.0, 1.0) var default_power_percent := 55.0
@export_range(10.0, 68.0, 1.0) var solution_elevation_degrees := 42.0
@export_range(10.0, 100.0, 1.0) var solution_power_percent := 55.0


func is_valid() -> bool:
	if course_id.is_empty() or display_name.strip_edges().is_empty():
		return false
	if block_centers.size() < 2 or block_centers.size() != block_sizes.size() \
			or block_centers.size() != block_yaw_degrees.size():
		return false
	for index in range(block_sizes.size()):
		var size := block_sizes[index]
		if not block_centers[index].is_finite() or not size.is_finite() \
				or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0 \
				or not is_finite(block_yaw_degrees[index]):
			return false
	return cannon_position.is_finite() and goal_position.is_finite() \
			and planning_focus.is_finite() and oblique_offset.is_finite() \
			and side_offset.is_finite() and goal_radius >= 3.5 \
			and play_bounds.has_volume() \
			and _launch_setup_is_valid(default_elevation_degrees, default_power_percent) \
			and _launch_setup_is_valid(solution_elevation_degrees, solution_power_percent)


func direct_solution() -> Vector2:
	return Vector2(solution_elevation_degrees, solution_power_percent)


func _launch_setup_is_valid(elevation: float, power: float) -> bool:
	return is_finite(elevation) and elevation >= 10.0 and elevation <= 68.0 \
			and is_equal_approx(elevation, roundf(elevation)) \
			and is_finite(power) and power >= 10.0 and power <= 100.0 \
			and is_equal_approx(power, roundf(power))
