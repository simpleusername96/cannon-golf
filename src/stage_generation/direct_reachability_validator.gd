class_name DirectReachabilityValidator
extends RefCounted

## Bounded offline entry-witness solver and real-body parity validator for one
## materialized layout. Its witnesses are never exposed as player auto-aim.

# A witness is accepted when its first top-surface contact lands within the
# bounded entry-sample tolerance. Requiring the exact sampled triangle would
# reject legitimate adjacent-facet contacts; this solver tolerance is separate
# from the current runtime paint footprint radius.
const TARGET_AIM_SOLVER := preload(
	"res://src/stage_generation/direct_target_aim_solver.gd"
)
const TARGET_DISTANCE_TOLERANCE := TARGET_AIM_SOLVER.TARGET_DISTANCE_TOLERANCE
const RIGIDBODY_IDENTITY_DISTANCE_TOLERANCE := \
		StageEntryAimWitness.TERRAIN_FACET_PARITY_TOLERANCE
const RIGIDBODY_TARGET_RADIUS_CLEARANCE := 0.10
# Certification bodies use layer 2 and never collide with one another; a
# wider offline batch keeps the real-body parity proof bounded without changing
# gameplay physics or the witness semantics.
const RIGIDBODY_BATCH_SIZE := 256
const WITNESS_SPATIAL_BUCKET_METERS := TARGET_DISTANCE_TOLERANCE
const CHECKSUM_OFFSET := 2166136261
const CHECKSUM_PRIME := 16777619
const DEFAULT_PAINT_SURFACE_TUNING := preload(
	"res://resources/paint/default_paint_surface_tuning.tres"
)


static func select_witness_index(
		witnesses: Array[AimTuple],
		witness_impact_points: PackedVector3Array,
		target_centroid_xz: Vector2
) -> int:
	if witnesses.is_empty() or witnesses.size() != witness_impact_points.size() \
			or not target_centroid_xz.is_finite():
		return -1
	var best_index := -1
	var best_distance_squared := INF
	for index in range(witnesses.size()):
		var witness := witnesses[index]
		var impact := witness_impact_points[index]
		if witness == null or not witness.is_valid() or not impact.is_finite():
			return -1
		var distance_squared := Vector2(impact.x, impact.z).distance_squared_to(
			target_centroid_xz
		)
		if best_index < 0 or distance_squared < best_distance_squared:
			best_index = index
			best_distance_squared = distance_squared
		elif distance_squared == best_distance_squared \
				and _aim_tuple_precedes(witness, witnesses[best_index]):
			best_index = index
	return best_index


static func validate_summit(
		space_state: PhysicsDirectSpaceState3D,
		cannon: CannonController,
		terrain_surface: TerrainSurface,
		layout: GeneratedStageLayout,
		stage_bounds: AABB
) -> Dictionary:
	var region := layout.summit_region(0.25) if layout != null else []
	if region.is_empty():
		return {"valid": false, "rejection": &"empty_summit_region"}
	var witnesses: Array[AimTuple] = []
	var witness_impacts := PackedVector3Array()
	var witness_identities: Array[TrajectoryHitIdentity] = []
	var target_points := PackedVector3Array()
	var target_witness_indices := PackedInt32Array()
	var distance_margins := PackedFloat32Array()
	var range_margins := PackedFloat32Array()
	var maximum_height := -INF
	var summit_addresses: Dictionary = {}
	for sample in region:
		summit_addresses[_triangle_key(sample.cell as Vector2i, int(sample.triangle))] = true
	for height in layout.heights:
		maximum_height = maxf(maximum_height, height)
	var best: Dictionary = {}
	var nearest_height_margin := INF
	for summit in region:
		var world_point := terrain_surface.to_global(summit.point as Vector3)
		var world_normal := (terrain_surface.global_transform.basis.inverse().transposed() \
			* (summit.normal as Vector3)).normalized()
		var solved := solve_one_target(
			space_state,
			cannon,
			layout,
			stage_bounds,
			world_point,
			world_normal,
			summit,
			true
		)
		if not bool(solved.get("valid", false)):
			continue
		var prediction := solved.prediction as TrajectoryPrediction
		if prediction == null or prediction.hit_identity == null \
				or prediction.hit_identity.contact_owner_id \
						!= TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
			continue
		if not summit_addresses.has(_triangle_key(
			prediction.hit_identity.terrain_cell,
			prediction.hit_identity.terrain_triangle
		)):
			continue
		# The witness must describe a shot that reaches terrain before the same
		# never-contacted cleanup used by live projectiles.
		if prediction.duration >= cannon.projectile_data.never_contacted_timeout:
			continue
		var world_offset_y := world_point.y - float(summit.point.y)
		var height_margin := maxf(
			(world_offset_y + maximum_height) - prediction.collision_contact_point().y,
			0.0
		)
		nearest_height_margin = minf(nearest_height_margin, height_margin)
		# A summit witness must remain inside the one-metre summit band. Within
		# that band, prefer a triangle-interior contact so the rigid body does not
		# straddle a faceted edge on the next physics tick.
		if height_margin > 1.0:
			continue
		var barycentric := prediction.hit_identity.barycentric
		var interior_margin := minf(barycentric.x, minf(barycentric.y, barycentric.z))
		if best.is_empty() or interior_margin > float(best.interior_margin) + 0.0001 \
				or (is_equal_approx(interior_margin, float(best.interior_margin)) \
				and height_margin < float(best.height_margin)):
			best = {
				"aim": solved.aim,
				"prediction": prediction,
				"prediction_duration": prediction.duration,
				"world_point": world_point,
				"height_margin": height_margin,
				"interior_margin": interior_margin,
				"range_margin": float(solved.get("range_margin", 0.0)),
			}
	if best.is_empty():
		return {
			"valid": false,
			"rejection": &"summit_contact_below_global_max" \
					if is_finite(nearest_height_margin) else &"summit_unreachable",
			"minimum_height_margin": nearest_height_margin,
		}
	var minimum_height_margin := float(best.height_margin)
	witnesses.append(best.aim as AimTuple)
	var best_prediction: TrajectoryPrediction = best.prediction
	witness_impacts.append(best_prediction.collision_contact_point())
	witness_identities.append(best_prediction.hit_identity)
	target_points.append(best.world_point)
	target_witness_indices.append(0)
	distance_margins.append(maxf(
		TARGET_DISTANCE_TOLERANCE \
				- best_prediction.collision_contact_point().distance_to(best.world_point),
		0.0
	))
	range_margins.append(float(best.range_margin))
	return {
		"valid": true,
		"rejection": &"",
		"region_count": region.size(),
		"witnesses": witnesses,
		"witness_impacts": witness_impacts,
		"witness_identities": witness_identities,
		"target_points": target_points,
		"target_witness_indices": target_witness_indices,
		"minimum_distance_margins": distance_margins,
		"minimum_range_margins": range_margins,
		"target_count": 1,
		"reachable_target_checksum": layout.reachable_target_checksum(target_witness_indices),
		"predictor_reachability_checksum": _prediction_checksum(
			witnesses,
			witness_identities,
			witness_impacts
		),
		"minimum_height_margin": minimum_height_margin,
		"prediction_duration": float(best.prediction_duration),
		"checksum": _summit_checksum(region, witnesses),
	}


static func _summit_checksum(region: Array[Dictionary], witnesses: Array[AimTuple]) -> int:
	var hash: int = CHECKSUM_OFFSET
	for summit in region:
		hash = _hash_int(hash, int(summit.triangle_id))
	for witness in witnesses:
		hash = _hash_int(hash, int(witness.stable_key().hash()))
	return hash


static func _aim_tuple_precedes(candidate: AimTuple, incumbent: AimTuple) -> bool:
	var candidate_key := [
		absf(candidate.yaw_degrees),
		candidate.elevation_degrees,
		candidate.power_percent,
		candidate.yaw_degrees,
	]
	var incumbent_key := [
		absf(incumbent.yaw_degrees),
		incumbent.elevation_degrees,
		incumbent.power_percent,
		incumbent.yaw_degrees,
	]
	for index in range(candidate_key.size()):
		if candidate_key[index] < incumbent_key[index]:
			return true
		if candidate_key[index] > incumbent_key[index]:
			return false
	return false


static func validate_rigidbody_batches(
		tree: SceneTree,
		certification_root: Node3D,
		cannon: CannonController,
		terrain_surface: TerrainSurface,
		layout: GeneratedStageLayout,
		stage_bounds: AABB,
		predictor_result: Dictionary,
		batch_size: int = RIGIDBODY_BATCH_SIZE
) -> Dictionary:
	var started := Time.get_ticks_msec()
	if tree == null or certification_root == null or cannon == null \
			or cannon.projectile_data == null or terrain_surface == null \
			or layout == null or not bool(predictor_result.get("valid", false)):
		return _failure(&"invalid_rigidbody_input", started)
	var witnesses: Array[AimTuple] = []
	for value in predictor_result.get("witnesses", []):
		witnesses.append(value as AimTuple)
	var expected_identities: Array[TrajectoryHitIdentity] = []
	for value in predictor_result.get("witness_identities", []):
		expected_identities.append(value as TrajectoryHitIdentity)
	var target_points: PackedVector3Array = predictor_result.get("target_points", PackedVector3Array())
	var expected_impacts: PackedVector3Array = predictor_result.get(
		"witness_impacts",
		PackedVector3Array()
	)
	if witnesses.is_empty() or expected_identities.size() != witnesses.size() \
			or expected_impacts.size() != witnesses.size() \
			or target_points.is_empty() or batch_size <= 0:
		return _failure(&"invalid_rigidbody_contract", started)

	var outcomes: Array[Dictionary] = []
	outcomes.resize(witnesses.size())
	var failure_diagnostics: Array[Dictionary] = []
	var physical_points := PackedVector3Array()
	physical_points.resize(witnesses.size())
	var physical_witness_valid := PackedByteArray()
	physical_witness_valid.resize(witnesses.size())
	physical_witness_valid.fill(0)
	var batch_start := 0
	while batch_start < witnesses.size():
		var batch_end := mini(batch_start + batch_size, witnesses.size())
		var pending: Dictionary = {}
		var projectiles: Array[PaintProjectile] = []
		for witness_index in range(batch_start, batch_end):
			var captured_index := witness_index
			var aim := witnesses[captured_index]
			var origin := cannon.get_launch_origin_for(aim.yaw_degrees, aim.elevation_degrees)
			var velocity := CannonBallistics.launch_velocity(
				cannon.projectile_data,
				aim.yaw_degrees,
				aim.elevation_degrees,
				float(aim.power_percent)
			)
			var projectile := PaintProjectile.new()
			projectile.name = "ReachabilityProjectile%06d" % captured_index
			projectile.configure(
				cannon.projectile_data,
				stage_bounds,
				terrain_surface,
				velocity,
				0,
				DEFAULT_PAINT_SURFACE_TUNING,
				captured_index
			)
			projectile.position = certification_root.to_local(origin)
			projectile.linear_velocity = velocity
			projectile.contact_reported.connect(func(
					observed_projectile: PaintProjectile,
					contact: ProjectileContact
			) -> void:
				var existing_outcome = outcomes[captured_index]
				if contact.is_first_contact and existing_outcome != null \
						and (existing_outcome as Dictionary).has("identity"):
					var duplicate_outcome := existing_outcome as Dictionary
					duplicate_outcome["duplicate"] = true
					outcomes[captured_index] = duplicate_outcome
				if not pending.has(captured_index):
					return
				var identity := _runtime_contact_identity(contact, terrain_surface)
				outcomes[captured_index] = {
					"identity": identity,
					"point": contact.world_position,
					"tick": contact.physics_tick,
					"first": contact.is_first_contact,
					"duplicate": false,
				}
				pending.erase(captured_index)
				observed_projectile.deactivate(&"reachability_first_contact")
			)
			projectile.stopped.connect(func(
					_observed_projectile: PaintProjectile,
					reason: StringName
			) -> void:
				if pending.has(captured_index):
					outcomes[captured_index] = {"stopped": reason}
					pending.erase(captured_index)
			)
			certification_root.add_child(projectile)
			projectiles.append(projectile)
			pending[captured_index] = true

		var remaining_ticks := TrajectoryPredictor.MAXIMUM_STEPS
		while not pending.is_empty() and remaining_ticks > 0:
			await tree.physics_frame
			remaining_ticks -= 1
		for witness_index in pending.keys():
			outcomes[int(witness_index)] = {"stopped": &"timeout"}
		for projectile in projectiles:
			if is_instance_valid(projectile):
				projectile.deactivate(&"reachability_batch_cleanup")
		await tree.physics_frame
		batch_start = batch_end

	for witness_index in range(witnesses.size()):
		var outcome_value = outcomes[witness_index]
		if outcome_value == null or not (outcome_value as Dictionary).has("identity"):
			failure_diagnostics.append({
				"witness_index": witness_index,
				"aim": witnesses[witness_index].stable_key(),
				"reason": (outcome_value as Dictionary).get("stopped", &"missing_contact") if outcome_value != null else &"missing_outcome",
			})
			continue
		var outcome := outcome_value as Dictionary
		if not bool(outcome.get("first", false)) or bool(outcome.get("duplicate", false)):
			failure_diagnostics.append({
				"witness_index": witness_index,
				"aim": witnesses[witness_index].stable_key(),
				"reason": &"duplicate_or_nonfirst_contact",
			})
			continue
		var actual_identity: TrajectoryHitIdentity = outcome.identity
		var expected_identity := expected_identities[witness_index]
		if actual_identity == null or expected_identity == null \
				or not outcome.point.is_finite() \
				or not _rigidbody_identity_compatible(
					actual_identity,
					expected_identity,
					expected_impacts[witness_index],
					outcome.point
				):
			failure_diagnostics.append({
				"witness_index": witness_index,
				"aim": witnesses[witness_index].stable_key(),
				"reason": &"wrong_surface_identity",
				"expected": expected_identity.stable_key() if expected_identity != null else &"",
				"actual": actual_identity.stable_key() if actual_identity != null else &"",
			})
			continue
		physical_points[witness_index] = outcome.point
		physical_witness_valid[witness_index] = 1

	# Predictor assignments are only nominations. Reconcile the complete target
	# table against actual rigid-body contact points so a nearby physical witness
	# can cover a texel when the first analytical witness drifted at a facet edge.
	var reconciled_assignments := PackedInt32Array()
	var reconciled_distance_margins := PackedFloat32Array()
	reconciled_distance_margins.resize(witnesses.size())
	var physical_target_tolerance := maxf(
		TARGET_DISTANCE_TOLERANCE,
		cannon.projectile_data.radius + RIGIDBODY_TARGET_RADIUS_CLEARANCE
	)
	var physical_bucket_radius := ceili(
		physical_target_tolerance / WITNESS_SPATIAL_BUCKET_METERS
	)
	var physical_witness_buckets: Dictionary = {}
	for witness_index in range(witnesses.size()):
		reconciled_distance_margins[witness_index] = physical_target_tolerance
		if physical_witness_valid[witness_index] == 1:
			var physical_bucket := _spatial_bucket_for(physical_points[witness_index])
			var physical_indices: PackedInt32Array = physical_witness_buckets.get(
				physical_bucket,
				PackedInt32Array()
			)
			physical_indices.append(witness_index)
			physical_witness_buckets[physical_bucket] = physical_indices
	for target_index in range(target_points.size()):
		var best_witness_index := -1
		var best_distance := INF
		var target_bucket := _spatial_bucket_for(target_points[target_index])
		# Expand the bucket neighborhood from the current physical tolerance so a
		# larger projectile cannot hide a valid nearby witness across a bucket edge.
		for bucket_x in range(
			target_bucket.x - physical_bucket_radius,
			target_bucket.x + physical_bucket_radius + 1
		):
			for bucket_z in range(
				target_bucket.y - physical_bucket_radius,
				target_bucket.y + physical_bucket_radius + 1
			):
				var nearby_indices: PackedInt32Array = physical_witness_buckets.get(
					Vector2i(bucket_x, bucket_z),
					PackedInt32Array()
				)
				for witness_index in nearby_indices:
					var distance := physical_points[witness_index].distance_to(target_points[target_index])
					if distance <= physical_target_tolerance \
							and (distance < best_distance \
							or (is_equal_approx(distance, best_distance) \
							and (best_witness_index < 0 or witness_index < best_witness_index))):
						best_witness_index = witness_index
						best_distance = distance
		if best_witness_index < 0:
			var nearest_physical_distance := INF
			var nearest_physical_point := Vector3.INF
			for witness_index in range(witnesses.size()):
				if physical_witness_valid[witness_index] != 1:
					continue
				var physical_distance := physical_points[witness_index].distance_to(
					target_points[target_index]
				)
				if physical_distance < nearest_physical_distance:
					nearest_physical_distance = physical_distance
					nearest_physical_point = physical_points[witness_index]
			failure_diagnostics.append({
				"target_index": target_index,
				"reason": &"physical_target_uncovered",
				"distance": nearest_physical_distance,
				"tolerance": physical_target_tolerance,
				"physical_point": nearest_physical_point,
				"target_point": target_points[target_index],
			})
			reconciled_assignments.append(0)
			continue
		reconciled_assignments.append(best_witness_index)
		reconciled_distance_margins[best_witness_index] = minf(
			reconciled_distance_margins[best_witness_index],
			physical_target_tolerance - best_distance
		)

	var valid := failure_diagnostics.is_empty()
	return {
		"valid": valid,
		"rejection": &"" if valid else &"rigidbody_parity",
		"failure_diagnostics": failure_diagnostics,
		"outcomes": outcomes,
		"physical_witness_impacts": physical_points,
		"target_witness_indices": reconciled_assignments,
		"minimum_distance_margins": reconciled_distance_margins,
		"rigidbody_reachability_checksum": _rigidbody_checksum(
			witnesses,
			outcomes
		) if valid else 0,
		"witness_count": witnesses.size(),
		"batch_count": ceili(float(witnesses.size()) / float(batch_size)),
		"elapsed_ms": Time.get_ticks_msec() - started,
	}




## MVP-only bounded entry point. It solves exactly one supplied target sample;
## it does not assign or claim reachability for any other target texel.
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
	return TARGET_AIM_SOLVER.solve_one_target(
		space_state,
		cannon,
		layout,
		stage_bounds,
		target_world_point,
		target_world_normal,
		target_sample,
		prefer_short_flight
	)


static func _rigidbody_identity_compatible(
		actual: TrajectoryHitIdentity,
		expected: TrajectoryHitIdentity,
		expected_endpoint: Vector3,
		actual_point: Vector3
) -> bool:
	if actual == null or expected == null or not actual.is_valid() or not expected.is_valid():
		return false
	if actual.contact_owner_id != expected.contact_owner_id \
			or actual.contact_shape_id != expected.contact_shape_id \
			or actual.body_shape_index != expected.body_shape_index:
		return false
	if actual.contact_owner_id != TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
		return actual.has_same_surface_address(expected)
	# A rigid sphere can cross a faceted edge between physics ticks. The owner,
	# shape, and body-shape metadata prove it remained on the same top collider;
	# the endpoint/contact distance prevents a distant triangle from masquerading
	# as an adjacent facet.
	if actual.terrain_cell == expected.terrain_cell \
			and actual.terrain_triangle == expected.terrain_triangle:
		return true
	return expected_endpoint.is_finite() and actual_point.is_finite() \
			and actual_point.distance_to(expected_endpoint) \
			<= RIGIDBODY_IDENTITY_DISTANCE_TOLERANCE


static func _spatial_bucket_for(world_point: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_point.x / WITNESS_SPATIAL_BUCKET_METERS),
		floori(world_point.z / WITNESS_SPATIAL_BUCKET_METERS)
	)


static func _runtime_contact_identity(
		contact: ProjectileContact,
		terrain_surface: TerrainSurface
) -> TrajectoryHitIdentity:
	var collision_object := contact.collider as CollisionObject3D
	if collision_object == null:
		return null
	var owner_id := StringName(collision_object.get_meta(
		PlayBoundsSpec.CONTACT_OWNER_META,
		&""
	))
	var shape_owner_id := collision_object.shape_find_owner(contact.collider_shape_index)
	if shape_owner_id < 0:
		return null
	var shape_owner := collision_object.shape_owner_get_owner(shape_owner_id)
	if shape_owner == null:
		return null
	var shape_id := StringName(shape_owner.get_meta(PlayBoundsSpec.CONTACT_SHAPE_META, &""))
	if owner_id == TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID:
		return terrain_surface.classify_top_physics_hit(
			contact.world_position,
			shape_id,
			contact.collider_shape_index
		)
	var identity := TrajectoryHitIdentity.new(
		owner_id,
		shape_id,
		contact.collider_shape_index
	)
	return identity if identity.is_valid() else null


static func _triangle_key(cell: Vector2i, triangle: int) -> int:
	return ((cell.y * StageGenerationContract.REQUIRED_CELL_COUNT.x + cell.x) * 2) + triangle


static func _prediction_checksum(
		witnesses: Array[AimTuple],
		identities: Array[TrajectoryHitIdentity],
		points: PackedVector3Array
) -> int:
	var hash := CHECKSUM_OFFSET
	for index in range(witnesses.size()):
		hash = _hash_int(hash, index)
		hash = _hash_aim(hash, witnesses[index])
		hash = _hash_identity(hash, identities[index])
		hash = _hash_point(hash, points[index])
	return hash


static func _rigidbody_checksum(
		witnesses: Array[AimTuple],
		outcomes: Array[Dictionary]
) -> int:
	var hash := CHECKSUM_OFFSET
	for index in range(witnesses.size()):
		var outcome: Dictionary = outcomes[index]
		hash = _hash_int(hash, index)
		hash = _hash_aim(hash, witnesses[index])
		hash = _hash_identity(hash, outcome.identity)
		hash = _hash_point(hash, outcome.point)
		hash = _hash_int(hash, int(outcome.tick))
	return hash


static func _hash_aim(hash: int, aim: AimTuple) -> int:
	hash = _hash_int(hash, roundi(aim.yaw_degrees * 10.0))
	hash = _hash_int(hash, roundi(aim.elevation_degrees * 10.0))
	return _hash_int(hash, int(aim.power_percent))


static func _hash_identity(hash: int, identity: TrajectoryHitIdentity) -> int:
	hash = _hash_string(hash, String(identity.contact_owner_id))
	hash = _hash_string(hash, String(identity.contact_shape_id))
	hash = _hash_int(hash, identity.body_shape_index)
	hash = _hash_int(hash, identity.terrain_cell.x)
	hash = _hash_int(hash, identity.terrain_cell.y)
	return _hash_int(hash, identity.terrain_triangle)


static func _hash_point(hash: int, point: Vector3) -> int:
	hash = _hash_int(hash, AimTuple._round_half_away_from_zero(point.x * 1000.0))
	hash = _hash_int(hash, AimTuple._round_half_away_from_zero(point.y * 1000.0))
	return _hash_int(hash, AimTuple._round_half_away_from_zero(point.z * 1000.0))


static func _hash_string(hash: int, value: String) -> int:
	var bytes := value.to_utf8_buffer()
	hash = _hash_int(hash, bytes.size())
	for byte in bytes:
		hash = hash ^ byte
		hash = int((hash * CHECKSUM_PRIME) & 0xffffffff)
	return hash


static func _hash_int(hash: int, value: int) -> int:
	for shift in [0, 8, 16, 24]:
		hash = hash ^ ((value >> shift) & 0xff)
		hash = int((hash * CHECKSUM_PRIME) & 0xffffffff)
	return hash
static func _failure(rejection: StringName, started: int) -> Dictionary:
	return {
		"valid": false,
		"rejection": rejection,
		"elapsed_ms": Time.get_ticks_msec() - started,
	}
