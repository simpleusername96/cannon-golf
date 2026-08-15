class_name CannonGolfOverviewCameraSolver
extends RefCounted

const FRAME_MARGIN := 1.08
const CLOSE_DISTANCE := 28.0
const FAR_DISTANCE_SCALE := 1.18
const BOOM_RADIUS := 1.25
const BOOM_MARGIN := 0.5


static func resolve_pose(
		camera: Camera3D,
		bounds: AABB,
		focus: Vector3,
		framing_focus: Vector3,
		base_offset: Vector3,
		orbit_degrees: Vector2,
		zoom: float
) -> Array[Vector3]:
	var direction := base_offset.normalized()
	var yaw := atan2(direction.x, direction.z) + deg_to_rad(orbit_degrees.x)
	var pitch := clampf(
		asin(clampf(direction.y, -1.0, 1.0)) + deg_to_rad(orbit_degrees.y),
		deg_to_rad(12.0),
		deg_to_rad(78.0)
	)
	var orbit_direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var pose := TerrainCameraFramer.framed_pose_around(
		bounds,
		framing_focus,
		framing_focus + orbit_direction * maxf(base_offset.length(), 1.0),
		framing_focus,
		camera.fov,
		viewport_size.x / maxf(viewport_size.y, 1.0),
		FRAME_MARGIN
	)
	var framed_position: Vector3 = pose[0]
	# Fit against the authored reset pivot, then translate that fixed boom to the
	# explored pivot. Panning must not silently zoom as the pivot nears an edge.
	var framed_offset := framed_position - framing_focus
	var framed_distance := maxf(framed_offset.length(), CLOSE_DISTANCE)
	var distance := framed_distance
	if zoom >= 0.0:
		distance = exp(lerpf(log(framed_distance), log(CLOSE_DISTANCE), zoom / 10.0))
	else:
		distance = framed_distance * lerpf(1.0, FAR_DISTANCE_SCALE, -zoom / 6.0)
	return [focus + framed_offset.normalized() * distance, focus]


static func sweep_boom(
		camera: Camera3D,
		origin: Vector3,
		desired: Vector3,
		exclusions: Array[RID],
		fallback: Vector3
) -> Vector3:
	var motion := desired - origin
	if not origin.is_finite() or not desired.is_finite() or motion.length() <= 0.01:
		return fallback
	var sphere := SphereShape3D.new()
	sphere.radius = BOOM_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = motion
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclusions
	var fractions := camera.get_world_3d().direct_space_state.cast_motion(query)
	if fractions.size() < 2:
		return fallback
	if fractions[0] >= 0.999:
		return desired
	var safe_fraction := maxf(0.0, fractions[0] - BOOM_MARGIN / motion.length())
	# A blocked spring arm collapses along its own boom. Returning a stale camera
	# position can put the new line of sight through terrain after a pan.
	return origin + motion * safe_fraction
