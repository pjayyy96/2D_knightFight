extends Area2D
## The end of a level: walk into it and the level is beaten.
## Drop one into any level scene and set `level_id` in the Inspector, so the exit knows
## WHICH level it finishes (the world map numbers them 1, 2, 3...).
##
## Unlike the checkpoint, no key press: touching the exit is enough, so we use the
## `body_entered` signal. It only fires on entering, which is exactly "once" here.

@export var level_id := 1

var done := false # walking out and back in during the win pause must not finish twice

## 0..1, how bright the beam of light above the gate is. A tween pulses it, so the exit
## catches your eye from far away. The setter redraws whenever the tween changes it.
var glow := 0.3:
	set(value):
		glow = value
		queue_redraw()

@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween := create_tween().set_loops() # repeat forever (until the exit is freed)
	tween.tween_property(self, "glow", 1.0, 0.8)
	tween.tween_property(self, "glow", 0.3, 0.8)


## Drawn BEHIND the child nodes (Gate, Label): a light beam up into the sky and a golden arch.
func _draw() -> void:
	var gold := Color(0.95, 0.8, 0.3)
	draw_rect(Rect2(-14, -400, 28, 370), Color(gold, 0.25 * glow)) # the beam
	draw_rect(Rect2(-20, -30, 4, 54), gold) # left post
	draw_rect(Rect2(16, -30, 4, 54), gold)  # right post
	draw_rect(Rect2(-24, -36, 48, 8), gold.lerp(Color.WHITE, glow * 0.5)) # top bar, pulsing


func _on_body_entered(body: Node2D) -> void:
	if done or not body.is_in_group("player"):
		return
	done = true
	label.text = "CLEAR!"
	GameState.finish_level(level_id) # save, short pause, back to the map
