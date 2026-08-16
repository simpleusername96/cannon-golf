class_name CannonGolfTerrainFeatureGraphBuilder
extends RefCounted

## Builds a small deterministic network of route ridges, branch ridges,
## valleys, shelves, peaks, and authored semantic accents.

const FEATURE := preload("res://src/cannon_golf/continuous_terrain_feature.gd")
const FIELD := preload("res://src/cannon_golf/continuous_terrain_field.gd")


static func build(
		course: CannonGolfCourseData,
		course_index: int,
		plan: Array[Dictionary],
		local_bounds: Rect2,
		base_height: float,
		relief: float
) -> RefCounted:
	if course == null or course_index < 0 or plan.is_empty() \
			or local_bounds.size.x <= 0.0 or local_bounds.size.y <= 0.0 or relief <= 0.0:
		return null
	var field := FIELD.new()
	field.local_bounds = local_bounds
	field.base_height = base_height
	field.relief = relief
	field.seed_phase = float(posmod(course.terrain_seed_window.x, 997)) * 0.017
	var tier := _progression_tier(course_index)
	_add_route_ridges(field, course_index, tier, plan)
	var landmarks := landmark_specs(course, course_index, plan, local_bounds)
	_add_landmark_network(field, course_index, tier, plan, landmarks)
	_add_valley_network(field, course_index, tier, plan, local_bounds)
	_add_authored_features(field, course, local_bounds, relief)
	return field if field.is_valid() else null


static func _add_route_ridges(
		field: RefCounted,
		course_index: int,
		tier: int,
		plan: Array[Dictionary]
) -> void:
	for leg_index in range(plan.size()):
		var leg_data: Dictionary = plan[leg_index]
		var start := Vector2(leg_data.launcher.x, leg_data.launcher.z)
		var goal := Vector2(leg_data.goal.x, leg_data.goal.z)
		var direction := (goal - start).normalized()
		var cross := Vector2(-direction.y, direction.x)
		var bend_sign := -1.0 if (course_index + leg_index) % 2 == 0 else 1.0
		var midpoint := start.lerp(goal, 0.5) + cross * bend_sign * (12.0 + float(tier) * 5.0)
		var start_ratio := 0.19 + float(leg_index) * 0.035
		var end_ratio := minf(0.66, 0.34 + float(tier) * 0.08 + float(leg_index) * 0.055)
		field.add_feature(FEATURE.new().configure(
			FEATURE.Kind.RIDGE,
			PackedVector2Array([start, midpoint, goal]),
			88.0 + float(tier) * 18.0,
			start_ratio,
			end_ratio,
			0.82
		))


static func _add_landmark_network(
		field: RefCounted,
		course_index: int,
		tier: int,
		plan: Array[Dictionary],
		landmarks: Array[Dictionary]
) -> void:
	for index in range(landmarks.size()):
		var landmark: Dictionary = landmarks[index]
		var anchor: Vector2 = landmark.anchor
		var station: Vector2 = landmark.station
		var peak_ratio: float = landmark.height_ratio
		var width: float = landmark.width
		field.add_feature(FEATURE.new().configure(
			FEATURE.Kind.PEAK,
			PackedVector2Array([anchor]),
			width,
			peak_ratio,
			peak_ratio,
			0.78
		))
		field.add_feature(FEATURE.new().configure(
			FEATURE.Kind.RIDGE,
			PackedVector2Array([station, station.lerp(anchor, 0.52), anchor]),
			width * 0.58,
			peak_ratio * 0.42,
			peak_ratio * 0.72,
			0.95
		))
		if tier >= 1 and index % 2 == 0:
			var tangent := (anchor - station).normalized()
			var cross := Vector2(-tangent.y, tangent.x)
			field.add_feature(FEATURE.new().configure(
				FEATURE.Kind.SHELF,
				PackedVector2Array([
					anchor - cross * width * 0.42,
					anchor + cross * width * 0.42,
				]),
				width * (0.42 + float(tier) * 0.05),
				peak_ratio * 0.62,
				peak_ratio * 0.62,
				0.48
			))
	# The final goal's macro summit is part of the graph, before its exact basin
	# and crest contract are compiled by the generator.
	var final_goal := Vector2(plan[-1].goal.x, plan[-1].goal.z)
	field.add_feature(FEATURE.new().configure(
		FEATURE.Kind.PEAK,
		PackedVector2Array([final_goal]),
		92.0 + float(tier) * 12.0,
		0.60 + float(tier) * 0.08,
		0.60 + float(tier) * 0.08,
		0.72
	))


static func _add_valley_network(
		field: RefCounted,
		course_index: int,
		tier: int,
		plan: Array[Dictionary],
		local_bounds: Rect2
) -> void:
	var center := local_bounds.get_center()
	var side := -1.0 if course_index % 2 == 0 else 1.0
	var x_offset := local_bounds.size.x * (0.18 + float(tier) * 0.025) * side
	var valley_points := PackedVector2Array([
		Vector2(center.x + x_offset * 0.65, local_bounds.end.y - local_bounds.size.y * 0.08),
		Vector2(center.x + x_offset, center.y),
		Vector2(center.x + x_offset * 0.42, local_bounds.position.y + local_bounds.size.y * 0.08),
	])
	field.add_feature(FEATURE.new().configure(
		FEATURE.Kind.VALLEY,
		valley_points,
		72.0 + float(tier) * 16.0,
		0.10 + float(tier) * 0.025,
		0.15 + float(tier) * 0.03,
		1.08
	))
	if tier < 2:
		return
	var first_goal := Vector2(plan[0].goal.x, plan[0].goal.z)
	var last_goal := Vector2(plan[-1].goal.x, plan[-1].goal.z)
	var route_direction := (last_goal - first_goal).normalized()
	var route_cross := Vector2(-route_direction.y, route_direction.x)
	field.add_feature(FEATURE.new().configure(
		FEATURE.Kind.VALLEY,
		PackedVector2Array([
			first_goal + route_cross * 110.0,
			first_goal.lerp(last_goal, 0.55) + route_cross * 135.0,
			last_goal + route_cross * 92.0,
		]),
		62.0,
		0.09,
		0.13,
		1.15
	))


static func _add_authored_features(
		field: RefCounted,
		course: CannonGolfCourseData,
		local_bounds: Rect2,
		relief: float
) -> void:
	var horizontal_scale := local_bounds.size.x / 210.0
	for feature_resource in course.landform_features:
		var authored := feature_resource as CannonGolfCourseLandformFeature
		if authored == null or not authored.is_valid():
			continue
		var anchor := Vector2(
			local_bounds.get_center().x + authored.route_offset.x * horizontal_scale,
			lerpf(local_bounds.position.y, local_bounds.end.y, authored.route_t)
		)
		var kind := FEATURE.Kind.PEAK
		match authored.kind:
			CannonGolfCourseLandformFeature.Kind.VALLEY, CannonGolfCourseLandformFeature.Kind.BASIN:
				kind = FEATURE.Kind.VALLEY
			CannonGolfCourseLandformFeature.Kind.PLATEAU, CannonGolfCourseLandformFeature.Kind.TERRACE:
				kind = FEATURE.Kind.SHELF
			_:
				kind = FEATURE.Kind.PEAK
		var amplitude_ratio := authored.amplitude / relief
		field.add_feature(FEATURE.new().configure(
			kind,
			PackedVector2Array([anchor]),
			maxf(authored.radius * horizontal_scale, 1.0),
			amplitude_ratio,
			amplitude_ratio,
			maxf(0.38, authored.flatness)
		))


static func landmark_specs(
		course: CannonGolfCourseData,
		course_index: int,
		plan: Array[Dictionary],
		local_bounds: Rect2
) -> Array[Dictionary]:
	var tier := _progression_tier(course_index)
	var count: int = int([2, 3, 5][tier])
	var camera_away := -Vector2(course.oblique_offset.x, course.oblique_offset.z).normalized()
	if camera_away.is_zero_approx():
		camera_away = Vector2(-0.7, -0.7)
	var camera_cross := Vector2(-camera_away.y, camera_away.x)
	var result: Array[Dictionary] = []
	for index in range(count):
		var leg_data: Dictionary = plan[mini(index, plan.size() - 1)]
		var leg_start := Vector2(leg_data.launcher.x, leg_data.launcher.z)
		var leg_goal := Vector2(leg_data.goal.x, leg_data.goal.z)
		var station := leg_start.lerp(leg_goal, 0.56)
		if index >= plan.size():
			var extra_t := float(index - plan.size() + 1) / float(count - plan.size() + 1)
			station = Vector2(
				lerpf(local_bounds.position.x, local_bounds.end.x, 0.25 + extra_t * 0.5),
				lerpf(local_bounds.position.y, local_bounds.end.y, 0.18 + extra_t * 0.42)
			)
		var leg_direction := (leg_goal - leg_start).normalized()
		var leg_cross := Vector2(-leg_direction.y, leg_direction.x)
		var side := -1.0 if (course_index + index) % 2 == 0 else 1.0
		var offset := 72.0 + float(tier) * 18.0 + float(index % 2) * 10.0
		var candidate_directions: Array[Vector2] = [
			leg_cross * side, -leg_cross * side,
			camera_cross * side, -camera_cross * side,
		]
		var anchor := station
		var best_clearance := -INF
		for direction in candidate_directions:
			var candidate := station + direction * offset + camera_away * 12.0
			if not local_bounds.grow(-28.0).has_point(candidate):
				continue
			var route_clearance := INF
			for planned_leg in plan:
				route_clearance = minf(route_clearance, _distance_to_segment(
					candidate,
					Vector2(planned_leg.launcher.x, planned_leg.launcher.z),
					Vector2(planned_leg.goal.x, planned_leg.goal.z)
				))
			if route_clearance > best_clearance:
				best_clearance = route_clearance
				anchor = candidate
		result.append({
			"anchor": anchor,
			"station": station,
			"width": 104.0 + float(tier) * 24.0 + float(index % 2) * 10.0,
			"height_ratio": minf(
				0.92,
				[0.42 + float(index) * 0.16,
				0.44 + float(index) * 0.14,
				0.46 + float(index) * 0.10][tier]
			),
		})
	return result


static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var delta := finish - start
	if delta.length_squared() <= 0.000001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(start + delta * t)


static func _progression_tier(course_index: int) -> int:
	return 0 if course_index <= 2 else (1 if course_index <= 6 else 2)
