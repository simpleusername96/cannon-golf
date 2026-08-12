class_name CannonGolfCourseCatalog
extends RefCounted

const COURSE_ONE := preload("res://resources/cannon_golf/courses/quiet_shelf.tres")
const COURSE_TWO := preload("res://resources/cannon_golf/courses/rising_bend.tres")


static func all_courses() -> Array[CannonGolfCourseData]:
	return [COURSE_ONE, COURSE_TWO]


static func course_at(index: int) -> CannonGolfCourseData:
	var courses := all_courses()
	if index < 0 or index >= courses.size():
		return null
	return courses[index]
