class_name CannonGolfSettlementGoal
extends Node3D

const RIM_SEGMENTS := 16
const ENTRY_GAP_SEGMENTS := 3
const PLATE_THICKNESS := 0.22
const WALL_THICKNESS := 0.34
const BASE_SETTLE_SECONDS := 1.0
const BASE_MAXIMUM_LINEAR_SPEED := 0.72
const BASE_MAXIMUM_ANGULAR_SPEED := 2.2
const BASE_CAPTURE_ENTRY_LINEAR_SPEED := 2.0
const BASE_CAPTURE_ENTRY_ANGULAR_SPEED := 8.0
const ACTIVE_FLAG_HEIGHT := 16.0
const FUTURE_FLAG_HEIGHT := 14.0
const CONFIRMED_FLAG_HEIGHT := 10.0

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

var _rim_markers: Array[MeshInstance3D] = []
var _plate_body: StaticBody3D
var _plate_floor: MeshInstance3D
var _flag_pole: MeshInstance3D
var _flag: MeshInstance3D
var _air_marker_stem: MeshInstance3D
var _air_marker_faces: Array[MeshInstance3D] = []
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
	rim_height = maxf(0.4, world_wall_top_y - world_position.y) \
			if is_finite(world_wall_top_y) else 0.8
	_incoming_yaw_degrees = incoming_yaw_degrees
	_marker_top_height = maxf(
		rim_height + 18.0,
		world_marker_top_y - world_position.y
	) if is_finite(world_marker_top_y) else rim_height + 18.0


func _ready() -> void:
	_build_plate()
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
	return origin_y + _marker_top_height


func _local_horizontal_contains(local_position: Vector3, ball_radius: float) -> bool:
	return Vector2(local_position.x, local_position.z).length() \
			<= inner_radius - ball_radius * 0.35


func _build_plate() -> void:
	var floor_material := _material(Color("E8E1CE"), 0.02, 0.84)
	var wall_material := _material(Color("D4D0C4"), 0.03, 0.78)
	var body := StaticBody3D.new()
	body.name = "GoalPlateBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"impact_mark_surface")
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.08
	physics.friction = 0.94
	body.physics_material_override = physics
	add_child(body)
	_plate_body = body
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "GoalPlateFloor"
	var floor_data := CylinderMesh.new()
	floor_data.top_radius = inner_radius
	floor_data.bottom_radius = inner_radius
	floor_data.height = PLATE_THICKNESS
	floor_data.radial_segments = 32
	floor_data.material = floor_material
	floor_mesh.mesh = floor_data
	floor_mesh.position.y = -PLATE_THICKNESS * 0.5
	body.add_child(floor_mesh)
	_plate_floor = floor_mesh
	var floor_collision := CollisionShape3D.new()
	floor_collision.name = "GoalPlateFloorCollision"
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = inner_radius
	floor_shape.height = PLATE_THICKNESS
	floor_collision.shape = floor_shape
	floor_collision.position.y = -PLATE_THICKNESS * 0.5
	body.add_child(floor_collision)
	var opening_angle := -deg_to_rad(_incoming_yaw_degrees)
	var segment_angle := TAU / float(RIM_SEGMENTS)
	var opening_half_angle := segment_angle * float(ENTRY_GAP_SEGMENTS) * 0.5
	var wall_radius := inner_radius + WALL_THICKNESS * 0.5
	var segment_length := TAU * (inner_radius + 0.25) / float(RIM_SEGMENTS) * 1.08
	for index in range(RIM_SEGMENTS):
		var angle := TAU * float(index) / float(RIM_SEGMENTS)
		if absf(wrapf(angle - opening_angle, -PI, PI)) <= opening_half_angle:
			continue
		var marker := MeshInstance3D.new()
		marker.name = "GoalRimMarker%02d" % (index + 1)
		marker.position = Vector3(
			sin(angle) * wall_radius,
			rim_height * 0.5,
			cos(angle) * wall_radius
		)
		marker.rotation.y = angle + PI * 0.5
		var mesh_data := BoxMesh.new()
		mesh_data.size = Vector3(WALL_THICKNESS, rim_height, segment_length)
		mesh_data.material = wall_material
		marker.mesh = mesh_data
		body.add_child(marker)
		_rim_markers.append(marker)
		var collision := CollisionShape3D.new()
		collision.name = "GoalPlateWallCollision%02d" % (index + 1)
		var wall_shape := BoxShape3D.new()
		wall_shape.size = mesh_data.size
		collision.shape = wall_shape
		collision.position = marker.position
		collision.rotation = marker.rotation
		body.add_child(collision)


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


func _build_air_marker() -> void:
	var marker_material := _material(Color("20D9F2"), 0.0, 0.34)
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var stem := MeshInstance3D.new()
	stem.name = "GoalAirMarkerStem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.15
	stem_mesh.bottom_radius = 0.15
	stem_mesh.height = maxf(_marker_top_height - rim_height, 1.0)
	stem_mesh.radial_segments = 10
	stem_mesh.material = marker_material
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, rim_height + stem_mesh.height * 0.5, 0.0)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stem)
	_air_marker_stem = stem
	for face_index in range(2):
		var face := MeshInstance3D.new()
		face.name = "GoalAirMarkerFace%d" % (face_index + 1)
		var face_mesh := BoxMesh.new()
		face_mesh.size = Vector3(5.8, 5.8, 0.22)
		face_mesh.material = marker_material
		face.mesh = face_mesh
		face.position = Vector3(0.0, _marker_top_height, 0.0)
		face.rotation = Vector3(0.0, float(face_index) * PI * 0.5, PI * 0.25)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(face)
		_air_marker_faces.append(face)


func _apply_visual_state() -> void:
	if _flag_pole == null or _flag == null or _air_marker_stem == null:
		return
	var pole_height := ACTIVE_FLAG_HEIGHT
	var flag_height := ACTIVE_FLAG_HEIGHT - 1.0
	var flag_scale := Vector3(1.75, 1.75, 1.0)
	var air_marker_scale := 1.0
	match visual_state:
		VisualState.FUTURE:
			pole_height = FUTURE_FLAG_HEIGHT
			flag_height = FUTURE_FLAG_HEIGHT - 1.0
			flag_scale = Vector3(1.35, 1.35, 1.0)
			air_marker_scale = 0.82
		VisualState.CONFIRMED:
			pole_height = CONFIRMED_FLAG_HEIGHT
			flag_height = CONFIRMED_FLAG_HEIGHT - 1.0
			flag_scale = Vector3(1.0, 1.0, 1.0)
			air_marker_scale = 0.75
	_flag_pole.scale = Vector3(1.0, pole_height / 10.0, 1.0)
	_flag_pole.position.y = rim_height + pole_height * 0.5
	_flag.scale = flag_scale
	_flag.position = Vector3(
		inner_radius * 0.72 - 1.9 * flag_scale.x,
		rim_height + flag_height,
		0.0
	)
	_air_marker_stem.visible = visual_state != VisualState.CONFIRMED
	for face in _air_marker_faces:
		face.scale = Vector3.ONE * air_marker_scale
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
