class_name CannonGolfLauncher
extends Node3D

const AIM_HALO_SCRIPT := preload("res://src/cannon_golf/cannon_golf_aim_halo.gd")
const VISUAL_SCALE := 2.0
const FIRST_PERSON_EYE_RISE := 0.65
const FIRST_PERSON_EYE_BACK_OFFSET := 0.35

var shot_axis_yaw_degrees := 0.0
var horizontal_aim := 50.0
var yaw_degrees := 0.0
var elevation_degrees := 50.0
var power_percent := 50.0

var _yaw_pivot: Node3D
var _elevation_pivot: Node3D
var _muzzle: Marker3D
var _visual_root: Node3D
var _aim_halo: Node3D


func _ready() -> void:
	_build_visuals()
	_apply_visuals()


func configure(course: CannonGolfCourseData) -> void:
	assert(course != null and course.is_valid(), "Launcher requires valid course data.")
	position = course.cannon_position
	shot_axis_yaw_degrees = course.shot_axis_yaw_degrees
	horizontal_aim = course.default_horizontal_aim
	elevation_degrees = course.default_elevation_degrees
	power_percent = course.default_power_percent
	yaw_degrees = CannonGolfBallistics.world_yaw_degrees(shot_axis_yaw_degrees, horizontal_aim)
	_apply_visuals()


func configure_leg(
		authored_leg: CannonGolfCourseLegData,
		generated_leg: CannonGolfGeneratedCourseLeg
) -> void:
	assert(authored_leg != null and authored_leg.is_valid(), "Launcher requires valid leg data.")
	assert(generated_leg != null and generated_leg.is_valid(), "Launcher requires generated leg data.")
	position = generated_leg.launcher_position
	shot_axis_yaw_degrees = generated_leg.shot_axis_yaw_degrees
	horizontal_aim = authored_leg.default_horizontal_aim
	elevation_degrees = authored_leg.default_elevation_degrees
	power_percent = authored_leg.default_power_percent
	yaw_degrees = CannonGolfBallistics.world_yaw_degrees(shot_axis_yaw_degrees, horizontal_aim)
	_apply_visuals()


func configure_prepared_leg(
		authored_leg: CannonGolfCourseLegData,
		prepared_leg: CannonGolfPreparedCourseLeg
) -> void:
	assert(authored_leg != null and authored_leg.is_valid(), "Launcher requires valid leg data.")
	assert(prepared_leg != null and prepared_leg.is_valid(), "Launcher requires prepared leg data.")
	position = prepared_leg.launcher_position
	shot_axis_yaw_degrees = prepared_leg.shot_axis_yaw_degrees
	horizontal_aim = authored_leg.default_horizontal_aim
	elevation_degrees = authored_leg.default_elevation_degrees
	power_percent = authored_leg.default_power_percent
	yaw_degrees = CannonGolfBallistics.world_yaw_degrees(shot_axis_yaw_degrees, horizontal_aim)
	_apply_visuals()


func set_setup(horizontal: float, elevation: float, power: float) -> void:
	horizontal_aim = CannonGolfBallistics.canonical_horizontal_aim(horizontal)
	elevation_degrees = CannonGolfBallistics.canonical_elevation(elevation)
	power_percent = CannonGolfBallistics.canonical_power(power)
	yaw_degrees = CannonGolfBallistics.world_yaw_degrees(shot_axis_yaw_degrees, horizontal_aim)
	_apply_visuals()


func launch_direction() -> Vector3:
	return CannonGolfBallistics.launch_direction(
		shot_axis_yaw_degrees, horizontal_aim, elevation_degrees
	)


func launch_speed() -> float:
	return CannonGolfBallistics.launch_speed(power_percent)


func launch_velocity() -> Vector3:
	return launch_direction() * launch_speed()


func launch_origin() -> Vector3:
	var root_position := global_position if is_inside_tree() else position
	return CannonGolfBallistics.launch_origin(
		root_position, shot_axis_yaw_degrees, horizontal_aim, elevation_degrees
	)


func first_person_eye_position() -> Vector3:
	var root_position := global_position if is_inside_tree() else position
	return root_position + _first_person_eye_offset()


func aim_halo_radius() -> float:
	return _aim_halo.presentation_radius() if _aim_halo != null else AIM_HALO_SCRIPT.RADIUS


func aim_halo_top_height() -> float:
	return _aim_halo.presentation_top_height() \
			if _aim_halo != null else AIM_HALO_SCRIPT.PRESENTATION_TOP_HEIGHT


func set_first_person_visuals_hidden(hidden: bool) -> void:
	if _visual_root != null:
		_visual_root.visible = not hidden
	if _aim_halo != null:
		_aim_halo.set_cannon_view_active(hidden, _first_person_eye_offset())


func _build_visuals() -> void:
	if _yaw_pivot != null:
		return
	var dark := _material(Color("0E1A29"), 0.46, 0.36)
	var white := _material(Color("F2EFE8"), 0.12, 0.5)
	var blue := _material(Color("2584FF"), 0.18, 0.3)
	_visual_root = Node3D.new()
	_visual_root.name = "LauncherVisualRoot"
	_visual_root.scale = Vector3.ONE * VISUAL_SCALE
	add_child(_visual_root)
	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.65
	base_mesh.bottom_radius = 1.95
	base_mesh.height = 0.6
	base_mesh.radial_segments = 16
	base_mesh.material = dark
	base.mesh = base_mesh
	base.position.y = 0.3 / VISUAL_SCALE
	base_mesh.height /= VISUAL_SCALE
	_visual_root.add_child(base)
	_yaw_pivot = Node3D.new()
	_yaw_pivot.name = "YawPivot"
	_yaw_pivot.position.y = CannonGolfBallistics.YAW_PIVOT_HEIGHT / VISUAL_SCALE
	_visual_root.add_child(_yaw_pivot)
	var pivot := MeshInstance3D.new()
	var pivot_mesh := SphereMesh.new()
	pivot_mesh.radius = 0.98
	pivot_mesh.height = 1.96
	pivot_mesh.radial_segments = 16
	pivot_mesh.rings = 8
	pivot_mesh.material = dark
	pivot.mesh = pivot_mesh
	_yaw_pivot.add_child(pivot)
	_elevation_pivot = Node3D.new()
	_elevation_pivot.name = "ElevationPivot"
	_yaw_pivot.add_child(_elevation_pivot)
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.42
	barrel_mesh.bottom_radius = 0.62
	barrel_mesh.height = CannonGolfBallistics.BARREL_LENGTH / VISUAL_SCALE
	barrel_mesh.radial_segments = 16
	barrel_mesh.material = white
	barrel.mesh = barrel_mesh
	barrel.position.z = -CannonGolfBallistics.BARREL_LENGTH * 0.5 / VISUAL_SCALE
	barrel.rotation_degrees.x = 90.0
	_elevation_pivot.add_child(barrel)
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.68
	band_mesh.bottom_radius = 0.68
	band_mesh.height = 0.22
	band_mesh.radial_segments = 16
	band_mesh.material = blue
	band.mesh = band_mesh
	band.position.z = -3.2 / VISUAL_SCALE
	band.rotation_degrees.x = 90.0
	_elevation_pivot.add_child(band)
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position.z = -CannonGolfBallistics.BARREL_LENGTH / VISUAL_SCALE
	_elevation_pivot.add_child(_muzzle)

	_aim_halo = AIM_HALO_SCRIPT.new()
	_aim_halo.name = "AimHalo"
	add_child(_aim_halo)


func _apply_visuals() -> void:
	if _yaw_pivot == null or _elevation_pivot == null:
		return
	_yaw_pivot.rotation.y = -deg_to_rad(yaw_degrees)
	_elevation_pivot.rotation.x = deg_to_rad(elevation_degrees)
	if _aim_halo != null:
		_aim_halo.set_angles(yaw_degrees, elevation_degrees, launch_direction())


func _first_person_eye_offset() -> Vector3:
	return Vector3.UP * (CannonGolfBallistics.YAW_PIVOT_HEIGHT + FIRST_PERSON_EYE_RISE) \
			- launch_direction() * FIRST_PERSON_EYE_BACK_OFFSET


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
