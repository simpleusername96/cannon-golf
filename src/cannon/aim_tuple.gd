class_name AimTuple
extends RefCounted

# The version-7 target footprint reaches 76.3° from the cannon at the widest
# late-stage route. Keep a small margin so every scoreable surface remains in
# the legal horizontal aiming fan instead of relying on an unreachable pixel.
const MINIMUM_YAW_DEGREES := -80.0
const MAXIMUM_YAW_DEGREES := 80.0
const MINIMUM_ELEVATION_DEGREES := 10.0
const MAXIMUM_ELEVATION_DEGREES := 68.0
const MINIMUM_POWER_PERCENT := 0
const MAXIMUM_POWER_PERCENT := 100

var yaw_degrees: float:
	get:
		return _yaw_degrees
var elevation_degrees: float:
	get:
		return _elevation_degrees
var power_percent: float:
	get:
		return _power_percent

var _yaw_degrees: float
var _elevation_degrees: float
var _power_percent: float


func _init(yaw: float = 0.0, elevation: float = 10.0, power: float = 0.0) -> void:
	_yaw_degrees = yaw
	_elevation_degrees = elevation
	_power_percent = power


func is_valid() -> bool:
	return is_finite(_yaw_degrees) and is_finite(_elevation_degrees) \
			and _yaw_degrees >= MINIMUM_YAW_DEGREES \
			and _yaw_degrees <= MAXIMUM_YAW_DEGREES \
			and _elevation_degrees >= MINIMUM_ELEVATION_DEGREES \
			and _elevation_degrees <= MAXIMUM_ELEVATION_DEGREES \
			and _power_percent >= MINIMUM_POWER_PERCENT \
			and _power_percent <= MAXIMUM_POWER_PERCENT \
			and is_equal_approx(_yaw_degrees, snap_angle(_yaw_degrees)) \
			and is_equal_approx(_elevation_degrees, snap_angle(_elevation_degrees)) \
			and is_equal_approx(_power_percent, snap_power(_power_percent))


func stable_key() -> StringName:
	var power_tenths := _round_half_away_from_zero(_power_percent * 10.0)
	var power_whole := power_tenths / 10
	if power_tenths % 10 == 0:
		# Existing generated certificates and catalog witnesses use this exact key.
		return StringName("%d:%d:%d" % [
			_round_half_away_from_zero(_yaw_degrees * 10.0),
			_round_half_away_from_zero(_elevation_degrees * 10.0),
			power_whole,
		])
	# The decimal suffix cannot collide with a historical whole-percent key.
	return StringName("%d:%d:%d.%d" % [
		_round_half_away_from_zero(_yaw_degrees * 10.0),
		_round_half_away_from_zero(_elevation_degrees * 10.0),
		power_whole,
		power_tenths % 10,
	])


func is_equal_to(other: AimTuple) -> bool:
	return other != null and stable_key() == other.stable_key()


static func canonicalize(yaw: float, elevation: float, power: float) -> AimTuple:
	if not is_finite(yaw) or not is_finite(elevation) or not is_finite(power):
		return null
	return AimTuple.new(
		snap_angle(clampf(yaw, MINIMUM_YAW_DEGREES, MAXIMUM_YAW_DEGREES)),
		snap_angle(clampf(elevation, MINIMUM_ELEVATION_DEGREES, MAXIMUM_ELEVATION_DEGREES)),
		snap_power(clampf(power, MINIMUM_POWER_PERCENT, MAXIMUM_POWER_PERCENT))
	)


static func snap_angle(value: float) -> float:
	return float(_round_half_away_from_zero(value * 10.0)) / 10.0


static func snap_power(value: float) -> float:
	return float(_round_half_away_from_zero(value * 10.0)) / 10.0


static func _round_half_away_from_zero(value: float) -> int:
	return floori(value + 0.5) if value >= 0.0 else ceili(value - 0.5)
