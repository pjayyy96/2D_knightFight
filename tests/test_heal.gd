extends SceneTree
## Self-check for the heal move (hold K, standing still): cost, timing, and what cancels it.
## Run from the project folder:
##   godot --headless --path . --script tests/test_heal.gd
## (Scenes are load()ed and GameState is reached as `gs`: see the note in test_enemies.gd.)

var PlayerScene: PackedScene
var PlatformScript: Script
var gs: Node # the GameState autoload

var failures := 0
var level: Node2D
var player


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	PlayerScene = load("res://scenes/player.tscn")
	PlatformScript = load("res://scripts/platform.gd")
	var full_charge := 0 # frames for one heal, plus a few spare; set once the player exists

	# 1. Hurt, enough mana, hold K long enough: +1 HP for 2 mana. Exactly ONE heal.
	await setup(2, 4)
	full_charge = int(player.heal_time * 60.0) + 6
	await hold("heal", full_charge)
	check(gs.hp == 3, "heal gives 1 HP (hp=%d)" % gs.hp)
	check(gs.mana == 4 - player.heal_cost, "heal costs %d mana (mana=%d)" % [player.heal_cost, gs.mana])
	check(player.body_color.is_equal_approx(player.get_node("Body").color), "color back to normal after the heal")

	# 2. Let go halfway: nothing happens, nothing is paid, and the charge resets.
	await setup(2, 4)
	await hold("heal", full_charge / 2)
	await frames(2)
	check(gs.hp == 2 and gs.mana == 4, "released early: no heal, no cost (hp=%d mana=%d)" % [gs.hp, gs.mana])
	check(player.heal_timer == 0.0, "released early: charge resets")

	# 3. Full HP: holding K wastes no mana.
	await setup(3, 4)
	await hold("heal", full_charge)
	check(gs.mana == 4, "full HP: no mana spent (mana=%d)" % gs.mana)

	# 4. Not enough mana: no heal.
	await setup(2, 1)
	await hold("heal", full_charge)
	check(gs.hp == 2 and gs.mana == 1, "too little mana: no heal (hp=%d mana=%d)" % [gs.hp, gs.mana])

	# 5. Walking while holding K: no heal (you must stand still).
	await setup(2, 4)
	Input.action_press("move_right")
	await hold("heal", full_charge)
	Input.action_release("move_right")
	check(gs.hp == 2 and gs.mana == 4, "moving: no heal (hp=%d mana=%d)" % [gs.hp, gs.mana])

	# 6. Getting hit mid-charge cancels the charge.
	await setup(2, 4)
	Input.action_press("heal")
	await frames(full_charge / 2)
	check(player.heal_timer > 0.0, "charge was building before the hit")
	player.take_hit(player.global_position + Vector2(20, 0))
	check(player.heal_timer == 0.0, "a hit resets the charge")
	Input.action_release("heal")

	# 7. Keep holding: heals again every heal_time until HP is full, then stops paying.
	await setup(1, 4)
	await hold("heal", full_charge * 3)
	check(gs.hp == 3 and gs.mana == 0, "held: 2 heals to full, 4 mana paid (hp=%d mana=%d)" % [gs.hp, gs.mana])

	print("heal tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Fresh level: a floor, the player standing on it, and the given HP and mana.
func setup(hp: int, mana: int) -> void:
	if level:
		level.queue_free()
		await process_frame
	level = Node2D.new()
	root.add_child(level)
	var floor_block := StaticBody2D.new()
	floor_block.set_script(PlatformScript)
	floor_block.size = Vector2(400, 16)
	floor_block.position = Vector2(0, 20) # top at y=12 = the player's feet
	level.add_child(floor_block)
	player = PlayerScene.instantiate()
	level.add_child(player)
	await frames(2) # let _ready() run and the player land
	gs.hp = hp
	gs.mana = mana


func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


func frames(n: int) -> void:
	for i in n:
		await physics_frame
