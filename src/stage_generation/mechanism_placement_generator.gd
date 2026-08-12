class_name MechanismPlacementGenerator
extends RefCounted

const ROUTE_EDGE_CLEARANCE := MechanismLoadoutPlanner.GLYPH_EDGE_MARGIN
const TERRAIN_RAY_FINAL_ALLOWANCE := 0.5


static func generate(
		stage_data: StageData,
		layout: GeneratedStageLayout
) -> Array[MechanismPlacement]:
	return MechanismLoadoutPlanner.plan(stage_data, layout)


static func effective_collision_radius(kind: MechanismData.Kind) -> float:
	# Compatibility name for generation and debug callers. Glyphs have no
	# projectile collider; this is their single activation/query/render radius.
	return _default_data_for_kind(kind).glyph_radius


static func effective_visual_diameter(kind: MechanismData.Kind) -> float:
	return effective_collision_radius(kind) * 2.0


static func _projected_horizontal_pixels(
		camera_position: Vector3,
		camera_target: Vector3,
		world_point: Vector3,
		diameter: float
) -> float:
	return MechanismLoadoutPlanner._projected_horizontal_pixels(
		camera_position, camera_target, world_point, diameter
	)


static func _terrain_ray_clear(
		_stage_data: StageData,
		_layout: GeneratedStageLayout,
		_camera_position: Vector3,
		_world_point: Vector3
) -> bool:
	# Terrain ray occlusion is intentionally not a generation gate. Map
	# inspection supplies alternate viewpoints and the footprint is authoritative.
	return true


static func _default_data_for_kind(kind: MechanismData.Kind) -> MechanismData:
	match int(kind):
		int(MechanismData.Kind.BURST):
			return preload("res://resources/mechanisms/burst_node.tres")
		int(MechanismData.Kind.SPLITTER):
			return preload("res://resources/mechanisms/splitter_node.tres")
		_:
			return preload("res://resources/mechanisms/uphill_rebound_node.tres")
