class_name StageData
extends Resource

@export_category("Identity")
@export var stage_id: StringName = &"stage_01"
@export var stage_version: int = StageGenerationContract.CONTRACT_VERSION
@export var display_name_key: StringName = &"stage.first_descent.name"
@export var stage_number: int = 1

@export_category("Rules")
@export_range(0.01, 100.0, 0.01) var target_coverage: float = 10.0
@export_range(1, 12, 1) var maximum_shots: int = 4
@export_range(0.0, 300.0, 1.0) var duration_seconds: float = 0.0
@export var paint_color: Color = Color(0.03, 0.38, 1.0, 1.0)
@export var star_thresholds := Vector3(10.0, 18.0, 28.0)
@export var objective_key: StringName = &"stage.first_descent.objective"

@export_category("World")
@export var generation_profile: StageGenerationProfile
@export var terrain_seed: int = 0
@export var terrain_center := Vector3(0.0, -2.0, -112.0)
@export var terrain_size := Vector2(180.0, 120.0)
@export var cannon_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 5.0))
@export var reachability_certificate: DirectReachabilityCertificate
@export var mechanism_loadout: Array[MechanismData] = []

@export_category("Camera Bookmarks")
@export var briefing_camera_position := Vector3(92.0, 62.0, 24.0)
@export var briefing_camera_target := Vector3(0.0, 24.0, -112.0)
@export var aiming_camera_position := Vector3(5.0, 3.2, 18.0)
@export var aiming_camera_target := Vector3(0.0, 18.0, -102.0)
@export var wide_camera_position := Vector3(82.0, 52.0, 8.0)
@export var wide_camera_target := Vector3(0.0, 22.0, -112.0)
@export var result_camera_position := Vector3(-78.0, 50.0, 4.0)
@export var result_camera_target := Vector3(0.0, 22.0, -112.0)
@export_range(24.0, 160.0, 1.0) var follow_camera_max_distance: float = 96.0


func resolved_duration_seconds() -> float:
	# Zero keeps existing serialized stages compatible while the progression
	# resource supplies the canonical duration tier.
	if duration_seconds > 0.0:
		return duration_seconds
	return float(StageProgressionData.duration_seconds_for(stage_number))


func paint_world_bounds() -> Rect2:
	return Rect2(
		Vector2(terrain_center.x - terrain_size.x * 0.5, terrain_center.z - terrain_size.y * 0.5),
		terrain_size
	)
