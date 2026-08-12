class_name TrajectoryPredictor
extends RefCounted

const PHYSICS_STEP := TrajectoryPredictionJob.PHYSICS_STEP
const MAXIMUM_STEPS := TrajectoryPredictionJob.MAXIMUM_STEPS
const COLLISION_MASK := TrajectoryPredictionJob.COLLISION_MASK


static func predict(
		space_state: PhysicsDirectSpaceState3D,
		cannon: CannonController,
		stage_bounds: AABB
) -> TrajectoryPrediction:
	return predict_motion(
		space_state,
		cannon.get_launch_origin(),
		cannon.get_launch_velocity(),
		cannon.projectile_data.radius,
		cannon.projectile_data.linear_damp,
		stage_bounds,
		COLLISION_MASK,
		true
	)


static func predict_motion(
		space_state: PhysicsDirectSpaceState3D,
		origin: Vector3,
		launch_velocity: Vector3,
		projectile_radius: float,
		linear_damp: float,
		stage_bounds: AABB,
		collision_mask: int = COLLISION_MASK,
		capture_sampled_points: bool = true
) -> TrajectoryPrediction:
	var job := TrajectoryPredictionJob.create(
		space_state,
		origin,
		launch_velocity,
		projectile_radius,
		linear_damp,
		stage_bounds,
		collision_mask,
		capture_sampled_points
	)
	while not job.is_complete():
		job.advance(MAXIMUM_STEPS)
	return job.completed_prediction()
