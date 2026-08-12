class_name CannonBallistics
extends RefCounted

const GAMEPLAY_PACE := preload("res://src/gameplay/gameplay_pace.gd")

## These offsets are the fixed cannon geometry contract used by both the scene
## controller and generation-time ballistic admission. Keep cannon.tscn aligned
## with them; CannonController asserts that alignment when it becomes ready.
const YAW_PIVOT_OFFSET := Vector3(0.0, 0.75, -0.1)
const ELEVATION_PIVOT_OFFSET := Vector3.ZERO
const MUZZLE_OFFSET := Vector3(0.0, 0.0, -3.45)
const PLATFORM_Y_BELOW_CANNON_ROOT := -0.125
const PROJECTILE_PLATFORM_CLEARANCE := 0.01


static func launch_direction(yaw_degrees: float, elevation_degrees: float) -> Vector3:
	var yaw := deg_to_rad(yaw_degrees)
	var elevation := deg_to_rad(elevation_degrees)
	var horizontal_scale := cos(elevation)
	# Positive yaw is defined in player space: it moves the aiming-camera landing
	# point toward screen right. The visual pivot therefore rotates by the
	# opposite Godot Y angle; solver, preview, and rigid-body launch share this
	# player-facing convention.
	return Vector3(
		sin(yaw) * horizontal_scale,
		sin(elevation),
		-cos(yaw) * horizontal_scale
	).normalized()


static func launch_velocity(
		projectile_data: ProjectileData,
		yaw_degrees: float,
		elevation_degrees: float,
		power_percent: float
) -> Vector3:
	return launch_direction(yaw_degrees, elevation_degrees) * projectile_data.launch_speed(power_percent)


static func launch_origin_local(yaw_degrees: float, elevation_degrees: float) -> Vector3:
	var yaw_basis := Basis(Vector3.UP, -deg_to_rad(yaw_degrees))
	var elevation_basis := Basis(Vector3.RIGHT, deg_to_rad(elevation_degrees))
	return YAW_PIVOT_OFFSET + yaw_basis * (
		ELEVATION_PIVOT_OFFSET + elevation_basis * MUZZLE_OFFSET
	)


static func launch_origin_for_transform(
		cannon_transform: Transform3D,
		yaw_degrees: float,
		elevation_degrees: float
) -> Vector3:
	return cannon_transform * launch_origin_local(yaw_degrees, elevation_degrees)


## Places the projectile centre one physical radius beyond the visible muzzle,
## then applies only the vertical lift needed to clear the cannon platform. This
## preserves one shared origin for solver, preview, and rigid body.
static func projectile_launch_origin_local(
		yaw_degrees: float,
		elevation_degrees: float,
		projectile_radius: float
) -> Vector3:
	var origin := launch_origin_local(yaw_degrees, elevation_degrees) \
			+ launch_direction(yaw_degrees, elevation_degrees) \
			* maxf(projectile_radius, 0.0)
	origin.y = maxf(
		origin.y,
		PLATFORM_Y_BELOW_CANNON_ROOT + maxf(projectile_radius, 0.0) \
				+ PROJECTILE_PLATFORM_CLEARANCE
	)
	return origin


static func projectile_launch_origin_for_transform(
		cannon_transform: Transform3D,
		yaw_degrees: float,
		elevation_degrees: float,
		projectile_radius: float
) -> Vector3:
	return cannon_transform * projectile_launch_origin_local(
		yaw_degrees,
		elevation_degrees,
		projectile_radius
	)


## Builds the exact discrete recurrence used by TrajectoryPredictor without
## creating physics or scene objects. Callers may add their own lookup tables to
## the returned dictionary, but must not mutate the packed recurrence arrays.
static func build_damped_motion_cache(
		linear_damp: float,
		gravity_y: float,
		step_seconds: float,
		maximum_steps: int
) -> Dictionary:
	if linear_damp < 0.0 or not is_finite(gravity_y) or step_seconds <= 0.0 \
			or maximum_steps <= 0:
		return {}
	var damping := maxf(1.0 - linear_damp * step_seconds, 0.0)
	if damping <= 0.0:
		return {}
	var horizontal_factors := PackedFloat64Array()
	var gravity_offsets := PackedFloat64Array()
	horizontal_factors.resize(maximum_steps + 1)
	gravity_offsets.resize(maximum_steps + 1)
	for step_count in range(1, maximum_steps + 1):
		if is_equal_approx(damping, 1.0):
			horizontal_factors[step_count] = step_seconds * float(step_count)
			gravity_offsets[step_count] = gravity_y * step_seconds * step_seconds \
					* float(step_count * (step_count + 1)) * 0.5
		else:
			var damping_sum := damping * (1.0 - pow(damping, step_count)) \
					/ (1.0 - damping)
			horizontal_factors[step_count] = step_seconds * damping_sum
			gravity_offsets[step_count] = step_seconds * gravity_y * step_seconds \
					/ (1.0 - damping) * (float(step_count) - damping_sum)
	return {
		"step": step_seconds,
		"maximum_steps": maximum_steps,
		"damping": damping,
		"log_damping": log(damping) if not is_equal_approx(damping, 1.0) else 0.0,
		"asymptotic_factor": step_seconds * damping / (1.0 - damping) \
				if not is_equal_approx(damping, 1.0) else INF,
		"horizontal_factors": horizontal_factors,
		"gravity_offsets": gravity_offsets,
	}


## Returns horizontal and vertical displacement at the first fixed-step segment
## that crosses projected_range. The interpolation matches the predictor's
## discrete damp-then-gravity-then-position order.
static func damped_position_at_horizontal_range(
		horizontal_speed: float,
		vertical_speed: float,
		projected_range: float,
		motion_cache: Dictionary
) -> Vector2:
	if horizontal_speed <= 0.000001 or projected_range <= 0.0 \
			or motion_cache.is_empty():
		return Vector2.INF
	var step := float(motion_cache.get("step", 0.0))
	var damping := float(motion_cache.get("damping", 0.0))
	var maximum_steps := int(motion_cache.get("maximum_steps", 0))
	if step <= 0.0 or damping <= 0.0 or maximum_steps <= 0:
		return Vector2.INF
	var step_count := 0
	if is_equal_approx(damping, 1.0):
		step_count = ceili(projected_range / maxf(horizontal_speed * step, 0.000001))
	else:
		var asymptotic_range := horizontal_speed \
				* float(motion_cache.get("asymptotic_factor", 0.0))
		if projected_range >= asymptotic_range:
			return Vector2.INF
		var remaining_ratio := 1.0 - projected_range / asymptotic_range
		step_count = ceili(log(remaining_ratio) / float(motion_cache.get("log_damping", 0.0)))
	step_count = clampi(step_count, 1, maximum_steps)
	var horizontal_factors: PackedFloat64Array = motion_cache.get(
		"horizontal_factors", PackedFloat64Array()
	)
	var gravity_offsets: PackedFloat64Array = motion_cache.get(
		"gravity_offsets", PackedFloat64Array()
	)
	if horizontal_factors.size() <= step_count or gravity_offsets.size() <= step_count:
		return Vector2.INF
	var previous := Vector2(
		horizontal_speed * horizontal_factors[step_count - 1],
		vertical_speed * horizontal_factors[step_count - 1] \
				+ gravity_offsets[step_count - 1]
	)
	var current := Vector2(
		horizontal_speed * horizontal_factors[step_count],
		vertical_speed * horizontal_factors[step_count] + gravity_offsets[step_count]
	)
	if current.x + 0.000001 < projected_range:
		return Vector2.INF
	var fraction := clampf(
		(projected_range - previous.x) / maxf(current.x - previous.x, 0.000001),
		0.0,
		1.0
	)
	return previous.lerp(current, fraction)


static func sample_unobstructed(
		origin: Vector3,
		velocity: Vector3,
		gravity: Vector3,
		step_seconds: float,
		maximum_seconds: float,
		linear_damp: float = 0.0
) -> PackedVector3Array:
	if linear_damp > 0.0:
		return _sample_damped(origin, velocity, gravity, step_seconds, maximum_seconds, linear_damp)
	var samples := PackedVector3Array([origin])
	var elapsed := step_seconds
	while elapsed <= maximum_seconds + 0.0001:
		samples.append(origin + velocity * elapsed + 0.5 * gravity * elapsed * elapsed)
		elapsed += step_seconds
	return samples


static func _sample_damped(
		origin: Vector3,
		velocity: Vector3,
		gravity: Vector3,
		sample_step: float,
		maximum_seconds: float,
		linear_damp: float
) -> PackedVector3Array:
	var physics_step := GAMEPLAY_PACE.ACTIVE_SIMULATION_STEP_SECONDS
	var samples := PackedVector3Array([origin])
	var position := origin
	var elapsed := 0.0
	var next_sample := sample_step
	while elapsed < maximum_seconds - 0.0001:
		var delta := minf(physics_step, maximum_seconds - elapsed)
		velocity *= maxf(0.0, 1.0 - linear_damp * delta)
		velocity += gravity * delta
		position += velocity * delta
		elapsed += delta
		if elapsed + 0.0001 >= next_sample:
			samples.append(position)
			next_sample += sample_step
	return samples
