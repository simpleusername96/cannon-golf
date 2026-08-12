extends RefCounted

## Owns immutable catalog-bundle persistence, verification, and pointer promotion.

const CATALOG_DATA_SCRIPT := preload("res://src/stage/stage_catalog_data.gd")
const BUNDLE_FORMAT_VERSION := 5
const CATALOG_PATH := "res://resources/stages/catalog.tres"

static func manifest_stage_descriptor(stage: StageData) -> String:
	var profile := stage.generation_profile
	var contract := profile.generation_contract
	var route_parts: Array[String] = []
	for route in profile.routes:
		route_parts.append("%d,%s,%.3f,%s,%s,%s,%s,%s,%s,%s" % [
			route.role,
		str(route.endpoint_x),
		route.width,
		str(route.grade_signs),
		str(route.drop_range),
		str(route.rise_range),
		str(route.lateral_bend_range),
		str(route.mechanism_kinds),
		str(route.mechanism_pad_ts),
		str(route.mechanism_pad_radii),
	])
	var loadout_parts: Array[String] = []
	for mechanism in stage.mechanism_loadout:
		loadout_parts.append(_mechanism_manifest_descriptor(mechanism))
	var stage_line := "|".join([
		str(stage.stage_id), str(stage.stage_number), str(stage.stage_version), str(stage.terrain_seed),
		str(stage.terrain_center), str(stage.terrain_size), str(stage.target_coverage), str(stage.maximum_shots),
		str(profile.profile_id), str(profile.profile_version), str(profile.nominal_peak),
		str(profile.accepted_height_range), str(profile.ridge_count), str(profile.basin_count),
		str(profile.pass_count), str(profile.undulation_amplitude), str(profile.route_width),
		str(contract.cell_count), str(contract.local_bounds), str(contract.route_station_z),
	])
	return "\n".join([
		stage_line,
		"routes=" + "|".join(route_parts),
		"loadout=" + "|".join(loadout_parts),
	])


static func _mechanism_manifest_descriptor(mechanism: MechanismData) -> String:
	if mechanism == null:
		return "null"
	return ",".join([
		str(int(mechanism.canonical_kind())), str(mechanism.glyph_radius),
		str(mechanism.maximum_charges), str(mechanism.cooldown_seconds),
		str(mechanism.burst_radius), str(mechanism.child_count),
		str(mechanism.maximum_split_generation), str(mechanism.child_radius_multiplier),
		str(mechanism.child_speed_multiplier), str(mechanism.child_minimum_route_speed),
		str(mechanism.child_target_lift), str(mechanism.child_target_t),
		str(mechanism.child_target_route_roles), str(mechanism.uphill_sample_distance),
		str(mechanism.minimum_uphill_rise), str(mechanism.rebound_speed_multiplier),
		str(mechanism.rebound_minimum_speed), str(mechanism.rebound_maximum_speed),
		str(mechanism.rebound_lift_ratio),
	])


static func sha256(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


static func write_bundle_manifest(catalog: StageCatalogData, layouts: Array[BakedStageLayoutData]) -> bool:
	if layouts.size() != catalog.stages.size():
		return false
	var bundle_root := CATALOG_DATA_SCRIPT.generated_bundle_root(catalog.manifest_sha256)
	var final_absolute := ProjectSettings.globalize_path(bundle_root)
	# A matching immutable bundle is already the desired output. Never rewrite it
	# in place: the catalog pointer can continue to refer to the old bundle if a
	# later write fails.
	if DirAccess.dir_exists_absolute(final_absolute):
		if verify_catalog_bundle(catalog, bundle_root):
			return true
		push_error("Refusing to overwrite an invalid content-addressed bundle: %s" % bundle_root)
		return false
	var staging_root := "res://resources/generated_stage_catalogs/.%s-%s.%d.staging" % [
		StageGenerationContract.version_tag(),
		catalog.manifest_sha256,
		Time.get_ticks_usec(),
	]
	var staging_absolute := ProjectSettings.globalize_path(staging_root)
	DirAccess.make_dir_recursive_absolute(staging_absolute)
	var bundle_catalog := "%s/catalog.tres" % staging_root
	if ResourceSaver.save(catalog, bundle_catalog) != OK:
		return false
	for subdirectory in ["stages", "profiles", "layouts", "certificates", "previews"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [staging_root, subdirectory]))
	var certificate_paths: Array[String] = []
	var preview_paths: Array[String] = []
	var play_bounds_checksums: Array[int] = []
	var coverage_metric_versions: Array[int] = []
	var total_target_surface_areas: Array[float] = []
	var target_surface_area_checksums: Array[int] = []
	var default_witnesses: Array[Dictionary] = []
	var summit_witnesses: Array[Dictionary] = []
	for index in range(catalog.stages.size()):
		var stage: StageData = catalog.stages[index]
		var numeric_id := "stage_%02d" % maxi(stage.stage_number, index + 1)
		if ResourceSaver.save(stage, "%s/stages/%s.tres" % [staging_root, numeric_id]) != OK:
			return false
		if ResourceSaver.save(stage.generation_profile, "%s/profiles/%s_profile.tres" % [staging_root, numeric_id]) != OK:
			return false
		var layout_path := "%s/layouts/%s_layout.res" % [staging_root, numeric_id]
		if ResourceSaver.save(layouts[index], layout_path, ResourceSaver.FLAG_COMPRESS) != OK:
			return false
		var reloaded := load(layout_path) as BakedStageLayoutData
		var hydrated := StageLayoutBakeCodec.hydrate(reloaded, stage)
		if hydrated == null:
			return false
		play_bounds_checksums.append(reloaded.play_bounds_checksum)
		coverage_metric_versions.append(reloaded.coverage_metric_version)
		total_target_surface_areas.append(reloaded.total_target_surface_area)
		target_surface_area_checksums.append(reloaded.target_surface_area_checksum)
		default_witnesses.append(_witness_manifest_summary(hydrated.generated_default_witness))
		summit_witnesses.append(_witness_manifest_summary(hydrated.generated_summit_witness))
		if stage.reachability_certificate != null:
			var certificate_path := "%s/certificates/%s_certificate.tres" % [staging_root, numeric_id]
			if ResourceSaver.save(stage.reachability_certificate, certificate_path) != OK:
				return false
			certificate_paths.append("%s/certificates/%s_certificate.tres" % [bundle_root, numeric_id])
	var manifest := {
		"catalog_version": catalog.catalog_version,
		"bundle_format": BUNDLE_FORMAT_VERSION,
		"baked_schema": BakedStageLayoutData.BAKED_LAYOUT_SCHEMA_VERSION,
		"manifest_sha256": catalog.manifest_sha256,
		"bundle_manifest_path": catalog.bundle_manifest_path,
		"stage_ids": catalog.stage_ids,
		"terrain_seeds": catalog.stages.map(func(stage: StageData) -> int: return stage.terrain_seed),
		"profile_ids": catalog.stages.map(func(stage: StageData) -> String: return String(stage.generation_profile.profile_id)),
		"layout_paths": catalog.layout_paths,
		"layout_payload_sha256": layouts.map(func(layout: BakedStageLayoutData) -> String: return layout.payload_sha256),
		"play_bounds_checksums": play_bounds_checksums,
		"coverage_metric_versions": coverage_metric_versions,
		"total_target_surface_areas": total_target_surface_areas,
		"target_surface_area_checksums": target_surface_area_checksums,
		"default_witnesses": default_witnesses,
		"summit_witnesses": summit_witnesses,
		"certificate_paths": certificate_paths,
		"preview_paths": preview_paths,
		"previews_ready": false,
	}
	var file := FileAccess.open("%s/manifest.json" % staging_root, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(manifest, "\t"))
	file.flush()
	file.close()
	# Promote the complete bundle only after every resource and manifest write has
	# succeeded. A failed run leaves the last catalog pointer and final bundle
	# untouched; the positively named staging directory is safe to inspect.
	if not verify_catalog_bundle(catalog, staging_root):
		push_error("Stage-bundle staging validation failed: %s" % staging_root)
		return false
	if DirAccess.rename_absolute(staging_absolute, final_absolute) != OK:
		push_error("Could not promote stage bundle %s" % bundle_root)
		return false
	return verify_catalog_bundle(catalog, bundle_root)


static func promote_staged_bundle(catalog: StageCatalogData, staging_root: String) -> bool:
	if catalog == null or staging_root.is_empty():
		return _bundle_validation_failure("staged-bundle promotion input is empty")
	var final_root := CATALOG_DATA_SCRIPT.generated_bundle_root(catalog.manifest_sha256)
	var expected_prefix := "res://resources/generated_stage_catalogs/.%s-%s." % [
		StageGenerationContract.version_tag(), catalog.manifest_sha256,
	]
	if not staging_root.begins_with(expected_prefix) or not staging_root.ends_with(".staging"):
		return _bundle_validation_failure(
			"promotion path is not the matching content-addressed staging directory"
		)
	if not verify_catalog_bundle(catalog, staging_root):
		return false
	var staging_absolute := ProjectSettings.globalize_path(staging_root)
	var final_absolute := ProjectSettings.globalize_path(final_root)
	if DirAccess.dir_exists_absolute(final_absolute):
		if verify_catalog_bundle(catalog, final_root):
			return true
		return _bundle_validation_failure("matching final bundle exists but is invalid")
	if DirAccess.rename_absolute(staging_absolute, final_absolute) != OK:
		return _bundle_validation_failure("could not promote verified staging directory")
	if verify_catalog_bundle(catalog, final_root):
		return true
	var rollback_error := DirAccess.rename_absolute(final_absolute, staging_absolute)
	if rollback_error != OK:
		push_error("Invalid promoted bundle remains recoverable at %s" % final_root)
	return _bundle_validation_failure("promoted bundle failed final-path verification")


static func publish_catalog_pointer(catalog: StageCatalogData) -> bool:
	if catalog == null or not verify_catalog_bundle(catalog):
		push_error("Refusing to publish a catalog pointer for an invalid final bundle.")
		return false
	var staging_path := _catalog_staging_path()
	var staging_error := ResourceSaver.save(catalog, staging_path)
	if staging_error != OK:
		push_error("Could not write catalog staging resource: %s" % staging_error)
		return false
	var promoted := _replace_catalog_pointer(staging_path, CATALOG_PATH)
	if promoted != OK:
		push_error("Could not promote catalog resource: %s" % promoted)
		return false
	return true


static func verify_catalog_bundle(catalog: StageCatalogData, bundle_root: String = "") -> bool:
	if catalog == null:
		return _bundle_validation_failure("catalog is null")
	if not catalog.is_valid(false):
		return _bundle_validation_failure("catalog failed StageCatalogData.is_valid(false)")
	if catalog.layout_paths.size() != catalog.stages.size():
		return _bundle_validation_failure("layout-path count differs from stage count")
	var resolved_root := bundle_root if not bundle_root.is_empty() \
		else CATALOG_DATA_SCRIPT.generated_bundle_root(catalog.manifest_sha256)
	var manifest_path := "%s/manifest.json" % resolved_root
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return _bundle_validation_failure("manifest is unreadable: %s" % manifest_path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return _bundle_validation_failure("manifest JSON is not a Dictionary")
	var manifest: Dictionary = parsed
	if int(manifest.get("bundle_format", -1)) != BUNDLE_FORMAT_VERSION \
			or int(manifest.get("baked_schema", -1)) \
					!= BakedStageLayoutData.BAKED_LAYOUT_SCHEMA_VERSION \
			or int(manifest.get("catalog_version", -1)) != catalog.catalog_version \
			or String(manifest.get("manifest_sha256", "")) != catalog.manifest_sha256 \
			or String(manifest.get("bundle_manifest_path", "")) != catalog.bundle_manifest_path:
		return _bundle_validation_failure("manifest header does not match catalog identity")
	if not _manifest_array_matches(manifest.get("stage_ids", []), _catalog_stage_ids(catalog)):
		return _bundle_validation_failure("manifest stage IDs differ from catalog")
	if not _manifest_array_matches(manifest.get("terrain_seeds", []), _catalog_seeds(catalog)):
		return _bundle_validation_failure("manifest terrain seeds differ from catalog")
	if not _manifest_array_matches(manifest.get("profile_ids", []), _catalog_profile_ids(catalog)):
		return _bundle_validation_failure("manifest profile IDs differ from catalog")
	if not _manifest_array_matches(manifest.get("layout_paths", []), catalog.layout_paths):
		return _bundle_validation_failure("manifest layout paths differ from catalog")
	var payload_hashes: Array = manifest.get("layout_payload_sha256", [])
	var play_bounds_checksums: Array = manifest.get("play_bounds_checksums", [])
	var coverage_metric_versions: Array = manifest.get("coverage_metric_versions", [])
	var total_target_surface_areas: Array = manifest.get("total_target_surface_areas", [])
	var target_surface_area_checksums: Array = manifest.get("target_surface_area_checksums", [])
	var default_witnesses: Array = manifest.get("default_witnesses", [])
	var summit_witnesses: Array = manifest.get("summit_witnesses", [])
	if payload_hashes.size() != catalog.stages.size():
		return _bundle_validation_failure("manifest payload-hash count differs from stage count")
	if play_bounds_checksums.size() != catalog.stages.size():
		return _bundle_validation_failure("manifest play-bounds count differs from stage count")
	if coverage_metric_versions.size() != catalog.stages.size() \
			or total_target_surface_areas.size() != catalog.stages.size() \
			or target_surface_area_checksums.size() != catalog.stages.size():
		return _bundle_validation_failure("manifest coverage metadata count differs from stage count")
	if default_witnesses.size() != catalog.stages.size():
		return _bundle_validation_failure("manifest default-witness count differs from stage count")
	if summit_witnesses.size() != catalog.stages.size():
		return _bundle_validation_failure("manifest summit-witness count differs from stage count")
	if not _manifest_optional_paths_are_valid(manifest, catalog):
		return _bundle_validation_failure("manifest optional artifact paths are invalid")
	var bundled_catalog := load("%s/catalog.tres" % resolved_root) as StageCatalogData
	if bundled_catalog == null:
		return _bundle_validation_failure("bundled catalog cannot be loaded")
	if not _catalog_identity_matches(catalog, bundled_catalog):
		return _bundle_validation_failure("bundled catalog identity differs from expected catalog")
	var manifest_parts: Array[String] = []
	for index in range(catalog.stages.size()):
		var stage: StageData = catalog.stages[index]
		var stage_id := String(catalog.stage_ids[index])
		var baked := load("%s/layouts/%s_layout.res" % [resolved_root, stage_id]) as BakedStageLayoutData
		if baked == null:
			return _bundle_validation_failure("%s layout cannot be loaded" % stage_id)
		if baked.payload_sha256 != String(payload_hashes[index]):
			return _bundle_validation_failure("%s payload hash differs from manifest" % stage_id)
		if baked.payload_sha256 != StageLayoutBakeCodec.payload_sha256(baked):
			return _bundle_validation_failure("%s serialized payload hash is not reproducible" % stage_id)
		var hydrated := StageLayoutBakeCodec.hydrate(baked, stage)
		if hydrated == null:
			return _bundle_validation_failure("%s layout hydration failed" % stage_id)
		if not hydrated.is_runtime_ready():
			return _bundle_validation_failure("%s hydrated layout is not runtime-ready" % stage_id)
		if baked.terrain_seed != StageProgressionData.CANONICAL_TERRAIN_SEED:
			return _bundle_validation_failure("%s terrain seed identity is invalid" % stage_id)
		if baked.play_bounds_checksum != int(play_bounds_checksums[index]) \
				or baked.play_bounds_checksum != PlayBoundsSpec.new().checksum():
			return _bundle_validation_failure("%s play bounds differ from manifest" % stage_id)
		if baked.coverage_metric_version != int(coverage_metric_versions[index]) \
				or not is_equal_approx(
					baked.total_target_surface_area,
					float(total_target_surface_areas[index])
				) \
				or baked.target_surface_area_checksum \
						!= int(target_surface_area_checksums[index]) \
				or not TargetSurfaceCoverage.metadata_is_valid(
					baked.coverage_metric_version,
					baked.total_target_surface_area,
					baked.target_surface_area_checksum
				):
			return _bundle_validation_failure("%s coverage metadata differs from manifest" % stage_id)
		if not _witness_manifest_matches(
			default_witnesses[index], hydrated.generated_default_witness
		):
			return _bundle_validation_failure(
				"%s default witness differs from manifest: stored=%s hydrated=%s" % [
					stage_id,
					JSON.stringify(default_witnesses[index]),
					JSON.stringify(_witness_manifest_summary(hydrated.generated_default_witness)),
				]
			)
		if not _witness_manifest_matches(
			summit_witnesses[index], hydrated.generated_summit_witness
		):
			return _bundle_validation_failure(
				"%s summit witness differs from manifest: stored=%s hydrated=%s" % [
					stage_id,
					JSON.stringify(summit_witnesses[index]),
					JSON.stringify(_witness_manifest_summary(hydrated.generated_summit_witness)),
				]
			)
		manifest_parts.append(manifest_stage_descriptor(stage))
		manifest_parts.append("layout=%s|%s" % [
			"layouts/%s_layout.res" % stage.stage_id,
			baked.payload_sha256,
		])
		manifest_parts.append("play_bounds_checksum=%d" % baked.play_bounds_checksum)
		manifest_parts.append("coverage=%d|%.6f|%d" % [
			baked.coverage_metric_version,
			baked.total_target_surface_area,
			baked.target_surface_area_checksum,
		])
		manifest_parts.append("default_witness=%s" % witness_manifest_descriptor(
			hydrated.generated_default_witness
		))
		manifest_parts.append("summit_witness=%s" % witness_manifest_descriptor(
			hydrated.generated_summit_witness
		))
	manifest_parts.append("bundle_format=%d" % BUNDLE_FORMAT_VERSION)
	manifest_parts.append(
		"baked_schema=%d" % BakedStageLayoutData.BAKED_LAYOUT_SCHEMA_VERSION
	)
	if sha256("\n".join(manifest_parts)) != catalog.manifest_sha256:
		return _bundle_validation_failure("reconstructed bundle manifest hash differs from catalog")
	return true


static func _bundle_validation_failure(reason: String) -> bool:
	push_error("Stage-bundle validation failed: %s" % reason)
	return false


static func _catalog_identity_matches(expected: StageCatalogData, bundled: StageCatalogData) -> bool:
	if expected == null or bundled == null or not bundled.is_valid(false) \
			or bundled.manifest_sha256 != expected.manifest_sha256 \
			or bundled.bundle_manifest_path != expected.bundle_manifest_path \
			or bundled.catalog_version != expected.catalog_version \
			or not _manifest_array_matches(_catalog_stage_ids(bundled), _catalog_stage_ids(expected)) \
			or not _manifest_array_matches(bundled.layout_paths, expected.layout_paths):
		return false
	for index in range(expected.stages.size()):
		if manifest_stage_descriptor(bundled.stages[index]) \
				!= manifest_stage_descriptor(expected.stages[index]):
			return false
	return true


static func _manifest_optional_paths_are_valid(manifest: Dictionary, catalog: StageCatalogData) -> bool:
	var certificate_paths: Array = manifest.get("certificate_paths", [])
	var preview_paths: Array = manifest.get("preview_paths", [])
	if not certificate_paths is Array or not preview_paths is Array:
		return false
	var expected_certificates: Array[String] = []
	var final_root := CATALOG_DATA_SCRIPT.generated_bundle_root(catalog.manifest_sha256)
	for index in range(catalog.stages.size()):
		if catalog.stages[index].reachability_certificate != null:
			expected_certificates.append("%s/certificates/%s_certificate.tres" % [
				final_root, String(catalog.stage_ids[index]),
			])
	return _manifest_array_matches(certificate_paths, expected_certificates) \
			and preview_paths.is_empty() and not bool(manifest.get("previews_ready", true))


static func _catalog_stage_ids(catalog: StageCatalogData) -> Array[String]:
	var ids: Array[String] = []
	for stage_id in catalog.stage_ids:
		ids.append(String(stage_id))
	return ids


static func _catalog_seeds(catalog: StageCatalogData) -> Array[int]:
	var seeds: Array[int] = []
	for stage in catalog.stages:
		seeds.append(stage.terrain_seed)
	return seeds


static func _catalog_profile_ids(catalog: StageCatalogData) -> Array[String]:
	var ids: Array[String] = []
	for stage in catalog.stages:
		ids.append(String(stage.generation_profile.profile_id))
	return ids


static func _manifest_array_matches(actual: Variant, expected: Array) -> bool:
	if not actual is Array or actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if actual[index] != expected[index]:
			return false
	return true


static func witness_manifest_descriptor(witness: StageEntryAimWitness) -> String:
	return JSON.stringify(_witness_manifest_summary(witness))


static func _witness_manifest_summary(witness: StageEntryAimWitness) -> Dictionary:
	if witness == null:
		return {}
	return {
		"predicted": _identity_manifest_summary(witness.predicted_identity),
		"physical": _identity_manifest_summary(witness.physical_identity),
	}


static func _identity_manifest_summary(identity: TrajectoryHitIdentity) -> Dictionary:
	if identity == null:
		return {}
	return {
		"owner": String(identity.contact_owner_id),
		"shape": String(identity.contact_shape_id),
		"body_shape": identity.body_shape_index,
		"cell_x": identity.terrain_cell.x,
		"cell_y": identity.terrain_cell.y,
		"triangle": identity.terrain_triangle,
	}


static func _witness_manifest_matches(value: Variant, witness: StageEntryAimWitness) -> bool:
	if not value is Dictionary:
		return false
	if witness == null:
		return value.is_empty()
	if value.size() != 2 or not value.has("predicted") or not value.has("physical"):
		return false
	return _identity_manifest_matches(value.get("predicted", {}), witness.predicted_identity) \
			and _identity_manifest_matches(value.get("physical", {}), witness.physical_identity)


static func _identity_manifest_matches(value: Variant, identity: TrajectoryHitIdentity) -> bool:
	if not value is Dictionary:
		return false
	if identity == null:
		return value.is_empty()
	if value.size() != 6:
		return false
	return String(value.get("owner", "")) == String(identity.contact_owner_id) \
			and String(value.get("shape", "")) == String(identity.contact_shape_id) \
			and _manifest_integer_matches(
				value.get("body_shape"), identity.body_shape_index
			) \
			and _manifest_integer_matches(value.get("cell_x"), identity.terrain_cell.x) \
			and _manifest_integer_matches(value.get("cell_y"), identity.terrain_cell.y) \
			and _manifest_integer_matches(value.get("triangle"), identity.terrain_triangle)


static func _manifest_integer_matches(value: Variant, expected: int) -> bool:
	if not value is int and not value is float:
		return false
	return float(value) == float(expected)


static func _replace_catalog_pointer(staging_path: String, destination_path: String) -> Error:
	var staging_absolute := ProjectSettings.globalize_path(staging_path)
	var destination_absolute := ProjectSettings.globalize_path(destination_path)
	if not FileAccess.file_exists(staging_absolute):
		return ERR_FILE_NOT_FOUND
	if not FileAccess.file_exists(destination_absolute):
		return DirAccess.rename_absolute(staging_absolute, destination_absolute)
	# Windows does not replace an existing destination with rename. Preserve the
	# live pointer until the staging resource is ready, then restore it on failure.
	var backup_absolute := "%s.%d.previous" % [destination_absolute, Time.get_ticks_usec()]
	var backup_error := DirAccess.rename_absolute(destination_absolute, backup_absolute)
	if backup_error != OK:
		return backup_error
	var replace_error := DirAccess.rename_absolute(staging_absolute, destination_absolute)
	if replace_error != OK:
		var restore_error := _restore_catalog_pointer(backup_absolute, destination_absolute)
		return restore_error if restore_error != OK else replace_error
	DirAccess.remove_absolute(backup_absolute)
	return OK


static func _restore_catalog_pointer(backup_absolute: String, destination_absolute: String) -> Error:
	if FileAccess.file_exists(destination_absolute):
		return OK
	var rename_error := DirAccess.rename_absolute(backup_absolute, destination_absolute)
	if rename_error == OK and FileAccess.file_exists(destination_absolute):
		return OK
	# Keep the recoverable backup when rename cannot restore it. A verified copy
	# is the last safe recovery step that leaves the live pointer present on Windows.
	var copy_error := DirAccess.copy_absolute(backup_absolute, destination_absolute)
	if copy_error == OK and FileAccess.file_exists(destination_absolute):
		return OK
	push_error(
		"Catalog pointer restore failed; recoverable backup remains at %s." \
				% backup_absolute
	)
	return copy_error if copy_error != OK else rename_error


static func _catalog_staging_path() -> String:
	return "res://resources/stages/.catalog-%s.staging.tres" % \
			StageGenerationContract.version_tag()
