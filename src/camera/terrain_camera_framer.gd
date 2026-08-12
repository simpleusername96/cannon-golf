class_name TerrainCameraFramer
extends RefCounted

const DEFAULT_MARGIN := 1.08
const FIT_DISTANCE_EPSILON := 0.05


static func framed_pose(
		bounds: AABB,
		authored_position: Vector3,
		authored_focus: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		margin: float = DEFAULT_MARGIN
) -> Array[Vector3]:
	return framed_pose_around(
		bounds,
		bounds.get_center(),
		authored_position,
		authored_focus,
		vertical_fov_degrees,
		aspect_ratio,
		margin
	)


static func framed_pose_around(
		bounds: AABB,
		focus: Vector3,
		authored_position: Vector3,
		authored_focus: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		margin: float = DEFAULT_MARGIN
) -> Array[Vector3]:
	assert(bounds.has_volume(), "Terrain camera framing requires non-empty render bounds.")
	return framed_pose_around_points(
		_packed_bounds_corners(bounds),
		focus,
		authored_position,
		authored_focus,
		vertical_fov_degrees,
		aspect_ratio,
		margin
	)


static func framed_pose_around_points(
		points: PackedVector3Array,
		focus: Vector3,
		authored_position: Vector3,
		authored_focus: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		margin: float = DEFAULT_MARGIN
) -> Array[Vector3]:
	assert(not points.is_empty(), "Terrain camera framing requires at least one world point.")
	assert(focus.is_finite(), "Terrain camera framing requires a finite focus.")
	assert(vertical_fov_degrees > 1.0 and vertical_fov_degrees < 179.0, "Terrain camera framing requires a valid vertical FOV.")
	assert(aspect_ratio > 0.0 and margin >= 1.0, "Terrain camera framing requires a positive aspect and non-cropping margin.")
	var forward := _authored_forward(authored_position, authored_focus)
	var required_distance := maxf(
		_required_distance_around_points(
			points, focus, forward, vertical_fov_degrees, aspect_ratio, margin
		),
		1.0
	) + FIT_DISTANCE_EPSILON
	return [focus - forward * required_distance, focus]


## Fits the supplied points inside an asymmetric normalized viewport region.
## The authored vector keeps the view direction while the returned focus shifts
## the content toward the safe region without cropping it behind UI.
static func framed_pose_in_normalized_rect(
		points: PackedVector3Array,
		content_center: Vector3,
		authored_position: Vector3,
		authored_focus: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		safe_rect: Rect2,
		margin: float = DEFAULT_MARGIN
) -> Array[Vector3]:
	if not _valid_normalized_rect_request(
		points, content_center, vertical_fov_degrees, aspect_ratio, safe_rect, margin
	) or not authored_position.is_finite() or not authored_focus.is_finite():
		return []
	var inner_rect := _inner_normalized_rect(safe_rect, margin)
	var forward := _authored_forward(authored_position, authored_focus)
	var basis := _view_basis(forward)
	var right: Vector3 = basis["right"]
	var up: Vector3 = basis["up"]
	var tangents := _frustum_tangents(vertical_fov_degrees, aspect_ratio)
	var horizontal_tangent: float = tangents["horizontal"]
	var vertical_tangent: float = tangents["vertical"]
	var left_ndc := inner_rect.position.x * 2.0 - 1.0
	var right_ndc := inner_rect.end.x * 2.0 - 1.0
	var top_ndc := 1.0 - inner_rect.position.y * 2.0
	var bottom_ndc := 1.0 - inner_rect.end.y * 2.0
	var minimum_distance := 1.0
	for point in points:
		var relative := point - content_center
		minimum_distance = maxf(
			minimum_distance,
			-relative.dot(forward) + FIT_DISTANCE_EPSILON
		)
	var maximum_distance := minimum_distance
	var intervals := _shift_intervals_for_distance(
		points, content_center, forward, right, up, maximum_distance,
		horizontal_tangent, vertical_tangent,
		left_ndc, right_ndc, bottom_ndc, top_ndc
	)
	for _expansion in range(32):
		if bool(intervals.get("valid", false)):
			break
		maximum_distance *= 2.0
		intervals = _shift_intervals_for_distance(
			points, content_center, forward, right, up, maximum_distance,
			horizontal_tangent, vertical_tangent,
			left_ndc, right_ndc, bottom_ndc, top_ndc
		)
	if not bool(intervals.get("valid", false)):
		return []
	var lower_distance := minimum_distance
	for _iteration in range(48):
		var candidate_distance := (lower_distance + maximum_distance) * 0.5
		var candidate_intervals := _shift_intervals_for_distance(
			points, content_center, forward, right, up, candidate_distance,
			horizontal_tangent, vertical_tangent,
			left_ndc, right_ndc, bottom_ndc, top_ndc
		)
		if bool(candidate_intervals.get("valid", false)):
			maximum_distance = candidate_distance
			intervals = candidate_intervals
		else:
			lower_distance = candidate_distance
	var right_shift := (float(intervals.x_min) + float(intervals.x_max)) * 0.5
	var up_shift := (float(intervals.y_min) + float(intervals.y_max)) * 0.5
	var shifted_focus := content_center - right * right_shift - up * up_shift
	return [shifted_focus - forward * (maximum_distance + FIT_DISTANCE_EPSILON), shifted_focus]


static func _shift_intervals_for_distance(
	points: PackedVector3Array,
	content_center: Vector3,
	forward: Vector3,
	right: Vector3,
	up: Vector3,
	distance: float,
	horizontal_tangent: float,
	vertical_tangent: float,
	left_ndc: float,
	right_ndc: float,
	bottom_ndc: float,
	top_ndc: float
) -> Dictionary:
	var x_min := -INF
	var x_max := INF
	var y_min := -INF
	var y_max := INF
	for point in points:
		var relative := point - content_center
		var depth := distance + relative.dot(forward)
		if depth <= FIT_DISTANCE_EPSILON:
			return {"valid": false}
		var right_offset := relative.dot(right)
		var up_offset := relative.dot(up)
		x_min = maxf(x_min, left_ndc * depth * horizontal_tangent - right_offset)
		x_max = minf(x_max, right_ndc * depth * horizontal_tangent - right_offset)
		y_min = maxf(y_min, bottom_ndc * depth * vertical_tangent - up_offset)
		y_max = minf(y_max, top_ndc * depth * vertical_tangent - up_offset)
	return {
		"valid": x_min <= x_max and y_min <= y_max,
		"x_min": x_min,
		"x_max": x_max,
		"y_min": y_min,
		"y_max": y_max,
	}


static func pose_fits_points_in_normalized_rect(
		points: PackedVector3Array,
		position: Vector3,
		focus: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		safe_rect: Rect2,
		margin: float = 1.0
) -> bool:
	if not _valid_normalized_rect_request(
		points, focus, vertical_fov_degrees, aspect_ratio, safe_rect, margin
	) or not position.is_finite():
		return false
	var inner_rect := _inner_normalized_rect(safe_rect, margin)
	var forward := _authored_forward(position, focus)
	var basis := _view_basis(forward)
	var right: Vector3 = basis["right"]
	var up: Vector3 = basis["up"]
	var tangents := _frustum_tangents(vertical_fov_degrees, aspect_ratio)
	var horizontal_tangent: float = tangents["horizontal"]
	var vertical_tangent: float = tangents["vertical"]
	for point in points:
		var relative := point - position
		var depth := relative.dot(forward)
		if depth <= 0.0:
			return false
		var normalized := Vector2(
			0.5 + relative.dot(right) / (depth * horizontal_tangent) * 0.5,
			0.5 - relative.dot(up) / (depth * vertical_tangent) * 0.5
		)
		if normalized.x < inner_rect.position.x - FIT_DISTANCE_EPSILON \
				or normalized.x > inner_rect.end.x + FIT_DISTANCE_EPSILON \
				or normalized.y < inner_rect.position.y - FIT_DISTANCE_EPSILON \
				or normalized.y > inner_rect.end.y + FIT_DISTANCE_EPSILON:
			return false
	return true


## Uses the same frustum math as framed_pose_around so callers can preserve an
## authored pose whenever it already contains the requested bounds.
static func pose_fits_bounds(
		bounds: AABB,
		position: Vector3,
		focus: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		margin: float = DEFAULT_MARGIN
) -> bool:
	if not bounds.has_volume():
		return false
	return pose_fits_points(
		_packed_bounds_corners(bounds),
		position,
		focus,
		vertical_fov_degrees,
		aspect_ratio,
		margin
	)


static func pose_fits_points(
		points: PackedVector3Array,
		position: Vector3,
		focus: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		margin: float = DEFAULT_MARGIN
) -> bool:
	if points.is_empty() or not position.is_finite() or not focus.is_finite() \
			or vertical_fov_degrees <= 1.0 or vertical_fov_degrees >= 179.0 \
			or aspect_ratio <= 0.0 or margin < 1.0:
		return false
	var forward := _authored_forward(position, focus)
	var basis: Dictionary = _view_basis(forward)
	var view_forward: Vector3 = basis["forward"]
	var right: Vector3 = basis["right"]
	var up: Vector3 = basis["up"]
	var tangents: Dictionary = _frustum_tangents(vertical_fov_degrees, aspect_ratio)
	var horizontal_tangent: float = tangents["horizontal"]
	var vertical_tangent: float = tangents["vertical"]
	for point in points:
		var relative := point - position
		var depth := relative.dot(view_forward)
		if depth <= 0.0:
			return false
		if absf(relative.dot(right)) * margin > depth * horizontal_tangent:
			return false
		if absf(relative.dot(up)) * margin > depth * vertical_tangent:
			return false
	return true


static func _required_distance_around_points(
		points: PackedVector3Array,
		focus: Vector3,
		forward: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		margin: float = DEFAULT_MARGIN
) -> float:
	var basis: Dictionary = _view_basis(forward)
	var view_forward: Vector3 = basis["forward"]
	var right: Vector3 = basis["right"]
	var up: Vector3 = basis["up"]
	var tangents: Dictionary = _frustum_tangents(vertical_fov_degrees, aspect_ratio)
	var horizontal_tangent: float = tangents["horizontal"]
	var vertical_tangent: float = tangents["vertical"]
	var required_distance := 0.0
	for point in points:
		var relative := point - focus
		var forward_offset := relative.dot(view_forward)
		required_distance = maxf(required_distance, maxf(
			absf(relative.dot(right)) * margin / horizontal_tangent - forward_offset,
			absf(relative.dot(up)) * margin / vertical_tangent - forward_offset
		))
	return required_distance


static func _authored_forward(authored_position: Vector3, authored_focus: Vector3) -> Vector3:
	var forward := (authored_focus - authored_position).normalized()
	return Vector3(0.0, -0.2, -1.0).normalized() if forward.is_zero_approx() else forward


static func _view_basis(forward: Vector3) -> Dictionary:
	var reference_up := Vector3.FORWARD if absf(forward.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var right := forward.cross(reference_up).normalized()
	return {"forward": forward, "right": right, "up": right.cross(forward).normalized()}


static func _frustum_tangents(vertical_fov_degrees: float, aspect_ratio: float) -> Dictionary:
	var vertical_half_fov := deg_to_rad(vertical_fov_degrees * 0.5)
	return {
		"vertical": tan(vertical_half_fov),
		"horizontal": tan(atan(tan(vertical_half_fov) * aspect_ratio)),
	}


static func _valid_normalized_rect_request(
		points: PackedVector3Array,
		content_center: Vector3,
		vertical_fov_degrees: float,
		aspect_ratio: float,
		safe_rect: Rect2,
		margin: float
) -> bool:
	if points.is_empty() or not content_center.is_finite() \
			or not is_finite(vertical_fov_degrees) or not is_finite(aspect_ratio) \
			or not is_finite(margin) or not safe_rect.position.is_finite() \
			or not safe_rect.size.is_finite() \
			or vertical_fov_degrees <= 1.0 or vertical_fov_degrees >= 179.0 \
			or aspect_ratio <= 0.0 or margin < 1.0 \
			or safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0 \
			or safe_rect.position.x < 0.0 or safe_rect.position.y < 0.0 \
			or safe_rect.end.x > 1.0 or safe_rect.end.y > 1.0:
		return false
	for point in points:
		if not point.is_finite():
			return false
	return true


static func _inner_normalized_rect(safe_rect: Rect2, margin: float) -> Rect2:
	var half_size := safe_rect.size * 0.5 / margin
	return Rect2(safe_rect.get_center() - half_size, half_size * 2.0)


static func bounds_corners(bounds: AABB) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x_side in range(2):
		for y_side in range(2):
			for z_side in range(2):
				result.append(bounds.position + Vector3(
					bounds.size.x * float(x_side),
					bounds.size.y * float(y_side),
					bounds.size.z * float(z_side)
				))
	return result


static func _packed_bounds_corners(bounds: AABB) -> PackedVector3Array:
	var result := PackedVector3Array()
	for corner in bounds_corners(bounds):
		result.append(corner)
	return result
