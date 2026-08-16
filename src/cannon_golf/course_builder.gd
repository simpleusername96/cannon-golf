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
	terrain_mesh.material_override = _terrain_material_with_goal_regions()
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_body.add_child(terrain_mesh)
	launcher = CannonGolfLauncher.new()
	launcher.name = "Launcher"
	add_child(launcher)
	_build_goals()
	if not select_launcher_source(-1):
		push_error("Prepared course could not activate its original launcher.")
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


## Places the one runtime cannon without selecting a target. Goal indices are
## stable source identities; -1 denotes the original course start.
func select_launcher_source(goal_index: int) -> bool:
	if prepared_course == null or launcher == null \
			or goal_index < -1 or goal_index >= goals.size():
		return false
	var source_position := prepared_course.legs[0].launcher_position
	if goal_index >= 0:
		source_position = goals[goal_index].position + Vector3.UP * 0.05
	launcher.position = source_position
	# A completed checkpoint owns the next generated leg's protected departure
	# corridor. Reuse that authored axis instead of aiming at the map center,
	# which can send the default shot straight into an unrelated ridge.
	launcher.shot_axis_yaw_degrees = prepared_course.legs[goal_index + 1].shot_axis_yaw_degrees \
			if goal_index >= 0 and goal_index + 1 < prepared_course.legs.size() \
			else _map_center_yaw(source_position)
	launcher.set_setup(50.0, 50.0, 50.0)
	course.cannon_position = source_position
	course.shot_axis_yaw_degrees = launcher.shot_axis_yaw_degrees
	course.planning_focus = course.content_bounds.get_center()
	goal = goals[0] if not goals.is_empty() else null
	return true


func set_goal_completed(index: int, completed: bool) -> bool:
	var settlement_goal := goal_at(index)
	if settlement_goal == null:
		return false
	settlement_goal.set_visual_state(
		CannonGolfSettlementGoal.VisualState.CONFIRMED if completed \
		else CannonGolfSettlementGoal.VisualState.ACTIVE
	)
	return true


func set_all_goals_available() -> void:
	for settlement_goal in goals:
		settlement_goal.set_visual_state(CannonGolfSettlementGoal.VisualState.ACTIVE)


func _map_center_yaw(source_position: Vector3) -> float:
	var center := course.content_bounds.get_center()
	var delta := Vector2(center.x - source_position.x, center.z - source_position.z)
	if delta.length_squared() <= 0.01:
		return prepared_course.legs[0].shot_axis_yaw_degrees
	return rad_to_deg(atan2(delta.x, -delta.y))


func leg_count() -> int:
	return prepared_course.legs.size() if prepared_course != null else 0


func goal_at(index: int) -> CannonGolfSettlementGoal:
	return goals[index] if index >= 0 and index < goals.size() else null


func frame_bounds_for_leg(index: int) -> AABB:
	if prepared_course == null or index < 0 or index >= prepared_course.legs.size():
		return AABB()
	var bounds := prepared_course.legs[index].frame_bounds
	var framed_goal := goal_at(index)
	if framed_goal != null:
		bounds = bounds.expand(Vector3(
			framed_goal.global_position.x,
			framed_goal.marker_top_world_y() + 3.0,
			framed_goal.global_position.z
		))
	return bounds


func presentation_bounds() -> AABB:
	var bounds := course.content_bounds if course != null else AABB()
	for settlement_goal in goals:
		bounds = bounds.expand(Vector3(
			settlement_goal.global_position.x,
			settlement_goal.marker_top_world_y() + 3.0,
			settlement_goal.global_position.z
		))
	if launcher != null:
		var cue := launcher.aim_halo_radius()
		bounds = bounds.expand(launcher.global_position + Vector3(
			cue, launcher.aim_halo_top_height(), cue
		))
		bounds = bounds.expand(launcher.global_position + Vector3(-cue, 0.0, -cue))
	return bounds


func camera_collision_exclusions() -> Array[RID]:
	var result: Array[RID] = []
	for settlement_goal in goals:
		var rid := settlement_goal.camera_collision_rid()
		if rid.is_valid():
			result.append(rid)
	return result


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
			prepared.goal_position,
			prepared.goal_radius,
			prepared.goal_lip_y,
			_goal_marker_top_y(prepared.goal_position, prepared.goal_lip_y),
			prepared.shot_axis_yaw_degrees
		)
		settlement_goal.visual_state = CannonGolfSettlementGoal.VisualState.ACTIVE
		add_child(settlement_goal)
		goals.append(settlement_goal)


## Marks the scoring regions in the shared terrain material. This avoids a
## raised plate or a flat overlay that can intersect the basin's triangles.
func _terrain_material_with_goal_regions() -> ShaderMaterial:
	var source := prepared_course.render_mesh.surface_get_material(0) as ShaderMaterial
	if source == null:
		return null
	var material := source.duplicate() as ShaderMaterial
	var regions := PackedVector4Array()
	for prepared in prepared_course.legs:
		regions.append(Vector4(
			prepared.goal_position.x,
			prepared.goal_position.z,
			prepared.goal_radius,
			0.0
		))
	while regions.size() < 6:
		regions.append(Vector4.ZERO)
	material.set_shader_parameter(&"goal_regions", regions)
	material.set_shader_parameter(&"goal_region_count", prepared_course.legs.size())
	return material


func _add_dressing() -> void:
	for index in range(prepared_course.dressing.size()):
		var placement := prepared_course.dressing[index]
		if _dressing_overlaps_goal_clearance(placement.position):
			continue
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


func _goal_marker_top_y(goal_position: Vector3, goal_lip_y: float) -> float:
	var local_skyline := goal_lip_y
	var sample_radius := 32.0
	var sample_step := 4.0
	var sample_count := ceili(sample_radius / sample_step)
	for z_index in range(-sample_count, sample_count + 1):
		for x_index in range(-sample_count, sample_count + 1):
			var offset := Vector2(float(x_index), float(z_index)) * sample_step
			if offset.length() > sample_radius:
				continue
			local_skyline = maxf(
				local_skyline,
				height_at_local(goal_position.x + offset.x, goal_position.z + offset.y)
			)
	return maxf(goal_lip_y + 18.0, local_skyline + 8.0)


func _dressing_overlaps_goal_clearance(position: Vector3) -> bool:
	var position_xz := Vector2(position.x, position.z)
	for settlement_goal in goals:
		var goal_xz := Vector2(settlement_goal.position.x, settlement_goal.position.z)
		if position_xz.distance_to(goal_xz) <= settlement_goal.inner_radius + 8.0:
			return true
	return false


func _apply_dressing_material(node: Node, is_tree: bool) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("40566A") if is_tree else Color("8F9696")
	material.roughness = 0.96
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).material_override = material
		_apply_dressing_material(child, is_tree)
