class_name MechanismGlyphAnchor
extends RefCounted

var id: StringName
var local_xz: Vector2
var surface_point: Vector3
var surface_normal: Vector3
var route_index: int
var route_role: StageRouteProfile.Role
var route_t: float
var route_tangent: Vector3


func _init(
		anchor_id: StringName,
		anchor_local_xz: Vector2,
		anchor_surface_point: Vector3,
		anchor_surface_normal: Vector3,
		anchor_route_index: int,
		anchor_route_role: StageRouteProfile.Role,
		anchor_route_t: float,
		anchor_route_tangent: Vector3
) -> void:
	id = anchor_id
	local_xz = anchor_local_xz
	surface_point = anchor_surface_point
	surface_normal = anchor_surface_normal.normalized()
	route_index = anchor_route_index
	route_role = anchor_route_role
	route_t = anchor_route_t
	route_tangent = anchor_route_tangent.normalized()


func is_valid() -> bool:
	return not String(id).is_empty() and local_xz.is_finite() \
			and surface_point.is_finite() and surface_normal.is_finite() \
			and not surface_normal.is_zero_approx() and route_index >= 0 \
			and route_t >= 0.0 and route_t <= 1.0 \
			and not route_tangent.is_zero_approx()
