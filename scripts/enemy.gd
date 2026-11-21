class_name Enemy # registers "Enemy" as a type name, so other scripts can write `extends Enemy`
extends Area2D
## Shared rules for everything hostile (walker, shooter, bullet). Subclasses add movement.
##  - touching the player's body kills the player
##  - a FLYING shield kills us
##  - we're in the "pogo" group, so the player can bounce on us (player.gd then calls hit())
##
## This is *inheritance*: write the common rules once here, and each enemy only adds what's
## different. A subclass can replace (override) any of these functions.


func _ready() -> void:
	add_to_group("pogo")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("shield") and area.is_flying():
		hit()


## Called when we get hit (thrown shield or pogo). Default: vanish.
## Later: drop gold (milestone 6); a boss will lose HP instead (milestone 9).
func hit() -> void:
	queue_free() # remove from the game at the end of this frame
