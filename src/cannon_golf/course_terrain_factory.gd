class_name CannonGolfCourseTerrainFactory
extends RefCounted

## Builds the authored shelf blocks as one closed faceted terrain mesh.
##
## The course resources remain intentionally simple editor data. This factory
## turns their overlapping shelf volumes into one physics owner so the ball
## cannot observe implementation seams between blocks while the top faces
## retain the authored flat route and elevation changes.

const TOP_GRID_X := 4
const TOP_GRID_Z := 4
const GOAL_RECESS_DEPTH := 0.72
const GOAL_RECESS_INNER_MARGIN := 0.65
const GOAL_RECESS_OUTER_MARGIN := 1.35


static func build(course: CannonGolfCourseData) -> Dictionary:
	assert(course != null and course.is_valid(), "Terrain factory requires valid course data.")
	var render_vertices := PackedVector3Array()
	var render_normals := PackedVector3Array()
	var render_colors := PackedColorArray()
	var collision_faces := PackedVector3Array()
	var goal_block_index := _goal_block_index(course)
	for index in range(course.block_centers.size()):
		_append_block(
			course,
			index,
			goal_block_index == index,
			render_vertices,
			render_normals,
			render_colors,
			collision_faces
		)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = render_vertices
	arrays[Mesh.ARRAY_NORMAL] = render_normals
	arrays[Mesh.ARRAY_COLOR] = render_colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision_faces)
	return {
		"mesh": mesh,
		"collision_shape": shape,
		"render_vertex_count": render_vertices.size(),
		"collision_face_count": collision_faces.size() / 3,
		"goal_block_index": goal_block_index,
	}


static func _append_block(
		course: CannonGolfCourseData,
		block_index: int,
		is_goal_block: bool,
		render_vertices: PackedVector3Array,
		render_normals: PackedVector3Array,
		render_colors: PackedColorArray,
		collision_faces: PackedVector3Array
) -> void:
	var center := course.block_centers[block_index]
	var size := course.block_sizes[block_index]
	var yaw := deg_to_rad(course.block_yaw_degrees[block_index])
	var basis := Basis(Vector3.UP, yaw)
	var half_size := size * 0.5
	var top_y := center.y + half_size.y
	var bottom_y := minf(center.y - half_size.y - 1.8, -4.6)
	var stride := TOP_GRID_X + 1
	var top_grid: Array[Vector3] = []
	for z_index in range(TOP_GRID_Z + 1):
		var z_fraction := float(z_index) / float(TOP_GRID_Z)
		for x_index in range(TOP_GRID_X + 1):
			var x_fraction := float(x_index) / float(TOP_GRID_X)
			var local_x := lerpf(-half_size.x, half_size.x, x_fraction)
			var local_z := lerpf(-half_size.z, half_size.z, z_fraction)
			var world_xz := center + basis * Vector3(local_x, 0.0, local_z)
			var height := top_y
			if is_goal_block:
				height += _goal_recess_offset(world_xz, course)
			top_grid.append(Vector3(world_xz.x, height, world_xz.z))

	for z_index in range(TOP_GRID_Z):
		for x_index in range(TOP_GRID_X):
			var p00 := top_grid[z_index * stride + x_index]
			var p10 := top_grid[z_index * stride + x_index + 1]
			var p01 := top_grid[(z_index + 1) * stride + x_index]
			var p11 := top_grid[(z_index + 1) * stride + x_index + 1]
			var cell_center := (p00 + p10 + p01 + p11) * 0.25
			if _top_cell_is_covered(course, block_index, cell_center):
				continue
			var alternate_diagonal := (block_index + x_index + z_index) % 2 == 1
			var first_color := _facet_color(course, block_index, x_index + z_index)
			var second_color := _facet_color(course, block_index, x_index + z_index + 1)
			if alternate_diagonal:
				_append_triangle(
					p00, p01, p10, first_color,
					render_vertices, render_normals, render_colors, collision_faces
				)
				_append_triangle(
					p10, p01, p11, second_color,
					render_vertices, render_normals, render_colors, collision_faces
				)
			else:
				_append_triangle(
					p00, p11, p10, first_color,
					render_vertices, render_normals, render_colors, collision_faces
				)
				_append_triangle(
					p00, p01, p11, second_color,
					render_vertices, render_normals, render_colors, collision_faces
				)

	# Close each shelf with a broad skirt that descends into the ground apron.
	# The wider base changes the silhouette from stacked boxes to a low-poly
	# mountain ridge without changing any certified top-surface contact.
	var bottom_grid: Array[Vector3] = []
	for z_index in range(TOP_GRID_Z + 1):
		var z_fraction := float(z_index) / float(TOP_GRID_Z)
		for x_index in range(TOP_GRID_X + 1):
			var x_fraction := float(x_index) / float(TOP_GRID_X)
			var local_x := lerpf(-half_size.x * 1.32, half_size.x * 1.32, x_fraction)
			var local_z := lerpf(-half_size.z * 1.18, half_size.z * 1.18, z_fraction)
			var world := center + basis * Vector3(local_x, 0.0, local_z)
			bottom_grid.append(Vector3(world.x, bottom_y, world.z))
	for x_index in range(TOP_GRID_X):
		_append_wall_segment(
			top_grid[x_index], top_grid[x_index + 1],
			bottom_grid[x_index], bottom_grid[x_index + 1],
			course, block_index,
			render_vertices, render_normals, render_colors, collision_faces
		)
	for z_index in range(TOP_GRID_Z):
		var top_offset := z_index * stride + TOP_GRID_X
		var bottom_offset := z_index * stride + TOP_GRID_X
		_append_wall_segment(
			top_grid[top_offset], top_grid[top_offset + stride],
			bottom_grid[bottom_offset], bottom_grid[bottom_offset + stride],
			course, block_index,
			render_vertices, render_normals, render_colors, collision_faces
		)
	for x_index in range(TOP_GRID_X, 0, -1):
		var top_offset := TOP_GRID_Z * stride + x_index
		var bottom_offset := TOP_GRID_Z * stride + x_index
		_append_wall_segment(
			top_grid[top_offset], top_grid[top_offset - 1],
			bottom_grid[bottom_offset], bottom_grid[bottom_offset - 1],
			course, block_index,
			render_vertices, render_normals, render_colors, collision_faces
		)
	for z_index in range(TOP_GRID_Z, 0, -1):
		var top_offset := z_index * stride
		var bottom_offset := z_index * stride
		_append_wall_segment(
			top_grid[top_offset], top_grid[top_offset - stride],
			bottom_grid[bottom_offset], bottom_grid[bottom_offset - stride],
			course, block_index,
			render_vertices, render_normals, render_colors, collision_faces
		)

	var bottom_a := bottom_grid[0]
	var bottom_b := bottom_grid[TOP_GRID_X]
	var bottom_c := bottom_grid[TOP_GRID_Z * stride]
	var bottom_d := bottom_grid[TOP_GRID_Z * stride + TOP_GRID_X]
	var bottom_color := _side_color(course, block_index)
	_append_triangle(
		bottom_a, bottom_c, bottom_b, bottom_color,
		render_vertices, render_normals, render_colors, collision_faces
	)
	_append_triangle(
		bottom_b, bottom_c, bottom_d, bottom_color,
		render_vertices, render_normals, render_colors, collision_faces
	)


static func _append_wall_segment(
		top_a: Vector3,
		top_b: Vector3,
		bottom_a: Vector3,
		bottom_b: Vector3,
		course: CannonGolfCourseData,
		block_index: int,
		render_vertices: PackedVector3Array,
		render_normals: PackedVector3Array,
		render_colors: PackedColorArray,
		collision_faces: PackedVector3Array
) -> void:
	var color := _side_color(course, block_index)
	_append_triangle(
		top_a, top_b, bottom_a, color,
		render_vertices, render_normals, render_colors, collision_faces
	)
	_append_triangle(
		top_b, bottom_b, bottom_a, color.darkened(0.06),
		render_vertices, render_normals, render_colors, collision_faces
	)


static func _append_triangle(
		a: Vector3,
		b: Vector3,
		c: Vector3,
		color: Color,
		render_vertices: PackedVector3Array,
		render_normals: PackedVector3Array,
		render_colors: PackedColorArray,
		collision_faces: PackedVector3Array
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	render_vertices.append_array(PackedVector3Array([a, b, c]))
	render_normals.append_array(PackedVector3Array([normal, normal, normal]))
	render_colors.append_array(PackedColorArray([color, color, color]))
	collision_faces.append_array(PackedVector3Array([a, b, c]))


static func _goal_block_index(course: CannonGolfCourseData) -> int:
	var selected := -1
	var highest_top := -1000000000.0
	for index in range(course.block_centers.size()):
		if not _point_inside_block(course.goal_position, course, index):
			continue
		var top := course.block_centers[index].y + course.block_sizes[index].y * 0.5
		if top > highest_top:
			highest_top = top
			selected = index
	return selected if selected >= 0 else course.block_centers.size() - 1


static func _top_cell_is_covered(
		course: CannonGolfCourseData,
		block_index: int,
		cell_center: Vector3
) -> bool:
	var current_top := course.block_centers[block_index].y + course.block_sizes[block_index].y * 0.5
	for other_index in range(course.block_centers.size()):
		if other_index == block_index:
			continue
		var other_top := course.block_centers[other_index].y + course.block_sizes[other_index].y * 0.5
		if other_top + 0.01 < current_top:
			continue
		if _point_inside_block(cell_center, course, other_index):
			return true
	return false


static func _point_inside_block(point: Vector3, course: CannonGolfCourseData, block_index: int) -> bool:
	var center := course.block_centers[block_index]
	var yaw := deg_to_rad(course.block_yaw_degrees[block_index])
	var local := Basis(Vector3.UP, -yaw) * (point - center)
	var half_size := course.block_sizes[block_index] * 0.5
	return absf(local.x) <= half_size.x + 0.01 and absf(local.z) <= half_size.z + 0.01


static func _goal_recess_offset(point: Vector3, course: CannonGolfCourseData) -> float:
	var distance := Vector2(point.x, point.z).distance_to(
		Vector2(course.goal_position.x, course.goal_position.z)
	)
	var inner_radius := maxf(course.goal_radius - GOAL_RECESS_INNER_MARGIN, 0.5)
	var outer_radius := course.goal_radius + GOAL_RECESS_OUTER_MARGIN
	if distance <= inner_radius:
		return -GOAL_RECESS_DEPTH
	if distance >= outer_radius:
		return 0.0
	var fraction := (distance - inner_radius) / (outer_radius - inner_radius)
	var smooth_fraction := fraction * fraction * (3.0 - 2.0 * fraction)
	return lerpf(-GOAL_RECESS_DEPTH, 0.0, smooth_fraction)


static func _facet_color(course: CannonGolfCourseData, block_index: int, facet_index: int) -> Color:
	var base := course.terrain_color if (block_index + facet_index) % 2 == 0 else course.terrain_accent_color
	var tone := 0.96 if facet_index % 3 == 0 else 1.0
	return Color(base.r * tone, base.g * tone, base.b * tone, 1.0)


static func _side_color(course: CannonGolfCourseData, block_index: int) -> Color:
	var base := course.terrain_accent_color if block_index % 2 == 0 else course.terrain_color
	return base.darkened(0.14)
