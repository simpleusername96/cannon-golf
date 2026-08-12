class_name MechanismPlacement
extends Resource

@export var mechanism_data: MechanismData
@export var anchor_id: StringName = &""
@export var local_xz: Vector2 = Vector2.ZERO
@export var local_transform: Transform3D = Transform3D.IDENTITY
@export var route_role: StageRouteProfile.Role = StageRouteProfile.Role.PRIMARY
@export var route_index: int = -1
@export var route_t: float = -1.0
# Compatibility field read by the current gameplay assembler. Uphill Rebound
# stores its authoritative uphill tangent here until that caller migrates.
@export var downstream_tangent: Vector3 = Vector3.ZERO
@export var splitter_route_targets := PackedVector3Array()
@export var uphill_tangent: Vector3 = Vector3.ZERO
