extends SceneTree

const TERRAIN_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const CANNON_SCENE := preload("res://scenes/gameplay/cannon.tscn")
const PROJECTILE_DATA := preload("res://resources/projectiles/basic_paintball.tres")
const PAINT_TUNING := preload("res://resources/paint/default_paint_surface_tuning.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var terrain := TERRAIN_SCENE.instantiate() as TerrainSurface
	host.add_child(terrain)
	terrain.configure(TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT))
	var cannon := CANNON_SCENE.instantiate() as CannonController
	cannon.position = Vector3(0.0, 0.0, 30.0)
	host.add_child(cannon)
	var manager := ProjectileManager.new()
	host.add_child(manager)
	manager.configure_terrain(terrain, PAINT_TUNING)
	manager.stage_bounds = PlayBoundsSpec.FIXED_BOUNDS
	var camera := Camera3D.new()
	camera.fov = 48.0
	host.add_child(camera)
	var director := CameraDirector.new()
	host.add_child(director)
	var stage := StageData.new()
	stage.terrain_center = Vector3.ZERO
	stage.terrain_size = Vector2(30.0, 30.0)
	stage.cannon_transform = cannon.global_transform
	stage.aiming_camera_position = Vector3(8.0, 6.0, 60.0)
	stage.aiming_camera_target = Vector3(0.0, 2.0, 0.0)
	director.configure(camera, stage, manager, terrain, cannon)
	director.set_mode(CameraDirector.Mode.AIMING, true)
	await physics_frame

	var first_root := manager.spawn_projectile(
		PROJECTILE_DATA,
		Vector3(0.0, 18.0, 24.0),
		Vector3.ZERO
	)
	_assert(first_root != null, "the fixture must spawn the accepted generation-0 root")
	first_root.freeze = true
	director._physics_process(1.0 / 60.0)
	_assert(
		director.current_mode == CameraDirector.Mode.FOLLOW \
				and director._follow_projectile == first_root,
		"an accepted root must enter Shot Follow with its exact identity"
	)
	_assert(
		director.camera_focus_position().distance_to(first_root.global_position) < 0.01,
		"Shot Follow must focus the selected root, not a family average"
	)

	var child := manager.spawn_projectile(
		PROJECTILE_DATA,
		Vector3(12.0, 22.0, 20.0),
		Vector3.ZERO,
		1,
		first_root.shot_id
	)
	_assert(child != null, "the fixture must create a same-family child")
	child.freeze = true
	child.position += Vector3(30.0, 0.0, 0.0)
	director._physics_process(1.0 / 60.0)
	_assert(
		director._follow_projectile == first_root,
		"Splitter children must not replace the root follow target"
	)

	var impact_point := Vector3(0.0, 0.0, 0.0)
	var contact := ProjectileContact.new(
		impact_point,
		Vector3.UP,
		impact_point + Vector3.UP * PROJECTILE_DATA.radius,
		0.0,
		Vector3.DOWN * 18.0,
		18.0,
		Vector3.ZERO,
		terrain.get_node("TerrainTopBody")
	)
	manager.projectile_contact_reported.emit(first_root, contact)
	_assert(
		director._follow_impact_hold_ticks == CameraDirector.FOLLOW_IMPACT_HOLD_TICKS,
		"first playable-surface impact must start the exact 0.4-second wall-clock hold"
	)
	for _tick in range(CameraDirector.FOLLOW_IMPACT_HOLD_TICKS - 1):
		director._update_follow_state()
	_assert(director.current_mode == CameraDirector.Mode.FOLLOW, "impact must remain visible until the final hold tick")
	director._update_follow_state()
	_assert(
		director.current_mode == CameraDirector.Mode.AIMING,
		"the 24th hold tick must restore Aim View"
	)

	var second_root := manager.spawn_projectile(
		PROJECTILE_DATA,
		Vector3(-4.0, 20.0, 24.0),
		Vector3.ZERO
	)
	_assert(second_root != null and director.current_mode == CameraDirector.Mode.FOLLOW, "a later accepted root must start a new follow")
	second_root.freeze = true
	var resident_count := manager.active_count()
	var retained_position := second_root.global_position
	_assert(director.return_to_aim_view(true), "the contextual return action must leave Shot Follow")
	_assert(
		director.current_mode == CameraDirector.Mode.AIMING \
				and manager.active_count() == resident_count \
				and is_instance_valid(second_root) \
				and second_root.global_position.is_equal_approx(retained_position),
		"returning the camera must not terminate or move projectile physics"
	)

	host.queue_free()
	await process_frame
	if not _failed:
		print("Shot Follow camera passed: exact root, child stability, 24-tick impact hold, and camera-only return.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Shot Follow camera check failed: %s" % message)
