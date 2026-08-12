class_name ProjectileManager
extends Node3D

signal projectile_spawned(projectile: PaintProjectile)
signal projectile_contact_reported(projectile: PaintProjectile, contact: ProjectileContact)
signal radial_paint_mark_ready(command: RadialPaintMark)
signal surface_paint_sweep_ready(command: SurfacePaintSweep)
signal transient_splash_requested(projectile: PaintProjectile, contact: ProjectileContact)
signal valid_top_traversed(projectile: PaintProjectile, contact: ProjectileContact, base_paint_committed: bool)
signal valid_top_exited(projectile: PaintProjectile)
signal projectile_stopped(projectile: PaintProjectile, reason: StringName)
signal projectile_motion_state_changed(projectile: PaintProjectile, previous_state: int, current_state: int)
signal projectile_woke(projectile: PaintProjectile, reason: StringName)
signal projectile_terrain_recovered(projectile: PaintProjectile, physics_tick: int, correction_distance: float)
signal all_projectiles_settled
signal shot_family_started(shot_id: int, root_projectile: PaintProjectile)
signal shot_family_finished(shot_id: int)
signal initial_root_launch_finished(shot_id: int)
signal activity_changed(active_shot_ids: PackedInt64Array, active_projectiles: int)
signal resident_activity_changed(moving_projectiles: int, resting_projectiles: int)

const MAXIMUM_ACTIVE_PROJECTILES := 21
const MAXIMUM_ACTIVE_ROOT_LAUNCHES := 2
const COMMAND_CANONICALIZATION_PRIORITY := 900
const DEFAULT_PAINT_SURFACE_TUNING := preload("res://resources/paint/default_paint_surface_tuning.tres")

var stage_bounds := AABB(Vector3(-140.0, -30.0, -210.0), Vector3(280.0, 210.0, 260.0))
var _terrain_surface: TerrainSurface
var _paint_surface_tuning: PaintSurfaceTuning = DEFAULT_PAINT_SURFACE_TUNING
var _active: Array[PaintProjectile] = []
var _settlement_check_queued := false
var _pending_intents: Array[Dictionary] = []
var _next_spawn_ordinal: int = 0
var _next_shot_id: int = 1
var _next_sequence_by_ordinal: Dictionary = {}
# Fire capacity and observation complete on different lifecycle boundaries.
# The first ends when a generation-0 launch reaches playable terrain; the
# second ends when every current family body has done so or has terminated.
# Terrain residents can continue moving for the stage without holding either.
var _active_initial_launch_shot_ids: Dictionary = {}
var _unsettled_shot_family_ids: Dictionary = {}
var _shot_ids_pending_post_stop_refresh: Dictionary = {}


func _init() -> void:
	process_physics_priority = COMMAND_CANONICALIZATION_PRIORITY


func configure_terrain(
		terrain_surface: TerrainSurface,
		paint_surface_tuning: PaintSurfaceTuning = DEFAULT_PAINT_SURFACE_TUNING
) -> void:
	assert(terrain_surface != null, "ProjectileManager requires TerrainSurface.")
	assert(paint_surface_tuning != null and paint_surface_tuning.is_valid(), "ProjectileManager requires valid paint-surface tuning.")
	_terrain_surface = terrain_surface
	_paint_surface_tuning = paint_surface_tuning


func spawn_projectile(
		projectile_data: ProjectileData,
		origin: Vector3,
		velocity: Vector3,
		split_generation: int = 0,
		requested_shot_id: int = 0,
		never_contacted_deadline: float = -1.0
) -> PaintProjectile:
	_prune_invalid()
	if _active.size() >= MAXIMUM_ACTIVE_PROJECTILES or _terrain_surface == null:
		return null
	if split_generation == 0 \
			and _active_initial_launch_shot_ids.size() >= MAXIMUM_ACTIVE_ROOT_LAUNCHES:
		return null
	if split_generation == 0 and requested_shot_id > 0:
		# Initial root identity is manager-owned. Accepting a caller-provided root
		# ID could merge two launches into one capacity slot.
		return null
	if split_generation > 0 and requested_shot_id <= 0:
		return null
	# Spawn ordinals stay monotonic for the complete attempt. This is important
	# when a new root is fired while the previous family's paint commands are
	# still queued: command identity must never collide across families.
	var assigned_ordinal := _next_spawn_ordinal
	_next_spawn_ordinal += 1
	var assigned_shot_id := requested_shot_id
	if split_generation == 0:
		assigned_shot_id = _next_shot_id
		_next_shot_id += 1
	var projectile := PaintProjectile.new()
	projectile.name = "PaintProjectile%02d" % (assigned_ordinal + 1)
	projectile.configure(
		projectile_data,
		stage_bounds,
		_terrain_surface,
		velocity,
		split_generation,
		_paint_surface_tuning,
		assigned_ordinal,
		assigned_shot_id,
		never_contacted_deadline if split_generation == 0 else -1.0
	)
	projectile.contact_reported.connect(_on_contact_reported)
	projectile.radial_paint_mark_intent_requested.connect(_on_radial_paint_mark_intent)
	projectile.surface_paint_sweep_intent_requested.connect(_on_surface_paint_sweep_intent)
	projectile.transient_splash_requested.connect(_on_transient_splash_requested)
	projectile.valid_top_traversed.connect(_on_valid_top_traversed)
	projectile.valid_top_exited.connect(_on_valid_top_exited)
	projectile.motion_state_changed.connect(_on_projectile_motion_state_changed)
	projectile.woke.connect(_on_projectile_woke)
	projectile.terrain_recovered.connect(_on_projectile_terrain_recovered)
	projectile.stopped.connect(_on_projectile_stopped)
	projectile.position = to_local(origin)
	projectile.linear_velocity = velocity
	add_child(projectile)
	_active.append(projectile)
	projectile_spawned.emit(projectile)
	if split_generation == 0:
		_active_initial_launch_shot_ids[assigned_shot_id] = true
		_unsettled_shot_family_ids[assigned_shot_id] = true
		shot_family_started.emit(assigned_shot_id, projectile)
	_emit_activity_changed()
	return projectile


func active_count() -> int:
	_prune_invalid()
	return _active.size()


func active_projectiles() -> Array[PaintProjectile]:
	_prune_invalid()
	return _active.duplicate()


func resident_activity_snapshot() -> Dictionary:
	_prune_invalid()
	var resting := 0
	for projectile in _active:
		if projectile.is_resting_on_terrain():
			resting += 1
	return {
		"moving": _active.size() - resting,
		"resting": resting,
	}


func pending_intent_count() -> int:
	return _pending_intents.size()


## Publishes every already accepted paint intent in canonical order. Result
## owners call this before PaintSystem's final drain and projectile cleanup.
## Repeated calls are safe and return zero after the first drain.
func finalize_pending_paint_intents() -> int:
	if _pending_intents.is_empty():
		return 0
	var ready := _pending_intents
	_pending_intents = []
	return _emit_canonicalized_intents(ready)


func active_shot_ids() -> PackedInt64Array:
	_prune_invalid()
	var ids := PackedInt64Array()
	for projectile in _active:
		if projectile.shot_id > 0 and not ids.has(projectile.shot_id):
			ids.append(projectile.shot_id)
	ids.sort()
	return ids


func active_root_count() -> int:
	_prune_invalid()
	return _active_initial_launch_shot_ids.size()


func initial_flight_shot_ids() -> PackedInt64Array:
	_prune_invalid()
	var ids := PackedInt64Array()
	for shot_id in _active_initial_launch_shot_ids:
		ids.append(int(shot_id))
	ids.sort()
	return ids


func root_capacity_available(maximum_roots: int = MAXIMUM_ACTIVE_ROOT_LAUNCHES) -> bool:
	return active_root_count() < maxi(1, maximum_roots)


## Admits a Splitter replacement without exposing resident-count arithmetic to
## mechanism nodes. The consumed parent must still be a managed resident.
func can_replace_resident_with_children(parent: PaintProjectile, child_count: int) -> bool:
	_prune_invalid()
	return parent != null and is_instance_valid(parent) and _active.has(parent) \
			and child_count > 0 and _active.size() - 1 + child_count \
			<= MAXIMUM_ACTIVE_PROJECTILES


## Current catalog policy bound, not a general branching simulator. A valid
## Splitter can replace one body per generation with its configured children.
static func maximum_residents_for_stage(
		maximum_shots: int,
		mechanisms: Array[MechanismData]
) -> int:
	var per_root := 1
	for mechanism in mechanisms:
		if mechanism == null or not mechanism.is_valid() \
				or mechanism.canonical_kind() != MechanismData.Kind.SPLITTER:
			continue
		per_root = maxi(
			per_root,
			int(pow(float(mechanism.child_count), float(mechanism.maximum_split_generation)))
		)
	return maxi(maximum_shots, 0) * per_root


static func stage_resident_capacity_is_valid(
		maximum_shots: int,
		mechanisms: Array[MechanismData]
) -> bool:
	return maximum_residents_for_stage(maximum_shots, mechanisms) <= MAXIMUM_ACTIVE_PROJECTILES


func submit_radial_paint_intent(intent: RadialPaintMark) -> bool:
	if intent == null or not intent.is_intent_valid():
		return false
	_pending_intents.append({"intent": intent})
	return true


func submit_surface_paint_intent(intent: SurfacePaintSweep) -> bool:
	if intent == null or not intent.is_intent_valid():
		return false
	_pending_intents.append({"intent": intent})
	return true


func cleanup() -> void:
	_settlement_check_queued = false
	_pending_intents.clear()
	_begin_shot_ordering()
	_next_shot_id = 1
	_active_initial_launch_shot_ids.clear()
	_unsettled_shot_family_ids.clear()
	_shot_ids_pending_post_stop_refresh.clear()
	for projectile in _active:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_active.clear()
	_emit_activity_changed()
	all_projectiles_settled.emit()


func _physics_process(_delta: float) -> void:
	_canonicalize_completed_ticks(Engine.get_physics_frames())


func _begin_shot_ordering() -> void:
	_next_spawn_ordinal = 0
	_next_sequence_by_ordinal.clear()


func _on_contact_reported(projectile: PaintProjectile, contact: ProjectileContact) -> void:
	projectile_contact_reported.emit(projectile, contact)


func _on_radial_paint_mark_intent(
		_projectile: PaintProjectile,
		intent: RadialPaintMark
) -> void:
	submit_radial_paint_intent(intent)


func _on_surface_paint_sweep_intent(
		_projectile: PaintProjectile,
		intent: SurfacePaintSweep
) -> void:
	submit_surface_paint_intent(intent)


func _canonicalize_completed_ticks(current_physics_tick: int) -> void:
	if _pending_intents.is_empty():
		return
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for entry in _pending_intents:
		var intent: Variant = entry.intent
		if int(intent.physics_tick) < current_physics_tick:
			ready.append(entry)
		else:
			waiting.append(entry)
	_pending_intents = waiting
	_emit_canonicalized_intents(ready)


func _emit_canonicalized_intents(entries: Array[Dictionary]) -> int:
	if entries.is_empty():
		return 0
	entries.sort_custom(_intent_entry_less)
	for entry in entries:
		var intent: Variant = entry.intent
		var ordinal := int(intent.spawn_ordinal)
		var sequence := int(_next_sequence_by_ordinal.get(ordinal, 0))
		_next_sequence_by_ordinal[ordinal] = sequence + 1
		if intent is RadialPaintMark:
			var radial := (intent as RadialPaintMark).with_sequence(sequence)
			assert(radial.is_valid(), "Canonicalized radial command must be valid.")
			radial_paint_mark_ready.emit(radial)
		elif intent is SurfacePaintSweep:
			var sweep := (intent as SurfacePaintSweep).with_sequence(sequence)
			assert(sweep.is_valid(), "Canonicalized sweep command must be valid.")
			surface_paint_sweep_ready.emit(sweep)
	return entries.size()


func _intent_entry_less(a: Dictionary, b: Dictionary) -> bool:
	var a_key: Array = a.intent.queue_sort_key()
	var b_key: Array = b.intent.queue_sort_key()
	for index in range(mini(a_key.size(), b_key.size())):
		if a_key[index] == b_key[index]:
			continue
		return a_key[index] < b_key[index]
	return a_key.size() < b_key.size()


func _on_transient_splash_requested(projectile: PaintProjectile, contact: ProjectileContact) -> void:
	transient_splash_requested.emit(projectile, contact)


func _on_valid_top_traversed(
		projectile: PaintProjectile,
		contact: ProjectileContact,
		base_paint_committed: bool
) -> void:
	valid_top_traversed.emit(projectile, contact, base_paint_committed)
	if projectile == null:
		return
	if projectile.split_generation == 0:
		_release_initial_root_launch(projectile.shot_id)
	_refresh_unsettled_shot_family(projectile.shot_id)
	_emit_activity_changed()


func _on_valid_top_exited(projectile: PaintProjectile) -> void:
	valid_top_exited.emit(projectile)


func _on_projectile_motion_state_changed(
		projectile: PaintProjectile,
		_previous_state: int,
		current_state: int
) -> void:
	projectile_motion_state_changed.emit(projectile, _previous_state, current_state)
	if projectile == null:
		return
	_emit_activity_changed()


func _on_projectile_woke(
		projectile: PaintProjectile,
		reason: StringName
) -> void:
	projectile_woke.emit(projectile, reason)


func _on_projectile_terrain_recovered(
		projectile: PaintProjectile,
		physics_tick: int,
		correction_distance: float
) -> void:
	projectile_terrain_recovered.emit(projectile, physics_tick, correction_distance)


func _on_projectile_stopped(projectile: PaintProjectile, reason: StringName) -> void:
	_active.erase(projectile)
	projectile_stopped.emit(projectile, reason)
	var shot_id := projectile.shot_id
	# Splitter consumes its root before it adds children in the same call stack.
	# Defer both lifecycle boundaries so family completion cannot occur between
	# parent consumption and admission of all replacement children.
	if shot_id > 0:
		_shot_ids_pending_post_stop_refresh[shot_id] = true
		_refresh_lifecycles_after_stop.call_deferred(shot_id, projectile.split_generation == 0)
	if _active.is_empty() and not _settlement_check_queued:
		_settlement_check_queued = true
		_emit_settled_if_still_empty.call_deferred()


func _emit_settled_if_still_empty() -> void:
	if not _settlement_check_queued:
		return
	_settlement_check_queued = false
	_prune_invalid()
	if _active.is_empty():
		all_projectiles_settled.emit()
	_emit_activity_changed()


func _prune_invalid() -> void:
	for index in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[index]):
			_active.remove_at(index)
	for shot_id in _active_initial_launch_shot_ids.keys():
		_refresh_initial_root_launch_without_prune(int(shot_id))
	for shot_id in _unsettled_shot_family_ids.keys():
		if _shot_ids_pending_post_stop_refresh.has(shot_id):
			continue
		_refresh_unsettled_shot_family_without_prune(int(shot_id))


func _has_active_shot_id(shot_id: int) -> bool:
	for projectile in _active:
		if is_instance_valid(projectile) and projectile.shot_id == shot_id:
			return true
	return false


func _refresh_lifecycles_after_stop(shot_id: int, stopped_root: bool) -> void:
	_shot_ids_pending_post_stop_refresh.erase(shot_id)
	_prune_invalid()
	if stopped_root:
		_release_initial_root_launch(shot_id)
	_refresh_unsettled_shot_family(shot_id)
	_emit_activity_changed()


func _release_initial_root_launch(shot_id: int) -> void:
	if shot_id <= 0 or not _active_initial_launch_shot_ids.has(shot_id):
		return
	_active_initial_launch_shot_ids.erase(shot_id)
	initial_root_launch_finished.emit(shot_id)


func _refresh_initial_root_launch_without_prune(shot_id: int) -> void:
	if shot_id <= 0 or not _active_initial_launch_shot_ids.has(shot_id):
		return
	for projectile in _active:
		if is_instance_valid(projectile) and projectile.shot_id == shot_id \
				and projectile.split_generation == 0 \
				and not projectile.has_reached_playable_top():
			return
	_release_initial_root_launch(shot_id)


func _refresh_unsettled_shot_family(shot_id: int) -> void:
	_prune_invalid()
	_refresh_unsettled_shot_family_without_prune(shot_id)


func _refresh_unsettled_shot_family_without_prune(shot_id: int) -> void:
	if shot_id <= 0 or not _unsettled_shot_family_ids.has(shot_id):
		return
	for projectile in _active:
		if is_instance_valid(projectile) and projectile.shot_id == shot_id \
				and not projectile.has_reached_playable_top():
			return
	_unsettled_shot_family_ids.erase(shot_id)
	shot_family_finished.emit(shot_id)


func _emit_activity_changed() -> void:
	activity_changed.emit(active_shot_ids(), _active.size())
	var resident_activity := resident_activity_snapshot()
	resident_activity_changed.emit(
		int(resident_activity.moving),
		int(resident_activity.resting)
	)
