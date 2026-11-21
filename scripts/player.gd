extends CharacterBody2D
## The knight. Milestone 1: run, jump, gravity — with the two tricks that make
## platformers feel fair: coyote time and jump buffering.
##
## Units: pixels and seconds. Velocity is px/s, gravity is px/s². +Y points DOWN in Godot.

@export_group("Running")
@export var run_speed := 140.0   # top horizontal speed
@export var acceleration := 1200.0 # how fast we reach top speed (higher = snappier)
@export var friction := 1600.0     # how fast we stop when no key is held

@export_group("Jumping")
@export var gravity := 900.0
@export var jump_velocity := -330.0 # negative = up
@export var max_fall_speed := 400.0
@export var jump_cut := 0.5         # release jump early -> keep only this fraction of upward speed
@export var coyote_time := 0.1      # seconds you may still jump after walking off a ledge
@export var jump_buffer := 0.1      # seconds a jump press is "remembered" before landing
@export var air_jumps := 1          # extra jumps allowed in the air (1 = double jump)
@export var pogo_velocity := -300.0 # bounce speed when the downward shield hits something

@export_group("Combat")
@export var throw_cost := 1          # mana per throw
@export var pogo_kill_mana := 1      # mana back for each enemy you pogo
@export var invincible_time := 1.0   # seconds of safety after a hit (you flicker)
@export var knockback := Vector2(160, -220) # pushed away and up when hit
@export var heal_cost := 2           # mana per heal (two throws' worth: healing is a real choice)
@export var heal_time := 0.8         # seconds K must be held, standing still, for +1 HP
@export var heal_color := Color(0.35, 0.95, 0.5) # the body fades to this while charging

@export_group("Sliding")
@export var slide_speed := 280.0     # top speed riding the shield down a slope (2× running)
@export var slide_accel := 600.0     # how fast a slide picks up speed
@export var momentum_drag := 150.0   # how slowly leftover slide speed fades (lower = longer jumps)

signal hurt # emitted by take_hit() when it actually hurts
signal died # emitted by die(); checkpoints (milestone 7) will listen to it

var invincible_timer := 0.0
var heal_timer := 0.0 # how long the current heal has been charging (0 = not charging)

var air_jumps_left := 0
var shield_down := false # true while airborne + holding S/↓ (or sliding). The shield reads this.
var sliding := false     # on a slope + holding S/↓
var coyote_timer := 0.0
var buffer_timer := 0.0
var spawn_point := Vector2.ZERO
var facing := 1.0 # 1 = right, -1 = left. The shield reads this.

@onready var shield := $Shield # `@onready` = look the child up once the scene is ready
@onready var body_color: Color = $Body.color # the normal color, to fade back to after healing


func _ready() -> void:
	add_to_group("player") # so checkpoints can recognise us
	spawn_point = global_position # checkpoints overwrite this
	shield.player = self # the shield needs to know who to follow and fly back to
	# Going DOWN a slope fast, we'd move sideways faster than gravity pulls us down and
	# "fly off" the surface every frame. Snapping pulls us back onto the floor if it's
	# within 6 px. (Not while jumping: Godot never snaps when velocity points up.)
	floor_snap_length = 6.0


func _physics_process(delta: float) -> void:
	# 1. Gravity: only while in the air, capped so falls stay readable.
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	# 2. Coyote time: refill while grounded, count down while airborne.
	#    Touching the floor also gives back the air jumps.
	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_left = air_jumps
	else:
		coyote_timer -= delta

	# 3. Jump buffer: a press starts the timer; it counts down every frame after.
	if Input.is_action_just_pressed("jump"):
		buffer_timer = jump_buffer
	else:
		buffer_timer -= delta

	# 4. Jump if BOTH "recently pressed" and "recently on the floor".
	#    This is why a slightly-early or slightly-late press still works.
	if buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		buffer_timer = 0.0
		coyote_timer = 0.0 # can't use the same coyote window twice
	# 4b. Air jump: no floor and no coyote left, so a fresh press spends one air jump.
	#     (`elif` matters: a ground/coyote jump must NOT also eat the air jump.)
	elif Input.is_action_just_pressed("jump") and air_jumps_left > 0:
		velocity.y = jump_velocity
		air_jumps_left -= 1
		buffer_timer = 0.0

	# 5. Variable jump height: letting go early cuts the rise short.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	# 6. Horizontal movement: slide, coast, or run.
	var dir := Input.get_axis("move_left", "move_right") # -1, 0 or 1
	# The floor normal is the arrow pointing straight out of the ground. On flat ground it's
	# (0, -1). On a slope it leans toward the DOWNHILL side, so its x tells us which way that is.
	var normal := get_floor_normal()
	sliding = is_on_floor() and absf(normal.x) > 0.1 and Input.is_action_pressed("shield_down")
	if sliding:
		# 6a. Ride the shield downhill, speeding up to slide_speed. Left/right are ignored.
		var downhill := signf(normal.x)
		facing = downhill
		velocity.x = move_toward(velocity.x, downhill * slide_speed, slide_accel * delta)
	elif absf(velocity.x) > run_speed and signf(velocity.x) != -dir:
		# 6b. Faster than we can run (leftover slide speed) and not braking: keep it,
		#     fading only slowly. Jump now and that speed becomes a long jump.
		velocity.x = move_toward(velocity.x, signf(velocity.x) * run_speed, momentum_drag * delta)
	elif dir != 0.0:
		# 6c. Normal running: ease toward target speed instead of snapping to it.
		facing = signf(dir)
		velocity.x = move_toward(velocity.x, dir * run_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# 7. Pogo, BEFORE moving. The shield sits below our feet, so it reaches spikes first.
	#    Bouncing now (before this frame's move) means the body never gets there.
	#    Only while falling, otherwise rising out of a bounce would re-trigger it.
	#    Whatever we bounced on gets hit too (enemies die, bullets pop; spikes have no hit()).
	#    Sliding counts as shield-down too, so you can slide over spikes and enemies.
	shield_down = (not is_on_floor() and Input.is_action_pressed("shield_down")) or sliding
	if shield_down and velocity.y > 0.0:
		var target: Area2D = shield.pogo_target()
		if target:
			bounce_on(target)

	# 8. Let Godot move us and resolve collisions (also updates is_on_floor()).
	move_and_slide()

	# 9. Throw the shield the way we face, if it's in hand AND we can pay the mana.
	#    (Order matters: check the hand first, or we'd pay for a throw that can't happen.)
	if Input.is_action_just_pressed("throw") and not shield.is_flying():
		if GameState.spend_mana(throw_cost):
			shield.throw(facing)

	# 9b. Heal: hold K, standing still on the ground, with HP to gain and mana to pay.
	#     The charge is the price: for heal_time you can't move, jump or attack, so you
	#     heal in a quiet moment, not in the middle of a fight. Break ANY condition (move,
	#     jump, let go of K, get hit) and the charge starts over from zero.
	#     Keep holding and it heals again every heal_time, until HP is full or mana runs out.
	var can_heal := is_on_floor() and dir == 0.0 and not sliding 			and GameState.hp < GameState.MAX_HP and GameState.mana >= heal_cost
	if can_heal and Input.is_action_pressed("heal"):
		heal_timer += delta
		if heal_timer >= heal_time:
			heal_timer = 0.0
			GameState.spend_mana(heal_cost) # can't fail: can_heal checked the mana
			GameState.heal(1)
	else:
		heal_timer = 0.0
	# lerp = "blend": 0 → normal color, 1 → fully green. The player SEES the charge build up.
	$Body.color = body_color.lerp(heal_color, heal_timer / heal_time)

	# 10. Invincibility after a hit: count down and flicker (visible on/off ~10×/s).
	if invincible_timer > 0.0:
		invincible_timer -= delta
		$Body.visible = int(invincible_timer * 20.0) % 2 == 0
	else:
		$Body.visible = true

	# Fell into a pit.
	if position.y > 600.0:
		die()


## Bounce off `target` and hit it. Used by BOTH ways of landing on things:
##  - pogo (shield held down, step 7), and
##  - stomp (landing on an enemy's head with your body; enemy.gd calls this with give_mana=false).
## Enemies die (a boss loses 1 HP), bullets pop, spikes just bounce you (they have no hit()).
## Only the SHIELD pogo refuels: stomping is the easy move, the pogo is the skilled one that pays.
func bounce_on(target: Node, give_mana := true) -> void:
	pogo()
	if target.has_method("hit"):
		target.hit()
		if give_mana:
			GameState.add_mana(pogo_kill_mana) # the core loop: fight in the air to refuel


## The bounce itself.
## The bounce also gives back the air jumps, so you can chain: bounce → double jump → bounce...
func pogo() -> void:
	velocity.y = pogo_velocity
	air_jumps_left = air_jumps


## Called by enemies, bullets and spikes when they touch our body.
## `from` = where the hit came from, so we get knocked AWAY from it.
func take_hit(from: Vector2) -> void:
	if invincible_timer > 0.0:
		return # still flickering from the last hit: ignore
	hurt.emit()
	heal_timer = 0.0 # a hit interrupts a heal
	if GameState.take_damage(1):
		die()
		return
	invincible_timer = invincible_time
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * knockback.x, knockback.y)


## Back to the last checkpoint (or the start) with full health and mana; gold is kept.
func die() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	invincible_timer = 0.0
	GameState.refill()
	died.emit()
