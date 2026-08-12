class_name BakedStageLayoutData
extends Resource

const BAKED_LAYOUT_SCHEMA_VERSION := 3

@export_storage var schema_version := BAKED_LAYOUT_SCHEMA_VERSION
@export_storage var payload_sha256 := ""
@export_storage var profile_id: StringName
@export_storage var profile_version := 0
@export_storage var layout_version := 0
@export_storage var terrain_seed := 0
@export_storage var cell_count := Vector2i.ZERO
@export_storage var local_bounds := Rect2()
@export_storage var heights := PackedFloat32Array()
@export_storage var footprint := PackedByteArray()
@export_storage var height_checksum := 0
@export_storage var target_mask := PackedByteArray()
@export_storage var target_checksum := 0
@export_storage var coverage_metric_version := 0
@export_storage var total_target_surface_area := 0.0
@export_storage var target_surface_area_checksum := 0
@export_storage var route_node_ids: Array[StringName] = []
@export_storage var route_node_positions := PackedVector3Array()
@export_storage var route_node_route_indices := PackedInt32Array()
@export_storage var route_node_station_indices := PackedInt32Array()
@export_storage var route_node_kinds := PackedInt32Array()
@export_storage var route_node_mechanism_kinds := PackedInt32Array()
@export_storage var route_node_pad_radii := PackedFloat64Array()
@export_storage var route_edge_ids: Array[StringName] = []
@export_storage var route_edge_from_ids: Array[StringName] = []
@export_storage var route_edge_to_ids: Array[StringName] = []
@export_storage var route_edge_route_indices := PackedInt32Array()
@export_storage var route_edge_indices := PackedInt32Array()
@export_storage var route_edge_roles := PackedInt32Array()
@export_storage var route_edge_widths := PackedFloat64Array()
@export_storage var play_bounds_checksum := 0
@export_storage var mechanism_loadout_indices := PackedInt32Array()
@export_storage var mechanism_anchor_ids: Array[StringName] = []
@export_storage var mechanism_local_xz := PackedVector2Array()
@export_storage var mechanism_transforms: Array[Transform3D] = []
@export_storage var mechanism_route_roles := PackedInt32Array()
@export_storage var mechanism_route_indices := PackedInt32Array()
@export_storage var mechanism_route_t := PackedFloat64Array()
@export_storage var mechanism_downstream_tangents := PackedVector3Array()
@export_storage var mechanism_splitter_targets: Array[PackedVector3Array] = []
@export_storage var mechanism_uphill_tangents := PackedVector3Array()
@export_storage var placement_checksum := 0
@export_storage var decoration_model_ids: Array[StringName] = []
@export_storage var decoration_local_xz := PackedVector2Array()
@export_storage var decoration_yaws := PackedFloat64Array()
@export_storage var decoration_scales := PackedFloat64Array()
# Witnesses deliberately use fixed primitive fields. Variant dictionaries and
# resource serialization are excluded from the semantic payload.
@export_storage var default_aim_yaw := 0.0
@export_storage var default_aim_elevation := 0.0
@export_storage var default_aim_power := -1
@export_storage var default_predicted_owner: StringName
@export_storage var default_predicted_shape: StringName
@export_storage var default_predicted_body_shape := -1
@export_storage var default_predicted_cell := Vector2i(-1, -1)
@export_storage var default_predicted_triangle := -1
@export_storage var default_predicted_barycentric := Vector3.ZERO
@export_storage var default_physical_owner: StringName
@export_storage var default_physical_shape: StringName
@export_storage var default_physical_body_shape := -1
@export_storage var default_physical_cell := Vector2i(-1, -1)
@export_storage var default_physical_triangle := -1
@export_storage var default_physical_barycentric := Vector3.ZERO
@export_storage var default_predicted_local_impact := Vector3.ZERO
@export_storage var default_physical_local_impact := Vector3.ZERO
@export_storage var default_target_local_point := Vector3.ZERO
@export_storage var default_target_pixel_index := -1
@export_storage var default_summit_region_checksum := 0
@export_storage var default_distance_margin := -1.0
@export_storage var default_range_margin := -1.0
@export_storage var default_height_margin := -1.0
@export_storage var summit_aim_yaw := 0.0
@export_storage var summit_aim_elevation := 0.0
@export_storage var summit_aim_power := -1
@export_storage var summit_predicted_owner: StringName
@export_storage var summit_predicted_shape: StringName
@export_storage var summit_predicted_body_shape := -1
@export_storage var summit_predicted_cell := Vector2i(-1, -1)
@export_storage var summit_predicted_triangle := -1
@export_storage var summit_predicted_barycentric := Vector3.ZERO
@export_storage var summit_physical_owner: StringName
@export_storage var summit_physical_shape: StringName
@export_storage var summit_physical_body_shape := -1
@export_storage var summit_physical_cell := Vector2i(-1, -1)
@export_storage var summit_physical_triangle := -1
@export_storage var summit_physical_barycentric := Vector3.ZERO
@export_storage var summit_predicted_local_impact := Vector3.ZERO
@export_storage var summit_physical_local_impact := Vector3.ZERO
@export_storage var summit_target_local_point := Vector3.ZERO
@export_storage var summit_target_pixel_index := -1
@export_storage var summit_summit_region_checksum := 0
@export_storage var summit_distance_margin := -1.0
@export_storage var summit_range_margin := -1.0
@export_storage var summit_height_margin := -1.0
