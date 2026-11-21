extends Enemy
## The boss: an Enemy with health, two phases and a small state machine (same idea as shield.gd).
##
##   IDLE ──(wind-up over)──▶ CHARGE ──(wall ahead)──▶ PAUSE ──▶ SHOOT ──(volley done)──▶ IDLE
##
## It charges across the arena until its WallRay sees a wall, turns around and stands dazed for
## a moment (your best chance to hit it), fires a volley back into the arena, then winds up again.
## Phase 2 (below half HP) is the same fight on fast-forward, and every other bullet flies HIGH.
##
## How to beat it (everything Enemy gives us still applies: touching it hurts, it's pogo-able):
##  - CHARGE: jump over it (it's 32 px tall, a jump is 60 px) and pogo it on the way down.
##  - PAUSE:  throw the shield at it, or pogo it.
##  - SHOOT:  jump the low bullets or block them with the held shield; stay DOWN under high ones.

signal defeated # the world map (a later milestone) listens to this to unlock the next area

enum State { IDLE, CHARGE, PAUSE, SHOOT }

const BulletScene = preload("res://scenes/bullet.tscn") # the shooter's bullet, reused as-is

@export var max_hp := 6
@export var hit_cooldown := 0.75 # seconds after a hit where more hits are ignored (see hit())
@export var charge_speed := 150.0
@export var idle_time := 1.0     # wind-up before each charge: the player's cue to get ready
@export var pause_time := 0.8    # dazed after reaching a wall: the safe moment to attack
@export var shots := 3           # bullets per volley
@export var shot_interval := 0.5
@export var rage := 1.6          # phase 2 runs this many times faster (moves AND waits)
@export var high_shot := 24.0    # phase 2: every other bullet flies this many px higher
@export var phase2_color := Color(0.95, 0.45, 0.2)

var hp := 0
var phase := 1
var state := State.IDLE
var direction := -1.0 # -1 = left, 1 = right. Starts facing left, toward the player.
var _timer := 0.0     # one countdown shared by every state that waits
var _cooldown := 0.0  # > 0 = just got hit, ignore hits and flicker
var _shots_left := 0

@onready var body: ColorRect = $Body
@onready var wall_ray: RayCast2D = $WallRay
@onready var hp_bar: ProgressBar = $HpBar


func _init() -> void:
	gold_value = 10 # a boss pays well (still editable in the Inspector)


func _ready() -> void:
	super() # Enemy._ready(): "pogo" group + touch/shield signals
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	_timer = idle_time


func _physics_process(delta: float) -> void:
	# Phase 2 = fast-forward: multiplying delta by `tempo` makes it move faster AND every
	# timer run out sooner, with one number instead of a second copy of every setting.
	var tempo := rage if phase == 2 else 1.0
	_timer -= delta * tempo

	match state:
		State.IDLE:
			if _timer <= 0.0:
				state = State.CHARGE

		State.CHARGE:
			# Look 8 px past our front edge BEFORE moving, so we stop before entering the wall.
			wall_ray.target_position.x = direction * 24.0
			wall_ray.force_raycast_update()
			# Only walls (StaticBody2D) stop us. The ray also sees the player's body,
			# but running into the player is the whole point of a charge.
			if wall_ray.get_collider() is StaticBody2D:
				direction = -direction # turn to face the arena: the player is always that way
				_start(State.PAUSE, pause_time)
			else:
				position.x += direction * charge_speed * tempo * delta

		State.PAUSE:
			if _timer <= 0.0:
				_shots_left = shots
				_start(State.SHOOT, 0.0) # 0 = first shot right away

		State.SHOOT:
			if _timer <= 0.0:
				_fire()
				_shots_left -= 1
				_timer = shot_interval
				if _shots_left == 0:
					_start(State.IDLE, idle_time)

	# Flicker while hits are ignored, so the player SEES that hitting now does nothing.
	if _cooldown > 0.0:
		_cooldown -= delta
		body.visible = int(_cooldown * 20.0) % 2 == 0
	else:
		body.visible = true


func _start(new_state: State, wait: float) -> void:
	state = new_state
	_timer = wait


func _fire() -> void:
	var bullet := BulletScene.instantiate()
	bullet.direction = direction
	# Phase 2 alternates low, HIGH, low... A low one hits a standing knight (jump or block it);
	# a high one flies over a standing knight but hits a jumping one. Read each shot!
	var high := phase == 2 and _shots_left % 2 == 0
	bullet.position = position + Vector2(direction * 20.0, -high_shot if high else 0.0)
	get_parent().add_child(bullet) # into the level, like the shooter's bullets


## Override: lose 1 HP instead of dying at once (Enemy.hit() would vanish on the first hit).
## Why the cooldown: a thrown shield enters us on the way OUT and again on the way BACK.
## A whole throw takes 140/360 + 140/420 = 0.72 s (out, then back), so the two passes are
## always less than 0.72 s apart, and 0.75 s turns one throw into one hit. (The first version
## used 0.6 s and test_boss.gd caught a close-range throw hitting twice.)
## The price: a pogo bounce (or a stomp on its head) comes back down after ~0.67 s, so on the
## same spot only every second bounce counts. You still bounce and still get mana.
func hit() -> void:
	if _cooldown > 0.0 or is_queued_for_deletion():
		return
	hp -= 1
	# A Tween animates a property over time: the bar SLIDES down to the new value in 0.4 s
	# instead of jumping, so the player sees how much that hit took off.
	create_tween().tween_property(hp_bar, "value", float(hp), 0.4)
	_cooldown = hit_cooldown
	if hp <= 0:
		defeated.emit() # tell listeners BEFORE we're gone
		super() # Enemy.hit(): pay gold_value and queue_free()
	elif phase == 1 and hp * 2 < max_hp: # below half HP
		phase = 2
		body.color = phase2_color # a visible "it's angry now" signal
