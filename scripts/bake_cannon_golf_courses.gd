extends SceneTree

## Repository bake entrypoint for fast trajectory-first prepared courses.

const GENERATOR := preload("res://src/cannon_golf/trajectory_course_generator.gd")
const COURSE_LIMIT_MSEC := 60000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_directory := "res://resources/cannon_golf/prepared"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	var requested_course_id := _requested_course_id()
	var baked_count := 0
	for course in CannonGolfCourseCatalog.all_courses():
		if not requested_course_id.is_empty() and course.course_id != requested_course_id:
			continue
		var started_msec := Time.get_ticks_msec()
		print("Constructing prepared Cannon Golf course: %s" % course.course_id)
		var result: Dictionary = GENERATOR.build(course, started_msec + COURSE_LIMIT_MSEC)
		var elapsed_msec := Time.get_ticks_msec() - started_msec
		if result.is_empty() or elapsed_msec >= COURSE_LIMIT_MSEC:
			push_error("Course construction failed or exceeded 60 seconds: %s (%d ms)" % [
				course.course_id, elapsed_msec,
			])
			quit(1)
			return
		var generated := result.generated as CannonGolfGeneratedCourse
		var intended_setups: Array[Vector3] = []
		for setup in result.intended_setups:
			intended_setups.append(setup as Vector3)
		var prepared := CannonGolfCourseArtifactCodec.bake_constructed(
			course, generated, intended_setups
		)
		if prepared == null or not prepared.is_valid_for(course):
			push_error("Constructed course could not be sealed: %s" % course.course_id)
			quit(1)
			return
		print("Constructed %s in %d ms; saving." % [course.course_id, elapsed_msec])
		var path := CannonGolfCourseCatalog.prepared_path_for(course)
		print("Saving prepared Cannon Golf course: %s" % path)
		var error := ResourceSaver.save(prepared, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Could not save prepared Cannon Golf course: %s (%d)" % [path, error])
			quit(1)
			return
		print("Baked %s -> %s [%s]" % [course.course_id, path, prepared.payload_sha256])
		baked_count += 1
	if baked_count == 0:
		push_error("Unknown Cannon Golf course requested for bake: %s" % requested_course_id)
		quit(1)
		return
	quit(0)


func _requested_course_id() -> StringName:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--course="):
			return StringName(argument.trim_prefix("--course=").strip_edges())
	return &""
