extends SceneTree

const CANNON_SCENE := preload("res://scenes/gameplay/cannon.tscn")
const STAGE_DATA: StageData = preload("res://resources/stages/first_descent.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_check")


func _run_check() -> void:
	root.size = Vector2i(1280, 720)
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.global_position = STAGE_DATA.aiming_camera_position
	camera.look_at(STAGE_DATA.aiming_camera_target, Vector3.UP)
	camera.make_current()
	var cannon := CANNON_SCENE.instantiate() as CannonController
	host.add_child(cannon)
	cannon.global_transform = STAGE_DATA.cannon_transform
	await process_frame

	var left := _project_aim(camera, cannon, -18.0)
	var center := _project_aim(camera, cannon, 0.0)
	var right := _project_aim(camera, cannon, 18.0)
	_assert_true(
		left.x < center.x and center.x < right.x,
		"positive yaw must move the authored aiming-camera trajectory toward screen right"
	)

	cannon.queue_free()
	camera.queue_free()
	host.queue_free()
	await process_frame
	if not _failed:
		print("Yaw screen-direction check passed: negative, neutral, and positive yaw project left-to-right.")
	quit(1 if _failed else 0)


func _project_aim(camera: Camera3D, cannon: CannonController, yaw_degrees: float) -> Vector2:
	cannon.set_aim(yaw_degrees, 38.0, 50.0)
	var visual_pivot := cannon.get_node("YawPivot/ElevationPivot") as Node3D
	var visual_direction := -visual_pivot.global_transform.basis.z.normalized()
	var ballistic_direction := CannonBallistics.launch_direction(yaw_degrees, 38.0)
	_assert_true(
		visual_direction.dot(ballistic_direction) >= 0.999,
		"the visible cannon and ballistic direction must share the player-facing yaw convention"
	)
	var endpoint := cannon.get_launch_origin_for(yaw_degrees, 38.0) \
			+ ballistic_direction * 80.0
	_assert_true(not camera.is_position_behind(endpoint), "the yaw sample must remain in front of the aiming camera")
	return camera.unproject_position(endpoint)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Yaw screen-direction check failed: %s" % message)
