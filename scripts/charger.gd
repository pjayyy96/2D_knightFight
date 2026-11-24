extends "res://scripts/enemy_walker.gd"
## A walker with a temper: a STATE MACHINE with four states.
##   PATROL  : walk like a walker. See the player close and level with us -> ALERT
##   ALERT   : stop and flash (the "tell": your warning to get ready) -> CHARGE
##   CHARGE  : rush ahead at high speed until a wall, a ledge or the time runs out -> STUNNED
##   STUNNED : stand dazed (grey). Your window to hit it safely -> PATROL
## Only ONE state is active at a time, and each state only decides "what now" and "what next".
## `extends` a file path: the walker has no class_name, and we reuse all its patrol code.

enum State { PATROL, ALERT, CHARGE, STUNNED }

const COLORS := {
	State.PATROL: Color(0.85, 0.45, 0.2),
	State.ALERT: Color(1, 0.9, 0.3),
	State.CHARGE: Color(1, 0.15, 0.15),
	State.STUNNED: Color(0.5, 0.5, 0.55),
}

@export var sight_range := 110.0 # px left or right
@export var alert_time := 0.5
@export var charge_speed := 220.0
@export var charge_time := 1.0
@export var stun_time := 0.8

var state := State.PATROL
var timer := 0.0 # time left in the current state (ALERT, CHARGE, STUNNED)

@onready var body: ColorRect = $Body


func _ready() -> void:
	super()
	enter(State.PATROL)


func _physics_process(delta: float) -> void:
	timer -= delta
	match state:
		State.PATROL:
			super(delta) # the walker's patrol: walk, turn at walls and ledges
			var player := _player_in_sight()
			if player:
				alert_toward(player.global_position.x)
		State.ALERT:
			# Flicker between alert and normal ~10x/s, so the tell is hard to miss.
			body.color = COLORS[State.ALERT] if int(timer * 20.0) % 2 == 0 else COLORS[State.PATROL]
			if timer <= 0.0:
				enter(State.CHARGE)
		State.CHARGE:
			_aim_rays()
			if wall_ray.get_collider() is StaticBody2D or not floor_ray.is_colliding() or timer <= 0.0:
				enter(State.STUNNED) # never runs off a ledge: a charge you can bait into a wall
			else:
				position.x += direction * charge_speed * delta
		State.STUNNED:
			if timer <= 0.0:
				enter(State.PATROL)


## Switch state. Every state change goes through here, so the timer and color are always set.
func enter(next: State) -> void:
	state = next
	timer = {State.ALERT: alert_time, State.CHARGE: charge_time, State.STUNNED: stun_time}.get(next, 0.0)
	body.color = COLORS[next]


## Face x and start the wind-up. Also used by the mystery chest's mimic.
func alert_toward(x: float) -> void:
	if x != global_position.x:
		direction = signf(x - global_position.x)
	enter(State.ALERT)


func _player_in_sight() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var d := player.global_position - global_position
	return player if absf(d.x) < sight_range and absf(d.y) < 24.0 else null
