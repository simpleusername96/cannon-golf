class_name StageProgressionData
extends Resource

## Single source of truth for the thirty-stage geometry ladder. Runtime stage
## entry consumes the one canonical terrain-family seed from the catalog; it
## never chooses or searches for a replacement seed.

const CANONICAL_TERRAIN_SEED := 1347223552
const STAGE_COUNT := 30

@export_category("Versioned progression")
@export var progression_version: int = StageGenerationContract.CONTRACT_VERSION
@export var stage_count: int = STAGE_COUNT


static func target_for(stage_number: int) -> float:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	if n <= 10:
		return 4.0 + 0.5 * float(n - 1)
	if n <= 15:
		return 8.5
	if n <= 20:
		return 9.0
	if n <= 25:
		return 9.5
	return 10.0


static func shots_for(stage_number: int) -> int:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	if n <= 5:
		return 4
	if n <= 15:
		return 5
	if n <= 25:
		return 6
	return 7


static func duration_seconds_for(stage_number: int) -> int:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	if n <= 10:
		return 60
	if n <= 20:
		return 90
	return 120


static func normalized_t(stage_number: int) -> float:
	return float(clampi(stage_number, 1, STAGE_COUNT) - 1) / float(STAGE_COUNT - 1)


static func nominal_peak_for(stage_number: int) -> float:
	return snappedf(64.0 + 28.0 * normalized_t(stage_number), 0.5)


static func terrain_seed_for(stage_number: int) -> int:
	# Keep the argument so callers remain explicit about stage identity even
	# though the terrain-family seed is intentionally shared.
	clampi(stage_number, 1, STAGE_COUNT)
	return CANONICAL_TERRAIN_SEED


static func terrain_size_for(stage_number: int) -> Vector2:
	var t := normalized_t(stage_number)
	return Vector2(
		float(roundi((210.0 + 70.0 * t) / 2.0) * 2),
		float(roundi((120.0 + 40.0 * t) / 2.0) * 2)
	)


static func cell_count_for(stage_number: int) -> Vector2i:
	var t := normalized_t(stage_number)
	return Vector2i(
		roundi((84.0 + 12.0 * t) / 2.0) * 2,
		roundi((48.0 + 16.0 * t) / 2.0) * 2
	)


static func station_count_for(stage_number: int) -> int:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	return 8 if n <= 9 else (9 if n <= 19 else 10)


static func route_count_for(stage_number: int) -> int:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	if n == 3:
		return 3
	return 1 if n <= 7 else (2 if n <= 17 else 3)


static func reversal_count_for(stage_number: int) -> int:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	return 0 if n <= 3 else (1 if n <= 11 else (2 if n <= 21 else 3))


static func ridge_count_for(stage_number: int) -> int:
	return 3 + floori(float(clampi(stage_number, 1, STAGE_COUNT) - 1) / 5.0)


static func basin_count_for(stage_number: int) -> int:
	return 0 if stage_number <= 6 else (1 if stage_number <= 16 else 2)


static func pass_count_for(stage_number: int) -> int:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	return 0 if n <= 5 else (1 if n <= 13 else (2 if n <= 21 else 3))


static func undulation_for(stage_number: int) -> float:
	return snappedf(2.0 + 6.0 * normalized_t(stage_number), 0.1)


static func route_width_for(stage_number: int) -> float:
	return snappedf(28.0 - 10.0 * normalized_t(stage_number), 0.5)


static func mechanism_count_for(stage_number: int) -> int:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	if n == 1:
		return 0
	if n == 2:
		return 1
	if n <= 6:
		return 2
	if n <= 12:
		return 3
	if n <= 18:
		return 4
	if n <= 24:
		return 5
	return 6


static func difficulty_score_for(stage_number: int) -> float:
	var n := clampi(stage_number, 1, STAGE_COUNT)
	var size := terrain_size_for(n)
	# Stage 03's wide three-route fan is a Splitter teaching witness, not the
	# late-game route-density tier. Keep the authored difficulty ladder gradual.
	var difficulty_route_count := 1 if n == 3 else route_count_for(n)
	return 0.05 * (size.x - 210.0) \
			+ 0.05 * (size.y - 120.0) \
			+ 4.0 * (difficulty_route_count - 1) \
			+ 2.0 * reversal_count_for(n) \
			+ 0.8 * (ridge_count_for(n) - 3) \
			+ pass_count_for(n) \
			+ basin_count_for(n) \
			+ 0.5 * (28.0 - route_width_for(n)) \
			+ 0.5 * mechanism_count_for(n) \
			+ 0.2 * (target_for(n) - 4.0) \
			+ 0.5 * (undulation_for(n) - 2.0) \
			+ 0.4 * (station_count_for(n) - 8)
