extends RefCounted

const GAMEPLAY_SCENE := preload("res://scenes/gameplay/gameplay.tscn")


## Instantiates gameplay from the same baked layout boundary used by AppRoot.
## Tests must not reintroduce runtime generation as a fixture shortcut.
static func instantiate(stage_id: StringName) -> Node3D:
	var stage := StageCatalog.get_stage(stage_id)
	if stage == null:
		return null
	var layout_path := StageCatalog.get_layout_path(stage.stage_id)
	if layout_path.is_empty():
		return null
	var baked := load(layout_path) as BakedStageLayoutData
	var layout := StageLayoutBakeCodec.hydrate(baked, stage)
	if layout == null:
		return null
	var gameplay := GAMEPLAY_SCENE.instantiate() as Node3D
	gameplay.call(&"prepare_stage", stage, layout)
	return gameplay
