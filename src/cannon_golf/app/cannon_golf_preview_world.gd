class_name CannonGolfPreviewWorld
extends Node3D

var course_index := 0

var _builder: CannonGolfCourseBuilder
var _camera: Camera3D
var _camera_rig: CannonGolfCourseCameraRig
var _environment: WorldEnvironment
var _ground: MeshInstance3D
var _sun: DirectionalLight3D


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


func _process(delta: float) -> void:
	if visible and _camera_rig != null:
		_camera_rig.update(delta)


func show_course(index: int, prepared: CannonGolfPreparedCourse = null) -> bool:
	var course := CannonGolfCourseCatalog.course_at(index)
	if course == null or prepared == null or not prepared.is_valid_for(course):
		return false
	if course_index == index and _builder.prepared_course == prepared:
		_camera.current = visible
		return true
	var replacement := CannonGolfCourseBuilder.new()
	replacement.name = "PreviewCourseBuilder"
	if not replacement.build(course, prepared):
		replacement.free()
		return false
	add_child(replacement)
	if _builder != null:
		remove_child(_builder)
		_builder.free()
	_builder = replacement
	course_index = index
	_apply_world_envelope()
	_camera_rig.configure(_camera, _builder.course)
	_camera.current = visible
	return true


func set_preview_visible(should_show: bool) -> void:
	visible = should_show
	if not should_show:
		_camera.current = false


func _build_environment() -> void:
	_environment = WorldEnvironment.new()
	_environment.name = "WorldEnvironment"
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
	_sun = sun
	_ground = MeshInstance3D.new()
	_ground.name = "OpenGround"
	_ground.position = Vector3(0.0, -5.0, -13.0)
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2.ONE * CannonGolfCourseWorldEnvelope.OPEN_GROUND_SPAN
	var material := ShaderMaterial.new()
	material.shader = load("res://src/terrain/open_ground.gdshader") as Shader
	material.set_shader_parameter(
		&"ground_albedo",
		load("res://assets/environment/ambientcg/Ground003_1K-JPG_Color.jpg") as Texture2D
	)
	material.set_shader_parameter(
		&"base_color", CannonGolfCourseWorldEnvelope.OPEN_GROUND_COLOR
	)
	material.set_shader_parameter(&"world_scale", 0.032)
	material.set_shader_parameter(&"detail_strength", 0.1)
	material.set_shader_parameter(&"source_saturation", 0.15)
	ground_mesh.material = material
	_ground.mesh = ground_mesh
	add_child(_ground)


func _apply_world_envelope() -> void:
	var envelope := CannonGolfCourseWorldEnvelope.resolve(_builder.course.content_bounds)
	var center: Vector3 = envelope.ground_center
	var scale_factor := float(envelope.ground_scale)
	_ground.position = center
	_ground.scale = Vector3(scale_factor, 1.0, scale_factor)
	_camera.far = float(envelope.far_distance)
	_sun.directional_shadow_max_distance = float(envelope.far_distance)
