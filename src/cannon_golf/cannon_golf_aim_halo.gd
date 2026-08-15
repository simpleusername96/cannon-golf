class_name CannonGolfAimHalo
extends Node3D

## World-space aim instrument kept separate from the launcher silhouette.

const FLOAT_HEIGHT := 0.72
const RADIUS := 6.4
const RING_THICKNESS := 0.18
const ARC_RADIUS := 4.4
const ARC_LATERAL_OFFSET := 2.6
const ARC_SAMPLE_COUNT := 9
const PRESENTATION_TOP_HEIGHT := FLOAT_HEIGHT \
		+ sin(deg_to_rad(CannonGolfBallistics.MAXIMUM_ELEVATION_DEGREES)) * ARC_RADIUS \
		+ 0.35

var _elevation_degrees := 50.0
var _elevation_bead: MeshInstance3D


func _init() -> void:
	position.y = FLOAT_HEIGHT


func _ready() -> void:
	_build_visuals()
	_update_elevation_bead()


func set_angles(yaw_degrees: float, elevation_degrees: float) -> void:
	rotation_degrees.y = -yaw_degrees
	_elevation_degrees = clampf(
		elevation_degrees,
		CannonGolfBallistics.MINIMUM_ELEVATION_DEGREES,
		CannonGolfBallistics.MAXIMUM_ELEVATION_DEGREES
	)
	_update_elevation_bead()


func indicated_elevation_degrees() -> float:
	return _elevation_degrees


func presentation_radius() -> float:
	return RADIUS


func presentation_top_height() -> float:
	return PRESENTATION_TOP_HEIGHT


func _build_visuals() -> void:
	if get_node_or_null("YawRing") != null:
		return
	var guide_material := _material(Color("24354A"), 0.24, 0.62)
	var active_material := _material(Color("F2A33A"), 0.02, 0.68)

	var ring := MeshInstance3D.new()
	ring.name = "YawRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = RADIUS - RING_THICKNESS
	ring_mesh.outer_radius = RADIUS
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 8
	ring_mesh.material = guide_material
	ring.mesh = ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var yaw_tick := MeshInstance3D.new()
	yaw_tick.name = "YawTick"
	var tick_mesh := BoxMesh.new()
	tick_mesh.size = Vector3(0.78, 0.24, 1.05)
	tick_mesh.material = active_material
	yaw_tick.mesh = tick_mesh
	yaw_tick.position = Vector3(0.0, 0.08, -RADIUS + 0.52)
	yaw_tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(yaw_tick)

	var elevation_arc := Node3D.new()
	elevation_arc.name = "ElevationArc"
	add_child(elevation_arc)
	for index in range(ARC_SAMPLE_COUNT):
		var fraction := float(index) / float(ARC_SAMPLE_COUNT - 1)
		var angle := lerpf(
			CannonGolfBallistics.MINIMUM_ELEVATION_DEGREES,
			CannonGolfBallistics.MAXIMUM_ELEVATION_DEGREES,
			fraction
		)
		var dot := MeshInstance3D.new()
		dot.name = "ElevationDot%02d" % index
		var dot_mesh := SphereMesh.new()
		dot_mesh.radius = 0.13
		dot_mesh.height = 0.26
		dot_mesh.radial_segments = 8
		dot_mesh.rings = 4
		dot_mesh.material = guide_material
		dot.mesh = dot_mesh
		dot.position = _arc_position(angle)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elevation_arc.add_child(dot)

	_elevation_bead = MeshInstance3D.new()
	_elevation_bead.name = "ElevationBead"
	var bead_mesh := SphereMesh.new()
	bead_mesh.radius = 0.32
	bead_mesh.height = 0.64
	bead_mesh.radial_segments = 12
	bead_mesh.rings = 6
	bead_mesh.material = active_material
	_elevation_bead.mesh = bead_mesh
	_elevation_bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_elevation_bead)


func _update_elevation_bead() -> void:
	if _elevation_bead != null:
		_elevation_bead.position = _arc_position(_elevation_degrees)


func _arc_position(angle_degrees: float) -> Vector3:
	var angle := deg_to_rad(angle_degrees)
	return Vector3(
		ARC_LATERAL_OFFSET,
		sin(angle) * ARC_RADIUS,
		-cos(angle) * ARC_RADIUS
	)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
