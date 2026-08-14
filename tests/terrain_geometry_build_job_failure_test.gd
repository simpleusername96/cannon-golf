extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var layout := TerrainTestFixtureFactory.build_layout(TerrainTestFixtureFactory.Kind.FLAT)
	var invalid_job := TerrainGeometryFactory.begin_build(layout, 100.0)
	while not invalid_job.step(9223372036854775807) and not invalid_job.failed():
		pass
	_assert(invalid_job.failed(), "An invalid skirt must stop the job in one terminal failure state.")
	_assert(
		invalid_job.failure_message() == "Terrain boundary must retain the minimum visible skirt height.",
		"The invalid skirt must report one structured failure."
	)
	var progress_after_failure := invalid_job.progress_fraction()
	_assert(not invalid_job.step(1), "A failed geometry job must not resume later phases.")
	_assert(
		is_equal_approx(invalid_job.progress_fraction(), progress_after_failure),
		"A failed geometry job must not advance after its first failure."
	)
	_assert(invalid_job.result() == null, "A failed geometry job must not produce an artifact.")
	var valid_geometry := TerrainGeometryFactory.build(layout)
	_assert(valid_geometry != null and valid_geometry.is_valid(), "Valid geometry must still build.")
	quit(1 if _failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
