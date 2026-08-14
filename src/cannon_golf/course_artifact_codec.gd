class_name CannonGolfCourseArtifactCodec
extends RefCounted

## Converts the authoring generator product into the shipping runtime resource.

const DRESSING_SPECS := [
	{"model": "res://assets/nature/kenney/rock_smallA.glb", "t": 0.78, "side": -1.0, "scale": 0.82},
	{"model": "res://assets/nature/kenney/tree_pineSmallA.glb", "t": 0.62, "side": 1.0, "scale": 0.72},
	{"model": "res://assets/nature/kenney/rock_largeA.glb", "t": 0.40, "side": -1.0, "scale": 0.68},
	{"model": "res://assets/nature/kenney/tree_pineSmallB.glb", "t": 0.27, "side": 1.0, "scale": 0.70},
]


static func bake(
		course: CannonGolfCourseData,
		generated: Variant,
		resolved_plan: Variant = null,
		certificates: Array[Dictionary] = []
) -> CannonGolfPreparedCourse:
	return _bake_payload(course, generated, resolved_plan, certificates, true)


## Bakes the fast trajectory-first product. Intended setups document how each
## leg was constructed; they are not represented as physics certificates.
static func bake_constructed(
		course: CannonGolfCourseData,
		generated: CannonGolfGeneratedCourse,
		intended_setups: Array[Vector3]
) -> CannonGolfPreparedCourse:
	return _bake_payload(course, generated, null, [], false, true, intended_setups)


## Creates the exact terrain payload used by the physics certifier. This does
## not produce a runtime-valid recipe artifact because its leg certificates are
## intentionally absent.
static func bake_certification_candidate(
		course: CannonGolfCourseData,
		generated: Variant,
		resolved_plan: Variant
) -> CannonGolfPreparedCourse:
	return _bake_payload(course, generated, resolved_plan, [], false)


static func _bake_payload(
		course: CannonGolfCourseData,
		generated: Variant,
		resolved_plan: Variant,
		certificates: Array[Dictionary],
		install_certificates: bool,
		install_construction: bool = false,
		intended_setups: Array[Vector3] = []
) -> CannonGolfPreparedCourse:
	if course == null or not course.is_valid():
		return null
	if course.is_constraint_recipe() and not install_construction and (resolved_plan == null \
			or not resolved_plan.is_valid_for(course) \
			or (install_certificates and certificates.size() != course.leg_count())):
		return null
	if install_construction and (
		not course.is_constraint_recipe()
		or intended_setups.size() != course.leg_count()
	):
		return null
	if not course.is_constraint_recipe() and not install_certificates and not install_construction:
		return null
	var layout: GeneratedStageLayout
	var geometry: TerrainGeometry
	var generated_legs: Array[CannonGolfGeneratedCourseLeg] = []
	var union_metrics: Dictionary = {}
	var landform_metrics: Dictionary = {}
	var content_bounds := AABB()
	var play_bounds := AABB()
	if generated is CannonGolfGeneratedCourse:
		var typed := generated as CannonGolfGeneratedCourse
		if not typed.is_valid() or not typed.is_sealed():
			return null
		layout = typed.layout
		geometry = typed.geometry
		generated_legs = typed.legs
		union_metrics = typed.union_range_metrics
		content_bounds = typed.content_bounds
		play_bounds = typed.play_bounds
		if _has_property(typed, &"landform_metrics"):
			landform_metrics = typed.get(&"landform_metrics") as Dictionary
	elif generated is Dictionary:
		var legacy := generated as Dictionary
		layout = legacy.get("layout") as GeneratedStageLayout
		geometry = legacy.get("geometry") as TerrainGeometry
		union_metrics = legacy.get("range_metrics", {}) as Dictionary
		landform_metrics = legacy.get("landform_metrics", {}) as Dictionary
		content_bounds = legacy.get("content_bounds", AABB()) as AABB
		play_bounds = legacy.get("play_bounds", AABB()) as AABB
		var leg := CannonGolfGeneratedCourseLeg.new()
		leg.goal_position = legacy.get("goal_position", Vector3.ZERO) as Vector3
		leg.goal_rim_y = float(legacy.get("goal_rim_y", 0.0))
		leg.goal_lip_y = leg.goal_rim_y
		leg.launcher_position = legacy.get("cannon_position", Vector3.ZERO) as Vector3
		leg.shot_axis_yaw_degrees = float(legacy.get("shot_axis_yaw_degrees", 0.0))
		leg.frame_bounds = content_bounds
		leg.corridor_admission = union_metrics
		generated_legs.append(leg)
	else:
		return null
	if layout == null or not layout.is_valid() or geometry == null or not geometry.is_valid() \
			or generated_legs.size() != course.leg_count():
		return null
	var prepared := CannonGolfPreparedCourse.new()
	prepared.course_id = course.course_id
	prepared.course_signature = CannonGolfCourseIdentity.signature(course)
	prepared.render_mesh = geometry.render_mesh.duplicate(false) as ArrayMesh
	prepared.top_shape = geometry.top_shape.duplicate(false) as ConcavePolygonShape3D
	prepared.skirt_shape = geometry.skirt_shape.duplicate(false) as ConcavePolygonShape3D
	prepared.cell_count = layout.cell_count
	prepared.local_bounds = layout.local_bounds
	prepared.heights = layout.heights.duplicate()
	prepared.footprint = layout.footprint_cells_read_only()
	prepared.content_bounds = content_bounds
	prepared.play_bounds = play_bounds
	prepared.union_range_metrics = union_metrics.duplicate(true)
	prepared.landform_metrics = landform_metrics.duplicate(true)
	prepared.top_triangle_count = geometry.top_triangle_count
	prepared.skirt_triangle_count = geometry.skirt_triangle_count
	prepared.bottom_triangle_count = geometry.bottom_triangle_count
	if course.is_constraint_recipe():
		if install_construction:
			prepared.construction_version = CannonGolfPreparedCourse.CONSTRUCTION_VERSION
			prepared.construction_sha256 = _construction_sha256(
				course, generated_legs, intended_setups
			)
		else:
			prepared.resolved_plan_sha256 = resolved_plan.sealed_sha256
			prepared.resolved_plan_course_id = resolved_plan.course_id
			prepared.resolved_plan_recipe_signature = resolved_plan.recipe_signature
			prepared.engine_version = CannonGolfPreparedCourse.runtime_engine_version()
			prepared.physics_backend = CannonGolfPreparedCourse.PHYSICS_BACKEND_ID
			prepared.physics_ticks_per_second = int(ProjectSettings.get_setting(
				"physics/common/physics_ticks_per_second", 60
			))
	for index in range(generated_legs.size()):
		var authored := course.leg_at(index)
		var source := generated_legs[index]
		var target := CannonGolfPreparedCourseLeg.new()
		target.route_index = int(_property_or(authored, &"route_index", 0))
		target.rim_elevation_band = int(_property_or(
			authored, &"relative_rim_band", 1
		)) if install_construction else int(
			(resolved_plan.legs[index] as Resource).get(&"rim_elevation_band")
		) if course.is_constraint_recipe() else int(_property_or(
			authored, &"rim_elevation_band", 1
		))
		target.feature_anchor = StringName(_property_or(authored, &"feature_anchor", &""))
		target.goal_position = source.goal_position
		target.goal_radius = _constructed_goal_radius(source) if install_construction else float((resolved_plan.legs[index] as Resource).get(&"bowl_radius")) \
				if course.is_constraint_recipe() else authored.goal_radius
		target.goal_rim_y = source.goal_rim_y
		target.goal_lip_y = source.goal_lip_y
		target.launcher_position = source.launcher_position
		target.shot_axis_yaw_degrees = source.shot_axis_yaw_degrees
		target.frame_bounds = source.frame_bounds
		target.corridor_admission = source.corridor_admission
		if install_construction:
			target.intended_setup = intended_setups[index]
		if course.is_constraint_recipe() and install_certificates and not _install_certificate(
				target, certificates[index]
		):
			return null
		prepared.legs.append(target)
	prepared.dressing = _bake_dressing(layout)
	if install_construction:
		return prepared if prepared.seal_constructed_payload(course) else null
	if course.is_constraint_recipe() and not install_certificates:
		return prepared if prepared.seal_certification_candidate(course) else null
	return prepared if prepared.seal_payload() else null


static func _install_certificate(
		leg: CannonGolfPreparedCourseLeg, certificate: Dictionary
) -> bool:
	leg.certified_setup = certificate.get("certified_setup", Vector3.ZERO) as Vector3
	leg.center_success_count = int(certificate.get("center_success_count", 0))
	leg.neighbor_successes = (certificate.get("neighbor_successes", {}) as Dictionary).duplicate(true)
	leg.axis_pass_evidence = (certificate.get("axis_pass_evidence", {}) as Dictionary).duplicate(true)
	leg.default_attempt_count = int(certificate.get("default_attempt_count", 0))
	leg.default_success_count = int(certificate.get("default_success_count", -1))
	leg.settlement_time_seconds = float(certificate.get("settlement_time_seconds", 0.0))
	leg.robustness_margins = (certificate.get("robustness_margins", {}) as Dictionary).duplicate(true)
	return leg.has_complete_certificate()


static func _bake_dressing(layout: GeneratedStageLayout) -> Array[CannonGolfPreparedCourseDressing]:
	var result: Array[CannonGolfPreparedCourseDressing] = []
	if layout == null or layout.route_graph == null:
		return result
	for index in range(DRESSING_SPECS.size()):
		var spec: Dictionary = DRESSING_SPECS[index]
		var source_point := layout.route_graph.route_position(0, float(spec.t))
		var source_tangent := layout.route_graph.route_tangent(0, float(spec.t))
		var tangent := Vector2(source_tangent.x, source_tangent.z).normalized()
		if tangent.is_zero_approx():
			tangent = Vector2.DOWN
		var side := Vector2(-tangent.y, tangent.x) * float(spec.side) * 10.0
		var xz := Vector2(source_point.x, source_point.z) + side
		var placement := CannonGolfPreparedCourseDressing.new()
		placement.model_path = String(spec.model)
		placement.position = Vector3(xz.x, layout.height_at_local(xz.x, xz.y), xz.y)
		placement.yaw_degrees = float(index * 37 - 18)
		placement.uniform_scale = float(spec.scale)
		placement.is_tree = placement.model_path.contains("tree_")
		if placement.is_valid():
			result.append(placement)
	return result


static func _property_or(object: Object, property_name: StringName, fallback: Variant) -> Variant:
	return object.get(property_name) if _has_property(object, property_name) else fallback


static func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


static func _constructed_goal_radius(source: CannonGolfGeneratedCourseLeg) -> float:
	if source == null or not _has_property(source, &"goal_radius"):
		return 0.0
	return float(source.get(&"goal_radius"))


static func _construction_sha256(
		course: CannonGolfCourseData,
		legs: Array[CannonGolfGeneratedCourseLeg],
		setups: Array[Vector3]
) -> String:
	var feed := PackedStringArray([
		str(CannonGolfPreparedCourse.CONSTRUCTION_VERSION),
		CannonGolfCourseIdentity.signature(course),
	])
	for index in range(legs.size()):
		var leg := legs[index]
		feed.append_array(PackedStringArray([
			str(leg.launcher_position), str(leg.goal_position),
			String.num(leg.goal_rim_y, 5), String.num(leg.goal_lip_y, 5),
			str(setups[index]),
		]))
	return "|".join(feed).sha256_text()
