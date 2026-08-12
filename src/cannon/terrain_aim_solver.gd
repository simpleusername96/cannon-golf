class_name TerrainAimSolver
extends RefCounted

## Inverts the fixed-step recurrence without collision queries. It builds one
## gravity baseline and nominates legal approximate aims immediately;
## exact physics prediction may later refine only the target presentation.
const TARGET_CONTACT_FACTOR := 0.5
const MAXIMUM_NOMINATIONS := 6
const BRANCH_SPLIT_ELEVATION_DEGREES := 45.0
const NOMINATION_STEP_STRIDE := 8
var _cannon: CannonController
var _target: TerrainAimTarget
var _constraint: StringName
var _requested_value := 0.0
var _branch: StringName
var _last_aim: AimTuple
var _step_index := 0
var _damping := 1.0
var _baseline_position := Vector3.ZERO
var _baseline_velocity := Vector3.ZERO
var _response := 0.0
var _candidates: Array[Dictionary] = []
var _seen: Dictionary = {}
var _complete := false


func _begin(cannon: CannonController, target: TerrainAimTarget, constraint: StringName,
		requested_value: float, branch: StringName, last_aim: AimTuple) -> void:
	_cannon = cannon
	_target = target
	_constraint = constraint
	_requested_value = requested_value
	_branch = branch
	_last_aim = last_aim
	_damping = maxf(1.0 - cannon.projectile_data.linear_damp * TrajectoryPredictionJob.PHYSICS_STEP, 0.0)
	_complete = _damping <= 0.0 or (constraint == &"elevation" and (requested_value < AimTuple.MINIMUM_ELEVATION_DEGREES or requested_value > AimTuple.MAXIMUM_ELEVATION_DEGREES)) or (constraint == &"power" and (requested_value < 0.0 or requested_value > 100.0))


func _advance_one() -> void:
	_response = _damping * (_response + TrajectoryPredictionJob.PHYSICS_STEP)
	_baseline_velocity *= _damping
	_baseline_velocity += _gravity_vector() * TrajectoryPredictionJob.PHYSICS_STEP
	_baseline_position += _baseline_velocity * TrajectoryPredictionJob.PHYSICS_STEP
	if _step_index % NOMINATION_STEP_STRIDE == NOMINATION_STEP_STRIDE - 1:
		_append_inverted_candidate(
			_candidates,
			_seen,
			_cannon,
			_target.world_point
					+ _target.world_normal * _cannon.projectile_data.radius,
			_baseline_position,
			_response,
			_constraint,
			_requested_value,
			_branch,
			_last_aim
		)
	_step_index += 1
	if _step_index >= TrajectoryPredictionJob.MAXIMUM_STEPS:
		_candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return _candidate_precedes(first, second, _branch, _last_aim))
		if _candidates.size() > MAXIMUM_NOMINATIONS:
			_candidates.resize(MAXIMUM_NOMINATIONS)
		_complete = true


static func nominate(cannon: CannonController, target: TerrainAimTarget,
		constraint: StringName, requested_value: float, branch: StringName,
		last_aim: AimTuple) -> Array[Dictionary]:
	if cannon == null or cannon.projectile_data == null or target == null:
		return []
	if constraint == &"elevation" and (requested_value < AimTuple.MINIMUM_ELEVATION_DEGREES \
			or requested_value > AimTuple.MAXIMUM_ELEVATION_DEGREES):
		return []
	if constraint == &"power" and (requested_value < AimTuple.MINIMUM_POWER_PERCENT \
			or requested_value > AimTuple.MAXIMUM_POWER_PERCENT):
		return []
	var request := TerrainAimSolver.new()
	request._begin(cannon, target, constraint, requested_value, branch, last_aim)
	while not request._complete:
		request._advance_one()
	return request._candidates


static func validates_target(prediction: TrajectoryPrediction, target: TerrainAimTarget,
		projectile_radius: float) -> bool:
	if prediction == null or target == null or prediction.kind != TrajectoryPrediction.Kind.COLLISION \
			or prediction.hit_identity == null:
		return false
	return prediction.hit_identity.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
		and prediction.collision_contact_point().distance_to(target.world_point) \
			<= projectile_radius * TARGET_CONTACT_FACTOR


static func _append_inverted_candidate(candidates: Array[Dictionary], seen: Dictionary,
		cannon: CannonController, desired: Vector3, baseline: Vector3, response: float,
		constraint: StringName, requested_value: float, branch: StringName, last_aim: AimTuple) -> void:
	var estimate_elevation := requested_value if constraint == &"elevation" else \
		(last_aim.elevation_degrees if last_aim != null else 38.0)
	var estimate_yaw := last_aim.yaw_degrees if last_aim != null else 0.0
	var required_velocity := Vector3.ZERO
	# Muzzle position depends on the derived direction. Refine against the shared
	# CannonBallistics origin before canonicalizing the candidate.
	for _iteration in range(2):
		var origin := cannon.get_launch_origin_for(estimate_yaw, estimate_elevation)
		required_velocity = (desired - origin - baseline) / response
		if required_velocity.length_squared() <= 0.0:
			return
		var horizontal := Vector2(required_velocity.x, required_velocity.z).length()
		estimate_yaw = rad_to_deg(atan2(required_velocity.x, -required_velocity.z))
		if constraint != &"elevation":
			estimate_elevation = rad_to_deg(atan2(required_velocity.y, horizontal))
	var required_speed := required_velocity.length()
	var power := (required_speed - cannon.projectile_data.minimum_launch_speed) * 100.0 \
		/ maxf(cannon.projectile_data.maximum_launch_speed - cannon.projectile_data.minimum_launch_speed, 0.000001)
	var aim: AimTuple
	if constraint == &"elevation":
		if power < AimTuple.MINIMUM_POWER_PERCENT or power > AimTuple.MAXIMUM_POWER_PERCENT:
			return
		aim = AimTuple.canonicalize(estimate_yaw, requested_value, power)
	elif constraint == &"power":
		if estimate_elevation < AimTuple.MINIMUM_ELEVATION_DEGREES \
				or estimate_elevation > AimTuple.MAXIMUM_ELEVATION_DEGREES:
			return
		aim = AimTuple.canonicalize(estimate_yaw, estimate_elevation, requested_value)
	else:
		if power < AimTuple.MINIMUM_POWER_PERCENT or power > AimTuple.MAXIMUM_POWER_PERCENT \
				or estimate_elevation < AimTuple.MINIMUM_ELEVATION_DEGREES \
				or estimate_elevation > AimTuple.MAXIMUM_ELEVATION_DEGREES:
			return
		aim = AimTuple.canonicalize(estimate_yaw, estimate_elevation, power)
	if aim == null or (constraint == &"elevation" and not is_equal_approx(aim.elevation_degrees, AimTuple.snap_angle(requested_value))):
		return
	if not _aim_matches_branch(aim, branch):
		return
	var key := aim.stable_key()
	if seen.has(key):
		return
	seen[key] = true
	var actual := CannonBallistics.launch_velocity(cannon.projectile_data, aim.yaw_degrees,
		aim.elevation_degrees, float(aim.power_percent))
	var error := (actual - required_velocity).length() * response
	candidates.append({"aim": aim, "miss": error})


static func _candidate_precedes(first: Dictionary, second: Dictionary, branch: StringName,
		last_aim: AimTuple) -> bool:
	var first_aim: AimTuple = first.aim
	var second_aim: AimTuple = second.aim
	if not is_equal_approx(float(first.miss), float(second.miss)):
		return float(first.miss) < float(second.miss)
	if last_aim != null and branch != &"":
		var first_distance := absf(first_aim.elevation_degrees - last_aim.elevation_degrees)
		var second_distance := absf(second_aim.elevation_degrees - last_aim.elevation_degrees)
		if not is_equal_approx(first_distance, second_distance):
			return first_distance < second_distance
	return String(first_aim.stable_key()) < String(second_aim.stable_key())


static func _aim_matches_branch(aim: AimTuple, branch: StringName) -> bool:
	if branch == &"low":
		return aim.elevation_degrees < BRANCH_SPLIT_ELEVATION_DEGREES
	if branch == &"high":
		return aim.elevation_degrees >= BRANCH_SPLIT_ELEVATION_DEGREES
	return true


static func _gravity_vector() -> Vector3:
	var magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var direction := Vector3(ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN))
	return direction.normalized() * magnitude
