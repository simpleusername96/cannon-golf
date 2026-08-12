class_name PresentationEffects
extends Node3D

const POOL_SIZE := 8
const PAINT_MIST := preload("res://assets/vfx/kenney/paint_mist.png")
const IMPACT_RIPPLE := preload("res://assets/vfx/kenney/impact_ripple.png")
const MUZZLE_RING := preload("res://assets/vfx/kenney/muzzle_ring.png")
const GLINT := preload("res://assets/vfx/kenney/glint.png")

var _particles: Array[GPUParticles3D] = []
var _mist_particles: Array[GPUParticles3D] = []
var _impact_particles: Array[GPUParticles3D] = []
var _muzzle_particles: Array[GPUParticles3D] = []
var _glint_particles: Array[GPUParticles3D] = []
var _next_particle: int = 0
var _next_mist: int = 0
var _next_impact: int = 0
var _next_muzzle: int = 0
var _next_glint: int = 0
var _shared_splash_process_material: ParticleProcessMaterial
var _shared_splash_mesh: SphereMesh
var _shared_textured_process_material: ParticleProcessMaterial
var _shared_textured_meshes: Dictionary = {}


func _ready() -> void:
	for index in range(POOL_SIZE):
		var particle := _build_particle(index)
		add_child(particle)
		_particles.append(particle)
		_mist_particles.append(_build_textured_particle("PaintMist%02d" % (index + 1), PAINT_MIST, Vector2(3.4, 3.4), 0.58))
		_impact_particles.append(_build_textured_particle("ImpactRipple%02d" % (index + 1), IMPACT_RIPPLE, Vector2(2.8, 2.8), 0.42))
	for index in range(4):
		_muzzle_particles.append(_build_textured_particle("MuzzleRing%02d" % (index + 1), MUZZLE_RING, Vector2(2.3, 2.3), 0.24))
		_glint_particles.append(_build_textured_particle("Glint%02d" % (index + 1), GLINT, Vector2(4.2, 4.2), 0.68))


func splash(world_position: Vector3, scale: float = 1.0) -> void:
	var particle := _particles[_next_particle]
	_next_particle = (_next_particle + 1) % _particles.size()
	particle.global_position = world_position
	particle.amount = clampi(roundi(22.0 * scale), 12, 42)
	particle.emitting = false
	particle.restart()
	particle.emitting = true
	_next_mist = _emit_textured(_mist_particles, _next_mist, world_position + Vector3.UP * 0.45, clampi(roundi(5.0 * scale), 3, 8))
	_next_impact = _emit_textured(_impact_particles, _next_impact, world_position + Vector3.UP * 0.12, 1)


func mechanism_burst(world_position: Vector3) -> void:
	splash(world_position + Vector3.UP, 1.7)
	_next_glint = _emit_textured(_glint_particles, _next_glint, world_position + Vector3.UP * 3.0, 3)


func muzzle_flash(world_position: Vector3) -> void:
	_next_muzzle = _emit_textured(_muzzle_particles, _next_muzzle, world_position, 2)


func clear_glint(world_position: Vector3) -> void:
	_next_glint = _emit_textured(_glint_particles, _next_glint, world_position, 8)


## One source per distinct GPU material family for render-only warm-up. The
## returned nodes remain owned by this pool and must never be reparented.
func warmup_sources() -> Array[GPUParticles3D]:
	var result: Array[GPUParticles3D] = []
	for pool in [
		_particles,
		_mist_particles,
		_impact_particles,
		_muzzle_particles,
		_glint_particles,
	]:
		if not pool.is_empty():
			result.append(pool[0])
	return result


func _build_particle(index: int) -> GPUParticles3D:
	var particle := GPUParticles3D.new()
	particle.name = "PaintSplash%02d" % (index + 1)
	particle.emitting = false
	particle.one_shot = true
	particle.explosiveness = 0.95
	particle.lifetime = 0.72
	particle.randomness = 0.36
	particle.visibility_aabb = AABB(Vector3(-18.0, -12.0, -18.0), Vector3(36.0, 32.0, 36.0))
	particle.process_material = _splash_process_material()
	particle.draw_pass_1 = _splash_mesh()
	return particle


func _build_textured_particle(
		particle_name: String,
		texture: Texture2D,
		size: Vector2,
		lifetime: float
) -> GPUParticles3D:
	var particle := GPUParticles3D.new()
	particle.name = particle_name
	particle.emitting = false
	particle.one_shot = true
	particle.amount = 1
	particle.explosiveness = 1.0
	particle.lifetime = lifetime
	particle.randomness = 0.3
	particle.visibility_aabb = AABB(Vector3(-12.0, -12.0, -12.0), Vector3(24.0, 24.0, 24.0))
	particle.process_material = _textured_process_material()
	particle.draw_pass_1 = _textured_mesh(texture, size)
	add_child(particle)
	return particle


func _splash_process_material() -> ParticleProcessMaterial:
	if _shared_splash_process_material != null:
		return _shared_splash_process_material
	_shared_splash_process_material = ParticleProcessMaterial.new()
	_shared_splash_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_shared_splash_process_material.emission_sphere_radius = 0.5
	_shared_splash_process_material.direction = Vector3.UP
	_shared_splash_process_material.spread = 78.0
	_shared_splash_process_material.initial_velocity_min = 5.0
	_shared_splash_process_material.initial_velocity_max = 11.0
	_shared_splash_process_material.gravity = Vector3(0.0, -16.0, 0.0)
	_shared_splash_process_material.scale_min = 0.5
	_shared_splash_process_material.scale_max = 1.45
	_shared_splash_process_material.color = Color(0.035, 0.38, 0.98, 0.94)
	return _shared_splash_process_material


func _splash_mesh() -> SphereMesh:
	if _shared_splash_mesh != null:
		return _shared_splash_mesh
	_shared_splash_mesh = SphereMesh.new()
	_shared_splash_mesh.radius = 0.14
	_shared_splash_mesh.height = 0.28
	_shared_splash_mesh.radial_segments = 8
	_shared_splash_mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.38, 0.98, 1.0)
	material.roughness = 0.3
	_shared_splash_mesh.material = material
	return _shared_splash_mesh


func _textured_process_material() -> ParticleProcessMaterial:
	if _shared_textured_process_material != null:
		return _shared_textured_process_material
	_shared_textured_process_material = ParticleProcessMaterial.new()
	_shared_textured_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_shared_textured_process_material.emission_sphere_radius = 0.55
	_shared_textured_process_material.direction = Vector3.UP
	_shared_textured_process_material.spread = 80.0
	_shared_textured_process_material.initial_velocity_min = 0.4
	_shared_textured_process_material.initial_velocity_max = 2.2
	_shared_textured_process_material.gravity = Vector3(0.0, -1.4, 0.0)
	_shared_textured_process_material.scale_min = 0.65
	_shared_textured_process_material.scale_max = 1.25
	_shared_textured_process_material.color = Color(0.035, 0.38, 1.0, 0.88)
	return _shared_textured_process_material


func _textured_mesh(texture: Texture2D, size: Vector2) -> QuadMesh:
	var key := "%s|%.3f|%.3f" % [texture.resource_path, size.x, size.y]
	var cached := _shared_textured_meshes.get(key) as QuadMesh
	if cached != null:
		return cached
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	quad.material = material
	_shared_textured_meshes[key] = quad
	return quad


func _emit_textured(pool: Array[GPUParticles3D], next_index: int, world_position: Vector3, amount: int) -> int:
	var particle := pool[next_index]
	particle.global_position = world_position
	particle.amount = amount
	particle.emitting = false
	particle.restart()
	particle.emitting = true
	return (next_index + 1) % pool.size()
