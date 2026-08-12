class_name MechanismLoadoutPlanner
extends RefCounted

const MAXIMUM_GLYPHS := 6
const FOOTPRINT_SAMPLE_COUNT := 16
const MAXIMUM_CENTER_SLOPE_DEGREES := 60.0
const MAXIMUM_NORMAL_VARIATION_DEGREES := 32.0
const GLYPH_EDGE_MARGIN := 0.75
const GLYPH_SEPARATION_MARGIN := 1.0
const MINIMUM_AIMING_DIAMETER_PIXELS := 12.0
const MINIMUM_BRIEFING_DIAMETER_PIXELS := 16.0
const MINIMUM_AIM_VIEW_FACING_DOT := 0.50
const AIM_VIEW_VISIBILITY_CLEARANCE := 0.5
const FOOTPRINT_RING_FRACTIONS := [0.0, 0.5, 1.0]
const AIM_VIEW_VERTICAL_FOV_DEGREES := 48.0
const AIM_VIEW_ASPECT_RATIO := 16.0 / 9.0
const PREFERRED_VIEW_BAND_MINIMUM := 0.38
const PREFERRED_VIEW_BAND_MAXIMUM := 0.62
const FALLBACK_VIEW_BAND_MINIMUM := 0.28
const FALLBACK_VIEW_BAND_MAXIMUM := 0.74
const PREFERRED_VIEW_CENTER := 0.50
const AIM_VIEW_HORIZONTAL_SAFE_NDC := 0.84


static func plan(
		stage_data: StageData,
		layout: GeneratedStageLayout
) -> Array[MechanismPlacement]:
	var empty: Array[MechanismPlacement] = []
	if stage_data == null or layout == null or not layout.is_valid():
		return empty
	if stage_data.mechanism_loadout.size() > MAXIMUM_GLYPHS:
		layout.metrics["placement_rejection"] = "glyph_count"
		return empty
	if stage_data.mechanism_loadout.is_empty():
		return empty
	var anchors := _build_generic_anchors(layout)
	if anchors.size() < stage_data.mechanism_loadout.size():
		layout.metrics["placement_rejection"] = "generic_anchor_count"
		return empty
	var aim_view := _build_aim_view_context(stage_data, layout)
	if aim_view.is_empty():
		layout.metrics["placement_rejection"] = "aim_view_projection"
		return empty

	var candidate_sets: Array = []
	var request_order: Array[Dictionary] = []
	for request_index in range(stage_data.mechanism_loadout.size()):
		var mechanism_data := stage_data.mechanism_loadout[request_index]
		if mechanism_data == null or not mechanism_data.is_valid():
			layout.metrics["placement_rejection"] = "invalid_mechanism_data"
			return empty
		var candidates: Array[Dictionary] = []
		for anchor in anchors:
			var candidate := _candidate_for(
				stage_data,
				layout,
				mechanism_data,
				anchor,
				aim_view
			)
			if not candidate.is_empty():
				candidates.append(candidate)
		candidates.sort_custom(_candidate_less)
		if candidates.is_empty():
			layout.metrics["placement_failed_kind"] = MechanismData.Kind.keys()[int(mechanism_data.canonical_kind())]
			layout.metrics["placement_rejection"] = "kind_suitability"
			return empty
		candidate_sets.append(candidates)
		request_order.append({
			"request_index": request_index,
			"candidate_count": candidates.size(),
			"kind": int(mechanism_data.canonical_kind()),
		})
	request_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.candidate_count) != int(b.candidate_count):
			return int(a.candidate_count) < int(b.candidate_count)
		if int(a.kind) != int(b.kind):
			return int(a.kind) > int(b.kind)
		return int(a.request_index) < int(b.request_index)
	)

	var selected: Array = []
	selected.resize(stage_data.mechanism_loadout.size())
	var assigned := false
	if _all_requests_have_candidates_within_ranks(candidate_sets, 1, 0):
		assigned = _assign_candidates(
			0, request_order, candidate_sets, selected, {}, 1, 0
		)
	if not assigned:
		selected.fill(null)
		assigned = _assign_candidates(
			0, request_order, candidate_sets, selected, {}, 2, 1
		)
	if not assigned:
		layout.metrics["placement_rejection"] = "glyph_separation_or_assignment"
		return empty
	var placements: Array[MechanismPlacement] = []
	for candidate in selected:
		placements.append(candidate.placement)
	return placements


static func _build_generic_anchors(layout: GeneratedStageLayout) -> Array[MechanismGlyphAnchor]:
	var anchors: Array[MechanismGlyphAnchor] = []
	var cell_size := layout.local_bounds.size / Vector2(layout.cell_count)
	for cell_z in range(layout.cell_count.y):
		for cell_x in range(layout.cell_count.x):
			var cell := Vector2i(cell_x, cell_z)
			if not layout.top_topology.is_cell_active(cell):
				continue
			var local_xz := layout.local_bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
			var sample := layout.surface_sample_at_local(local_xz.x, local_xz.y, false)
			var route_metadata := _nearest_route_metadata(layout.route_graph, local_xz)
			if sample.is_empty() or route_metadata.is_empty():
				continue
			var anchor := MechanismGlyphAnchor.new(
				StringName("surface/%04d/%04d/%d" % [cell_z, cell_x, int(sample.source_triangle_id)]),
				local_xz,
				sample.point,
				sample.normal,
				int(route_metadata.route_index),
				int(route_metadata.route_role) as StageRouteProfile.Role,
				float(route_metadata.route_t),
				route_metadata.route_tangent
			)
			if anchor.is_valid():
				anchors.append(anchor)
	return anchors


static func _nearest_route_metadata(route_graph: GeneratedRouteGraph, local_xz: Vector2) -> Dictionary:
	var nearest := route_graph.nearest_edge(local_xz)
	var edge := nearest.edge as GeneratedRouteEdge
	if edge == null:
		return {}
	var start_t := route_graph.route_normalized_t_for_node(edge.route_index, edge.from_node_id)
	var end_t := route_graph.route_normalized_t_for_node(edge.route_index, edge.to_node_id)
	if start_t < 0.0 or end_t < start_t:
		return {}
	var route_t := lerpf(start_t, end_t, float(nearest.edge_t))
	var tangent := route_graph.route_tangent(edge.route_index, route_t)
	if tangent.is_zero_approx():
		return {}
	return {
		"route_index": edge.route_index,
		"route_role": route_graph.route_role(edge.route_index),
		"route_t": route_t,
		"route_tangent": tangent,
	}


static func _candidate_for(
		stage_data: StageData,
	layout: GeneratedStageLayout,
	mechanism_data: MechanismData,
	anchor: MechanismGlyphAnchor,
	aim_view: Dictionary
) -> Dictionary:
	if not _generic_suitability(stage_data, layout, mechanism_data, anchor, aim_view):
		return {}
	var split_targets := PackedVector3Array()
	var uphill_tangent := Vector3.ZERO
	var kind_score := 0.0
	match mechanism_data.canonical_kind():
		MechanismData.Kind.SPLITTER:
			split_targets = _splitter_route_targets(layout, mechanism_data, anchor)
			if split_targets.size() != mechanism_data.child_count:
				return {}
			kind_score = _splitter_divergence_score(anchor.surface_point, split_targets)
		MechanismData.Kind.UPHILL_REBOUND:
			var witness := _uphill_witness(layout, mechanism_data, anchor)
			if witness.is_empty():
				return {}
			uphill_tangent = witness.tangent
			kind_score = float(witness.rise)
		_:
			kind_score = 0.0
	var forward := uphill_tangent if not uphill_tangent.is_zero_approx() else anchor.route_tangent
	var local_z_axis := -forward
	var local_x_axis := anchor.surface_normal.cross(local_z_axis).normalized()
	if local_x_axis.is_zero_approx():
		return {}
	local_z_axis = local_x_axis.cross(anchor.surface_normal).normalized()
	var placement := MechanismPlacement.new()
	placement.mechanism_data = mechanism_data
	placement.anchor_id = anchor.id
	placement.local_xz = anchor.local_xz
	placement.local_transform = Transform3D(
		Basis(local_x_axis, anchor.surface_normal, local_z_axis),
		anchor.surface_point
	)
	placement.route_role = anchor.route_role
	placement.route_index = anchor.route_index
	placement.route_t = anchor.route_t
	placement.downstream_tangent = forward
	placement.splitter_route_targets = split_targets
	placement.uphill_tangent = uphill_tangent
	var horizontal_extent := _glyph_horizontal_extent_ndc(
		stage_data, layout, placement, aim_view
	)
	if not is_finite(horizontal_extent) \
			or horizontal_extent > AIM_VIEW_HORIZONTAL_SAFE_NDC:
		return {}
	var world_point := stage_data.terrain_center + anchor.surface_point
	var view_fraction := _aim_view_vertical_fraction(world_point, aim_view)
	if not is_finite(view_fraction):
		return {}
	view_fraction = clampf(view_fraction, 0.0, 1.0)
	var view_rank := 2
	if (
		view_fraction >= PREFERRED_VIEW_BAND_MINIMUM
		and view_fraction <= PREFERRED_VIEW_BAND_MAXIMUM
	):
		view_rank = 0
	elif (
		view_fraction >= FALLBACK_VIEW_BAND_MINIMUM
		and view_fraction <= FALLBACK_VIEW_BAND_MAXIMUM
	):
		view_rank = 1
	var facing_dot := anchor.surface_normal.dot(
		(Vector3(aim_view.camera_position) - world_point).normalized()
	)
	return {
		"anchor_id": anchor.id,
		"score": kind_score,
		"view_rank": view_rank,
		"view_distance": absf(
			view_fraction - PREFERRED_VIEW_CENTER
		),
		"aim_view_vertical_fraction": view_fraction,
		"readability_rank": 0 if facing_dot >= MINIMUM_AIM_VIEW_FACING_DOT else 1,
		"aim_view_facing_dot": facing_dot,
		"placement": placement,
	}


static func _generic_suitability(
		stage_data: StageData,
	layout: GeneratedStageLayout,
	mechanism_data: MechanismData,
	anchor: MechanismGlyphAnchor,
	aim_view: Dictionary
) -> bool:
	var radius := mechanism_data.glyph_radius
	if not layout.local_bounds.grow(-(radius + GLYPH_EDGE_MARGIN)).has_point(anchor.local_xz):
		return false
	var center_slope := rad_to_deg(acos(clampf(anchor.surface_normal.y, -1.0, 1.0)))
	if center_slope > MAXIMUM_CENTER_SLOPE_DEGREES:
		return false
	var minimum_normal_dot := cos(deg_to_rad(MAXIMUM_NORMAL_VARIATION_DEGREES))
	for ring_fraction in FOOTPRINT_RING_FRACTIONS:
		var radius_fraction := float(ring_fraction)
		for sample_index in range(FOOTPRINT_SAMPLE_COUNT):
			var angle := TAU * float(sample_index) / float(FOOTPRINT_SAMPLE_COUNT)
			var point: Vector2 = anchor.local_xz + Vector2.from_angle(angle) * radius * radius_fraction
			var sample := layout.surface_sample_at_local(point.x, point.y, false)
			if sample.is_empty() or anchor.surface_normal.dot(Vector3(sample.normal)) < minimum_normal_dot:
				return false
	if not _has_aim_view_visibility(stage_data, layout, anchor, aim_view):
		return false
	var diameter := radius * 2.0
	var world_point := stage_data.terrain_center + anchor.surface_point
	if _projected_horizontal_pixels(
		aim_view.camera_position,
		aim_view.camera_target,
		world_point,
		diameter
	) < MINIMUM_AIMING_DIAMETER_PIXELS:
		return false
	return _projected_horizontal_pixels(
		stage_data.briefing_camera_position,
		stage_data.briefing_camera_target,
		world_point,
		diameter
	) >= MINIMUM_BRIEFING_DIAMETER_PIXELS


static func _has_aim_view_visibility(
		stage_data: StageData,
		layout: GeneratedStageLayout,
		anchor: MechanismGlyphAnchor,
		aim_view: Dictionary
) -> bool:
	var camera_local := Vector3(aim_view.camera_position) - stage_data.terrain_center
	var start_xz := Vector2(camera_local.x, camera_local.z)
	var distance := start_xz.distance_to(anchor.local_xz)
	var cell_size := layout.local_bounds.size / Vector2(layout.cell_count)
	var sample_count := maxi(1, ceili(distance / maxf(cell_size.length() * 0.5, 0.001)))
	for sample_index in range(1, sample_count):
		var t := float(sample_index) / float(sample_count)
		var point_xz := start_xz.lerp(anchor.local_xz, t)
		var sample := layout.surface_sample_at_local(point_xz.x, point_xz.y, false)
		if sample.is_empty():
			continue
		var line_height := lerpf(camera_local.y, anchor.surface_point.y, t)
		if float(sample.point.y) > line_height + AIM_VIEW_VISIBILITY_CLEARANCE:
			return false
	return true


static func _splitter_route_targets(
		layout: GeneratedStageLayout,
		mechanism_data: MechanismData,
		anchor: MechanismGlyphAnchor
) -> PackedVector3Array:
	var targets := PackedVector3Array()
	var route_indices := PackedInt32Array()
	for role in mechanism_data.child_target_route_roles:
		var route_index := layout.route_graph.route_index_for_role(role)
		if route_index < 0 or route_indices.has(route_index):
			return PackedVector3Array()
		var route_point := layout.route_graph.route_position(route_index, mechanism_data.child_target_t)
		var sample := layout.surface_sample_at_local(route_point.x, route_point.z, false)
		if sample.is_empty():
			return PackedVector3Array()
		route_indices.append(route_index)
		targets.append(sample.point)
	for first_index in range(targets.size()):
		for second_index in range(first_index + 1, targets.size()):
			var first_xz := Vector2(targets[first_index].x, targets[first_index].z)
			var second_xz := Vector2(targets[second_index].x, targets[second_index].z)
			if first_xz.distance_to(second_xz) < mechanism_data.glyph_radius * 1.2:
				return PackedVector3Array()
			var first_direction := (targets[first_index] - anchor.surface_point).normalized()
			var second_direction := (targets[second_index] - anchor.surface_point).normalized()
			if first_direction.dot(second_direction) > 0.94:
				return PackedVector3Array()
	return targets


static func _uphill_witness(
		layout: GeneratedStageLayout,
		mechanism_data: MechanismData,
		anchor: MechanismGlyphAnchor
) -> Dictionary:
	var best_rise := -INF
	var best_point := Vector3.ZERO
	for sample_index in range(12):
		var angle := TAU * float(sample_index) / 12.0
		var local_xz := anchor.local_xz \
				+ Vector2.from_angle(angle) * mechanism_data.uphill_sample_distance
		var sample := layout.surface_sample_at_local(local_xz.x, local_xz.y, false)
		if sample.is_empty():
			continue
		var rise := float(sample.point.y) - anchor.surface_point.y
		if rise > best_rise:
			best_rise = rise
			best_point = sample.point
	var delta := best_point - anchor.surface_point
	var tangent := delta - anchor.surface_normal * delta.dot(anchor.surface_normal)
	if tangent.is_zero_approx():
		return {}
	return {"tangent": tangent.normalized(), "rise": best_rise}


static func _splitter_divergence_score(origin: Vector3, targets: PackedVector3Array) -> float:
	var score := 0.0
	for first_index in range(targets.size()):
		for second_index in range(first_index + 1, targets.size()):
			var a := (targets[first_index] - origin).normalized()
			var b := (targets[second_index] - origin).normalized()
			score += 1.0 - a.dot(b)
	return score


static func _assign_candidates(
		order_index: int,
		request_order: Array[Dictionary],
		candidate_sets: Array,
		selected: Array,
		used_anchor_ids: Dictionary,
		maximum_view_rank: int,
		maximum_readability_rank: int
) -> bool:
	if order_index >= request_order.size():
		return true
	var request_index := int(request_order[order_index].request_index)
	for candidate: Dictionary in candidate_sets[request_index]:
		if int(candidate.view_rank) > maximum_view_rank:
			continue
		if int(candidate.readability_rank) > maximum_readability_rank:
			continue
		if used_anchor_ids.has(candidate.anchor_id):
			continue
		var placement := candidate.placement as MechanismPlacement
		if not _separated_from_selected(placement, selected):
			continue
		selected[request_index] = candidate
		used_anchor_ids[candidate.anchor_id] = true
		if _assign_candidates(
			order_index + 1,
			request_order,
			candidate_sets,
			selected,
			used_anchor_ids,
			maximum_view_rank,
			maximum_readability_rank
		):
			return true
		used_anchor_ids.erase(candidate.anchor_id)
		selected[request_index] = null
	return false


static func _all_requests_have_candidates_within_ranks(
		candidate_sets: Array,
		maximum_view_rank: int,
		maximum_readability_rank: int
) -> bool:
	for candidates: Array in candidate_sets:
		var has_candidate := false
		for candidate: Dictionary in candidates:
			if int(candidate.view_rank) <= maximum_view_rank \
					and int(candidate.readability_rank) <= maximum_readability_rank:
				has_candidate = true
				break
		if not has_candidate:
			return false
	return true


static func _separated_from_selected(
		candidate: MechanismPlacement,
		selected: Array
) -> bool:
	for entry in selected:
		if entry == null:
			continue
		var existing := entry.placement as MechanismPlacement
		var required := candidate.mechanism_data.glyph_radius \
				+ existing.mechanism_data.glyph_radius + GLYPH_SEPARATION_MARGIN
		if candidate.local_xz.distance_to(existing.local_xz) < required:
			return false
	return true


static func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a.view_rank) != int(b.view_rank):
		return int(a.view_rank) < int(b.view_rank)
	if int(a.readability_rank) != int(b.readability_rank):
		return int(a.readability_rank) < int(b.readability_rank)
	if not is_equal_approx(float(a.score), float(b.score)):
		return float(a.score) > float(b.score)
	if not is_equal_approx(float(a.view_distance), float(b.view_distance)):
		return float(a.view_distance) < float(b.view_distance)
	return String(a.anchor_id) < String(b.anchor_id)


static func _build_aim_view_context(
		stage_data: StageData,
		layout: GeneratedStageLayout
) -> Dictionary:
	var world_points := _playable_top_world_points(stage_data, layout)
	if world_points.is_empty():
		return {}
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for point in world_points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	minimum.y = minf(
		minimum.y,
		stage_data.terrain_center.y + TerrainGeometryFactory.DEFAULT_BASE_Y
	)
	var terrain_bounds := AABB(minimum, maximum - minimum)
	if not terrain_bounds.has_volume():
		return {}
	var composed := AimCameraComposer.compose(
		world_points,
		terrain_bounds,
		stage_data.cannon_transform,
		AIM_VIEW_VERTICAL_FOV_DEGREES,
		AIM_VIEW_ASPECT_RATIO
	)
	if composed.is_empty():
		return {}
	var camera_position := Vector3(composed.position)
	var camera_target := Vector3(composed.focus)
	var forward := (camera_target - camera_position).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	if forward.is_zero_approx() or right.is_zero_approx() or up.is_zero_approx():
		return {}
	var context := {
		"camera_position": camera_position,
		"camera_target": camera_target,
		"forward": forward,
		"right": right,
		"up": up,
		"vertical_tangent": tan(deg_to_rad(AIM_VIEW_VERTICAL_FOV_DEGREES * 0.5)),
	}
	context["horizontal_tangent"] = float(context.vertical_tangent) \
			* AIM_VIEW_ASPECT_RATIO
	var top_ndc := -INF
	var bottom_ndc := INF
	for point in world_points:
		var vertical_ndc := _projected_vertical_ndc(point, context)
		if not is_finite(vertical_ndc):
			continue
		top_ndc = maxf(top_ndc, vertical_ndc)
		bottom_ndc = minf(bottom_ndc, vertical_ndc)
	if not is_finite(top_ndc) or not is_finite(bottom_ndc) \
			or top_ndc - bottom_ndc <= 0.0001:
		return {}
	context["top_ndc"] = clampf(top_ndc, -1.0, 1.0)
	context["bottom_ndc"] = clampf(bottom_ndc, -1.0, 1.0)
	if float(context.top_ndc) - float(context.bottom_ndc) <= 0.0001:
		return {}
	return context


static func _playable_top_world_points(
		stage_data: StageData,
		layout: GeneratedStageLayout
) -> PackedVector3Array:
	if stage_data == null or layout == null or layout.top_topology == null:
		return PackedVector3Array()
	var topology := layout.top_topology
	var vertices := topology.canonical_vertices_read_only()
	var indices := topology.canonical_triangle_indices_read_only()
	var seen: Dictionary = {}
	var world_points := PackedVector3Array()
	for source_index in indices:
		if seen.has(source_index):
			continue
		seen[source_index] = true
		world_points.append(stage_data.terrain_center + vertices[source_index])
	return world_points


static func _aim_view_vertical_fraction(
		world_point: Vector3,
		aim_view: Dictionary
) -> float:
	if aim_view.is_empty():
		return INF
	var vertical_ndc := _projected_vertical_ndc(world_point, aim_view)
	if not is_finite(vertical_ndc):
		return INF
	return inverse_lerp(
		float(aim_view.top_ndc),
		float(aim_view.bottom_ndc),
		vertical_ndc
	)


static func _projected_vertical_ndc(
		world_point: Vector3,
		aim_view: Dictionary
) -> float:
	var relative := world_point - Vector3(aim_view.camera_position)
	var depth := relative.dot(Vector3(aim_view.forward))
	var vertical_tangent := float(aim_view.vertical_tangent)
	if depth <= 0.01 or vertical_tangent <= 0.0:
		return INF
	return relative.dot(Vector3(aim_view.up)) / (depth * vertical_tangent)


static func _projected_horizontal_ndc(
		world_point: Vector3,
		aim_view: Dictionary
) -> float:
	var relative := world_point - Vector3(aim_view.camera_position)
	var depth := relative.dot(Vector3(aim_view.forward))
	var horizontal_tangent := float(aim_view.horizontal_tangent)
	if depth <= 0.01 or horizontal_tangent <= 0.0:
		return INF
	return relative.dot(Vector3(aim_view.right)) / (depth * horizontal_tangent)


static func _glyph_horizontal_extent_ndc(
		stage_data: StageData,
		layout: GeneratedStageLayout,
		placement: MechanismPlacement,
		aim_view: Dictionary
) -> float:
	if stage_data == null or layout == null or placement == null \
			or placement.mechanism_data == null:
		return INF
	var maximum_extent := 0.0
	var radius := placement.mechanism_data.glyph_radius
	for sample_index in range(FOOTPRINT_SAMPLE_COUNT):
		var angle := TAU * float(sample_index) / float(FOOTPRINT_SAMPLE_COUNT)
		var planar := Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)
		var surface_guess := placement.local_transform * planar
		var sample := layout.surface_sample_at_local(
			surface_guess.x, surface_guess.z, false
		)
		if sample.is_empty():
			return INF
		var horizontal_ndc := _projected_horizontal_ndc(
			stage_data.terrain_center + Vector3(sample.point), aim_view
		)
		if not is_finite(horizontal_ndc):
			return INF
		maximum_extent = maxf(maximum_extent, absf(horizontal_ndc))
	return maximum_extent


static func _projected_horizontal_pixels(
		camera_position: Vector3,
		camera_target: Vector3,
		world_point: Vector3,
		diameter: float
) -> float:
	var forward := (camera_target - camera_position).normalized()
	var depth := (world_point - camera_position).dot(forward)
	if depth <= 0.01:
		return 0.0
	return diameter / (2.0 * tan(deg_to_rad(25.0)) * depth) * 1280.0
