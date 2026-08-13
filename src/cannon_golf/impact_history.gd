class_name CannonGolfImpactHistory
extends Node3D

const MAXIMUM_MARKS := 5

var _marks: Array[MeshInstance3D] = []


func clear() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()


func stamp(world_position: Vector3, world_normal: Vector3) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "ImpactMark%02d" % (_marks.size() + 1)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.86
	mesh.bottom_radius = 1.02
	mesh.height = 0.045
	mesh.radial_segments = 18
	mark.mesh = mesh
	mark.global_transform = Transform3D(
		Basis(Quaternion(Vector3.UP, world_normal.normalized())),
		world_position + world_normal.normalized() * 0.035
	)
	add_child(mark)
	_marks.append(mark)
	if _marks.size() > MAXIMUM_MARKS:
		var oldest: MeshInstance3D = _marks.pop_front()
		oldest.queue_free()
	_refresh_materials()


func count() -> int:
	return _marks.size()


func oldest_color() -> Color:
	return _mark_color(_marks.front()) if not _marks.is_empty() else Color.TRANSPARENT


func newest_color() -> Color:
	return _mark_color(_marks.back()) if not _marks.is_empty() else Color.TRANSPARENT


func newest_position() -> Vector3:
	return _marks.back().global_position if not _marks.is_empty() else Vector3.INF


func mark_instance_ids() -> PackedInt64Array:
	var identities := PackedInt64Array()
	for mark in _marks:
		identities.append(mark.get_instance_id())
	return identities


func _refresh_materials() -> void:
	var mark_count := _marks.size()
	for index in range(mark_count):
		var age := mark_count - 1 - index
		var fade := clampf(float(age) / float(MAXIMUM_MARKS), 0.0, 0.76)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("13243A").lerp(Color("D9D5CB"), fade)
		material.roughness = 0.82
		_marks[index].material_override = material


func _mark_color(mark: MeshInstance3D) -> Color:
	var material := mark.material_override as StandardMaterial3D
	return material.albedo_color if material != null else Color.TRANSPARENT
