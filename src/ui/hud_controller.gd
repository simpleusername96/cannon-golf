class_name HUDController
extends CanvasLayer

signal begin_aiming_requested
signal fire_requested
signal restart_requested
signal pause_requested
signal settings_requested
signal stage_select_requested
signal main_menu_requested
signal next_stage_requested
signal finish_requested
signal interaction_mode_requested(mode: int)
signal return_to_cannon_requested
signal power_step_requested(direction: float)
signal angle_step_requested(direction: float)

@onready var _top: TopStatusBar = %TopStatusBar
@onready var _aim: AimControls = %AimControls
@onready var _coverage: CoverageMeter = %CoverageMeter
@onready var _actions: ActionButtons = %ActionButtons
@onready var _run_status: RunStatusCard = %RunStatusCard
@onready var _interaction: CameraInteractionControl = %CameraInteractionControl
@onready var _return_to_cannon: Button = %ReturnToCannon
@onready var _result: ResultPanel = %ResultPanel
@onready var _briefing: Control = %BriefingActions
@onready var _pause: PauseOverlay = %PauseOverlay
@onready var _context_legend: ContextLegend = %ContextLegend
var _stage_data: StageData
var _current_state := StageController.State.LOADING
var _shots_remaining := 0
var _last_aim := Vector3.ZERO
var _last_coverage := 0.0
var _current_interaction_mode := CameraDirector.InteractionMode.AIM_LOCKED
var _current_camera_mode := CameraDirector.Mode.BRIEFING
var _run_started := false
var _clock_finished := false
var _pause_overlay_suspended := false


func update_clock(snapshot: Dictionary) -> void:
	_run_started = bool(snapshot.get("started", false))
	_clock_finished = bool(snapshot.get("finished", false))
	_run_status.update_clock(snapshot)
	_apply_finish_availability()


func _ready() -> void:
	_return_to_cannon.hide()
	_connect_components()
	get_node("/root/GameState").settings_changed.connect(_on_settings_changed)
	_refresh_briefing_locale()
	_refresh_context_legend()


func configure(stage_data: StageData) -> void:
	_stage_data = stage_data
	_top.configure(stage_data)
	_coverage.configure(stage_data.target_coverage)
	_run_started = false
	_clock_finished = false
	_run_status.reset_for_stage(stage_data.maximum_shots, stage_data.resolved_duration_seconds())
	_result.configure_has_next(not StageCatalog.next_stage_id(stage_data.stage_id).is_empty())
	_result.configure_target(stage_data.target_coverage)
	update_shots(stage_data.maximum_shots, stage_data.maximum_shots)


func update_aim(yaw: float, elevation: float, power: float) -> void:
	_last_aim = Vector3(yaw, elevation, power)
	_aim.update_aim(yaw, elevation, power)


func update_shots(remaining: int, _maximum: int) -> void:
	_shots_remaining = remaining
	_run_status.update_shots(remaining)


func update_coverage(value: float) -> void:
	_last_coverage = value
	_coverage.update_coverage(value)


func set_fire_readiness(snapshot: Dictionary) -> void:
	_actions.set_fire_readiness(snapshot)


func show_state(state: StageController.State) -> void:
	_current_state = state
	_top.update_mode(state)
	# The interaction toggle is the only mode label during the Board Phase.
	# Keeping the serial-state "Aiming" chip beside "Map Inspection" is
	# truthful internally but contradictory to players.
	_top.mode_value.get_parent().visible = state != StageController.State.AIMING
	_briefing.visible = state == StageController.State.BRIEFING
	var aiming_surface := state in [
		StageController.State.AIMING,
	]
	_interaction.visible = aiming_surface
	_interaction.set_mode_switch_available(aiming_surface)
	_apply_interaction_presentation(false)
	_run_status.visible = aiming_surface
	_apply_finish_availability()
	_coverage.visible = state not in [StageController.State.LOADING, StageController.State.BRIEFING]
	_result.visible = state == StageController.State.RESULT
	_pause.visible = state == StageController.State.PAUSED and not _pause_overlay_suspended
	_refresh_context_legend()
	if state == StageController.State.BRIEFING:
		%Start.grab_focus()
	elif state == StageController.State.AIMING:
		if _current_interaction_mode == CameraDirector.InteractionMode.AIM_LOCKED:
			_actions.focus_fire()
		else:
			_interaction.grab_focus()
	elif state == StageController.State.RESULT:
		_result.focus_retry()
	elif state == StageController.State.PAUSED:
		_pause.focus_resume.call_deferred()


func set_interaction_mode(mode: CameraDirector.InteractionMode) -> void:
	_current_interaction_mode = mode
	_interaction.set_interaction_mode(mode)
	_apply_interaction_presentation(true)
	_refresh_context_legend()


func set_camera_mode(mode: CameraDirector.Mode) -> void:
	_current_camera_mode = mode
	_return_to_cannon.visible = mode == CameraDirector.Mode.FOLLOW
	var aiming_surface := _current_state == StageController.State.AIMING \
			and mode == CameraDirector.Mode.AIMING
	_interaction.visible = aiming_surface
	_interaction.set_mode_switch_available(aiming_surface)
	_apply_interaction_presentation(false)
	_refresh_context_legend()


func show_coverage_result(
		final_coverage: float,
		star_count: int,
		previous_best: float = 0.0,
		elapsed_seconds: float = -1.0,
		shots_used: int = -1,
		finish_reason: StringName = &"manual"
) -> void:
	_result.show_coverage_result(
		final_coverage,
		star_count,
		previous_best,
		elapsed_seconds,
		shots_used,
		finish_reason
	)


func show_coverage_result_snapshot(result: Dictionary, star_count: int, previous_best: float = 0.0) -> void:
	var ticks_per_second := maxi(int(result.get("ticks_per_second", Engine.physics_ticks_per_second)), 1)
	var elapsed_seconds := float(result.get("elapsed_ticks", -ticks_per_second)) / float(ticks_per_second)
	show_coverage_result(
		float(result.get("coverage", 0.0)),
		star_count,
		previous_best,
		elapsed_seconds,
		int(result.get("shots_used", -1)),
		StringName(result.get("finish_reason", &"manual"))
	)


func set_pause_overlay_suspended(suspended: bool) -> void:
	_pause_overlay_suspended = suspended
	show_state(_current_state)


func focus_pause_settings() -> void:
	_pause.focus_settings.call_deferred()


func _connect_components() -> void:
	%Start.pressed.connect(func() -> void: begin_aiming_requested.emit())
	%Back.pressed.connect(func() -> void: stage_select_requested.emit())
	_aim.power_step_requested.connect(func(direction: float) -> void: power_step_requested.emit(direction))
	_aim.angle_step_requested.connect(func(direction: float) -> void: angle_step_requested.emit(direction))
	_top.settings_requested.connect(func() -> void: pause_requested.emit())
	_actions.fire_requested.connect(func() -> void: fire_requested.emit())
	_run_status.finish_requested.connect(func() -> void: finish_requested.emit())
	_interaction.interaction_mode_requested.connect(
		func(mode: int) -> void: interaction_mode_requested.emit(mode)
	)
	_return_to_cannon.pressed.connect(func() -> void: return_to_cannon_requested.emit())
	_result.retry_requested.connect(func() -> void: restart_requested.emit())
	_result.next_requested.connect(func() -> void: next_stage_requested.emit())
	_result.stages_requested.connect(func() -> void: stage_select_requested.emit())
	_pause.resume_requested.connect(func() -> void: pause_requested.emit())
	_pause.restart_requested.connect(func() -> void: restart_requested.emit())
	_pause.settings_requested.connect(func() -> void: settings_requested.emit())
	_pause.stages_requested.connect(func() -> void: stage_select_requested.emit())
	_pause.main_menu_requested.connect(func() -> void: main_menu_requested.emit())


func _on_settings_changed(_settings: Dictionary) -> void:
	_refresh_briefing_locale()
	_aim.refresh_locale()
	_actions.refresh_locale()
	if _stage_data != null:
		_top.configure(_stage_data)
		_top.update_mode(_current_state)
		_run_status.refresh_locale()
		_run_status.update_shots(_shots_remaining)
		_aim.update_aim(_last_aim.x, _last_aim.y, _last_aim.z)
		_interaction.refresh_locale()
		_return_to_cannon.text = tr("hud.return_to_cannon")
		_return_to_cannon.tooltip_text = tr("hud.return_to_cannon_hint")
		_result.refresh_locale()
		_context_legend.refresh_locale()
		_coverage.configure(_stage_data.target_coverage)
		_coverage.update_coverage(_last_coverage)
	show_state(_current_state)


func _refresh_briefing_locale() -> void:
	%Back.text = tr("ui.back")
	%Start.text = tr("ui.start_aiming")


func _refresh_context_legend() -> void:
	if not is_instance_valid(_context_legend):
		return
	if _current_state == StageController.State.BRIEFING:
		_context_legend.visible = true
		_context_legend.set_context(ContextLegend.Mode.BRIEFING)
		return
	if _current_state != StageController.State.AIMING:
		_context_legend.visible = false
		return
	_context_legend.visible = true
	if _current_camera_mode == CameraDirector.Mode.FOLLOW:
		_context_legend.set_context(ContextLegend.Mode.FOLLOW)
	elif _current_interaction_mode == CameraDirector.InteractionMode.MAP_INSPECTION:
		_context_legend.set_context(ContextLegend.Mode.MAP)
	else:
		_context_legend.set_context(ContextLegend.Mode.AIM)


func _apply_interaction_presentation(update_focus: bool) -> void:
	var aim_locked := _current_interaction_mode == CameraDirector.InteractionMode.AIM_LOCKED
	var aiming_surface := _current_state == StageController.State.AIMING \
			and _current_camera_mode == CameraDirector.Mode.AIMING
	_aim.visible = aiming_surface and aim_locked
	_actions.visible = aiming_surface and aim_locked
	if not aiming_surface:
		return
	if not update_focus:
		return
	if aim_locked:
		_actions.focus_fire.call_deferred()
	else:
		_interaction.grab_focus.call_deferred()


func _apply_finish_availability() -> void:
	_run_status.set_finish_available(
		_run_started
		and not _clock_finished
		and _current_state == StageController.State.AIMING
	)
