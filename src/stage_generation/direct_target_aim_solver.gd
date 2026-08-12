extends RefCounted

## Bounded inverse solver for one terrain target. Physical parity remains in
## DirectReachabilityValidator; callers use its compatibility façade.

const TARGET_DISTANCE_TOLERANCE := 2.10
const MAXIMUM_PERPENDICULAR_MISS := 1.02
const ELEVATION_BISECTION_ITERATIONS := 12

static func solve_one_target(
		space_state: PhysicsDirectSpaceState3D,
		cannon: CannonController,
		layout: GeneratedStageLayout,
		stage_bounds: AABB,
		target_world_point: Vector3,
		target_world_normal: Vector3,
		target_sample: Dictionary,
		prefer_short_flight: bool = false
) -> Dictionary:
	if space_state == null or cannon == null or layout == null \
			or not target_world_point.is_finite() \
			or not target_world_normal.is_finite() or target_sample.is_empty():
		return {"valid": false, "rejection": &"invalid_single_target_input"}
	return _solve_target(
		space_state,
		cannon,
		layout,
		stage_bounds,
		target_world_point,
		target_world_normal,
		target_sample,
		{},
		_build_solver_cache(cannon),
		TARGET_DISTANCE_TOLERANCE,
		prefer_short_flight
	)


static func _solve_target(
		space_state: PhysicsDirectSpaceState3D,
		cannon: CannonController,
		layout: GeneratedStageLayout,
		stage_bounds: AABB,
		target_world_point: Vector3,
		target_world_normal: Vector3,
		target_sample: Dictionary,
		prediction_cache: Dictionary,
		solver_cache: Dictionary = {},
		maximum_distance: float = TARGET_DISTANCE_TOLERANCE,
		prefer_short_flight: bool = false
) -> Dictionary:
	if solver_cache.is_empty():
		solver_cache = _build_solver_cache(cannon)
	if solver_cache.is_empty():
		return {"valid": false, "rejection": &"invalid_ballistic_cache"}
	var nominations: Array[Dictionary] = []
	var nomination_by_key: Dictionary = {}
	# At 90 degrees the barrel's muzzle offset has no XZ component, exposing the
	# horizontal yaw pivot without depending on CannonController's private nodes.
	# Every legal muzzle offset is collinear with its yaw direction, so bearing
	# from this pivot is the exact nearest-yaw nomination reference.
	var reference_origin := cannon.get_launch_origin_for(0.0, 90.0)
	var reference_delta := Vector2(
		target_world_point.x - reference_origin.x,
		target_world_point.z - reference_origin.z
	)
	# Positive yaw is the aiming camera's screen-right direction and therefore
	# maps toward positive world X for the authored cannon/camera contract.
	var bearing := rad_to_deg(atan2(reference_delta.x, -reference_delta.y))
	var nearest_yaw := AimTuple.snap_angle(bearing)
	var desired_center := target_world_point \
			+ target_world_normal * cannon.projectile_data.radius
	for yaw in [nearest_yaw, nearest_yaw - 0.1, nearest_yaw + 0.1]:
		if yaw < AimTuple.MINIMUM_YAW_DEGREES or yaw > AimTuple.MAXIMUM_YAW_DEGREES:
			continue
		var horizontal_direction := Vector2(
			sin(deg_to_rad(yaw)),
			-cos(deg_to_rad(yaw))
		).normalized()
		var integer_origins := PackedVector3Array()
		for integer_elevation in range(
			ceili(AimTuple.MINIMUM_ELEVATION_DEGREES),
			floori(AimTuple.MAXIMUM_ELEVATION_DEGREES) + 1
		):
			integer_origins.append(cannon.get_launch_origin_for(yaw, float(integer_elevation)))
		for power in range(AimTuple.MINIMUM_POWER_PERCENT, AimTuple.MAXIMUM_POWER_PERCENT + 1):
			var has_previous := false
			var previous_height_error := 0.0
			var speed: float = solver_cache.speeds[power]
			for integer_elevation in range(
				ceili(AimTuple.MINIMUM_ELEVATION_DEGREES),
				floori(AimTuple.MAXIMUM_ELEVATION_DEGREES) + 1
			):
				var elevation_index := integer_elevation - ceili(AimTuple.MINIMUM_ELEVATION_DEGREES)
				var current := _collision_free_endpoint_values(
					integer_origins[elevation_index],
					horizontal_direction,
					speed * float(solver_cache.cosines[elevation_index]),
					speed * float(solver_cache.sines[elevation_index]),
					target_world_point,
					desired_center,
					solver_cache
				)
				if not is_finite(current.x):
					has_previous = false
					continue
				if is_zero_approx(current.x):
					_append_elevation_neighborhood(
						nominations,
						nomination_by_key,
						cannon,
						yaw,
						float(integer_elevation),
						power,
						target_world_point,
						target_world_normal,
						solver_cache
					)
				elif has_previous and signf(previous_height_error) != signf(current.x):
					var root_elevation := _bisect_elevation(
						cannon,
						yaw,
						float(integer_elevation - 1),
						float(integer_elevation),
						power,
						target_world_point,
						target_world_normal,
						solver_cache
					)
					_append_elevation_neighborhood(
						nominations,
						nomination_by_key,
						cannon,
						yaw,
						root_elevation,
						power,
						target_world_point,
						target_world_normal,
						solver_cache
					)
				has_previous = true
				previous_height_error = current.x

	nominations.sort_custom(
		_short_flight_nomination_precedes if prefer_short_flight else _nomination_precedes
	)
	var predictor_calls := 0
	var diagnostics := _new_prediction_diagnostics()
	for nomination in nominations:
		var aim: AimTuple = nomination.aim
		var key := aim.stable_key()
		var prediction: TrajectoryPrediction = prediction_cache.get(key)
		if prediction == null:
			prediction = TrajectoryPredictor.predict_motion(
				space_state,
				cannon.get_launch_origin_for(aim.yaw_degrees, aim.elevation_degrees),
				CannonBallistics.launch_velocity(
					cannon.projectile_data,
					aim.yaw_degrees,
					aim.elevation_degrees,
					float(aim.power_percent)
				),
				cannon.projectile_data.radius,
				cannon.projectile_data.linear_damp,
				stage_bounds,
				TrajectoryPredictor.COLLISION_MASK,
				false
			)
			prediction_cache[key] = prediction
			predictor_calls += 1
		_record_prediction_diagnostic(
			diagnostics,
			prediction,
			target_world_point,
			target_sample,
			aim
		)
		if not _prediction_witnesses_target(
				prediction,
				target_world_point,
				target_sample,
				maximum_distance
			):
			continue
		return {
			"valid": true,
			"aim": aim,
			"prediction": prediction,
			"range_margin": maxf(
				MAXIMUM_PERPENDICULAR_MISS - float(nomination.perpendicular_miss),
				0.0
			),
			"candidate_count": nominations.size(),
			"predictor_calls": predictor_calls,
		}
	return {
		"valid": false,
		"candidate_count": nominations.size(),
		"predictor_calls": predictor_calls,
		"diagnostics": _finalize_prediction_diagnostics(diagnostics),
	}


static func _collision_free_endpoint_error(
		cannon: CannonController,
		yaw_degrees: float,
		elevation_degrees: float,
		power_percent: int,
		target_world_point: Vector3,
		target_world_normal: Vector3,
		solver_cache: Dictionary = {}
) -> Dictionary:
	if solver_cache.is_empty():
		solver_cache = _build_solver_cache(cannon)
	if solver_cache.is_empty():
		return {}
	var origin := cannon.get_launch_origin_for(yaw_degrees, elevation_degrees)
	var direction := CannonBallistics.launch_direction(yaw_degrees, elevation_degrees)
	var horizontal_direction := Vector2(direction.x, direction.z).normalized()
	if horizontal_direction.is_zero_approx():
		return {}
	var delta_xz := Vector2(
		target_world_point.x - origin.x,
		target_world_point.z - origin.z
	)
	var projected_range := delta_xz.dot(horizontal_direction)
	var perpendicular_miss := absf(delta_xz.cross(horizontal_direction))
	if projected_range <= 0.0 or perpendicular_miss > MAXIMUM_PERPENDICULAR_MISS:
		return {}
	var speed := cannon.projectile_data.launch_speed(float(power_percent))
	var horizontal_speed := speed * cos(deg_to_rad(elevation_degrees))
	if horizontal_speed <= 0.000001:
		return {}
	var vertical_speed := speed * sin(deg_to_rad(elevation_degrees))
	return _collision_free_endpoint_error_from_components(
		origin,
		horizontal_direction,
		horizontal_speed,
		vertical_speed,
		target_world_point,
		target_world_normal,
		cannon.projectile_data.radius,
		solver_cache
	)


static func _collision_free_endpoint_error_from_components(
		origin: Vector3,
		horizontal_direction: Vector2,
		horizontal_speed: float,
		vertical_speed: float,
		target_world_point: Vector3,
		target_world_normal: Vector3,
		projectile_radius: float,
		solver_cache: Dictionary
) -> Dictionary:
	var desired_center := target_world_point + target_world_normal * projectile_radius
	var values := _collision_free_endpoint_values(
		origin,
		horizontal_direction,
		horizontal_speed,
		vertical_speed,
		target_world_point,
		desired_center,
		solver_cache
	)
	if not is_finite(values.x):
		return {}
	return {
		"height_error": values.x,
		"endpoint_error": values.y,
		"perpendicular_miss": values.z,
		"projected_range": values.w,
	}


static func _collision_free_endpoint_values(
		origin: Vector3,
		horizontal_direction: Vector2,
		horizontal_speed: float,
		vertical_speed: float,
		target_world_point: Vector3,
		desired_center: Vector3,
		solver_cache: Dictionary
) -> Vector4:
	var delta_xz := Vector2(
		target_world_point.x - origin.x,
		target_world_point.z - origin.z
	)
	var projected_range := delta_xz.dot(horizontal_direction)
	var perpendicular_miss := absf(delta_xz.cross(horizontal_direction))
	if projected_range <= 0.0 or perpendicular_miss > MAXIMUM_PERPENDICULAR_MISS \
			or horizontal_speed <= 0.000001:
		return Vector4(INF, INF, INF, INF)
	var relative := CannonBallistics.damped_position_at_horizontal_range(
		horizontal_speed,
		vertical_speed,
		projected_range,
		solver_cache
	)
	if relative == Vector2.INF:
		return Vector4(INF, INF, INF, INF)
	var endpoint := origin + Vector3(
		horizontal_direction.x * relative.x,
		relative.y,
		horizontal_direction.y * relative.x
	)
	return Vector4(
		endpoint.y - desired_center.y,
		endpoint.distance_to(desired_center),
		perpendicular_miss,
		projected_range
	)


static func _build_solver_cache(cannon: CannonController) -> Dictionary:
	var step := TrajectoryPredictor.PHYSICS_STEP
	var gravity_magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var gravity_direction := Vector3(ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector",
		Vector3.DOWN
	)).normalized()
	var gravity_y := gravity_direction.y * gravity_magnitude
	var cache := CannonBallistics.build_damped_motion_cache(
		cannon.projectile_data.linear_damp,
		gravity_y,
		step,
		TrajectoryPredictor.MAXIMUM_STEPS
	)
	if cache.is_empty():
		return {}
	var speeds := PackedFloat32Array()
	speeds.resize(AimTuple.MAXIMUM_POWER_PERCENT + 1)
	for power in range(AimTuple.MAXIMUM_POWER_PERCENT + 1):
		speeds[power] = cannon.projectile_data.launch_speed(float(power))
	var sines := PackedFloat32Array()
	var cosines := PackedFloat32Array()
	var elevation_count := floori(AimTuple.MAXIMUM_ELEVATION_DEGREES) \
			- ceili(AimTuple.MINIMUM_ELEVATION_DEGREES) + 1
	sines.resize(elevation_count)
	cosines.resize(elevation_count)
	for index in range(elevation_count):
		var elevation := float(ceili(AimTuple.MINIMUM_ELEVATION_DEGREES) + index)
		sines[index] = sin(deg_to_rad(elevation))
		cosines[index] = cos(deg_to_rad(elevation))
	cache["speeds"] = speeds
	cache["sines"] = sines
	cache["cosines"] = cosines
	return cache


static func _bisect_elevation(
		cannon: CannonController,
		yaw_degrees: float,
		lower_elevation: float,
		upper_elevation: float,
		power_percent: int,
		target_world_point: Vector3,
		target_world_normal: Vector3,
		solver_cache: Dictionary
) -> float:
	var lower := lower_elevation
	var upper := upper_elevation
	var lower_result := _collision_free_endpoint_error(
		cannon, yaw_degrees, lower, power_percent, target_world_point, target_world_normal,
		solver_cache
	)
	for _iteration in range(ELEVATION_BISECTION_ITERATIONS):
		var middle := (lower + upper) * 0.5
		var middle_result := _collision_free_endpoint_error(
			cannon, yaw_degrees, middle, power_percent, target_world_point, target_world_normal,
			solver_cache
		)
		if middle_result.is_empty():
			break
		if signf(float(lower_result.height_error)) == signf(float(middle_result.height_error)):
			lower = middle
			lower_result = middle_result
		else:
			upper = middle
	return (lower + upper) * 0.5


static func _append_elevation_neighborhood(
		nominations: Array[Dictionary],
		nomination_by_key: Dictionary,
		cannon: CannonController,
		yaw_degrees: float,
		root_elevation: float,
		power_percent: int,
		target_world_point: Vector3,
		target_world_normal: Vector3,
		solver_cache: Dictionary
) -> void:
	var nearest := AimTuple.snap_angle(root_elevation)
	for elevation in [nearest, nearest - 0.1, nearest + 0.1]:
		var aim := AimTuple.canonicalize(yaw_degrees, elevation, power_percent)
		if aim == null or not is_equal_approx(aim.elevation_degrees, elevation):
			continue
		var endpoint := _collision_free_endpoint_error(
			cannon,
			aim.yaw_degrees,
			aim.elevation_degrees,
			int(aim.power_percent),
			target_world_point,
			target_world_normal,
			solver_cache
		)
		if endpoint.is_empty():
			continue
		var key := aim.stable_key()
		var nomination := {
			"aim": aim,
			"endpoint_error": float(endpoint.endpoint_error),
			"perpendicular_miss": float(endpoint.perpendicular_miss),
			"flight_duration": _damped_duration_at_horizontal_range_cached(
				float(solver_cache.speeds[int(aim.power_percent)]) * cos(deg_to_rad(aim.elevation_degrees)),
				float(endpoint.projected_range),
				solver_cache
			),
		}
		if not nomination_by_key.has(key):
			nomination_by_key[key] = nominations.size()
			nominations.append(nomination)
		elif float(nomination.endpoint_error) < float(
			nominations[int(nomination_by_key[key])].endpoint_error
		):
			nominations[int(nomination_by_key[key])] = nomination


static func _nomination_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_aim: AimTuple = first.aim
	var second_aim: AimTuple = second.aim
	var first_key := [
		float(first.endpoint_error),
		absf(first_aim.yaw_degrees),
		first_aim.elevation_degrees,
		first_aim.power_percent,
		first_aim.yaw_degrees,
	]
	var second_key := [
		float(second.endpoint_error),
		absf(second_aim.yaw_degrees),
		second_aim.elevation_degrees,
		second_aim.power_percent,
		second_aim.yaw_degrees,
	]
	for index in range(first_key.size()):
		if first_key[index] < second_key[index]:
			return true
		if first_key[index] > second_key[index]:
			return false
	return false


static func _short_flight_nomination_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_duration := float(first.get("flight_duration", INF))
	var second_duration := float(second.get("flight_duration", INF))
	if not is_equal_approx(first_duration, second_duration):
		return first_duration < second_duration
	return _nomination_precedes(first, second)


static func _damped_duration_at_horizontal_range_cached(
		horizontal_speed: float,
		projected_range: float,
		solver_cache: Dictionary
) -> float:
	if horizontal_speed <= 0.000001 or projected_range <= 0.0:
		return INF
	var step: float = solver_cache.step
	var damping: float = solver_cache.damping
	if damping <= 0.0:
		return INF
	var step_count := 0
	if is_equal_approx(damping, 1.0):
		step_count = ceili(projected_range / maxf(horizontal_speed * step, 0.000001))
	else:
		var asymptotic_range := horizontal_speed * float(solver_cache.asymptotic_factor)
		if projected_range >= asymptotic_range:
			return INF
		var remaining_ratio := 1.0 - projected_range / asymptotic_range
		step_count = ceili(log(remaining_ratio) / float(solver_cache.log_damping))
	return float(clampi(step_count, 1, TrajectoryPredictor.MAXIMUM_STEPS)) * step


static func _prediction_witnesses_target(
	prediction: TrajectoryPrediction,
	target_world_point: Vector3,
	target_sample: Dictionary,
	maximum_distance: float = TARGET_DISTANCE_TOLERANCE
) -> bool:
	if prediction == null or prediction.kind != TrajectoryPrediction.Kind.COLLISION \
			or prediction.hit_identity == null:
		return false
	var identity := prediction.hit_identity
	return identity.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			and not target_sample.is_empty() \
			and prediction.collision_contact_point().distance_to(target_world_point) \
					<= maximum_distance


static func _new_prediction_diagnostics() -> Dictionary:
	return {
		"kind_counts": {
			"collision": 0,
			"bounds_exit": 0,
			"timeout": 0,
			"missing": 0,
		},
		"owner_shape_counts": {},
		"terrain_address_counts": {
			"same_triangle": 0,
			"same_cell_wrong_triangle": 0,
			"wrong_cell": 0,
			"invalid_identity": 0,
		},
		"minimum_same_triangle_distance": INF,
		"minimum_terrain_top_distance": INF,
		"nearest_same_triangle_aim": &"",
		"nearest_terrain_top_aim": &"",
	}


static func _record_prediction_diagnostic(
		diagnostics: Dictionary,
		prediction: TrajectoryPrediction,
		target_world_point: Vector3,
		target_sample: Dictionary,
		aim: AimTuple
) -> void:
	var kind_counts: Dictionary = diagnostics.kind_counts
	if prediction == null:
		kind_counts["missing"] = int(kind_counts.missing) + 1
		return
	match prediction.kind:
		TrajectoryPrediction.Kind.COLLISION:
			kind_counts["collision"] = int(kind_counts.collision) + 1
		TrajectoryPrediction.Kind.BOUNDS_EXIT:
			kind_counts["bounds_exit"] = int(kind_counts.bounds_exit) + 1
		TrajectoryPrediction.Kind.TIMEOUT:
			kind_counts["timeout"] = int(kind_counts.timeout) + 1
	if prediction.kind != TrajectoryPrediction.Kind.COLLISION:
		return
	var identity := prediction.hit_identity
	var owner_shape_counts: Dictionary = diagnostics.owner_shape_counts
	if identity == null:
		owner_shape_counts["<invalid>"] = int(owner_shape_counts.get("<invalid>", 0)) + 1
		return
	var owner_shape_key := "%s|%s" % [identity.contact_owner_id, identity.contact_shape_id]
	owner_shape_counts[owner_shape_key] = int(owner_shape_counts.get(owner_shape_key, 0)) + 1
	if identity.contact_owner_id != TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
		return
	var distance := prediction.collision_contact_point().distance_to(target_world_point)
	if distance < float(diagnostics.minimum_terrain_top_distance):
		diagnostics.minimum_terrain_top_distance = distance
		diagnostics.nearest_terrain_top_aim = aim.stable_key()
	var address_counts: Dictionary = diagnostics.terrain_address_counts
	if identity.terrain_cell != target_sample.cell:
		address_counts["wrong_cell"] = int(address_counts.wrong_cell) + 1
		return
	if identity.terrain_triangle != int(target_sample.triangle):
		address_counts["same_cell_wrong_triangle"] = int(
			address_counts.same_cell_wrong_triangle
		) + 1
		return
	address_counts["same_triangle"] = int(address_counts.same_triangle) + 1
	if distance < float(diagnostics.minimum_same_triangle_distance):
		diagnostics.minimum_same_triangle_distance = distance
		diagnostics.nearest_same_triangle_aim = aim.stable_key()


static func _finalize_prediction_diagnostics(diagnostics: Dictionary) -> Dictionary:
	if not is_finite(float(diagnostics.minimum_same_triangle_distance)):
		diagnostics.minimum_same_triangle_distance = -1.0
	if not is_finite(float(diagnostics.minimum_terrain_top_distance)):
		diagnostics.minimum_terrain_top_distance = -1.0
	return diagnostics
