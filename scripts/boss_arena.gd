extends Node2D
## The boss level (world map level 3). Its exit is the boss: beat it and the level is done.
## boss.gd already announces `defeated` (milestone 9). We only listen. The boss doesn't need
## to know about maps or saving, the same way GameState doesn't know the HUD exists.

@export var level_id := 3

@onready var message: Label = $HUD/Message


func _ready() -> void:
	$Boss.defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	message.text = "VICTORY!"
	GameState.finish_level(level_id) # save, short pause, back to the map
