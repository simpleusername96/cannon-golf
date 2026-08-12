class_name MountainHeightFieldBuilder
extends RefCounted

## Samples the mountain-range surface inside the footprint owned by
## RouteGraphMountainSynthesizer. A continuous backbone and broad summit fields
## create the mass; route geometry only blends usable rolling lanes into it.

const KEYED_STAGE_SAMPLER := preload("res://src/stage_generation/keyed_stage_sampler.gd")
const FOOTPRINT_HEIGHT_BLEND := preload(
	"res://src/stage_generation/footprint_height_blend.gd"
)
const ROUTE_CORE_BLEND_RANGE := Vector2(0.30, 0.78)
const ROUTE_TARGET_BLEND_RANGE := Vector2(0.10, 0.62)
const RANGE_RELIEF_SCALE := 0.91
const FRONT_DESCENT_DISTANCE := 80.0


static func build(
		stage_id: StringName,
		profile: StageGenerationProfile,
		graph: GeneratedRouteGraph,
		terrain_seed: int,
		footprint: PackedByteArray
) -> PackedFloat32Array:
	var contract := profile.generation_contract
	var noise := FastNoiseLite.new()
	noise.seed = KEYED_STAGE_SAMPLER.fnv1a32(
		KEYED_STAGE_SAMPLER.versioned_key(stage_id, terrain_seed, "range/noise")
	) & 0x7fffffff
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = contract.noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = contract.noise_octaves
	noise.fractal_lacunarity = contract.noise_lacunarity
	noise.fractal_gain = contract.noise_gain
	var parameters := _build_range_parameters(stage_id, profile, graph, terrain_seed)
	var ordered_pads := graph.pad_nodes()
	var footprint_blends: PackedFloat32Array = FOOTPRINT_HEIGHT_BLEND.build(
		contract.cell_count,
		contract.local_bounds,
		footprint
	)

	var sample_size := contract.cell_count + Vector2i.ONE
	var heights := PackedFloat32Array()
	heights.resize(sample_size.x * sample_size.y)
	for z_index in range(sample_size.y):
		var local_z := lerpf(
			contract.local_bounds.position.y,
			contract.local_bounds.end.y,
			float(z_index) / float(contract.cell_count.y)
		)
		for x_index in range(sample_size.x):
			var local_x := lerpf(
				contract.local_bounds.position.x,
				contract.local_bounds.end.x,
				float(x_index) / float(contract.cell_count.x)
			)
			var sample_index := z_index * sample_size.x + x_index
			heights[sample_index] = _height_at(
				Vector2(local_x, local_z), graph, ordered_pads, contract,
				profile.nominal_peak,
				noise, parameters, footprint_blends[sample_index]
			)
	return heights


static func route_footprint_ratio(
		graph: GeneratedRouteGraph,
		contract: StageGenerationContract
) -> float:
	var edge_starts := PackedVector2Array()
	var edge_deltas := PackedVector2Array()
	var footprint_radii := PackedFloat32Array()
	for edge in graph.edges:
		var from := graph.node_by_id(edge.from_node_id).position
		var to := graph.node_by_id(edge.to_node_id).position
		var start := Vector2(from.x, from.z)
		edge_starts.append(start)
		edge_deltas.append(Vector2(to.x, to.z) - start)
		footprint_radii.append(edge.width * 0.5 + contract.target_shoulder_distance)
	var pad_positions := PackedVector2Array()
	var pad_radii := PackedFloat32Array()
	for pad in graph.pad_nodes():
		pad_positions.append(Vector2(pad.position.x, pad.position.z))
		pad_radii.append(pad.pad_radius + 4.0)
	var count := 0
	for pixel_y in range(contract.mask_size):
		var local_z := lerpf(
			contract.local_bounds.position.y,
			contract.local_bounds.end.y,
			(float(pixel_y) + 0.5) / float(contract.mask_size)
		)
		for pixel_x in range(contract.mask_size):
			var local_x := lerpf(
				contract.local_bounds.position.x,
				contract.local_bounds.end.x,
				(float(pixel_x) + 0.5) / float(contract.mask_size)
			)
			var point := Vector2(local_x, local_z)
			if _edge_distance(contract.local_bounds, point) < contract.outer_band_width:
				continue
			var included := false
			for edge_index in range(edge_starts.size()):
				var delta := edge_deltas[edge_index]
				var t := clampf(
					(point - edge_starts[edge_index]).dot(delta) \
							/ maxf(delta.length_squared(), 0.000001),
					0.0,
					1.0
				)
				var closest := edge_starts[edge_index] + delta * t
				if point.distance_squared_to(closest) \
						<= footprint_radii[edge_index] * footprint_radii[edge_index]:
					included = true
					break
			if not included:
				for pad_index in range(pad_positions.size()):
					if point.distance_squared_to(pad_positions[pad_index]) \
							<= pad_radii[pad_index] * pad_radii[pad_index]:
						included = true
						break
			if included:
				count += 1
	return float(count) / float(contract.mask_size * contract.mask_size)


static func _build_range_parameters(
		stage_id: StringName,
		profile: StageGenerationProfile,
		graph: GeneratedRouteGraph,
		terrain_seed: int
) -> Dictionary:
	var level := clampi(graph.route_count(), 1, 3)
	var range_angle := _sample_range(
		stage_id, terrain_seed, "range/angle", Vector2(-0.12, 0.12)
	)
	var direction := Vector2(cos(range_angle), sin(range_angle))
	var perpendicular := Vector2(-direction.y, direction.x)
	var ridges: Array[Dictionary] = [{
		"center": Vector2(
			_sample_range(stage_id, terrain_seed, "range/backbone/x", Vector2(-0.04, 0.04)),
			_sample_range(stage_id, terrain_seed, "range/backbone/z", Vector2(-0.34, -0.20))
		),
		"angle": range_angle + _sample_range(
			stage_id, terrain_seed, "range/backbone/angle", Vector2(-0.08, 0.08)
		),
		"height": _sample_range(
			stage_id, terrain_seed, "range/backbone/height", Vector2(0.47, 0.54)
		),
		"length_spread": _sample_range(
			stage_id, terrain_seed, "range/backbone/length", Vector2(0.58, 0.78)
		),
		"width_spread": _sample_range(
			stage_id, terrain_seed, "range/backbone/width", Vector2(0.11, 0.17)
		),
	}]
	var secondary_count := maxi(1, profile.ridge_count - 1)
	for index in range(secondary_count):
		var key := "range/ridge/%d" % index
		var progress := float(index + 1) / float(secondary_count + 1)
		var along := lerpf(-0.66, 0.66, progress) + _sample_range(
			stage_id, terrain_seed, key + "/along", Vector2(-0.07, 0.07)
		)
		var cross_limit := 0.10 + float(profile.ridge_count - 3) * 0.014
		var across := _sample_range(
			stage_id, terrain_seed, key + "/across", Vector2(-cross_limit, cross_limit)
		)
		ridges.append({
			"center": Vector2(0.0, -0.25) + direction * along + perpendicular * across,
			"angle": range_angle + _sample_range(
				stage_id, terrain_seed, key + "/angle", Vector2(-0.20, 0.20)
			),
			"height": _sample_range(
				stage_id, terrain_seed, key + "/height",
				Vector2(0.20 + float(profile.ridge_count - 3) * 0.015, 0.28 + float(profile.ridge_count - 3) * 0.020)
			),
			"length_spread": _sample_range(
				stage_id, terrain_seed, key + "/length", Vector2(0.22, 0.40)
			),
			"width_spread": _sample_range(
				stage_id, terrain_seed, key + "/width", Vector2(0.050, 0.095)
			),
		})
	var summits: Array[Dictionary] = []
	for index in range(1, ridges.size()):
		var ridge: Dictionary = ridges[index]
		var key := "range/summit/%d" % (index - 1)
		summits.append({
			"center": ridge.center,
			"angle": ridge.angle,
			"height": _sample_range(
				stage_id, terrain_seed, key + "/height",
				Vector2(0.16 + float(level) * 0.010, 0.22 + float(level) * 0.010)
			),
			"length_spread": _sample_range(
				stage_id, terrain_seed, key + "/length", Vector2(0.035, 0.065)
			),
			"width_spread": _sample_range(
				stage_id, terrain_seed, key + "/width", Vector2(0.070, 0.120)
			),
		})

	var basins: Array[Dictionary] = []
	for basin_index in range(profile.basin_count):
		var first: Dictionary = ridges[2]
		var second: Dictionary = ridges[mini(3 + basin_index, ridges.size() - 1)]
		var first_center: Vector2 = first["center"]
		var second_center: Vector2 = second["center"]
		basins.append({
			"center": first_center.lerp(second_center, 0.5) \
					+ perpendicular * 0.25,
			"angle": range_angle + _sample_range(
				stage_id, terrain_seed, "range/basin/%d/angle" % basin_index, Vector2(-0.45, 0.45)
			),
			"height": _sample_range(
				stage_id, terrain_seed, "range/basin/depth", Vector2(0.035, 0.055)
			),
			"length_spread": _sample_range(
				stage_id, terrain_seed, "range/basin/length", Vector2(0.10, 0.16)
			),
			"width_spread": _sample_range(
				stage_id, terrain_seed, "range/basin/width", Vector2(0.10, 0.17)
			),
		})

	var passes: Array[Dictionary] = []
	for index in range(profile.pass_count):
		var key := "range/pass/%d" % index
		var progress := float(index + 1) / float(profile.pass_count + 1)
		var along := lerpf(-0.46, 0.46, progress) + _sample_range(
			stage_id, terrain_seed, key + "/along", Vector2(-0.04, 0.04)
		)
		passes.append({
			"center": Vector2(0.0, -0.25) + direction * along,
			"angle": range_angle + PI * 0.5 + _sample_range(
				stage_id, terrain_seed, key + "/angle", Vector2(-0.18, 0.18)
			),
			"height": _sample_range(
				stage_id, terrain_seed, key + "/depth", Vector2(0.025, 0.045)
			),
			"length_spread": _sample_range(
				stage_id, terrain_seed, key + "/length", Vector2(0.14, 0.22)
			),
			"width_spread": _sample_range(
				stage_id, terrain_seed, key + "/width", Vector2(0.028, 0.050)
			),
		})

	var waves: Array[Dictionary] = []
	for index in range(profile.pass_count):
		var key := "range/wave/%d" % index
		waves.append({
			"angular_frequency": 2.0 + float(index),
			"radial_frequency": 1.0 + float(index % 2),
			"phase": _sample_range(stage_id, terrain_seed, key + "/phase", Vector2(0.0, TAU)),
			"amplitude": _sample_range(
				stage_id, terrain_seed, key + "/amplitude",
				Vector2(0.008, 0.014 + profile.undulation_amplitude * 0.0015)
			),
		})
	return {
		"ridges": ridges,
		"summits": summits,
		"basins": basins,
		"passes": passes,
		"waves": waves,
	}


static func _height_at(
		point: Vector2,
	graph: GeneratedRouteGraph,
	pads: Array[GeneratedRouteNode],
	contract: StageGenerationContract,
	nominal_peak: float,
	noise: FastNoiseLite,
	parameters: Dictionary,
	footprint_blend: float
) -> float:
	var nearest_distance := INF
	var nearest_core_radius := 0.0
	var route_height := 0.0
	for route_index in range(graph.route_count()):
		var route_edges := graph.route_edges(route_index)
		var closest_edge: GeneratedRouteEdge
		var closest_sample: Dictionary = {}
		for candidate_edge in route_edges:
			var candidate := _edge_sample(point, graph, candidate_edge)
			if closest_sample.is_empty() \
					or float(candidate.distance) < float(closest_sample.distance):
				closest_edge = candidate_edge
				closest_sample = candidate
		var height_edge := _edge_for_route_z(point.y, graph, route_edges)
		if closest_edge == null or height_edge == null:
			continue
		var cross_section := _cross_section_sample(point, graph, height_edge)
		var distance := float(closest_sample.distance)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_core_radius = closest_edge.width * 0.5
			route_height = float(cross_section.height)

	var normalized := Vector2(
		point.x / maxf(contract.local_bounds.size.x * 0.5, 0.001),
		point.y / maxf(contract.local_bounds.size.y * 0.5, 0.001)
	)
	var route_level_t := float(clampi(graph.route_count(), 1, 3) - 1) / 2.0
	var route_core_blend := lerpf(
		ROUTE_CORE_BLEND_RANGE.x, ROUTE_CORE_BLEND_RANGE.y, route_level_t
	)
	var route_target_blend := lerpf(
		ROUTE_TARGET_BLEND_RANGE.x, ROUTE_TARGET_BLEND_RANGE.y, route_level_t
	)
	if nearest_core_radius > 0.0:
		# A broad route remains rollable without becoming a perfectly flat strip.
		# The edge-lowering crown preserves the authored centerline height and
		# therefore does not move the certified primary landing point upward.
		var cross_t := _smoothstep01(nearest_distance / nearest_core_radius)
		var crown_steps := 3.0 / float(maxi(graph.route_count(), 1))
		route_height -= contract.terrace_step * crown_steps * cross_t
	var height_ratio := _range_height_ratio(normalized, parameters)
	# The approved mountain-range field owns the broad mass. Route height only
	# cuts a readable rolling lane into that mass; it must not turn the whole
	# target into one front-to-back ramp.
	var mountain_height := nominal_peak * height_ratio * RANGE_RELIEF_SCALE
	var terraced := roundf(mountain_height / contract.terrace_step) * contract.terrace_step
	mountain_height = lerpf(mountain_height, terraced, contract.terrace_blend)
	var target_edge := nearest_core_radius + contract.target_shoulder_distance
	var support_edge := nearest_core_radius + contract.support_distance
	# The route remains the majority height owner, but does not erase the broad
	# ridge field. This keeps a rollable lane from reading as a rectangular ramp.
	var route_blend := route_core_blend
	if nearest_distance > nearest_core_radius and nearest_distance <= target_edge:
		var target_t := _smoothstep01(
			(nearest_distance - nearest_core_radius) / contract.target_shoulder_distance
		)
		route_blend = lerpf(route_core_blend, route_target_blend, target_t)
	elif nearest_distance > target_edge:
		var support_t := _smoothstep01(
			(nearest_distance - target_edge) \
					/ maxf(support_edge - target_edge, 0.001)
		)
		route_blend = route_target_blend * (1.0 - support_t)
	var height := lerpf(mountain_height, route_height, route_blend)
	var noise_weight := 1.0 - route_blend
	height += noise.get_noise_2d(point.x, point.y) * contract.noise_amplitude * noise_weight
	height *= _front_descent_blend(contract, point.y)

	# Mechanism pads retain a flat core, but the complete surface still descends
	# through the actual irregular footprint before its closure shell begins.
	for pad in pads:
		var pad_xz := Vector2(pad.position.x, pad.position.z)
		var distance_to_pad := point.distance_to(pad_xz)
		var pad_weight := 1.0 - _smoothstep01(
			(distance_to_pad - 0.65 * pad.pad_radius) / (0.35 * pad.pad_radius)
		)
		var pad_height := pad.position.y * _front_descent_blend(contract, pad.position.z)
		height = lerpf(height, pad_height, pad_weight)
	# Never raise a contour sample above its footprint falloff. Doing so leaves a
	# high exposed edge that the closure mesh must turn into a rectangular wall.
	return maxf(0.0, height * footprint_blend)


static func _front_descent_blend(
		contract: StageGenerationContract,
		local_z: float
) -> float:
	var distance_to_front := contract.local_bounds.end.y - local_z
	return _smoothstep01(distance_to_front / FRONT_DESCENT_DISTANCE)


static func _range_height_ratio(point: Vector2, parameters: Dictionary) -> float:
	var radial := Vector2(point.x * 0.88, (point.y + 0.08) * 0.78).length()
	var body := 0.30 + 0.26 * pow(maxf(0.0, 1.0 - pow(radial, 1.8)), 0.68)
	var strongest := 0.0
	var second := 0.0
	var third := 0.0
	for ridge in parameters.ridges:
		var contribution := float(ridge.height) * _oriented_gaussian(point, ridge)
		if contribution > strongest:
			third = second
			second = strongest
			strongest = contribution
		elif contribution > second:
			third = second
			second = contribution
		elif contribution > third:
			third = contribution
	var ratio := body + strongest + second * 0.34 + third * 0.12
	var strongest_summit := 0.0
	var second_summit := 0.0
	for summit in parameters.summits:
		var contribution := float(summit.height) * _oriented_gaussian(point, summit)
		if contribution > strongest_summit:
			second_summit = strongest_summit
			strongest_summit = contribution
		elif contribution > second_summit:
			second_summit = contribution
	ratio += strongest_summit + second_summit * 0.18
	var theta := atan2(point.y, point.x)
	for wave in parameters.waves:
		var angular_wave := sin(theta * float(wave.angular_frequency) + float(wave.phase))
		var radial_wave := sin(radial * PI * float(wave.radial_frequency))
		ratio += angular_wave * radial_wave * float(wave.amplitude)
	for basin in parameters.basins:
		ratio -= float(basin.height) * _oriented_gaussian(point, basin)
	for range_pass in parameters.passes:
		ratio -= float(range_pass.height) * _oriented_gaussian(point, range_pass)
	# Preserve separation between overlapping ridges. Clamping at 1.0 flattened
	# every strong contribution into one table-top summit; the paired relief
	# scale keeps the authored nominal peak while retaining the ridge hierarchy.
	return clampf(ratio, 0.30, 1.16)


static func _oriented_gaussian(point: Vector2, feature: Dictionary) -> float:
	var center: Vector2 = feature.center
	var delta := point - center
	var angle := float(feature.angle)
	var cosine := cos(angle)
	var sine := sin(angle)
	var along := delta.x * cosine + delta.y * sine
	var across := -delta.x * sine + delta.y * cosine
	return exp(-(
		along * along / float(feature.length_spread)
		+ across * across / float(feature.width_spread)
	))


static func _edge_sample(
		point: Vector2,
		graph: GeneratedRouteGraph,
		edge: GeneratedRouteEdge
) -> Dictionary:
	var from := graph.node_by_id(edge.from_node_id).position
	var to := graph.node_by_id(edge.to_node_id).position
	var from_xz := Vector2(from.x, from.z)
	var to_xz := Vector2(to.x, to.z)
	var delta := to_xz - from_xz
	var t := clampf(
		(point - from_xz).dot(delta) / maxf(delta.length_squared(), 0.000001),
		0.0,
		1.0
	)
	return {
		"distance": point.distance_to(from_xz.lerp(to_xz, t)),
		"height": lerpf(from.y, to.y, t),
	}


static func _edge_for_route_z(
		local_z: float,
		graph: GeneratedRouteGraph,
		route_edges: Array[GeneratedRouteEdge]
) -> GeneratedRouteEdge:
	if route_edges.is_empty():
		return null
	for edge in route_edges:
		var finish := graph.node_by_id(edge.to_node_id).position
		if local_z <= finish.z:
			return edge
	return route_edges[-1]


static func _cross_section_sample(
		point: Vector2,
		graph: GeneratedRouteGraph,
		edge: GeneratedRouteEdge
) -> Dictionary:
	var from := graph.node_by_id(edge.from_node_id).position
	var to := graph.node_by_id(edge.to_node_id).position
	var t := clampf((point.y - from.z) / maxf(to.z - from.z, 0.000001), 0.0, 1.0)
	return {
		"height": lerpf(from.y, to.y, t),
	}


static func _sample_range(
		stage_id: StringName,
		terrain_seed: int,
		key: String,
		value_range: Vector2
) -> float:
	return KEYED_STAGE_SAMPLER.sample_range(stage_id, terrain_seed, key, value_range)


static func _smoothstep01(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


static func _edge_distance(bounds: Rect2, point: Vector2) -> float:
	return minf(
		minf(point.x - bounds.position.x, bounds.end.x - point.x),
		minf(point.y - bounds.position.y, bounds.end.y - point.y)
	)
