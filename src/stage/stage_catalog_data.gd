class_name StageCatalogData
extends Resource

## Immutable catalog pointer written by the offline builder. Runtime lookup only
## reads these serialized StageData entries; it never synthesizes a profile or
## searches for a replacement seed.

@export var catalog_version: int = StageGenerationContract.CONTRACT_VERSION
@export var manifest_sha256: String = ""
@export var bundle_manifest_path: String = ""
@export var progression: StageProgressionData
@export var stage_ids: Array[StringName] = []
@export var stages: Array[StageData] = []
@export var layout_paths: Array[String] = []
@export var legacy_aliases: Dictionary = {
	"first_descent": "stage_01",
	"burst_basin": "stage_02",
	"split_ridge": "stage_03",
}


static func generated_bundle_root(manifest_hash: String) -> String:
	return "res://resources/generated_stage_catalogs/%s-%s" % [
		StageGenerationContract.version_tag(), manifest_hash,
	]


static func generated_bundle_manifest_path(manifest_hash: String) -> String:
	return "%s/manifest.json" % generated_bundle_root(manifest_hash)


func is_valid(require_bundle: bool = true) -> bool:
	if catalog_version != StageGenerationContract.CONTRACT_VERSION:
		return false
	if progression == null \
			or progression.progression_version != catalog_version \
			or progression.stage_count != StageProgressionData.STAGE_COUNT:
		return false
	if stage_ids.size() != StageProgressionData.STAGE_COUNT \
			or stage_ids.size() != stages.size() \
			or layout_paths.size() != stages.size():
		return false
	var seen := {}
	for index in range(stage_ids.size()):
		var stage_id := stage_ids[index]
		var stage := stages[index]
		if String(stage_id).is_empty() or seen.has(stage_id) or stage == null:
			return false
		if stage_id != StringName("stage_%02d" % (index + 1)) \
				or stage.stage_number != index + 1:
			return false
		if stage.stage_id != stage_id or stage.stage_version != catalog_version:
			return false
		var expected_layout_path := "%s/layouts/%s_layout.res" % [
			generated_bundle_root(manifest_sha256), String(stage_id)
		]
		if layout_paths[index] != expected_layout_path or not layout_paths[index].begins_with(
				generated_bundle_root(manifest_sha256) + "/layouts/"
		):
			return false
		if stage.generation_profile == null or not stage.generation_profile.is_valid():
			return false
		if StageGenerationProfile.stage_id_from_profile_id(
			stage.generation_profile.profile_id
		) != stage_id:
			return false
		if not _stage_mechanism_contract_is_valid(stage):
			return false
		seen[stage_id] = true
	return not manifest_sha256.is_empty() \
			and bundle_manifest_path == generated_bundle_manifest_path(manifest_sha256) \
			and (not require_bundle or FileAccess.file_exists(bundle_manifest_path)) \
			and legacy_aliases.get("first_descent", "") == "stage_01" \
			and legacy_aliases.get("burst_basin", "") == "stage_02" \
			and legacy_aliases.get("split_ridge", "") == "stage_03"


static func _stage_mechanism_contract_is_valid(stage: StageData) -> bool:
	if stage.mechanism_loadout.size() \
			!= StageProgressionData.mechanism_count_for(stage.stage_number):
		return false
	var loadout_kinds := PackedInt32Array()
	for mechanism in stage.mechanism_loadout:
		if mechanism == null or not mechanism.is_valid():
			return false
		loadout_kinds.append(int(mechanism.canonical_kind()))
	if not ProjectileManager.stage_resident_capacity_is_valid(
		stage.maximum_shots,
		stage.mechanism_loadout
	):
		return false
	var slot_kinds := PackedInt32Array()
	for route in stage.generation_profile.routes:
		for slot in route.mechanism_slots():
			slot_kinds.append(int(slot.kind))
	if slot_kinds != loadout_kinds:
		return false
	if stage.stage_number == 1:
		return loadout_kinds.is_empty()
	if stage.stage_number == 2:
		return loadout_kinds == PackedInt32Array([MechanismData.Kind.BURST])
	if stage.stage_number == 3:
		return loadout_kinds == PackedInt32Array([
			MechanismData.Kind.SPLITTER,
			MechanismData.Kind.UPHILL_REBOUND,
		]) and stage.generation_profile.routes.size() == 3
	for kind in loadout_kinds:
		if kind == MechanismData.Kind.SPLITTER \
				and stage.generation_profile.routes.size() < 3:
			return false
		if stage.stage_number <= 17 \
				and kind != MechanismData.Kind.BURST \
				and kind != MechanismData.Kind.UPHILL_REBOUND:
			return false
	return true


func get_stage(stage_id: StringName) -> StageData:
	var requested := String(stage_id)
	if legacy_aliases.has(requested):
		requested = String(legacy_aliases[requested])
	for index in range(stage_ids.size()):
		if String(stage_ids[index]) == requested:
			return stages[index]
	return null


func ordered_stages() -> Array[StageData]:
	return stages.duplicate()


func get_layout_path(stage_id: StringName) -> String:
	var stage := get_stage(stage_id)
	if stage == null:
		return ""
	var index := stage_ids.find(stage.stage_id)
	return layout_paths[index] if index >= 0 and index < layout_paths.size() else ""
