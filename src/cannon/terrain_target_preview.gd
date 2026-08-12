class_name TerrainTargetPreview
extends Node3D

## Stateless world presentation for the target owned by TerrainAimController.
## The controller supplies the surface pose and semantic state; this node never
## decides whether a target or prediction is current.
const STATE_HIDDEN := &"hidden"
const STATE_SELECTED := &"selected"
const STATE_PENDING := &"pending"
const STATE_CONFIRMED := &"confirmed"
const STATE_REJECTED := &"rejected"

const SURFACE_OFFSET := 0.06
const BASE_DISTANCE := 80.0
const MINIMUM_SCALE := 0.85
const MAXIMUM_SCALE := 2.5
const TARGET_BLUE := Color(0.08, 0.46, 1.0, 0.96)
const TARGET_BLUE_SUBDUED := Color(0.34, 0.66, 1.0, 0.84)

var _visual_state: StringName = STATE_HIDDEN
var _surface_point := Vector3.ZERO
var _surface_normal := Vector3.UP
var _ring: MeshInstance3D
var _pending_ticks: Node3D
var _confirmed_center: MeshInstance3D
var _rejected_x: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_build_visuals()
	visibility_changed.connect(_update_process_enabled)
	_apply_visual_state()
	_update_process_enabled()


func _process(_delta: float) -> void:
	_update_camera_scale()


func present_target(
		world_point: Vector3,
		world_normal: Vector3,
		state: StringName = STATE_SELECTED
) -> void:
	if not world_point.is_finite() or not world_normal.is_finite() \
			or world_normal.length_squared() <= 0.000001 or not _is_known_state(state):
		clear_target()
		return
	_surface_point = world_point
	_surface_normal = world_normal.normalized()
	_visual_state = state
	global_position = _surface_point + _surface_normal * SURFACE_OFFSET
	global_basis = Basis(Quaternion(Vector3.UP, _surface_normal))
	_apply_visual_state()
	_update_camera_scale()
	_update_process_enabled()


func set_visual_state(state: StringName) -> void:
	if not _is_known_state(state):
		return
	_visual_state = state
	_apply_visual_state()
	_update_process_enabled()


func clear_target() -> void:
	_visual_state = STATE_HIDDEN
	_apply_visual_state()
	_update_process_enabled()


func visual_state() -> StringName:
	return _visual_state


func surface_point() -> Vector3:
	return _surface_point


func surface_normal() -> Vector3:
	return _surface_normal


func _build_visuals() -> void:
	var primary_material := _unshaded_material(TARGET_BLUE)
	var subdued_material := _unshaded_material(TARGET_BLUE_SUBDUED)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.02
	ring_mesh.outer_radius = 1.24
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 10
	ring_mesh.material = primary_material
	_ring = _mesh_instance("SelectedRing", ring_mesh)
	add_child(_ring)

	_pending_ticks = Node3D.new()
	_pending_ticks.name = "PendingTicks"
	add_child(_pending_ticks)
	for tick_index in range(4):
		var tick_mesh := BoxMesh.new()
		tick_mesh.size = Vector3(0.44, 0.055, 0.13)
		tick_mesh.material = subdued_material
		var tick := _mesh_instance("Tick%d" % tick_index, tick_mesh)
		var angle := float(tick_index) * PI * 0.5
		tick.position = Vector3(cos(angle), 0.0, sin(angle)) * 0.76
		tick.rotation.y = -angle
		_pending_ticks.add_child(tick)

	var center_mesh := CylinderMesh.new()
	center_mesh.top_radius = 0.24
	center_mesh.bottom_radius = 0.24
	center_mesh.height = 0.065
	center_mesh.radial_segments = 16
	center_mesh.material = primary_material
	_confirmed_center = _mesh_instance("ConfirmedCenter", center_mesh)
	add_child(_confirmed_center)

	_rejected_x = Node3D.new()
	_rejected_x.name = "RejectedX"
	add_child(_rejected_x)
	for x_index in range(2):
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(1.45, 0.065, 0.16)
		bar_mesh.material = primary_material
		var bar := _mesh_instance("Bar%d" % x_index, bar_mesh)
		bar.rotation.y = deg_to_rad(-45.0 if x_index == 0 else 45.0)
		_rejected_x.add_child(bar)


func _apply_visual_state() -> void:
	if _ring == null:
		return
	visible = _visual_state != STATE_HIDDEN
	_ring.visible = visible
	_pending_ticks.visible = _visual_state == STATE_PENDING
	_confirmed_center.visible = _visual_state == STATE_CONFIRMED
	_rejected_x.visible = _visual_state == STATE_REJECTED


func _update_camera_scale() -> void:
	if not visible or not is_inside_tree():
		return
	var active_camera := get_viewport().get_camera_3d()
	var marker_scale := clampf(
		active_camera.global_position.distance_to(_surface_point) / BASE_DISTANCE,
		MINIMUM_SCALE,
		MAXIMUM_SCALE
	) if active_camera != null else 1.0
	scale = Vector3.ONE * marker_scale


func _update_process_enabled() -> void:
	set_process(is_visible_in_tree() and _visual_state != STATE_HIDDEN)


func _is_known_state(state: StringName) -> bool:
	return state == STATE_HIDDEN or state == STATE_SELECTED or state == STATE_PENDING \
			or state == STATE_CONFIRMED or state == STATE_REJECTED


func _mesh_instance(instance_name: String, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = instance_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	return material
