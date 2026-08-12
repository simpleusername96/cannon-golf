extends RefCounted

## Owns deterministic stage/profile/loadout transformation for offline catalog builds.

const BURST_DATA: MechanismData = preload("res://resources/mechanisms/burst_node.tres")
const SPLITTER_DATA: MechanismData = preload("res://resources/mechanisms/splitter_node.tres")
const UPHILL_REBOUND_DATA: MechanismData = preload(
	"res://resources/mechanisms/uphill_rebound_node.tres"
)

static func materialize_stage(source: StageData, stage_number: int) -> StageData:
	if source == null:
		return null
	var stage := source.duplicate(true) as StageData
	var stage_id := StringName("stage_%02d" % stage_number)
	stage.stage_id = stage_id
	stage.stage_version = StageGenerationContract.CONTRACT_VERSION
	stage.stage_number = stage_number
	stage.target_coverage = StageProgressionData.target_for(stage_number)
	stage.maximum_shots = StageProgressionData.shots_for(stage_number)
	stage.star_thresholds = Vector3(
		stage.target_coverage,
		stage.target_coverage + 2.5,
		stage.target_coverage + 5.0
	)
	stage.terrain_seed = StageProgressionData.terrain_seed_for(stage_number)
	stage.terrain_size = StageProgressionData.terrain_size_for(stage_number)
	# One shared world anchor keeps the independent mountain distant while its
	# depth expands in both directions instead of growing toward the cannon.
	stage.terrain_center = Vector3(0.0, -2.0, -130.0)
	stage.mechanism_loadout = _materialize_mechanisms(source.mechanism_loadout, stage_number)
	if stage.mechanism_loadout.size() != StageProgressionData.mechanism_count_for(stage_number):
		return null
	stage.generation_profile = _materialize_profile(
		stage.generation_profile,
		stage_number,
		stage_id,
		stage.terrain_seed
	)
	if stage.generation_profile == null \
			or not _materialize_route_mechanism_slots(
				stage.generation_profile, stage.mechanism_loadout, stage_number
			) \
			or not stage.generation_profile.is_valid():
		return null
	return stage


static func _materialize_profile(
	source: StageGenerationProfile,
	stage_number: int,
	stage_id: StringName,
	terrain_seed: int
) -> StageGenerationProfile:
	if source == null:
		return null
	var profile := source.duplicate(true) as StageGenerationProfile
	profile.profile_id = StageGenerationProfile.profile_id_for_stage(stage_id)
	profile.profile_version = StageGenerationContract.CONTRACT_VERSION
	profile.base_seed = terrain_seed
	profile.nominal_peak = StageProgressionData.nominal_peak_for(stage_number)
	profile.accepted_height_range = Vector2(
		profile.nominal_peak - (12.0 if stage_number == 3 else 4.0),
		profile.nominal_peak + 10.0
	)
	profile.ridge_count = StageProgressionData.ridge_count_for(stage_number)
	profile.basin_count = StageProgressionData.basin_count_for(stage_number)
	profile.pass_count = StageProgressionData.pass_count_for(stage_number)
	profile.undulation_amplitude = StageProgressionData.undulation_for(stage_number)
	profile.route_width = StageProgressionData.route_width_for(stage_number)
	profile.generation_contract = _materialize_contract(
		profile.generation_contract, stage_number
	)
	if profile.generation_contract == null:
		return null
	if stage_number <= 3:
		profile.target_ratio_range = Vector2(0.18, 0.72)
		profile.target_mean_slope_range = Vector2(12.0, 45.0)
		profile.target_p95_slope_max = 60.0
		profile.target_maximum_slope = 68.0
		profile.route_core_p95_slope_max = 60.0
		profile.corridor_lip_maximum_slope = 50.0
		profile.routes = _intro_routes(stage_number, profile.route_width)
	return profile


static func _materialize_contract(
		source: StageGenerationContract,
		stage_number: int
) -> StageGenerationContract:
	if source == null:
		return null
	var contract := source.duplicate(true) as StageGenerationContract
	contract.generation_version = StageGenerationContract.CONTRACT_VERSION
	contract.profile_version = StageGenerationContract.CONTRACT_VERSION
	contract.layout_version = StageGenerationContract.CONTRACT_VERSION
	var terrain_size := StageProgressionData.terrain_size_for(stage_number)
	contract.cell_count = StageProgressionData.cell_count_for(stage_number)
	contract.local_bounds = Rect2(-terrain_size * 0.5, terrain_size)
	contract.maximum_top_triangle_count = contract.cell_count.x * contract.cell_count.y * 2
	var station_count := StageProgressionData.station_count_for(stage_number)
	var stations := PackedFloat32Array()
	var route_start_z := contract.local_bounds.position.y + contract.outer_band_width + 4.0
	var route_end_z := contract.local_bounds.end.y - contract.outer_band_width - 4.0
	for index in range(station_count):
		stations.append(lerpf(route_start_z, route_end_z, float(index) / float(station_count - 1)))
	contract.route_station_z = stations
	return contract


static func _intro_routes(stage_number: int, width: float) -> Array[StageRouteProfile]:
	var routes: Array[StageRouteProfile] = []
	if stage_number <= 2:
		routes.append(_intro_route(
			stage_number,
			width,
			StageRouteProfile.Role.PRIMARY,
			0.0
		))
		return routes
	# Splitter's three children need three distinct, authoritative route roles.
	# Stage 03 teaches that fan-out explicitly; later stages keep their reviewed
	# catalog profiles rather than inheriting this tutorial topology.
	routes.append(_intro_route(
		stage_number,
		width,
		StageRouteProfile.Role.SAFE,
		-48.0
	))
	routes.append(_intro_route(
		stage_number,
		width,
		StageRouteProfile.Role.SPLITTER,
		0.0,
		MechanismData.Kind.SPLITTER,
		0.42,
		10.0
	))
	routes.append(_intro_route(
		stage_number,
		width,
		StageRouteProfile.Role.BUMPER,
		48.0,
		MechanismData.Kind.UPHILL_REBOUND,
		0.76,
		1.5
	))
	return routes


static func _intro_route(
		stage_number: int,
		width: float,
		role: StageRouteProfile.Role,
		endpoint_x: float,
		mechanism_kind: int = -1,
		mechanism_pad_t: float = -1.0,
		mechanism_pad_radius: float = 0.0
) -> StageRouteProfile:
	var route := StageRouteProfile.new()
	route.role = role
	route.endpoint_x = endpoint_x
	route.width = width
	route.grade_signs = PackedInt32Array([-1, -1, -1, -1, -1, -1, -1])
	route.drop_range = Vector2(5.5 + float(stage_number - 1) * 0.35, 7.0 + float(stage_number - 1) * 0.45)
	route.rise_range = Vector2.ZERO
	route.lateral_bend_range = Vector2(-8.0 - float(stage_number), 8.0 + float(stage_number))
	if stage_number == 3:
		# Keep the three tutorial branches readable and inside the per-station
		# movement limit. The route width, not this legacy pad radius, supports
		# the terrain-conforming glyph footprint.
		route.lateral_bend_range = Vector2(-4.0, 4.0)
	if stage_number == 2:
		route.mechanism_kinds = PackedInt32Array([MechanismData.Kind.BURST])
		# Keep the tutorial glyph on the broad upper shelf. The former midpoint
		# crossed the sharp bank and could not render as a readable surface mark.
		route.mechanism_pad_ts = PackedFloat32Array([0.25])
		route.mechanism_pad_radii = PackedFloat32Array([10.0])
	elif mechanism_kind >= 0:
		route.mechanism_kinds = PackedInt32Array([mechanism_kind])
		route.mechanism_pad_ts = PackedFloat32Array([mechanism_pad_t])
		route.mechanism_pad_radii = PackedFloat32Array([mechanism_pad_radius])
	return route


static func _materialize_mechanisms(source: Array[MechanismData], stage_number: int) -> Array[MechanismData]:
	var result: Array[MechanismData] = []
	var desired := StageProgressionData.mechanism_count_for(stage_number)
	if stage_number == 1:
		return result
	if stage_number == 2:
		_append_canonical_mechanism(result, MechanismData.Kind.BURST)
		return result
	if stage_number == 3:
		_append_canonical_mechanism(result, MechanismData.Kind.SPLITTER)
		_append_canonical_mechanism(result, MechanismData.Kind.UPHILL_REBOUND)
		return result

	var route_count := StageProgressionData.route_count_for(stage_number)
	var safe_early_kinds := [MechanismData.Kind.BURST, MechanismData.Kind.UPHILL_REBOUND]
	var three_route_default_kinds := [
		MechanismData.Kind.BURST,
		MechanismData.Kind.SPLITTER,
		MechanismData.Kind.UPHILL_REBOUND,
	]
	for index in range(desired):
		var kind: MechanismData.Kind
		if route_count < 3:
			kind = safe_early_kinds[index % safe_early_kinds.size()]
		elif index < source.size() and source[index] != null and source[index].is_valid():
			kind = source[index].canonical_kind()
		else:
			kind = three_route_default_kinds[index % three_route_default_kinds.size()]
		_append_canonical_mechanism(result, kind)
	return result


static func _append_canonical_mechanism(
		result: Array[MechanismData],
		kind: MechanismData.Kind
) -> void:
	var canonical := _canonical_mechanism_data(kind)
	if canonical != null:
		result.append(canonical.duplicate(true) as MechanismData)


static func _materialize_route_mechanism_slots(
		profile: StageGenerationProfile,
		loadout: Array[MechanismData],
		stage_number: int = -1
) -> bool:
	if profile == null:
		return false
	var slot_count := 0
	for route in profile.routes:
		if route != null:
			slot_count += route.mechanism_slots().size()
	if slot_count != loadout.size():
		return false

	var loadout_index := 0
	for route in profile.routes:
		if route == null:
			return false
		var source_slots := route.mechanism_slots()
		if source_slots.is_empty():
			continue
		var kinds := PackedInt32Array()
		var pad_ts := PackedFloat32Array()
		var pad_radii := PackedFloat32Array()
		for source_slot in source_slots:
			var mechanism := loadout[loadout_index]
			if mechanism == null:
				return false
			var kind := mechanism.canonical_kind()
			kinds.append(int(kind))
			pad_ts.append(_mechanism_pad_t(
				kind, float(source_slot.get("t", -1.0)), stage_number
			))
			pad_radii.append(_mechanism_pad_radius(kind, stage_number))
			loadout_index += 1
		route.mechanism_kind = -1
		route.mechanism_pad_t = -1.0
		route.mechanism_pad_radius = 0.0
		route.mechanism_kinds = kinds
		route.mechanism_pad_ts = pad_ts
		route.mechanism_pad_radii = pad_radii
	return loadout_index == loadout.size()


static func _mechanism_pad_t(
	kind: MechanismData.Kind,
	source_t: float,
	stage_number: int = -1
) -> float:
	# Stage 04's reviewed route has a natural uphill witness on its upper shelf;
	# the old late-route anchor sits on the sharp terminal descent instead.
	if stage_number == 4 and kind == MechanismData.Kind.UPHILL_REBOUND:
		return 0.30
	return source_t


static func _mechanism_pad_radius(kind: MechanismData.Kind, stage_number: int = -1) -> float:
	match int(kind):
		int(MechanismData.Kind.SPLITTER):
			return 10.0
		int(MechanismData.Kind.UPHILL_REBOUND):
			# Stages 04 and 08 use already-planar natural slopes, where even a
			# narrow artificial shelf erases the ascent witness.
			return 0.25 if stage_number in [4, 8] else 1.5
	# Burst's full ring must stay on its broad shelf instead of crossing the
	# sharp support blend at the edge of the old 8 m anchor.
	return 10.0


static func _canonical_mechanism_data(kind: MechanismData.Kind) -> MechanismData:
	match int(kind):
		int(MechanismData.Kind.BURST):
			return BURST_DATA
		int(MechanismData.Kind.SPLITTER):
			return SPLITTER_DATA
		int(MechanismData.Kind.UPHILL_REBOUND):
			return UPHILL_REBOUND_DATA
	return null
