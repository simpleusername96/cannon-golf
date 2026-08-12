class_name StageLayoutRepository
extends Node

## App-owned immutable baked-layout loader. It never generates or solves.
signal layout_ready(stage_id: StringName, layout: GeneratedStageLayout)
signal layout_failed(stage_id: StringName)

const MAX_CACHED_LAYOUTS := 3

var _active_selected_request: Dictionary = {}
var _active_prefetch_request: Dictionary = {}
var _queued_selected_request: Dictionary = {}
var _queued_prefetch_request: Dictionary = {}
var _layout_cache: Dictionary = {}
var _least_recently_used: Array[StringName] = []


func _process(_delta: float) -> void:
	_poll_active_request(true)
	_poll_active_request(false)
	_start_queued_requests()


## A selection and a prefetch can load independently. ResourceLoader requests
## cannot be cancelled, so each role retains one active handle and one latest
## queued desire until the active work has been polled to completion.
func request_layout(stage: StageData, layout_path: String, selected: bool = true) -> bool:
	if stage == null:
		return false
	if ready_layout(stage) != null:
		return true
	if layout_path.is_empty():
		layout_failed.emit(stage.stage_id)
		return false
	var request := _request_for(stage, layout_path)
	if selected:
		if _request_matches(_active_selected_request, stage, layout_path):
			_queued_selected_request = {}
			return false
		if _request_matches(_queued_selected_request, stage, layout_path):
			return false
		if _request_matches(_active_prefetch_request, stage, layout_path):
			# Keep both outstanding handles, but make the requested one authoritative.
			var previous_selected := _active_selected_request
			_active_selected_request = _active_prefetch_request
			_active_prefetch_request = previous_selected
			_queued_selected_request = {}
			return false
		if _active_selected_request.is_empty():
			return _start_request(request, true)
		_queued_selected_request = request
	else:
		if _request_matches(_active_prefetch_request, stage, layout_path) \
				or _request_matches(_queued_prefetch_request, stage, layout_path) \
				or _request_matches(_active_selected_request, stage, layout_path) \
				or _request_matches(_queued_selected_request, stage, layout_path):
			return false
		if _active_prefetch_request.is_empty():
			return _start_request(request, false)
		_queued_prefetch_request = request
	return false


func ready_layout(stage: StageData) -> GeneratedStageLayout:
	if stage == null:
		return null
	var cached := _layout_cache.get(stage.stage_id) as GeneratedStageLayout
	if cached == null or not _layout_matches_stage(cached, stage):
		_layout_cache.erase(stage.stage_id)
		_least_recently_used.erase(stage.stage_id)
		return null
	_touch(stage.stage_id)
	return cached


func is_preparing(stage_id: StringName) -> bool:
	return _request_stage_id(_active_selected_request) == stage_id \
			or _request_stage_id(_active_prefetch_request) == stage_id \
			or _request_stage_id(_queued_selected_request) == stage_id \
			or _request_stage_id(_queued_prefetch_request) == stage_id


func active_request_count() -> int:
	return int(not _active_selected_request.is_empty()) + int(not _active_prefetch_request.is_empty())


func cached_layout_count() -> int:
	return _layout_cache.size()


func _poll_active_request(selected: bool) -> void:
	var request: Dictionary = _active_selected_request if selected else _active_prefetch_request
	if request.is_empty():
		return
	var path := String(request.path)
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if selected:
		_active_selected_request = {}
	else:
		_active_prefetch_request = {}
	var stage := request.stage as StageData
	var current_selection := selected and _queued_selected_request.is_empty()
	if status != ResourceLoader.THREAD_LOAD_LOADED or stage == null:
		if current_selection and stage != null:
			layout_failed.emit(stage.stage_id)
		return
	var baked := ResourceLoader.load_threaded_get(path) as BakedStageLayoutData
	var layout := StageLayoutBakeCodec.hydrate(baked, stage)
	if not _layout_matches_stage(layout, stage):
		if current_selection:
			layout_failed.emit(stage.stage_id)
		return
	_cache_layout(stage.stage_id, layout)
	# Readiness is identity-scoped, so an obsolete selection cannot enter another
	# stage. Prefetch readiness is still published because AppRoot uses it to
	# install the Stage 01 menu preview.
	layout_ready.emit(stage.stage_id, layout)


func _start_queued_requests() -> void:
	if _active_selected_request.is_empty() and not _queued_selected_request.is_empty():
		var selected_request := _queued_selected_request
		_queued_selected_request = {}
		if _request_matches(_active_prefetch_request, selected_request.stage as StageData, String(selected_request.path)):
			_active_selected_request = _active_prefetch_request
			_active_prefetch_request = {}
		else:
			_start_request(selected_request, true)
	if _active_prefetch_request.is_empty() and not _queued_prefetch_request.is_empty():
		var prefetch_request := _queued_prefetch_request
		_queued_prefetch_request = {}
		_start_request(prefetch_request, false)


func _start_request(request: Dictionary, selected: bool) -> bool:
	var stage := request.stage as StageData
	var error := ResourceLoader.load_threaded_request(
		String(request.path), "", false, ResourceLoader.CACHE_MODE_REUSE
	)
	if error != OK:
		if selected and stage != null:
			layout_failed.emit(stage.stage_id)
		return false
	if selected:
		_active_selected_request = request
	else:
		_active_prefetch_request = request
	return false


func _request_for(stage: StageData, layout_path: String) -> Dictionary:
	return {"stage": stage, "path": layout_path}


func _request_matches(request: Dictionary, stage: StageData, layout_path: String) -> bool:
	return not request.is_empty() and request.get("path", "") == layout_path \
			and _same_stage_identity(request.get("stage") as StageData, stage)


func _request_stage_id(request: Dictionary) -> StringName:
	var stage := request.get("stage") as StageData
	return stage.stage_id if stage != null else &""


func _cache_layout(stage_id: StringName, layout: GeneratedStageLayout) -> void:
	_layout_cache[stage_id] = layout
	_touch(stage_id)
	while _least_recently_used.size() > MAX_CACHED_LAYOUTS:
		_layout_cache.erase(StringName(_least_recently_used.pop_front()))


func _touch(stage_id: StringName) -> void:
	_least_recently_used.erase(stage_id)
	_least_recently_used.append(stage_id)


func _same_stage_identity(left: StageData, right: StageData) -> bool:
	if left == null or right == null or left.generation_profile == null \
			or right.generation_profile == null:
		return false
	return left.stage_id == right.stage_id \
			and left.stage_version == right.stage_version \
			and left.terrain_seed == right.terrain_seed \
			and left.generation_profile.profile_id == right.generation_profile.profile_id \
			and left.generation_profile.profile_version == right.generation_profile.profile_version


func _layout_matches_stage(layout: GeneratedStageLayout, stage: StageData) -> bool:
	return layout != null and layout.matches_stage_identity(stage) and layout.is_runtime_ready() \
			and layout.terrain_seed == StageProgressionData.CANONICAL_TERRAIN_SEED \
			and stage.terrain_seed == StageProgressionData.CANONICAL_TERRAIN_SEED
