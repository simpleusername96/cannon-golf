class_name MechanismData
extends Resource

enum Kind {
	BURST = 0,
	SPLITTER = 1,
	UPHILL_REBOUND = 2,
	# Serialized stage resources and callers from the previous contract still
	# decode value 2. Remove this alias after those callers use the new name.
	BUMPER = 2,
}

@export_category("Identity")
@export var kind: Kind = Kind.BURST
@export var display_name_key: StringName = &"mechanism.burst"
@export var description_key: StringName = &"mechanism.burst.description"

@export_category("Activation")
@export_range(2.0, 8.0, 0.1) var glyph_radius: float = 4.2
@export_range(0, 8, 1) var maximum_charges: int = 1
@export_range(0.0, 5.0, 0.05) var cooldown_seconds: float = 0.35

@export_category("Burst")
@export_range(0.5, 40.0, 0.5) var burst_radius: float = 14.0

@export_category("Splitter")
@export_range(2, 5, 1) var child_count: int = 3
@export_range(0, 2, 1) var maximum_split_generation: int = 1
@export_range(0.5, 1.0, 0.01) var child_radius_multiplier: float = 0.78
@export_range(0.2, 1.5, 0.05) var child_speed_multiplier: float = 0.78
@export_range(1.0, 60.0, 0.5) var child_minimum_route_speed: float = 22.0
@export_range(0.0, 20.0, 0.5) var child_target_lift: float = 5.0
@export_range(0.0, 1.0, 0.01) var child_target_t: float = 0.82
@export var child_target_route_roles := PackedInt32Array([
	StageRouteProfile.Role.SAFE,
	StageRouteProfile.Role.SPLITTER,
	StageRouteProfile.Role.BUMPER,
])

@export_category("Uphill Rebound")
@export_range(1.0, 8.0, 0.25) var uphill_sample_distance: float = 3.0
@export_range(0.1, 4.0, 0.1) var minimum_uphill_rise: float = 0.5
@export_range(0.2, 1.5, 0.05) var rebound_speed_multiplier: float = 0.85
@export_range(1.0, 60.0, 0.5) var rebound_minimum_speed: float = 18.0
@export_range(1.0, 60.0, 0.5) var rebound_maximum_speed: float = 32.0
@export_range(0.0, 1.0, 0.01) var rebound_lift_ratio: float = 0.22


func has_finite_charges() -> bool:
	return maximum_charges > 0


func canonical_kind() -> Kind:
	return Kind.UPHILL_REBOUND if int(kind) == int(Kind.UPHILL_REBOUND) else kind


func is_valid() -> bool:
	if glyph_radius <= 0.0 or not is_finite(glyph_radius) \
			or maximum_charges < 0 or cooldown_seconds < 0.0:
		return false
	match canonical_kind():
		Kind.BURST:
			return burst_radius > 0.0 and is_finite(burst_radius)
		Kind.SPLITTER:
			return child_count == 3 and maximum_split_generation == 1 \
					and child_radius_multiplier > 0.0 \
					and child_speed_multiplier > 0.0 \
					and child_minimum_route_speed > 0.0 \
					and child_target_route_roles.size() == child_count
		Kind.UPHILL_REBOUND:
			return uphill_sample_distance > 0.0 and minimum_uphill_rise > 0.0 \
					and rebound_speed_multiplier > 0.0 \
					and rebound_minimum_speed > 0.0 \
					and rebound_maximum_speed >= rebound_minimum_speed \
					and rebound_lift_ratio >= 0.0
	return false
