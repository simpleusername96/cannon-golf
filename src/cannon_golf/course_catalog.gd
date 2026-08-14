class_name CannonGolfCourseCatalog
extends RefCounted

const COURSE_ONE := preload("res://resources/cannon_golf/courses/first_ridge.tres")
const COURSE_TWO := preload("res://resources/cannon_golf/courses/rising_bend.tres")
const COURSE_THREE := preload("res://resources/cannon_golf/courses/summit_saddle.tres")
const COURSE_FOUR := preload("res://resources/cannon_golf/courses/deep_relay.tres")
const COURSE_FIVE := preload("res://resources/cannon_golf/courses/linked_bowls.tres")
const COURSE_SIX := preload("res://resources/cannon_golf/courses/terraced_peak.tres")
const COURSE_SEVEN := preload("res://resources/cannon_golf/courses/u_valley.tres")
const COURSE_EIGHT := preload("res://resources/cannon_golf/courses/twin_peaks.tres")
const COURSE_NINE := preload("res://resources/cannon_golf/courses/basin_garden.tres")
const COURSE_TEN := preload("res://resources/cannon_golf/courses/alpine_complex.tres")


static func all_courses() -> Array[CannonGolfCourseData]:
	return [COURSE_ONE, COURSE_TWO, COURSE_THREE, COURSE_FOUR, COURSE_FIVE, COURSE_SIX, COURSE_SEVEN, COURSE_EIGHT, COURSE_NINE, COURSE_TEN]


static func course_at(index: int) -> CannonGolfCourseData:
	var courses := all_courses()
	if index < 0 or index >= courses.size():
		return null
	return courses[index]


static func index_of(course_id: StringName) -> int:
	for index in range(all_courses().size()):
		if all_courses()[index].course_id == course_id:
			return index
	return -1


static func prepared_path_for(course: CannonGolfCourseData) -> String:
	return "res://resources/cannon_golf/prepared/%s.res" % course.course_id if course != null and not course.course_id.is_empty() else ""
