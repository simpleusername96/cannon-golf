class_name CannonGolfCourseRouteMotifs
extends RefCounted

## Course-scale station patterns are deliberately small authored vocabulary.
## Values multiply the generator's bounded lateral span; the first station is
## the opening launcher and each following station is one goal.

const STATION_MULTIPLIERS := [
	[-0.82, 0.56],
	[0.78, -0.50],
	[-0.76, 0.58, -0.18],
	[0.70, -0.64, 0.42],
	[-0.68, 0.22, 0.58, -0.38],
	[0.74, -0.20, -0.70, 0.36],
	[-0.58, 0.70, -0.50, 0.62, -0.92],
	[0.62, -0.90, 0.50, -0.62, -0.06],
	[-0.74, 0.34, -0.92, 0.68, -0.82, 0.90],
	[0.68, -0.95, 0.86, -0.78, 0.94, -0.66, 0.74],
	[-0.96, 0.88, -0.82, 0.94, -0.90],
	[0.94, -0.92, 0.86, -0.96, 0.90, -0.84],
	[-0.98, 0.92, -0.88, 0.96, -0.94, 0.86, -0.90],
	[0.90, -0.98, 0.94, -0.86, 0.98, -0.92, 0.88],
	[-0.94, 0.98, -0.90, 0.96, -0.86, 0.92, -0.98],
]

const MACRO_PROFILE_NAMES := [
	&"ridge_spur", &"rising_bend", &"summit_saddle", &"deep_relay",
	&"linked_basins", &"terraced_peak", &"u_valley", &"twin_peaks",
	&"basin_garden", &"summit_chain",
	&"granite_switchbacks", &"skyline_crossing", &"crown_relay",
	&"storm_saddles", &"final_ascent",
]


static func station_multiplier(course_index: int, station_index: int) -> float:
	if course_index < 0 or course_index >= STATION_MULTIPLIERS.size():
		return 0.0
	var stations: Array = STATION_MULTIPLIERS[course_index]
	if station_index < 0 or station_index >= stations.size():
		return 0.0
	return stations[station_index]


static func has_station_count(course_index: int, leg_count: int) -> bool:
	return course_index >= 0 and course_index < STATION_MULTIPLIERS.size() \
			and leg_count >= 1 and STATION_MULTIPLIERS[course_index].size() == leg_count + 1


static func macro_profile_name(course_index: int) -> StringName:
	if course_index < 0 or course_index >= MACRO_PROFILE_NAMES.size():
		return &"ridge_spur"
	return MACRO_PROFILE_NAMES[course_index]
