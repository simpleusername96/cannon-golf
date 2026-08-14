extends SceneTree


func _initialize() -> void:
	push_error("intentional bounded-wrapper failure fixture")
	await process_frame
