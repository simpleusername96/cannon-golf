class_name CannonGolfPreviewWorld
extends Node3D

var course_index := 0

var _builder: CannonGolfCourseBuilder
var _camera: Camera3D
var _camera_rig: CannonGolfCourseCameraRig
var _environment: WorldEnvironment
var _ground: MeshInstance3D


func _ready() -> void:
	_build_environment()
	_builder = CannonGolfCourseBuilder.new()
	_builder.name = "PreviewCourseBuilder"
	add_child(_builder)
	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.fov = 46.0
	_camera.near = 0.1
	_camera.far = 520.0
	add_child(_camera)
	_camera_rig = CannonGolfCourseCameraRig.new()
	_camera_rig.name = "PreviewCameraRig"
	add_child(_camera_rig)
	show_course(0)


func _process(delta: float) -> void:
	if visible and _camera_rig != null:
		_camera_rig.update(delta)


func show_course(index: int) -> bool:
	var course := CannonGolfCourseCatalog.course_at(index)
	if course == null:
		return false
	course_index = index
	_builder.build(course)
	_camera_rig.configure(_camera, _builder.course)
	_camera.current = visible
	return true


func set_preview_visible(should_show: bool) -> void:
	visible = should_show
	if not should_show:
		_camera.current = false
		if _builder != null:
			_builder.clear_course()
		return
	show_course(course_index)


func _build_environment() -> void:
	_environment = WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/environment/kenney/skybox-day.png") as Texture2D
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.91, 0.93, 0.95, 1.0)
	environment.ambient_light_energy = 0.34
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.environment = environment
	add_child(_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "PreviewSun"
	sun.rotation_degrees = Vector3(-48.0, -58.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88, 1.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 520.0
	add_child(sun)
	_ground = MeshInstance3D.new()
	_ground.name = "GroundApron"
	_ground.position = Vector3(0.0, -5.0, -13.0)
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 160.0
	ground_mesh.bottom_radius = 166.0
	ground_mesh.height = 2.0
	ground_mesh.radial_segments = 32
	var material := ShaderMaterial.new()
	material.shader = load("res://src/terrain/open_ground.gdshader") as Shader
	material.set_shader_parameter(
		&"ground_albedo",
		load("res://assets/environment/ambientcg/Ground003_1K-JPG_Color.jpg") as Texture2D
	)
	material.set_shader_parameter(&"base_color", Color(0.48, 0.51, 0.42, 1.0))
	material.set_shader_parameter(&"world_scale", 0.032)
	material.set_shader_parameter(&"detail_strength", 0.18)
	material.set_shader_parameter(&"source_saturation", 0.15)
	ground_mesh.material = material
	_ground.mesh = ground_mesh
	add_child(_ground)
