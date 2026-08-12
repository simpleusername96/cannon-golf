extends SceneTree

const PROJECTILE_DATA: ProjectileData = preload(
	"res://resources/projectiles/basic_paintball.tres"
)

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	Engine.physics_ticks_per_second = 60
	var stage := StageCatalog.get_stage(&"stage_01")
	_assert_true(stage != null, "Stage 01 must exist")
	if stage == null:
		quit(1)
		return
	var constraint := ProjectileRangeConstraint.new(stage, PROJECTILE_DATA)
	_assert_true(
		constraint.is_valid(),
		"the canonical projectile domain must configure: %s" \
				% constraint.configuration_rejection()
	)
	var rotated_stage := stage.duplicate(true) as StageData
	rotated_stage.cannon_transform.basis = Basis(Vector3.UP, deg_to_rad(15.0))
	var rotated_constraint := ProjectileRangeConstraint.new(rotated_stage, PROJECTILE_DATA)
	_assert_true(
		not rotated_constraint.is_valid() \
				and rotated_constraint.configuration_rejection() == &"unsupported_cannon_basis",
		"range admission must fail closed when visual-root rotation would disagree with launch velocity"
	)
	var legal_surface := _surface_from_legal_flight(stage, 0.0, 36.0, 100.0, 90)
	_assert_shared_recurrence(stage, legal_surface, 0.0, 36.0, 100.0)
	var legal := constraint.evaluate_world_surface(legal_surface, Vector3.UP, false)
	_assert_true(
		bool(legal.get("valid", false)),
		"a surface centered on a legal unobstructed trajectory must be in range: %s" % legal
	)
	var reference := CannonBallistics.projectile_launch_origin_for_transform(
		stage.cannon_transform,
		0.0,
		90.0,
		PROJECTILE_DATA.radius
	)
	var outside_yaw_direction := CannonBallistics.launch_direction(100.0, 10.0)
	var outside_yaw_surface := reference + Vector3(
		outside_yaw_direction.x * 100.0,
		0.0,
		outside_yaw_direction.z * 100.0
	)
	var outside_yaw := constraint.evaluate_world_surface(
		outside_yaw_surface,
		Vector3.UP,
		false
	)
	_assert_true(
		not bool(outside_yaw.get("valid", true)) \
				and outside_yaw.get("rejection", &"") == &"yaw",
		"a surface outside the legal yaw fan must fail the range gate: %s" % outside_yaw
	)
	var beyond_horizon := constraint.evaluate_world_surface(
		reference + Vector3(0.0, -PROJECTILE_DATA.radius, -500.0),
		Vector3.UP,
		false
	)
	_assert_true(
		not bool(beyond_horizon.get("valid", true)) \
				and beyond_horizon.get("rejection", &"") == &"horizontal_range",
		"a surface beyond the damped fixed-step horizon must fail: %s" % beyond_horizon
	)
	var above_envelope := constraint.evaluate_world_surface(
		reference + Vector3(0.0, 500.0, -100.0),
		Vector3.UP,
		false
	)
	_assert_true(
		not bool(above_envelope.get("valid", true)) \
				and above_envelope.get("rejection", &"") == &"height_above",
		"a surface above every legal trajectory must fail: %s" % above_envelope
	)
	var below_envelope := constraint.evaluate_world_surface(
		reference + Vector3(0.0, -500.0, -100.0),
		Vector3.UP,
		false
	)
	_assert_true(
		not bool(below_envelope.get("valid", true)) \
				and below_envelope.get("rejection", &"") == &"height_below",
		"a surface below every legal trajectory must fail: %s" % below_envelope
	)
	var stage_one_layout: GeneratedStageLayout
	for stage_id in [&"stage_01", &"stage_30"]:
		var generated_stage := StageCatalog.get_stage(stage_id)
		var started_at := Time.get_ticks_msec()
		var layout := SeededStageGenerator.generate(
			generated_stage.generation_profile,
			generated_stage.terrain_seed,
			generated_stage
		)
		print("%s ballistic generation elapsed_ms=%d" % [
			stage_id,
			Time.get_ticks_msec() - started_at,
		])
		_assert_true(layout != null, "%s must pass generation-time range admission" % stage_id)
		if layout == null:
			continue
		if stage_id == &"stage_01":
			stage_one_layout = layout
			_assert_configured_target_shoulder_is_scoreable(
				layout,
				generated_stage.generation_profile.generation_contract
			)
		_assert_true(
			int(layout.metrics.get("ballistic_target_count", -1)) \
					== layout.target_pixel_count(),
			"%s must check every scoreable target sample" % stage_id
		)
		_assert_true(
			int(layout.metrics.get("ballistic_summit_triangle_id", -1)) >= 0,
			"%s must admit at least one canonical summit sample" % stage_id
		)
		_assert_true(
			float(layout.metrics.get("ballistic_minimum_range_margin", -INF)) >= 0.0,
			"%s must retain a non-negative horizontal range margin" % stage_id
		)
		_assert_true(
			float(layout.metrics.get("ballistic_minimum_height_margin", -INF)) >= 0.0,
			"%s must retain a non-negative reachable-height margin" % stage_id
		)
		var baked := load(StageCatalog.get_layout_path(stage_id)) as BakedStageLayoutData
		var accepted_layout := StageLayoutBakeCodec.hydrate(baked, generated_stage) \
				if baked != null else null
		var runtime_copy := accepted_layout.copy_for_runtime() \
				if accepted_layout != null else null
		_assert_true(
			runtime_copy != null and runtime_copy.matches_stage_identity(generated_stage),
			"%s runtime copy must preserve accepted layout identity" % stage_id
		)
		if runtime_copy != null:
			var cached_default_aim := accepted_layout.generated_default_aim
			runtime_copy.metrics["runtime_copy_probe"] = true
			runtime_copy.generated_default_aim = AimTuple.new(0.0, 38.0, 68)
			_assert_true(
				not accepted_layout.metrics.has("runtime_copy_probe") \
						and accepted_layout.generated_default_aim == cached_default_aim,
				"%s runtime annotations must not mutate the prepared cache source" % stage_id
			)
	_assert_raster_rejects_out_of_range_stage(stage, stage_one_layout)
	if not _failed:
		print("Projectile range constraint checks passed without scene or physics-world use.")
	quit(1 if _failed else 0)


func _assert_configured_target_shoulder_is_scoreable(
		layout: GeneratedStageLayout,
		contract: StageGenerationContract
) -> void:
	var mask_size := contract.mask_size
	for pixel_y in range(mask_size):
		for pixel_x in range(mask_size):
			var pixel_index := pixel_y * mask_size + pixel_x
			if layout.target_mask[pixel_index] < 128:
				continue
			var local_xz := Vector2(
				lerpf(
					contract.local_bounds.position.x,
					contract.local_bounds.end.x,
					(float(pixel_x) + 0.5) / float(mask_size)
				),
				lerpf(
					contract.local_bounds.position.y,
					contract.local_bounds.end.y,
					(float(pixel_y) + 0.5) / float(mask_size)
				)
			)
			var nearest := layout.route_graph.nearest_edge(local_xz)
			var edge := nearest.get("edge") as GeneratedRouteEdge
			if edge == null:
				continue
			var distance := float(nearest.get("distance", INF))
			var core_radius := edge.width * 0.5
			if distance > core_radius + contract.bank_blend_distance + 0.05 \
					and distance <= core_radius + contract.target_shoulder_distance + 0.05:
				return
	_assert_true(
		false,
		"the configured target shoulder must stay scoreable; range failures reject the candidate instead"
	)


func _assert_raster_rejects_out_of_range_stage(
		stage: StageData,
		layout: GeneratedStageLayout
) -> void:
	if layout == null:
		return
	var displaced_stage := stage.duplicate(true) as StageData
	displaced_stage.cannon_transform.origin += Vector3(500.0, 0.0, 0.0)
	var displaced_constraint := ProjectileRangeConstraint.new(
		displaced_stage,
		PROJECTILE_DATA
	)
	var result := TargetMaskRasterizer.build(
		layout.route_graph,
		layout.top_topology,
		stage.generation_profile.generation_contract,
		stage.generation_profile,
		displaced_constraint
	)
	_assert_true(
		not bool(result.get("valid", true)) \
				and result.get("rejection", "") == "projectile_range" \
				and result.has("ballistic_failure_pixel"),
		"target rasterization must reject the whole candidate at the first out-of-range sample"
	)


func _assert_shared_recurrence(
		stage: StageData,
		flight_surface: Vector3,
		yaw_degrees: float,
		elevation_degrees: float,
		power_percent: float
) -> void:
	var origin := CannonBallistics.projectile_launch_origin_for_transform(
		stage.cannon_transform,
		yaw_degrees,
		elevation_degrees,
		PROJECTILE_DATA.radius
	)
	var endpoint_center := flight_surface + Vector3.UP * PROJECTILE_DATA.radius
	var horizontal_direction_3d := CannonBallistics.launch_direction(
		yaw_degrees,
		elevation_degrees
	)
	var horizontal_direction := Vector2(
		horizontal_direction_3d.x,
		horizontal_direction_3d.z
	).normalized()
	var horizontal_delta := Vector2(
		endpoint_center.x - origin.x,
		endpoint_center.z - origin.z
	)
	var speed := PROJECTILE_DATA.launch_speed(power_percent)
	var gravity_magnitude := float(ProjectSettings.get_setting(
		"physics/3d/default_gravity",
		9.8
	))
	var cache := CannonBallistics.build_damped_motion_cache(
		PROJECTILE_DATA.linear_damp,
		-gravity_magnitude,
		TrajectoryPredictor.PHYSICS_STEP,
		TrajectoryPredictor.MAXIMUM_STEPS
	)
	var relative := CannonBallistics.damped_position_at_horizontal_range(
		speed * cos(deg_to_rad(elevation_degrees)),
		speed * sin(deg_to_rad(elevation_degrees)),
		horizontal_delta.dot(horizontal_direction),
		cache
	)
	_assert_true(
		relative != Vector2.INF \
				and absf(relative.y - (endpoint_center.y - origin.y)) <= 0.001,
		"the shared analytic recurrence must match direct fixed-step simulation"
	)


func _surface_from_legal_flight(
		stage: StageData,
		yaw_degrees: float,
		elevation_degrees: float,
		power_percent: float,
		step_count: int
) -> Vector3:
	var position := CannonBallistics.projectile_launch_origin_for_transform(
		stage.cannon_transform,
		yaw_degrees,
		elevation_degrees,
		PROJECTILE_DATA.radius
	)
	var velocity := CannonBallistics.launch_velocity(
		PROJECTILE_DATA,
		yaw_degrees,
		elevation_degrees,
		power_percent
	)
	var gravity_magnitude := float(ProjectSettings.get_setting(
		"physics/3d/default_gravity",
		9.8
	))
	for _step_index in range(step_count):
		velocity *= maxf(
			1.0 - PROJECTILE_DATA.linear_damp * TrajectoryPredictor.PHYSICS_STEP,
			0.0
		)
		velocity += Vector3.DOWN * gravity_magnitude * TrajectoryPredictor.PHYSICS_STEP
		position += velocity * TrajectoryPredictor.PHYSICS_STEP
	return position - Vector3.UP * PROJECTILE_DATA.radius


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Projectile-range check failed: %s" % message)
