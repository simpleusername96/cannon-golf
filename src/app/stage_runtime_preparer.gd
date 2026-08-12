class_name StageRuntimePreparer
extends Node

signal artifact_progress(stage_id: StringName, phase: StringName, progress: float)
signal artifact_ready(stage_id: StringName, artifact: StageRuntimeArtifact)
signal artifact_failed(stage_id: StringName)

const MAX_CACHED_ARTIFACTS := 3
const WEB_AND_DEVELOPMENT_STEP_BUDGET_USEC := 8000
const NATIVE_RELEASE_STEP_BUDGET_USEC := 12000
const MASK_SIZE := 512
const PREVIEW_MASK_SIZE := 96
const SURFACE_SAMPLE_UNKNOWN := 0
const SURFACE_SAMPLE_INACTIVE := 1
const SURFACE_SAMPLE_ACTIVE := 2
const PAINT_SURFACE_TUNING := preload(
	"res://resources/paint/default_paint_surface_tuning.tres"
)

enum Phase {
	COPY_LAYOUT,
	START_GEOMETRY,
	BUILD_GEOMETRY,
	BUILD_PLAYABLE_POINTS,
	BUILD_PRESENTATION_POINTS,
	INIT_DRESSING,
	BUILD_DRESSING,
	PRELOAD_DRESSING,
	INIT_PAINT,
	BUILD_TOPOLOGY,
	BUILD_X_AXIS,
	BUILD_Y_AXIS,
	CREATE_TARGET_IMAGE,
	CREATE_TARGET_TEXTURE,
	INIT_PREVIEW_PAINT,
	BUILD_PREVIEW_PAINT,
	CREATE_PREVIEW_TEXTURE,
	COMPLETE,
}

var _selected_job: Dictionary = {}
var _prefetch_job: Dictionary = {}
var _artifact_cache: Dictionary = {}
var _least_recently_used: Array[StringName] = []
var _geometry_job_starts: Dictionary = {}


func _process(_delta: float) -> void:
	var selected := not _selected_job.is_empty()
	if not selected and _prefetch_job.is_empty():
		return
	var step_budget_usec := _step_budget_usec()
	var started_at := Time.get_ticks_usec()
	while not (_selected_job if selected else _prefetch_job).is_empty():
		var elapsed := int(Time.get_ticks_usec() - started_at)
		if elapsed >= step_budget_usec:
			break
		_advance_job(selected, step_budget_usec - elapsed)


func _step_budget_usec() -> int:
	if OS.has_feature("web") or OS.has_feature("editor"):
		return WEB_AND_DEVELOPMENT_STEP_BUDGET_USEC
	return NATIVE_RELEASE_STEP_BUDGET_USEC


func request_artifact(
		stage: StageData,
		layout: GeneratedStageLayout,
		selected: bool = true
) -> bool:
	if stage == null or layout == null or not layout.matches_stage_identity(stage) \
			or not layout.is_runtime_ready():
		if stage != null and selected:
			artifact_failed.emit(stage.stage_id)
		return false
	if ready_artifact(stage) != null:
		return true
	if _job_matches(_selected_job, stage, layout) \
			or _job_matches(_prefetch_job, stage, layout):
		return false
	var job := _new_job(stage, layout)
	RuntimeDeliveryTelemetry.emit_marker(&"artifact_prepare_started", {
		"stage_id": String(stage.stage_id),
		"selected": selected,
	})
	if selected:
		_selected_job = job
	else:
		_prefetch_job = job
	return false


func ready_artifact(stage: StageData) -> StageRuntimeArtifact:
	if stage == null:
		return null
	var artifact := _artifact_cache.get(stage.stage_id) as StageRuntimeArtifact
	if artifact == null or not artifact.is_complete_for(stage, PAINT_SURFACE_TUNING, MASK_SIZE):
		_artifact_cache.erase(stage.stage_id)
		_least_recently_used.erase(stage.stage_id)
		return null
	_touch(stage.stage_id)
	return artifact


func is_preparing(stage_id: StringName) -> bool:
	return _job_stage_id(_selected_job) == stage_id or _job_stage_id(_prefetch_job) == stage_id


func cached_artifact_count() -> int:
	return _artifact_cache.size()


func geometry_job_start_count(stage_id: StringName) -> int:
	return int(_geometry_job_starts.get(stage_id, 0))


func cancel_except(stage_id: StringName) -> void:
	if not _selected_job.is_empty() and _job_stage_id(_selected_job) != stage_id:
		_selected_job = {}
	if not _prefetch_job.is_empty() and _job_stage_id(_prefetch_job) != stage_id:
		_prefetch_job = {}


func _new_job(stage: StageData, layout: GeneratedStageLayout) -> Dictionary:
	return {
		"stage": stage,
		"source_layout": layout,
		"phase": Phase.COPY_LAYOUT,
		"artifact": StageRuntimeArtifact.new(),
		"geometry_job": null,
		"playable_cell_cursor": 0,
		"playable_seen": PackedByteArray(),
		"playable_points": PackedVector3Array(),
		"dressing_cursor": 0,
		"dressing_model_ids": [],
		"dressing_model_cursor": 0,
		"topology_cursor": 0,
		"axis_cursor": 0,
		"preview_cursor": 0,
		"preview_bytes": PackedByteArray(),
		"started_at_usec": Time.get_ticks_usec(),
		"max_slice_usec": 0,
	}


func _advance_job(selected: bool, budget_usec: int) -> void:
	var slice_started_at := Time.get_ticks_usec()
	var job: Dictionary = _selected_job if selected else _prefetch_job
	var stage := job.get("stage") as StageData
	if stage == null:
		_finish_failure(selected, &"")
		return
	var phase := int(job.get("phase", Phase.COPY_LAYOUT))
	match phase:
		Phase.COPY_LAYOUT:
			var source := job.get("source_layout") as GeneratedStageLayout
			var runtime_layout := source.copy_for_runtime() if source != null else null
			var artifact := job.get("artifact") as StageRuntimeArtifact
			if runtime_layout == null or not artifact.install_identity(stage, runtime_layout):
				_finish_failure(selected, stage.stage_id)
				return
			artifact.runtime_layout = runtime_layout
			job.phase = Phase.START_GEOMETRY
		Phase.START_GEOMETRY:
			var artifact := job.get("artifact") as StageRuntimeArtifact
			job.geometry_job = TerrainGeometryFactory.begin_build(artifact.runtime_layout)
			_geometry_job_starts[stage.stage_id] = geometry_job_start_count(stage.stage_id) + 1
			job.phase = Phase.BUILD_GEOMETRY
		Phase.BUILD_GEOMETRY:
			var geometry_job := job.get("geometry_job") as TerrainGeometryBuildJob
			if geometry_job == null:
				_finish_failure(selected, stage.stage_id)
				return
			if geometry_job.step(budget_usec):
				(job.get("artifact") as StageRuntimeArtifact).geometry = geometry_job.result()
				job.phase = Phase.BUILD_PLAYABLE_POINTS
		Phase.BUILD_PLAYABLE_POINTS:
			_build_playable_points(job, budget_usec)
		Phase.BUILD_PRESENTATION_POINTS:
			var artifact := job.get("artifact") as StageRuntimeArtifact
			artifact.playable_local_points = job.get("playable_points", PackedVector3Array())
			artifact.presentation_local_points = TerrainSurface.local_presentation_points(
				artifact.runtime_layout,
				artifact.geometry.render_mesh.get_aabb()
			)
			job.phase = Phase.INIT_DRESSING
		Phase.INIT_DRESSING:
			_init_dressing(job)
		Phase.BUILD_DRESSING:
			if not _build_dressing(job, selected, budget_usec):
				return
		Phase.PRELOAD_DRESSING:
			if not _preload_dressing(job, selected):
				return
		Phase.INIT_PAINT:
			_init_paint(job)
		Phase.BUILD_TOPOLOGY:
			_build_topology(job, budget_usec)
		Phase.BUILD_X_AXIS:
			_build_axis(job, true, budget_usec)
		Phase.BUILD_Y_AXIS:
			_build_axis(job, false, budget_usec)
		Phase.CREATE_TARGET_IMAGE:
			var bootstrap := _bootstrap(job)
			bootstrap.target_image = Image.create_from_data(
				MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, bootstrap.target_bytes
			)
			job.phase = Phase.CREATE_TARGET_TEXTURE
		Phase.CREATE_TARGET_TEXTURE:
			var bootstrap := _bootstrap(job)
			bootstrap.target_texture = ImageTexture.create_from_image(bootstrap.target_image)
			job.phase = Phase.INIT_PREVIEW_PAINT
		Phase.INIT_PREVIEW_PAINT:
			var preview_bytes := PackedByteArray()
			preview_bytes.resize(PREVIEW_MASK_SIZE * PREVIEW_MASK_SIZE)
			preview_bytes.fill(0)
			job.preview_bytes = preview_bytes
			job.preview_cursor = 0
			job.phase = Phase.BUILD_PREVIEW_PAINT
		Phase.BUILD_PREVIEW_PAINT:
			_build_preview_paint(job, budget_usec)
		Phase.CREATE_PREVIEW_TEXTURE:
			var image := Image.create_from_data(
				PREVIEW_MASK_SIZE, PREVIEW_MASK_SIZE, false, Image.FORMAT_L8,
				job.get("preview_bytes", PackedByteArray())
			)
			(job.get("artifact") as StageRuntimeArtifact).preview_paint_texture = \
				ImageTexture.create_from_image(image)
			job.phase = Phase.COMPLETE
		Phase.COMPLETE:
			var artifact := job.get("artifact") as StageRuntimeArtifact
			if not artifact.is_complete_for(stage, PAINT_SURFACE_TUNING, MASK_SIZE):
				_finish_failure(selected, stage.stage_id)
				return
			var current_slice_usec := int(Time.get_ticks_usec() - slice_started_at)
			job.max_slice_usec = maxi(int(job.get("max_slice_usec", 0)), current_slice_usec)
			RuntimeDeliveryTelemetry.emit_marker(&"artifact_prepare_complete", {
				"stage_id": String(stage.stage_id),
				"elapsed_usec": int(Time.get_ticks_usec() - int(job.get("started_at_usec", 0))),
				"max_slice_usec": int(job.max_slice_usec),
			})
			_cache(stage.stage_id, artifact)
			if selected:
				_selected_job = {}
			else:
				_prefetch_job = {}
			artifact_ready.emit(stage.stage_id, artifact)
			return
	job.max_slice_usec = maxi(
		int(job.get("max_slice_usec", 0)),
		int(Time.get_ticks_usec() - slice_started_at)
	)
	artifact_progress.emit(stage.stage_id, Phase.keys()[int(job.phase)], _job_progress(job))
	if int(job.phase) != phase:
		RuntimeDeliveryTelemetry.emit_marker(&"artifact_phase", {
			"stage_id": String(stage.stage_id),
			"phase": Phase.keys()[int(job.phase)],
		})
	if selected:
		_selected_job = job
	else:
		_prefetch_job = job


func _build_playable_points(job: Dictionary, budget_usec: int) -> void:
	var artifact := job.get("artifact") as StageRuntimeArtifact
	var layout := artifact.runtime_layout
	var topology := layout.top_topology
	var cell_total := layout.cell_count.x * layout.cell_count.y
	var cursor := int(job.get("playable_cell_cursor", 0))
	var seen: PackedByteArray = job.get("playable_seen", PackedByteArray())
	if seen.is_empty():
		var sample_size := topology.sample_size()
		seen.resize(sample_size.x * sample_size.y)
		seen.fill(0)
	var points: PackedVector3Array = job.get("playable_points", PackedVector3Array())
	var started_at := Time.get_ticks_usec()
	while cursor < cell_total and Time.get_ticks_usec() - started_at < maxi(budget_usec, 1):
		var cell := Vector2i(cursor % layout.cell_count.x, cursor / layout.cell_count.x)
		if topology.is_cell_active(cell):
			for triangle_in_cell in range(TerrainTopTopology.TRIANGLES_PER_CELL):
				var indices := topology.triangle_vertex_indices(cell, triangle_in_cell)
				for source_index in [indices.x, indices.y, indices.z]:
					if seen[source_index] == 0:
						seen[source_index] = 1
						points.append(topology.vertex_at(source_index))
		cursor += 1
	job.playable_cell_cursor = cursor
	job.playable_seen = seen
	job.playable_points = points
	if cursor >= cell_total:
		job.phase = Phase.BUILD_PRESENTATION_POINTS


func _init_paint(job: Dictionary) -> void:
	var artifact := job.get("artifact") as StageRuntimeArtifact
	var layout := artifact.runtime_layout
	var bootstrap := PaintSurfaceBootstrap.new()
	bootstrap.layout_checksum = layout.checksum
	bootstrap.target_mask_checksum = layout.target_mask_checksum
	bootstrap.world_bounds = (job.get("stage") as StageData).paint_world_bounds()
	bootstrap.terrain_origin_y = (job.get("stage") as StageData).terrain_center.y
	bootstrap.painted_threshold_byte = PAINT_SURFACE_TUNING.painted_threshold_byte
	bootstrap.target_bytes = layout.target_mask
	bootstrap.topology_cell_count = layout.top_topology.cell_count
	var cell_total := bootstrap.topology_cell_count.x * bootstrap.topology_cell_count.y
	bootstrap.topology_cell_cache_states.resize(cell_total)
	bootstrap.topology_cell_cache_states.fill(SURFACE_SAMPLE_UNKNOWN)
	bootstrap.topology_cell_triangle_vertices.resize(
		cell_total * TerrainTopTopology.TRIANGLES_PER_CELL \
				* TerrainTopTopology.CORNERS_PER_TRIANGLE
	)
	bootstrap.topology_cell_triangle_normals.resize(
		cell_total * TerrainTopTopology.TRIANGLES_PER_CELL
	)
	bootstrap.surface_column_cells.resize(MASK_SIZE)
	bootstrap.surface_row_cells.resize(MASK_SIZE)
	bootstrap.surface_column_fractions.resize(MASK_SIZE)
	bootstrap.surface_row_fractions.resize(MASK_SIZE)
	bootstrap.surface_world_x.resize(MASK_SIZE)
	bootstrap.surface_world_z.resize(MASK_SIZE)
	artifact.paint_bootstrap = bootstrap
	job.topology_cursor = 0
	job.phase = Phase.BUILD_TOPOLOGY


func _init_dressing(job: Dictionary) -> void:
	var artifact := job.get("artifact") as StageRuntimeArtifact
	artifact.decoration_placements.clear()
	artifact.decoration_scenes.clear()
	artifact.decoration_checksum = StageRuntimeArtifact.checksum_decorations(
		artifact.runtime_layout.decoration_placements
	)
	job.dressing_cursor = 0
	job.dressing_model_ids = []
	job.dressing_model_cursor = 0
	job.phase = Phase.BUILD_DRESSING


func _build_dressing(job: Dictionary, selected: bool, budget_usec: int) -> bool:
	var artifact := job.get("artifact") as StageRuntimeArtifact
	var source := artifact.runtime_layout.decoration_placements
	var cursor := int(job.get("dressing_cursor", 0))
	var model_ids: Array = job.get("dressing_model_ids", [])
	var started_at := Time.get_ticks_usec()
	while cursor < source.size() and Time.get_ticks_usec() - started_at < maxi(budget_usec, 1):
		var placement := source[cursor]
		if placement == null:
			_finish_failure(selected, artifact.stage_id)
			return false
		artifact.decoration_placements.append(DecorationPlacement.new(
			placement.model_id,
			placement.local_xz,
			placement.yaw_degrees,
			placement.uniform_scale
		))
		if not model_ids.has(placement.model_id):
			model_ids.append(placement.model_id)
		cursor += 1
	job.dressing_cursor = cursor
	job.dressing_model_ids = model_ids
	if cursor >= source.size():
		job.phase = Phase.PRELOAD_DRESSING
	return true


func _preload_dressing(job: Dictionary, selected: bool) -> bool:
	var artifact := job.get("artifact") as StageRuntimeArtifact
	var model_ids: Array = job.get("dressing_model_ids", [])
	var cursor := int(job.get("dressing_model_cursor", 0))
	if cursor >= model_ids.size():
		job.phase = Phase.INIT_PAINT
		return true
	var model_id := StringName(model_ids[cursor])
	var packed_scene := load(EnvironmentDressing.model_path_for(model_id)) as PackedScene
	if packed_scene == null:
		_finish_failure(selected, artifact.stage_id)
		return false
	artifact.decoration_scenes[model_id] = packed_scene
	job.dressing_model_cursor = cursor + 1
	return true


func _build_topology(job: Dictionary, budget_usec: int) -> void:
	var artifact := job.get("artifact") as StageRuntimeArtifact
	var bootstrap := artifact.paint_bootstrap
	var topology := artifact.runtime_layout.top_topology
	var cell_total := bootstrap.topology_cell_count.x * bootstrap.topology_cell_count.y
	var cursor := int(job.get("topology_cursor", 0))
	var started_at := Time.get_ticks_usec()
	while cursor < cell_total and Time.get_ticks_usec() - started_at < maxi(budget_usec, 1):
		var cell := Vector2i(
			cursor % bootstrap.topology_cell_count.x,
			cursor / bootstrap.topology_cell_count.x
		)
		if not topology.is_cell_active(cell):
			bootstrap.topology_cell_cache_states[cursor] = SURFACE_SAMPLE_INACTIVE
		else:
			for triangle_in_cell in range(TerrainTopTopology.TRIANGLES_PER_CELL):
				var triangle_index := cursor * TerrainTopTopology.TRIANGLES_PER_CELL \
						+ triangle_in_cell
				var vertex_offset := triangle_index * TerrainTopTopology.CORNERS_PER_TRIANGLE
				var indices := topology.triangle_vertex_indices(cell, triangle_in_cell)
				bootstrap.topology_cell_triangle_vertices[vertex_offset] = topology.vertex_at(indices.x)
				bootstrap.topology_cell_triangle_vertices[vertex_offset + 1] = topology.vertex_at(indices.y)
				bootstrap.topology_cell_triangle_vertices[vertex_offset + 2] = topology.vertex_at(indices.z)
				bootstrap.topology_cell_triangle_normals[triangle_index] = topology.triangle_normal(
					cell, triangle_in_cell
				)
			bootstrap.topology_cell_cache_states[cursor] = SURFACE_SAMPLE_ACTIVE
		cursor += 1
	job.topology_cursor = cursor
	if cursor >= cell_total:
		job.axis_cursor = 0
		job.phase = Phase.BUILD_X_AXIS


func _build_axis(job: Dictionary, horizontal: bool, budget_usec: int) -> void:
	var artifact := job.get("artifact") as StageRuntimeArtifact
	var bootstrap := artifact.paint_bootstrap
	var topology := artifact.runtime_layout.top_topology
	var cursor := int(job.get("axis_cursor", 0))
	var started_at := Time.get_ticks_usec()
	while cursor < MASK_SIZE and Time.get_ticks_usec() - started_at < maxi(budget_usec, 1):
		var normalized := (float(cursor) + 0.5) / float(MASK_SIZE)
		if horizontal:
			var local_x := topology.local_bounds.position.x + normalized * topology.local_bounds.size.x
			var grid_x := (local_x - topology.local_bounds.position.x) \
					/ topology.local_bounds.size.x * float(topology.cell_count.x)
			var cell_x := clampi(floori(grid_x), 0, topology.cell_count.x - 1)
			bootstrap.surface_column_cells[cursor] = cell_x
			bootstrap.surface_column_fractions[cursor] = grid_x - float(cell_x)
			bootstrap.surface_world_x[cursor] = bootstrap.world_bounds.position.x \
					+ normalized * bootstrap.world_bounds.size.x
		else:
			var local_z := topology.local_bounds.position.y + normalized * topology.local_bounds.size.y
			var grid_y := (local_z - topology.local_bounds.position.y) \
					/ topology.local_bounds.size.y * float(topology.cell_count.y)
			var cell_y := clampi(floori(grid_y), 0, topology.cell_count.y - 1)
			bootstrap.surface_row_cells[cursor] = cell_y
			bootstrap.surface_row_fractions[cursor] = grid_y - float(cell_y)
			bootstrap.surface_world_z[cursor] = bootstrap.world_bounds.position.y \
					+ normalized * bootstrap.world_bounds.size.y
		cursor += 1
	job.axis_cursor = cursor
	if cursor >= MASK_SIZE:
		job.axis_cursor = 0
		job.phase = Phase.CREATE_TARGET_IMAGE if not horizontal else Phase.BUILD_Y_AXIS


func _build_preview_paint(job: Dictionary, budget_usec: int) -> void:
	var stage := job.get("stage") as StageData
	var bytes: PackedByteArray = job.get("preview_bytes", PackedByteArray())
	var centers: Array[Vector2] = [
		Vector2(0.45, 0.25),
		Vector2(0.49, 0.34),
		Vector2(0.45, 0.43),
		Vector2(0.51, 0.52),
	]
	if stage.stage_number > 1:
		centers.append_array([
			Vector2(0.64, 0.32), Vector2(0.68, 0.43), Vector2(0.63, 0.54)
		])
	var cursor := int(job.get("preview_cursor", 0))
	var denominator := float(PREVIEW_MASK_SIZE - 1)
	var started_at := Time.get_ticks_usec()
	while cursor < bytes.size() and Time.get_ticks_usec() - started_at < maxi(budget_usec, 1):
		var x := cursor % PREVIEW_MASK_SIZE
		var y := cursor / PREVIEW_MASK_SIZE
		var point := Vector2(float(x) / denominator, float(y) / denominator)
		var amount := 0.0
		for center in centers:
			var distance := point.distance_to(center)
			amount = maxf(amount, 1.0 - smoothstep(0.035, 0.075, distance))
		bytes[cursor] = clampi(roundi(amount * 255.0), 0, 255)
		cursor += 1
	job.preview_bytes = bytes
	job.preview_cursor = cursor
	if cursor >= bytes.size():
		job.phase = Phase.CREATE_PREVIEW_TEXTURE


func _bootstrap(job: Dictionary) -> PaintSurfaceBootstrap:
	return (job.get("artifact") as StageRuntimeArtifact).paint_bootstrap


func _job_progress(job: Dictionary) -> float:
	var phase := int(job.get("phase", Phase.COPY_LAYOUT))
	if phase == Phase.BUILD_GEOMETRY:
		var geometry_job := job.get("geometry_job") as TerrainGeometryBuildJob
		if geometry_job != null:
			return (float(phase) + geometry_job.progress_fraction()) / float(Phase.COMPLETE)
	return float(phase) / float(Phase.COMPLETE)


func _job_matches(job: Dictionary, stage: StageData, layout: GeneratedStageLayout) -> bool:
	if job.is_empty() or stage == null or layout == null:
		return false
	var job_stage := job.get("stage") as StageData
	var source := job.get("source_layout") as GeneratedStageLayout
	return job_stage != null and source != null \
			and job_stage.stage_id == stage.stage_id \
			and job_stage.stage_version == stage.stage_version \
			and job_stage.terrain_seed == stage.terrain_seed \
			and job_stage.paint_color == stage.paint_color \
			and job_stage.generation_profile != null \
			and stage.generation_profile != null \
			and job_stage.generation_profile.profile_id == stage.generation_profile.profile_id \
			and job_stage.generation_profile.profile_version \
					== stage.generation_profile.profile_version \
			and source.checksum == layout.checksum


func _job_stage_id(job: Dictionary) -> StringName:
	var stage := job.get("stage") as StageData
	return stage.stage_id if stage != null else &""


func _cache(stage_id: StringName, artifact: StageRuntimeArtifact) -> void:
	_artifact_cache[stage_id] = artifact
	_touch(stage_id)
	while _least_recently_used.size() > MAX_CACHED_ARTIFACTS:
		_artifact_cache.erase(StringName(_least_recently_used.pop_front()))


func _touch(stage_id: StringName) -> void:
	_least_recently_used.erase(stage_id)
	_least_recently_used.append(stage_id)


func _finish_failure(selected: bool, stage_id: StringName) -> void:
	if selected:
		_selected_job = {}
	else:
		_prefetch_job = {}
	if not stage_id.is_empty():
		artifact_failed.emit(stage_id)
