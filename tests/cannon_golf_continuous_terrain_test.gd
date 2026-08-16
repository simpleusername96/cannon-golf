extends SceneTree

const FEATURE := preload("res://src/cannon_golf/continuous_terrain_feature.gd")
const FIELD := preload("res://src/cannon_golf/continuous_terrain_field.gd")
const GENERATOR := preload("res://src/cannon_golf/trajectory_course_generator.gd")

var _failed := false


func _initialize() -> void:
	_assert_continuous_feature_profiles()
	_assert_first_course_compiles_smoothly()
	print("Cannon Golf continuous curve terrain contract passed.")
	quit(1 if _failed else 0)


func _assert_continuous_feature_profiles() -> void:
	var ridge := FEATURE.new().configure(
		FEATURE.Kind.RIDGE,
		PackedVector2Array([Vector2(-30.0, 0.0), Vector2(30.0, 0.0)]),
		20.0, 0.45, 0.45, 0.85
	)
	var valley := FEATURE.new().configure(
		FEATURE.Kind.VALLEY,
		PackedVector2Array([Vector2(0.0, -30.0), Vector2(0.0, 30.0)]),
		18.0, 0.18, 0.18, 1.0
	)
	var shelf := FEATURE.new().configure(
		FEATURE.Kind.SHELF,
		PackedVector2Array([Vector2(-20.0, -22.0), Vector2(20.0, -22.0)]),
		16.0, 0.52, 0.52, 0.48
	)
	_assert_true(ridge.is_valid() and valley.is_valid() and shelf.is_valid(),
		"Continuous terrain features must validate their bounded curve profiles.")
	var ridge_field := _field_with(ridge)
	var valley_field := _field_with(valley)
	var shelf_field := _field_with(shelf)
	_assert_true(ridge_field != null and valley_field != null and shelf_field != null,
		"Each semantic feature must form a valid continuous field.")
	if ridge_field == null or valley_field == null or shelf_field == null:
		return
	_assert_true(
		is_equal_approx(ridge_field.sample(Vector2(4.0, 3.0)), ridge_field.sample(Vector2(4.0, 3.0))),
		"Continuous terrain sampling must be deterministic."
	)
	_assert_true(
		ridge_field.sample(Vector2.ZERO) > ridge_field.sample(Vector2(0.0, 28.0)),
		"A ridge curve must raise its spine above its compact exterior."
	)
	_assert_true(
		valley_field.sample(Vector2.ZERO) < valley_field.sample(Vector2(28.0, 0.0)),
		"A valley curve must lower its spine below its compact exterior."
	)
	_assert_true(
		shelf_field.sample(Vector2(0.0, -22.0)) > shelf_field.sample(Vector2(0.0, 4.0)),
		"A shelf curve must create a broad raised surface."
	)
	var inside: float = ridge_field.sample(Vector2(0.0, 19.999))
	var outside: float = ridge_field.sample(Vector2(0.0, 20.001))
	_assert_true(
		absf(inside - outside) < 0.01,
		"A compact curve field must meet its exterior continuously without a height seam."
	)


func _field_with(feature: RefCounted) -> RefCounted:
	var field := FIELD.new()
	field.local_bounds = Rect2(-50.0, -50.0, 100.0, 100.0)
	field.base_height = 0.0
	field.relief = 100.0
	field.seed_phase = 0.25
	return field if field.add_feature(feature) and field.is_valid() else null


func _assert_first_course_compiles_smoothly() -> void:
	_assert_true(GENERATOR.ALGORITHM_VERSION == 12,
		"The continuous curve-field replacement must advance the algorithm identity.")
	var course := CannonGolfCourseCatalog.course_at(0)
	var product := GENERATOR.build(course)
	_assert_true(not product.is_empty(),
		"The first course must satisfy all intrinsic contracts from the continuous field.")
	if product.is_empty():
		return
	var generated: CannonGolfGeneratedCourse = product.generated
	var smooth_geometry := generated.geometry
	_assert_true(smooth_geometry != null and smooth_geometry.is_valid(),
		"The continuous field must compile to valid render and collision geometry.")
	if smooth_geometry == null or not smooth_geometry.is_valid():
		return
	var flat_geometry := TerrainGeometryFactory.build(
		generated.layout, smooth_geometry.base_y, false
	)
	_assert_true(flat_geometry != null and flat_geometry.is_valid(),
		"The inherited flat geometry default must remain available.")
	if flat_geometry == null or not flat_geometry.is_valid():
		return
	_assert_true(
		smooth_geometry.top_triangle_count == flat_geometry.top_triangle_count \
				and smooth_geometry.top_shape.get_faces() == flat_geometry.top_shape.get_faces(),
		"Smooth rendering must not change collision vertices or triangle identity."
	)
	_assert_flat_top_normals(flat_geometry)
	_assert_smooth_top_normals_and_tone(smooth_geometry)


func _assert_flat_top_normals(geometry: TerrainGeometry) -> void:
	var arrays := geometry.render_mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for offset in range(0, geometry.top_vertex_count, 3):
		if not normals[offset].is_equal_approx(normals[offset + 1]) \
				or not normals[offset].is_equal_approx(normals[offset + 2]):
			_assert_true(false, "The shared geometry factory must stay flat-shaded by default.")
			return


func _assert_smooth_top_normals_and_tone(geometry: TerrainGeometry) -> void:
	var arrays := geometry.render_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var first_corner_by_source := {}
	var found_curved_vertex := false
	var minimum_tone := INF
	var maximum_tone := -INF
	for corner in range(geometry.top_vertex_count):
		var source_index := geometry.top_render_source_vertex_indices[corner]
		minimum_tone = minf(minimum_tone, colors[corner].g)
		maximum_tone = maxf(maximum_tone, colors[corner].g)
		if first_corner_by_source.has(source_index):
			var first_corner: int = first_corner_by_source[source_index]
			_assert_true(
				vertices[corner].is_equal_approx(vertices[first_corner]) \
						and normals[corner].dot(normals[first_corner]) > 0.99999 \
						and colors[corner].is_equal_approx(colors[first_corner]),
				"Duplicated render corners from one source vertex must share normal and tone."
			)
		else:
			first_corner_by_source[source_index] = corner
		var face_normal := geometry.top_topology.canonical_triangle_normals_read_only()[corner / 3]
		if normals[corner].dot(face_normal) < 0.9995:
			found_curved_vertex = true
	_assert_true(found_curved_vertex,
		"A curved course must use averaged vertex normals instead of only face normals.")
	_assert_true(maximum_tone - minimum_tone >= 0.05,
		"Smooth terrain must retain bounded macro-scale tonal variation.")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
