extends Area2D
## The boomerang shield. A tiny "state machine": it is always in exactly one state,
## and each state has its own rules for how it moves and what ends it.
##
##   HELD ──throw()──▶ OUT ──(flew far enough / hit a wall)──▶ RETURNING ──(reached player)──▶ HELD
##
## Area2D = detects overlaps but doesn't collide physically. Perfect for hitboxes.
## `top_level = true` (set in shield.tscn) means the shield ignores the player's
## transform, so once thrown it stays where it flew instead of moving with the player.

enum State { HELD, OUT, RETURNING }

@export var throw_speed := 360.0
@export var return_speed := 420.0  # a bit faster than the throw so it always catches up
@export var max_distance := 140.0  # how far it flies before turning back
@export var hold_offset := 10.0    # where it sits next to the player while held
@export var down_offset := 18.0    # how far below the player's center it sits when held down
                                   # (below the feet, so it touches spikes/enemies before the body does)

var state := State.HELD
var player: Node2D                 # set by the player in its _ready()
var _velocity := Vector2.ZERO
var _traveled := 0.0


## Called by the player. Returns false if the shield isn't in hand.
func throw(direction: float) -> bool:
	if state != State.HELD:
		return false
	state = State.OUT
	rotation = 0.0 # stand upright again if it was held down
	_velocity = Vector2(direction * throw_speed, 0.0)
	_traveled = 0.0
	return true


func _physics_process(delta: float) -> void:
	match state:
		State.HELD:
			if player.shield_down:
				# Under the feet, turned flat (90°) like a plate.
				global_position = player.global_position + Vector2(0.0, down_offset)
				rotation = PI / 2
			else:
				# Glue it to the player's front side. `facing` is 1 (right) or -1 (left).
				global_position = player.global_position + Vector2(player.facing * hold_offset, 0.0)
				rotation = 0.0

		State.OUT:
			global_position += _velocity * delta
			_traveled += throw_speed * delta
			if _traveled >= max_distance or _touching_wall():
				state = State.RETURNING

		State.RETURNING:
			# Home in on the player's *current* position each frame (it may have moved).
			# On the way back it flies through walls, so it can never get stuck.
			global_position = global_position.move_toward(player.global_position, return_speed * delta)
			if global_position.distance_to(player.global_position) < 8.0:
				state = State.HELD


## Is the shield overlapping anything solid other than the player?
## (We ask every frame instead of using the `body_entered` signal, because that signal
## only fires on *entering* — a shield thrown while already inside a wall would miss it.)
func _touching_wall() -> bool:
	for body in get_overlapping_bodies():
		if body != player:
			return true
	return false


## Asked by the player every frame while the shield is held down.
## Anything in the "pogo" group can be bounced on: spikes now, enemies and bullets later.
## A *group* is a tag you put on nodes; this way the shield doesn't need to know what spikes are.
func touching_pogo_target() -> bool:
	if state != State.HELD:
		return false # shield is flying: nothing under your feet
	for area in get_overlapping_areas():
		if area.is_in_group("pogo"):
			return true
	return false
