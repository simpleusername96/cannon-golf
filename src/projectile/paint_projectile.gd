class_name PaintProjectile
extends RigidBody3D

signal contact_reported(projectile: PaintProjectile, contact: ProjectileContact)
signal radial_paint_mark_intent_requested(projectile: PaintProjectile, intent: RadialPaintMark)
signal surface_paint_sweep_intent_requested(projectile: PaintProjectile, intent: SurfacePaintSweep)
signal transient_splash_requested(projectile: PaintProjectile, contact: ProjectileContact)
signal valid_top_traversed(
	projectile: PaintProjectile,
	contact: ProjectileContact,
	base_paint_committed: bool
)
signal valid_top_exited(projectile: PaintProjectile)
signal motion_state_changed(
	projectile: PaintProjectile,
	previous_state: int,
	current_state: int
)
signal woke(projectile: PaintProjectile, reason: StringName)
signal terrain_recovered(projectile: PaintProjectile, physics_tick: int, correction_distance: float)
signal stopped(projectile: PaintProjectile, reason: StringName)

const IMPACT_SPEED_THRESHOLD := 8.0
const RECONTACT_ABSENCE_TICKS := 2
const RECOVERY_CLEARANCE_EPSILON := 0.01
const INVALID_GEOMETRY_CONFIRMATION_TICKS := 3
const RECOVERY_EVENT_MINIMUM_FRACTION := 0.25

enum MotionState {
	MOVING_AIRBORNE,
	MOVING_ON_TERRAIN,
	RESTING_ON_TERRAIN,
}

var projectile_data: ProjectileData
var split_generation: int = 0
var shot_id: int = 0
var stage_bounds := AABB(Vector3(-140.0, -30.0, -210.0), Vector3(280.0, 210.0, 260.0))
var spawn_ordinal: int:
	get:
		return _spawn_ordinal
var motion_state: MotionState:
	get:
		return _motion_state
var terminal_reason: StringName:
	get:
		return _terminal_reason
var never_contacted_deadline: float:
	get:
		return _never_contacted_deadline

var _terrain_surface: TerrainSurface
var _paint_surface_tuning: PaintSurfaceTuning
var _spawn_ordinal: int = -1
var _elapsed: float = 0.0
var _never_contacted_deadline: float = 0.0
var _deactivated: bool = false
var _motion_state: MotionState = MotionState.MOVING_AIRBORNE
var _terminal_reason: StringName = &""
var _has_touched_playable_top: bool = false
var _current_top_contact: ProjectileContact
var _current_paintable_top_contact: ProjectileContact
var _current_paintable_event_index: int = -1
var _last_valid_top_contact: ProjectileContact
var _sweep_anchor_contact: ProjectileContact
var _interval_last_contact: ProjectileContact
var _interval_missing_ticks: int = 0
var _has_emitted_first_impact: bool = false
var _needs_recontact_impact: bool = false
var _cached_incoming_velocity: Vector3 = Vector3.ZERO
var _contact_missing_ticks: Dictionary = {}
var _stable_identity_rids: Dictionary = {}
var _has_reported_contact: bool = false
var _invalid_geometry_ticks: int = 0
var _velocity_history: Array[Vector3] = []
var _queued_desired_velocity := Vector3.INF
var _queued_desired_velocity_tick: int = -1


func paint_radius_multiplier() -> float:
	return 0.78 if split_generation > 0 else 1.0


func physical_radius() -> float:
	return projectile_data.radius * (0.78 if split_generation > 0 else 1.0)


func has_reached_playable_top() -> bool:
	return _has_touched_playable_top


func is_resting_on_terrain() -> bool:
	return _motion_state == MotionState.RESTING_ON_TERRAIN


func configure(
		data: ProjectileData,
		bounds: AABB,
		terrain_surface: TerrainSurface,
		launch_velocity: Vector3,
		generation: int = 0,
		paint_surface_tuning: PaintSurfaceTuning = null,
		assigned_spawn_ordinal: int = -1,
		assigned_shot_id: int = 0,
		assigned_never_contacted_deadline: float = -1.0
) -> void:
	projectile_data = data
	stage_bounds = bounds
	_terrain_surface = terrain_surface
	_paint_surface_tuning = paint_surface_tuning
	_spawn_ordinal = assigned_spawn_ordinal
	shot_id = assigned_shot_id
	_never_contacted_deadline = maxf(
		projectile_data.never_contacted_timeout,
		minf(
			projectile_data.predicted_contact_hard_maximum,
			maxf(
				projectile_data.never_contacted_timeout,
				assigned_never_contacted_deadline
			)
		)
	)
	_cached_incoming_velocity = launch_velocity
	_velocity_history.assign([launch_velocity])
	split_generation = generation


func _ready() -> void:
	assert(projectile_data != null, "PaintProjectile requires ProjectileData before entering the tree.")
	assert(_terrain_surface != null, "PaintProjectile requires the authoritative TerrainSurface.")
	assert(_paint_surface_tuning != null and _paint_surface_tuning.is_valid(), "PaintProjectile requires valid paint-surface tuning.")
	assert(_spawn_ordinal >= 0, "PaintProjectile requires a stable per-shot spawn ordinal.")
	mass = projectile_data.mass
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = projectile_data.linear_damp
	angular_damp = projectile_data.angular_damp
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 16
	can_sleep = true
	collision_layer = 2
	collision_mask = 1 | 4
	_build_body()


func _physics_process(delta: float) -> void:
	if _deactivated:
		return
	_elapsed += delta
	if not stage_bounds.has_point(global_position):
		deactivate(ProjectileSettlementReason.ESCAPED_BOUNDS)
		return
	if not _has_touched_playable_top \
			and _elapsed >= _never_contacted_deadline:
		deactivate(ProjectileSettlementReason.MISSED_TERRAIN)
		return
	if sleeping and _has_touched_playable_top and _last_valid_top_contact != null:
		_set_motion_state(MotionState.RESTING_ON_TERRAIN)
	elif not sleeping and _motion_state == MotionState.RESTING_ON_TERRAIN:
		_set_motion_state(
			MotionState.MOVING_ON_TERRAIN
			if _current_paintable_top_contact != null
			else MotionState.MOVING_AIRBORNE
		)
		woke.emit(self, &"collision_or_force")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _deactivated:
		return
	var current_keys: Dictionary = {}
	var contacts_by_key: Dictionary = {}
	var identity_failure: StringName = &""
	var physics_tick := Engine.get_physics_frames()
	for index in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(index)
		var collider_shape := state.get_contact_collider_shape(index)
		var local_shape := state.get_contact_local_shape(index)
		var collider_rid := state.get_contact_collider(index)
		var identity := ProjectileContactIdentityResolver.resolve(collider, collider_shape)
		if not bool(identity.get("valid", false)):
			identity_failure = StringName(identity.get("reason", &"invalid_contact_identity"))
			break
		var stable_identity_key := "%s\u001f%s" % [
			String(identity.owner_id),
			String(identity.shape_id),
		]
		var collider_rid_id := collider_rid.get_id()
		if _stable_identity_rids.has(stable_identity_key) \
				and int(_stable_identity_rids[stable_identity_key]) != collider_rid_id:
			identity_failure = &"duplicate_stable_contact_identity"
			break
		_stable_identity_rids[stable_identity_key] = collider_rid_id
		var key := "%d:%d:%d" % [collider_rid.get_id(), collider_shape, local_shape]
		current_keys[key] = true
		var world_normal := state.get_contact_local_normal(index).normalized()
		var world_position := state.get_contact_collider_position(index)
		var collider_velocity := state.get_contact_collider_velocity_at_position(index)
		var incoming_velocity := _select_incoming_velocity(world_normal, collider_velocity)
		var relative_velocity := incoming_velocity - collider_velocity
		var relative_normal_speed := maxf(0.0, -relative_velocity.dot(world_normal))
		var impulse := state.get_contact_impulse(index)
		var impulse_was_measured := impulse.length_squared() >= 0.0001
		if not impulse_was_measured:
			impulse = Vector3.ZERO
		var contact := ProjectileContact.new(
			world_position,
			world_normal,
			state.transform.origin,
			absf(state.transform.origin.distance_to(world_position) - physical_radius()),
			incoming_velocity,
			relative_normal_speed,
			impulse,
			collider,
			local_shape,
			collider_shape,
			physics_tick,
			false,
			impulse_was_measured,
			StringName(identity.owner_id),
			StringName(identity.shape_id),
			collider_rid
		)
		var manifold_contacts: Array = contacts_by_key.get(key, [])
		manifold_contacts.append(contact)
		contacts_by_key[key] = manifold_contacts

	if not String(identity_failure).is_empty():
		push_error("PaintProjectile blocked an invalid gameplay contact identity: %s" % identity_failure)
		_deactivate_from_state(
			state,
			ProjectileSettlementReason.CONTACT_CONFIGURATION_ERROR
		)
		return

	var current_contacts: Array[ProjectileContact] = []
	var begun_contacts: Array[ProjectileContact] = []
	for key in contacts_by_key:
		var typed_manifold: Array[ProjectileContact] = []
		for contact: ProjectileContact in contacts_by_key[key]:
			typed_manifold.append(contact)
		var primary := _primary_contact(typed_manifold)
		current_contacts.append(primary)
		if not _contact_missing_ticks.has(key) \
				or int(_contact_missing_ticks[key]) >= RECONTACT_ABSENCE_TICKS:
			begun_contacts.append(primary)
		_contact_missing_ticks[key] = 0
	for key in _contact_missing_ticks.keys():
		if not current_keys.has(key):
			_contact_missing_ticks[key] = mini(
				int(_contact_missing_ticks[key]) + 1,
				RECONTACT_ABSENCE_TICKS
			)

	current_contacts.sort_custom(_stable_contact_less)
	begun_contacts.sort_custom(_stable_contact_less)
	for event_index in range(current_contacts.size()):
		current_contacts[event_index].assign_source_event_index(event_index)
	_current_top_contact = _first_top_contact(current_contacts)
	for contact in begun_contacts:
		if not contact.impulse_was_measured:
			var measured_normal_delta := maxf(
				0.0,
				(state.linear_velocity - contact.incoming_velocity).dot(contact.normal)
			)
			contact._impulse = contact.normal * measured_normal_delta * mass
		contact._is_first_contact = not _has_reported_contact
		_has_reported_contact = true
		contact_reported.emit(self, contact)
		if contact.relative_normal_speed >= IMPACT_SPEED_THRESHOLD:
			transient_splash_requested.emit(self, contact)

	_recover_terrain_embedding(state, _current_top_contact)
	if _deactivated:
		return
	_update_paintable_contact_interval(current_contacts, state.get_space_state())
	if _queued_desired_velocity != Vector3.INF and physics_tick > _queued_desired_velocity_tick:
		state.apply_central_impulse(mass * (_queued_desired_velocity - state.linear_velocity))
		_queued_desired_velocity = Vector3.INF
		_queued_desired_velocity_tick = -1
	_cached_incoming_velocity = state.linear_velocity
	_velocity_history.append(state.linear_velocity)
	if _velocity_history.size() > 3:
		_velocity_history.pop_front()


func queue_desired_velocity(desired_velocity: Vector3, contact_tick: int) -> void:
	if desired_velocity.is_finite() and not desired_velocity.is_zero_approx():
		var was_resting := _motion_state == MotionState.RESTING_ON_TERRAIN
		_queued_desired_velocity = desired_velocity
		_queued_desired_velocity_tick = contact_tick
		sleeping = false
		if _motion_state == MotionState.RESTING_ON_TERRAIN:
			_set_motion_state(MotionState.MOVING_ON_TERRAIN)
		if was_resting:
			woke.emit(self, &"mechanism_impulse")


func deactivate(reason: StringName) -> void:
	if _deactivated:
		return
	_deactivated = true
	_terminal_reason = reason
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	stopped.emit(self, reason)
	queue_free()


func _update_paintable_contact_interval(
		current_contacts: Array[ProjectileContact],
		space_state: PhysicsDirectSpaceState3D
) -> void:
	_current_paintable_top_contact = null
	_current_paintable_event_index = -1
	for event_index in range(current_contacts.size()):
		var contact := current_contacts[event_index]
		if SurfaceContactGapValidator.is_paintable_contact(
			_terrain_surface,
			_paint_surface_tuning,
			contact
		):
			_current_paintable_top_contact = contact
			_current_paintable_event_index = event_index
			break

	if _current_paintable_top_contact == null:
		if _motion_state != MotionState.RESTING_ON_TERRAIN:
			_set_motion_state(MotionState.MOVING_AIRBORNE)
		if _interval_last_contact != null:
			_interval_missing_ticks += 1
			if _interval_missing_ticks > _paint_surface_tuning.maximum_bridge_ticks:
				_needs_recontact_impact = true
				valid_top_exited.emit(self)
				_close_paint_interval()
		return

	var current := _current_paintable_top_contact
	var previous_valid_top_contact := _last_valid_top_contact
	_has_touched_playable_top = true
	_last_valid_top_contact = current
	_set_motion_state(
		MotionState.RESTING_ON_TERRAIN
		if sleeping
		else MotionState.MOVING_ON_TERRAIN
	)

	if not _has_emitted_first_impact or _sweep_anchor_contact == null \
			or _interval_last_contact == null \
			or not _interval_last_contact.same_collider_shape(current):
		var requires_impact := not _has_emitted_first_impact or _needs_recontact_impact \
				or (previous_valid_top_contact != null \
				and not previous_valid_top_contact.same_collider_shape(current))
		var impact_committed := true
		if requires_impact:
			impact_committed = _emit_impact_intent(
				current,
				_current_paintable_event_index
			)
		_has_emitted_first_impact = true
		_needs_recontact_impact = false
		_seed_paint_interval(current)
		valid_top_traversed.emit(self, current, impact_committed)
		return

	var missing_ticks := maxi(0, current.physics_tick - _interval_last_contact.physics_tick - 1)
	var bridged_gap := false
	if missing_ticks > 0:
		bridged_gap = SurfaceContactGapValidator.can_bridge(
			_terrain_surface,
			_paint_surface_tuning,
			_interval_last_contact,
			current,
			missing_ticks,
			space_state
		)
		if not bridged_gap:
			_seed_paint_interval(current)
			return

	var base_paint_committed := true
	if _sweep_anchor_contact.world_position.distance_to(current.world_position) \
			>= projectile_data.minimum_paint_travel_distance:
		base_paint_committed = _emit_sweep_intent(
			_sweep_anchor_contact,
			current,
			_current_paintable_event_index,
			bridged_gap
		)
		_sweep_anchor_contact = current
	_interval_last_contact = current
	_interval_missing_ticks = 0
	valid_top_traversed.emit(self, current, base_paint_committed)


func _seed_paint_interval(contact: ProjectileContact) -> void:
	_sweep_anchor_contact = contact
	_interval_last_contact = contact
	_interval_missing_ticks = 0


func _close_paint_interval() -> void:
	_sweep_anchor_contact = null
	_interval_last_contact = null
	_interval_missing_ticks = 0


func _set_motion_state(next_state: MotionState) -> void:
	if _motion_state == next_state:
		return
	var previous := _motion_state
	_motion_state = next_state
	if next_state == MotionState.RESTING_ON_TERRAIN:
		_close_paint_interval()
	motion_state_changed.emit(self, previous, next_state)


func _emit_impact_intent(contact: ProjectileContact, source_event_index: int) -> bool:
	var intent := RadialPaintMark.new(
		contact.physics_tick,
		_spawn_ordinal,
		source_event_index,
		-1,
		contact.world_position,
		contact.normal,
		projectile_data.impact_paint_radius * paint_radius_multiplier(),
		contact.collider_rid,
		contact.contact_owner_id,
		contact.contact_shape_id,
		contact.collider_shape_index,
			RadialPaintMark.Kind.IMPACT,
			shot_id
	)
	if intent.is_intent_valid():
		radial_paint_mark_intent_requested.emit(self, intent)
		return true
	return false


func _emit_sweep_intent(
		from_contact: ProjectileContact,
		to_contact: ProjectileContact,
		source_event_index: int,
		bridged_gap: bool
) -> bool:
	var intent := SurfacePaintSweep.new(
		to_contact.physics_tick,
		_spawn_ordinal,
		source_event_index,
		-1,
		from_contact.world_position,
		to_contact.world_position,
		from_contact.normal,
		to_contact.normal,
		projectile_data.paint_footprint_radius * paint_radius_multiplier(),
		to_contact.collider_rid,
		to_contact.contact_owner_id,
		to_contact.contact_shape_id,
		to_contact.collider_shape_index,
			bridged_gap,
			shot_id
	)
	if intent.is_intent_valid():
		surface_paint_sweep_intent_requested.emit(self, intent)
		return true
	return false


func _recover_terrain_embedding(
		state: PhysicsDirectBodyState3D,
		top_contact: ProjectileContact
) -> void:
	var center := state.transform.origin
	var probe_xz := Vector2(center.x, center.z)
	if top_contact != null:
		probe_xz = Vector2(top_contact.world_position.x, top_contact.world_position.z)
	if not _terrain_surface.contains_world_xz(probe_xz):
		if top_contact != null:
			_record_invalid_geometry(state, top_contact, &"top_contact_outside_playable_surface")
		else:
			_invalid_geometry_ticks = 0
		return

	var surface_point := _terrain_surface.world_surface_point(probe_xz)
	var surface_normal := _terrain_surface.world_surface_normal(probe_xz)
	if not surface_point.is_finite() or not surface_normal.is_finite() \
			or surface_normal.is_zero_approx():
		_record_invalid_geometry(state, top_contact, &"non_finite_surface_sample")
		return
	if top_contact != null and absf(
		(top_contact.world_position - surface_point).dot(surface_normal)
	) > TerrainTopTopology.HIT_HEIGHT_TOLERANCE:
		_record_invalid_geometry(state, top_contact, &"collider_surface_mismatch")
		return

	var signed_clearance := (center - surface_point).dot(surface_normal)
	# Without a real top contact, do not pre-empt the normal CCD collision. The
	# fallback only catches a body whose center has already tunneled below top.
	if top_contact == null and signed_clearance >= -RECOVERY_CLEARANCE_EPSILON:
		_invalid_geometry_ticks = 0
		return
	var correction_distance := physical_radius() - signed_clearance
	if correction_distance <= RECOVERY_CLEARANCE_EPSILON:
		_invalid_geometry_ticks = 0
		return
	var corrected_transform := state.transform
	corrected_transform.origin += surface_normal \
			* (correction_distance + RECOVERY_CLEARANCE_EPSILON)
	if not corrected_transform.origin.is_finite():
		_record_invalid_geometry(state, top_contact, &"non_finite_recovery_transform")
		return
	state.transform = corrected_transform
	var inward_normal_speed := state.linear_velocity.dot(surface_normal)
	if inward_normal_speed < 0.0:
		state.linear_velocity -= surface_normal * inward_normal_speed
	if correction_distance >= physical_radius() * RECOVERY_EVENT_MINIMUM_FRACTION:
		terrain_recovered.emit(self, Engine.get_physics_frames(), correction_distance)
	_invalid_geometry_ticks = 0


func _record_invalid_geometry(
		state: PhysicsDirectBodyState3D,
		contact: ProjectileContact,
		diagnostic: StringName
) -> void:
	_invalid_geometry_ticks += 1
	if _invalid_geometry_ticks < INVALID_GEOMETRY_CONFIRMATION_TICKS:
		return
	var contact_point := contact.world_position if contact != null else Vector3.INF
	push_warning(
		"PaintProjectile invalid geometry: diagnostic=%s shot=%d ordinal=%d center=%s contact=%s radius=%.3f" % [
			String(diagnostic),
			shot_id,
			_spawn_ordinal,
			str(state.transform.origin),
			str(contact_point),
			physical_radius(),
		]
	)
	_deactivate_from_state(state, ProjectileSettlementReason.INVALID_GEOMETRY)


func _deactivate_from_state(state: PhysicsDirectBodyState3D, reason: StringName) -> void:
	if _deactivated:
		return
	_deactivated = true
	_terminal_reason = reason
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	stopped.emit(self, reason)
	queue_free()


func _first_top_contact(contacts: Array[ProjectileContact]) -> ProjectileContact:
	for contact in contacts:
		if _terrain_surface.is_top_collider(contact.collider):
			return contact
	return null


func _stable_contact_less(a: ProjectileContact, b: ProjectileContact) -> bool:
	var a_owner := String(a.contact_owner_id)
	var b_owner := String(b.contact_owner_id)
	if a_owner != b_owner:
		return a_owner < b_owner
	var a_shape := String(a.contact_shape_id)
	var b_shape := String(b.contact_shape_id)
	if a_shape != b_shape:
		return a_shape < b_shape
	if a.local_shape_index != b.local_shape_index:
		return a.local_shape_index < b.local_shape_index
	return false


func _primary_contact(contacts: Array[ProjectileContact]) -> ProjectileContact:
	if contacts.is_empty():
		return null
	# A begun event represents one RID/collider-shape/local-shape key, not every raw
	# manifold point. Prefer measured impulse, then deterministic geometric ties.
	contacts.sort_custom(func(a: ProjectileContact, b: ProjectileContact) -> bool:
		var a_impulse := a.impulse.length_squared()
		var b_impulse := b.impulse.length_squared()
		if not is_equal_approx(a_impulse, b_impulse):
			return a_impulse > b_impulse
		if not is_equal_approx(a._selection_distance_error, b._selection_distance_error):
			return a._selection_distance_error < b._selection_distance_error
		if not is_equal_approx(a.world_position.x, b.world_position.x):
			return a.world_position.x < b.world_position.x
		if not is_equal_approx(a.world_position.y, b.world_position.y):
			return a.world_position.y < b.world_position.y
		return a.world_position.z < b.world_position.z
	)
	return contacts[0]


func _select_incoming_velocity(world_normal: Vector3, collider_velocity: Vector3) -> Vector3:
	var selected := _cached_incoming_velocity
	var selected_closing_speed := -(selected - collider_velocity).dot(world_normal)
	for candidate in _velocity_history:
		var closing_speed := -(candidate - collider_velocity).dot(world_normal)
		if closing_speed > selected_closing_speed:
			selected = candidate
			selected_closing_speed = closing_speed
	return selected


func _build_body() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = projectile_data.bounce
	material.friction = projectile_data.friction
	physics_material_override = material
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = physical_radius()
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = sphere_shape
	add_child(collision)
	var sphere_mesh := visual_mesh(projectile_data, 0.78 if split_generation > 0 else 1.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PaintballMesh"
	mesh_instance.mesh = sphere_mesh
	add_child(mesh_instance)


## Render-only projectile representation shared by live bodies and the stage
## warm-up path. It never creates physics state or emits gameplay signals.
static func visual_mesh(data: ProjectileData, radius_multiplier: float = 1.0) -> SphereMesh:
	assert(data != null, "Paint projectile visual requires ProjectileData.")
	var sphere_mesh := SphereMesh.new()
	var radius := data.radius * radius_multiplier
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	var paint_material := StandardMaterial3D.new()
	paint_material.albedo_color = Color(0.03, 0.36, 1.0, 1.0)
	paint_material.metallic = 0.16
	paint_material.roughness = 0.24
	sphere_mesh.material = paint_material
	return sphere_mesh
