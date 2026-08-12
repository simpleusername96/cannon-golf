class_name EnvironmentDressing
extends Node3D

const MODEL_PATHS := {
	&"tree_pineSmallA": "res://assets/nature/kenney/tree_pineSmallA.glb",
	&"tree_pineSmallB": "res://assets/nature/kenney/tree_pineSmallB.glb",
	&"tree_pineTallA": "res://assets/nature/kenney/tree_pineTallA.glb",
	&"rock_smallA": "res://assets/nature/kenney/rock_smallA.glb",
	&"rock_largeA": "res://assets/nature/kenney/rock_largeA.glb",
}

var _stage_data: StageData
var _generated_layout: GeneratedStageLayout


func configure(
		stage_data: StageData,
		generated_layout: GeneratedStageLayout = null,
		prepared_placements: Array[DecorationPlacement] = [],
		prepared_scenes: Dictionary = {}
) -> void:
	_stage_data = stage_data
	_generated_layout = generated_layout
	for child in get_children():
		child.queue_free()
	var placements := prepared_placements \
			if not prepared_placements.is_empty() else _generated_layout.decoration_placements
	for placement in placements:
		_add_decoration(placement, prepared_scenes.get(placement.model_id) as PackedScene)


func _add_decoration(placement: DecorationPlacement, prepared_scene: PackedScene = null) -> void:
	var packed_scene := prepared_scene
	if packed_scene == null:
		packed_scene = load(model_path_for(placement.model_id)) as PackedScene
	assert(packed_scene != null, "Approved decoration model must import as a PackedScene.")
	var decoration := packed_scene.instantiate() as Node3D
	decoration.name = String(placement.model_id)
	var height := _height_at(placement.local_xz.x, placement.local_xz.y)
	decoration.position = Vector3(
		_stage_data.terrain_center.x + placement.local_xz.x,
		_stage_data.terrain_center.y + height,
		_stage_data.terrain_center.z + placement.local_xz.y
	)
	decoration.rotation.y = deg_to_rad(placement.yaw_degrees)
	decoration.scale = Vector3.ONE * placement.uniform_scale
	_apply_muted_material(decoration, String(placement.model_id).begins_with("tree_"))
	add_child(decoration)


static func model_path_for(model_id: StringName) -> String:
	return String(MODEL_PATHS.get(model_id, ""))


func _apply_muted_material(node: Node, is_tree: bool) -> void:
	var material := _material(Color("40566a") if is_tree else Color("9aa0a8"), 0.94)
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material
		_apply_muted_material(child, is_tree)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result


func _height_at(local_x: float, local_z: float) -> float:
	assert(_generated_layout != null, "Environment dressing requires the accepted generated layout.")
	return _generated_layout.height_at_local(local_x, local_z)
