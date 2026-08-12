class_name TerrainScreenRayPicker
extends RefCounted

## Latest-only screen ray contract. Queue from input and consume only in a
## fixed-physics callback; a changed or replaced camera context is rejected.
var _camera_ref: WeakRef
var _camera_transform := Transform3D.IDENTITY
var _camera_world: World3D
var _screen_position := Vector2.ZERO
var _request_revision := -1
var _consumed_request_revision := -1
var _has_pending_request := false


func queue_latest(camera: Camera3D, screen_position: Vector2, request_revision: int) -> bool:
	if camera == null or not is_instance_valid(camera) or not screen_position.is_finite():
		return false
	var world := camera.get_world_3d()
	if world == null:
		return false
	_camera_ref = weakref(camera)
	_camera_transform = camera.global_transform
	_camera_world = world
	_screen_position = screen_position
	_request_revision = request_revision
	_has_pending_request = true
	return true


func pick_latest_in_physics(terrain: TerrainSurface) -> TerrainAimTarget:
	if not _has_pending_request:
		return null
	_has_pending_request = false
	_consumed_request_revision = _request_revision
	if terrain == null or not is_instance_valid(terrain) or _camera_ref == null:
		return null
	var camera := _camera_ref.get_ref() as Camera3D
	if camera == null or not is_instance_valid(camera) or not camera.is_current() \
			or camera.get_world_3d() != _camera_world \
			or terrain.get_world_3d() != _camera_world \
			or not camera.global_transform.is_equal_approx(_camera_transform):
		return null
	var ray_origin := camera.project_ray_origin(_screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(_screen_position) * camera.far
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 0xFFFFFFFF)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := _camera_world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or not terrain.is_top_collider(hit.get("collider") as Object):
		return null
	var point := hit.get("position", Vector3.INF) as Vector3
	var normal := hit.get("normal", Vector3.ZERO) as Vector3
	if not point.is_finite() or not normal.is_finite() or normal.length_squared() <= 0.0:
		return null
	var identity := terrain.classify_top_physics_hit(
		point, TerrainSurface.TOP_SHAPE_ID, int(hit.get("shape", -1))
	)
	if identity == null:
		return null
	return TerrainAimTarget.new(point, normal, identity)


func queued_request_revision() -> int:
	return _request_revision if _has_pending_request else -1


func consumed_request_revision() -> int:
	return _consumed_request_revision


func clear() -> void:
	_camera_ref = null
	_camera_world = null
	_request_revision = -1
	_consumed_request_revision = -1
	_has_pending_request = false
