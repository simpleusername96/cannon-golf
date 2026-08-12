class_name TrajectoryPreview
extends Node3D

const MAXIMUM_DOTS := 96
const MINIMUM_DOT_SPACING := 2.8

var first_collision_position := Vector3.ZERO
var has_first_collision := false
var _cannon: CannonController
var _prediction: TrajectoryPrediction
var _dot_instances: MultiMeshInstance3D
var _dot_multimesh: MultiMesh
var _visible_sample_count := 0
var _impact_marker: MeshInstance3D
var _exit_marker: Node3D
var _pending := false


func _ready() -> void:
	_build_visuals()
	visibility_changed.connect(_update_process_enabled)
	_update_process_enabled()


func _process(_delta: float) -> void:
	if _prediction == null:
		return
	if _impact_marker.visible:
		_set_marker_scale(_impact_marker, _prediction.collision_contact_point())
	elif _exit_marker.visible:
		var active_camera := get_viewport().get_camera_3d()
		if active_camera != null:
			_exit_marker.look_at(active_camera.global_position, Vector3.UP, true)
		_set_marker_scale(_exit_marker, _prediction.endpoint)


func configure(cannon: CannonController) -> void:
	_cannon = cannon
	if not _cannon.prediction_changed.is_connected(set_prediction):
		_cannon.prediction_changed.connect(set_prediction)
	if not _cannon.prediction_status_changed.is_connected(set_prediction_status):
		_cannon.prediction_status_changed.connect(set_prediction_status)
	set_prediction(_cannon.current_prediction())
	set_prediction_status(_cannon.prediction_status())


func set_prediction(prediction: TrajectoryPrediction) -> void:
	_prediction = prediction
	refresh()


func current_prediction() -> TrajectoryPrediction:
	return _prediction


func set_prediction_status(status: StringName) -> void:
	_pending = status == &"pending"
	_apply_pending_presentation()
	_update_process_enabled()


func visible_sample_count() -> int:
	return _visible_sample_count


func refresh() -> void:
	if not is_inside_tree():
		return
	var display_points := PackedVector3Array()
	if _prediction != null:
		display_points = _display_points(_prediction.sampled_points)
	_visible_sample_count = mini(display_points.size(), MAXIMUM_DOTS)
	_dot_multimesh.visible_instance_count = _visible_sample_count
	for index in range(_visible_sample_count):
		_dot_multimesh.set_instance_transform(
			index,
			Transform3D(Basis.IDENTITY, to_local(display_points[index]))
		)
	_update_dot_bounds(display_points)
	has_first_collision = _prediction != null and _prediction.kind == TrajectoryPrediction.Kind.COLLISION
	first_collision_position = _prediction.collision_contact_point() \
			if has_first_collision else Vector3.ZERO
	_impact_marker.visible = has_first_collision
	_exit_marker.visible = _prediction != null and _prediction.kind == TrajectoryPrediction.Kind.BOUNDS_EXIT
	if _prediction == null:
		_apply_pending_presentation()
		_update_process_enabled()
		return
	if has_first_collision:
		_impact_marker.global_position = _prediction.collision_contact_point()
		_impact_marker.global_basis = Basis(Quaternion(Vector3.UP, _prediction.normal))
		_set_marker_scale(_impact_marker, _prediction.collision_contact_point())
	elif _prediction.kind == TrajectoryPrediction.Kind.BOUNDS_EXIT:
		_exit_marker.global_position = _prediction.endpoint
		var active_camera := get_viewport().get_camera_3d()
		if active_camera != null:
			_exit_marker.look_at(active_camera.global_position, Vector3.UP, true)
		_set_marker_scale(_exit_marker, _prediction.endpoint)
	_apply_pending_presentation()
	_update_process_enabled()


func _display_points(source: PackedVector3Array) -> PackedVector3Array:
	if source.is_empty():
		return PackedVector3Array()
	if source.size() == 1:
		return source.duplicate()
	var total_length := 0.0
	for index in range(1, source.size()):
		total_length += source[index - 1].distance_to(source[index])
	var spacing := maxf(MINIMUM_DOT_SPACING, total_length / float(MAXIMUM_DOTS - 1))
	var result := PackedVector3Array([source[0]])
	var distance_since_sample := 0.0
	for index in range(1, source.size()):
		var segment_start := source[index - 1]
		var segment_end := source[index]
		var segment_length := segment_start.distance_to(segment_end)
		if segment_length <= 0.000001:
			continue
		var consumed := 0.0
		while distance_since_sample + segment_length - consumed >= spacing \
				and result.size() < MAXIMUM_DOTS - 1:
			var needed := spacing - distance_since_sample
			consumed += needed
			result.append(segment_start.lerp(segment_end, consumed / segment_length))
			distance_since_sample = 0.0
		distance_since_sample += segment_length - consumed
	var endpoint := source[source.size() - 1]
	if result[result.size() - 1].distance_to(endpoint) > 0.0001:
		if result.size() >= MAXIMUM_DOTS:
			result[result.size() - 1] = endpoint
		else:
			result.append(endpoint)
	return result


func _build_visuals() -> void:
	var dot_material := _unshaded_material(Color(0.08, 0.46, 1.0, 0.9))
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.18
	dot_mesh.height = 0.36
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	dot_mesh.material = dot_material
	_dot_multimesh = MultiMesh.new()
	_dot_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_dot_multimesh.mesh = dot_mesh
	_dot_multimesh.instance_count = MAXIMUM_DOTS
	_dot_multimesh.visible_instance_count = 0
	_dot_instances = MultiMeshInstance3D.new()
	_dot_instances.name = "TrajectoryDots"
	_dot_instances.multimesh = _dot_multimesh
	_dot_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dot_instances)
	var marker_mesh := TorusMesh.new()
	marker_mesh.inner_radius = 0.68
	marker_mesh.outer_radius = 1.0
	marker_mesh.rings = 16
	marker_mesh.ring_segments = 10
	marker_mesh.material = _unshaded_material(Color(0.78, 0.90, 1.0, 0.96))
	_impact_marker = MeshInstance3D.new()
	_impact_marker.name = "ImpactMarker"
	_impact_marker.mesh = marker_mesh
	_impact_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_marker.visible = false
	add_child(_impact_marker)
	_exit_marker = Node3D.new()
	_exit_marker.name = "BoundsExitMarker"
	_exit_marker.visible = false
	add_child(_exit_marker)
	var exit_material := _unshaded_material(Color(0.92, 0.16, 0.16, 0.96))
	for rotation_degrees in [-45.0, 45.0]:
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(2.4, 0.28, 0.06)
		bar_mesh.material = exit_material
		var bar := MeshInstance3D.new()
		bar.mesh = bar_mesh
		bar.rotation_degrees.z = rotation_degrees
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_exit_marker.add_child(bar)
func _apply_pending_presentation() -> void:
	if _dot_instances == null:
		return
	var fade := 0.48 if _pending else 0.0
	_dot_instances.transparency = fade
	# A prior arc can remain as subdued context, but an endpoint is a promise.
	# Hide stale collision and bounds markers until the current context publishes.
	_impact_marker.visible = not _pending and has_first_collision
	_exit_marker.visible = not _pending and _prediction != null \
			and _prediction.kind == TrajectoryPrediction.Kind.BOUNDS_EXIT


func _set_marker_scale(marker: Node3D, endpoint: Vector3) -> void:
	var active_camera := get_viewport().get_camera_3d()
	var marker_scale := clampf(active_camera.global_position.distance_to(endpoint) / 80.0, 1.0, 2.5) \
			if active_camera != null else 1.0
	marker.scale = Vector3.ONE * marker_scale


func _update_dot_bounds(points: PackedVector3Array) -> void:
	if points.is_empty():
		_dot_instances.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE * 0.01)
		return
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for index in range(mini(points.size(), MAXIMUM_DOTS)):
		var local_point := to_local(points[index])
		minimum = minimum.min(local_point)
		maximum = maximum.max(local_point)
	var radius := Vector3.ONE * 0.25
	_dot_instances.custom_aabb = AABB(minimum - radius, maximum - minimum + radius * 2.0)


func _update_process_enabled() -> void:
	set_process(
		is_visible_in_tree() and _prediction != null \
				and (_impact_marker.visible or _exit_marker.visible)
	)


func _unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	return material
