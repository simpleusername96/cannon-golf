class_name StageRouteProfile
extends Resource

enum Role {
	PRIMARY,
	SAFE,
	SPLITTER,
	BUMPER,
}

@export var role: Role = Role.PRIMARY
@export_range(-70.0, 70.0, 1.0) var endpoint_x: float = 0.0
@export_range(1.0, 64.0, 0.5) var width: float = 20.0
@export var grade_signs := PackedInt32Array([-1, -1, -1, -1, -1, -1, -1])
@export var drop_range := Vector2(5.5, 7.0)
@export var rise_range := Vector2(0.0, 0.0)
@export var lateral_bend_range := Vector2(-8.0, 8.0)
@export_range(-1, 2, 1) var mechanism_kind: int = -1
@export_range(-1.0, 1.0, 0.01) var mechanism_pad_t: float = -1.0
@export_range(0.0, 20.0, 0.5) var mechanism_pad_radius: float = 0.0
@export var mechanism_kinds := PackedInt32Array()
@export var mechanism_pad_ts := PackedFloat32Array()
@export var mechanism_pad_radii := PackedFloat32Array()


func is_valid(required_grade_count: int = 7) -> bool:
	if width <= 0.0 or grade_signs.size() != required_grade_count:
		return false
	if drop_range.x <= 0.0 or drop_range.x > drop_range.y:
		return false
	if rise_range.x < 0.0 or rise_range.x > rise_range.y:
		return false
	if lateral_bend_range.x > lateral_bend_range.y:
		return false
	for grade in grade_signs:
		if grade != -1 and grade != 1:
			return false
		if grade > 0 and rise_range.x <= 0.0:
			return false
	if not mechanism_kinds.is_empty() \
			or not mechanism_pad_ts.is_empty() \
			or not mechanism_pad_radii.is_empty():
		if mechanism_kinds.size() != mechanism_pad_ts.size() \
				or mechanism_kinds.size() != mechanism_pad_radii.size():
			return false
		for index in range(mechanism_kinds.size()):
			if mechanism_kinds[index] < 0 or mechanism_kinds[index] > 2 \
					or mechanism_pad_ts[index] <= 0.0 or mechanism_pad_ts[index] >= 1.0 \
					or mechanism_pad_radii[index] <= 0.0:
				return false
		return true
	return (mechanism_kind < 0 and mechanism_pad_t < 0.0 and is_zero_approx(mechanism_pad_radius)) \
			or (mechanism_kind >= 0 and mechanism_kind <= 2 \
				and mechanism_pad_t >= 0.0 and mechanism_pad_t <= 1.0 \
				and mechanism_pad_radius > 0.0)


func mechanism_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not mechanism_kinds.is_empty():
		for index in range(mechanism_kinds.size()):
			result.append({
				"kind": mechanism_kinds[index],
				"t": mechanism_pad_ts[index],
				"radius": mechanism_pad_radii[index],
			})
		return result
	if mechanism_kind >= 0:
		result.append({"kind": mechanism_kind, "t": mechanism_pad_t, "radius": mechanism_pad_radius})
	return result


func reversal_count() -> int:
	var reversals := 0
	for index in range(grade_signs.size() - 1):
		if grade_signs[index] != grade_signs[index + 1]:
			reversals += 1
	return reversals
