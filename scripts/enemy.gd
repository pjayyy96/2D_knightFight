class_name Enemy # registers "Enemy" as a type name, so other scripts can write `extends Enemy`
extends Area2D
## Shared rules for everything hostile (walker, shooter, bullet). Subclasses add movement.
##  - touching the player's body hurts the player
##  - dying pays `gold_value` gold
##  - a FLYING shield kills us
##  - we're in the "pogo" group, so the player can bounce on us (player.gd then calls hit())
##
## This is *inheritance*: write the common rules once here, and each enemy only adds what's
## different. A subclass can replace (override) any of these functions.

@export var gold_value := 1


func _ready() -> void:
	add_to_group("pogo")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


# shortcut: hurts only on *entering*; overlapping a walker after the flicker ends is safe.
# Rare (knockback separates you) — switch to a per-frame check like spikes.gd if it shows up.
func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_hit"):
		return # a wall or floor, not the player
	if _is_stomp(body):
		body.bounce_on(self, false) # landed on our head: WE get hit, the player bounces (no mana)
	else:
		body.take_hit(global_position) # ran into us: the player gets hurt


## A stomp = the player is FALLING and their center is above ours, i.e. they came down
## on top of us. From the side the centers are level (or the player is lower), so it hurts.
## Standing on the floor, velocity.y is 0, so walking into an enemy is never a stomp.
func _is_stomp(body: Node2D) -> bool:
	return body.velocity.y > 0.0 and body.global_position.y < global_position.y


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("shield") and area.is_flying():
		hit()


## Called when we get hit (thrown shield or pogo). Default: pay gold and vanish.
## (A boss will lose HP instead, milestone 9.)
func hit() -> void:
	if is_queued_for_deletion():
		return # already dying this frame (e.g. shield AND pogo at once): don't pay twice
	GameState.add_gold(gold_value)
	queue_free() # remove from the game at the end of this frame
