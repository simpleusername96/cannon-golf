class_name CannonGolfCourseIdentity
extends RefCounted

## Canonical authored-input signature used to reject stale prepared courses.


static func signature(course: CannonGolfCourseData) -> String:
	if course == null or course.generation_profile == null \
			or course.generation_profile.generation_contract == null:
		return ""
	var profile := course.generation_profile
	var contract := profile.generation_contract
	var feed := PackedStringArray([
		String(course.course_id), course.display_name, str(course.authoring_mode),
		_f(course.terrain_horizontal_scale), _f(course.terrain_vertical_scale),
		_v3(course.terrain_origin), _color(course.terrain_color),
		_color(course.terrain_accent_color), String(profile.profile_id),
		str(profile.profile_version), str(profile.base_seed), _f(profile.nominal_peak),
		_v2(profile.accepted_height_range), str(profile.ridge_count),
		str(profile.basin_count), str(profile.pass_count),
		_f(profile.undulation_amplitude), _f(profile.route_width),
		str(contract.generation_version), str(contract.profile_version),
		str(contract.layout_version), _v2i(contract.cell_count), _rect2(contract.local_bounds),
		str(contract.maximum_top_triangle_count), _variant_feed(contract.route_station_z),
	])
	if course.is_constraint_recipe():
		feed.append_array(PackedStringArray([
			_v2i(course.terrain_seed_window), _dictionary_feed(course.difficulty_targets),
			_f(course.cannon_route_t),
		]))
	else:
		feed.append_array(PackedStringArray([
			str(course.terrain_seed), _f(course.goal_route_t), _f(course.cannon_route_t),
			_f(course.goal_recess_depth),
		]))
	for route in profile.routes:
		if route == null:
			return ""
		feed.append_array(PackedStringArray([
			str(route.role), _f(route.endpoint_x), _f(route.width),
			_variant_feed(route.grade_signs), _v2(route.drop_range), _v2(route.rise_range),
			_v2(route.lateral_bend_range), _variant_feed(route.mechanism_kinds),
			_variant_feed(route.mechanism_pad_ts), _variant_feed(route.mechanism_pad_radii),
		]))
	if course.has_method(&"landform_signature"):
		feed.append(String(course.call(&"landform_signature")))
	for leg_index in range(course.leg_count()):
		var leg := course.leg_at(leg_index)
		if leg == null:
			return ""
		if course.is_constraint_recipe():
			feed.append_array(PackedStringArray([
				str(leg_index), str(leg.route_index),
				_v2(leg.route_interval), _v2(leg.lateral_offset_range),
				str(leg.relative_rim_band), _v2(leg.bowl_radius_range),
				_v2(leg.bowl_recess_depth_range), _v2(leg.bowl_lip_height_range),
				String(leg.semantic_role),
			]))
		else:
			feed.append_array(PackedStringArray([
				str(leg_index), _f(leg.goal_route_t), _f(leg.launcher_route_t),
				_f(leg.goal_radius), _f(leg.goal_recess_depth), _f(leg.goal_lip_height),
				_v3(leg.default_setup()), _v3(leg.direct_solution()),
				str(leg.get(&"route_index") if _has_property(leg, &"route_index") else 0),
				_v2(leg.get(&"goal_placement_offset") if _has_property(leg, &"goal_placement_offset") else Vector2.ZERO),
				str(leg.get(&"rim_elevation_band") if _has_property(leg, &"rim_elevation_band") else 1),
				String(leg.get(&"feature_anchor") if _has_property(leg, &"feature_anchor") else &""),
			]))
	return "|".join(feed).sha256_text()


static func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


static func _f(value: float) -> String:
	return String.num(value, 6)


static func _v2(value: Vector2) -> String:
	return "%s,%s" % [_f(value.x), _f(value.y)]


static func _v3(value: Vector3) -> String:
	return "%s,%s,%s" % [_f(value.x), _f(value.y), _f(value.z)]


static func _v2i(value: Vector2i) -> String:
	return "%d,%d" % [value.x, value.y]


static func _rect2(value: Rect2) -> String:
	return "%s;%s" % [_v2(value.position), _v2(value.size)]


static func _color(value: Color) -> String:
	return "%s,%s,%s,%s" % [_f(value.r), _f(value.g), _f(value.b), _f(value.a)]


static func _dictionary_feed(values: Dictionary) -> String:
	var keys := values.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	var feed := PackedStringArray()
	for key in keys:
		feed.append("%s=%s" % [str(key), _variant_feed(values[key])])
	return ",".join(feed)


static func _variant_feed(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "1" if value else "0"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return _f(float(value))
		TYPE_VECTOR2:
			return _v2(value)
		TYPE_VECTOR2I:
			return _v2i(value)
		TYPE_VECTOR3:
			return _v3(value)
		TYPE_RECT2:
			return _rect2(value)
		TYPE_DICTIONARY:
			return "{%s}" % _dictionary_feed(value)
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var items := PackedStringArray()
			for item in value:
				items.append(_variant_feed(item))
			return "[%s]" % ",".join(items)
		_:
			return String(value)
