extends SceneTree

const STAGES: Array[StageData] = [
	preload("res://resources/stages/first_descent.tres"),
	preload("res://resources/stages/burst_basin.tres"),
	preload("res://resources/stages/split_ridge.tres"),
]
const BOUNDARY_EPSILON := 0.001

var _failed := false


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	for stage in STAGES:
		_assert_stage(stage)
	if not _failed:
		print("Phase 8.1 terrain contract passed: every mountain is a connected, closed 3D mass shared by rendering and collision.")
	quit(1 if _failed else 0)


func _assert_stage(stage: StageData) -> void:
	var layout := SeededStageGenerator.generate(
		stage.generation_profile,
		stage.terrain_seed,
		stage
	)
	_assert_true(layout != null, "%s production layout must generate" % stage.stage_id)
	if layout == null:
		return
	_assert_connected_row_solid_footprint(stage, layout)
	_assert_zero_height_front_boundary(stage, layout)
	_assert_shared_closed_geometry(stage, layout)


func _assert_connected_row_solid_footprint(
		stage: StageData,
		layout: GeneratedStageLayout
) -> void:
	var cells := layout.footprint_cells_read_only()
	var size := layout.cell_count
	var previous_left := -1
	var previous_right := -1
	var maximum_span := 0
	var final_span := 0
	for cell_z in range(size.y):
		var left := -1
		var right := -1
		var span_ended := false
		for cell_x in range(size.x):
			var active := cells[cell_z * size.x + cell_x] != 0
			if active:
				_assert_true(
					not span_ended,
					"%s row %d must contain one solid span" % [stage.stage_id, cell_z]
				)
				if left < 0:
					left = cell_x
				right = cell_x
			elif left >= 0:
				span_ended = true
		_assert_true(left >= 0, "%s footprint row %d must be active" % [stage.stage_id, cell_z])
		if left < 0:
			continue
		if previous_left >= 0:
			_assert_true(
				left <= previous_right and right >= previous_left,
				"%s rows %d and %d must overlap" % [stage.stage_id, cell_z - 1, cell_z]
			)
		var span := right - left + 1
		maximum_span = maxi(maximum_span, span)
		if cell_z == size.y - 1:
			final_span = span
		previous_left = left
		previous_right = right
	_assert_true(final_span > 0, "%s footprint must reach its final front row" % stage.stage_id)
	_assert_true(
		final_span < maximum_span,
		"%s final front row must taper below the mountain's widest row" % stage.stage_id
	)


func _assert_zero_height_front_boundary(
		stage: StageData,
		layout: GeneratedStageLayout
) -> void:
	var topology := layout.top_topology
	var boundary_edges := topology.boundary_edges_read_only()
	var front_vertex_count := 0
	for source_vertex_index in boundary_edges:
		var vertex := topology.vertex_at(source_vertex_index)
		if not is_equal_approx(vertex.z, layout.local_bounds.end.y):
			continue
		front_vertex_count += 1
		_assert_true(
			absf(vertex.y) <= BOUNDARY_EPSILON,
			"%s front top boundary vertex must meet y=0; got %.6f" % [
				stage.stage_id,
				vertex.y,
			]
		)
	_assert_true(
		front_vertex_count > 0,
		"%s topology must expose a front boundary at the full local bound" % stage.stage_id
	)


func _assert_shared_closed_geometry(
		stage: StageData,
		layout: GeneratedStageLayout
) -> void:
	var geometry := TerrainGeometryFactory.build(layout)
	_assert_true(geometry.is_valid(), "%s terrain geometry must remain valid" % stage.stage_id)
	_assert_true(
		geometry.top_topology == layout.top_topology,
		"%s render and collision must share the layout's canonical top topology" % stage.stage_id
	)
	_assert_true(
		geometry.render_mesh.get_surface_count() == 1,
		"%s closed terrain must remain one render surface" % stage.stage_id
	)
	var render_vertices: PackedVector3Array = \
			geometry.render_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top_faces := geometry.top_shape.get_faces()
	var shell_faces := geometry.skirt_shape.get_faces()
	_assert_true(
		top_faces.size() == geometry.top_vertex_count,
		"%s top collision must contain every rendered top corner" % stage.stage_id
	)
	_assert_true(
		shell_faces.size() == geometry.shell_vertex_count,
		"%s shell collision must contain every rendered shell corner" % stage.stage_id
	)
	_assert_true(
		render_vertices.size() == top_faces.size() + shell_faces.size(),
		"%s render mesh must be the shared top plus closed shell" % stage.stage_id
	)
	for corner_index in range(top_faces.size()):
		var source_index := geometry.top_render_source_vertex_indices[corner_index]
		_assert_true(
			render_vertices[corner_index].is_equal_approx(
				layout.top_topology.vertex_at(source_index)
			),
			"%s rendered top corners must map to canonical topology vertices" % stage.stage_id
		)
	for corner_index in range(shell_faces.size()):
		_assert_true(
			render_vertices[top_faces.size() + corner_index].is_equal_approx(
				shell_faces[corner_index]
			),
			"%s rendered and colliding shell corners must match" % stage.stage_id
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Phase 8.1 front transition check failed: %s" % message)
