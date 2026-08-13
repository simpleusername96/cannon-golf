class_name CannonGolfSettlementGoal
extends Node3D

const RIM_SEGMENTS := 16
const BASE_SETTLE_SECONDS := 1.15
const BASE_MAXIMUM_LINEAR_SPEED := 0.72
const BASE_MAXIMUM_ANGULAR_SPEED := 2.2
const BASE_CAPTURE_ENTRY_LINEAR_SPEED := 2.0
const BASE_CAPTURE_ENTRY_ANGULAR_SPEED := 8.0

enum VisualState {
	FUTURE,
	ACTIVE,
	CONFIRMED,
}

var inner_radius := 5.5
var rim_height := 0.8
var settle_seconds := BASE_SETTLE_SECONDS / CannonGolfBallistics.MOTION_TIME_SCALE
var maximum_linear_speed := BASE_MAXIMUM_LINEAR_SPEED * CannonGolfBallistics.MOTION_TIME_SCALE
var maximum_angular_speed := BASE_MAXIMUM_ANGULAR_SPEED * CannonGolfBallistics.MOTION_TIME_SCALE
var capture_entry_linear_speed := BASE_CAPTURE_ENTRY_LINEAR_SPEED \
		* CannonGolfBallistics.MOTION_TIME_SCALE
var capture_entry_angular_speed := BASE_CAPTURE_ENTRY_ANGULAR_SPEED \
		* CannonGolfBallistics.MOTION_TIME_SCALE
var visual_state := VisualState.ACTIVE

var _rim_markers: Array[MeshInstance3D] = []
var _flag_pole: MeshInstance3D
var _flag: MeshInstance3D


func configure(world_position: Vector3, radius: float, world_rim_y: float = INF) -> void:
	position = world_position
	inner_radius = radius
	rim_height = maxf(0.0, world_rim_y - world_position.y) if is_finite(world_rim_y) else 0.8


func _ready() -> void:
	_build_rim()
	_build_flag()
	_apply_visual_state()


func set_visual_state(next_state: VisualState) -> void:
	visual_state = next_state
	_apply_visual_state()


func contains_ball(ball_position: Vector3, ball_radius: float) -> bool:
	var origin := global_position if is_inside_tree() else position
	var local := ball_position - origin
	return _local_horizontal_contains(local, ball_radius) \
			and local.y >= -ball_radius * 0.8 \
			and local.y <= rim_height + ball_radius * 1.5


func contains_rebound_column(ball_position: Vector3, ball_radius: float) -> bool:
	var origin := global_position if is_inside_tree() else position
	var local := ball_position - origin
	return _local_horizontal_contains(local, ball_radius) and local.y >= -ball_radius * 0.8


func motion_is_safe(linear_velocity: Vector3, angular_velocity: Vector3) -> bool:
	return linear_velocity.length() <= maximum_linear_speed \
			and angular_velocity.length() <= maximum_angular_speed


func motion_allows_settlement_drag(
		linear_velocity: Vector3,
		angular_velocity: Vector3
) -> bool:
	return linear_velocity.length() <= capture_entry_linear_speed \
			and angular_velocity.length() <= capture_entry_angular_speed


func _local_horizontal_contains(local_position: Vector3, ball_radius: float) -> bool:
	return Vector2(local_position.x, local_position.z).length() \
			<= inner_radius - ball_radius * 0.35


func _build_rim() -> void:
	var rim_material := _material(Color("F6F2E7"), 0.04, 0.72)
	var segment_length := TAU * (inner_radius + 0.25) / float(RIM_SEGMENTS) * 1.08
	for index in range(RIM_SEGMENTS):
		var angle := TAU * float(index) / float(RIM_SEGMENTS)
		var marker := MeshInstance3D.new()
		marker.name = "GoalRimMarker%02d" % (index + 1)
		marker.position = Vector3(
			sin(angle) * (inner_radius + 0.28),
			rim_height + 0.055,
			cos(angle) * (inner_radius + 0.28)
		)
		marker.rotation.y = angle + PI * 0.5
		var mesh_data := BoxMesh.new()
		mesh_data.size = Vector3(0.22, 0.10, segment_length)
		mesh_data.material = rim_material
		marker.mesh = mesh_data
		add_child(marker)
		_rim_markers.append(marker)


func _build_flag() -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 10.0
	pole_mesh.radial_segments = 10
	pole_mesh.material = _material(Color("13243A"), 0.22, 0.44)
	pole.mesh = pole_mesh
	pole.position = Vector3(inner_radius * 0.72, rim_height + 5.0, 0.0)
	add_child(pole)
	_flag_pole = pole
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(4.0, 1.7, 0.10)
	flag_mesh.material = _material(Color("2584FF"), 0.08, 0.42)
	flag.mesh = flag_mesh
	flag.position = Vector3(inner_radius * 0.72 - 1.9, rim_height + 9.0, 0.0)
	add_child(flag)
	_flag = flag


func _apply_visual_state() -> void:
	if _flag_pole == null or _flag == null:
		return
	var pole_height := 10.0
	var flag_height := 9.0
	var flag_scale := Vector3.ONE
	match visual_state:
		VisualState.FUTURE:
			pole_height = 4.8
			flag_height = 4.2
			flag_scale = Vector3(0.62, 0.62, 1.0)
		VisualState.CONFIRMED:
			pole_height = 2.6
			flag_height = 2.1
			flag_scale = Vector3(0.42, 0.42, 1.0)
	_flag_pole.scale = Vector3(1.0, pole_height / 10.0, 1.0)
	_flag_pole.position.y = rim_height + pole_height * 0.5
	_flag.scale = flag_scale
	_flag.position = Vector3(
		inner_radius * 0.72 - 1.9 * flag_scale.x,
		rim_height + flag_height,
		0.0
	)
	for index in range(_rim_markers.size()):
		var marker := _rim_markers[index]
		if visual_state == VisualState.FUTURE:
			marker.visible = index % 2 == 0
		elif visual_state == VisualState.CONFIRMED:
			marker.visible = index % 4 == 0
		else:
			marker.visible = true


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
