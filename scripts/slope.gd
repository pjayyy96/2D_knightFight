@tool # draws in the editor too, like platform.gd
extends StaticBody2D
## A ramp (a solid right triangle). Like platform.gd, the node's origin is the CENTER of
## its `size` box. `descends_right` picks the downhill side.
## Hold S/↓ on it to slide down on your shield.
## Keep it under 45° (height < width): steeper than that, Godot treats it as a WALL, not a floor.

@export var size := Vector2(160, 60):
	set(value):
		size = value
		queue_redraw()

@export var descends_right := true:
	set(value):
		descends_right = value
		queue_redraw()

@export var color := Color(0.4, 0.35, 0.3)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var collision := CollisionPolygon2D.new()
	collision.polygon = _points()
	add_child(collision)


func _draw() -> void:
	draw_colored_polygon(_points(), color)


## The triangle's 3 corners: the high top corner, plus both bottom corners.
func _points() -> PackedVector2Array:
	var half := size / 2
	var top := Vector2(-half.x if descends_right else half.x, -half.y)
	return PackedVector2Array([top, Vector2(half.x, half.y), Vector2(-half.x, half.y)])
