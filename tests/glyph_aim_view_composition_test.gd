extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load("res://resources/stages/catalog.tres") as StageCatalogData
	_assert_true(catalog != null, "glyph composition fixture requires the active stage catalog")
	if catalog == null:
		quit(1)
		return
	for stage_id in [&"stage_02", &"stage_03", &"stage_08", &"stage_30"]:
		_assert_stage_glyphs_use_middle_view_band(catalog, stage_id)
	if not _failed:
		print("Glyph Aim View composition passed: representative placements stay inside the middle screen band.")
	quit(1 if _failed else 0)


func _assert_stage_glyphs_use_middle_view_band(
		catalog: StageCatalogData,
		stage_id: StringName
) -> void:
	var stage := catalog.get_stage(stage_id)
	var baked := load(catalog.get_layout_path(stage_id)) as BakedStageLayoutData
	var layout := StageLayoutBakeCodec.hydrate(baked, stage)
	_assert_true(stage != null and layout != null, "%s baked fixture must hydrate" % stage_id)
	if stage == null or layout == null:
		return
	var aim_view := MechanismLoadoutPlanner._build_aim_view_context(stage, layout)
	_assert_true(not aim_view.is_empty(), "%s must expose its canonical Aim View projection" % stage_id)
	if aim_view.is_empty():
		return
	var planned := MechanismLoadoutPlanner.plan(stage, layout)
	_assert_true(
		planned.size() == layout.mechanism_placements.size(),
		"%s active baked placements must match the current planner count" % stage_id
	)
	if planned.size() == layout.mechanism_placements.size():
		for placement_index in range(planned.size()):
			_assert_true(
				planned[placement_index].anchor_id \
						== layout.mechanism_placements[placement_index].anchor_id,
				"%s active baked placement %d must match the current planner" % [
					stage_id, placement_index,
				]
			)
	for placement in layout.mechanism_placements:
		var world_point := stage.terrain_center + placement.local_transform.origin
		var view_fraction := MechanismLoadoutPlanner._aim_view_vertical_fraction(
			world_point, aim_view
		)
		print("%s %s Aim View fraction=%.3f" % [
			stage_id,
			MechanismData.Kind.keys()[int(placement.mechanism_data.canonical_kind())],
			view_fraction,
		])
		_assert_true(
			view_fraction >= MechanismLoadoutPlanner.FALLBACK_VIEW_BAND_MINIMUM \
					and view_fraction <= MechanismLoadoutPlanner.FALLBACK_VIEW_BAND_MAXIMUM,
			"%s %s must stay off the skyline and foot (fraction %.3f)" % [
				stage_id,
				MechanismData.Kind.keys()[int(placement.mechanism_data.canonical_kind())],
				view_fraction,
			]
		)
		var horizontal_extent := MechanismLoadoutPlanner._glyph_horizontal_extent_ndc(
			stage, layout, placement, aim_view
		)
		_assert_true(
			horizontal_extent <= MechanismLoadoutPlanner.AIM_VIEW_HORIZONTAL_SAFE_NDC,
			"%s %s must stay inside the Aim View horizontal safe frame (extent %.3f)" % [
				stage_id,
				MechanismData.Kind.keys()[int(placement.mechanism_data.canonical_kind())],
				horizontal_extent,
			]
		)
		var surface_sample := layout.surface_sample_at_local(
			placement.local_xz.x, placement.local_xz.y, false
		)
		_assert_true(
			not surface_sample.is_empty(),
			"%s baked glyph anchor must retain a playable surface sample" % stage_id
		)
		if surface_sample.is_empty():
			continue
		var facing_dot := Vector3(surface_sample.normal).dot(
			(Vector3(aim_view.camera_position) - world_point).normalized()
		)
		_assert_true(
			facing_dot >= MechanismLoadoutPlanner.MINIMUM_AIM_VIEW_FACING_DOT,
			"%s %s must face the Aim View enough to read as a complete glyph (dot %.3f)" % [
				stage_id,
				MechanismData.Kind.keys()[int(placement.mechanism_data.canonical_kind())],
				facing_dot,
			]
		)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Glyph Aim View composition failed: %s" % message)
