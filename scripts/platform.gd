@tool # runs in the editor too, so you see the rectangle while building levels
extends StaticBody2D
## A solid block. Change `size` in the Inspector; the look and the collision both follow.
## StaticBody2D = a physics body that never moves but others collide with it.

@export var size := Vector2(64, 16):
	set(value):
		size = value
		queue_redraw() # ask Godot to call _draw() again with the new size

@export var color := Color(0.4, 0.35, 0.3)


func _ready() -> void:
	# The editor shows a warning "no CollisionShape2D" — ignore it, we add one here at runtime.
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	# The node's origin is the CENTER of the block, same as RectangleShape2D.
	draw_rect(Rect2(-size / 2, size), color)
