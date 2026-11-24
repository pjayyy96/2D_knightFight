extends Enemy
## A bat. Floats through walls (it's an Area2D: nothing blocks it). A state machine again:
##   HOVER  : bob up and down at home. Player close (and rested) -> WINDUP
##   WINDUP : shiver in place and remember where the player IS now -> SWOOP
##   SWOOP  : dive straight at that remembered spot. Move away during the wind-up and it misses.
##   RETURN : fly slowly back home (an easy stomp/pogo target), rest, -> HOVER

enum State { HOVER, WINDUP, SWOOP, RETURN }

@export var sight_range := 130.0
@export var windup_time := 0.4
@export var swoop_speed := 170.0
@export var return_speed := 70.0
@export var rest_time := 1.2 # after a swoop, hover this long before the next one

var state := State.HOVER
var home := Vector2.ZERO
var target := Vector2.ZERO
var timer := 0.0
var rest := 0.0
var bob := 0.0 # time since we started hovering, for the sine wave

@onready var body: ColorRect = $Body


func _ready() -> void:
	super()
	home = global_position


func _physics_process(delta: float) -> void:
	timer -= delta
	rest -= delta
	match state:
		State.HOVER:
			bob += delta
			global_position = home + Vector2(0, sin(bob * 3.0) * 6.0)
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player and rest <= 0.0 and global_position.distance_to(player.global_position) < sight_range:
				target = player.global_position
				state = State.WINDUP
				timer = windup_time
		State.WINDUP:
			body.position.x = -7.0 + (1.0 if int(timer * 30.0) % 2 == 0 else -1.0) # shiver
			if timer <= 0.0:
				body.position.x = -7.0
				state = State.SWOOP
		State.SWOOP:
			global_position = global_position.move_toward(target, swoop_speed * delta)
			if global_position == target:
				state = State.RETURN
		State.RETURN:
			global_position = global_position.move_toward(home, return_speed * delta)
			if global_position == home:
				state = State.HOVER
				rest = rest_time
				bob = 0.0 # start the bob at home, not with a jump
