class_name TerrainTestFixtureFactory
extends RefCounted

enum Kind {
	FLAT,
	RAMP,
	FACETED,
}

const CELL_COUNT := Vector2i(12, 12)
const BOUNDS := Rect2(Vector2(-15.0, -15.0), Vector2(30.0, 30.0))


static func build_layout(kind: Kind) -> GeneratedStageLayout:
	var layout := GeneratedStageLayout.new()
	layout.profile_id = &"terrain_test_fixture"
	layout.profile_version = StageGenerationContract.CONTRACT_VERSION
	layout.layout_version = StageGenerationContract.CONTRACT_VERSION
	layout.terrain_seed = int(kind) + 1
	layout.cell_count = CELL_COUNT
	layout.local_bounds = BOUNDS
	layout.heights = PackedFloat32Array()
	layout.heights.resize((CELL_COUNT.x + 1) * (CELL_COUNT.y + 1))
	for z_index in range(CELL_COUNT.y + 1):
		for x_index in range(CELL_COUNT.x + 1):
			var x := lerpf(BOUNDS.position.x, BOUNDS.end.x, float(x_index) / float(CELL_COUNT.x))
			var z := lerpf(BOUNDS.position.y, BOUNDS.end.y, float(z_index) / float(CELL_COUNT.y))
			var height := 0.0
			if kind == Kind.RAMP:
				height = ramp_height(x)
			elif kind == Kind.FACETED:
				height = facet_height(x_index, z_index, x, z)
			layout.heights[z_index * (CELL_COUNT.x + 1) + x_index] = height
	var footprint := PackedByteArray()
	footprint.resize(CELL_COUNT.x * CELL_COUNT.y)
	footprint.fill(1)
	assert(layout.install_footprint(footprint), "Terrain test fixture must install its full footprint.")
	layout.top_topology = TerrainTopTopology.build(
		layout.cell_count, layout.local_bounds, layout.heights, footprint
	)
	var summit_id := GeneratedRouteNode.summit_id(&"terrain_test_fixture")
	var exit_id := GeneratedRouteNode.route_node_id(&"terrain_test_fixture", 0, 1)
	var summit := GeneratedRouteNode.new(
		summit_id,
		Vector3(0.0, layout.height_at_local(0.0, -10.0), -10.0),
		-1,
		0,
		GeneratedRouteNode.Kind.SUMMIT
	)
	var exit := GeneratedRouteNode.new(
		exit_id,
		Vector3(0.0, layout.height_at_local(0.0, 10.0), 10.0),
		0,
		1,
		GeneratedRouteNode.Kind.EXIT
	)
	var edge := GeneratedRouteEdge.new(
		GeneratedRouteEdge.stable_id(&"terrain_test_fixture", 0, 0),
		summit_id,
		exit_id,
		0,
		0,
		StageRouteProfile.Role.PRIMARY,
		10.0
	)
	layout.route_graph = GeneratedRouteGraph.new([summit, exit], [edge])
	layout.play_bounds = PlayBoundsSpec.new()
	return layout


static func install_target_mask_with_coverage(
		layout: GeneratedStageLayout,
		target_mask: PackedByteArray
) -> bool:
	if layout == null or layout.top_topology == null \
			or not layout.install_target_mask(
				target_mask, TargetMaskRasterizer.byte_checksum(target_mask)
			):
		return false
	var total_area := TargetSurfaceCoverage.total_target_surface_area(
		target_mask,
		layout.top_topology,
		layout.local_bounds,
		StageGenerationContract.REQUIRED_MASK_SIZE
	)
	return layout.install_target_surface_coverage(
		TargetSurfaceCoverage.METRIC_VERSION,
		total_area,
		TargetSurfaceCoverage.metadata_checksum(
			TargetSurfaceCoverage.METRIC_VERSION, total_area
		)
	)


static func ramp_height(x: float) -> float:
	return tan(deg_to_rad(35.0)) * (x + 15.0)


static func facet_height(sample_x: int, sample_z: int, local_x: float, local_z: float) -> float:
	var keyed_offset := float((sample_x * 7 + sample_z * 11) % 5) * 0.35
	return 0.12 * local_x + 0.08 * local_z + keyed_offset
