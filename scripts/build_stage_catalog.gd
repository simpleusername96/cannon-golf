extends SceneTree

## Offline catalog writer. The first version deliberately emits the typed
## catalog pointer from the already-reviewed deterministic profile builder; the
## runtime then consumes only the serialized result.

const CATALOG_PATH := "res://resources/stages/catalog.tres"
const BUNDLE_FORMAT_VERSION := 5
const CATALOG_DATA_SCRIPT := preload("res://src/stage/stage_catalog_data.gd")
const MATERIALIZER := preload("res://src/stage_generation/stage_catalog_materializer.gd")
const BUNDLE_STORE := preload("res://src/stage_generation/stage_catalog_bundle_store.gd")
const TERRAIN_SCENE := preload("res://tests/fixtures/terrain_surface_fixture.tscn")
const OPEN_ENVIRONMENT_SCENE := preload("res://scenes/gameplay/open_play_environment.tscn")
const CANNON_SCENE := preload("res://scenes/gameplay/cannon.tscn")


func _initialize() -> void:
	var promotion_root := _bundle_promotion_argument()
	if not promotion_root.is_empty():
		var promotion_catalog := load("%s/catalog.tres" % promotion_root) as StageCatalogData
		if promotion_catalog == null:
			push_error("Bundle promotion could not load catalog: %s" % promotion_root)
			quit(1)
			return
		if not BUNDLE_STORE.promote_staged_bundle(promotion_catalog, promotion_root) \
				or not BUNDLE_STORE.publish_catalog_pointer(promotion_catalog):
			quit(1)
			return
		print("Stage bundle and catalog pointer promoted: manifest=%s" % promotion_catalog.manifest_sha256)
		quit()
		return
	var verification_root := _bundle_verification_argument()
	if not verification_root.is_empty():
		var verification_catalog := load("%s/catalog.tres" % verification_root) as StageCatalogData
		if verification_catalog == null:
			push_error("Bundle verification could not load catalog: %s" % verification_root)
			quit(1)
			return
		var verification_passed := BUNDLE_STORE.verify_catalog_bundle(
			verification_catalog, verification_root
		)
		if verification_passed:
			print("Stage bundle verification passed: %s" % verification_root)
		quit(0 if verification_passed else 1)
		return
	var diagnostic_stage := _diagnostic_stage_argument()
	if not diagnostic_stage.is_empty():
		var diagnostic_passed := await _diagnose_stage(diagnostic_stage)
		quit(0 if diagnostic_passed else 3)
		return
	var write := "--write" in OS.get_cmdline_user_args()
	var dry_build := "--dry-build" in OS.get_cmdline_user_args()
	if not write and not dry_build:
		_check_active_catalog()
		return
	var build = await _build_catalog()
	var catalog: StageCatalogData = build.get("catalog") if build is Dictionary else null
	var layouts: Array[BakedStageLayoutData] = []
	if build is Dictionary:
		var raw_layouts: Variant = build.get("layouts")
		if raw_layouts is Array:
			for value in raw_layouts:
				var baked := value as BakedStageLayoutData
				if baked == null:
					push_error("Stage catalog build returned a non-baked layout.")
					quit(1)
					return
				layouts.append(baked)
	if catalog == null or not catalog.is_valid(false) or layouts.size() != catalog.stages.size():
		push_error("Stage catalog build failed validation.")
		quit(1)
		return
	if dry_build:
		print("Stage catalog dry build passed: %d stages manifest=%s" % [
			catalog.stages.size(), catalog.manifest_sha256,
		])
		quit()
		return
	if not BUNDLE_STORE.write_bundle_manifest(catalog, layouts):
		push_error("Could not promote the content-addressed stage bundle.")
		quit(1)
		return
	if not BUNDLE_STORE.publish_catalog_pointer(catalog):
		quit(1)
		return
	print("Stage catalog written: %s manifest=%s" % [CATALOG_PATH, catalog.manifest_sha256])
	quit()


## Offline/no-publish diagnostic for one exact canonical stage.
func _diagnose_stage(stage_id: String) -> bool:
	var existing := load(CATALOG_PATH) as StageCatalogData
	if existing == null:
		push_error("Offline exact-stage diagnostic requires the current source catalog.")
		return false
	var source_stage := existing.get_stage(StringName(stage_id)) as StageData
	if source_stage == null:
		push_error("Offline exact-stage diagnostic requested unknown stage: %s" % stage_id)
		return false
	var stage := MATERIALIZER.materialize_stage(source_stage, source_stage.stage_number)
	if stage == null:
		push_error("Offline exact-stage diagnostic could not materialize %s." % stage_id)
		return false
	var result := await _generate_and_bake(stage)
	if result.is_empty():
		push_error("Exact-stage diagnostic rejected stage=%s seed=%d" % [
			stage_id, StageProgressionData.CANONICAL_TERRAIN_SEED,
		])
		return false
	print("Exact-stage diagnostic passed: stage=%s seed=%d" % [
		stage_id, StageProgressionData.CANONICAL_TERRAIN_SEED,
	])
	return true


func _diagnostic_stage_argument() -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find("--diagnose-stage")
	return String(arguments[index + 1]) if index >= 0 and index + 1 < arguments.size() else ""


func _bundle_verification_argument() -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find("--verify-bundle")
	return String(arguments[index + 1]) if index >= 0 and index + 1 < arguments.size() else ""


func _bundle_promotion_argument() -> String:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find("--promote-bundle")
	return String(arguments[index + 1]) if index >= 0 and index + 1 < arguments.size() else ""


func _check_active_catalog() -> void:
	var existing := load(CATALOG_PATH) as StageCatalogData
	if existing == null or not BUNDLE_STORE.verify_catalog_bundle(existing):
		push_error("Serialized format-5 catalog pointer is missing or invalid.")
		quit(1); return
	print("Stage catalog check passed: %d stages manifest=%s" % [existing.stages.size(), existing.manifest_sha256])
	quit()


func _build_catalog() -> Dictionary:
	var result := StageCatalogData.new()
	result.catalog_version = StageGenerationContract.CONTRACT_VERSION
	result.progression = load(_progression_path()) as StageProgressionData
	var existing := load(CATALOG_PATH) as StageCatalogData
	if existing == null or not existing.is_valid(false):
		push_error("The offline builder needs the complete reviewed thirty-stage source catalog.")
		return {}
	var source_stages: Array[StageData] = existing.ordered_stages()
	var manifest_parts: Array[String] = []
	var layouts: Array[BakedStageLayoutData] = []
	for source_index in range(StageProgressionData.STAGE_COUNT):
		var stage := MATERIALIZER.materialize_stage(source_stages[source_index], source_index + 1)
		if stage == null:
			return {}
		var built := await _generate_and_bake(stage)
		if built.is_empty():
			return {}
		stage = built.stage as StageData
		var baked := built.baked as BakedStageLayoutData
		var hydrated := StageLayoutBakeCodec.hydrate(baked, stage)
		if hydrated == null:
			return {}
		result.stage_ids.append(stage.stage_id)
		result.stages.append(stage.duplicate(true) as StageData)
		manifest_parts.append(BUNDLE_STORE.manifest_stage_descriptor(stage))
		manifest_parts.append("layout=%s|%s" % [
			"layouts/%s_layout.res" % stage.stage_id, baked.payload_sha256
		])
		manifest_parts.append("play_bounds_checksum=%d" % baked.play_bounds_checksum)
		manifest_parts.append("coverage=%d|%.6f|%d" % [
			baked.coverage_metric_version,
			baked.total_target_surface_area,
			baked.target_surface_area_checksum,
		])
		manifest_parts.append("default_witness=%s" % BUNDLE_STORE.witness_manifest_descriptor(
			hydrated.generated_default_witness
		))
		manifest_parts.append("summit_witness=%s" % BUNDLE_STORE.witness_manifest_descriptor(
			hydrated.generated_summit_witness
		))
		layouts.append(baked)
	manifest_parts.append("bundle_format=%d" % BUNDLE_FORMAT_VERSION)
	manifest_parts.append("baked_schema=%d" % BakedStageLayoutData.BAKED_LAYOUT_SCHEMA_VERSION)
	result.manifest_sha256 = BUNDLE_STORE.sha256("\n".join(manifest_parts))
	result.bundle_manifest_path = CATALOG_DATA_SCRIPT.generated_bundle_manifest_path(
		result.manifest_sha256
	)
	for stage_id in result.stage_ids:
		result.layout_paths.append("%s/layouts/%s_layout.res" % [
			CATALOG_DATA_SCRIPT.generated_bundle_root(result.manifest_sha256), stage_id
		])
	return {"catalog": result, "layouts": layouts}


## One exact canonical identity either builds completely or fails closed.
func _generate_and_bake(stage: StageData) -> Dictionary:
	var exact_stage := stage.duplicate(true) as StageData
	exact_stage.terrain_seed = StageProgressionData.CANONICAL_TERRAIN_SEED
	exact_stage.generation_profile.base_seed = StageProgressionData.CANONICAL_TERRAIN_SEED
	_place_cannon_from_contract(exact_stage)
	var layout := SeededStageGenerator.generate_exact(
		exact_stage.generation_profile,
		exact_stage.terrain_seed,
		exact_stage
	)
	if layout == null or layout.terrain_seed != StageProgressionData.CANONICAL_TERRAIN_SEED:
		push_error("Exact canonical generation failed for %s." % stage.stage_id)
		return {}
	var witness_result := await _install_entry_witnesses_diagnostic(exact_stage, layout)
	if not bool(witness_result.get("valid", false)):
		push_error("Bounded entry witnesses failed for %s: %s/%s." % [
			stage.stage_id,
			String(witness_result.get("phase", "unknown")),
			String(witness_result.get("reason", "unknown")),
		])
		return {}
	var baked := StageLayoutBakeCodec.bake(layout, exact_stage)
	if baked == null:
		push_error(
			"Baking failed for %s: readiness=%s placement_count=%d placement_checksum=%d default=%s summit=%s." % [
				stage.stage_id,
				str(layout.runtime_readiness_diagnostic()),
				layout.mechanism_placements.size(),
				layout.placement_checksum(),
				layout.generated_default_witness != null and layout.generated_default_witness.is_valid(),
				layout.generated_summit_witness != null and layout.generated_summit_witness.is_valid(true),
			]
		)
		return {}
	return {"stage": exact_stage, "baked": baked}


static func _place_cannon_from_contract(stage: StageData) -> void:
	var front_world_z := stage.terrain_center.z \
			+ stage.generation_profile.generation_contract.local_bounds.end.y
	var origin := stage.cannon_transform.origin
	origin.x = stage.terrain_center.x
	origin.z = front_world_z + StageGenerationContract.FIXED_CANNON_STANDOFF
	stage.cannon_transform = Transform3D(stage.cannon_transform.basis, origin)


## Exactly two predictor/real-body checks: target-centroid and summit band.
func _install_entry_witnesses(stage: StageData, layout: GeneratedStageLayout) -> bool:
	return bool((await _install_entry_witnesses_diagnostic(stage, layout)).get("valid", false))


## The production caller consumes only validity. The offline diagnostic retains
## the first failed predictor/body boundary without changing either validator.
func _install_entry_witnesses_diagnostic(stage: StageData, layout: GeneratedStageLayout) -> Dictionary:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var terrain := TERRAIN_SCENE.instantiate() as TerrainSurface
	terrain.position = stage.terrain_center
	fixture.add_child(terrain)
	await process_frame
	terrain.configure(layout)
	var open_environment := OPEN_ENVIRONMENT_SCENE.instantiate() as OpenPlayEnvironment
	fixture.add_child(open_environment)
	open_environment.configure(layout.play_bounds, stage.paint_world_bounds(), stage.terrain_center.y)
	var cannon := CANNON_SCENE.instantiate() as CannonController
	fixture.add_child(cannon)
	cannon.global_transform = stage.cannon_transform
	await physics_frame
	var default_sample := _stable_default_sample(layout)
	var default_result := _single_target_result(cannon, terrain, layout, default_sample)
	if not bool(default_result.get("valid", false)):
		var default_predictor_reason := _diagnostic_result_reason(default_result, "invalid_default_prediction")
		fixture.queue_free()
		await physics_frame
		return {"valid": false, "phase": "default_predictor", "reason": default_predictor_reason}
	var default_body := await DirectReachabilityValidator.validate_rigidbody_batches(
		self, fixture, cannon, terrain, layout, layout.play_bounds.bounds, default_result, 1
	)
	if not bool(default_body.get("valid", false)):
		var default_body_reason := _diagnostic_result_reason(default_body, "default_rigidbody_parity")
		default_body_reason += " predicted_duration=%.3f" % float(default_result.get("prediction_duration", -1.0))
		fixture.queue_free()
		await physics_frame
		return {"valid": false, "phase": "default_body", "reason": default_body_reason}
	var summit_result := DirectReachabilityValidator.validate_summit(
		root.get_world_3d().direct_space_state, cannon, terrain, layout, layout.play_bounds.bounds
	)
	if not bool(summit_result.get("valid", false)):
		var summit_predictor_reason := _diagnostic_result_reason(summit_result, "invalid_summit_prediction")
		fixture.queue_free()
		await physics_frame
		return {"valid": false, "phase": "summit_predictor", "reason": summit_predictor_reason}
	var summit_body := await DirectReachabilityValidator.validate_rigidbody_batches(
		self, fixture, cannon, terrain, layout, layout.play_bounds.bounds, summit_result, 1
	)
	if not bool(summit_body.get("valid", false)):
		var summit_body_reason := _diagnostic_result_reason(summit_body, "summit_rigidbody_parity")
		summit_body_reason += " predicted_duration=%.3f" % float(summit_result.get("prediction_duration", -1.0))
		fixture.queue_free()
		await physics_frame
		return {"valid": false, "phase": "summit_body", "reason": summit_body_reason}
	layout.generated_default_witness = _witness_from_results(default_result, default_body, terrain, default_sample, 0)
	layout.generated_summit_witness = _witness_from_results(summit_result, summit_body, terrain, {}, layout.summit_region_checksum())
	var valid := layout.generated_default_witness != null and layout.generated_summit_witness != null
	fixture.queue_free()
	await physics_frame
	var reason := ""
	if not valid:
		reason = "invalid_default_witness" if layout.generated_default_witness == null \
				else "invalid_summit_witness"
	return {"valid": valid, "phase": "witness_payload", "reason": reason}


func _diagnostic_result_reason(result: Dictionary, default_reason: String) -> String:
	var rejection := String(result.get("rejection", ""))
	var reason := rejection if not rejection.is_empty() else default_reason
	var failures: Array = result.get("failure_diagnostics", [])
	return "%s %s" % [reason, JSON.stringify(failures)] if not failures.is_empty() else reason


func _single_target_result(cannon: CannonController, terrain: TerrainSurface, layout: GeneratedStageLayout, sample: Dictionary) -> Dictionary:
	if sample.is_empty(): return {"valid": false}
	var target := terrain.to_global(sample.point as Vector3)
	var normal := (terrain.global_transform.basis.inverse().transposed() * (sample.normal as Vector3)).normalized()
	var solved := DirectReachabilityValidator.solve_one_target(
		root.get_world_3d().direct_space_state,
		cannon,
		layout,
		layout.play_bounds.bounds,
		target,
		normal,
		sample,
		true
	)
	if not bool(solved.get("valid", false)): return solved
	var prediction := solved.prediction as TrajectoryPrediction
	return {"valid": prediction != null and prediction.hit_identity != null, "prediction_duration": prediction.duration, "witnesses": [solved.aim], "witness_identities": [prediction.hit_identity], "witness_impacts": PackedVector3Array([prediction.endpoint]), "target_points": PackedVector3Array([target]), "target_witness_indices": PackedInt32Array([0]), "minimum_distance_margins": PackedFloat32Array([maxf(DirectReachabilityValidator.TARGET_DISTANCE_TOLERANCE - prediction.endpoint.distance_to(target), 0.0)]), "minimum_range_margins": PackedFloat32Array([float(solved.get("range_margin", 0.0))])}


func _stable_default_sample(layout: GeneratedStageLayout) -> Dictionary:
	var sample := layout.target_sample_nearest_centroid()
	if sample.is_empty():
		return sample
	var indices := layout.top_topology.triangle_vertex_indices(
		sample.cell as Vector2i,
		int(sample.triangle)
	)
	var vertices := layout.top_topology.canonical_vertices_read_only()
	if indices.x < 0 or indices.y < 0 or indices.z < 0 \
			or indices.x >= vertices.size() or indices.y >= vertices.size() \
			or indices.z >= vertices.size():
		return {}
	# Aim at the selected target triangle's interior, not a mask-pixel center that
	# may sit exactly on the cell diagonal and make equivalent physics hits report
	# adjacent triangle IDs.
	sample["point"] = (vertices[indices.x] + vertices[indices.y] + vertices[indices.z]) / 3.0
	sample["normal"] = layout.top_topology.triangle_normal(
		sample.cell as Vector2i,
		int(sample.triangle)
	)
	return sample


func _witness_from_results(predictor: Dictionary, body: Dictionary, terrain: TerrainSurface, sample: Dictionary, summit_checksum: int) -> StageEntryAimWitness:
	var outcomes: Array = body.get("outcomes", [])
	var identities: Array = predictor.get("witness_identities", [])
	var impacts: PackedVector3Array = predictor.get("witness_impacts", PackedVector3Array())
	var physical: PackedVector3Array = body.get("physical_witness_impacts", PackedVector3Array())
	var aims: Array = predictor.get("witnesses", [])
	var targets: PackedVector3Array = predictor.get("target_points", PackedVector3Array())
	if aims.size() != 1 or identities.size() != 1 or outcomes.size() != 1 \
			or impacts.size() != 1 or physical.size() != 1 or targets.size() != 1: return null
	var outcome: Dictionary = outcomes[0]
	var witness := StageEntryAimWitness.new()
	witness.aim = aims[0] as AimTuple; witness.predicted_identity = identities[0] as TrajectoryHitIdentity; witness.physical_identity = outcome.get("identity") as TrajectoryHitIdentity
	witness.predicted_local_impact = terrain.to_local(impacts[0]); witness.physical_local_impact = terrain.to_local(physical[0]); witness.target_local_point = sample.get("point", terrain.to_local(targets[0]))
	witness.target_pixel_index = int(sample.get("target_pixel_index", -1)); witness.summit_region_checksum = summit_checksum
	witness.distance_margin = float((body.get("minimum_distance_margins", PackedFloat32Array([0.0])) as PackedFloat32Array)[0]); witness.range_margin = float((predictor.get("minimum_range_margins", PackedFloat32Array([0.0])) as PackedFloat32Array)[0]); witness.height_margin = float(predictor.get("minimum_height_margin", 0.0))
	if not witness.is_valid(summit_checksum != 0):
		push_error("Witness payload invalid: summit=%s target_pixel=%d distance=%.4f range=%.4f height=%.4f predicted=%s physical=%s" % [
			summit_checksum != 0,
			witness.target_pixel_index,
			witness.distance_margin,
			witness.range_margin,
			witness.height_margin,
			str(witness.predicted_identity.terrain_cell if witness.predicted_identity != null else Vector2i(-1, -1)),
			str(witness.physical_identity.terrain_cell if witness.physical_identity != null else Vector2i(-1, -1)),
		])
		return null
	return witness


static func _progression_path() -> String:
	return "res://resources/stage_generation/version%d_progression.tres" % \
			StageGenerationContract.CONTRACT_VERSION
