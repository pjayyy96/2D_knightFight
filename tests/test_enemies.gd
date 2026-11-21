extends SceneTree
## Self-check for enemies vs. shield, plus health / mana / gold, with real physics.
## Run from the project folder:
##   godot --headless --path . --script tests/test_enemies.gd

## Note: scenes are `load()`ed at runtime, not `preload`ed, and GameState is reached as `gs`.
## A test run with --script is compiled BEFORE autoloads exist, so any script that names
## `GameState` must not be compiled until the test is already running.
var PlayerScene: PackedScene
var WalkerScene: PackedScene
var BulletScene: PackedScene
var PlatformScript: Script
var gs: Node # the GameState autoload

var failures := 0
var level: Node2D
var player
var hurts := 0
var deaths := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	PlayerScene = load("res://scenes/player.tscn")
	WalkerScene = load("res://scenes/enemy_walker.tscn")
	BulletScene = load("res://scenes/bullet.tscn")
	PlatformScript = load("res://scripts/platform.gd")

	# 1. Thrown shield kills a walker; the throw costs mana, the kill pays gold.
	await setup_level(true)
	var walker := spawn(WalkerScene, Vector2(60, 0))
	Input.action_press("throw")
	await frames(2) # physics_frame fires BEFORE nodes process, so give the player a full frame
	Input.action_release("throw")
	check(gs.mana == gs.MAX_MANA - 1, "throw costs 1 mana (mana=%d)" % gs.mana)
	await frames(40)
	check(not is_instance_valid(walker), "thrown shield kills walker")
	check(gs.gold == 1, "walker pays 1 gold")
	check(hurts == 0, "player safe while killing walker")

	# 2. No mana: J does nothing.
	await setup_level(true)
	gs.mana = 0
	Input.action_press("throw")
	await frames(2)
	Input.action_release("throw")
	check(not player.shield.is_flying(), "can't throw with 0 mana")

	# 3. Held shield (facing the bullet) blocks it.
	await setup_level(true)
	var bullet := spawn(BulletScene, Vector2(80, 0)) # flies left, toward the player
	await frames(60)
	check(not is_instance_valid(bullet), "held shield blocks bullet")
	check(hurts == 0, "blocked bullet doesn't hurt")
	check(gs.gold == 0, "bullets pay no gold")

	# 4. No shield in hand: two bullets close together = ONE hit (invincibility frames).
	await setup_level(true)
	player.shield.throw(-1.0) # throw it away from the bullets
	spawn(BulletScene, Vector2(80, 0))
	spawn(BulletScene, Vector2(100, 0))
	await frames(60)
	check(hurts == 1, "second bullet ignored while flickering (got %d hits)" % hurts)
	check(gs.hp == gs.MAX_HP - 1, "lost exactly 1 HP")

	# 5. Out of HP: die, respawn with full HP and mana, keep gold.
	await setup_level(true)
	gs.hp = 1
	gs.mana = 0
	gs.gold = 7
	player.take_hit(Vector2(50, 0))
	check(deaths == 1, "last HP lost = death")
	check(gs.hp == gs.MAX_HP and gs.mana == gs.MAX_MANA, "respawn refills")
	check(gs.gold == 7, "gold kept after death")

	# 6. Pogo on a walker: bounce, walker dies, mana comes back, player unhurt.
	await setup_level(false) # no floor: the player falls onto the walker
	gs.mana = 0
	walker = spawn(WalkerScene, Vector2(0, 80))
	Input.action_press("shield_down")
	await frames(60)
	Input.action_release("shield_down")
	check(not is_instance_valid(walker), "pogo kills walker")
	check(gs.mana == 1, "pogo kill refills 1 mana")
	check(hurts == 0, "pogo on walker doesn't hurt")

	print("enemy tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Fresh level each time: player at (0, 0), optionally standing on a floor. Fresh stats too.
func setup_level(with_floor: bool) -> void:
	if level:
		level.queue_free()
		await process_frame
	level = Node2D.new()
	root.add_child(level)
	if with_floor:
		var floor_block := StaticBody2D.new()
		floor_block.set_script(PlatformScript)
		floor_block.size = Vector2(400, 16)
		floor_block.position = Vector2(0, 20) # top at y=12 = the player's feet
		level.add_child(floor_block)
	player = PlayerScene.instantiate()
	level.add_child(player)
	gs.refill()
	gs.gold = 0
	hurts = 0
	deaths = 0
	player.hurt.connect(func(): hurts += 1)
	player.died.connect(func(): deaths += 1)
	await frames(2) # let _ready() run and the player settle


func spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	var node := scene.instantiate()
	node.position = pos
	level.add_child(node)
	return node


func frames(n: int) -> void:
	for i in n:
		await physics_frame
