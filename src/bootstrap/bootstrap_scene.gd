extends Node3D

@onready var _camera: Camera3D = %Camera
@onready var _mountain_mesh: MeshInstance3D = %MountainMesh
@onready var _mountain_collision: CollisionShape3D = %MountainCollision


func _ready() -> void:
	var mountain := BootstrapMountainMeshFactory.build()
	_mountain_mesh.mesh = mountain
	_mountain_collision.shape = mountain.create_trimesh_shape()
	_camera.look_at(Vector3(0.0, 16.0, -83.0), Vector3.UP)
	print("Paint Mountain bootstrap scene ready.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()
