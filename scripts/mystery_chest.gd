extends Area2D
## A mystery chest. Stand at it on the ground and press S/↓ to open it (same key as a checkpoint).
## What's inside is random:
##   GOLD   : +gold_amount gold
##   REFILL : full HP and mana
##   MIMIC  : a charger jumps out on the far side and winds up at you. Get ready to jump!
## Risk and reward: it's usually worth it, but not always.

enum Reward { GOLD, REFILL, MIMIC }

const ChargerScene = preload("res://scenes/charger.tscn")

@export var gold_amount := 5
@export var reward := -1 # -1 = random when opened. 0/1/2 forces a reward (tests use it).

var opened := false

@onready var lid: ColorRect = $Lid
@onready var label: Label = $Label


func _physics_process(_delta: float) -> void:
	if opened:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.is_on_floor() \
				and Input.is_action_just_pressed("shield_down"):
			open(body)
			return


func open(player: Node2D) -> void:
	opened = true
	lid.color = Color(0.3, 0.25, 0.2) # dark = empty
	var pick := reward if reward >= 0 else randi() % Reward.size()
	match pick:
		Reward.GOLD:
			GameState.add_gold(gold_amount)
			label.text = "+%d gold" % gold_amount
		Reward.REFILL:
			GameState.refill()
			label.text = "full HP+mana"
		Reward.MIMIC:
			label.text = "MIMIC!"
			# Spawn on the side AWAY from the player, so it can't hurt you the moment it appears.
			var side := signf(player.global_position.x - global_position.x)
			if side == 0.0:
				side = 1.0
			var mimic := ChargerScene.instantiate()
			mimic.position = position + Vector2(-side * 24.0, 0.0)
			get_parent().add_child(mimic)
			mimic.alert_toward(player.global_position.x)
