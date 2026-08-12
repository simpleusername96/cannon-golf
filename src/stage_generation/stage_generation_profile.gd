class_name StageGenerationProfile
extends Resource

@export_category("Identity")
@export var profile_id: StringName = profile_id_for_stage(&"stage_01")
@export_range(1, 99, 1) var profile_version: int = StageGenerationContract.CONTRACT_VERSION
@export var base_seed: int = StageProgressionData.CANONICAL_TERRAIN_SEED
@export var generation_contract: StageGenerationContract

@export_category("Stage shape")
@export_range(1.0, 100.0, 0.5) var nominal_peak: float = 72.0
@export var accepted_height_range := Vector2(68.0, 78.0)
@export_range(3, 12, 1) var ridge_count: int = 3
@export_range(0, 4, 1) var basin_count: int = 0
@export_range(0, 4, 1) var pass_count: int = 0
@export_range(0.0, 16.0, 0.1) var undulation_amplitude: float = 2.0
@export_range(0.0, 64.0, 0.5) var route_width: float = 28.0

@export_category("Routes")
@export var routes: Array[StageRouteProfile] = []

@export_category("Acceptance gates")
@export var target_ratio_range := Vector2(0.24, 0.42)
@export var target_mean_slope_range := Vector2(16.0, 30.0)
@export_range(0.0, 90.0, 0.5) var target_p95_slope_max: float = 34.0
@export_range(0.0, 90.0, 0.5) var target_maximum_slope: float = 38.0
@export_range(0.0, 90.0, 0.5) var route_core_p95_slope_max: float = 32.0
@export_range(0.0, 90.0, 0.5) var corridor_lip_maximum_slope: float = 30.0


static func profile_id_for_stage(stage_id: StringName) -> StringName:
	return StringName("%s_%s" % [stage_id, StageGenerationContract.version_tag()])


static func stage_id_from_profile_id(versioned_profile_id: StringName) -> StringName:
	return StringName(
		String(versioned_profile_id).trim_suffix("_%s" % StageGenerationContract.version_tag())
	)


func is_valid() -> bool:
	if profile_version != StageGenerationContract.CONTRACT_VERSION:
		return false
	if not String(profile_id).ends_with("_%s" % StageGenerationContract.version_tag()):
		return false
	if generation_contract == null or not generation_contract.is_valid() or routes.is_empty():
		return false
	if String(profile_id).is_empty() \
			or base_seed != StageProgressionData.CANONICAL_TERRAIN_SEED:
		return false
	if nominal_peak <= 0.0 or accepted_height_range.x > accepted_height_range.y:
		return false
	if ridge_count < 3 or basin_count < 0 or pass_count < 0 \
			or undulation_amplitude < 0.0 or route_width <= 0.0:
		return false
	if target_ratio_range.x <= 0.0 or target_ratio_range.x > target_ratio_range.y or target_ratio_range.y > 1.0:
		return false
	if target_mean_slope_range.x < 0.0 or target_mean_slope_range.x > target_mean_slope_range.y:
		return false
	if target_p95_slope_max < target_mean_slope_range.x \
			or target_maximum_slope < target_p95_slope_max \
			or route_core_p95_slope_max <= 0.0 \
			or corridor_lip_maximum_slope <= 0.0:
		return false
	for route in routes:
		if route == null or not route.is_valid(generation_contract.route_station_z.size() - 1):
			return false
	return true
