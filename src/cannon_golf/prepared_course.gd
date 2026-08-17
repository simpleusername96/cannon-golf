class_name CannonGolfPreparedCourse
extends Resource

## Schema-versioned runtime course. Selection loads this artifact; it never generates.

const SCHEMA_VERSION := 3
const PHYSICS_BACKEND_ID := "GodotPhysics3D"
const CONSTRUCTION_VERSION := 4

@export_storage var schema_version := SCHEMA_VERSION
@export_storage var course_id: StringName
@export_storage var course_signature := ""
@export_storage var payload_sha256 := ""
@export_storage var render_mesh: ArrayMesh
@export_storage var top_shape: ConcavePolygonShape3D
@export_storage var skirt_shape: ConcavePolygonShape3D
@export_storage var cell_count := Vector2i.ZERO
@export_storage var local_bounds := Rect2()
@export_storage var heights := PackedFloat32Array()
@export_storage var footprint := PackedByteArray()
@export_storage var legs: Array[CannonGolfPreparedCourseLeg] = []
@export_storage var content_bounds := AABB()
@export_storage var play_bounds := AABB()
@export_storage var union_range_metrics: Dictionary = {}
@export_storage var landform_metrics: Dictionary = {}
@export_storage var dressing: Array[CannonGolfPreparedCourseDressing] = []
@export_storage var top_triangle_count := 0
@export_storage var skirt_triangle_count := 0
@export_storage var bottom_triangle_count := 0
@export_storage var resolved_plan_sha256 := ""
@export_storage var resolved_plan_course_id: StringName
@export_storage var resolved_plan_recipe_signature := ""
@export_storage var engine_version := ""
@export_storage var physics_backend := ""
@export_storage var physics_ticks_per_second := 0
@export_storage var construction_version := 0
@export_storage var construction_sha256 := ""


func is_valid() -> bool:
	if not _has_valid_structural_payload():
		return false
	for leg in legs:
		if leg.has_any_certificate_data() and not leg.has_complete_certificate():
			return false
	if has_any_construction_data() and not has_complete_construction():
		return false
	return (not has_any_certificate_data() or has_complete_certificate()) \
			and payload_sha256 == compute_payload_sha256()


func is_valid_for(course: CannonGolfCourseData) -> bool:
	var base_match := course != null and course_id == course.course_id \
			and course_signature == CannonGolfCourseIdentity.signature(course) \
			and legs.size() == course.leg_count() and is_valid()
	return base_match and (
		not course.is_constraint_recipe()
		or has_complete_certificate_for(course)
		or has_complete_construction_for(course)
	)


## Offline-only seam. Normal gameplay continues to call `is_valid_for()` and
## therefore cannot load a recipe artifact before every leg is certified.
func is_valid_certification_candidate_for(course: CannonGolfCourseData) -> bool:
	if course == null or not course.is_constraint_recipe() or not course.is_valid() \
			or course_id != course.course_id \
			or course_signature != CannonGolfCourseIdentity.signature(course) \
			or resolved_plan_course_id != course.course_id \
			or resolved_plan_recipe_signature != course_signature \
			or resolved_plan_sha256.is_empty() \
			or engine_version != runtime_engine_version() \
			or physics_backend != PHYSICS_BACKEND_ID \
			or String(ProjectSettings.get_setting(
				"physics/3d/physics_engine", PHYSICS_BACKEND_ID
			)) != PHYSICS_BACKEND_ID \
			or physics_ticks_per_second != int(ProjectSettings.get_setting(
				"physics/common/physics_ticks_per_second", 60
			)) or not _has_valid_structural_payload():
		return false
	for leg in legs:
		if leg.has_any_certificate_data():
			return false
	return payload_sha256 == compute_payload_sha256()


func has_complete_certificate() -> bool:
	if resolved_plan_sha256.is_empty() or resolved_plan_course_id.is_empty() \
			or resolved_plan_recipe_signature.is_empty() or engine_version.is_empty() \
			or physics_backend != PHYSICS_BACKEND_ID or physics_ticks_per_second != 60:
		return false
	for leg in legs:
		if leg == null or not leg.has_complete_certificate():
			return false
	return true


func has_complete_certificate_for(course: CannonGolfCourseData) -> bool:
	return has_complete_certificate() and resolved_plan_course_id == course.course_id \
		and resolved_plan_recipe_signature == CannonGolfCourseIdentity.signature(course) \
		and engine_version == runtime_engine_version() \
		and String(ProjectSettings.get_setting(
			"physics/3d/physics_engine", PHYSICS_BACKEND_ID
		)) == PHYSICS_BACKEND_ID \
		and physics_ticks_per_second == int(ProjectSettings.get_setting(
			"physics/common/physics_ticks_per_second", 60
		))


func has_complete_construction() -> bool:
	if construction_version != CONSTRUCTION_VERSION or construction_sha256.is_empty():
		return false
	for leg in legs:
		if leg == null or not leg.has_valid_intended_setup():
			return false
	return true


func has_complete_construction_for(course: CannonGolfCourseData) -> bool:
	return course != null and course_id == course.course_id \
			and course_signature == CannonGolfCourseIdentity.signature(course) \
			and has_complete_construction()


func has_any_construction_data() -> bool:
	return construction_version != 0 or not construction_sha256.is_empty()


func has_any_certificate_data() -> bool:
	if not resolved_plan_sha256.is_empty() or not resolved_plan_course_id.is_empty() \
		or not resolved_plan_recipe_signature.is_empty() or not engine_version.is_empty() \
		or not physics_backend.is_empty() or physics_ticks_per_second != 0:
		return true
	for leg in legs:
		if leg != null and leg.has_any_certificate_data():
			return true
	return false


static func runtime_engine_version() -> String:
	return String(Engine.get_version_info().get("string", ""))


func seal_payload() -> bool:
	payload_sha256 = compute_payload_sha256()
	return not payload_sha256.is_empty() and is_valid()


func seal_constructed_payload(course: CannonGolfCourseData) -> bool:
	payload_sha256 = compute_payload_sha256()
	return not payload_sha256.is_empty() and is_valid_for(course)


func seal_certification_candidate(course: CannonGolfCourseData) -> bool:
	payload_sha256 = compute_payload_sha256()
	return not payload_sha256.is_empty() and is_valid_certification_candidate_for(course)


func height_at_local(local_x: float, local_z: float) -> float:
	if not is_finite(local_x) or not is_finite(local_z) or heights.is_empty() \
			or not local_bounds.has_area():
		return 0.0
	var grid_x := clampf(
		(local_x - local_bounds.position.x) / local_bounds.size.x * float(cell_count.x),
		0.0, float(cell_count.x)
	)
	var grid_z := clampf(
		(local_z - local_bounds.position.y) / local_bounds.size.y * float(cell_count.y),
		0.0, float(cell_count.y)
	)
	var cell_x := mini(floori(grid_x), cell_count.x - 1)
	var cell_z := mini(floori(grid_z), cell_count.y - 1)
	var u := clampf(grid_x - float(cell_x), 0.0, 1.0)
	var v := clampf(grid_z - float(cell_z), 0.0, 1.0)
	var stride := cell_count.x + 1
	var p00 := heights[cell_z * stride + cell_x]
	var p01 := heights[(cell_z + 1) * stride + cell_x]
	var p10 := heights[cell_z * stride + cell_x + 1]
	var p11 := heights[(cell_z + 1) * stride + cell_x + 1]
	if u + v <= 1.0:
		return p00 * (1.0 - u - v) + p01 * v + p10 * u
	return p10 * (1.0 - v) + p01 * (1.0 - u) + p11 * (u + v - 1.0)


func relief() -> float:
	if heights.is_empty():
		return 0.0
	var minimum := INF
	var maximum := -INF
	for value in heights:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return maximum - minimum


func compute_payload_sha256() -> String:
	if course_id.is_empty() or course_signature.is_empty():
		return ""
	var feed := PackedStringArray([
		str(schema_version), String(course_id), course_signature, _v2i(cell_count),
		_rect2(local_bounds), _aabb(content_bounds), _aabb(play_bounds),
		str(top_triangle_count), str(skirt_triangle_count), str(bottom_triangle_count),
	])
	if has_any_certificate_data():
		feed.append_array(PackedStringArray([
			resolved_plan_sha256, String(resolved_plan_course_id), resolved_plan_recipe_signature,
			engine_version, physics_backend, str(physics_ticks_per_second),
		]))
	if has_any_construction_data():
		feed.append_array(PackedStringArray([
			str(construction_version), construction_sha256,
		]))
	for value in heights:
		feed.append(_f32_bits(value))
	for value in footprint:
		feed.append(str(value))
	for leg in legs:
		if leg == null:
			return ""
		var leg_feed := PackedStringArray([
			str(leg.route_index), str(leg.rim_elevation_band), String(leg.feature_anchor),
			_v3(leg.goal_position), _f64_bits(leg.goal_radius), _f64_bits(leg.goal_rim_y),
			_f64_bits(leg.goal_lip_y), _v3(leg.launcher_position),
			_f64_bits(leg.shot_axis_yaw_degrees), _aabb(leg.frame_bounds),
			_metric_feed(leg.corridor_admission), _v3(leg.intended_setup),
		])
		if leg.has_any_certificate_data():
			leg_feed.append_array(PackedStringArray([
				_v3(leg.certified_setup), str(leg.center_success_count),
				_metric_feed(leg.neighbor_successes), _metric_feed(leg.axis_pass_evidence),
				str(leg.default_attempt_count), str(leg.default_success_count),
				_f64_bits(leg.settlement_time_seconds),
				_metric_feed(leg.robustness_margins),
			]))
		feed.append_array(leg_feed)
	feed.append(_metric_feed(union_range_metrics))
	feed.append(_metric_feed(landform_metrics))
	for placement in dressing:
		if placement == null:
			return ""
		feed.append_array(PackedStringArray([
			placement.model_path, _v3(placement.position),
			_f64_bits(placement.yaw_degrees),
			_f64_bits(placement.uniform_scale), "1" if placement.is_tree else "0",
		]))
	return "|".join(feed).sha256_text()


func _has_valid_structural_payload() -> bool:
	if schema_version != SCHEMA_VERSION or course_id.is_empty() \
			or course_signature.is_empty() or payload_sha256.is_empty() \
			or render_mesh == null or render_mesh.get_surface_count() != 1 \
			or top_shape == null or skirt_shape == null \
			or cell_count.x <= 0 or cell_count.y <= 0 or not local_bounds.has_area() \
			or heights.size() != (cell_count.x + 1) * (cell_count.y + 1) \
			or footprint.size() != cell_count.x * cell_count.y \
			or legs.is_empty() or legs.size() > 6 \
			or not content_bounds.has_volume() or not play_bounds.has_volume() \
			or union_range_metrics.is_empty() or top_triangle_count <= 0 \
			or skirt_triangle_count <= 0 or bottom_triangle_count <= 0:
		return false
	for value in heights:
		if not is_finite(value):
			return false
	if footprint.count(1) <= 0:
		return false
	for leg in legs:
		if leg == null or not leg.is_valid():
			return false
	for placement in dressing:
		if placement == null or not placement.is_valid():
			return false
	return true


func _metric_feed(metrics: Dictionary) -> String:
	var keys := metrics.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	var values := PackedStringArray()
	for key in keys:
		values.append("%s=%s" % [str(key), _metric_value_feed(metrics[key])])
	return ",".join(values)


func _metric_value_feed(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "1" if value else "0"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return _f64_bits(float(value))
		TYPE_VECTOR2:
			return _v2(value)
		TYPE_VECTOR2I:
			return _v2i(value)
		TYPE_VECTOR3:
			return _v3(value)
		TYPE_RECT2:
			return _rect2(value)
		TYPE_AABB:
			return _aabb(value)
		TYPE_DICTIONARY:
			return "{%s}" % _metric_feed(value)
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var items := PackedStringArray()
			for item in value:
				items.append(_metric_value_feed(item))
			return "[%s]" % ",".join(items)
		_:
			return String(value)


func _v2(value: Vector2) -> String:
	return "%s,%s" % [_f64_bits(value.x), _f64_bits(value.y)]


func _v2i(value: Vector2i) -> String:
	return "%d,%d" % [value.x, value.y]


func _v3(value: Vector3) -> String:
	return "%s,%s,%s" % [
		_f64_bits(value.x), _f64_bits(value.y), _f64_bits(value.z),
	]


func _rect2(value: Rect2) -> String:
	return "%s;%s" % [_v2(value.position), _v2(value.size)]


func _aabb(value: AABB) -> String:
	return "%s;%s" % [_v3(value.position), _v3(value.size)]


func _f32_bits(value: float) -> String:
	# Decimal midpoint rounding differs across platforms; hashes use exact IEEE payloads.
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	return bytes.hex_encode()


func _f64_bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()
