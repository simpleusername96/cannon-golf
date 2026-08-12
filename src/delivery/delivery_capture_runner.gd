extends Node

const BACKGROUND_CAPTURE_SIZE := Vector2i(1280, 720)
const BACKGROUND_CAPTURE_POSITION := Vector2i(-32000, -32000)
const TIMEOUT_CAPTURE_TIME_SCALE := 8.0
const STAGE_PREPARATION_TIMEOUT_MSEC := 180_000

var _app: AppRoot
var _screen: String = ""
var _capture_stage: StringName = &"stage_01"
var _output_path: String = ""
var _background_capture := false
var _capture_size := BACKGROUND_CAPTURE_SIZE
var _capture_language: StringName = &"ko"
var _capture_settle_frames := -1
var _failed: bool = false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-screen="):
			_screen = argument.trim_prefix("--capture-screen=")
		elif argument.begins_with("--capture-stage="):
			_capture_stage = StringName(argument.trim_prefix("--capture-stage="))
		elif argument.begins_with("--capture-output="):
			_output_path = argument.trim_prefix("--capture-output=")
		elif argument.begins_with("--capture-size="):
			_capture_size = _parse_capture_size(argument.trim_prefix("--capture-size="))
		elif argument.begins_with("--capture-language="):
			_capture_language = StringName(
				argument.trim_prefix("--capture-language=")
			)
		elif argument.begins_with("--capture-settle-frames="):
			_capture_settle_frames = maxi(
				int(argument.trim_prefix("--capture-settle-frames=")), 0
			)
		elif argument == "--capture-background":
			_background_capture = true
	if _screen.is_empty() or _output_path.is_empty():
		return
	if StageCatalog.get_stage(_capture_stage) == null:
		push_error("Unknown capture stage: %s" % _capture_stage)
		get_tree().quit(1)
		return
	_configure_capture_window()
	_app = get_parent() as AppRoot
	# Child _ready() runs before AppRoot._ready(). Initialize deterministic capture
	# state here so AppRoot never starts preparing a persisted user selection.
	var game_state := get_node("/root/GameState") as GameState
	game_state.persistence_enabled = false
	var initial_data: Dictionary = get_node("/root/SaveSystem").default_data()
	initial_data.selected_stage_id = &"stage_01" \
			if _screen == "stage_transition_briefing" else _capture_stage
	_initialize_capture_game_state(game_state, initial_data)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_capture.call_deferred()


func _run_capture() -> void:
	_configure_capture_window()
	match _screen:
		"main_menu":
			_app._show_main_menu()
		"stage_select":
			_app._show_stage_select()
		"stage_select_page_2":
			_app._show_stage_select()
			await get_tree().process_frame
			_app.get_node("StageSelect").set_page_for_capture(1)
		"briefing":
			await _start_stage(_capture_stage, false)
		"stage_briefing":
			await _start_stage(_capture_stage, false)
		"stage_transition_briefing":
			await _capture_stage_transition()
		"aiming":
			await _capture_aiming(_capture_stage)
		"shot_follow_midflight":
			await _capture_shot_follow_midflight(_capture_stage)
		"shot_follow_impact_hold":
			await _capture_shot_follow_impact_hold(_capture_stage)
		"shot_follow_returned":
			await _capture_shot_follow_returned(_capture_stage)
		"progression_aiming":
			await _start_stage(_capture_stage, true)
			await get_tree().create_timer(1.0).timeout
		"map_inspection":
			await _capture_map_inspection(_capture_stage)
		"terrain_target_selected":
			await _capture_terrain_target_selected(_capture_stage)
		"terrain_target_dragged":
			await _capture_terrain_target_dragged(_capture_stage)
		"terrain_target_low_arc":
			await _capture_terrain_target_arc(_capture_stage, &"low")
		"terrain_target_high_arc":
			await _capture_terrain_target_arc(_capture_stage, &"high")
		"terrain_target_rejected":
			await _capture_terrain_target_rejected(_capture_stage)
		"protected_long_flight_impact":
			await _capture_protected_long_flight_impact(_capture_stage)
		"aim_return":
			await _capture_aim_return(_capture_stage)
		"summit_hit":
			await _capture_summit_hit()
		"next_aim_pending":
			await _capture_next_aim(false)
		"next_aim_ready":
			await _capture_next_aim(true)
		"target_nontarget_paint":
			await _capture_target_and_nontarget_paint(_capture_stage)
		"two_family":
			await _capture_two_family()
		"scale_contact":
			await _capture_scale_contact()
		"aiming_burst":
			var burst_stage := _capture_stage
			if StageCatalog.canonical_id(burst_stage) == &"stage_01":
				burst_stage = &"stage_02"
			await _capture_aiming(burst_stage)
		"aiming_split":
			var split_stage := _capture_stage
			if StageCatalog.canonical_id(split_stage) == &"stage_01":
				split_stage = &"stage_03"
			await _capture_aiming(split_stage)
		"projectile_and_continuous_paint":
			await _capture_continuous_paint()
		"observation":
			await _capture_continuous_paint()
		"pause":
			var paused_gameplay := await _start_stage(&"stage_01", true)
			if paused_gameplay == null:
				return
			(paused_gameplay.get_node("StageController") as StageController).toggle_pause()
			await get_tree().process_frame
		"settings":
			var settings_gameplay := await _start_stage(&"stage_01", true)
			if settings_gameplay == null:
				return
			(settings_gameplay.get_node("StageController") as StageController).toggle_pause()
			_app._show_settings(&"gameplay")
			await get_tree().process_frame
		"manual_result":
			await _capture_manual_result(_capture_stage)
		"timeout_result":
			await _capture_timeout_result(_capture_stage)
		_:
			push_error("Unknown delivery capture screen: %s" % _screen)
			get_tree().quit(1)
			return
	if _screen not in [
		"projectile_and_continuous_paint",
		"summit_hit",
		"next_aim_pending",
		"next_aim_ready",
		"two_family",
		"scale_contact",
		"protected_long_flight_impact",
	]:
		Engine.time_scale = 1.0
	if _failed:
		get_tree().quit(1)
		return
	var settle_frames := 42
	if _screen == "terrain_target_rejected":
		settle_frames = 2
	elif _screen in [
		"next_aim_pending",
		"next_aim_ready",
		"scale_contact",
		"protected_long_flight_impact",
		"shot_follow_midflight",
		"shot_follow_impact_hold",
		"shot_follow_returned",
	]:
		settle_frames = 0
	elif _screen == "two_family":
		settle_frames = 1
	if _capture_settle_frames >= 0:
		settle_frames = _capture_settle_frames
	for _frame in range(settle_frames):
		await get_tree().process_frame
	var absolute_path := ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	if image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		_fail_capture("The running renderer returned an empty capture image")
		get_tree().quit(1)
		return
	var error := image.save_png(absolute_path)
	print("Delivery capture %s -> %s (%dx%d, %s)" % [_screen, absolute_path, image.get_width(), image.get_height(), error_string(error)])
	# Paused captures can retain one deferred RefCounted object when the process
	# quits in the same frame. Tear down gameplay on the normal AppRoot boundary
	# and allow that queue to drain after the image has been saved.
	Engine.time_scale = 1.0
	if _app != null:
		_app._remove_gameplay()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if error == OK else 1)


func _configure_capture_window() -> void:
	if not _background_capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	# This remains a real Windows/Compatibility-renderer window. Keeping it
	# windowed, non-focusable, and outside the desktop lets UI work inspect the
	# actual runtime image without taking over the user's screen.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(_capture_size)
	DisplayServer.window_set_position(BACKGROUND_CAPTURE_POSITION)


func _start_stage(stage_id: StringName, begin_aiming: bool) -> Node3D:
	var game_state := get_node("/root/GameState")
	var data: Dictionary = get_node("/root/SaveSystem").default_data()
	data.selected_stage_id = stage_id
	_initialize_capture_game_state(game_state, data)
	_configure_capture_window()
	_app._start_stage(stage_id)
	var gameplay := await _wait_for_active_gameplay(stage_id)
	if gameplay == null:
		return null
	print("Delivery stage entry ready: stage=%s" % StageCatalog.canonical_id(stage_id))
	if begin_aiming:
		gameplay.get_node("StageController").begin_aiming()
	return gameplay


func _initialize_capture_game_state(game_state: GameState, data: Dictionary) -> void:
	var settings := Dictionary(data.get("settings", {})).duplicate(true)
	settings["language"] = String(_capture_language)
	settings["language_user_selected"] = true
	if _background_capture:
		# SettingsScreen reapplies the initialized display preference when it opens.
		# Keep that preference aligned with the requested off-screen capture size.
		settings["fullscreen"] = false
		settings["resolution"] = "%dx%d" % [_capture_size.x, _capture_size.y]
	data["settings"] = settings
	game_state.initialize_from_data(data)


func _wait_for_active_gameplay(stage_id: StringName) -> Node3D:
	var canonical_stage_id := StageCatalog.canonical_id(stage_id)
	var deadline := Time.get_ticks_msec() + STAGE_PREPARATION_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var gameplay := _app.get_node_or_null("ActiveGameplay") as Node3D
		var active_stage := gameplay.get("stage_data") as StageData \
				if gameplay != null and not gameplay.is_queued_for_deletion() else null
		if active_stage != null \
				and StageCatalog.canonical_id(active_stage.stage_id) == canonical_stage_id:
			return gameplay
		await get_tree().process_frame
	_fail_capture("stage %s did not finish background preparation" % canonical_stage_id)
	return null


func _capture_aiming(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	if director.current_interaction_mode != CameraDirector.InteractionMode.AIM_LOCKED:
		_fail_capture("aiming capture did not enter Aim Lock")
		return
	await get_tree().process_frame


func _capture_stage_transition() -> void:
	var first := await _start_stage(&"stage_01", false)
	if first == null:
		return
	_app._show_stage_select()
	await get_tree().process_frame
	var target_stage := StageCatalog.get_stage(_capture_stage)
	var stage_select := _app.get_node("StageSelect") as StageSelectScreen
	var page := (target_stage.stage_number - 1) / StageSelectScreen.PAGE_SIZE
	var slot := (target_stage.stage_number - 1) % StageSelectScreen.PAGE_SIZE
	stage_select.set_page_for_capture(page)
	await get_tree().process_frame
	RuntimeDeliveryTelemetry.emit_marker(&"stage_selection_started", {
		"from_stage_id": "stage_01",
		"to_stage_id": String(_capture_stage),
	})
	stage_select._cards[slot].pressed.emit()
	var deadline := Time.get_ticks_msec() + STAGE_PREPARATION_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _app._prepared_gameplay_matches(target_stage) \
				and not stage_select._start_button.disabled:
			break
		await get_tree().process_frame
	if not _app._prepared_gameplay_matches(target_stage) \
			or stage_select._start_button.disabled:
		_fail_capture("selected stage %s never became Start-ready" % _capture_stage)
		return
	var game_state := get_node("/root/GameState") as GameState
	if game_state.selected_stage_id != &"stage_01":
		_fail_capture("Stage Select committed the target before Start")
		return
	RuntimeDeliveryTelemetry.emit_marker(&"stage_selection_ready", {
		"stage_id": String(_capture_stage),
	})
	stage_select._start_button.pressed.emit()
	var second := await _wait_for_active_gameplay(_capture_stage)
	if second == null:
		return
	RuntimeDeliveryTelemetry.emit_marker(&"stage_selection_complete", {
		"stage_id": String(_capture_stage),
	})


func _capture_shot_follow_midflight(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	await _wait_for_cannon_prediction(cannon)
	if not controller.request_fire():
		_fail_capture("mid-flight capture could not fire the default root")
		return
	for _tick in range(45):
		await get_tree().physics_frame
	if director.current_mode != CameraDirector.Mode.FOLLOW \
			or director._follow_projectile == null \
			or director._follow_impact_hold_ticks > 0:
		_fail_capture("mid-flight capture did not retain the airborne root")


func _capture_shot_follow_impact_hold(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	await _wait_for_cannon_prediction(cannon)
	if not controller.request_fire():
		_fail_capture("impact-hold capture could not fire the default root")
		return
	var budget := 360
	while director._follow_impact_hold_ticks <= 0 and budget > 0:
		await get_tree().physics_frame
		budget -= 1
	if budget <= 0 or director.current_mode != CameraDirector.Mode.FOLLOW:
		_fail_capture("impact-hold capture did not observe first terrain contact")
		return
	await get_tree().process_frame


func _capture_shot_follow_returned(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	var manager := gameplay.get_node("ProjectileManager") as ProjectileManager
	await _wait_for_cannon_prediction(cannon)
	if not controller.request_fire():
		_fail_capture("returned-Aim capture could not fire the default root")
		return
	for _tick in range(30):
		await get_tree().physics_frame
	var residents_before := manager.active_count()
	if not director.return_to_aim_view(true):
		_fail_capture("returned-Aim capture could not leave Shot Follow")
		return
	for _frame in range(12):
		await get_tree().process_frame
	if director.current_mode != CameraDirector.Mode.AIMING \
			or residents_before <= 0 or manager.active_count() <= 0:
		_fail_capture("returning the camera changed projectile residency")


func _capture_map_inspection(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	if not director.set_interaction_mode(CameraDirector.InteractionMode.MAP_INSPECTION, true):
		_fail_capture("map inspection capture could not leave Aim Lock")
		return
	if not director.orbit_inspection(Vector2(42.0, -14.0)) \
			or not director.zoom_inspection(-1.0):
		_fail_capture("map inspection capture could not apply orbit and zoom")
		return
	await get_tree().create_timer(4.2).timeout
	if director.current_interaction_mode != CameraDirector.InteractionMode.MAP_INSPECTION:
		_fail_capture("map inspection capture did not retain Map Inspection")


func _capture_terrain_target_selected(stage_id: StringName) -> void:
	var gameplay := await _start_terrain_target_capture(stage_id)
	if gameplay == null:
		return
	var terrain_aim := gameplay.get_node("TerrainAimController") as TerrainAimController
	if terrain_aim.selected_target() == null \
			or terrain_aim.selected_target_state() not in [
				TerrainTargetPreview.STATE_SELECTED,
				TerrainTargetPreview.STATE_CONFIRMED,
			]:
		_fail_capture("selected-target capture did not expose a terrain target")


func _capture_terrain_target_dragged(stage_id: StringName) -> void:
	var gameplay := await _start_terrain_target_capture(stage_id)
	if gameplay == null:
		return
	var terrain_aim := gameplay.get_node("TerrainAimController") as TerrainAimController
	var terrain := gameplay.get_node("TerrainSurface") as TerrainSurface
	var camera := gameplay.get_node("Camera") as Camera3D
	var cannon := gameplay.get_node("Cannon") as CannonController
	var original := terrain_aim.selected_target()
	if original == null:
		_fail_capture("dragged-target capture has no initial target")
		return
	var drag_distance := maxf(cannon.projectile_data.radius * 0.75, 1.0)
	var desired := terrain.world_surface_point(
		Vector2(original.world_point.x, original.world_point.z)
				+ Vector2(drag_distance, -drag_distance)
	)
	if not desired.is_finite() or camera.is_position_behind(desired):
		_fail_capture("dragged-target capture could not derive a visible nearby top point")
		return
	var start_screen := camera.unproject_position(original.world_point)
	var end_screen := camera.unproject_position(desired)
	for sample_index in range(24):
		var progress := float(sample_index + 1) / 24.0
		if not terrain_aim.queue_pointer_target(
			start_screen.lerp(end_screen, progress),
			sample_index == 23
		):
			_fail_capture("dragged-target capture could not queue the latest pointer sample")
			return
	await get_tree().physics_frame
	if not await _wait_for_selected_terrain_target(terrain_aim):
		return
	var dragged := terrain_aim.selected_target()
	if dragged == null or dragged.world_point.distance_to(original.world_point) \
			< drag_distance * 0.45:
		_fail_capture("dragged-target capture did not move the selected surface point")


func _capture_terrain_target_arc(stage_id: StringName, branch: StringName) -> void:
	var gameplay := await _start_terrain_target_capture(stage_id)
	if gameplay == null:
		return
	var terrain_aim := gameplay.get_node("TerrainAimController") as TerrainAimController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var stage_controller := gameplay.get_node("StageController") as StageController
	var target := terrain_aim.selected_target()
	if target == null:
		_fail_capture("%s-arc capture has no selected target" % branch)
		return
	var initial_elevation := cannon.elevation_degrees
	if branch == &"low":
		if not terrain_aim.request_elevation_delta(0.5):
			_fail_capture("low-arc capture could not request a target-preserving angle step")
			return
		if not await _wait_for_selected_terrain_target(terrain_aim):
			return
	elif branch == &"high":
		if not await _request_delivery_arc_solution(
			gameplay, target, &"high", stage_controller, cannon
		):
			return
	else:
		_fail_capture("unknown terrain-target arc branch: %s" % branch)
		return
	var expected_high := branch == &"high"
	if (cannon.elevation_degrees >= TerrainAimSolver.BRANCH_SPLIT_ELEVATION_DEGREES) \
			!= expected_high:
		_fail_capture("%s-arc capture published the wrong ballistic branch" % branch)
		return
	if branch == &"low" and is_equal_approx(cannon.elevation_degrees, initial_elevation):
		_fail_capture("low-arc capture did not publish a distinct same-target angle")
		return
	if terrain_aim.selected_target() != target:
		_fail_capture("%s-arc capture did not retain the selected target" % branch)


func _capture_terrain_target_rejected(stage_id: StringName) -> void:
	var gameplay := await _start_terrain_target_capture(stage_id)
	if gameplay == null:
		return
	var terrain_aim := gameplay.get_node("TerrainAimController") as TerrainAimController
	var cannon := gameplay.get_node("Cannon") as CannonController
	# A low-branch target cannot silently flip to this high-branch elevation.
	# The normal controller path must restore the committed aim and show its X.
	var delta := AimTuple.MAXIMUM_ELEVATION_DEGREES - cannon.elevation_degrees
	if terrain_aim.request_elevation_delta(delta) \
			or terrain_aim.selected_target_state() != TerrainTargetPreview.STATE_REJECTED:
		_fail_capture("rejected-target capture did not reject the incompatible branch immediately")


func _capture_protected_long_flight_impact(stage_id: StringName) -> void:
	var gameplay := await _start_terrain_target_capture(stage_id)
	if gameplay == null:
		return
	var terrain_aim := gameplay.get_node("TerrainAimController") as TerrainAimController
	var terrain := gameplay.get_node("TerrainSurface") as TerrainSurface
	var manager := gameplay.get_node("ProjectileManager") as ProjectileManager
	var cannon := gameplay.get_node("Cannon") as CannonController
	var target := terrain_aim.selected_target()
	if target == null:
		_fail_capture("long-flight capture has no selected terrain target")
		return
	# This delivery-only drop isolates the lifetime promise from aim solving.
	# Prediction and the live body share the same sphere and authored play
	# bounds, while the selected marker supplies a visible impact.
	var maximum_height := manager.stage_bounds.end.y - target.world_point.y \
			- cannon.projectile_data.radius - 2.0
	var drop_height := minf(120.0, maximum_height)
	if drop_height < 90.0:
		_fail_capture("long-flight capture bounds cannot hold a greater-than-six-second drop")
		return
	var origin := target.world_point + Vector3.UP * drop_height
	var prediction := TrajectoryPredictor.predict_motion(
		gameplay.get_world_3d().direct_space_state,
		origin,
		Vector3.ZERO,
		cannon.projectile_data.radius,
		cannon.projectile_data.linear_damp,
		manager.stage_bounds
	)
	if prediction.kind != TrajectoryPrediction.Kind.COLLISION \
			or prediction.hit_identity == null \
			or prediction.hit_identity.contact_owner_id \
					!= TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID \
			or prediction.duration <= cannon.projectile_data.never_contacted_timeout:
		_fail_capture("long-flight capture did not predict a protected terrain-top impact")
		return
	var deadline := minf(
		cannon.projectile_data.predicted_contact_hard_maximum,
		maxf(
			cannon.projectile_data.never_contacted_timeout,
			prediction.duration + cannon.projectile_data.predicted_contact_grace
		)
	)
	var contact_state := {"seen": false, "contact": null}
	var root_projectile := manager.spawn_projectile(
		cannon.projectile_data,
		origin,
		Vector3.ZERO,
		0,
		0,
		deadline
	)
	if root_projectile == null:
		_fail_capture("long-flight capture could not spawn its protected root")
		return
	var contact_callback := func(projectile: PaintProjectile, contact: ProjectileContact) -> void:
		if projectile == root_projectile and contact != null \
				and contact.is_first_contact and terrain.is_top_collider(contact.collider):
			contact_state.seen = true
			contact_state.contact = contact
	manager.projectile_contact_reported.connect(
		contact_callback
	)
	var budget := ceili((deadline + 1.0) * float(Engine.physics_ticks_per_second))
	while not bool(contact_state.seen) and budget > 0 \
			and root_projectile.terminal_reason != ProjectileSettlementReason.MISSED_TERRAIN:
		await get_tree().physics_frame
		budget -= 1
	if manager.projectile_contact_reported.is_connected(contact_callback):
		manager.projectile_contact_reported.disconnect(contact_callback)
	if not bool(contact_state.seen):
		_fail_capture("protected long-flight root disappeared before its predicted top impact")
		return
	var contact := contact_state.contact as ProjectileContact
	if contact == null \
			or contact.world_position.distance_to(prediction.collision_contact_point()) > 0.25:
		_fail_capture("protected long-flight live contact diverged from its prediction")
		return
	# Hold the just-contacted real body long enough for the off-screen renderer
	# to capture it without changing gameplay ownership or adding a fake marker.
	Engine.time_scale = 0.08


func _start_terrain_target_capture(stage_id: StringName) -> Node3D:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return null
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	if not director.set_interaction_mode(
		CameraDirector.InteractionMode.AIM_LOCKED, true
	):
		_fail_capture("terrain-target capture could not settle the authored Aim View")
		return null
	var cannon := gameplay.get_node("Cannon") as CannonController
	var terrain_aim := gameplay.get_node("TerrainAimController") as TerrainAimController
	await _wait_for_cannon_prediction(cannon)
	if _failed or not await _wait_for_selected_terrain_target(terrain_aim):
		return null
	return gameplay


func _wait_for_selected_terrain_target(
		terrain_aim: TerrainAimController,
		maximum_ticks: int = 900
) -> bool:
	var budget := maximum_ticks
	while budget > 0:
		if terrain_aim.selected_target() != null \
				and terrain_aim.selected_target_state() in [
					TerrainTargetPreview.STATE_SELECTED,
					TerrainTargetPreview.STATE_CONFIRMED,
				]:
			return true
		await get_tree().physics_frame
		await get_tree().process_frame
		budget -= 1
	_fail_capture("terrain target did not become selectable inside the capture budget")
	return false


func _request_delivery_arc_solution(
		gameplay: Node3D,
		target: TerrainAimTarget,
		branch: StringName,
		stage_controller: StageController,
		cannon: CannonController
) -> bool:
	var high_reference := AimTuple.new(
		cannon.yaw_degrees,
		maxf(60.0, TerrainAimSolver.BRANCH_SPLIT_ELEVATION_DEGREES + 0.5),
		cannon.power_percent
	)
	var candidates := TerrainAimSolver.nominate(
		cannon,
		target,
		&"target",
		0.0,
		branch,
		high_reference
	)
	if candidates.is_empty():
		_fail_capture("%s-arc capture could not nominate a same-target solution" % branch)
		return false
	var aim := candidates[0].aim as AimTuple
	if not stage_controller.set_aim(
		aim.yaw_degrees,
		aim.elevation_degrees,
		aim.power_percent,
		StageController.ActionOrigin.DEBUG
	):
		_fail_capture("%s-arc capture could not commit its nominated aim" % branch)
		return false
	return true


func _capture_aim_return(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var director := gameplay.get_node("CameraDirector") as CameraDirector
	if not director.set_interaction_mode(CameraDirector.InteractionMode.MAP_INSPECTION, true):
		_fail_capture("aim return capture could not enter Map Inspection")
		return
	if not director.orbit_inspection(Vector2(-36.0, 12.0)) \
			or not director.zoom_inspection(-1.0):
		_fail_capture("aim return capture could not exercise map navigation")
		return
	for _frame in range(12):
		await get_tree().process_frame
	if not director.set_interaction_mode(CameraDirector.InteractionMode.AIM_LOCKED, true):
		_fail_capture("aim return capture could not restore Aim Lock")
		return
	await get_tree().create_timer(4.2).timeout
	if director.current_interaction_mode != CameraDirector.InteractionMode.AIM_LOCKED:
		_fail_capture("aim return capture did not retain Aim Lock")


func _capture_manual_result(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	if not await _fire_until_target_paint(gameplay):
		return
	var controller := gameplay.get_node("StageController") as StageController
	if not controller.finish_stage(StageController.ActionOrigin.HUMAN):
		_fail_capture("manual result capture could not accept Finish")
		return
	await get_tree().process_frame
	_validate_result_capture(controller, StageController.FINISH_REASON_MANUAL)


func _capture_timeout_result(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	await _wait_for_cannon_prediction(cannon)
	if not controller.request_fire():
		_fail_capture("timeout result capture could not fire the first root")
		return
	Engine.time_scale = TIMEOUT_CAPTURE_TIME_SCALE
	var budget := controller.remaining_run_ticks() + Engine.physics_ticks_per_second * 5
	while controller.current_state != StageController.State.RESULT and budget > 0:
		await get_tree().physics_frame
		budget -= 1
	Engine.time_scale = 1.0
	if budget <= 0:
		_fail_capture("timeout result capture did not reach RESULT inside its stage clock")
		return
	await get_tree().process_frame
	_validate_result_capture(controller, StageController.FINISH_REASON_TIMEOUT)


func _fire_until_target_paint(gameplay: Node3D) -> bool:
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var paint := gameplay.get_node("PaintSystem") as PaintSystem
	await _wait_for_cannon_prediction(cannon)
	if not controller.request_fire():
		_fail_capture("manual result capture could not fire the first root")
		return false
	Engine.time_scale = 3.0
	var budget := Engine.physics_ticks_per_second * 12
	while paint.painted_target_pixels() <= 0 \
			and controller.current_state == StageController.State.AIMING \
			and budget > 0:
		await get_tree().physics_frame
		budget -= 1
	Engine.time_scale = 1.0
	if paint.painted_target_pixels() <= 0:
		_fail_capture("manual result capture did not paint the target before Finish")
		return false
	return true


func _validate_result_capture(controller: StageController, expected_reason: StringName) -> void:
	if controller.current_state != StageController.State.RESULT:
		_fail_capture("result capture did not enter RESULT")
		return
	var result := controller.result_snapshot()
	if StringName(result.get("finish_reason", &"")) != expected_reason:
		_fail_capture("result capture stored the wrong finish reason")


func _capture_summit_hit() -> void:
	var gameplay := await _start_stage(_capture_stage, true)
	if gameplay == null:
		return
	await get_tree().process_frame
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var terrain := gameplay.get_node("TerrainSurface") as TerrainSurface
	var layout := gameplay.generated_layout() as GeneratedStageLayout
	var manager := gameplay.get_node("ProjectileManager") as ProjectileManager
	var contact_state := {"seen": false}
	manager.projectile_contact_reported.connect(
		func(_projectile: PaintProjectile, contact: ProjectileContact) -> void:
			if contact != null and terrain.is_top_collider(contact.collider):
				contact_state.seen = true
	)
	var summit_aim := layout.generated_summit_aim
	if summit_aim == null:
		_fail_capture("summit capture could not resolve a legal summit aim")
		return
	controller.set_aim(summit_aim.yaw_degrees, summit_aim.elevation_degrees, summit_aim.power_percent)
	await _wait_for_cannon_prediction(cannon)
	if not controller.request_fire():
		_fail_capture("summit capture could not fire the resolved summit aim")
		return
	var budget := 600
	while not bool(contact_state.seen) and budget > 0:
		await get_tree().physics_frame
		budget -= 1
	if not bool(contact_state.seen):
		_fail_capture("summit capture did not observe a real terrain contact")


func _capture_next_aim(wait_until_ready: bool) -> void:
	var gameplay := await _start_stage(_capture_stage, true)
	if gameplay == null:
		return
	await get_tree().process_frame
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var changed_yaw := cannon.yaw_degrees + 7.0
	controller.set_aim(changed_yaw, cannon.elevation_degrees, cannon.power_percent)
	if not wait_until_ready:
		# Keep the last complete arc visible while the world preview truthfully
		# shows its updating state. Fire admission must remain unchanged.
		gameplay.hold_prediction_refresh_for_delivery()
		await get_tree().process_frame
		if cannon.prediction_status() != &"pending" \
				or not controller.fire_readiness_snapshot().fireable:
			_fail_capture("pending preview capture changed legal Fire readiness")
		return
	await _wait_for_cannon_prediction(cannon)
	if not cannon.prediction_matches_expected_context() \
			or not controller.fire_readiness_snapshot().fireable:
		_fail_capture("changed aim did not publish its newest advisory preview")


func _capture_target_and_nontarget_paint(stage_id: StringName) -> void:
	var gameplay := await _start_stage(stage_id, true)
	if gameplay == null:
		return
	var layout := gameplay.generated_layout() as GeneratedStageLayout
	var terrain := gameplay.get_node("TerrainSurface") as TerrainSurface
	var paint := gameplay.get_node("PaintSystem") as PaintSystem
	var target_bytes := paint.target_bytes_read_only()
	var target_local := _nearest_mask_surface_local(
		layout,
		target_bytes,
		true,
		layout.target_centroid_local_xz(),
		0.0
	)
	var nontarget_local := _nearest_mask_surface_local(
		layout, target_bytes, false, target_local, 9.0
	)
	if not target_local.is_finite() or not nontarget_local.is_finite():
		_fail_capture("target/non-target capture could not find two playable patches")
		return
	var identity := paint.authoritative_top_surface_identity()
	for index in range(2):
		var local_xz := target_local if index == 0 else nontarget_local
		var sample := layout.surface_sample_at_local(local_xz.x, local_xz.y, false)
		var world_point := terrain.to_global(sample.point as Vector3)
		var world_normal := (
			terrain.global_transform.basis.inverse().transposed()
			* (sample.normal as Vector3)
		).normalized()
		var command := RadialPaintMark.new(
			Engine.get_physics_frames(),
			index,
			index,
			index,
			world_point,
			world_normal,
			4.0,
			identity.collider_rid as RID,
			StringName(identity.contact_owner_id),
			StringName(identity.contact_shape_id),
			int(identity.collider_shape_index),
			RadialPaintMark.Kind.IMPACT,
			index + 1
		)
		if not paint.queue_radial_paint_mark(command):
			_fail_capture("target/non-target capture rejected a canonical paint mark")
			return
	paint.drain_pending_commands()
	paint.force_flush_paint_texture()
	var painted_bytes := paint.paint_bytes_read_only()
	var painted_nontarget_pixels := 0
	for pixel_index in range(painted_bytes.size()):
		if painted_bytes[pixel_index] >= 128 and target_bytes[pixel_index] < 128:
			painted_nontarget_pixels += 1
	if paint.painted_target_pixels() <= 0 or painted_nontarget_pixels <= 0:
		_fail_capture("target/non-target capture did not publish both paint classes")
		return
	await get_tree().process_frame


func _nearest_mask_surface_local(
		layout: GeneratedStageLayout,
		target_bytes: PackedByteArray,
		desired_target: bool,
		reference: Vector2,
		minimum_distance: float
) -> Vector2:
	var best := Vector2(INF, INF)
	var best_distance := INF
	for pixel_y in range(2, PaintSystem.MASK_SIZE - 2, 2):
		for pixel_x in range(2, PaintSystem.MASK_SIZE - 2, 2):
			var pixel_index := pixel_y * PaintSystem.MASK_SIZE + pixel_x
			if (target_bytes[pixel_index] >= 128) != desired_target:
				continue
			var normalized := Vector2(
				(float(pixel_x) + 0.5) / float(PaintSystem.MASK_SIZE),
				(float(pixel_y) + 0.5) / float(PaintSystem.MASK_SIZE)
			)
			var local_xz := layout.local_bounds.position \
					+ normalized * layout.local_bounds.size
			var distance := local_xz.distance_to(reference)
			if distance < minimum_distance or distance >= best_distance \
					or layout.surface_sample_at_local(
						local_xz.x, local_xz.y, false
					).is_empty():
				continue
			best = local_xz
			best_distance = distance
	return best


func _capture_two_family() -> void:
	var gameplay := await _start_stage(_capture_stage, true)
	if gameplay == null:
		return
	await get_tree().process_frame
	var controller := gameplay.get_node("StageController") as StageController
	var cannon := gameplay.get_node("Cannon") as CannonController
	var manager := gameplay.get_node("ProjectileManager") as ProjectileManager
	if not controller.request_fire():
		_fail_capture("two-family capture could not fire the first root")
		return
	# Capture-only slow motion keeps the first family visible while the
	# coalesced next-aim prediction arrives.
	Engine.time_scale = 0.25
	controller.set_aim(cannon.yaw_degrees + 7.0, cannon.elevation_degrees, cannon.power_percent)
	await _wait_for_cannon_prediction(cannon)
	if not controller.request_fire():
		_fail_capture("two-family capture could not fire the second root")
		return
	if manager.active_root_count() < 2:
		_fail_capture("two-family capture did not retain two active root families")


func _capture_scale_contact() -> void:
	var gameplay := await _start_stage(_capture_stage, true)
	if gameplay == null:
		return
	await get_tree().process_frame
	var controller := gameplay.get_node("StageController") as StageController
	var manager := gameplay.get_node("ProjectileManager") as ProjectileManager
	var paint := gameplay.get_node("PaintSystem") as PaintSystem
	var contact_paint_seen := {"value": false}
	paint.paint_command_applied.connect(
		func(_command, written_pixel_count: int, _newly_painted_pixel_count: int) -> void:
			if written_pixel_count > 0 and manager.active_count() > 0:
				contact_paint_seen.value = true
	)
	if not controller.request_fire():
		_fail_capture("scale capture could not fire the default aim")
		return
	# Run the real flight at normal speed, then hold just after the first
	# authoritative mark so the frame contains the physical ball and paint.
	var budget := Engine.physics_ticks_per_second * 12
	while not bool(contact_paint_seen.value) and budget > 0:
		await get_tree().physics_frame
		budget -= 1
	if not bool(contact_paint_seen.value):
		_fail_capture("scale capture did not observe a live ball and target paint together")
		return
	Engine.time_scale = 0.08


func _wait_for_cannon_prediction(cannon: CannonController) -> void:
	var budget := 90
	while not cannon.prediction_matches_expected_context() and budget > 0:
		await get_tree().physics_frame
		budget -= 1
	if budget <= 0:
		_fail_capture("advisory prediction did not settle inside the capture budget")


func _capture_continuous_paint() -> void:
	var gameplay := await _start_stage(&"first_descent", true)
	if gameplay == null:
		return
	var controller: StageController = gameplay.get_node("StageController")
	var paint: PaintSystem = gameplay.get_node("PaintSystem")
	var manager: ProjectileManager = gameplay.get_node("ProjectileManager")
	var observed := {
		"written_pixels": 0,
		"sweep_count": 0,
		"active_sweep_intent_seen": false,
	}
	paint.paint_command_applied.connect(
		func(command, written_pixel_count: int, _newly_painted_pixel_count: int) -> void:
			observed.written_pixels += written_pixel_count
			if command is SurfacePaintSweep:
				observed.sweep_count += 1
	)
	# Record activity at the canonical intent boundary so the evidence proves the
	# persistent body and a real continuous-paint sweep coexisted.
	manager.surface_paint_sweep_ready.connect(
		func(_command: SurfacePaintSweep) -> void:
			if manager.active_count() > 0:
				observed.active_sweep_intent_seen = true
	)
	var initial_upload_count := paint.texture_upload_batch_count()
	if not controller.request_fire():
		_fail_capture("First Descent runtime default aim could not fire")
		return
	# Keep the physical ball on screen long enough to capture the first real
	# contact/sweep, then the outer runner restores normal time before saving.
	Engine.time_scale = 1.0
	var budget := 60 * 12
	while (
		int(observed.written_pixels) < 120
		or int(observed.sweep_count) < 12
		or not bool(observed.active_sweep_intent_seen)
	) and budget > 0:
		await get_tree().physics_frame
		budget -= 1
	if budget <= 0 or int(observed.written_pixels) < 120 \
			or int(observed.sweep_count) < 12 \
			or not bool(observed.active_sweep_intent_seen):
		_fail_capture("continuous paint did not arrive while the projectile was active")
		return
	if paint.texture_upload_batch_count() <= initial_upload_count:
		_fail_capture("continuous paint mask was not published to the terrain material")
		return
	gameplay.get_node("CameraDirector").set_mode(CameraDirector.Mode.AIMING, true)
	Engine.time_scale = 0.25


func _fail_capture(message: String) -> void:
	push_error("Delivery capture failed: %s" % message)
	_failed = true


func _parse_capture_size(value: String) -> Vector2i:
	var pieces := value.to_lower().split("x")
	if pieces.size() != 2:
		return BACKGROUND_CAPTURE_SIZE
	var width := maxi(320, pieces[0].to_int())
	var height := maxi(240, pieces[1].to_int())
	return Vector2i(width, height)
