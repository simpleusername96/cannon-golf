class_name CannonGolfGeneratedCourseLeg
extends RefCounted

## Immutable terrain result for one authored course leg.

var goal_position := Vector3.ZERO:
	set(value):
		_assert_writable()
		goal_position = value
var goal_rim_y := 0.0:
	set(value):
		_assert_writable()
		goal_rim_y = value
var goal_lip_y := 0.0:
	set(value):
		_assert_writable()
		goal_lip_y = value
var goal_radius := 0.0:
	set(value):
		_assert_writable()
		goal_radius = value
var launcher_position := Vector3.ZERO:
	set(value):
		_assert_writable()
		launcher_position = value
var shot_axis_yaw_degrees := 0.0:
	set(value):
		_assert_writable()
		shot_axis_yaw_degrees = value
var frame_bounds := AABB():
	set(value):
		_assert_writable()
		frame_bounds = value
var corridor_admission: Dictionary = {}:
	get:
		return corridor_admission.duplicate(true)
	set(value):
		_assert_writable()
		corridor_admission = value.duplicate(true)

var _sealed := false


func seal() -> void:
	assert(is_valid(), "Only complete generated leg data may be sealed.")
	_sealed = true


func is_sealed() -> bool:
	return _sealed


func is_valid() -> bool:
	return goal_position.is_finite() and launcher_position.is_finite() \
			and is_finite(goal_rim_y) and is_finite(goal_lip_y) \
			and is_finite(shot_axis_yaw_degrees) and frame_bounds.has_volume() \
			and not corridor_admission.is_empty()


func _assert_writable() -> void:
	assert(not _sealed, "Generated course legs are immutable after generation.")
