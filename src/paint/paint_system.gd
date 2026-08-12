class_name PaintSystem
extends Node

signal coverage_changed(coverage_percent: float)
signal paint_command_applied(command, written_pixel_count: int, newly_painted_pixel_count: int)
signal paint_command_rejected(command)
signal paint_commands_drained(
	last_drained_physics_tick: int,
	command_count: int,
	paint_mask_checksum: int
)

const MASK_SIZE := 512
const PAINT_DRAIN_PRIORITY := 1000
# The mask remains authoritative in CPU memory; the material only needs a
# bounded presentation cadence. Ten uploads per second keeps the blue trail
# visibly continuous while avoiding a texture update on every sixth rendered
# frame during a long rolling contact.
const PAINT_TEXTURE_PUBLISH_INTERVAL := 1.0 / 10.0
const NORMAL_FACING_THRESHOLD := 0.2588190451 # cos(75 degrees)
const WRITE_RESULT_NONE := 0
const WRITE_RESULT_WRITTEN := 1
const WRITE_RESULT_NEW_TARGET := 2
const SURFACE_SAMPLE_UNKNOWN := 0
const SURFACE_SAMPLE_INACTIVE := 1
const SURFACE_SAMPLE_ACTIVE := 2
# Two 26-bit components keep JSON diagnostic round-trips exact while avoiding scans.
const CHECKSUM_COMPONENT_MASK := 0x03ffffff
const CHECKSUM_XOR_SEED := 0x02d95df4
const CHECKSUM_SUM_SEED := 0x01873593
const CHECKSUM_TOKEN_SALT_A := 0x165667b1
const CHECKSUM_TOKEN_SALT_B := 0x27d4eb2d
const CHECKSUM_TOKEN_MULTIPLIER := 0x45d9f3b
const DEFAULT_PAINT_SURFACE_TUNING := preload(
	"res://resources/paint/default_paint_surface_tuning.tres"
)
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _generated_layout: GeneratedStageLayout
var _world_bounds: Rect2
var _terrain_origin_y: float = 0.0
var _surface_tuning: PaintSurfaceTuning = DEFAULT_PAINT_SURFACE_TUNING

var _expected_top_collider_rid := RID()
var _expected_top_owner_id: StringName = TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID
var _expected_top_shape_id: StringName = TrajectoryHitIdentity.TERRAIN_TOP_SHAPE_ID
var _expected_top_shape_index: int = 0

var _paint_bytes := PackedByteArray()
var _target_bytes := PackedByteArray()
var _paintable_surface_bytes := PackedByteArray()
var _surface_sample_states := PackedByteArray()
var _recent_bytes := PackedByteArray()
var _surface_positions := PackedVector3Array()
var _surface_normals := PackedVector3Array()
var _surface_column_cells := PackedInt32Array()
var _surface_row_cells := PackedInt32Array()
var _surface_column_fractions := PackedFloat32Array()
var _surface_row_fractions := PackedFloat32Array()
var _surface_world_x := PackedFloat32Array()
var _surface_world_z := PackedFloat32Array()
var _topology_cell_cache_states := PackedByteArray()
var _topology_cell_triangle_vertices := PackedVector3Array()
var _topology_cell_triangle_normals := PackedVector3Array()
var _topology_cell_count := Vector2i.ZERO
var _candidate_generation := PackedInt32Array()
var _visited_generation := PackedInt32Array()
var _candidate_generation_id: int = 0
var _visited_generation_id: int = 0
var _component_queue := PackedInt32Array()
var _component_pixels := PackedInt32Array()

var _paint_image: Image
var _target_image: Image
var _recent_image: Image
var _nontarget_image: Image
var _paint_texture: ImageTexture
var _target_texture: ImageTexture
var _recent_texture: ImageTexture
var _nontarget_texture: ImageTexture
var _terrain_material: ShaderMaterial

var _pending_commands: Array = []
var _queued_command_keys: Dictionary = {}
var _last_drained_physics_tick: int = -1
var _paint_mask_checksum: int = 0
var _paint_checksum_xor_component: int = CHECKSUM_XOR_SEED
var _paint_checksum_sum_component: int = CHECKSUM_SUM_SEED
var _painted_target_pixels: int = 0
var _total_target_pixels: int = 0
var _painted_target_surface_area: float = 0.0
var _total_target_surface_area: float = 0.0
var _projected_texel_area: float = 0.0
var _paint_dirty_rect := Rect2i()
var _recent_dirty_rect := Rect2i()
var _recent_live_rect := Rect2i()
var _texture_upload_pending: bool = false
var _texture_upload_batch_count: int = 0
var _paint_texture_publish_elapsed: float = 0.0
var _coverage_changed_since_publish: bool = false
var _recent_diagnostics_enabled: bool = false
var _nontarget_diagnostic_build_count: int = 0


func _init() -> void:
	process_physics_priority = PAINT_DRAIN_PRIORITY


func configure(
		world_bounds: Rect2,
		terrain_origin_y: float,
		terrain_material: ShaderMaterial,
		paint_color: Color,
		generated_layout: GeneratedStageLayout,
		paint_surface_tuning: PaintSurfaceTuning = DEFAULT_PAINT_SURFACE_TUNING,
		prepared_bootstrap: PaintSurfaceBootstrap = null
) -> void:
	assert(generated_layout != null and generated_layout.is_valid(), "PaintSystem requires the accepted generated layout.")
	assert(generated_layout.has_valid_target_mask(), "PaintSystem requires an authoritative target mask.")
	assert(generated_layout.has_valid_target_surface_coverage(), "PaintSystem requires metric-2 target surface metadata.")
	assert(paint_surface_tuning != null and paint_surface_tuning.is_valid(), "PaintSystem requires typed surface tuning.")
	assert(paint_surface_tuning.mask_size == MASK_SIZE, "PaintSystem mask size is fixed at 512 for version 5.")
	assert(world_bounds.has_area(), "PaintSystem requires non-empty world bounds.")
	assert(
		world_bounds.size.is_equal_approx(generated_layout.local_bounds.size),
		"PaintSystem world and generated-layout bounds must share one XZ scale."
	)
	_generated_layout = generated_layout
	_world_bounds = world_bounds
	_terrain_origin_y = terrain_origin_y
	_terrain_material = terrain_material
	_surface_tuning = paint_surface_tuning
	_pending_commands.clear()
	_queued_command_keys.clear()
	_last_drained_physics_tick = -1
	_create_masks_and_surface_cache(prepared_bootstrap)
	_reset_paint_mask_checksum()
	if _terrain_material != null:
		_terrain_material.set_shader_parameter(&"paint_mask", _paint_texture)
		_terrain_material.set_shader_parameter(&"target_mask", _target_texture)
		_terrain_material.set_shader_parameter(&"paint_color", paint_color)


func configure_top_surface_identity(
		top_collider_rid: RID,
		owner_id: StringName = TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID,
		shape_id: StringName = TrajectoryHitIdentity.TERRAIN_TOP_SHAPE_ID,
		shape_index: int = 0
) -> void:
	assert(top_collider_rid.is_valid(), "PaintSystem requires the real terrain-top body RID.")
	assert(not String(owner_id).is_empty() and not String(shape_id).is_empty(), "PaintSystem requires stable terrain-top identity.")
	assert(shape_index >= 0, "PaintSystem requires a nonnegative terrain-top shape index.")
	_expected_top_collider_rid = top_collider_rid
	_expected_top_owner_id = owner_id
	_expected_top_shape_id = shape_id
	_expected_top_shape_index = shape_index


func authoritative_top_surface_identity() -> Dictionary:
	return {
		"collider_rid": _expected_top_collider_rid,
		"contact_owner_id": _expected_top_owner_id,
		"contact_shape_id": _expected_top_shape_id,
		"collider_shape_index": _expected_top_shape_index,
	}


func _physics_process(_delta: float) -> void:
	drain_pending_commands()


func _process(delta: float) -> void:
	_paint_texture_publish_elapsed += delta
	if _paint_texture_publish_elapsed >= PAINT_TEXTURE_PUBLISH_INTERVAL:
		_paint_texture_publish_elapsed = 0.0
		_upload_dirty_images()


func queue_radial_paint_mark(command: RadialPaintMark) -> bool:
	return _queue_typed_command(command)


func queue_surface_paint_sweep(command: SurfacePaintSweep) -> bool:
	return _queue_typed_command(command)


func _queue_typed_command(command) -> bool:
	if not _command_matches_authoritative_surface(command):
		paint_command_rejected.emit(command)
		return false
	var command_tick := int(command.physics_tick)
	if command_tick <= _last_drained_physics_tick:
		paint_command_rejected.emit(command)
		return false
	var key := _command_key(command)
	if _queued_command_keys.has(key):
		paint_command_rejected.emit(command)
		return false
	_queued_command_keys[key] = true
	_pending_commands.append(command)
	return true


func drain_pending_commands() -> Dictionary:
	if _pending_commands.is_empty():
		return {
			"last_drained_physics_tick": _last_drained_physics_tick,
			"command_count": 0,
			"written_pixel_count": 0,
			"newly_painted_pixel_count": 0,
			"paint_mask_checksum": _paint_mask_checksum,
		}
	_clear_recent_region()
	if _pending_commands.size() > 1:
		_pending_commands.sort_custom(_typed_command_less)
	var commands := _pending_commands
	_pending_commands = []
	var written := 0
	var newly_painted := 0
	var drained_tick := _last_drained_physics_tick
	for command in commands:
		_queued_command_keys.erase(_command_key(command))
		var counts := Vector2i.ZERO
		if command is RadialPaintMark:
			counts = _rasterize_radial_command(command as RadialPaintMark)
		elif command is SurfacePaintSweep:
			counts = _rasterize_sweep_command(command as SurfacePaintSweep)
		if counts.x > 0:
			# Publish once per authoritative command so observers see its complete
			# incremental checksum without paying a second combine per painted pixel.
			_publish_paint_mask_checksum()
		written += counts.x
		newly_painted += counts.y
		drained_tick = maxi(drained_tick, int(command.physics_tick))
		paint_command_applied.emit(command, counts.x, counts.y)
	_last_drained_physics_tick = drained_tick
	_coverage_changed_since_publish = _coverage_changed_since_publish or newly_painted > 0
	var checksum := _paint_mask_checksum
	paint_commands_drained.emit(drained_tick, commands.size(), checksum)
	return {
		"last_drained_physics_tick": drained_tick,
		"command_count": commands.size(),
		"written_pixel_count": written,
		"newly_painted_pixel_count": newly_painted,
		"paint_mask_checksum": checksum,
	}


func _rasterize_radial_command(command: RadialPaintMark) -> Vector2i:
	return _rasterize_radial(command.center, command.normal, command.radius)


func _rasterize_sweep_command(command: SurfacePaintSweep) -> Vector2i:
	var generation := _build_sweep_candidates(
		command.from_point,
		command.to_point,
		command.from_normal,
		command.to_normal,
		command.footprint_radius
	)
	if generation <= 0:
		return Vector2i.ZERO
	var from_seed := _snap_candidate(command.from_point, generation)
	var to_seed := _snap_candidate(command.to_point, generation)
	if from_seed >= 0 and to_seed >= 0:
		_collect_candidate_component(from_seed, generation)
		if _was_visited(to_seed):
			return _write_sweep_component(
				_component_pixels,
				command.from_point,
				command.to_point,
				command.footprint_radius
			)
	# A disconnected chord is never persisted; independently valid endpoint
	# discs preserve the two physically measured contacts.
	var result := Vector2i.ZERO
	if from_seed >= 0:
		var from_counts := _rasterize_radial(
			command.from_point, command.from_normal, command.footprint_radius
		)
		result += from_counts
	if to_seed >= 0:
		var to_counts := _rasterize_radial(
			command.to_point, command.to_normal, command.footprint_radius
		)
		result += to_counts
	return result


func _rasterize_radial(center: Vector3, normal: Vector3, radius: float) -> Vector2i:
	var generation := _build_radial_candidates(center, normal, radius)
	if generation <= 0:
		return Vector2i.ZERO
	var seed := _snap_candidate(center, generation)
	if seed < 0:
		return Vector2i.ZERO
	_collect_candidate_component(seed, generation)
	return _write_radial_component(_component_pixels, center, radius)


func _build_radial_candidates(center: Vector3, normal: Vector3, radius: float) -> int:
	var pixel_bounds := _candidate_pixel_bounds(
		Vector2(center.x - radius, center.z - radius),
		Vector2(center.x + radius, center.z + radius)
	)
	if not pixel_bounds.has_area():
		return -1
	var generation := _next_candidate_generation()
	var radius_squared := radius * radius
	for pixel_y in range(pixel_bounds.position.y, pixel_bounds.end.y):
		for pixel_x in range(pixel_bounds.position.x, pixel_bounds.end.x):
			var index := pixel_y * MASK_SIZE + pixel_x
			if not _ensure_surface_sample(index):
				continue
			if _surface_positions[index].distance_squared_to(center) > radius_squared:
				continue
			if _surface_normals[index].dot(normal) < NORMAL_FACING_THRESHOLD:
				continue
			_candidate_generation[index] = generation
	return generation


func _build_sweep_candidates(
		from_point: Vector3,
		to_point: Vector3,
		from_normal: Vector3,
		to_normal: Vector3,
		radius: float
) -> int:
	var pixel_bounds := _candidate_pixel_bounds(
		Vector2(minf(from_point.x, to_point.x) - radius, minf(from_point.z, to_point.z) - radius),
		Vector2(maxf(from_point.x, to_point.x) + radius, maxf(from_point.z, to_point.z) + radius)
	)
	if not pixel_bounds.has_area():
		return -1
	var generation := _next_candidate_generation()
	var delta := to_point - from_point
	var length_squared := delta.length_squared()
	var radius_squared := radius * radius
	for pixel_y in range(pixel_bounds.position.y, pixel_bounds.end.y):
		for pixel_x in range(pixel_bounds.position.x, pixel_bounds.end.x):
			var index := pixel_y * MASK_SIZE + pixel_x
			if not _ensure_surface_sample(index):
				continue
			var surface_point := _surface_positions[index]
			var t := clampf((surface_point - from_point).dot(delta) / maxf(length_squared, 0.000001), 0.0, 1.0)
			var closest := from_point + delta * t
			if surface_point.distance_squared_to(closest) > radius_squared:
				continue
			var expected_normal := from_normal.lerp(to_normal, t).normalized()
			if _surface_normals[index].dot(expected_normal) < NORMAL_FACING_THRESHOLD:
				continue
			_candidate_generation[index] = generation
	return generation


func _snap_candidate(world_point: Vector3, generation: int) -> int:
	var uv := (Vector2(world_point.x, world_point.z) - _world_bounds.position) / _world_bounds.size
	var snapped := PaintMaskAddressing.snap_uv_to_pixel(uv, MASK_SIZE)
	if snapped.x < 0:
		return -1
	var best_index := -1
	var best_distance_squared := 0x7fffffff
	var best_y := 0x7fffffff
	var best_x := 0x7fffffff
	for offset_y in range(-2, 3):
		for offset_x in range(-2, 3):
			var candidate := snapped + Vector2i(offset_x, offset_y)
			if candidate.x < 0 or candidate.x >= MASK_SIZE \
					or candidate.y < 0 or candidate.y >= MASK_SIZE:
				continue
			var candidate_index := candidate.y * MASK_SIZE + candidate.x
			if _candidate_generation[candidate_index] != generation:
				continue
			var distance_squared := offset_x * offset_x + offset_y * offset_y
			if distance_squared < best_distance_squared \
					or (distance_squared == best_distance_squared and candidate.y < best_y) \
					or (distance_squared == best_distance_squared and candidate.y == best_y \
							and candidate.x < best_x):
				best_index = candidate_index
				best_distance_squared = distance_squared
				best_y = candidate.y
				best_x = candidate.x
	return best_index


func _collect_candidate_component(seed: int, candidate_generation: int) -> void:
	_component_queue.clear()
	_component_pixels.clear()
	var visit_generation := _next_visited_generation()
	_component_queue.append(seed)
	_visited_generation[seed] = visit_generation
	var cursor := 0
	while cursor < _component_queue.size():
		var current := _component_queue[cursor]
		cursor += 1
		_component_pixels.append(current)
		var point := Vector2i(current % MASK_SIZE, current / MASK_SIZE)
		for offset in NEIGHBOR_OFFSETS:
			var neighbor := point + offset
			if neighbor.x < 0 or neighbor.x >= MASK_SIZE \
					or neighbor.y < 0 or neighbor.y >= MASK_SIZE:
				continue
			var neighbor_index := neighbor.y * MASK_SIZE + neighbor.x
			if _candidate_generation[neighbor_index] != candidate_generation \
					or _visited_generation[neighbor_index] == visit_generation:
				continue
			_visited_generation[neighbor_index] = visit_generation
			_component_queue.append(neighbor_index)


func _was_visited(index: int) -> bool:
	return index >= 0 and _visited_generation[index] == _visited_generation_id


func _write_radial_component(
		component: PackedInt32Array,
		center: Vector3,
		radius: float
) -> Vector2i:
	var written := 0
	var newly_painted := 0
	for index in component:
		var distance := _surface_positions[index].distance_to(center)
		var write_result := _write_paint_value(index, _alpha_for_distance(distance, radius))
		if write_result != WRITE_RESULT_NONE:
			written += 1
		if (write_result & WRITE_RESULT_NEW_TARGET) != 0:
			newly_painted += 1
	return Vector2i(written, newly_painted)


func _write_sweep_component(
		component: PackedInt32Array,
		from_point: Vector3,
		to_point: Vector3,
		radius: float
) -> Vector2i:
	var written := 0
	var newly_painted := 0
	var delta := to_point - from_point
	var length_squared := delta.length_squared()
	for index in component:
		var surface_point := _surface_positions[index]
		var t := clampf((surface_point - from_point).dot(delta) / maxf(length_squared, 0.000001), 0.0, 1.0)
		var distance := surface_point.distance_to(from_point + delta * t)
		var write_result := _write_paint_value(index, _alpha_for_distance(distance, radius))
		if write_result != WRITE_RESULT_NONE:
			written += 1
		if (write_result & WRITE_RESULT_NEW_TARGET) != 0:
			newly_painted += 1
	return Vector2i(written, newly_painted)


func _alpha_for_distance(distance: float, radius: float) -> int:
	var core_radius := radius * _surface_tuning.core_ratio
	if distance <= core_radius or is_equal_approx(core_radius, radius):
		return 255
	var edge_weight := clampf((distance - core_radius) / (radius - core_radius), 0.0, 1.0)
	return clampi(
		roundi(lerpf(255.0, float(_surface_tuning.painted_threshold_byte), edge_weight)),
		_surface_tuning.painted_threshold_byte,
		255
	)


func _write_paint_value(index: int, value: int) -> int:
	if index < 0 or index >= _paint_bytes.size() \
			or _surface_sample_states[index] != SURFACE_SAMPLE_ACTIVE:
		return WRITE_RESULT_NONE
	var existing := int(_paint_bytes[index])
	var updated := maxi(existing, clampi(value, 0, 255))
	if updated <= existing:
		return WRITE_RESULT_NONE
	var crossed_paint_threshold := existing < _surface_tuning.painted_threshold_byte \
			and updated >= _surface_tuning.painted_threshold_byte
	var newly_painted := crossed_paint_threshold \
			and _target_bytes[index] >= _surface_tuning.painted_threshold_byte
	_paint_bytes[index] = updated
	_update_paint_mask_checksum(index, existing, updated)
	if _recent_diagnostics_enabled:
		_recent_bytes[index] = 255
	if newly_painted:
		_painted_target_pixels += 1
		var surface_area := TargetSurfaceCoverage.texel_surface_area(
			_surface_normals[index], _projected_texel_area
		)
		assert(surface_area > 0.0, "Target coverage requires a valid upward canonical normal.")
		_painted_target_surface_area += surface_area
	_mark_paint_dirty(index)
	if _recent_diagnostics_enabled:
		_mark_recent_dirty(index)
	return WRITE_RESULT_WRITTEN | (WRITE_RESULT_NEW_TARGET if newly_painted else 0)


func _command_matches_authoritative_surface(command) -> bool:
	if _generated_layout == null:
		return false
	if command is RadialPaintMark:
		if not (command as RadialPaintMark).is_valid():
			return false
	elif command is SurfacePaintSweep:
		if not (command as SurfacePaintSweep).is_valid():
			return false
	else:
		return false
	if command.contact_owner_id != _expected_top_owner_id \
			or command.contact_shape_id != _expected_top_shape_id \
			or int(command.collider_shape_index) != _expected_top_shape_index:
		return false
	return not _expected_top_collider_rid.is_valid() \
			or command.top_collider_rid == _expected_top_collider_rid


func _typed_command_less(a, b) -> bool:
	var a_key: PackedInt64Array = a.drain_sort_key()
	var b_key: PackedInt64Array = b.drain_sort_key()
	for index in range(mini(a_key.size(), b_key.size())):
		if a_key[index] != b_key[index]:
			return a_key[index] < b_key[index]
	return a_key.size() < b_key.size()


func _command_key(command) -> String:
	return "%d:%d:%d:%d" % [command.shot_id, command.physics_tick, command.spawn_ordinal, command.sequence]


func _candidate_pixel_bounds(minimum_world: Vector2, maximum_world: Vector2) -> Rect2i:
	if maximum_world.x < _world_bounds.position.x or minimum_world.x > _world_bounds.end.x \
			or maximum_world.y < _world_bounds.position.y or minimum_world.y > _world_bounds.end.y:
		return Rect2i()
	var minimum_uv := (minimum_world - _world_bounds.position) / _world_bounds.size
	var maximum_uv := (maximum_world - _world_bounds.position) / _world_bounds.size
	var minimum := Vector2i(
		clampi(floori(minimum_uv.x * MASK_SIZE) - 1, 0, MASK_SIZE - 1),
		clampi(floori(minimum_uv.y * MASK_SIZE) - 1, 0, MASK_SIZE - 1)
	)
	var maximum := Vector2i(
		clampi(ceili(maximum_uv.x * MASK_SIZE) + 1, 0, MASK_SIZE - 1),
		clampi(ceili(maximum_uv.y * MASK_SIZE) + 1, 0, MASK_SIZE - 1)
	)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _next_candidate_generation() -> int:
	_candidate_generation_id += 1
	if _candidate_generation_id >= 0x7fffffff:
		_candidate_generation.fill(0)
		_candidate_generation_id = 1
	return _candidate_generation_id


func _next_visited_generation() -> int:
	_visited_generation_id += 1
	if _visited_generation_id >= 0x7fffffff:
		_visited_generation.fill(0)
		_visited_generation_id = 1
	return _visited_generation_id


func force_flush_paint_texture() -> void:
	drain_pending_commands()
	var published_batch := _upload_dirty_images()
	_paint_texture_publish_elapsed = 0.0
	if not published_batch:
		_coverage_changed_since_publish = false
		coverage_changed.emit(coverage_percent())


func flush_pending() -> void:
	force_flush_paint_texture()


func clear() -> void:
	if _paint_image == null:
		return
	_pending_commands.clear()
	_queued_command_keys.clear()
	_last_drained_physics_tick = -1
	_paint_bytes.fill(0)
	if _recent_diagnostics_enabled:
		_recent_bytes.fill(0)
	_reset_paint_mask_checksum()
	_painted_target_pixels = 0
	_painted_target_surface_area = 0.0
	_paint_dirty_rect = Rect2i(Vector2i.ZERO, Vector2i(MASK_SIZE, MASK_SIZE))
	_recent_dirty_rect = _paint_dirty_rect if _recent_diagnostics_enabled else Rect2i()
	_recent_live_rect = Rect2i()
	_texture_upload_pending = true
	_paint_texture_publish_elapsed = 0.0
	_coverage_changed_since_publish = true


func coverage_percent() -> float:
	if _total_target_surface_area <= 0.0:
		return 0.0
	return clampf(
		100.0 * _painted_target_surface_area / _total_target_surface_area,
		0.0,
		100.0
	)


func paint_mask_checksum() -> int:
	return _paint_mask_checksum


func _reset_paint_mask_checksum() -> void:
	_paint_checksum_xor_component = CHECKSUM_XOR_SEED
	_paint_checksum_sum_component = CHECKSUM_SUM_SEED
	_publish_paint_mask_checksum()


func _update_paint_mask_checksum(index: int, previous_value: int, next_value: int) -> void:
	var previous_xor_token := _paint_checksum_token(index, previous_value, CHECKSUM_TOKEN_SALT_A)
	var next_xor_token := _paint_checksum_token(index, next_value, CHECKSUM_TOKEN_SALT_A)
	var previous_sum_token := _paint_checksum_token(index, previous_value, CHECKSUM_TOKEN_SALT_B)
	var next_sum_token := _paint_checksum_token(index, next_value, CHECKSUM_TOKEN_SALT_B)
	_paint_checksum_xor_component = (
		_paint_checksum_xor_component ^ previous_xor_token ^ next_xor_token
	) & CHECKSUM_COMPONENT_MASK
	_paint_checksum_sum_component = (
		_paint_checksum_sum_component - previous_sum_token + next_sum_token
	) & CHECKSUM_COMPONENT_MASK


func _paint_checksum_token(index: int, value: int, salt: int) -> int:
	if value <= 0:
		return 0
	var mixed := (
		(index + 1) * 1103515245 + value * 12345 + salt
	) & CHECKSUM_COMPONENT_MASK
	mixed = ((mixed ^ (mixed >> 16)) * CHECKSUM_TOKEN_MULTIPLIER) \
			& CHECKSUM_COMPONENT_MASK
	mixed = ((mixed ^ (mixed >> 16)) * CHECKSUM_TOKEN_MULTIPLIER) \
			& CHECKSUM_COMPONENT_MASK
	return (mixed ^ (mixed >> 16)) & CHECKSUM_COMPONENT_MASK


func _publish_paint_mask_checksum() -> void:
	_paint_mask_checksum = (
		(_paint_checksum_xor_component << 26) | _paint_checksum_sum_component
	)
	if _paint_mask_checksum == 0:
		_paint_mask_checksum = 1


func paint_texture() -> ImageTexture:
	return _paint_texture


func target_texture() -> ImageTexture:
	return _target_texture


func recent_texture() -> ImageTexture:
	return _recent_texture


func set_recent_diagnostics_enabled(value: bool) -> void:
	var should_enable := value and OS.is_debug_build()
	if _recent_diagnostics_enabled == should_enable:
		return
	_recent_diagnostics_enabled = should_enable
	_recent_dirty_rect = Rect2i()
	_recent_live_rect = Rect2i()
	if should_enable:
		_allocate_recent_diagnostics()
		return
	_recent_bytes = PackedByteArray()
	_recent_image = null
	_recent_texture = null
	_texture_upload_pending = _paint_dirty_rect.has_area()


func nontarget_texture() -> ImageTexture:
	if _nontarget_texture == null and _target_bytes.size() == MASK_SIZE * MASK_SIZE:
		_build_nontarget_diagnostic_texture()
	return _nontarget_texture


func nontarget_diagnostic_build_count() -> int:
	return _nontarget_diagnostic_build_count


func pending_work_count() -> int:
	return _pending_commands.size()


func last_drained_physics_tick() -> int:
	return _last_drained_physics_tick


func texture_upload_batch_count() -> int:
	return _texture_upload_batch_count


func dirty_region_read_only() -> Rect2i:
	return _paint_dirty_rect


func total_target_pixels() -> int:
	return _total_target_pixels


func painted_target_pixels() -> int:
	return _painted_target_pixels


func painted_target_surface_area() -> float:
	return _painted_target_surface_area


func total_target_surface_area() -> float:
	return _total_target_surface_area


func persistent_nontarget_pixel_count() -> int:
	var count := 0
	for index in range(_paint_bytes.size()):
		if _paint_bytes[index] > 0 and _target_bytes[index] < _surface_tuning.painted_threshold_byte:
			count += 1
	return count


func paint_bytes_read_only() -> PackedByteArray:
	return _paint_bytes.duplicate()


func target_bytes_read_only() -> PackedByteArray:
	return _target_bytes.duplicate()


func generated_layout_read_only() -> GeneratedStageLayout:
	return _generated_layout


func terrain_surface_position(world_xz: Vector2) -> Vector3:
	var sample := _surface_sample_at_world(world_xz)
	return Vector3(world_xz.x, _terrain_origin_y + float(sample.point.y), world_xz.y)


func terrain_surface_normal(world_xz: Vector2) -> Vector3:
	return _surface_sample_at_world(world_xz).normal


func _create_masks_and_surface_cache(prepared_bootstrap: PaintSurfaceBootstrap = null) -> void:
	var pixel_count := MASK_SIZE * MASK_SIZE
	var use_prepared := prepared_bootstrap != null and prepared_bootstrap.is_valid_for(
		_generated_layout,
		_world_bounds,
		_terrain_origin_y,
		_surface_tuning,
		MASK_SIZE
	)
	_paint_bytes.resize(pixel_count)
	_paint_bytes.fill(0)
	_paintable_surface_bytes.resize(pixel_count)
	_paintable_surface_bytes.fill(0)
	_surface_sample_states.resize(pixel_count)
	_surface_sample_states.fill(SURFACE_SAMPLE_UNKNOWN)
	_recent_bytes = PackedByteArray()
	_target_bytes = prepared_bootstrap.target_bytes \
			if use_prepared else _generated_layout.target_mask
	assert(_target_bytes.size() == pixel_count, "Generated layout target mask must be 512 square.")
	if not use_prepared:
		assert(
			TargetMaskRasterizer.byte_checksum(_target_bytes) == _generated_layout.target_mask_checksum,
			"PaintSystem target-mask copy must match the accepted layout checksum."
		)
	_surface_positions.resize(pixel_count)
	_surface_normals.resize(pixel_count)
	if use_prepared:
		_install_surface_bootstrap(prepared_bootstrap)
	else:
		_build_surface_axis_mappings()
	_candidate_generation.resize(pixel_count)
	_candidate_generation.fill(0)
	_visited_generation.resize(pixel_count)
	_visited_generation.fill(0)
	_candidate_generation_id = 0
	_visited_generation_id = 0
	_total_target_pixels = _generated_layout.target_pixel_count()
	assert(_total_target_pixels > 0, "PaintSystem requires at least one target pixel.")
	_total_target_surface_area = _generated_layout.total_target_surface_area
	_projected_texel_area = TargetSurfaceCoverage.projected_texel_area(
		_generated_layout.local_bounds, MASK_SIZE
	)
	assert(_total_target_surface_area > 0.0 and _projected_texel_area > 0.0)
	_paint_image = Image.create_from_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, _paint_bytes)
	_target_image = prepared_bootstrap.target_image if use_prepared else Image.create_from_data(
		MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, _target_bytes
	)
	_paint_texture = ImageTexture.create_from_image(_paint_image)
	_recent_image = null
	_recent_texture = null
	if _recent_diagnostics_enabled:
		_allocate_recent_diagnostics()
	_target_texture = prepared_bootstrap.target_texture \
			if use_prepared else ImageTexture.create_from_image(_target_image)
	_nontarget_image = null
	_nontarget_texture = null
	_nontarget_diagnostic_build_count = 0
	_painted_target_pixels = 0
	_painted_target_surface_area = 0.0
	_paint_dirty_rect = Rect2i()
	_recent_dirty_rect = Rect2i()
	_recent_live_rect = Rect2i()
	_texture_upload_pending = false
	_texture_upload_batch_count = 0
	_paint_texture_publish_elapsed = 0.0
	_coverage_changed_since_publish = false


## The inverse target view is diagnostics-only. Building its 262,144 pixels
## during ordinary stage entry delayed readiness even though gameplay rendering
## samples the target texture directly.
func _build_nontarget_diagnostic_texture() -> void:
	var nontarget_bytes := PackedByteArray()
	nontarget_bytes.resize(_target_bytes.size())
	for index in range(_target_bytes.size()):
		nontarget_bytes[index] = 0 \
				if _target_bytes[index] >= _surface_tuning.painted_threshold_byte else 255
	_nontarget_image = Image.create_from_data(
		MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, nontarget_bytes
	)
	_nontarget_texture = ImageTexture.create_from_image(_nontarget_image)
	_nontarget_diagnostic_build_count += 1


func _install_surface_bootstrap(bootstrap: PaintSurfaceBootstrap) -> void:
	_surface_column_cells = bootstrap.surface_column_cells
	_surface_row_cells = bootstrap.surface_row_cells
	_surface_column_fractions = bootstrap.surface_column_fractions
	_surface_row_fractions = bootstrap.surface_row_fractions
	_surface_world_x = bootstrap.surface_world_x
	_surface_world_z = bootstrap.surface_world_z
	_topology_cell_cache_states = bootstrap.topology_cell_cache_states
	_topology_cell_triangle_vertices = bootstrap.topology_cell_triangle_vertices
	_topology_cell_triangle_normals = bootstrap.topology_cell_triangle_normals
	_topology_cell_count = bootstrap.topology_cell_count


## Caches the two independent mask-to-topology axes and the much smaller accepted
## topology-cell triangle table. Individual 512-square mask samples stay lazy.
func _build_surface_axis_mappings() -> void:
	var topology := _generated_layout.top_topology
	var topology_bounds := topology.local_bounds
	var topology_cells := topology.cell_count
	_topology_cell_count = topology_cells
	var topology_cell_total := topology_cells.x * topology_cells.y
	_topology_cell_cache_states.resize(topology_cell_total)
	_topology_cell_cache_states.fill(SURFACE_SAMPLE_UNKNOWN)
	_topology_cell_triangle_vertices.resize(
		topology_cell_total * TerrainTopTopology.TRIANGLES_PER_CELL \
				* TerrainTopTopology.CORNERS_PER_TRIANGLE
	)
	_topology_cell_triangle_normals.resize(
		topology_cell_total * TerrainTopTopology.TRIANGLES_PER_CELL
	)
	for cell_y in range(topology_cells.y):
		for cell_x in range(topology_cells.x):
			_ensure_topology_cell_cache(Vector2i(cell_x, cell_y))
	_surface_column_cells.resize(MASK_SIZE)
	_surface_row_cells.resize(MASK_SIZE)
	_surface_column_fractions.resize(MASK_SIZE)
	_surface_row_fractions.resize(MASK_SIZE)
	_surface_world_x.resize(MASK_SIZE)
	_surface_world_z.resize(MASK_SIZE)
	for pixel_x in range(MASK_SIZE):
		var normalized_x := (float(pixel_x) + 0.5) / float(MASK_SIZE)
		var local_x := topology_bounds.position.x + normalized_x * topology_bounds.size.x
		var grid_x := (local_x - topology_bounds.position.x) \
				/ topology_bounds.size.x * float(topology_cells.x)
		var cell_x := clampi(floori(grid_x), 0, topology_cells.x - 1)
		_surface_column_cells[pixel_x] = cell_x
		_surface_column_fractions[pixel_x] = grid_x - float(cell_x)
		_surface_world_x[pixel_x] = _world_bounds.position.x \
				+ normalized_x * _world_bounds.size.x
	for pixel_y in range(MASK_SIZE):
		var normalized_y := (float(pixel_y) + 0.5) / float(MASK_SIZE)
		var local_z := topology_bounds.position.y + normalized_y * topology_bounds.size.y
		var grid_y := (local_z - topology_bounds.position.y) \
				/ topology_bounds.size.y * float(topology_cells.y)
		var cell_y := clampi(floori(grid_y), 0, topology_cells.y - 1)
		_surface_row_cells[pixel_y] = cell_y
		_surface_row_fractions[pixel_y] = grid_y - float(cell_y)
		_surface_world_z[pixel_y] = _world_bounds.position.y \
				+ normalized_y * _world_bounds.size.y


## Resolves only pixels reached by a paint footprint. The former eager 512-square
## topology walk blocked scene entry even though a shot touches a small fraction.
func _ensure_surface_sample(index: int) -> bool:
	if index < 0 or index >= _surface_sample_states.size():
		return false
	var state := int(_surface_sample_states[index])
	if state != SURFACE_SAMPLE_UNKNOWN:
		return state == SURFACE_SAMPLE_ACTIVE
	var pixel := Vector2i(index % MASK_SIZE, index / MASK_SIZE)
	var cell := Vector2i(
		_surface_column_cells[pixel.x],
		_surface_row_cells[pixel.y]
	)
	if not _ensure_topology_cell_cache(cell):
		assert(
			_target_bytes[index] < _surface_tuning.painted_threshold_byte,
			"Eligible coverage pixels must belong to a real mountain top triangle."
		)
		_surface_sample_states[index] = SURFACE_SAMPLE_INACTIVE
		return false
	var local_uv := Vector2(
		_surface_column_fractions[pixel.x],
		_surface_row_fractions[pixel.y]
	)
	var address := TerrainTopTopology.triangle_barycentric_for_cell_uv(local_uv)
	var triangle_in_cell := int(address.x)
	var cell_index := cell.y * _topology_cell_count.x + cell.x
	var triangle_index := cell_index * TerrainTopTopology.TRIANGLES_PER_CELL \
			+ triangle_in_cell
	var vertex_offset := triangle_index * TerrainTopTopology.CORNERS_PER_TRIANGLE
	var local_point := _topology_cell_triangle_vertices[vertex_offset] * address.y \
			+ _topology_cell_triangle_vertices[vertex_offset + 1] * address.z \
			+ _topology_cell_triangle_vertices[vertex_offset + 2] * address.w
	_surface_positions[index] = Vector3(
		_surface_world_x[pixel.x],
		_terrain_origin_y + local_point.y,
		_surface_world_z[pixel.y]
	)
	_surface_normals[index] = _topology_cell_triangle_normals[triangle_index]
	_paintable_surface_bytes[index] = 255
	_surface_sample_states[index] = SURFACE_SAMPLE_ACTIVE
	return true


func _ensure_topology_cell_cache(cell: Vector2i) -> bool:
	var cell_index := cell.y * _topology_cell_count.x + cell.x
	var state := int(_topology_cell_cache_states[cell_index])
	if state != SURFACE_SAMPLE_UNKNOWN:
		return state == SURFACE_SAMPLE_ACTIVE
	var topology := _generated_layout.top_topology
	if not topology.is_cell_active(cell):
		_topology_cell_cache_states[cell_index] = SURFACE_SAMPLE_INACTIVE
		return false
	for triangle_in_cell in range(TerrainTopTopology.TRIANGLES_PER_CELL):
		var triangle_index := cell_index * TerrainTopTopology.TRIANGLES_PER_CELL \
				+ triangle_in_cell
		var vertex_offset := triangle_index * TerrainTopTopology.CORNERS_PER_TRIANGLE
		var source_indices := topology.triangle_vertex_indices(cell, triangle_in_cell)
		assert(source_indices.x >= 0, "Active paint cells require emitted top triangles.")
		_topology_cell_triangle_vertices[vertex_offset] = topology.vertex_at(source_indices.x)
		_topology_cell_triangle_vertices[vertex_offset + 1] = topology.vertex_at(source_indices.y)
		_topology_cell_triangle_vertices[vertex_offset + 2] = topology.vertex_at(source_indices.z)
		_topology_cell_triangle_normals[triangle_index] = topology.triangle_normal(
			cell,
			triangle_in_cell
		)
	_topology_cell_cache_states[cell_index] = SURFACE_SAMPLE_ACTIVE
	return true


func _allocate_recent_diagnostics() -> void:
	if _paint_bytes.is_empty():
		return
	_recent_bytes.resize(_paint_bytes.size())
	_recent_bytes.fill(0)
	_recent_image = Image.create_from_data(
		MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, _recent_bytes
	)
	_recent_texture = ImageTexture.create_from_image(_recent_image)


func _mark_paint_dirty(index: int) -> void:
	_paint_dirty_rect = _include_pixel(_paint_dirty_rect, Vector2i(index % MASK_SIZE, index / MASK_SIZE))
	_texture_upload_pending = true


func _mark_recent_dirty(index: int) -> void:
	var pixel := Vector2i(index % MASK_SIZE, index / MASK_SIZE)
	_recent_dirty_rect = _include_pixel(_recent_dirty_rect, pixel)
	_recent_live_rect = _include_pixel(_recent_live_rect, pixel)
	_texture_upload_pending = true


func _clear_recent_region() -> void:
	if not _recent_diagnostics_enabled or not _recent_live_rect.has_area():
		return
	for pixel_y in range(_recent_live_rect.position.y, _recent_live_rect.end.y):
		for pixel_x in range(_recent_live_rect.position.x, _recent_live_rect.end.x):
			var index := pixel_y * MASK_SIZE + pixel_x
			if _recent_bytes[index] != 0:
				_recent_bytes[index] = 0
				_recent_dirty_rect = _include_pixel(_recent_dirty_rect, Vector2i(pixel_x, pixel_y))
	_recent_live_rect = Rect2i()
	_texture_upload_pending = _texture_upload_pending or _recent_dirty_rect.has_area()


func _include_pixel(rect: Rect2i, pixel: Vector2i) -> Rect2i:
	if not rect.has_area():
		return Rect2i(pixel, Vector2i.ONE)
	var minimum := Vector2i(mini(rect.position.x, pixel.x), mini(rect.position.y, pixel.y))
	var maximum := Vector2i(maxi(rect.end.x - 1, pixel.x), maxi(rect.end.y - 1, pixel.y))
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _upload_dirty_images() -> bool:
	if not _texture_upload_pending:
		return false
	if _paint_dirty_rect.has_area():
		_paint_image.set_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, _paint_bytes)
		_update_texture_region(_paint_texture, _paint_image, _paint_dirty_rect)
	if _recent_diagnostics_enabled and _recent_dirty_rect.has_area():
		_recent_image.set_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, _recent_bytes)
		_update_texture_region(_recent_texture, _recent_image, _recent_dirty_rect)
	_texture_upload_batch_count += 1
	_paint_dirty_rect = Rect2i()
	_recent_dirty_rect = Rect2i()
	_texture_upload_pending = false
	if _coverage_changed_since_publish:
		_coverage_changed_since_publish = false
		coverage_changed.emit(coverage_percent())
	return true


func _update_texture_region(
		texture: ImageTexture,
		image: Image,
		dirty_rect: Rect2i
) -> void:
	# The CPU mask is authoritative, but the GPU only needs the changed region.
	# Compatibility's partial upload avoids stalling the render thread with a
	# full 512x512 texture update for every rolling paint sweep.
	if texture.has_method(&"set_data_partial"):
		texture.call(&"set_data_partial", image, dirty_rect, dirty_rect.position)
	else:
		# Keep a safe fallback for renderers/builds that expose only update().
		texture.update(image)


func _surface_sample_at_world(world_xz: Vector2) -> Dictionary:
	var normalized := (world_xz - _world_bounds.position) / _world_bounds.size
	var local := _generated_layout.local_bounds.position \
			+ normalized * _generated_layout.local_bounds.size
	var sample := _generated_layout.surface_sample_at_local(local.x, local.y, false)
	assert(not sample.is_empty(), "PaintSystem surface query must resolve through accepted top topology.")
	return sample
