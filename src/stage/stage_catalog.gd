class_name StageCatalog
extends RefCounted

## Runtime catalog facade. StageData and generation profiles are serialized by
## the offline catalog builder; this class only resolves aliases and order.

const CATALOG_PATH := "res://resources/stages/catalog.tres"
const CATALOG_DATA_SCRIPT := preload("res://src/stage/stage_catalog_data.gd")
const STAGE_ORDER: Array[StringName] = [
	&"stage_01", &"stage_02", &"stage_03", &"stage_04", &"stage_05", &"stage_06", &"stage_07", &"stage_08", &"stage_09", &"stage_10",
	&"stage_11", &"stage_12", &"stage_13", &"stage_14", &"stage_15", &"stage_16", &"stage_17", &"stage_18", &"stage_19", &"stage_20",
	&"stage_21", &"stage_22", &"stage_23", &"stage_24", &"stage_25", &"stage_26", &"stage_27", &"stage_28", &"stage_29", &"stage_30",
]

static var _catalog_data: Resource


static func canonical_id(stage_id: StringName) -> StringName:
	match stage_id:
		&"first_descent": return &"stage_01"
		&"burst_basin": return &"stage_02"
		&"split_ridge": return &"stage_03"
		_: return stage_id


static func get_stage(stage_id: StringName) -> StageData:
	var catalog := _catalog()
	if catalog == null:
		return null
	var stage := catalog.get_stage(canonical_id(stage_id)) as StageData
	if stage == null:
		push_error("Stage catalog does not contain %s." % stage_id)
	return stage


static func get_layout_path(stage_id: StringName) -> String:
	var catalog := _catalog()
	return catalog.get_layout_path(canonical_id(stage_id)) if catalog != null else ""


static func all_stages() -> Array[StageData]:
	var catalog := _catalog()
	if catalog == null:
		return []
	return catalog.ordered_stages()


static func all_stage_ids() -> Array[StringName]:
	var catalog := _catalog()
	if catalog == null:
		return STAGE_ORDER.duplicate()
	var result: Array[StringName] = []
	for stage_id in catalog.stage_ids:
		result.append(stage_id)
	return result


static func next_stage_id(stage_id: StringName) -> StringName:
	var index := STAGE_ORDER.find(canonical_id(stage_id))
	if index < 0 or index + 1 >= STAGE_ORDER.size():
		return &""
	return STAGE_ORDER[index + 1]


static func _catalog() -> Resource:
	if _catalog_data != null:
		return _catalog_data
	var loaded := load(CATALOG_PATH)
	if loaded == null or loaded.get_script() != CATALOG_DATA_SCRIPT:
		push_error("Missing or invalid serialized StageCatalogData at %s." % CATALOG_PATH)
		return null
	_catalog_data = loaded
	if not _catalog_data.is_valid():
		push_error("Serialized StageCatalogData failed its versioned contract.")
		_catalog_data = null
		return null
	return _catalog_data
