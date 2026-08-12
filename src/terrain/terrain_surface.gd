class_name TerrainSurface
extends Node3D

const TOP_SHAPE_ID := &"TerrainTopShape"
const SHELL_OWNER_ID := &"terrain/shell"
const SHELL_SHAPE_ID := &"TerrainShellShape"
const NORMAL_TERRAIN_PHYSICS_MATERIAL := preload(
	"res://resources/physics/normal_terrain_physics_material.tres"
)
const PRESENTATION_SUMMIT_HEADROOM := 8.0
const PRESENTATION_SUMMIT_HEIGHT_TOLERANCE := 0.25

var _layout: GeneratedStageLayout
var _geometry: TerrainGeometry
var _playable_top_world_points := PackedVector3Array()
var _presentation_world_points := PackedVector3Array()
var _visual_world_center := Vector3.ZERO


func configure(
		layout: GeneratedStageLayout,
		prepared_geometry: TerrainGeometry = null,
		prepared_playable_local_points: PackedVector3Array = PackedVector3Array(),
		prepared_presentation_local_points: PackedVector3Array = PackedVector3Array()
) -> bool:
	assert(layout != null and layout.is_valid(), "TerrainSurface requires a valid generated layout.")
	_layout = layout
	if prepared_geometry != null:
		if not prepared_geometry.is_valid() \
				or prepared_geometry.top_topology != layout.top_topology \
				or prepared_geometry.local_bounds != layout.local_bounds \
				or prepared_playable_local_points.is_empty() \
				or prepared_presentation_local_points.is_empty():
			return false
		_geometry = prepared_geometry
	else:
		_geometry = TerrainGeometryFactory.build(layout)
	_playable_top_world_points = _world_points_from_local(prepared_playable_local_points) \
			if not prepared_playable_local_points.is_empty() \
			else _build_playable_top_world_points()
	_presentation_world_points = _world_points_from_local(prepared_presentation_local_points) \
			if not prepared_presentation_local_points.is_empty() \
			else _build_presentation_world_points()
	_visual_world_center = _build_visual_world_center()
	var terrain_mesh := get_node_or_null("TerrainMesh") as MeshInstance3D
	var top_body := get_node_or_null("TerrainTopBody") as StaticBody3D
	var top_collision := get_node_or_null("TerrainTopBody/CollisionShape3D") as CollisionShape3D
	var shell_body := get_node_or_null("TerrainShellBody") as StaticBody3D
	var shell_collision := get_node_or_null("TerrainShellBody/CollisionShape3D") as CollisionShape3D
	assert(terrain_mesh != null and top_body != null and top_collision != null, "TerrainSurface top nodes are missing.")
	assert(shell_body != null and shell_collision != null, "TerrainSurface shell nodes are missing.")
	terrain_mesh.mesh = _geometry.render_mesh
	top_collision.shape = _geometry.top_shape
	top_collision.scale = Vector3.ONE
	shell_collision.shape = _geometry.skirt_shape
	top_body.set_meta(PlayBoundsSpec.CONTACT_OWNER_META, TrajectoryHitIdentity.TERRAIN_TOP_OWNER_ID)
	top_collision.set_meta(PlayBoundsSpec.CONTACT_SHAPE_META, TOP_SHAPE_ID)
	shell_body.set_meta(PlayBoundsSpec.CONTACT_OWNER_META, SHELL_OWNER_ID)
	shell_collision.set_meta(PlayBoundsSpec.CONTACT_SHAPE_META, SHELL_SHAPE_ID)
	top_body.collision_layer = 1
	top_body.collision_mask = 0
	top_body.physics_material_override = NORMAL_TERRAIN_PHYSICS_MATERIAL
	shell_body.collision_layer = 1
	shell_body.collision_mask = 0
	shell_body.physics_material_override = NORMAL_TERRAIN_PHYSICS_MATERIAL
	return true


func world_surface_point(world_xz: Vector2) -> Vector3:
	if _layout == null:
		return Vector3(world_xz.x, global_position.y, world_xz.y)
	var local_reference := to_local(Vector3(world_xz.x, global_position.y, world_xz.y))
	return to_global(Vector3(
		local_reference.x,
		_layout.height_at_local(local_reference.x, local_reference.z),
		local_reference.z
	))


func world_surface_normal(world_xz: Vector2) -> Vector3:
	if _layout == null:
		return Vector3.UP
	var local_reference := to_local(Vector3(world_xz.x, global_position.y, world_xz.y))
	return (global_transform.basis.inverse().transposed() \
			* _layout.normal_at_local(local_reference.x, local_reference.z)).normalized()


func contains_world_xz(world_xz: Vector2, margin: float = 0.0) -> bool:
	if _layout == null:
		return false
	var local_reference := to_local(Vector3(world_xz.x, global_position.y, world_xz.y))
	var local_xz := Vector2(local_reference.x, local_reference.z)
	if not _layout.local_bounds.grow(margin).has_point(local_xz):
		return false
	return not _layout.surface_sample_at_local(local_xz.x, local_xz.y, false).is_empty()


func is_top_collider(object: Object) -> bool:
	return object != null and object == get_node_or_null("TerrainTopBody")


func is_skirt_collider(object: Object) -> bool:
	return object != null and object == get_node_or_null("TerrainShellBody")


func layout_read_only() -> GeneratedStageLayout:
	return _layout


func render_world_aabb() -> AABB:
	if _geometry == null or _geometry.render_mesh == null:
		return AABB()
	return global_transform * _geometry.render_mesh.get_aabb()


## Canonical active-top vertices for exact projection checks. The packed array
## is duplicated so callers cannot mutate TerrainSurface's cached geometry.
func playable_top_world_points() -> PackedVector3Array:
	return _playable_top_world_points.duplicate()


## Cached perimeter and summit landmarks used by presentation cameras. Callers
## receive a copy and cannot mutate the accepted terrain geometry.
func presentation_world_points() -> PackedVector3Array:
	return _presentation_world_points.duplicate()


## Fixed pivot for interactive terrain inspection. It centers the visible
## mountain mass while excluding virtual framing headroom and the buried shell.
func visual_world_center() -> Vector3:
	return _visual_world_center


func _build_playable_top_world_points() -> PackedVector3Array:
	if _layout == null or _layout.top_topology == null:
		return PackedVector3Array()
	var topology := _layout.top_topology
	var seen_source_indices: Dictionary = {}
	var result := PackedVector3Array()
	for cell_z in range(_layout.cell_count.y):
		for cell_x in range(_layout.cell_count.x):
			var cell := Vector2i(cell_x, cell_z)
			if not topology.is_cell_active(cell):
				continue
			for triangle_in_cell in range(TerrainTopTopology.TRIANGLES_PER_CELL):
				var indices := topology.triangle_vertex_indices(cell, triangle_in_cell)
				for source_index in [indices.x, indices.y, indices.z]:
					if seen_source_indices.has(source_index):
						continue
					seen_source_indices[source_index] = true
					result.append(to_global(topology.vertex_at(source_index)))
	return result


func _build_presentation_world_points() -> PackedVector3Array:
	if _layout == null or _geometry == null or _geometry.render_mesh == null:
		return PackedVector3Array()
	var result := PackedVector3Array()
	for local_point in local_presentation_points(_layout, _geometry.render_mesh.get_aabb()):
		result.append(to_global(local_point))
	return result


func _build_visual_world_center() -> Vector3:
	if _playable_top_world_points.is_empty():
		return global_position
	var visible_bounds := AABB(_playable_top_world_points[0], Vector3.ZERO)
	for point_index in range(1, _playable_top_world_points.size()):
		visible_bounds = visible_bounds.expand(_playable_top_world_points[point_index])
	var visible_base_y := global_position.y
	if _geometry != null and _geometry.render_mesh != null:
		var local_base_y := maxf(_geometry.render_mesh.get_aabb().position.y, 0.0)
		visible_base_y = to_global(Vector3(0.0, local_base_y, 0.0)).y
	visible_bounds = visible_bounds.expand(Vector3(
		visible_bounds.position.x,
		visible_base_y,
		visible_bounds.position.z
	))
	visible_bounds = visible_bounds.expand(Vector3(
		visible_bounds.end.x,
		visible_base_y,
		visible_bounds.end.z
	))
	return visible_bounds.get_center()


func _world_points_from_local(local_points: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(local_points.size())
	for index in range(local_points.size()):
		result[index] = to_global(local_points[index])
	return result


## View-independent presentation landmarks: the real top/base perimeter plus
## authored summit landmarks. Interior vertices do not describe a silhouette
## and would make framing reserve empty projected space behind the mountain.
static func local_presentation_points(layout: GeneratedStageLayout, render_bounds: AABB) -> PackedVector3Array:
	var result := PackedVector3Array()
	if layout == null or layout.top_topology == null or not render_bounds.has_volume():
		return result
	var topology := layout.top_topology
	# The open-play apron meets the terrain at local Y=0 and hides the authored
	# shell/bottom below it. Frame the visible base intersection, not the buried
	# -28 m support geometry.
	var visible_base_y := maxf(render_bounds.position.y, 0.0)
	var boundary_indices := topology.boundary_edges_read_only()
	var seen_boundary_indices: Dictionary = {}
	for source_index in boundary_indices:
		if seen_boundary_indices.has(source_index):
			continue
		seen_boundary_indices[source_index] = true
		var boundary_point := topology.vertex_at(source_index)
		result.append(boundary_point)
		result.append(Vector3(boundary_point.x, visible_base_y, boundary_point.z))
	for summit in layout.summit_region(PRESENTATION_SUMMIT_HEIGHT_TOLERANCE):
		var summit_point := summit.point as Vector3
		result.append(summit_point)
		result.append(summit_point + Vector3.UP * PRESENTATION_SUMMIT_HEADROOM)
	return result


func classify_top_hit(
		world_point: Vector3,
		predicted_world_normal: Vector3,
		shape_id: StringName = TOP_SHAPE_ID,
		body_shape_index: int = 0
) -> TrajectoryHitIdentity:
	if _layout == null or _layout.top_topology == null:
		return null
	var local_point := to_local(world_point)
	var local_normal := (global_transform.basis.transposed() * predicted_world_normal).normalized()
	var sample := _layout.top_topology.classify_local_hit(local_point, local_normal)
	if sample.is_empty():
		return null
	return TrajectoryHitIdentity.terrain_top(
		shape_id,
		body_shape_index,
		sample.cell,
		sample.triangle,
		sample.barycentric
	)


func classify_top_physics_hit(
		world_point: Vector3,
		shape_id: StringName = TOP_SHAPE_ID,
		body_shape_index: int = 0
) -> TrajectoryHitIdentity:
	# RigidBody contact manifolds at a shared faceted edge can report a blended
	# normal that is not the authored triangle normal. The top collider metadata
	# already proves the owner/shape; classify the canonical triangle from the
	# measured contact XZ and retain only the authoritative height check.
	if _layout == null or _layout.top_topology == null:
		return null
	var local_point := to_local(world_point)
	var sample := _layout.top_topology.surface_sample_at_local(local_point.x, local_point.z, false)
	if sample.is_empty() or absf(float(sample.point.y) - local_point.y) \
			> TerrainTopTopology.HIT_HEIGHT_TOLERANCE:
		return null
	return TrajectoryHitIdentity.terrain_top(
		shape_id,
		body_shape_index,
		sample.cell,
		int(sample.triangle),
		sample.barycentric
	)


static func classify_top_cell_uv(
		shape_id: StringName,
		body_shape_index: int,
		cell: Vector2i,
		local_uv: Vector2
) -> TrajectoryHitIdentity:
	if cell.x < 0 or cell.y < 0:
		return null
	var address := TerrainTopTopology.triangle_barycentric_for_cell_uv(local_uv)
	if address.x < 0.0:
		return null
	return TrajectoryHitIdentity.terrain_top(
		shape_id,
		body_shape_index,
		cell,
		int(address.x),
		Vector3(address.y, address.z, address.w)
	)
