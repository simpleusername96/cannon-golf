class_name DecorationPlacement
extends RefCounted

var model_id: StringName
var local_xz: Vector2
var yaw_degrees: float
var uniform_scale: float


func _init(
		requested_model_id: StringName = &"tree_pineSmallA",
		requested_local_xz: Vector2 = Vector2.ZERO,
		requested_yaw_degrees: float = 0.0,
		requested_uniform_scale: float = 1.0
) -> void:
	model_id = requested_model_id
	local_xz = requested_local_xz
	yaw_degrees = requested_yaw_degrees
	uniform_scale = requested_uniform_scale
