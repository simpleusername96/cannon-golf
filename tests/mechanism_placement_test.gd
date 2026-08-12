extends SceneTree

const BURST_DATA: MechanismData = preload("res://resources/mechanisms/burst_node.tres")
const SPLITTER_DATA: MechanismData = preload("res://resources/mechanisms/splitter_node.tres")
const UPHILL_DATA: MechanismData = preload("res://resources/mechanisms/uphill_rebound_node.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_assert_shared_radius_contract()
	var first_fixture := _three_route_fixture(TerrainTestFixtureFactory.Kind.RAMP)
	var repeated_fixture := _three_route_fixture(TerrainTestFixtureFactory.Kind.RAMP)
	var stage := first_fixture.stage as StageData
	var first := first_fixture.layout as GeneratedStageLayout
	var repeated := repeated_fixture.layout as GeneratedStageLayout
	var placements := MechanismPlacementGenerator.generate(stage, first)
	var repeated_placements := MechanismPlacementGenerator.generate(stage, repeated)
	_assert_true(placements.size() == 3, "three generic anchors must admit the three typed glyphs")
	_assert_true(repeated_placements.size() == placements.size(), "generic assignment must be deterministic")
	if placements.size() == 3 and repeated_placements.size() == 3:
		_assert_placement_contract(first, placements, repeated_placements)
		_assert_placement_checksum_contract(first, placements)
	_assert_surface_candidates_are_not_legacy_pads(first, placements)
	_assert_gentle_uphill_is_ranked_without_a_minimum_rise_gate()
	_assert_aim_view_middle_is_preferred()
	_assert_count_cap()
	print("Phase 4 generic glyph placement passed")
	quit(1 if _failed else 0)


func _assert_shared_radius_contract() -> void:
	for data in [BURST_DATA, SPLITTER_DATA, UPHILL_DATA]:
		_assert_true(
			is_equal_approx(MechanismPlacementGenerator.effective_collision_radius(data.kind), data.glyph_radius),
			"compatibility radius must resolve the typed glyph footprint"
		)
		_assert_true(
			is_equal_approx(MechanismPlacementGenerator.effective_visual_diameter(data.kind), data.glyph_radius * 2.0),
			"render diameter must derive from the same typed glyph radius"
		)


func _assert_placement_contract(
		layout: GeneratedStageLayout,
		placements: Array[MechanismPlacement],
		repeated: Array[MechanismPlacement]
) -> void:
	var by_kind: Dictionary = {}
	for index in range(placements.size()):
		var placement := placements[index]
		by_kind[int(placement.mechanism_data.canonical_kind())] = placement
		_assert_true(String(placement.anchor_id).begins_with("surface/"), "placement must retain its canonical surface anchor identity")
		_assert_true(placement.local_transform.is_equal_approx(repeated[index].local_transform), "same layout must repeat the same transform")
		var radius := placement.mechanism_data.glyph_radius
		_assert_true(layout.local_bounds.grow(-radius).has_point(placement.local_xz), "glyph footprint must remain inside terrain bounds")
		for other in placements:
			if other == placement:
				continue
			_assert_true(
				placement.local_xz.distance_to(other.local_xz) >= radius + other.mechanism_data.glyph_radius,
				"glyph footprints must not overlap"
			)
	var splitter := by_kind.get(int(MechanismData.Kind.SPLITTER)) as MechanismPlacement
	_assert_true(splitter != null and splitter.splitter_route_targets.size() == 3, "Splitter placement must store three route witnesses")
	if splitter != null:
		var unique_targets: Dictionary = {}
		for target in splitter.splitter_route_targets:
			unique_targets[Vector2(target.x, target.z).snapped(Vector2.ONE)] = true
		_assert_true(unique_targets.size() == 3, "Splitter route witnesses must be visibly distinct")
	var uphill := by_kind.get(int(MechanismData.Kind.UPHILL_REBOUND)) as MechanismPlacement
	_assert_true(uphill != null and not uphill.uphill_tangent.is_zero_approx(), "Uphill Rebound must store an authoritative ascent tangent")
	if uphill != null:
		_assert_uphill_tangent_is_local_maximum(layout, uphill)


func _assert_placement_checksum_contract(
		layout: GeneratedStageLayout,
		placements: Array[MechanismPlacement]
) -> void:
	layout.mechanism_placements = placements
	var baseline := layout.placement_checksum()
	_assert_true(baseline != 0, "complete glyph placement data must produce a checksum")

	var anchor := placements[0]
	var original_anchor_id := anchor.anchor_id
	anchor.anchor_id = StringName("%s/changed" % String(original_anchor_id))
	_assert_true(layout.placement_checksum() != baseline, "anchor identity must participate in the placement checksum")
	anchor.anchor_id = original_anchor_id

	var splitter: MechanismPlacement
	var uphill: MechanismPlacement
	for placement in placements:
		if placement.mechanism_data.canonical_kind() == MechanismData.Kind.SPLITTER:
			splitter = placement
		elif placement.mechanism_data.canonical_kind() == MechanismData.Kind.UPHILL_REBOUND:
			uphill = placement
	if splitter != null:
		var original_targets := splitter.splitter_route_targets.duplicate()
		var changed_targets := original_targets.duplicate()
		changed_targets[0] += Vector3(1.0, 0.0, 0.0)
		splitter.splitter_route_targets = changed_targets
		_assert_true(layout.placement_checksum() != baseline, "Splitter route witnesses must participate in the placement checksum")
		splitter.splitter_route_targets = original_targets
	if uphill != null:
		var original_tangent := uphill.uphill_tangent
		uphill.uphill_tangent = -original_tangent
		_assert_true(layout.placement_checksum() != baseline, "uphill tangent must participate in the placement checksum")
		uphill.uphill_tangent = original_tangent
	_assert_true(layout.placement_checksum() == baseline, "restored glyph placement data must restore the checksum")


func _assert_surface_candidates_are_not_legacy_pads(
		layout: GeneratedStageLayout,
		placements: Array[MechanismPlacement]
) -> void:
	var legacy_pads := layout.route_graph.pad_nodes()
	for placement in placements:
		for pad in legacy_pads:
			_assert_true(
				not placement.local_xz.is_equal_approx(Vector2(pad.position.x, pad.position.z)),
				"canonical surface anchors must not reuse legacy pad coordinates"
			)


func _assert_gentle_uphill_is_ranked_without_a_minimum_rise_gate() -> void:
	var fixture := _three_route_fixture(TerrainTestFixtureFactory.Kind.RAMP)
	var stage := fixture.stage as StageData
	var layout := fixture.layout as GeneratedStageLayout
	var gentle_uphill := UPHILL_DATA.duplicate() as MechanismData
	gentle_uphill.uphill_sample_distance = 0.25
	stage.mechanism_loadout = [gentle_uphill]
	var placements := MechanismPlacementGenerator.generate(stage, layout)
	_assert_true(placements.size() == 1, "Uphill Rebound must rank a positive local ascent below its legacy minimum rise")
	if placements.size() == 1:
		_assert_uphill_tangent_is_local_maximum(layout, placements[0], 0.25)


func _assert_uphill_tangent_is_local_maximum(
		layout: GeneratedStageLayout,
		uphill: MechanismPlacement,
		sample_distance: float = UPHILL_DATA.uphill_sample_distance
) -> void:
	var start_height := layout.height_at_local(uphill.local_xz.x, uphill.local_xz.y)
	var tangent_direction := Vector2(uphill.uphill_tangent.x, uphill.uphill_tangent.z).normalized()
	var tangent_height := layout.height_at_local(
		uphill.local_xz.x + tangent_direction.x * sample_distance,
		uphill.local_xz.y + tangent_direction.y * sample_distance
	)
	var highest_height := -INF
	for sample_index in range(12):
		var angle := TAU * float(sample_index) / 12.0
		var probe := uphill.local_xz + Vector2.from_angle(angle) * sample_distance
		highest_height = maxf(highest_height, layout.height_at_local(probe.x, probe.y))
	_assert_true(tangent_height > start_height, "stored uphill tangent must point toward higher terrain")
	_assert_true(is_equal_approx(tangent_height, highest_height), "stored uphill tangent must point toward the locally highest ascent")


func _assert_count_cap() -> void:
	var fixture := _three_route_fixture(TerrainTestFixtureFactory.Kind.RAMP)
	var stage := fixture.stage as StageData
	stage.mechanism_loadout = [
		BURST_DATA, BURST_DATA, BURST_DATA, BURST_DATA,
		BURST_DATA, BURST_DATA, BURST_DATA,
	]
	_assert_true(MechanismPlacementGenerator.generate(stage, fixture.layout).is_empty(), "placement must preserve the six-glyph stage cap")


func _assert_aim_view_middle_is_preferred() -> void:
	var fixture := _three_route_fixture(TerrainTestFixtureFactory.Kind.RAMP)
	var stage := fixture.stage as StageData
	var layout := fixture.layout as GeneratedStageLayout
	stage.mechanism_loadout = [BURST_DATA]
	var placements := MechanismPlacementGenerator.generate(stage, layout)
	_assert_true(placements.size() == 1, "Aim View preference fixture must place Burst")
	if placements.is_empty():
		return
	var aim_view := MechanismLoadoutPlanner._build_aim_view_context(stage, layout)
	var view_fraction := MechanismLoadoutPlanner._aim_view_vertical_fraction(
		stage.terrain_center + placements[0].local_transform.origin,
		aim_view
	)
	_assert_true(
		view_fraction >= MechanismLoadoutPlanner.PREFERRED_VIEW_BAND_MINIMUM \
				and view_fraction <= MechanismLoadoutPlanner.PREFERRED_VIEW_BAND_MAXIMUM,
		"a suitable Burst glyph must prefer the middle of the projected Aim View terrain silhouette"
	)


func _three_route_fixture(kind: TerrainTestFixtureFactory.Kind) -> Dictionary:
	var layout := TerrainTestFixtureFactory.build_layout(kind)
	layout.route_graph = _three_route_graph(layout)
	var stage := StageData.new()
	stage.stage_id = &"generic_glyph_fixture"
	stage.terrain_center = Vector3.ZERO
	stage.cannon_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 30.0, 25.0))
	stage.aiming_camera_position = Vector3(34, 32, 34)
	stage.aiming_camera_target = Vector3.ZERO
	stage.briefing_camera_position = Vector3(-34, 38, 34)
	stage.briefing_camera_target = Vector3.ZERO
	stage.mechanism_loadout = [UPHILL_DATA, BURST_DATA, SPLITTER_DATA]
	_assert_true(layout.is_valid(), "synthetic three-route glyph layout must be structurally valid")
	return {"stage": stage, "layout": layout}


func _three_route_graph(layout: GeneratedStageLayout) -> GeneratedRouteGraph:
	var stage_id := &"generic_glyph_fixture"
	var summit_id := GeneratedRouteNode.summit_id(stage_id)
	var summit_xz := Vector2(0, -14)
	var summit := GeneratedRouteNode.new(
		summit_id,
		Vector3(summit_xz.x, layout.height_at_local(summit_xz.x, summit_xz.y), summit_xz.y),
		-1,
		0,
		GeneratedRouteNode.Kind.SUMMIT
	)
	var nodes: Array[GeneratedRouteNode] = [summit]
	var edges: Array[GeneratedRouteEdge] = []
	var pad_points := [Vector2(-9, -7), Vector2(0, 8), Vector2(9, -7)]
	var exit_points := [Vector2(-12, 14), Vector2(0, 14), Vector2(12, 14)]
	var roles := [StageRouteProfile.Role.SAFE, StageRouteProfile.Role.SPLITTER, StageRouteProfile.Role.BUMPER]
	for route_index in range(3):
		var pad_xz: Vector2 = pad_points[route_index]
		var exit_xz: Vector2 = exit_points[route_index]
		var pad_id := StringName("%s/route/%d/generic_anchor" % [stage_id, route_index])
		var exit_id := GeneratedRouteNode.route_node_id(stage_id, route_index, 2)
		var pad := GeneratedRouteNode.new(
			pad_id,
			Vector3(pad_xz.x, layout.height_at_local(pad_xz.x, pad_xz.y), pad_xz.y),
			route_index,
			1,
			GeneratedRouteNode.Kind.PAD,
			int(MechanismData.Kind.BURST),
			7.0
		)
		var exit := GeneratedRouteNode.new(
			exit_id,
			Vector3(exit_xz.x, layout.height_at_local(exit_xz.x, exit_xz.y), exit_xz.y),
			route_index,
			2,
			GeneratedRouteNode.Kind.EXIT
		)
		nodes.append(pad)
		nodes.append(exit)
		edges.append(GeneratedRouteEdge.new(
			GeneratedRouteEdge.stable_id(stage_id, route_index, 0, &"anchor"),
			summit_id,
			pad_id,
			route_index,
			0,
			roles[route_index],
			12.0
		))
		edges.append(GeneratedRouteEdge.new(
			GeneratedRouteEdge.stable_id(stage_id, route_index, 1, &"exit"),
			pad_id,
			exit_id,
			route_index,
			1,
			roles[route_index],
			12.0
		))
	return GeneratedRouteGraph.new(nodes, edges)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Mechanism placement check failed: %s" % message)
