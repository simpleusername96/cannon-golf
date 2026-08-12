class_name DebugOverlay
extends CanvasLayer

const GAMEPLAY_PACE := preload("res://src/gameplay/gameplay_pace.gd")

signal mechanism_labels_toggled(visible: bool)

var _stage_data: StageData
var _generated_layout: GeneratedStageLayout
var _controller: StageController
var _cannon: CannonController
var _projectiles: ProjectileManager
var _paint: PaintSystem
var _trajectory: TrajectoryPreview
var _camera: CameraDirector
var _mechanisms: Array[TerrainGlyphMechanism] = []
var _attempt_recorder: AttemptRecorder
var _root: Control
var _metrics: Label
var _paint_preview: TextureRect
var _target_preview: TextureRect
var _recent_preview: TextureRect
var _nontarget_preview: TextureRect
var _last_gain: float = 0.0
var _last_restart_ms: float = 0.0
var _slow_motion: bool = false
var _labels_visible: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	set_process(OS.is_debug_build())
	set_process_unhandled_input(OS.is_debug_build())


func configure(
		stage_data: StageData,
		controller: StageController,
		cannon: CannonController,
		projectiles: ProjectileManager,
		paint: PaintSystem,
		trajectory: TrajectoryPreview,
		camera: CameraDirector,
		mechanisms: Array[TerrainGlyphMechanism],
		attempt_recorder: AttemptRecorder,
		generated_layout: GeneratedStageLayout
) -> void:
	_stage_data = stage_data
	_generated_layout = generated_layout
	_controller = controller
	_cannon = cannon
	_projectiles = projectiles
	_paint = paint
	_trajectory = trajectory
	_camera = camera
	_mechanisms = mechanisms
	_attempt_recorder = attempt_recorder
	_paint_preview.texture = _paint.paint_texture()
	_target_preview.texture = _paint.target_texture()
	_nontarget_preview.texture = null
	_set_overlay_visible(visible)
	_controller.shot_result.connect(func(gain: float, _total: float) -> void: _last_gain = gain)
	_controller.restart_completed.connect(func(elapsed_ms: float) -> void: _last_restart_ms = elapsed_ms)
	if not _controller.state_changed.is_connected(_on_stage_state_changed):
		_controller.state_changed.connect(_on_stage_state_changed)


func _process(_delta: float) -> void:
	if not visible or _controller == null:
		return
	_paint_preview.texture = _paint.paint_texture()
	var velocity := Vector3.ZERO
	var active := _projectiles.active_projectiles()
	if not active.is_empty():
		velocity = active[0].linear_velocity
	var shot_observation := _controller.current_shot_observation()
	if shot_observation == null:
		shot_observation = _controller.last_sealed_shot_observation()
	var shot_command_count := (
		shot_observation.paint_command_count if shot_observation != null else 0
	)
	var mechanism_lines: Array[String] = []
	for mechanism in _mechanisms:
		var snapshot := mechanism.state_snapshot()
		mechanism_lines.append("%s charge=%s cd=%.2f" % [snapshot.kind, snapshot.remaining_charges, snapshot.cooldown])
	var seed := _generated_layout.terrain_seed if _generated_layout != null else 0
	_metrics.text = "STATE  %s\nFPS  %d\nPROJECTILES  %d / %d\nVELOCITY  %s\nPAINT COMMANDS  %d (PENDING %d)\nLAST DRAIN TICK  %d\nMASK CHECKSUM  %d\nCOVERAGE  %.3f%%\nSHOT GAIN  %.3f%%\nTRAJECTORY SAMPLES  %d\nFIRST COLLISION  %s\nMECHANISMS\n%s\nSEED  %d\nBOUNDS  %s\nCAMERA  %s\nRESTART  %.3f ms" % [
		_controller.state_name(),
		Engine.get_frames_per_second(),
		active.size(),
		ProjectileManager.MAXIMUM_ACTIVE_PROJECTILES,
		velocity,
		shot_command_count,
		_paint.pending_work_count(),
		_paint.last_drained_physics_tick(),
		_paint.paint_mask_checksum(),
		_paint.coverage_percent(),
		_last_gain,
		_trajectory.visible_sample_count(),
		str(_trajectory.first_collision_position) if _trajectory.has_first_collision else "NONE",
		"\n".join(mechanism_lines) if not mechanism_lines.is_empty() else "NONE",
		seed,
		_generated_layout.play_bounds.bounds,
		_camera.mode_name(),
		_last_restart_ms,
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_set_overlay_visible(not visible)
		get_viewport().set_input_as_handled()


func set_debug_visible(value: bool) -> void:
	_set_overlay_visible(value)


func _exit_tree() -> void:
	if _paint != null:
		_paint.set_recent_diagnostics_enabled(false)


func _set_overlay_visible(value: bool) -> void:
	visible = value and OS.is_debug_build()
	if _paint == null:
		return
	_paint.set_recent_diagnostics_enabled(visible)
	_recent_preview.texture = _paint.recent_texture() if visible else null
	_nontarget_preview.texture = _paint.nontarget_texture() if visible else null


func export_shot_log(path: String = "user://paint_mountain_shot_log.json") -> Error:
	if _attempt_recorder == null:
		return ERR_UNCONFIGURED
	var payload := _attempt_recorder.export_log()
	payload["exported_state"] = _controller.state_name()
	payload["coverage"] = _paint.coverage_percent()
	payload["last_shot_gain"] = _last_gain
	payload["mechanisms"] = []
	for mechanism in _mechanisms:
		payload.mechanisms.append(mechanism.state_snapshot())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return OK


func _build() -> void:
	_root = Control.new()
	_root.name = "DebugRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DebugPanel"
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(520.0, clampf(get_viewport().get_visible_rect().size.y - 36.0, 320.0, 920.0))
	_root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = panel.custom_minimum_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = "PAINT MOUNTAIN DEBUG  ·  F3"
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.2, 0.62, 1.0))
	content.add_child(heading)
	_metrics = Label.new()
	_metrics.custom_minimum_size.y = 410.0
	_metrics.add_theme_font_size_override("font_size", 13)
	_metrics.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	content.add_child(_metrics)
	var previews := GridContainer.new()
	previews.columns = 2
	previews.add_theme_constant_override("h_separation", 12)
	previews.add_theme_constant_override("v_separation", 8)
	content.add_child(previews)
	_paint_preview = _mask_preview("PAINT MASK", previews)
	_target_preview = _mask_preview("TARGET MASK", previews)
	_recent_preview = _mask_preview("RECENT STAMPS", previews)
	_nontarget_preview = _mask_preview("NON-TARGET MASK", previews)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	content.add_child(actions)
	_add_action(actions, "REFILL SHOTS", func() -> void: _run_debug_action(func() -> void: _controller.debug_refill_shots()))
	_add_action(actions, "CLEAR PAINT", func() -> void: _run_debug_action(func() -> void: _paint.clear()))
	_add_action(actions, "FORCE RESULT", func() -> void: _run_debug_action(func() -> void: _controller.force_finish_debug()))
	_add_action(actions, "TEST PROJECTILE", func() -> void: _run_debug_action(_spawn_test_projectile))
	_add_action(actions, "SLOW MOTION", func() -> void: _run_debug_action(_toggle_slow_motion))
	_add_action(actions, "MECHANISM LABELS", func() -> void: _run_debug_action(_toggle_labels))
	_add_action(actions, "SAVE AIM", func() -> void: _run_debug_action(_save_aim))
	_add_action(actions, "EXPORT SHOT LOG", func() -> void: export_shot_log())


func _mask_preview(caption: String, parent: Container) -> TextureRect:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	column.add_child(label)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(222.0, 105.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(preview)
	return preview


func _add_action(parent: GridContainer, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(228.0, 38.0)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	parent.add_child(button)


func _run_debug_action(action: Callable) -> void:
	if _controller == null:
		return
	action.call()


func _spawn_test_projectile() -> void:
	if _projectiles.active_count() >= ProjectileManager.MAXIMUM_ACTIVE_PROJECTILES:
		return
	_projectiles.spawn_projectile(_cannon.projectile_data, _cannon.get_launch_origin(), _cannon.get_launch_velocity())


func _toggle_slow_motion() -> void:
	_slow_motion = not _slow_motion
	_apply_time_scale_for_stage_state()


func _on_stage_state_changed(_current_state: int, _previous_state: int) -> void:
	_apply_time_scale_for_stage_state()


func _apply_time_scale_for_stage_state() -> void:
	if _controller == null or _controller.current_state != StageController.State.AIMING:
		GAMEPLAY_PACE.apply_normal()
	elif _slow_motion:
		GAMEPLAY_PACE.apply_debug_slow_motion()
	else:
		GAMEPLAY_PACE.apply_active()


func _toggle_labels() -> void:
	_labels_visible = not _labels_visible
	mechanism_labels_toggled.emit(_labels_visible)


func _save_aim() -> void:
	var file := FileAccess.open("user://paint_mountain_debug_aim.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"stage_id": String(_stage_data.stage_id),
		"yaw": _cannon.yaw_degrees,
		"elevation": _cannon.elevation_degrees,
		"power": _cannon.power_percent,
	}, "\t"))
	file.close()
