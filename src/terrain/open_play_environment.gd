class_name OpenPlayEnvironment
extends Node3D

const NORMAL_TERRAIN_PHYSICS_MATERIAL := preload(
	"res://resources/physics/normal_terrain_physics_material.tres"
)

var play_bounds_spec: PlayBoundsSpec:
	get: return _play_bounds_spec

var _play_bounds_spec: PlayBoundsSpec
var _apron_geometry: ApronGeometry


func configure(
		spec: PlayBoundsSpec,
		terrain_world_bounds: Rect2,
		terrain_world_base_y: float
) -> void:
	assert(spec != null and spec.is_valid(), "OpenPlayEnvironment requires valid play bounds.")
	var apron_mesh := get_node_or_null("ApronMesh") as MeshInstance3D
	var apron_body := get_node_or_null("ApronBody") as StaticBody3D
	var apron_shape := get_node_or_null("ApronBody/ApronShape") as CollisionShape3D
	assert(apron_mesh != null and apron_body != null and apron_shape != null, "Apron nodes are missing.")
	_play_bounds_spec = spec
	_apron_geometry = ApronGeometryFactory.build(spec, terrain_world_bounds, terrain_world_base_y)
	apron_mesh.mesh = _apron_geometry.render_mesh
	apron_shape.shape = _apron_geometry.collision_shape
	apron_body.collision_layer = spec.collision_layer
	apron_body.collision_mask = spec.collision_mask
	apron_body.set_meta(PlayBoundsSpec.CONTACT_OWNER_META, PlayBoundsSpec.APRON_OWNER_ID)
	apron_shape.set_meta(PlayBoundsSpec.CONTACT_SHAPE_META, PlayBoundsSpec.APRON_SHAPE_ID)
	apron_body.physics_material_override = NORMAL_TERRAIN_PHYSICS_MATERIAL


func is_configured() -> bool:
	return _play_bounds_spec != null and _play_bounds_spec.is_valid() \
			and _apron_geometry != null and _apron_geometry.is_valid()


func apron_geometry_read_only() -> ApronGeometry:
	return _apron_geometry
