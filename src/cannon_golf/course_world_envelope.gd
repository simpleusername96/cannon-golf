class_name CannonGolfCourseWorldEnvelope
extends RefCounted

## Resolves the presentation envelope around generated course bounds.

const BASE_GROUND_RADIUS := 160.0
const BASE_FAR_DISTANCE := 520.0
const BASE_GROUND_CENTER_XZ := Vector2(0.0, -13.0)
const GROUND_MARGIN := 32.0
const LONGITUDINAL_EXPANSION_THRESHOLD := 220.0


static func resolve(content_bounds: AABB) -> Dictionary:
	assert(content_bounds.has_volume(), "World envelope requires valid content bounds.")
	if content_bounds.size.z <= LONGITUDINAL_EXPANSION_THRESHOLD:
		return {
			"ground_center": Vector3(
				BASE_GROUND_CENTER_XZ.x,
				0.0,
				BASE_GROUND_CENTER_XZ.y
			),
			"ground_scale": 1.0,
			"far_distance": BASE_FAR_DISTANCE,
		}
	var horizontal_radius := Vector2(
		content_bounds.size.x,
		content_bounds.size.z
	).length() * 0.5 + GROUND_MARGIN
	return {
		"ground_center": Vector3(
			content_bounds.get_center().x,
			0.0,
			content_bounds.get_center().z
		),
		"ground_scale": maxf(1.0, horizontal_radius / BASE_GROUND_RADIUS),
		"far_distance": maxf(BASE_FAR_DISTANCE, content_bounds.size.length() * 2.4),
	}
