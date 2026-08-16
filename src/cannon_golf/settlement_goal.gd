class_name CannonGolfSettlementGoal
extends Node3D

const BASE_SETTLE_SECONDS := 1.0
const BASE_MAXIMUM_LINEAR_SPEED := 0.72
const BASE_MAXIMUM_ANGULAR_SPEED := 2.2
const BASE_CAPTURE_ENTRY_LINEAR_SPEED := 2.0
const BASE_CAPTURE_ENTRY_ANGULAR_SPEED := 8.0
const ACTIVE_FLAG_HEIGHT := 16.0
const INCOMPLETE_FLAG_COLOR := Color("2584FF")
const COMPLETED_FLAG_COLOR := Color("F2A33A")
const ARROW_SHAFT_HEIGHT := 7.0
const ARROW_TIP_HEIGHT := 4.0
const ARROW_COLLAR_HEIGHT := 0.6
const ARROW_TOTAL_HEIGHT := ARROW_TIP_HEIGHT + ARROW_SHAFT_HEIGHT

enum VisualState {
	FUTURE,
	ACTIVE,
	CONFIRMED,
}

var inner_radius := 5.5
var rim_height := 0.8
var settle_seconds := BASE_SETTLE_SECONDS
var maximum_linear_speed := BASE_MAXIMUM_LINEAR_SPEED * CannonGolfBallistics.MOTION_TIME_SCALE
var maximum_angular_speed := BASE_MAXIMUM_ANGULAR_SPEED * CannonGolfBallistics.MOTION_TIME_SCALE
var capture_entry_linear_speed := BASE_CAPTURE_ENTRY_LINEAR_SPEED \
		* CannonGolfBallistics.MOTION_TIME_SCALE
var capture_entry_angular_speed := BASE_CAPTURE_ENTRY_ANGULAR_SPEED \
		* CannonGolfBallistics.MOTION_TIME_SCALE
var visual_state := VisualState.ACTIVE

var _flag_pole: MeshInstance3D
var _flag: MeshInstance3D
var _flag_material: StandardMaterial3D
var _air_arrow: Node3D
var _marker_top_height := 18.0
var _incoming_yaw_degrees := 0.0


func configure(
		world_position: Vector3,
		radius: float,
		world_wall_top_y: float = INF,
		world_marker_top_y: float = INF,
		incoming_yaw_degrees: float = 0.0
) -> void:
	position = world_position
	inner_radius = radius
	var authored_rim_height := world_wall_top_y - world_position.y \
			if is_finite(world_wall_top_y) else 0.8
	rim_height = maxf(maxf(0.4, authored_rim_height), CannonGolfBall.RADIUS * 0.8)
	_incoming_yaw_degrees = incoming_yaw_degrees
	_marker_top_height = maxf(
		rim_height + 18.0,
		world_marker_top_y - world_position.y
	) if is_finite(world_marker_top_y) else rim_height + 18.0


func _ready() -> void:
	_build_flag()
	_build_air_marker()
	_apply_visual_state()


func set_visual_state(next_state: VisualState) -> void:
	visual_state = next_state
	_apply_visual_state()


func contains_ball(ball_position: Vector3, ball_radius: float) -> bool:
	var origin := global_position if is_inside_tree() else position
	var local := ball_position - origin
	return _local_horizontal_contains(local, ball_radius) \
			and local.y >= -ball_radius * 0.15 \
			and local.y <= rim_height + ball_radius * 1.5


func contains_rebound_column(ball_position: Vector3, ball_radius: float) -> bool:
	var origin := global_position if is_inside_tree() else position
	var local := ball_position - origin
	return _local_horizontal_contains(local, ball_radius) and local.y >= -ball_radius * 0.15


func motion_is_safe(linear_velocity: Vector3, angular_velocity: Vector3) -> bool:
	return linear_velocity.length() <= maximum_linear_speed \
			and angular_velocity.length() <= maximum_angular_speed


func motion_allows_settlement_drag(
		linear_velocity: Vector3,
		angular_velocity: Vector3
) -> bool:
	return linear_velocity.length() <= capture_entry_linear_speed \
			and angular_velocity.length() <= capture_entry_angular_speed


func marker_top_world_y() -> float:
	var origin_y := global_position.y if is_inside_tree() else position.y
	return origin_y + _marker_top_height + ARROW_TOTAL_HEIGHT


func camera_collision_rid() -> RID:
	return RID()


func entry_opening_width() -> float:
	return inner_radius * 2.0


func _local_horizontal_contains(local_position: Vector3, ball_radius: float) -> bool:
	return Vector2(local_position.x, local_position.z).length() \
			<= inner_radius - ball_radius * 0.35


func _build_flag() -> void:
	var pole := MeshInstance3D.new()
	pole.name = "GoalFlagPole"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = ACTIVE_FLAG_HEIGHT
	pole_mesh.radial_segments = 10
	pole_mesh.material = _material(Color("13243A"), 0.22, 0.44)
	pole.mesh = pole_mesh
	pole.position = Vector3(inner_radius * 0.62, ACTIVE_FLAG_HEIGHT * 0.5, 0.0)
	add_child(pole)
	_flag_pole = pole
	var flag := MeshInstance3D.new()
	flag.name = "GoalFlag"
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(4.0, 1.7, 0.10)
	_flag_material = _material(INCOMPLETE_FLAG_COLOR, 0.08, 0.42)
	flag_mesh.material = _flag_material
	flag.mesh = flag_mesh
	flag.position = Vector3(inner_radius * 0.62 - 1.9, ACTIVE_FLAG_HEIGHT - 1.0, 0.0)
	add_child(flag)
	_flag = flag


func _build_air_marker() -> void:
	var amber := _air_marker_material(Color("F2A33A"), 0.0, 0.82)
	var dark := _air_marker_material(Color("13243A"), 0.08, 0.72)
	var arrow := Node3D.new()
	arrow.name = "GoalAirArrow"
	arrow.position.y = _marker_top_height
	add_child(arrow)
	_air_arrow = arrow

	var tip := MeshInstance3D.new()
	tip.name = "GoalAirArrowTip"
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 2.4
	tip_mesh.bottom_radius = 0.0
	tip_mesh.height = ARROW_TIP_HEIGHT
	tip_mesh.radial_segments = 16
	tip_mesh.material = amber
	tip.mesh = tip_mesh
	tip.position.y = ARROW_TIP_HEIGHT * 0.5
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(tip)

	var collar := MeshInstance3D.new()
	collar.name = "GoalAirArrowCollar"
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.9
	collar_mesh.bottom_radius = 0.9
	collar_mesh.height = ARROW_COLLAR_HEIGHT
	collar_mesh.radial_segments = 16
	collar_mesh.material = dark
	collar.mesh = collar_mesh
	collar.position.y = ARROW_TIP_HEIGHT + ARROW_COLLAR_HEIGHT * 0.5
	collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(collar)

	var shaft := MeshInstance3D.new()
	shaft.name = "GoalAirArrowShaft"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.55
	shaft_mesh.bottom_radius = 0.55
	shaft_mesh.height = ARROW_SHAFT_HEIGHT
	shaft_mesh.radial_segments = 12
	shaft_mesh.material = amber
	shaft.mesh = shaft_mesh
	shaft.position.y = ARROW_TIP_HEIGHT + ARROW_SHAFT_HEIGHT * 0.5
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(shaft)


func _apply_visual_state() -> void:
	if _flag_pole == null or _flag == null or _flag_material == null or _air_arrow == null:
		return
	_flag_material.albedo_color = COMPLETED_FLAG_COLOR \
			if visual_state == VisualState.CONFIRMED else INCOMPLETE_FLAG_COLOR


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


## The arrow is a distant locator for a terrain basin. Completion does not
## mutate it; only the local flag material carries the world-state change.
func _air_marker_material(
	color: Color, metallic: float, roughness: float
) -> StandardMaterial3D:
	var material := _material(color, metallic, roughness)
	material.no_depth_test = true
	return material
