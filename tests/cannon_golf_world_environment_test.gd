extends SceneTree

const GAME_SCENE := preload("res://scenes/cannon_golf/cannon_golf.tscn")
const PREVIEW_SCENE := preload("res://scenes/cannon_golf/app/cannon_golf_preview_world.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var preview := PREVIEW_SCENE.instantiate() as CannonGolfPreviewWorld
	root.add_child(preview)
	await process_frame
	_assert_open_world(preview, preview.get_node("OpenGround") as MeshInstance3D, "Preview")
	preview.queue_free()
	await process_frame

	var game := GAME_SCENE.instantiate() as CannonGolfGame
	root.add_child(game)
	await process_frame
	_assert_open_world(game, game.get_node("OpenGround") as MeshInstance3D, "Gameplay")
	_assert_terrain_meets_open_ground(game)
	game.queue_free()
	await process_frame
	print("Cannon Golf open-ground and sky contract passed.")
	quit(0)


func _assert_open_world(owner: Node, ground: MeshInstance3D, label: String) -> void:
	_assert_true(ground != null and ground.mesh is PlaneMesh, "%s must use open planar ground." % label)
	var plane := ground.mesh as PlaneMesh
	_assert_true(
		plane.size.x >= CannonGolfCourseWorldEnvelope.OPEN_GROUND_SPAN \
				and plane.size.y >= CannonGolfCourseWorldEnvelope.OPEN_GROUND_SPAN,
		"%s ground must extend beyond the camera instead of reading as a small plate." % label
	)
	var material := plane.material as ShaderMaterial
	var base_color := material.get_shader_parameter(&"base_color") as Color
	_assert_true(
		maxf(base_color.r, maxf(base_color.g, base_color.b)) < 0.5,
		"%s ground must not retain a white or near-white base." % label
	)
	var world_environment := owner.get_node("WorldEnvironment") as WorldEnvironment
	_assert_true(
		world_environment.environment.background_mode == Environment.BG_SKY \
				and world_environment.environment.sky != null,
		"%s must retain the Paint Mountain panoramic sky treatment." % label
	)


func _assert_terrain_meets_open_ground(game: CannonGolfGame) -> void:
	var ground := game.get_node("OpenGround") as MeshInstance3D
	var expected_ground_y := (
		game.active_course().content_bounds.position.y
		- CannonGolfCourseWorldEnvelope.GROUND_JOIN_DEPTH
	)
	_assert_true(
		is_equal_approx(ground.position.y, expected_ground_y),
		"Open ground must meet the terrain surface instead of exposing a raised terrain plate."
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
