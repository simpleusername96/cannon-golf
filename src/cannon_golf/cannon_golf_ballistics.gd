class_name CannonGolfBallistics
extends RefCounted

## Pure launch and range-admission contract for Cannon Golf.
##
## The generated shot axis is world data. Horizontal aim is the player's
## centered parameter and is converted here so launch, terrain admission, and
## tests cannot drift into separate ballistic models.

const MINIMUM_HORIZONTAL_AIM := 0.0
const MAXIMUM_HORIZONTAL_AIM := 100.0
const CENTER_HORIZONTAL_AIM := 50.0
const MINIMUM_YAW_OFFSET_DEGREES := -80.0
const MAXIMUM_YAW_OFFSET_DEGREES := 80.0
const MINIMUM_ELEVATION_DEGREES := 10.0
const MAXIMUM_ELEVATION_DEGREES := 68.0
const MINIMUM_POWER_PERCENT := 10.0
const MAXIMUM_POWER_PERCENT := 100.0
const MOTION_TIME_SCALE := 2.0
const MINIMUM_SPEED := 14.0 * MOTION_TIME_SCALE
const MAXIMUM_SPEED := 60.0 * MOTION_TIME_SCALE
const BALL_RADIUS := 1.0
const YAW_PIVOT_HEIGHT := 1.05
const BARREL_LENGTH := 4.0
const MUZZLE_CLEARANCE_FACTOR := 1.2
const LINEAR_DAMP := 0.10 * MOTION_TIME_SCALE
const GRAVITY_Y := -9.8 * MOTION_TIME_SCALE * MOTION_TIME_SCALE
const PHYSICS_STEP_SECONDS := 1.0 / 60.0
const MAXIMUM_FLIGHT_SECONDS := 10.0
const MAXIMUM_STEPS := 600
const REQUIRED_RANGE_MARGIN := 8.0
const REQUIRED_YAW_MARGIN_DEGREES := 8.0
const REQUIRED_HEIGHT_MARGIN := 8.0
const ADMISSION_SAMPLE_ELEVATIONS := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 68.0]
const ADMISSION_SAMPLE_POWERS := [10.0, 100.0]

static var _motion_cache: Dictionary = {}
static var _maximum_range := -1.0


static func canonical_horizontal_aim(value: float) -> float:
	return clampf(roundf(value), MINIMUM_HORIZONTAL_AIM, MAXIMUM_HORIZONTAL_AIM)


static func canonical_elevation(value: float) -> float:
	return clampf(roundf(value), MINIMUM_ELEVATION_DEGREES, MAXIMUM_ELEVATION_DEGREES)


static func canonical_power(value: float) -> float:
	return clampf(roundf(value), MINIMUM_POWER_PERCENT, MAXIMUM_POWER_PERCENT)


static func yaw_offset_degrees(horizontal_aim: float) -> float:
	return lerpf(
		MINIMUM_YAW_OFFSET_DEGREES,
		MAXIMUM_YAW_OFFSET_DEGREES,
		canonical_horizontal_aim(horizontal_aim) / MAXIMUM_HORIZONTAL_AIM
	)


static func world_yaw_degrees(shot_axis_yaw_degrees: float, horizontal_aim: float) -> float:
	return shot_axis_yaw_degrees + yaw_offset_degrees(horizontal_aim)


static func launch_direction(
		shot_axis_yaw_degrees: float,
		horizontal_aim: float,
		elevation_degrees: float
) -> Vector3:
	var yaw := deg_to_rad(world_yaw_degrees(shot_axis_yaw_degrees, horizontal_aim))
	var elevation := deg_to_rad(canonical_elevation(elevation_degrees))
	var horizontal := cos(elevation)
	return Vector3(
		sin(yaw) * horizontal,
		sin(elevation),
		-cos(yaw) * horizontal
	).normalized()


static func launch_speed(power_percent: float) -> float:
	return lerpf(MINIMUM_SPEED, MAXIMUM_SPEED, canonical_power(power_percent) / 100.0)


static func launch_origin(
		cannon_position: Vector3,
		shot_axis_yaw_degrees: float,
		horizontal_aim: float,
		elevation_degrees: float
) -> Vector3:
	return cannon_position + Vector3.UP * YAW_PIVOT_HEIGHT \
			+ launch_direction(shot_axis_yaw_degrees, horizontal_aim, elevation_degrees) \
			* (BARREL_LENGTH + BALL_RADIUS * MUZZLE_CLEARANCE_FACTOR)


static func launch_velocity(
		shot_axis_yaw_degrees: float,
		horizontal_aim: float,
		elevation_degrees: float,
		power_percent: float
) -> Vector3:
	return launch_direction(shot_axis_yaw_degrees, horizontal_aim, elevation_degrees) \
			* launch_speed(power_percent)


## Returns minimum and maximum reachable height relative to the cannon root at
## one radial horizontal distance. Legal whole-degree elevation and power values
## share the same damped 60 Hz recurrence as the live rigid body.
static func reachable_height_interval(horizontal_distance: float) -> Vector2:
	if horizontal_distance <= 0.0 or horizontal_distance > maximum_horizontal_range():
		return Vector2(INF, -INF)
	var cache := _damped_motion_cache()
	var horizontal_factors: PackedFloat64Array = cache.horizontal_factors
	var horizon_factor := float(horizontal_factors[MAXIMUM_STEPS])
	var lowest := INF
	var highest := -INF
	for elevation_value in range(
		int(MINIMUM_ELEVATION_DEGREES), int(MAXIMUM_ELEVATION_DEGREES) + 1
	):
		var elevation := deg_to_rad(float(elevation_value))
		var horizontal_scale := cos(elevation)
		var muzzle_forward := horizontal_scale * (BARREL_LENGTH + BALL_RADIUS * MUZZLE_CLEARANCE_FACTOR)
		var projected_range := horizontal_distance - muzzle_forward
		if projected_range <= 0.0:
			continue
		var required_speed := projected_range / maxf(horizontal_scale * horizon_factor, 0.000001)
		if required_speed > MAXIMUM_SPEED + 0.0001:
			continue
		var minimum_power := _minimum_legal_power_for_speed(required_speed)
		var speeds := PackedFloat32Array([launch_speed(minimum_power), launch_speed(MAXIMUM_POWER_PERCENT)])
		for speed in speeds:
			var displacement := CannonBallistics.damped_position_at_horizontal_range(
				speed * horizontal_scale,
				speed * sin(elevation),
				projected_range,
				cache
			)
			if not displacement.is_finite():
				continue
			var height := YAW_PIVOT_HEIGHT \
					+ sin(elevation) * (BARREL_LENGTH + BALL_RADIUS * MUZZLE_CLEARANCE_FACTOR) \
					+ displacement.y
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	return Vector2(lowest, highest)


## Returns a conservative inner interval made only from legal sampled shots.
## A point inside this interval by the required margin is therefore admitted
## without evaluating the full outer envelope; uncertain points still use the
## exact interval above.
static func sampled_reachable_height_interval(horizontal_distance: float) -> Vector2:
	if horizontal_distance <= 0.0 or horizontal_distance > maximum_horizontal_range():
		return Vector2(INF, -INF)
	var lowest := INF
	var highest := -INF
	for elevation in ADMISSION_SAMPLE_ELEVATIONS:
		for power in ADMISSION_SAMPLE_POWERS:
			var height := _height_for_setup_at_distance(horizontal_distance, elevation, power)
			if not is_finite(height):
				continue
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	return Vector2(lowest, highest)


## Exact analytic height of one legal setup at a horizontal distance. Course
## construction uses this before terrain exists; live launch still owns the
## final rigid-body motion.
static func height_for_setup_at_distance(
		horizontal_distance: float, elevation_degrees: float, power_percent: float
) -> float:
	return _height_for_setup_at_distance(
		horizontal_distance,
		canonical_elevation(elevation_degrees),
		canonical_power(power_percent)
	)


static func maximum_horizontal_range() -> float:
	if _maximum_range >= 0.0:
		return _maximum_range
	var cache := _damped_motion_cache()
	var horizontal_factors: PackedFloat64Array = cache.horizontal_factors
	var horizon_factor := float(horizontal_factors[MAXIMUM_STEPS])
	_maximum_range = 0.0
	for elevation_value in range(
		int(MINIMUM_ELEVATION_DEGREES), int(MAXIMUM_ELEVATION_DEGREES) + 1
	):
		var horizontal_scale := cos(deg_to_rad(float(elevation_value)))
		_maximum_range = maxf(
			_maximum_range,
			horizontal_scale * (BARREL_LENGTH + BALL_RADIUS * MUZZLE_CLEARANCE_FACTOR) \
					+ MAXIMUM_SPEED * horizontal_scale * horizon_factor
		)
	return _maximum_range


static func admit_world_point(
		point: Vector3,
		cannon_position: Vector3,
		shot_axis_yaw_degrees: float
) -> Dictionary:
	var horizontal_delta := Vector2(point.x - cannon_position.x, point.z - cannon_position.z)
	var distance := horizontal_delta.length()
	var bearing := rad_to_deg(atan2(horizontal_delta.x, -horizontal_delta.y))
	var yaw_offset := wrapf(bearing - shot_axis_yaw_degrees, -180.0, 180.0)
	var interval := reachable_height_interval(distance)
	var relative_height := point.y - cannon_position.y
	var yaw_margin := MAXIMUM_YAW_OFFSET_DEGREES - absf(yaw_offset)
	var range_margin := maximum_horizontal_range() - distance
	var height_margin := minf(
		relative_height - interval.x,
		interval.y - relative_height
	) if interval.is_finite() and interval.x <= interval.y else -INF
	var in_front := absf(yaw_offset) < 90.0
	var yaw_valid := yaw_margin >= 0.0
	var range_valid := range_margin >= 0.0
	var height_valid := height_margin >= 0.0
	return {
		"passed": in_front and yaw_valid and range_valid and height_valid \
				and yaw_margin >= REQUIRED_YAW_MARGIN_DEGREES \
				and range_margin >= REQUIRED_RANGE_MARGIN \
				and height_margin >= REQUIRED_HEIGHT_MARGIN,
		"in_front": in_front,
		"yaw_valid": yaw_valid,
		"range_valid": range_valid,
		"height_valid": height_valid,
		"distance": distance,
		"yaw_offset_degrees": yaw_offset,
		"relative_height": relative_height,
		"height_interval": interval,
		"yaw_margin_degrees": yaw_margin,
		"range_margin": range_margin,
		"height_margin": height_margin,
	}


static func _minimum_legal_power_for_speed(required_speed: float) -> float:
	var raw_percent := (required_speed - MINIMUM_SPEED) \
			/ (MAXIMUM_SPEED - MINIMUM_SPEED) * 100.0
	return clampf(ceilf(raw_percent - 0.00001), MINIMUM_POWER_PERCENT, MAXIMUM_POWER_PERCENT)


static func _height_for_setup_at_distance(
		horizontal_distance: float, elevation_degrees: float, power_percent: float
) -> float:
	var elevation := deg_to_rad(elevation_degrees)
	var horizontal_scale := cos(elevation)
	var muzzle_forward := horizontal_scale * (BARREL_LENGTH + BALL_RADIUS * MUZZLE_CLEARANCE_FACTOR)
	var projected_range := horizontal_distance - muzzle_forward
	if projected_range <= 0.0:
		return INF
	var speed := launch_speed(power_percent)
	var displacement := CannonBallistics.damped_position_at_horizontal_range(
		speed * horizontal_scale,
		speed * sin(elevation),
		projected_range,
		_damped_motion_cache()
	)
	if not displacement.is_finite():
		return INF
	return YAW_PIVOT_HEIGHT \
			+ sin(elevation) * (BARREL_LENGTH + BALL_RADIUS * MUZZLE_CLEARANCE_FACTOR) \
			+ displacement.y


static func _damped_motion_cache() -> Dictionary:
	if _motion_cache.is_empty():
		_motion_cache = CannonBallistics.build_damped_motion_cache(
			LINEAR_DAMP,
			GRAVITY_Y,
			PHYSICS_STEP_SECONDS,
			MAXIMUM_STEPS
		)
	return _motion_cache
