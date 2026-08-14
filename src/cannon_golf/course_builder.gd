class_name CannonGolfCourseBuilder
extends Node3D

## Instantiates one prepared course. Generation belongs only to the bake command.

var course: CannonGolfCourseData
var prepared_course: CannonGolfPreparedCourse
var terrain_body: StaticBody3D
var launcher: CannonGolfLauncher
var goal: CannonGolfSettlementGoal
var goals: Array[CannonGolfSettlementGoal] = []

# Retained as compatibility probes for authoring-only tests. Shipping builds use
# `prepared_course` and never hydrate or generate these heavy transient owners.
var terrain_layout: GeneratedStageLayout
var terrain_geometry: TerrainGeometry
var generated_course: CannonGolfGeneratedCourse


func build(
		selected_course: CannonGolfCourseData,
		prepared: CannonGolfPreparedCourse = null
) -> bool:
	return _build(selected_course, prepared, false)


## Offline authoring seam for optional exact-physics certification. Shipping
## gameplay accepts either a certificate or the current trajectory-construction
## contract through the normal `build()` path.
func build_certification_candidate(
		selected_course: CannonGolfCourseData,
		prepared: CannonGolfPreparedCourse
) -> bool:
	return _build(selected_course, prepared, true)


func _build(
		selected_course: CannonGolfCourseData,
		prepared: CannonGolfPreparedCourse,
		allow_certification_candidate: bool
) -> bool:
	if selected_course == null or not selected_course.is_valid():
		push_error("Course builder requires valid authored data.")
		return false
	var resolved := prepared
	if resolved == null:
		resolved = ResourceLoader.load(
			CannonGolfCourseCatalog.prepared_path_for(selected_course)
		) as CannonGolfPreparedCourse
	var artifact_valid := resolved != null and (
		resolved.is_valid_certification_candidate_for(selected_course)
		if allow_certification_candidate else resolved.is_valid_for(selected_course)
	)
	if not artifact_valid:
		push_error("Course builder requires the matching prepared course artifact.")
		return false
	clear_course()
	course = selected_course.duplicate(true) as CannonGolfCourseData
	course.is_prepared_runtime_projection = course.is_constraint_recipe()
	prepared_course = resolved
	_apply_prepared_course_data()
	terrain_body = StaticBody3D.new()
	terrain_body.name = "Terrain"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0
	terrain_body.add_to_group(&"impact_mark_surface")
	var terrain_physics := PhysicsMaterial.new()
	terrain_physics.bounce = 0.10
	terrain_physics.friction = 0.86
	terrain_body.physics_material_override = terrain_physics
	add_child(terrain_body)
	var top_collision := CollisionShape3D.new()
	top_collision.name = "TerrainTopCollision"
	top_collision.shape = prepared_course.top_shape
	terrain_body.add_child(top_collision)
	var shell_collision := CollisionShape3D.new()
	shell_collision.name = "TerrainShellCollision"
	shell_collision.shape = prepared_course.skirt_shape
	terrain_body.add_child(shell_collision)
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	terrain_mesh.mesh = prepared_course.render_mesh
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_body.add_child(terrain_mesh)
	launcher = CannonGolfLauncher.new()
	launcher.name = "Launcher"
	add_child(launcher)
	_build_goals()
	if not activate_leg(0):
		push_error("Prepared course could not activate its first leg.")
		clear_course()
		return false
	_add_dressing()
	return true


func clear_course() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	terrain_body = null
	launcher = null
	goal = null
	goals.clear()
	terrain_layout = null
	terrain_geometry = null
	generated_course = null
	prepared_course = null
	course = null


func terrain_body_count() -> int:
	var count := 0
	for child in get_children():
		if child is StaticBody3D and child.name == "Terrain":
			count += 1
	return count


func activate_leg(index: int) -> bool:
	if prepared_course == null or index < 0 or index >= prepared_course.legs.size():
		return false
	var authored := course.leg_at(index)
	var prepared := prepared_course.legs[index]
	# Constraint recipes intentionally clear their legacy witness fields, so
	# their authored legs do not satisfy the legacy `is_valid()` predicate used
	# by the launcher's compatibility adapter. Apply the small prepared runtime
	# contract directly here for both authoring modes.
	launcher.position = prepared.launcher_position
	launcher.shot_axis_yaw_degrees = prepared.shot_axis_yaw_degrees
	launcher.set_setup(
		authored.default_horizontal_aim,
		authored.default_elevation_degrees,
		authored.default_power_percent
	)
	goal = goals[index]
	course.cannon_position = prepared.launcher_position
	course.goal_position = prepared.goal_position
	course.goal_radius = prepared.goal_radius
	course.shot_axis_yaw_degrees = prepared.shot_axis_yaw_degrees
	course.planning_focus = prepared.frame_bounds.get_center()
	for goal_index in range(goals.size()):
		if goal_index < index:
			goals[goal_index].set_visual_state(CannonGolfSettlementGoal.VisualState.CONFIRMED)
		elif goal_index == index:
			goals[goal_index].set_visual_state(CannonGolfSettlementGoal.VisualState.ACTIVE)
		else:
			goals[goal_index].set_visual_state(CannonGolfSettlementGoal.VisualState.FUTURE)
	return true


func leg_count() -> int:
	return prepared_course.legs.size() if prepared_course != null else 0


func goal_at(index: int) -> CannonGolfSettlementGoal:
	return goals[index] if index >= 0 and index < goals.size() else null


func frame_bounds_for_leg(index: int) -> AABB:
	return prepared_course.legs[index].frame_bounds \
			if prepared_course != null and index >= 0 and index < prepared_course.legs.size() \
			else AABB()


func height_at_local(local_x: float, local_z: float) -> float:
	return prepared_course.height_at_local(local_x, local_z) \
			if prepared_course != null else 0.0


func _apply_prepared_course_data() -> void:
	var first := prepared_course.legs[0]
	course.cannon_position = first.launcher_position
	course.goal_position = first.goal_position
	course.goal_radius = first.goal_radius
	course.shot_axis_yaw_degrees = first.shot_axis_yaw_degrees
	course.play_bounds = prepared_course.play_bounds
	course.content_bounds = prepared_course.content_bounds
	course.planning_focus = first.frame_bounds.get_center()


func _build_goals() -> void:
	for index in range(prepared_course.legs.size()):
		var prepared := prepared_course.legs[index]
		var settlement_goal := CannonGolfSettlementGoal.new()
		settlement_goal.name = "SettlementGoal%02d" % (index + 1)
		settlement_goal.configure(
			prepared.goal_position, prepared.goal_radius, prepared.goal_lip_y
		)
		settlement_goal.visual_state = CannonGolfSettlementGoal.VisualState.ACTIVE \
				if index == 0 else CannonGolfSettlementGoal.VisualState.FUTURE
		add_child(settlement_goal)
		goals.append(settlement_goal)


func _add_dressing() -> void:
	for index in range(prepared_course.dressing.size()):
		var placement := prepared_course.dressing[index]
		var packed := load(placement.model_path) as PackedScene
		if packed == null:
			continue
		var decoration := packed.instantiate() as Node3D
		if decoration == null:
			continue
		decoration.name = "NatureDressing%02d" % (index + 1)
		decoration.position = placement.position
		decoration.rotation.y = deg_to_rad(placement.yaw_degrees)
		decoration.scale = Vector3.ONE * placement.uniform_scale
		_apply_dressing_material(decoration, placement.is_tree)
		add_child(decoration)


func _apply_dressing_material(node: Node, is_tree: bool) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("40566A") if is_tree else Color("8F9696")
	material.roughness = 0.96
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).material_override = material
		_apply_dressing_material(child, is_tree)
