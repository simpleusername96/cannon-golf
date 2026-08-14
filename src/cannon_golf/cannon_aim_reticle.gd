class_name CannonGolfAimReticle
extends Control

const INK := Color("13243A")
const AMBER := Color("F2A33A")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 3.0, AMBER)
	var directions: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for direction: Vector2 in directions:
		var tangent: Vector2 = direction.orthogonal()
		var tip := center + direction * 22.0
		var back := center + direction * 13.0
		draw_polyline(PackedVector2Array([
			back + tangent * 5.0, tip, back - tangent * 5.0
		]), INK, 2.5, true)
