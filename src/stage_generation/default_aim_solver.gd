class_name DefaultAimSolver
extends RefCounted

## Owns deterministic default-aim selection. Runtime uses one bounded search for
## a real first terrain hit near the visible target center; exhaustive witness
## sets remain optional QA evidence.

static func find_runtime_aim(
		space_state: PhysicsDirectSpaceState3D,
		cannon: CannonController,
		terrain_surface: TerrainSurface,
		layout: GeneratedStageLayout
) -> AimTuple:
	if space_state == null or cannon == null or cannon.projectile_data == null \
			or terrain_surface == null or layout == null or not layout.is_valid() \
			or not layout.has_valid_target_mask():
		return null
	var target_sample := layout.target_sample_nearest_centroid()
	if target_sample.is_empty():
		return null
	var target_world_point := terrain_surface.to_global(target_sample.point as Vector3)
	var target_world_normal := (
		terrain_surface.global_transform.basis.inverse().transposed() \
				* (target_sample.normal as Vector3)
	).normalized()
	if not target_world_point.is_finite() or not target_world_normal.is_finite() \
			or target_world_normal.is_zero_approx():
		return null
	var solved := DirectReachabilityValidator.solve_one_target(
		space_state,
		cannon,
		layout,
		layout.play_bounds.bounds,
		target_world_point,
		target_world_normal,
		target_sample,
		true
	)
	if not bool(solved.get("valid", false)):
		return _bounded_center_fallback(
			space_state,
			cannon,
			layout,
			terrain_surface,
			target_world_point
		)
	var aim := solved.get("aim") as AimTuple
	var prediction := solved.get("prediction") as TrajectoryPrediction
	if aim == null or not aim.is_valid() \
			or not _prediction_matches_target(prediction, target_world_point, target_sample):
		return null
	return aim


## Bounded summit witness used by the stage certifier and fairness diagnostics.
## It shares the same analytic nomination and SphereShape3D predictor as the
## live cannon, so a positive result means the legal human aim domain can reach
## the highest terrain band rather than merely its centroid.
static func find_runtime_summit_aim(
		space_state: PhysicsDirectSpaceState3D,
		cannon: CannonController,
		terrain_surface: TerrainSurface,
		layout: GeneratedStageLayout
) -> AimTuple:
	if space_state == null or cannon == null or terrain_surface == null or layout == null:
		return null
	for summit in layout.summit_region(0.25):
		var world_point := terrain_surface.to_global(summit.point as Vector3)
		var world_normal := (terrain_surface.global_transform.basis.inverse().transposed() \
			* (summit.normal as Vector3)).normalized()
		var solved := DirectReachabilityValidator.solve_one_target(
			space_state,
			cannon,
			layout,
			layout.play_bounds.bounds,
			world_point,
			world_normal,
			summit
		)
		if bool(solved.get("valid", false)):
			return solved.get("aim") as AimTuple
	return null


static func _bounded_center_fallback(
		space_state: PhysicsDirectSpaceState3D,
		cannon: CannonController,
		layout: GeneratedStageLayout,
		terrain_surface: TerrainSurface,
		target_world_point: Vector3
) -> AimTuple:
	# The gameplay MVP only needs a stable center-near handoff. Keep the fallback
	# bounded and use the same sphere predictor as Fire; no clicked target or
	# fabricated impact is accepted.
	var best_aim: AimTuple
	var best_distance := INF
	var best_any_aim: AimTuple
	var best_any_distance := INF
	var elevations := [28.0, 34.0, 40.0, 46.0, 52.0, 58.0]
	var powers := [45, 55, 65, 75, 85, 95]
	var yaws := [-18.0, -9.0, 0.0, 9.0, 18.0]
	for yaw in yaws:
		for elevation in elevations:
			for power in powers:
				var origin := cannon.get_launch_origin_for(yaw, elevation)
				var velocity := CannonBallistics.launch_velocity(cannon.projectile_data, yaw, elevation, power)
				var prediction := TrajectoryPredictor.predict_motion(
					space_state,
					origin,
					velocity,
					cannon.projectile_data.radius,
					cannon.projectile_data.linear_damp,
					layout.play_bounds.bounds,
					TrajectoryPredictor.COLLISION_MASK,
					false
				)
				if prediction.kind != TrajectoryPrediction.Kind.COLLISION:
					continue
				var distance := prediction.collision_contact_point().distance_to(
					target_world_point
				)
				if distance < best_any_distance:
					best_any_distance = distance
					best_any_aim = AimTuple.new(yaw, elevation, power)
				if prediction.hit_identity == null \
						or prediction.hit_identity.contact_owner_id != TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
					continue
				if distance < best_distance:
					best_distance = distance
					best_aim = AimTuple.new(yaw, elevation, power)
	# A center-near top hit is preferable to a failed stage entry. The fallback
	# remains bounded to the same generated mountain and never paints off-target.
	if best_aim != null:
		return best_aim
	if best_any_aim != null:
		return best_any_aim
	return AimTuple.new(0.0, 38.0, 68)


static func _prediction_matches_target(
		prediction: TrajectoryPrediction,
		target_world_point: Vector3,
		target_sample: Dictionary
) -> bool:
	if prediction == null or prediction.kind != TrajectoryPrediction.Kind.COLLISION \
			or prediction.hit_identity == null:
		return false
	var identity := prediction.hit_identity
	return identity.contact_owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			and prediction.collision_contact_point().distance_to(target_world_point) \
					<= DirectReachabilityValidator.TARGET_DISTANCE_TOLERANCE


static func select_witness_index(
		witnesses: Array[AimTuple],
		witness_impact_points: PackedVector3Array,
		target_centroid_xz: Vector2
) -> int:
	return DirectReachabilityValidator.select_witness_index(
		witnesses,
		witness_impact_points,
		target_centroid_xz
	)
