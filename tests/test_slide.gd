extends SceneTree
## Self-check for sliding down slopes and carrying the speed into a long jump.
## Run from the project folder:
##   godot --headless --path . --script tests/test_slide.gd
## (Scenes are load()ed at runtime; see the note in test_enemies.gd.)

var failures := 0
var level: Node2D
var player


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame

	# 1. Standing on a slope without input: you don't slip down.
	await setup()
	var x0: float = player.global_position.x
	await frames(30)
	check(absf(player.global_position.x - x0) < 2.0, "idle on a slope: stays put")

	# 2. Hold S: slide downhill, much faster than running.
	await setup()
	Input.action_press("shield_down")
	var top_speed := 0.0
	var slid := false
	for i in 60:
		await physics_frame
		top_speed = maxf(top_speed, player.velocity.x)
		slid = slid or player.sliding
	Input.action_release("shield_down")
	check(slid, "holding S on a slope = sliding")
	check(top_speed > 200.0, "slide reaches > 200 px/s (got %d)" % top_speed)

	# 3. Off the slope: the speed fades slowly, and a jump keeps it in the air.
	await slide_to_flat()
	var speed_at_bottom: float = player.velocity.x
	Input.action_press("jump")
	await frames(12)
	Input.action_release("jump")
	check(not player.is_on_floor(), "jumped")
	check(player.velocity.x > player.run_speed,
		"long jump: still faster than running in the air (%d > %d, was %d)"
		% [player.velocity.x, player.run_speed, speed_at_bottom])

	# 4. Holding the opposite direction brakes at normal strength.
	await slide_to_flat()
	Input.action_press("move_left")
	await frames(12)
	Input.action_release("move_left")
	check(player.velocity.x < player.run_speed, "braking kills the slide speed quickly")

	print("slide tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Slope from (-80,-30) down to (80,30), flat ground after it. Player near the top.
func setup() -> void:
	if level:
		level.queue_free()
		await process_frame
	level = Node2D.new()
	root.add_child(level)
	var slope := StaticBody2D.new()
	slope.set_script(load("res://scripts/slope.gd"))
	slope.size = Vector2(160, 60)
	level.add_child(slope)
	var ground := StaticBody2D.new()
	ground.set_script(load("res://scripts/platform.gd"))
	ground.size = Vector2(800, 32)
	ground.position = Vector2(480, 46) # x 80..880, top at y=30 = the slope's foot
	level.add_child(ground)
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(-60, -40) # just above the slope surface (y=-22.5 there)
	level.add_child(player)
	await frames(15) # land and settle


## Slide down, then let go of S as soon as we're past the foot of the slope.
func slide_to_flat() -> void:
	await setup()
	Input.action_press("shield_down")
	for i in 120:
		await physics_frame
		if player.global_position.x > 90.0:
			break
	Input.action_release("shield_down")


func frames(n: int) -> void:
	for i in n:
		await physics_frame
