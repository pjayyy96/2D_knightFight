extends Area2D
## A checkpoint flag. Stand at it on the ground and press S/↓ to pay `cost` gold.
## Once lit: dying brings you back HERE, and lighting it also refills HP and mana.
##
## Why pay? It turns gold into a decision: save now and be safe, or keep the gold
## (for the shop, later) and risk replaying the section.

@export var cost := 1

var active := false

@onready var flag: ColorRect = $Flag
@onready var label: Label = $Label


func _ready() -> void:
	_refresh()


func _physics_process(_delta: float) -> void:
	if active:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.is_on_floor() \
				and Input.is_action_just_pressed("shield_down"):
			if GameState.spend_gold(cost):
				activate(body)
			else:
				label.text = "need %dg" % cost # feedback beats silence


func activate(player: Node2D) -> void:
	active = true
	# Respawn standing on the ground at the flag. We're 32 px tall and the player 24,
	# so the player's center is 4 px lower than ours.
	player.spawn_point = global_position + Vector2(0, 4)
	GameState.refill()
	_refresh()


func _refresh() -> void:
	flag.color = Color(0.3, 0.85, 0.4) if active else Color(0.45, 0.45, 0.5)
	label.text = "saved" if active else "S: save %dg" % cost
