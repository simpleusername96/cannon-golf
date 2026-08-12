class_name ProjectileRangeConstraint
extends RefCounted

## Pure generation-time admission for the legal collision-free ballistic domain.
## It is deliberately a necessary range gate, not a terrain-occlusion or first-
## contact certificate. A complete target mask is either accepted or rejected.

const DEFAULT_PROJECTILE_DATA: ProjectileData = preload(
	"res://resources/projectiles/basic_paintball.tres"
)
const RANGE_SAMPLE_METERS := 0.25
const RANGE_TOLERANCE_METERS := 0.30
const HEIGHT_TOLERANCE_METERS := 0.50
const PERPENDICULAR_TOLERANCE_METERS := 0.12
const YAW_SAMPLE_DEGREES := 0.1
const ELEVATION_SAMPLE_DEGREES := 0.1

static var _envelope_cache: Dictionary = {}
static var _envelope_cache_mutex := Mutex.new()

var _stage_data: StageData
var _projectile_data: ProjectileData
var _motion_cache: Dictionary = {}
var _inverse_cannon_transform := Transform3D.IDENTITY
var _terrain_center_in_cannon_space := Vector3.ZERO
var _reference_origin := Vector3.ZERO
var _yaw_directions := PackedVector2Array()
var _lower_height_envelope := PackedFloat32Array()
var _upper_height_envelope := PackedFloat32Array()
var _maximum_reference_range := 0.0
var _configuration_rejection: StringName = &""
var _checked_target_count := 0
var _minimum_yaw_margin_degrees := INF
var _minimum_perpendicular_margin := INF
var _minimum_range_margin := INF
var _minimum_height_margin := INF


func _init(
		stage_data: StageData = null,
		projectile_data: ProjectileData = DEFAULT_PROJECTILE_DATA
) -> void:
	_stage_data = stage_data
	_projectile_data = projectile_data
	_configure()


func is_valid() -> bool:
	return _configuration_rejection.is_empty() and _stage_data != null \
			and _projectile_data != null and not _motion_cache.is_empty() \
			and not _yaw_directions.is_empty() \
			and not _lower_height_envelope.is_empty() \
			and _lower_height_envelope.size() == _upper_height_envelope.size() \
			and _maximum_reference_range > 0.0


func configuration_rejection() -> StringName:
	return _configuration_rejection


func evaluate_local_surface(
		local_surface_point: Vector3,
		local_surface_normal: Vector3,
		record_target: bool = true
) -> Dictionary:
	if not is_valid() or not local_surface_point.is_finite() \
			or not local_surface_normal.is_finite() \
			or local_surface_normal.is_zero_approx():
		return _failure(&"invalid_input")
	return _evaluate_cannon_local_center(
		_terrain_center_in_cannon_space + local_surface_point \
				+ local_surface_normal.normalized() * _projectile_data.radius,
		record_target
	)


func evaluate_world_surface(
		world_surface_point: Vector3,
		world_surface_normal: Vector3,
		record_target: bool = true
) -> Dictionary:
	if not is_valid() or not world_surface_point.is_finite() \
			or not world_surface_normal.is_finite() \
			or world_surface_normal.is_zero_approx():
		return _failure(&"invalid_input")
	var normalized_world_normal := world_surface_normal.normalized()
	return _evaluate_cannon_local_center(
		_inverse_cannon_transform * (
			world_surface_point + normalized_world_normal * _projectile_data.radius
		),
		record_target
	)


func _evaluate_cannon_local_center(
		desired_local_center: Vector3,
		record_target: bool
) -> Dictionary:
	var reference_delta := Vector2(
		desired_local_center.x - _reference_origin.x,
		desired_local_center.z - _reference_origin.z
	)
	if reference_delta.length_squared() <= 0.000001:
		return _failure(&"before_muzzle")
	var bearing := rad_to_deg(atan2(reference_delta.x, -reference_delta.y))
	var nearest_yaw := AimTuple.snap_angle(clampf(
		bearing,
		AimTuple.MINIMUM_YAW_DEGREES,
		AimTuple.MAXIMUM_YAW_DEGREES
	))
	var yaw_index := clampi(
		roundi((nearest_yaw - AimTuple.MINIMUM_YAW_DEGREES) / YAW_SAMPLE_DEGREES),
		0,
		_yaw_directions.size() - 1
	)
	var horizontal_direction := _yaw_directions[yaw_index]
	var projected_range := reference_delta.dot(horizontal_direction)
	var perpendicular_miss := absf(reference_delta.cross(horizontal_direction))
	var perpendicular_limit := _projectile_data.radius \
			+ PERPENDICULAR_TOLERANCE_METERS
	if projected_range <= 0.0 or perpendicular_miss > perpendicular_limit:
		return _failure(&"yaw", {
			"bearing_degrees": bearing,
			"nearest_yaw_degrees": nearest_yaw,
			"perpendicular_miss": perpendicular_miss,
			"perpendicular_limit": perpendicular_limit,
		})
	var height_interval := _height_interval_at(projected_range)
	if height_interval == Vector2.INF:
		return _failure(&"horizontal_range", {
			"bearing_degrees": bearing,
			"projected_range": projected_range,
			"maximum_range": _maximum_reference_range,
		})
	var lower_height := height_interval.x
	var upper_height := height_interval.y
	var yaw_margin := minf(
		bearing - AimTuple.MINIMUM_YAW_DEGREES,
		AimTuple.MAXIMUM_YAW_DEGREES - bearing
	)
	var perpendicular_margin := perpendicular_limit - perpendicular_miss
	var range_margin := _maximum_reference_range - projected_range
	var lower_height_margin := desired_local_center.y - lower_height
	var upper_height_margin := upper_height - desired_local_center.y
	var height_margin := minf(lower_height_margin, upper_height_margin)
	var result := {
		"valid": height_margin >= 0.0,
		"rejection": &"" if height_margin >= 0.0 \
				else (&"height_below" if lower_height_margin < 0.0 else &"height_above"),
		"bearing_degrees": bearing,
		"nearest_yaw_degrees": nearest_yaw,
		"projected_range": projected_range,
		"maximum_range": _maximum_reference_range,
		"lower_height": lower_height,
		"upper_height": upper_height,
		"desired_center_height": desired_local_center.y,
		"yaw_margin_degrees": yaw_margin,
		"perpendicular_margin": perpendicular_margin,
		"range_margin": range_margin,
		"lower_height_margin": lower_height_margin,
		"upper_height_margin": upper_height_margin,
		"height_margin": height_margin,
	}
	if bool(result.valid) and record_target:
		_checked_target_count += 1
		_minimum_yaw_margin_degrees = minf(_minimum_yaw_margin_degrees, yaw_margin)
		_minimum_perpendicular_margin = minf(
			_minimum_perpendicular_margin,
			perpendicular_margin
		)
		_minimum_range_margin = minf(_minimum_range_margin, range_margin)
		_minimum_height_margin = minf(_minimum_height_margin, height_margin)
	return result


func evaluate_summit(layout: GeneratedStageLayout) -> Dictionary:
	if not is_valid() or layout == null or not layout.is_valid():
		return _failure(&"invalid_summit_input")
	var summit_region := layout.summit_region()
	if summit_region.is_empty():
		return _failure(&"empty_summit_region")
	var best_failure: Dictionary = {}
	for sample in summit_region:
		var result := evaluate_local_surface(
			sample.point as Vector3,
			sample.normal as Vector3,
			false
		)
		if bool(result.get("valid", false)):
			result["summit_triangle_id"] = int(sample.triangle_id)
			result["summit_sample_count"] = summit_region.size()
			return result
		if best_failure.is_empty() or float(result.get("height_margin", -INF)) \
				> float(best_failure.get("height_margin", -INF)):
			best_failure = result
	best_failure["valid"] = false
	best_failure["summit_sample_count"] = summit_region.size()
	return best_failure


func target_metrics() -> Dictionary:
	return {
		"ballistic_target_count": _checked_target_count,
		"ballistic_minimum_yaw_margin_degrees": _minimum_yaw_margin_degrees,
		"ballistic_minimum_perpendicular_margin": _minimum_perpendicular_margin,
		"ballistic_minimum_range_margin": _minimum_range_margin,
		"ballistic_minimum_height_margin": _minimum_height_margin,
		"ballistic_maximum_reference_range": _maximum_reference_range,
	}


func _configure() -> void:
	if _stage_data == null or _projectile_data == null:
		_configuration_rejection = &"missing_stage_or_projectile"
		return
	if not _stage_data.cannon_transform.is_finite() or _projectile_data.radius <= 0.0 \
			or _projectile_data.minimum_launch_speed <= 0.0 \
			or _projectile_data.maximum_launch_speed <= 0.0 \
			or _projectile_data.minimum_launch_speed \
					> _projectile_data.maximum_launch_speed \
			or _projectile_data.linear_damp < 0.0:
		_configuration_rejection = &"invalid_stage_or_projectile"
		return
	var cannon_basis := _stage_data.cannon_transform.basis
	# Runtime launch velocity is expressed in world axes; a rotated/scaled cannon
	# root would make its visual muzzle and velocity disagree. Fail closed until
	# that broader runtime contract is explicitly changed in both owners.
	if not cannon_basis.is_equal_approx(Basis.IDENTITY):
		_configuration_rejection = &"unsupported_cannon_basis"
		return
	_inverse_cannon_transform = _stage_data.cannon_transform.affine_inverse()
	_terrain_center_in_cannon_space = _inverse_cannon_transform \
			* _stage_data.terrain_center
	_reference_origin = CannonBallistics.projectile_launch_origin_local(
		0.0, 90.0, _projectile_data.radius
	)
	var yaw_count := roundi(
		(AimTuple.MAXIMUM_YAW_DEGREES - AimTuple.MINIMUM_YAW_DEGREES) \
				/ YAW_SAMPLE_DEGREES
	) + 1
	_yaw_directions.resize(yaw_count)
	for yaw_index in range(yaw_count):
		var yaw := AimTuple.MINIMUM_YAW_DEGREES \
				+ float(yaw_index) * YAW_SAMPLE_DEGREES
		_yaw_directions[yaw_index] = Vector2(
			sin(deg_to_rad(yaw)),
			-cos(deg_to_rad(yaw))
		).normalized()
	var gravity_magnitude := float(ProjectSettings.get_setting(
		"physics/3d/default_gravity",
		9.8
	))
	var gravity_direction := Vector3(ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector",
		Vector3.DOWN
	)).normalized()
	if gravity_magnitude <= 0.0 or not gravity_direction.is_equal_approx(Vector3.DOWN):
		_configuration_rejection = &"unsupported_gravity"
		return
	_motion_cache = CannonBallistics.build_damped_motion_cache(
		_projectile_data.linear_damp,
		-gravity_magnitude,
		TrajectoryPredictor.PHYSICS_STEP,
		TrajectoryPredictor.MAXIMUM_STEPS
	)
	if _motion_cache.is_empty():
		_configuration_rejection = &"invalid_motion_cache"
		return
	var envelope := _cached_or_build_envelope(gravity_magnitude)
	_lower_height_envelope = envelope.get("lower_heights", PackedFloat32Array())
	_upper_height_envelope = envelope.get("upper_heights", PackedFloat32Array())
	_maximum_reference_range = float(envelope.get("maximum_reference_range", 0.0))
	if _lower_height_envelope.is_empty() \
			or _lower_height_envelope.size() != _upper_height_envelope.size() \
			or _maximum_reference_range <= 0.0:
		_configuration_rejection = &"invalid_envelope"


func _cached_or_build_envelope(gravity_magnitude: float) -> Dictionary:
	var cache_key := "%.6f|%.6f|%.6f|%.6f|%.6f|%d|%.6f|%.6f|%s|%s|%s|%s" % [
		_projectile_data.minimum_launch_speed,
		_projectile_data.maximum_launch_speed,
		_projectile_data.linear_damp,
		gravity_magnitude,
		TrajectoryPredictor.PHYSICS_STEP,
		TrajectoryPredictor.MAXIMUM_STEPS,
		AimTuple.MINIMUM_ELEVATION_DEGREES,
		AimTuple.MAXIMUM_ELEVATION_DEGREES,
		str(CannonBallistics.YAW_PIVOT_OFFSET),
		str(CannonBallistics.ELEVATION_PIVOT_OFFSET),
		str(CannonBallistics.MUZZLE_OFFSET),
		str(_projectile_data.radius),
	]
	_envelope_cache_mutex.lock()
	var envelope: Dictionary = _envelope_cache.get(cache_key, {})
	if envelope.is_empty():
		envelope = _build_envelope()
		_envelope_cache[cache_key] = envelope
	_envelope_cache_mutex.unlock()
	return envelope


func _build_envelope() -> Dictionary:
	var reference_origin := CannonBallistics.projectile_launch_origin_local(
		0.0, 90.0, _projectile_data.radius
	)
	var horizontal_factors: PackedFloat64Array = _motion_cache.horizontal_factors
	var final_horizontal_factor := horizontal_factors[TrajectoryPredictor.MAXIMUM_STEPS]
	var minimum_speed := _projectile_data.minimum_launch_speed
	var maximum_speed := _projectile_data.maximum_launch_speed
	var speed_span := maximum_speed - minimum_speed
	var maximum_range := 0.0
	var elevation_count := roundi(
		(AimTuple.MAXIMUM_ELEVATION_DEGREES - AimTuple.MINIMUM_ELEVATION_DEGREES) \
				/ ELEVATION_SAMPLE_DEGREES
	) + 1
	var origins := PackedVector3Array()
	var cosines := PackedFloat32Array()
	var sines := PackedFloat32Array()
	var muzzle_forward_offsets := PackedFloat32Array()
	var horizontal_speeds := PackedFloat32Array()
	var vertical_speeds := PackedFloat32Array()
	origins.resize(elevation_count)
	cosines.resize(elevation_count)
	sines.resize(elevation_count)
	muzzle_forward_offsets.resize(elevation_count)
	horizontal_speeds.resize(elevation_count)
	vertical_speeds.resize(elevation_count)
	for index in range(elevation_count):
		var elevation := AimTuple.MINIMUM_ELEVATION_DEGREES \
				+ float(index) * ELEVATION_SAMPLE_DEGREES
		var origin := CannonBallistics.projectile_launch_origin_local(
			0.0, elevation, _projectile_data.radius
		)
		var radians := deg_to_rad(elevation)
		var cosine := cos(radians)
		var sine := sin(radians)
		var horizontal_speed := maximum_speed * cosine
		var vertical_speed := maximum_speed * sine
		var muzzle_forward_offset := Vector2(
			origin.x - reference_origin.x,
			origin.z - reference_origin.z
		).dot(Vector2(0.0, -1.0))
		origins[index] = origin
		cosines[index] = cosine
		sines[index] = sine
		muzzle_forward_offsets[index] = muzzle_forward_offset
		horizontal_speeds[index] = horizontal_speed
		vertical_speeds[index] = vertical_speed
		maximum_range = maxf(
			maximum_range,
			muzzle_forward_offset + horizontal_speed * final_horizontal_factor
		)
	var sample_count := ceili(maximum_range / RANGE_SAMPLE_METERS) + 1
	var lower_heights := PackedFloat32Array()
	var upper_heights := PackedFloat32Array()
	lower_heights.resize(sample_count)
	upper_heights.resize(sample_count)
	for range_index in range(sample_count):
		var reference_range := float(range_index) * RANGE_SAMPLE_METERS
		var lower_height := INF
		var upper_height := -INF
		for elevation_index in range(elevation_count):
			var origin := origins[elevation_index]
			var muzzle_forward_offset := muzzle_forward_offsets[elevation_index]
			var range_from_muzzle := reference_range - muzzle_forward_offset
			if range_from_muzzle <= 0.0:
				continue
			var relative := CannonBallistics.damped_position_at_horizontal_range(
				horizontal_speeds[elevation_index],
				vertical_speeds[elevation_index],
				range_from_muzzle,
				_motion_cache
			)
			if relative == Vector2.INF:
				continue
			upper_height = maxf(upper_height, origin.y + relative.y)
			var required_speed := range_from_muzzle \
					/ maxf(float(cosines[elevation_index]) * final_horizontal_factor, 0.000001)
			if required_speed > maximum_speed + 0.000001:
				continue
			var minimum_power := 0
			if speed_span > 0.000001 and required_speed > minimum_speed:
				minimum_power = clampi(
					ceili((required_speed - minimum_speed) / speed_span * 100.0 - 0.000001),
					AimTuple.MINIMUM_POWER_PERCENT,
					AimTuple.MAXIMUM_POWER_PERCENT
				)
			var lowest_reaching_speed := _projectile_data.launch_speed(
				float(minimum_power)
			)
			var lower_relative := CannonBallistics.damped_position_at_horizontal_range(
				lowest_reaching_speed * cosines[elevation_index],
				lowest_reaching_speed * sines[elevation_index],
				range_from_muzzle,
				_motion_cache
			)
			if lower_relative != Vector2.INF:
				lower_height = minf(lower_height, origin.y + lower_relative.y)
		lower_heights[range_index] = lower_height
		upper_heights[range_index] = upper_height
	return {
		"lower_heights": lower_heights,
		"upper_heights": upper_heights,
		"maximum_reference_range": maximum_range,
	}


func _height_interval_at(projected_range: float) -> Vector2:
	if projected_range <= 0.0 \
			or projected_range > _maximum_reference_range + RANGE_TOLERANCE_METERS:
		return Vector2.INF
	var position := projected_range / RANGE_SAMPLE_METERS
	var lower_index := clampi(floori(position), 0, _upper_height_envelope.size() - 1)
	var upper_index := clampi(lower_index + 1, 0, _upper_height_envelope.size() - 1)
	var lower_height := minf(
		_lower_height_envelope[lower_index],
		_lower_height_envelope[upper_index]
	)
	var upper_height := maxf(
		_upper_height_envelope[lower_index],
		_upper_height_envelope[upper_index]
	)
	if not is_finite(lower_height) or not is_finite(upper_height) \
			or lower_height > upper_height:
		return Vector2.INF
	return Vector2(
		lower_height - HEIGHT_TOLERANCE_METERS,
		upper_height + HEIGHT_TOLERANCE_METERS
	)


func _failure(reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := details.duplicate()
	result["valid"] = false
	result["rejection"] = reason
	return result
