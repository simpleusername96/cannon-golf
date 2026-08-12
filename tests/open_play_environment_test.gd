extends SceneTree

const ENVIRONMENT_SCENE := preload("res://scenes/gameplay/open_play_environment.tscn")
const GAMEPLAY_SCENE := preload("res://scenes/gameplay/gameplay.tscn")
const GROUND_SHADER_PATH := "res://src/terrain/open_ground.gdshader"
const GROUND_TEXTURE_PATH := "res://assets/environment/ambientcg/Ground003_1K-JPG_Color.jpg"
const SKY_TEXTURE_PATH := "res://assets/environment/kenney/skybox-day.png"

var _failed := false


func _initialize() -> void:
	var environment := ENVIRONMENT_SCENE.instantiate() as OpenPlayEnvironment
	root.add_child(environment)
	environment.configure(PlayBoundsSpec.new(), Rect2(Vector2(-105, -190), Vector2(210, 120)), -2.0)
	_assert(environment.is_configured(), "open environment must configure its apron")
	_assert(environment.get_node_or_null("BackstopWallMesh") == null \
			and environment.get_node_or_null("SideWallLeft") == null \
			and environment.get_node_or_null("SideWallRight") == null, "open environment must contain no rear or side wall")
	var bodies := environment.find_children("*", "StaticBody3D", true, false)
	_assert(bodies.size() == 1 and bodies[0].name == "ApronBody", "the apron must be the only environment collider")
	var apron_body := environment.get_node("ApronBody") as StaticBody3D
	var apron_shape := environment.get_node("ApronBody/ApronShape") as CollisionShape3D
	_assert(apron_body.get_meta(PlayBoundsSpec.CONTACT_OWNER_META, &"") == PlayBoundsSpec.APRON_OWNER_ID, "apron owner identity must be stable")
	_assert(apron_shape.get_meta(PlayBoundsSpec.CONTACT_SHAPE_META, &"") == PlayBoundsSpec.APRON_SHAPE_ID, "apron shape identity must be stable")
	var apron_geometry := environment.apron_geometry_read_only()
	_assert(apron_geometry.terrain_join_gap <= 0.001, "apron and terrain join must align")
	_assert(apron_geometry.top_xz_bounds == PlayBoundsSpec.FIXED_APRON_XZ_BOUNDS, "the collision apron bounds must remain fixed")
	var apron_mesh := environment.get_node("ApronMesh") as MeshInstance3D
	var visual_bounds := apron_mesh.mesh.get_aabb()
	var minimum_visual_size := PlayBoundsSpec.FIXED_APRON_XZ_BOUNDS.size \
			+ Vector2.ONE * ApronGeometryFactory.VISUAL_GROUND_MARGIN * 2.0
	_assert(visual_bounds.size.x >= minimum_visual_size.x and visual_bounds.size.z >= minimum_visual_size.y, "the render-only ground must extend beyond the finite apron collider on both axes")
	var ground_material := apron_mesh.material_override as ShaderMaterial
	_assert(ground_material != null, "the apron must use the lit ground shader material")
	if ground_material != null:
		_assert(ground_material.shader != null and ground_material.shader.resource_path == GROUND_SHADER_PATH, "the apron must use the approved ground shader")
		var ground_texture := ground_material.get_shader_parameter("ground_albedo") as Texture2D
		_assert(ground_texture != null and ground_texture.resource_path == GROUND_TEXTURE_PATH, "the apron must use the approved local ground texture")
	environment.queue_free()

	var gameplay := GAMEPLAY_SCENE.instantiate()
	var world_environment := gameplay.get_node("WorldEnvironment") as WorldEnvironment
	var sky_material := world_environment.environment.sky.sky_material as PanoramaSkyMaterial
	_assert(sky_material != null, "gameplay must use a panorama sky material")
	if sky_material != null:
		_assert(sky_material.panorama != null and sky_material.panorama.resource_path == SKY_TEXTURE_PATH, "gameplay must use the approved local sky panorama")
	gameplay.free()
	if not _failed:
		print("open_play_environment_test passed: extended visual ground, approved sky, one apron collider, no walls")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
