extends Area2D
## The end of a level: walk into it and the level is beaten.
## Drop one into any level scene and set `level_id` in the Inspector, so the exit knows
## WHICH level it finishes (the world map numbers them 1, 2, 3...).
##
## Unlike the checkpoint, no key press: touching the exit is enough, so we use the
## `body_entered` signal. It only fires on entering, which is exactly "once" here.

@export var level_id := 1

var done := false # walking out and back in during the win pause must not finish twice

@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if done or not body.is_in_group("player"):
		return
	done = true
	label.text = "CLEAR!"
	GameState.finish_level(level_id) # save, short pause, back to the map
