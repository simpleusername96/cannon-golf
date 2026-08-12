class_name AimCameraComposer
extends RefCounted

## Shared foreground-cannon composition. The accepted terrain remains
## authoritative; modest peripheral cropping is preferable to making the cannon
## disappear in order to fit every surface vertex.
const CAMERA_SIDE_OFFSET := 8.0
const CAMERA_HEIGHT_OFFSET := 6.0
const CAMERA_REAR_OFFSET := 30.0
const FOCUS_HEIGHT_FRACTION := 0.35
const FOCUS_DEPTH_FROM_FRONT_FRACTION := 0.25
const TERRAIN_FOCUS_CLEARANCE := 0.25


static func compose(
		interest_points: PackedVector3Array,
		terrain_bounds: AABB,
		cannon_transform: Transform3D,
		vertical_fov_degrees: float,
		aspect_ratio: float
) -> Dictionary:
	if interest_points.is_empty() or not terrain_bounds.has_volume() \
			or vertical_fov_degrees <= 0.0 or aspect_ratio <= 0.0:
		return {}
	var focus := _visible_surface_focus(interest_points, terrain_bounds)
	var cannon_origin := cannon_transform.origin
	return {
		"position": cannon_origin + Vector3(
			CAMERA_SIDE_OFFSET,
			CAMERA_HEIGHT_OFFSET,
			CAMERA_REAR_OFFSET
		),
		"focus": focus,
	}


static func _visible_surface_focus(
		interest_points: PackedVector3Array,
		terrain_bounds: AABB
) -> Vector3:
	var desired := Vector3(
		terrain_bounds.get_center().x,
		terrain_bounds.position.y + terrain_bounds.size.y * FOCUS_HEIGHT_FRACTION,
		terrain_bounds.end.z - terrain_bounds.size.z * FOCUS_DEPTH_FROM_FRONT_FRACTION
	)
	var best_point := desired
	var best_distance := INF
	var scale := Vector3(
		maxf(terrain_bounds.size.x, 0.001),
		maxf(terrain_bounds.size.y, 0.001),
		maxf(terrain_bounds.size.z, 0.001)
	)
	for point in interest_points:
		if not terrain_bounds.has_point(point):
			continue
		var normalized_delta := (point - desired) / scale
		var distance := normalized_delta.length_squared()
		if distance < best_distance:
			best_distance = distance
			best_point = point
	return best_point + Vector3.UP * TERRAIN_FOCUS_CLEARANCE
