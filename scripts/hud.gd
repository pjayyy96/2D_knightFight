extends CanvasLayer
## The status line in the top-left corner.
## A CanvasLayer draws on top of the game and ignores the camera, so the HUD stays put.
## It doesn't poll every frame. It listens to GameState.changed and redraws only then.

@onready var label: Label = $Label


func _ready() -> void:
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	label.text = "HP %d/%d    MANA %d/%d    GOLD %d" % [
		GameState.hp, GameState.MAX_HP, GameState.mana, GameState.MAX_MANA, GameState.gold]
