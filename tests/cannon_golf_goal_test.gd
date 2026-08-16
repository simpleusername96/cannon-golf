extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var goal := CannonGolfSettlementGoal.new()
	goal.configure(Vector3(3.0, 2.0, -8.0), 10.0, 6.0, 24.0, 0.0)
	root.add_child(goal)
	await process_frame

	_assert_true(
		goal.find_children("*", "StaticBody3D", true, false).is_empty(),
		"A goal must use the terrain basin and must not add a physical plate or fence."
	)
	_assert_true(
		goal.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"A goal must not add hidden collision geometry."
	)
	_assert_true(
		goal.find_children("GoalFloorCue", "MeshInstance3D", true, false).is_empty(),
		"A goal must let the terrain material own the complete circular floor cue."
	)
	_assert_true(not goal.camera_collision_rid().is_valid(), "A goal must not obstruct the camera.")
	_assert_true(_air_marker_ignores_terrain_depth(goal), "The air locator must remain readable.")

	var pole := goal.get_node("GoalFlagPole") as MeshInstance3D
	var flag := goal.get_node("GoalFlag") as MeshInstance3D
	var arrow := goal.get_node("GoalAirArrow") as Node3D
	var initial_pole_transform := pole.transform
	var initial_flag_transform := flag.transform
	var initial_arrow_transform := arrow.transform
	var initial_child_count := goal.get_child_count()
	_assert_flag_color(flag, CannonGolfSettlementGoal.INCOMPLETE_FLAG_COLOR)

	goal.set_visual_state(CannonGolfSettlementGoal.VisualState.FUTURE)
	_assert_visual_geometry_unchanged(
		goal, pole, flag, arrow, initial_pole_transform, initial_flag_transform,
		initial_arrow_transform, initial_child_count
	)
	_assert_flag_color(flag, CannonGolfSettlementGoal.INCOMPLETE_FLAG_COLOR)

	goal.set_visual_state(CannonGolfSettlementGoal.VisualState.CONFIRMED)
	_assert_visual_geometry_unchanged(
		goal, pole, flag, arrow, initial_pole_transform, initial_flag_transform,
		initial_arrow_transform, initial_child_count
	)
	_assert_flag_color(flag, CannonGolfSettlementGoal.COMPLETED_FLAG_COLOR)

	_assert_true(
		goal.contains_ball(Vector3(3.0, 3.0, -8.0), CannonGolfBall.RADIUS),
		"A centered ball must be inside the goal volume."
	)
	_assert_true(
		not goal.contains_ball(Vector3(14.0, 3.0, -8.0), CannonGolfBall.RADIUS),
		"An outside ball must not be contained."
	)
	_assert_true(goal.motion_is_safe(Vector3(0.2, 0.1, 0.2), Vector3(0.0, 0.8, 0.0)), "Slow motion must be safe.")
	_assert_true(
		not goal.motion_is_safe(Vector3.RIGHT * goal.maximum_linear_speed * 1.01, Vector3.ZERO),
		"Fast translation must not settle."
	)

	goal.queue_free()
	await process_frame
	print("Cannon Golf terrain-owned goal contract passed.")
	quit(0)


func _assert_visual_geometry_unchanged(
	goal: CannonGolfSettlementGoal,
	pole: MeshInstance3D,
	flag: MeshInstance3D,
	arrow: Node3D,
	pole_transform: Transform3D,
	flag_transform: Transform3D,
	arrow_transform: Transform3D,
	child_count: int
) -> void:
	_assert_true(goal.get_child_count() == child_count, "Completion must not add or remove goal geometry.")
	_assert_true(pole.transform == pole_transform, "Completion must not move the flag pole.")
	_assert_true(flag.transform == flag_transform, "Completion must not move the flag.")
	_assert_true(arrow.transform == arrow_transform and arrow.visible, "Completion must not change the air locator.")


func _assert_flag_color(flag: MeshInstance3D, expected: Color) -> void:
	var material := flag.mesh.surface_get_material(0) as StandardMaterial3D
	_assert_true(material != null and material.albedo_color == expected, "Only the flag color may communicate completion.")


func _air_marker_ignores_terrain_depth(goal: CannonGolfSettlementGoal) -> bool:
	var marker_parts := goal.find_children("GoalAirArrow*", "MeshInstance3D", true, false)
	if marker_parts.size() != 3:
		return false
	for part in marker_parts:
		var mesh_instance := part as MeshInstance3D
		var material := mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
		if material == null or not material.no_depth_test:
			return false
	return true


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
