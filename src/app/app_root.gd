class_name AppRoot
extends Node

const GAMEPLAY_SCENE := preload("res://scenes/gameplay/gameplay.tscn")
const ENVIRONMENT_DRESSING_SCRIPT := preload("res://src/terrain/environment_dressing.gd")
const MAIN_MENU_SCENE := preload("res://scenes/ui/screens/main_menu.tscn")
const STAGE_SELECT_SCENE := preload("res://scenes/ui/screens/stage_select.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/screens/settings.tscn")
const STAGE_LAYOUT_REPOSITORY_SCRIPT := preload("res://src/app/stage_layout_repository.gd")
const STAGE_RUNTIME_PREPARER_SCRIPT := preload("res://src/app/stage_runtime_preparer.gd")
const GAMEPLAY_PACE := preload("res://src/gameplay/gameplay_pace.gd")
const PREVIEW_SAFE_RECT := Rect2(0.30, 0.08, 0.68, 0.86)
const PREVIEW_FRAME_MARGIN := 1.02

var _preview_world: Node3D
var _preview_environment: WorldEnvironment
var _preview_environment_resource: Environment
var _preview_mountain: MeshInstance3D
var _preview_camera: Camera3D
var _main_menu: MainMenuScreen
var _stage_select: StageSelectScreen
var _settings: SettingsScreen
var _gameplay: Node3D
var _gameplay_presented := false
var _layout_repository: StageLayoutRepository
var _runtime_preparer: StageRuntimePreparer
var _settings_return: StringName = &"main_menu"
var _preview_dressing: Node3D
var _preview_material: ShaderMaterial
var _active_preview_stage_id: StringName = &""
var _requested_user_stage_id: StringName = &""
var _pending_start_stage_id: StringName = &""


func _ready() -> void:
	_layout_repository = STAGE_LAYOUT_REPOSITORY_SCRIPT.new()
	_layout_repository.name = "StageLayoutRepository"
	add_child(_layout_repository)
	_layout_repository.layout_ready.connect(_on_layout_ready)
	_layout_repository.layout_failed.connect(_on_layout_failed)
	_runtime_preparer = STAGE_RUNTIME_PREPARER_SCRIPT.new()
	_runtime_preparer.name = "StageRuntimePreparer"
	add_child(_runtime_preparer)
	_runtime_preparer.artifact_ready.connect(_on_artifact_ready)
	_runtime_preparer.artifact_failed.connect(_on_artifact_failed)
	_build_preview_world()
	get_viewport().size_changed.connect(_on_preview_viewport_size_changed)
	_main_menu = MAIN_MENU_SCENE.instantiate()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)
	_stage_select = STAGE_SELECT_SCENE.instantiate()
	_stage_select.name = "StageSelect"
	add_child(_stage_select)
	_settings = SETTINGS_SCENE.instantiate()
	_settings.name = "Settings"
	add_child(_settings)
	_connect_screens()
	_show_main_menu()
	RuntimeDeliveryTelemetry.emit_marker(&"app_root_ready", {
		"selected_stage_id": String(
			(get_node("/root/GameState") as GameState).selected_stage_id
		),
	})


func _connect_screens() -> void:
	_main_menu.play_requested.connect(_start_selected_stage)
	_main_menu.stage_select_requested.connect(_show_stage_select)
	_main_menu.settings_requested.connect(func() -> void: _show_settings(&"main_menu"))
	_main_menu.quit_requested.connect(func() -> void: get_tree().quit())
	_stage_select.back_requested.connect(_show_main_menu)
	_stage_select.start_requested.connect(_start_stage)
	_stage_select.selection_changed.connect(_on_stage_selection_changed)
	_settings.close_requested.connect(_on_settings_closed)


func _show_main_menu() -> void:
	_audio_ui()
	_pending_start_stage_id = &""
	if _gameplay_presented:
		_remove_gameplay()
	_set_preview_world_active(true)
	_main_menu.visible = true
	_stage_select.visible = false
	_main_menu.begin_passive_focus_session()
	var game_state := get_node("/root/GameState")
	_request_user_stage(StageCatalog.get_stage(game_state.selected_stage_id))
	_request_menu_preview()


func _show_stage_select() -> void:
	_audio_ui()
	_pending_start_stage_id = &""
	if _gameplay_presented:
		_remove_gameplay()
	_set_preview_world_active(false)
	_main_menu.visible = false
	_stage_select.visible = true
	_stage_select.refresh()
	_request_user_stage(StageCatalog.get_stage(_stage_select.selected_stage_id()))
	_stage_select.focus_primary.call_deferred()


func _start_selected_stage() -> void:
	var game_state := get_node("/root/GameState")
	_start_stage(game_state.selected_stage_id)


func _start_stage(stage_id: StringName) -> void:
	var game_state := get_node("/root/GameState")
	if not game_state.select_stage(stage_id):
		_set_catalog_load_failed()
		return
	var selected_stage := StageCatalog.get_stage(stage_id)
	if selected_stage == null:
		_set_catalog_load_failed()
		return
	_requested_user_stage_id = selected_stage.stage_id
	if _prepared_gameplay_matches(selected_stage):
		_enter_stage(selected_stage)
		return
	_pending_start_stage_id = selected_stage.stage_id
	_request_user_stage(selected_stage)


func _enter_stage(selected_stage: StageData) -> void:
	if selected_stage == null or not _prepared_gameplay_matches(selected_stage):
		if selected_stage != null:
			_set_stage_preparation_state(selected_stage, false)
		return
	_runtime_preparer.cancel_except(selected_stage.stage_id)
	_pending_start_stage_id = &""
	_audio_ui()
	_set_preview_world_active(false)
	_main_menu.visible = false
	_stage_select.visible = false
	_gameplay.name = "ActiveGameplay"
	_gameplay.call(&"set_stage_presented", true)
	_gameplay_presented = true
	RuntimeDeliveryTelemetry.emit_marker(&"gameplay_visible", {
		"stage_id": String(selected_stage.stage_id),
		"artifact_cache_entries": _runtime_preparer.cached_artifact_count(),
	})


func _on_stage_selection_changed(stage: StageData) -> void:
	if stage == null:
		return
	if not _pending_start_stage_id.is_empty() and _pending_start_stage_id != stage.stage_id:
		_pending_start_stage_id = &""
	_request_user_stage(stage)


func _request_user_stage(stage: StageData) -> void:
	if stage == null:
		_set_catalog_load_failed()
		return
	# Stage Select does not commit GameState until Start. Keep the newest
	# asynchronous preparation desire separate from that persisted selection.
	_requested_user_stage_id = stage.stage_id
	if not _gameplay_presented and _gameplay != null and is_instance_valid(_gameplay):
		var preparing_stage := _gameplay.get("stage_data") as StageData
		if preparing_stage == null or preparing_stage.stage_id != stage.stage_id:
			_remove_gameplay()
	if _prepared_gameplay_matches(stage):
		_set_stage_preparation_state(stage, true)
		return
	_set_stage_preparation_state(stage, false)
	_runtime_preparer.cancel_except(stage.stage_id)
	var artifact := _runtime_preparer.ready_artifact(stage)
	if artifact != null:
		_prepare_hidden_gameplay(stage, artifact)
		return
	var layout := _layout_repository.ready_layout(stage)
	if layout != null:
		_runtime_preparer.request_artifact(stage, layout, true)
	else:
		_layout_repository.request_layout(
			stage,
			StageCatalog.get_layout_path(stage.stage_id),
			true
		)


func _prepared_gameplay_matches(stage: StageData) -> bool:
	if stage == null or _gameplay == null or not is_instance_valid(_gameplay) \
			or _gameplay.is_queued_for_deletion() \
			or not _gameplay.has_method(&"is_stage_prepared") \
			or not bool(_gameplay.call(&"is_stage_prepared")):
		return false
	var prepared_stage := _gameplay.get("stage_data") as StageData
	var artifact := _gameplay.call(&"prepared_artifact_read_only") as StageRuntimeArtifact
	return prepared_stage != null and prepared_stage.stage_id == stage.stage_id \
			and artifact != null and artifact.matches_stage(stage)


func _prepare_hidden_gameplay(stage: StageData, artifact: StageRuntimeArtifact) -> void:
	if stage == null or artifact == null or not artifact.matches_stage(stage):
		_on_artifact_failed(stage.stage_id if stage != null else &"")
		return
	_runtime_preparer.cancel_except(stage.stage_id)
	if _prepared_gameplay_matches(stage):
		_set_stage_preparation_state(stage, true)
		if _pending_start_stage_id == stage.stage_id:
			_enter_stage(stage)
		return
	_remove_gameplay()
	_gameplay = GAMEPLAY_SCENE.instantiate()
	_gameplay.name = "PreparedGameplay"
	if not bool(_gameplay.call(&"prepare_stage", stage, artifact)):
		_gameplay.queue_free()
		_gameplay = null
		_on_artifact_failed(stage.stage_id)
		return
	_gameplay.call(&"set_stage_presented", false)
	_gameplay.connect(&"navigation_requested", _on_gameplay_navigation)
	_gameplay.connect(&"stage_prepared", _on_gameplay_prepared)
	_gameplay.connect(&"stage_preparation_failed", _on_gameplay_preparation_failed)
	add_child(_gameplay)
	_gameplay_presented = false


func _on_gameplay_prepared(stage_id: StringName) -> void:
	if _requested_user_stage_id != stage_id:
		return
	var stage := StageCatalog.get_stage(stage_id)
	if stage == null or not _prepared_gameplay_matches(stage):
		_remove_gameplay()
		_on_artifact_failed(stage_id)
		return
	_gameplay.call(&"set_stage_presented", false)
	RuntimeDeliveryTelemetry.emit_marker(&"gameplay_prepared", {
		"stage_id": String(stage_id),
		"artifact_cache_entries": _runtime_preparer.cached_artifact_count(),
	})
	_set_stage_preparation_state(stage, true)
	if _pending_start_stage_id == stage_id:
		_enter_stage(stage)


func _on_gameplay_preparation_failed(stage_id: StringName) -> void:
	if _requested_user_stage_id != stage_id:
		return
	_remove_gameplay()
	_on_artifact_failed(stage_id)


## A missing catalog has no stage identity for the repository to report, but it
## must still leave the player with the same explicit retry state as a failed
## selected layout. Retry only re-reads the catalog/artifact; it never generates.
func _set_catalog_load_failed() -> void:
	_requested_user_stage_id = &""
	if _main_menu != null:
		_main_menu.set_play_preparation_state(false, true)
	if _stage_select != null:
		_stage_select.set_catalog_load_failed()


func _set_stage_preparation_state(
		stage: StageData,
		ready: bool,
		failed: bool = false
) -> void:
	if stage == null:
		return
	var game_state := get_node_or_null("/root/GameState")
	if _main_menu != null and game_state != null \
			and game_state.selected_stage_id == stage.stage_id:
		_main_menu.set_play_preparation_state(ready, failed)
	if _stage_select != null:
		_stage_select.set_stage_preparation_state(stage.stage_id, ready, failed)


func _on_layout_ready(stage_id: StringName, layout: GeneratedStageLayout) -> void:
	var stage := StageCatalog.get_stage(stage_id)
	if stage == null or not _layout_matches_stage(layout, stage):
		_on_layout_failed(stage_id)
		return
	var selected := _requested_user_stage_id == stage_id
	RuntimeDeliveryTelemetry.emit_marker(&"layout_ready", {
		"stage_id": String(stage_id),
		"layout_checksum": layout.checksum,
	})
	if not selected and (_gameplay_presented \
			or (_gameplay != null and is_instance_valid(_gameplay))):
		return
	_runtime_preparer.request_artifact(stage, layout, selected)


func _on_layout_failed(stage_id: StringName) -> void:
	if _requested_user_stage_id != stage_id:
		return
	var stage := StageCatalog.get_stage(stage_id)
	if stage != null:
		_set_stage_preparation_state(stage, false, true)
	if _pending_start_stage_id == stage_id:
		_pending_start_stage_id = &""
	_requested_user_stage_id = &""


func _on_artifact_ready(stage_id: StringName, artifact: StageRuntimeArtifact) -> void:
	var stage := StageCatalog.get_stage(stage_id)
	if stage == null or artifact == null or not artifact.matches_stage(stage):
		_on_artifact_failed(stage_id)
		return
	var game_state := get_node_or_null("/root/GameState")
	RuntimeDeliveryTelemetry.emit_marker(&"artifact_ready", {
		"stage_id": String(stage_id),
		"layout_checksum": artifact.layout_checksum,
		"artifact_cache_entries": _runtime_preparer.cached_artifact_count(),
	})
	if game_state != null and game_state.selected_stage_id == stage_id \
			and _preview_world.visible:
		_set_menu_preview_if_visible.call_deferred(stage)
	if _requested_user_stage_id == stage_id:
		_prepare_hidden_gameplay(stage, artifact)


func _on_artifact_failed(stage_id: StringName) -> void:
	if _requested_user_stage_id != stage_id:
		return
	var stage := StageCatalog.get_stage(stage_id)
	if stage != null:
		_set_stage_preparation_state(stage, false, true)
	if _pending_start_stage_id == stage_id:
		_pending_start_stage_id = &""
	_requested_user_stage_id = &""


func _request_menu_preview() -> void:
	var game_state := get_node_or_null("/root/GameState") as GameState
	var preview_stage := StageCatalog.get_stage(game_state.selected_stage_id) \
			if game_state != null else null
	if preview_stage == null:
		return
	if _runtime_preparer.ready_artifact(preview_stage) != null:
		_set_menu_preview_if_visible.call_deferred(preview_stage)
		return
	var layout := _layout_repository.ready_layout(preview_stage)
	if layout != null:
		_runtime_preparer.request_artifact(preview_stage, layout, false)
	else:
		_layout_repository.request_layout(
			preview_stage,
			StageCatalog.get_layout_path(preview_stage.stage_id),
			false
		)


func _set_menu_preview_if_visible(stage: StageData) -> void:
	if _preview_world.visible and _main_menu.visible:
		_set_preview_stage(stage)


func _on_gameplay_navigation(destination: StringName) -> void:
	match destination:
		&"main_menu":
			_show_main_menu()
		&"stage_select":
			_show_stage_select()
		&"next_stage":
			var game_state := get_node("/root/GameState")
			var next_id := StageCatalog.next_stage_id(game_state.selected_stage_id)
			if next_id.is_empty() or not game_state.unlocked_stages.has(next_id):
				_show_stage_select()
			else:
				_start_stage(next_id)
		&"settings":
			_show_settings(&"gameplay")


func _remove_gameplay() -> void:
	GAMEPLAY_PACE.apply_normal()
	get_tree().paused = false
	if _gameplay != null and is_instance_valid(_gameplay):
		if _gameplay.get_parent() == self:
			remove_child(_gameplay)
		_gameplay.queue_free()
		_gameplay = null
	_gameplay_presented = false


func _show_settings(return_to: StringName) -> void:
	_audio_ui()
	_pending_start_stage_id = &""
	_settings_return = return_to
	if return_to == &"main_menu":
		_main_menu.visible = false
	elif return_to == &"stage_select":
		_stage_select.visible = false
	elif return_to == &"gameplay":
		if _gameplay != null and _gameplay.has_method(&"set_pause_overlay_suspended"):
			_gameplay.call(&"set_pause_overlay_suspended", true)
	_settings.open()


func _on_settings_closed() -> void:
	match _settings_return:
		&"stage_select":
			_stage_select.visible = true
			_stage_select.focus_primary.call_deferred()
		&"gameplay":
			if _gameplay != null and _gameplay.has_method(&"set_pause_overlay_suspended"):
				_gameplay.call(&"set_pause_overlay_suspended", false)
				if _gameplay.has_method(&"focus_pause_settings"):
					_gameplay.call_deferred(&"focus_pause_settings")
		_:
			_main_menu.visible = true
			_main_menu.begin_passive_focus_session()


func _build_preview_world() -> void:
	_preview_world = Node3D.new()
	_preview_world.name = "PreviewWorld"
	add_child(_preview_world)
	_preview_environment = WorldEnvironment.new()
	_preview_environment_resource = Environment.new()
	_preview_environment_resource.background_mode = Environment.BG_COLOR
	_preview_environment_resource.background_color = Color("FFFDFC")
	_preview_environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_preview_environment_resource.ambient_light_color = Color("E9EDF2")
	_preview_environment_resource.ambient_light_energy = 0.34
	_preview_environment.environment = _preview_environment_resource
	_preview_world.add_child(_preview_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86, 1.0)
	sun.light_energy = 1.08
	sun.shadow_enabled = true
	_preview_world.add_child(sun)
	_preview_camera = Camera3D.new()
	_preview_camera.position = Vector3(94.0, 58.0, 20.0)
	_preview_camera.fov = 48.0
	_preview_camera.current = true
	_preview_world.add_child(_preview_camera)
	_preview_camera.look_at(Vector3(0.0, 24.0, -112.0), Vector3.UP)
	_preview_mountain = MeshInstance3D.new()
	_preview_mountain.name = "PreviewMountain"
	_preview_mountain.position = Vector3(0.0, -2.0, -112.0)
	_preview_mountain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_preview_world.add_child(_preview_mountain)


func _set_preview_world_active(active: bool) -> void:
	_preview_world.visible = active
	# Node3D visibility does not deactivate a WorldEnvironment. Release the
	# preview resource so the gameplay panorama owns the viewport in a stage.
	_preview_environment.environment = _preview_environment_resource if active else null


func _set_preview_stage(stage: StageData) -> void:
	if stage == null or _preview_mountain == null:
		return
	var artifact := _runtime_preparer.ready_artifact(stage)
	if artifact == null:
		return
	if _active_preview_stage_id == stage.stage_id \
			and _preview_mountain.mesh == artifact.geometry.render_mesh:
		return
	_clear_preview_presentation()
	_preview_mountain.position = stage.terrain_center
	_preview_mountain.mesh = artifact.geometry.render_mesh
	_preview_material = ShaderMaterial.new()
	_preview_material.shader = load("res://src/paint/terrain_paint.gdshader")
	_preview_material.set_shader_parameter(&"paint_mask", artifact.preview_paint_texture)
	_preview_material.set_shader_parameter(
		&"target_mask", artifact.paint_bootstrap.target_texture
	)
	_preview_material.set_shader_parameter(&"paint_color", stage.paint_color)
	_preview_material.set_shader_parameter(&"rock_color", Color("9FA3A9"))
	_preview_material.set_shader_parameter(&"shadow_tint", Color("626D7B"))
	_preview_mountain.material_override = _preview_material
	_preview_dressing = ENVIRONMENT_DRESSING_SCRIPT.new()
	_preview_dressing.name = "PreviewDressing_%s" % stage.stage_id
	_preview_world.add_child(_preview_dressing)
	_preview_dressing.configure(
		stage,
		artifact.runtime_layout,
		artifact.decoration_placements,
		artifact.decoration_scenes
	)
	_active_preview_stage_id = stage.stage_id
	_fit_preview_camera(artifact.presentation_local_points)


func _fit_preview_camera(local_points: PackedVector3Array) -> void:
	if _preview_camera == null or _preview_mountain == null or _preview_mountain.mesh == null:
		return
	var world_bounds := _preview_mountain.global_transform * _preview_mountain.mesh.get_aabb()
	if not world_bounds.has_volume() or local_points.is_empty():
		return
	var points := PackedVector3Array()
	for local_point in local_points:
		points.append(_preview_mountain.to_global(local_point))
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / viewport_size.y if viewport_size.y > 0.0 else 16.0 / 9.0
	var authored_position := Vector3(94.0, 58.0, 20.0)
	var authored_focus := Vector3(0.0, 24.0, -112.0)
	var framed := TerrainCameraFramer.framed_pose_in_normalized_rect(
		points,
		world_bounds.get_center(),
		authored_position,
		authored_focus,
		_preview_camera.fov,
		aspect_ratio,
		PREVIEW_SAFE_RECT,
		PREVIEW_FRAME_MARGIN
	)
	if framed.is_empty():
		return
	_preview_camera.global_position = framed[0]
	_preview_camera.look_at(framed[1], Vector3.UP)


func _on_preview_viewport_size_changed() -> void:
	if _preview_world == null or not _preview_world.visible or _active_preview_stage_id.is_empty():
		return
	var stage := StageCatalog.get_stage(_active_preview_stage_id)
	var artifact := _runtime_preparer.ready_artifact(stage)
	if artifact != null:
		_fit_preview_camera(artifact.presentation_local_points)


func _clear_preview_presentation() -> void:
	if _preview_dressing != null and is_instance_valid(_preview_dressing):
		_preview_dressing.visible = false
		_preview_dressing.queue_free()
	_preview_dressing = null
	_preview_material = null
	_active_preview_stage_id = &""


func _layout_matches_stage(layout: GeneratedStageLayout, stage: StageData) -> bool:
	return layout != null and layout.matches_stage_identity(stage) and layout.is_runtime_ready()


func _audio_ui() -> void:
	var audio_director := get_node_or_null("/root/AudioDirector")
	if audio_director != null:
		audio_director.play_cue(&"ui")
