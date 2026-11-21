extends SceneTree
## Self-check for checkpoints: paying gold, saving the respawn point, refilling.
## Run from the project folder:
##   godot --headless --path . --script tests/test_checkpoint.gd
## (Scenes are load()ed at runtime and GameState is `gs`; see the note in test_enemies.gd.)

var failures := 0
var gs: Node


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")

	# Level: a floor, the player at x=0, a checkpoint at x=100, standing on the floor.
	var level := Node2D.new()
	root.add_child(level)
	var floor_block := StaticBody2D.new()
	floor_block.set_script(load("res://scripts/platform.gd"))
	floor_block.size = Vector2(600, 16)
	floor_block.position = Vector2(0, 20) # top at y=12
	level.add_child(floor_block)
	var checkpoint = load("res://scenes/checkpoint.tscn").instantiate()
	checkpoint.position = Vector2(100, -4) # 32 tall, bottom on the floor top
	level.add_child(checkpoint)
	var player = load("res://scenes/player.tscn").instantiate()
	level.add_child(player)
	await frames(3)
	var start: Vector2 = player.spawn_point

	# 1. Pressing S away from the flag does nothing.
	gs.gold = 5
	await press("shield_down")
	check(not checkpoint.active and gs.gold == 5, "S away from the flag does nothing")

	# 2. At the flag without enough gold: not activated, gold untouched.
	player.global_position = Vector2(100, 0)
	gs.gold = 0
	await frames(3)
	await press("shield_down")
	check(not checkpoint.active, "no gold, no checkpoint")
	check(checkpoint.label.text.begins_with("need"), "tells you it needs gold")

	# 3. Enough gold: pay, save, refill.
	gs.gold = 3
	gs.hp = 1
	gs.mana = 0
	await press("shield_down")
	check(checkpoint.active, "activates with enough gold")
	check(gs.gold == 2, "costs 1 gold (gold=%d)" % gs.gold)
	check(gs.hp == gs.MAX_HP and gs.mana == gs.MAX_MANA, "lighting it refills HP and mana")
	check(player.spawn_point != start, "respawn point moved")

	# 4. Dying now brings you to the checkpoint, not the start.
	player.global_position = Vector2(-200, 0)
	player.die()
	check(player.global_position.distance_to(Vector2(100, 0)) < 1.0,
		"respawn at the checkpoint (at %s)" % player.global_position)

	# 5. Pressing again doesn't charge twice.
	await press("shield_down")
	check(gs.gold == 2, "already lit: no second payment")

	print("checkpoint tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


func press(action: String) -> void:
	Input.action_press(action)
	await frames(2) # physics_frame fires BEFORE nodes process, so give everyone a full frame
	Input.action_release(action)
	await frames(1)


func frames(n: int) -> void:
	for i in n:
		await physics_frame
