@tool # draws in the editor too, like platform.gd
extends Node2D
## The start of a level: a green arch with the level's name. Place its origin ON the ground.
## Pure decoration, no collision: it only tells you "you began here".

@export var title := "START":
	set(value):
		title = value
		queue_redraw()

const GREEN := Color(0.3, 0.85, 0.4)


func _draw() -> void:
	draw_rect(Rect2(-20, -56, 4, 56), GREEN) # left post
	draw_rect(Rect2(16, -56, 4, 56), GREEN)  # right post
	draw_rect(Rect2(-24, -62, 48, 8), GREEN) # top bar
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-60, -68), "START", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, GREEN)
	draw_string(font, Vector2(-60, -82), title, HORIZONTAL_ALIGNMENT_CENTER, 120, 10)
