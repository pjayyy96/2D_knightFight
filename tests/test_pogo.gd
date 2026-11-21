extends SceneTree
## Self-check for the pogo bounce, using real physics (not hand-stepped like test_shield).
## Run from the project folder:
##   godot --headless --path . --script tests/test_pogo.gd

var failures := 0
var gs: Node # the GameState autoload (see the note in test_enemies.gd)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	var with_shield := await drop_onto_spikes(true)
	check(with_shield.bounced, "shield down: bounces off spikes")
	check(with_shield.refilled, "shield down: bounce refills air jumps")
	check(with_shield.hurts == 0, "shield down: not hurt")

	var without := await drop_onto_spikes(false)
	check(without.hurts > 0, "no shield: spikes hurt")

	print("pogo tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Builds a tiny level (player in the air, spikes below), lets it run 1.5 s, reports what happened.
func drop_onto_spikes(hold_shield_down: bool) -> Dictionary:
	var level := Node2D.new()
	root.add_child(level)
	var spikes := Area2D.new()
	spikes.set_script(load("res://scripts/spikes.gd"))
	spikes.position = Vector2(0, 80)
	level.add_child(spikes)
	var player = load("res://scenes/player.tscn").instantiate()
	level.add_child(player) # starts at (0, 0), falling, with 0 air jumps left

	gs.refill()
	var result := {"bounced": false, "refilled": false, "hurts": 0}
	player.hurt.connect(func(): result.hurts += 1)
	if hold_shield_down:
		Input.action_press("shield_down") # fake holding the key
	for i in 90:
		await physics_frame
		if player.velocity.y < 0.0 and not result.bounced:
			result.bounced = true
			result.refilled = player.air_jumps_left == player.air_jumps

	Input.action_release("shield_down")
	level.queue_free()
	await process_frame
	return result
