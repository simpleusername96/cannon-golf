extends SceneTree


func _initialize() -> void:
	var builder := CannonGolfCourseBuilder.new()
	root.add_child(builder)
	for course in CannonGolfCourseCatalog.all_courses():
		builder.build(course)
		var terrain := builder.terrain_body
		_assert_true(builder.terrain_body_count() == 1, "Terrain must use one body for %s." % course.course_id)
		_assert_true(terrain != null, "Terrain body must exist for %s." % course.course_id)
		_assert_true(terrain.is_in_group(&"impact_mark_surface"), "Terrain must be an impact surface.")
		var collision := terrain.get_node_or_null("TerrainCollision") as CollisionShape3D
		_assert_true(collision != null, "Connected terrain must have one collision shape.")
		_assert_true(collision.shape is ConcavePolygonShape3D, "Terrain collision must use triangle faces.")
		var faces := (collision.shape as ConcavePolygonShape3D).get_faces()
		_assert_true(faces.size() >= 36, "Connected terrain must contain shelf and skirt faces.")
		var mesh_instance := terrain.get_node_or_null("TerrainMesh") as MeshInstance3D
		_assert_true(mesh_instance != null, "Connected terrain must have one mesh instance.")
		var mesh := mesh_instance.mesh as ArrayMesh
		_assert_true(mesh != null and mesh.get_surface_count() == 1, "Terrain must be one triangle mesh surface.")
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		_assert_true(vertices.size() >= 36, "Terrain mesh must retain visible shelf geometry.")
		_assert_true(colors.size() == vertices.size(), "Terrain facets must carry stable color variation.")
		_assert_true(_contains_multiple_colors(colors), "Terrain must expose alternating low-poly facets.")
		_assert_true(_contains_upward_top_normal(normals), "Terrain shelves must be lit from upward-facing normals.")
		_assert_true(_retains_authored_shelf_levels(vertices, course), "Terrain must retain authored flat shelf levels.")
		_assert_true(_goal_area_is_recessed(vertices, course), "Goal floor area must remain below the terrain shelf edge.")
	print("Cannon Golf connected terrain contract passed for both courses.")
	quit(0)


func _contains_multiple_colors(colors: PackedColorArray) -> bool:
	if colors.is_empty():
		return false
	var first := colors[0]
	for color in colors:
		if not color.is_equal_approx(first):
			return true
	return false


func _contains_upward_top_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if normal.y > 0.99:
			return true
	return false


func _retains_authored_shelf_levels(vertices: PackedVector3Array, course: CannonGolfCourseData) -> bool:
	for index in range(course.block_centers.size()):
		var expected_top := course.block_centers[index].y + course.block_sizes[index].y * 0.5
		var found := false
		for vertex in vertices:
			if absf(vertex.y - expected_top) > 0.01:
				continue
			if _inside_authored_block(vertex, course, index):
				found = true
				break
		if not found:
			return false
	return true


func _goal_area_is_recessed(vertices: PackedVector3Array, course: CannonGolfCourseData) -> bool:
	var highest_goal_vertex := -1000000000.0
	var goal_center := Vector2(course.goal_position.x, course.goal_position.z)
	for vertex in vertices:
		if Vector2(vertex.x, vertex.z).distance_to(goal_center) <= course.goal_radius:
			highest_goal_vertex = maxf(highest_goal_vertex, vertex.y)
	return highest_goal_vertex <= course.goal_position.y - 0.2


func _inside_authored_block(point: Vector3, course: CannonGolfCourseData, index: int) -> bool:
	var center := course.block_centers[index]
	var local := Basis(Vector3.UP, -deg_to_rad(course.block_yaw_degrees[index])) * (point - center)
	var half_size := course.block_sizes[index] * 0.5
	return absf(local.x) <= half_size.x + 0.01 and absf(local.z) <= half_size.z + 0.01


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
