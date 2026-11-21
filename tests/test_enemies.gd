extends SceneTree
## Self-check for enemies vs. shield, with real physics.
## Run from the project folder:
##   godot --headless --path . --script tests/test_enemies.gd

const PlayerScene = preload("res://scenes/player.tscn")
const WalkerScene = preload("res://scenes/enemy_walker.tscn")
const BulletScene = preload("res://scenes/bullet.tscn")
const PlatformScript = preload("res://scripts/platform.gd")

var failures := 0
var level: Node2D
var player
var deaths := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	# 1. Thrown shield kills a walker.
	await setup_level(true)
	var walker := spawn(WalkerScene, Vector2(60, 0))
	player.shield.throw(1.0)
	await frames(40)
	check(not is_instance_valid(walker), "thrown shield kills walker")
	check(deaths == 0, "player safe while killing walker")

	# 2. Held shield (facing the bullet) blocks it.
	await setup_level(true)
	var bullet := spawn(BulletScene, Vector2(80, 0)) # flies left, toward the player
	await frames(60)
	check(not is_instance_valid(bullet), "held shield blocks bullet")
	check(deaths == 0, "blocked bullet doesn't kill")

	# 3. No shield in hand: the bullet hits the body.
	await setup_level(true)
	player.shield.throw(-1.0) # throw it away from the bullet
	spawn(BulletScene, Vector2(80, 0))
	await frames(60)
	check(deaths > 0, "unshielded player dies to bullet")

	# 4. Pogo on a walker: bounce, walker dies, player survives.
	await setup_level(false) # no floor: the player falls onto the walker
	walker = spawn(WalkerScene, Vector2(0, 80))
	Input.action_press("shield_down")
	await frames(60)
	Input.action_release("shield_down")
	check(not is_instance_valid(walker), "pogo kills walker")
	check(deaths == 0, "pogo on walker doesn't kill player")

	print("enemy tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Fresh level each time: player at (0, 0), optionally standing on a floor.
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
	deaths = 0
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
