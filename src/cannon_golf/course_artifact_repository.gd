class_name CannonGolfCourseArtifactRepository
extends Node

## App-owned asynchronous prepared-course loader. It never generates terrain.

signal course_ready(course_id: StringName, prepared: CannonGolfPreparedCourse)
signal course_failed(course_id: StringName)

const MAX_CACHED_COURSES := 3

var _active_request: Dictionary = {}
var _queued_request: Dictionary = {}
var _cache: Dictionary = {}
var _least_recently_used: Array[StringName] = []
var _desired_course_id: StringName


func _process(_delta: float) -> void:
	_poll_active_request()
	_start_queued_request()


func request_course(course: CannonGolfCourseData) -> bool:
	if course == null:
		return false
	_desired_course_id = course.course_id
	if ready_course(course) != null:
		_queued_request = {}
		return true
	var path := CannonGolfCourseCatalog.prepared_path_for(course)
	if path.is_empty():
		course_failed.emit(course.course_id)
		return false
	var request := {"course": course, "path": path}
	if _request_matches(_active_request, course, path):
		_queued_request = {}
		return false
	if _request_matches(_queued_request, course, path):
		return false
	if _active_request.is_empty():
		_start_request(request)
	else:
		_queued_request = request
	return false


func ready_course(course: CannonGolfCourseData) -> CannonGolfPreparedCourse:
	if course == null:
		return null
	var prepared := _cache.get(course.course_id) as CannonGolfPreparedCourse
	if prepared == null or not prepared.is_valid_for(course):
		_cache.erase(course.course_id)
		_least_recently_used.erase(course.course_id)
		return null
	_touch(course.course_id)
	return prepared


func is_preparing(course_id: StringName) -> bool:
	return _request_course_id(_active_request) == course_id \
			or _request_course_id(_queued_request) == course_id


func cached_course_count() -> int:
	return _cache.size()


func active_request_count() -> int:
	return 0 if _active_request.is_empty() else 1


func _poll_active_request() -> void:
	if _active_request.is_empty():
		return
	var path := String(_active_request.path)
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var request := _active_request
	_active_request = {}
	var course := request.course as CannonGolfCourseData
	var is_latest := course != null and course.course_id == _desired_course_id
	if status != ResourceLoader.THREAD_LOAD_LOADED or course == null:
		if is_latest and course != null:
			course_failed.emit(course.course_id)
		return
	var prepared := ResourceLoader.load_threaded_get(path) as CannonGolfPreparedCourse
	if prepared == null or not prepared.is_valid_for(course):
		if is_latest:
			course_failed.emit(course.course_id)
		return
	_cache_course(course.course_id, prepared)
	if is_latest:
		course_ready.emit(course.course_id, prepared)


func _start_queued_request() -> void:
	if not _active_request.is_empty() or _queued_request.is_empty():
		return
	var request := _queued_request
	_queued_request = {}
	var course := request.course as CannonGolfCourseData
	if course != null:
		var cached := ready_course(course)
		if cached != null:
			course_ready.emit(course.course_id, cached)
			return
	_start_request(request)


func _start_request(request: Dictionary) -> void:
	var course := request.get("course") as CannonGolfCourseData
	var error := ResourceLoader.load_threaded_request(
		String(request.get("path", "")), "", false, ResourceLoader.CACHE_MODE_REUSE
	)
	if error != OK:
		if course != null:
			course_failed.emit(course.course_id)
		return
	_active_request = request


func _request_matches(
		request: Dictionary, course: CannonGolfCourseData, path: String
) -> bool:
	if request.is_empty() or request.get("path", "") != path:
		return false
	var requested := request.get("course") as CannonGolfCourseData
	return requested != null and requested.course_id == course.course_id \
			and CannonGolfCourseIdentity.signature(requested) \
					== CannonGolfCourseIdentity.signature(course)


func _request_course_id(request: Dictionary) -> StringName:
	var course := request.get("course") as CannonGolfCourseData
	return course.course_id if course != null else &""


func _cache_course(course_id: StringName, prepared: CannonGolfPreparedCourse) -> void:
	_cache[course_id] = prepared
	_touch(course_id)
	while _least_recently_used.size() > MAX_CACHED_COURSES:
		_cache.erase(StringName(_least_recently_used.pop_front()))


func _touch(course_id: StringName) -> void:
	_least_recently_used.erase(course_id)
	_least_recently_used.append(course_id)
