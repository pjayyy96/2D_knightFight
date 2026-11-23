extends SceneTree
## Self-check for the air dash (L / Shift): air only, once per jump, flat, refilled by landing or pogo.
## Run from the project folder:
##   godot --headless --path . --script tests/test_dash.gd
## (Scenes are load()ed: see the note in test_enemies.gd.)

var PlayerScene: PackedScene
var PlatformScript: Script

var failures := 0
var level: Node2D
var player


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	PlayerScene = load("res://scenes/player.tscn")
	PlatformScript = load("res://scripts/platform.gd")
	var dash_frames := 0 # frames one dash lasts; set once the player exists

	# 1. On the ground: no dash.
	await setup()
	dash_frames = int(player.dash_time * 60.0)
	await hold("dash", 2)
	check(player.dash_timer == 0.0, "no dash on the ground")

	# 2. In the air, while still rising: a flat burst sideways, much faster than running.
	await setup()
	await hold("jump", 6)
	await hold("dash", 2)
	var start: Vector2 = player.global_position # measured once the dash is under way
	await frames(dash_frames - 3)
	var moved: Vector2 = player.global_position - start
	check(moved.x > player.run_speed * player.dash_time, "dash goes far right (dx=%.1f)" % moved.x)
	check(absf(moved.y) < 1.0, "dash is flat (dy=%.1f)" % moved.y)
	await frames(4)
	check(player.dash_timer <= 0.0, "dash ends")
	check(absf(player.velocity.x) <= player.run_speed, "dash ends at running speed (vx=%.1f)" % player.velocity.x)

	# 3. Only one per jump.
	await hold("dash", 2)
	check(player.dash_timer <= 0.0, "no second dash in the same jump")

	# 4. A pogo gives it back.
	player.pogo()
	check(player.can_dash, "pogo refills the dash")

	# 5. Landing gives it back.
	await setup()
	await hold("jump", 3)
	await hold("dash", 2)
	check(not player.can_dash, "dash spent")
	await frames(90) # fall back down
	check(player.is_on_floor() and player.can_dash, "landing refills the dash")

	# 6. Holding left dashes left, even when facing right.
	await setup()
	await hold("jump", 6)
	Input.action_press("move_left")
	var start_x: float = player.global_position.x
	await hold("dash", 2)
	await frames(dash_frames - 2)
	Input.action_release("move_left")
	var dx: float = player.global_position.x - start_x
	check(dx < -player.run_speed * player.dash_time * 1.5, "dash left (dx=%.1f)" % dx)

	# 7. Jumping out of a dash ends it (double jump), keeping the speed.
	await setup()
	await hold("jump", 6)
	await hold("dash", 2)
	await hold("jump", 2)
	check(player.dash_timer == 0.0 and player.velocity.y < 0.0, "jump cancels the dash")
	check(player.velocity.x > player.run_speed, "dash-jump keeps the speed (vx=%.1f)" % player.velocity.x)

	print("dash tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Fresh level: a wide floor and the player standing on it.
func setup() -> void:
	if level:
		level.queue_free()
		await process_frame
	level = Node2D.new()
	root.add_child(level)
	var floor_block := StaticBody2D.new()
	floor_block.set_script(PlatformScript)
	floor_block.size = Vector2(2000, 16)
	floor_block.position = Vector2(0, 20) # top at y=12 = the player's feet
	level.add_child(floor_block)
	player = PlayerScene.instantiate()
	level.add_child(player)
	await frames(2) # let _ready() run and the player land


func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


func frames(n: int) -> void:
	for i in n:
		await physics_frame
