extends SceneTree
## Self-check for the state-machine enemies (charger, flyer), the mystery chest, and that the
## levels load with the new pieces. Run from the project folder:
##   godot --headless --path . --script tests/test_state_enemies.gd
## (Scenes are load()ed at runtime and GameState is `gs`; see the note in test_enemies.gd.)

var PlayerScene: PackedScene
var ChargerScene: PackedScene
var FlyerScene: PackedScene
var ChestScene: PackedScene
var PlatformScript: Script
var gs: Node

var failures := 0
var level: Node2D
var player
var hurts := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	PlayerScene = load("res://scenes/player.tscn")
	ChargerScene = load("res://scenes/charger.tscn")
	FlyerScene = load("res://scenes/flyer.tscn")
	ChestScene = load("res://scenes/mystery_chest.tscn")
	PlatformScript = load("res://scripts/platform.gd")

	# 1. Charger sees you: PATROL -> ALERT (stands still) -> CHARGE -> it rams you.
	await setup_level()
	var charger = spawn(ChargerScene, Vector2(80, 6)) # on the floor, 80 px away
	await frames(2)
	check(charger.state == charger.State.ALERT, "charger spots the player (state=%d)" % charger.state)
	var x_before: float = charger.position.x
	await frames(15)
	check(charger.position.x == x_before, "charger stands still while winding up")
	check(hurts == 0, "the wind-up itself doesn't hurt")
	var charged := false
	for i in 60:
		await physics_frame
		charged = charged or charger.state == charger.State.CHARGE
	check(charged, "charger charges after the wind-up")
	check(hurts >= 1, "the charge hits the player")

	# 2. A charge stops at a ledge (stunned), never runs off; then it goes back to patrol.
	await setup_level()
	player.global_position = Vector2(-180, 0) # far away: out of sight
	charger = spawn(ChargerScene, Vector2(150, 6)) # floor ends at x=200
	await frames(2)
	charger.alert_toward(300.0)
	var stunned := false
	for i in 90:
		await physics_frame
		stunned = stunned or charger.state == charger.State.STUNNED
	check(stunned, "charger gets stunned at the ledge")
	check(charger.position.x <= 200.0, "charger doesn't run off the ledge (x=%.0f)" % charger.position.x)
	await frames(60)
	check(charger.state == charger.State.PATROL, "charger recovers and patrols again")

	# 3. Stomping a charger kills it and pays 2 gold (inherited from Enemy).
	await setup_level()
	charger = spawn(ChargerScene, Vector2(-180, 6))
	charger.speed = 0.0
	charger.sight_range = 0.0 # stays put in PATROL so we can land on it
	player.global_position = Vector2(-180, -60)
	await frames(40)
	check(not is_instance_valid(charger), "stomp kills the charger")
	check(gs.gold == 2, "charger pays 2 gold (got %d)" % gs.gold)

	# 4. Flyer: hovers, winds up, swoops at where you stood, flies home.
	await setup_level()
	var flyer = spawn(FlyerScene, Vector2(60, -60))
	await frames(2)
	check(flyer.state == flyer.State.WINDUP, "flyer notices the player")
	await frames(60)
	check(hurts >= 1, "a swoop you don't dodge hits you")
	await frames(120)
	check(flyer.state == flyer.State.HOVER and flyer.global_position.distance_to(Vector2(60, -60)) < 7.0,
		"flyer returns home to hover")

	# 5. Flyer swoop can be dodged: move during the wind-up and it dives at an empty spot.
	await setup_level()
	flyer = spawn(FlyerScene, Vector2(60, -60))
	await frames(2)
	player.global_position = Vector2(-160, 0)
	await frames(60)
	check(hurts == 0, "dodged swoop doesn't hurt")
	check(flyer.state != flyer.State.HOVER, "flyer went for the swoop anyway")

	# 6. Chest, GOLD: S while standing at it pays gold, once.
	await setup_level()
	var chest = spawn(ChestScene, Vector2(0, 6))
	chest.reward = 0
	await press("shield_down")
	check(chest.opened and gs.gold == chest.gold_amount, "gold chest pays %d (got %d)" % [chest.gold_amount, gs.gold])
	await press("shield_down")
	check(gs.gold == chest.gold_amount, "an open chest pays nothing more")

	# 7. Chest, REFILL.
	await setup_level()
	chest = spawn(ChestScene, Vector2(0, 6))
	chest.reward = 1
	gs.hp = 1
	gs.mana = 0
	await press("shield_down")
	check(gs.hp == gs.MAX_HP and gs.mana == gs.MAX_MANA, "refill chest fills HP and mana")

	# 8. Chest, MIMIC: a charger appears on the far side, winding up, without hurting you yet.
	await setup_level()
	chest = spawn(ChestScene, Vector2(4, 6)) # player slightly left of the chest
	chest.reward = 2
	await press("shield_down")
	var mimic: Node2D = null
	for child in level.get_children():
		if child.scene_file_path == ChargerScene.resource_path:
			mimic = child
	check(mimic != null, "mimic chest spawns a charger")
	if mimic:
		check(mimic.position.x > chest.position.x, "mimic appears on the far side of the chest")
		check(mimic.state == mimic.State.ALERT and mimic.direction < 0.0, "mimic winds up toward you")
	check(hurts == 0, "the mimic doesn't hurt you the moment it appears")

	# 9. Chest: S in the air does nothing.
	await setup_level()
	chest = spawn(ChestScene, Vector2(0, 6))
	player.velocity.y = -300.0
	await frames(3)
	await press("shield_down")
	check(not chest.opened, "can't open a chest mid-jump")

	# 10. The levels load with their new pieces, and their exits finish the right level.
	for path in ["res://scenes/main.tscn", "res://scenes/climb.tscn"]:
		var lvl: Node = load(path).instantiate()
		root.add_child(lvl)
		await frames(30)
		check(lvl.has_node("LevelStart"), "%s has a start marker" % path)
		if path.ends_with("climb.tscn"):
			check(lvl.get_node("LevelExit").level_id == 2, "the Climb's exit is level 2")
		lvl.queue_free()
		await process_frame

	print("state enemy tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Fresh level: a floor from x=-200 to 200 (top at y=12), player standing at (0, 0).
func setup_level() -> void:
	if level:
		level.queue_free()
		await process_frame
	level = Node2D.new()
	root.add_child(level)
	var floor_block := StaticBody2D.new()
	floor_block.set_script(PlatformScript)
	floor_block.size = Vector2(400, 16)
	floor_block.position = Vector2(0, 20)
	level.add_child(floor_block)
	player = PlayerScene.instantiate()
	level.add_child(player)
	gs.refill()
	gs.gold = 0
	hurts = 0
	player.hurt.connect(func(): hurts += 1)
	await frames(2)


func spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	var node := scene.instantiate()
	node.position = pos
	level.add_child(node)
	return node


func press(action: String) -> void:
	Input.action_press(action)
	await frames(2) # hold ≥2 frames: 1-frame taps get missed
	Input.action_release(action)
	await frames(1)


func frames(n: int) -> void:
	for i in n:
		await physics_frame
