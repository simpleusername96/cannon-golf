extends SceneTree

const BAKED_GAMEPLAY_FIXTURE := preload("res://tests/support/baked_gameplay_fixture.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.persistence_enabled = false
	game_state.selected_stage_id = &"stage_01"
	var gameplay := BAKED_GAMEPLAY_FIXTURE.instantiate(&"stage_01")
	root.add_child(gameplay)
	await physics_frame
	await physics_frame
	var camera := gameplay.get_node("Camera") as Camera3D
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	var terrain := gameplay.get_node("TerrainSurface") as TerrainSurface
	var cannon := gameplay.get_node("Cannon") as CannonController
	var fixed_center := terrain.visual_world_center()
	_assert_true(
		director.camera_focus_position().is_equal_approx(fixed_center),
		"Briefing must begin around the terrain visual center"
	)
	_assert_spherical_orbit(camera, director, fixed_center, "Briefing initial orbit")
	_assert_true(
		director.orbit_inspection(Vector2(36.0, -18.0)),
		"Briefing must use the shared terrain orbit"
	)
	director._apply_inspection_orbit(true)
	_assert_true(
		director.camera_focus_position().is_equal_approx(fixed_center),
		"Briefing drag must not move the terrain-center pivot"
	)
	_assert_spherical_orbit(camera, director, fixed_center, "Briefing dragged orbit")
	director.set_mode(CameraDirector.Mode.AIMING, true)
	var cannon_transform := cannon.global_transform
	_assert_true(director.set_interaction_mode(CameraDirector.InteractionMode.MAP_INSPECTION, true), "Map Inspection must be available from Aim View")
	_assert_true(
		director.camera_focus_position().is_equal_approx(fixed_center),
		"Map Inspection must reuse the Briefing terrain-center pivot"
	)
	var landmark := fixed_center + Vector3.FORWARD * 24.0
	var before := camera.unproject_position(landmark)
	var pitch_before := director._inspection_pitch_radians
	_assert_true(director.orbit_inspection(Vector2(-80.0, 0.0)), "right-to-left Map drag must orbit")
	director._apply_inspection_orbit(true)
	var after := camera.unproject_position(landmark)
	_assert_true(after.x > before.x, "right-to-left Map drag must move a landmark right with the direct-grab convention")
	_assert_true(is_equal_approx(director._inspection_pitch_radians, pitch_before), "horizontal Map drag must not change pitch")
	# Move away from the lower pitch clamp before checking the corrected upward
	# direct-grab gesture retained from the prior responsiveness pass.
	_assert_true(director.orbit_inspection(Vector2(0.0, 80.0)), "Map orbit must allow a pitch setup")
	director._apply_inspection_orbit(true)
	var vertical_landmark := fixed_center + Vector3.UP * 12.0
	var vertical_before := camera.unproject_position(vertical_landmark)
	var vertical_pitch_before := director._inspection_pitch_radians
	_assert_true(director.orbit_inspection(Vector2(0.0, -60.0)), "bottom-to-top Map drag must orbit")
	director._apply_inspection_orbit(true)
	var vertical_after := camera.unproject_position(vertical_landmark)
	_assert_true(
		vertical_after.y < vertical_before.y,
		"bottom-to-top Map drag must move an elevated landmark up with the direct-grab convention"
	)
	_assert_true(
		director._inspection_pitch_radians < vertical_pitch_before,
		"bottom-to-top Map drag must lower the camera pitch instead of applying the reversed sign"
	)
	var focus_before_click := director.camera_focus_position()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(160.0, 140.0)
	click.pressed = true
	director._unhandled_input(click)
	click.pressed = false
	director._unhandled_input(click)
	_assert_true(
		director.camera_focus_position().is_equal_approx(focus_before_click),
		"Map Inspection click must not pan or refocus the camera"
	)
	var solve_count_before := director.safety_solve_count()
	var changed_ticks := 0
	var prior_transform := camera.global_transform
	for _step in range(12):
		director.orbit_inspection(Vector2(-2.0, 1.0))
		await physics_frame
		await process_frame
		if not camera.global_transform.is_equal_approx(prior_transform):
			changed_ticks += 1
		prior_transform = camera.global_transform
	_assert_true(
		director.safety_solve_count() == solve_count_before,
		"Map orbit must not wait on or churn the generic physics safety solver"
	)
	_assert_true(changed_ticks >= 10, "sustained Map drag must update the rendered camera on consecutive ticks")
	_assert_true(
		director.camera_focus_position().is_equal_approx(fixed_center),
		"sustained Map drag must retain the terrain-center pivot"
	)
	_assert_spherical_orbit(camera, director, fixed_center, "Map sustained orbit")
	_assert_true(cannon.global_transform.is_equal_approx(cannon_transform), "Map inspection must not change committed cannon aim")
	gameplay.queue_free()
	await process_frame
	game_state.persistence_enabled = true
	if not _failed:
		print("Terrain inspection passed: fixed visual center, spherical orbit, direct drag, and unchanged aim.")
	quit(1 if _failed else 0)


func _assert_spherical_orbit(
		camera: Camera3D,
		director: CameraDirector,
		center: Vector3,
		label: String
) -> void:
	var actual_offset := camera.global_position - center
	var horizontal_scale := cos(director._inspection_pitch_radians)
	var requested_direction := Vector3(
		sin(director._inspection_yaw_radians) * horizontal_scale,
		sin(director._inspection_pitch_radians),
		cos(director._inspection_yaw_radians) * horizontal_scale
	).normalized()
	_assert_true(
		actual_offset.normalized().dot(requested_direction) >= 0.9999,
		"%s must stay on the selected center-to-camera spherical ray" % label
	)
	_assert_true(
		actual_offset.length() >= director._inspection_min_distance - 0.01 \
				and actual_offset.length() <= director._inspection_max_distance + 0.01,
		"%s radius must remain inside the stage-derived shell" % label
	)
	var camera_forward := -camera.global_transform.basis.z.normalized()
	_assert_true(
		camera_forward.dot((center - camera.global_position).normalized()) >= 0.9999,
		"%s camera must look at the fixed center" % label
	)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true
