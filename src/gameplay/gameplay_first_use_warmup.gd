class_name GameplayFirstUseWarmup
extends Node

signal completed

static var _completed_signatures: Dictionary = {}

var _running := false
var _completed := false
var _warmed_effect_family_count := 0


func is_complete() -> bool:
	return _completed


func warmed_effect_family_count() -> int:
	return _warmed_effect_family_count


## Exercises only render resources. No physics body, projectile-manager call,
## effect signal, paint mutation, shot, or StageController action is created.
func run(
		terrain_mesh: ArrayMesh,
		terrain_material: ShaderMaterial,
		projectile_data: ProjectileData,
		effect_sources: Array[GPUParticles3D]
) -> void:
	if _completed:
		completed.emit()
		return
	var signature := _warmup_signature(terrain_material, projectile_data, effect_sources)
	if _completed_signatures.has(signature):
		_warmed_effect_family_count = int(_completed_signatures[signature])
		_completed = true
		completed.emit()
		return
	if _running:
		await completed
		return
	if not is_inside_tree():
		return
	if terrain_mesh == null or terrain_material == null or projectile_data == null:
		return
	_running = true
	var scene_tree := get_tree()
	if scene_tree == null:
		_running = false
		return
	var viewport := _build_viewport()
	add_child(viewport)
	var world_root := viewport.get_node("WarmupWorld") as Node3D
	var terrain_instance := MeshInstance3D.new()
	terrain_instance.name = "TerrainMaterialWarmup"
	terrain_instance.mesh = terrain_mesh
	terrain_instance.material_override = terrain_material
	terrain_instance.scale = Vector3.ONE * 0.008
	terrain_instance.position = Vector3(0.0, -0.8, 0.0)
	world_root.add_child(terrain_instance)

	var projectile_instance := MeshInstance3D.new()
	projectile_instance.name = "ProjectileVisualWarmup"
	projectile_instance.mesh = PaintProjectile.visual_mesh(projectile_data)
	projectile_instance.position = Vector3(0.0, 0.0, 0.5)
	world_root.add_child(projectile_instance)

	var warmed_particles: Array[GPUParticles3D] = []
	for source in effect_sources:
		if source == null:
			continue
		var particle := _clone_particle_family(source)
		world_root.add_child(particle)
		particle.restart()
		particle.emitting = true
		warmed_particles.append(particle)
		_warmed_effect_family_count += 1
	# Submit every current material family together. Two completed render frames
	# cover initial pipeline creation and the first GPU-particle simulation step
	# without serializing each family behind a separate frame.
	for _render_pass in range(2):
		await _wait_for_render_completion(scene_tree)
		if not is_inside_tree():
			return
	for particle in warmed_particles:
		particle.emitting = false
		particle.queue_free()

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	await scene_tree.process_frame
	if not is_inside_tree():
		return
	_completed_signatures[signature] = _warmed_effect_family_count
	_running = false
	_completed = true
	completed.emit()


func _warmup_signature(
		terrain_material: ShaderMaterial,
		projectile_data: ProjectileData,
		effect_sources: Array[GPUParticles3D]
) -> String:
	var parts := PackedStringArray([
		terrain_material.shader.resource_path if terrain_material.shader != null else "",
		projectile_data.resource_path,
	])
	for source in effect_sources:
		if source == null:
			parts.append("null")
			continue
		parts.append("%s|%s|%d|%.6f" % [
			source.process_material.resource_path if source.process_material != null else "",
			source.draw_pass_1.resource_path if source.draw_pass_1 != null else "",
			source.amount,
			source.lifetime,
		])
	return "\n".join(parts)


func _wait_for_render_completion(scene_tree: SceneTree) -> void:
	# The dummy headless renderer does not publish frame_post_draw. Runtime Web
	# and Windows builds wait for the actual rendering-server completion signal.
	if DisplayServer.get_name() == "headless":
		await scene_tree.process_frame
	else:
		await RenderingServer.frame_post_draw


func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "FirstUseWarmupViewport"
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	var world_root := Node3D.new()
	world_root.name = "WarmupWorld"
	viewport.add_child(world_root)
	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(0.0, 0.0, 8.0), Vector3.ZERO, Vector3.UP)
	camera.current = true
	world_root.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	light.light_energy = 1.0
	world_root.add_child(light)
	return viewport


func _clone_particle_family(source: GPUParticles3D) -> GPUParticles3D:
	var particle := GPUParticles3D.new()
	particle.name = "%sWarmup" % source.name
	particle.one_shot = true
	particle.amount = maxi(source.amount, 1)
	particle.lifetime = source.lifetime
	particle.explosiveness = source.explosiveness
	particle.randomness = source.randomness
	particle.visibility_aabb = source.visibility_aabb
	particle.process_material = source.process_material
	particle.draw_pass_1 = source.draw_pass_1
	return particle
