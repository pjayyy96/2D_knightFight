extends SceneTree
## Self-check for the boss: HP, hit cooldown, phases, defeat, and the attack cycle.
## Run from the project folder:
##   godot --headless --path . --script tests/test_boss.gd
## (Scenes are load()ed and GameState is reached as `gs`: see the note in test_enemies.gd.)

var BossScene: PackedScene
var PlayerScene: PackedScene
var PlatformScript: Script
var gs: Node # the GameState autoload

var failures := 0
var level: Node2D


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	BossScene = load("res://scenes/boss.tscn")
	PlayerScene = load("res://scenes/player.tscn")
	PlatformScript = load("res://scripts/platform.gd")

	# 1. A hit costs 1 HP; a second hit right after is ignored (cooldown), a later one counts.
	await new_level()
	var boss = spawn_boss(Vector2(0, -4))
	boss.hit()
	check(boss.hp == boss.max_hp - 1, "hit lowers HP by 1 (hp=%d)" % boss.hp)
	boss.hit()
	check(boss.hp == boss.max_hp - 1, "second hit during cooldown ignored (hp=%d)" % boss.hp)
	await frames(int(boss.hit_cooldown * 60.0) + 2)
	boss.hit()
	check(boss.hp == boss.max_hp - 2, "hit after cooldown counts (hp=%d)" % boss.hp)

	# 2. A real thrown shield passes through the boss twice (out and back) = still ONE hit.
	await new_level()
	var player = PlayerScene.instantiate()
	level.add_child(player) # at (0, 0), facing right, feet on the floor
	boss = spawn_boss(Vector2(40, -4)) # close: the worst case for a double hit
	await frames(2)
	player.shield.throw(1.0)
	await frames(60) # long enough for the whole trip
	check(not player.shield.is_flying(), "shield came back")
	check(boss.hp == boss.max_hp - 1, "one throw = one hit (hp=%d)" % boss.hp)

	# 3. Phase 2 starts only BELOW half HP (6 HP: phase 1 at 3, phase 2 at 2).
	await new_level()
	boss = spawn_boss(Vector2(0, -4))
	boss.hp = 4
	boss.hit()
	check(boss.phase == 1, "still phase 1 at half HP (hp=%d)" % boss.hp)
	await frames(int(boss.hit_cooldown * 60.0) + 2)
	boss.hit()
	check(boss.phase == 2, "phase 2 below half HP (hp=%d)" % boss.hp)

	# 4. Last HP: emits `defeated`, pays its gold, disappears.
	await new_level()
	boss = spawn_boss(Vector2(0, -4))
	var defeats := [0] # an Array so the lambda below can change it (it can't reassign a local int)
	boss.defeated.connect(func(): defeats[0] += 1)
	var reward: int = boss.gold_value
	boss.hp = 1
	boss.hit()
	boss.hit() # same frame again (e.g. shield AND pogo): must not pay twice
	await frames(2)
	check(defeats[0] == 1, "defeated emitted once (got %d)" % defeats[0])
	check(gs.gold == reward, "boss pays %d gold (gold=%d)" % [reward, gs.gold])
	check(not is_instance_valid(boss), "boss freed")

	# 5. The attack cycle runs between two walls: charge, turn at the wall, shoot back.
	await new_level()
	for x in [-150.0, 150.0]:
		var wall := StaticBody2D.new()
		wall.set_script(PlatformScript)
		wall.size = Vector2(20, 100)
		wall.position = Vector2(x, 0)
		level.add_child(wall)
	boss = spawn_boss(Vector2(0, -4), false) # normal timings this time
	var seen := {}
	var spawned := [] # everything added to the level from now on = the boss's bullets
	level.child_entered_tree.connect(func(n): spawned.append(n))
	for i in 300: # 5 s: idle 1 + charge ~0.8 + pause 0.8 + 3 shots
		await physics_frame
		seen[boss.state] = true
		check(absf(boss.position.x) < 140.0 - 16.0, "boss stays out of the walls (x=%.1f)" % boss.position.x)
	check(seen.size() == 4, "visited all 4 states (saw %s)" % [seen.keys()])
	check(boss.direction == 1.0, "turned around at the left wall")
	check(spawned.size() >= 3, "fired a volley (%d bullets)" % spawned.size())

	# 6. Stomp: drop the player onto the boss's head (no shield). Boss loses 1 HP, player
	#    bounces unhurt, and the HP bar SLIDES down instead of jumping.
	await new_level()
	boss = spawn_boss(Vector2(0, -4)) # top of the boss at y = -20
	player = PlayerScene.instantiate()
	player.position = Vector2(0, -80)
	level.add_child(player)
	var hurts := [0]
	player.hurt.connect(func(): hurts[0] += 1)
	var bar_mid := -1.0
	for i in 40:
		await physics_frame
		if bar_mid < 0.0 and boss.hp < boss.max_hp:
			await physics_frame # one frame after the stomp: the bar should be partway
			bar_mid = boss.hp_bar.value
	check(boss.hp == boss.max_hp - 1, "stomp takes 1 HP (hp=%d)" % boss.hp)
	check(hurts[0] == 0, "stomping the boss doesn't hurt you")
	check(bar_mid > boss.hp, "HP bar slides down, not instant (was %.2f right after)" % bar_mid)
	await frames(30)
	check(is_equal_approx(boss.hp_bar.value, boss.hp), "HP bar ends at the new HP")

	print("boss tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Fresh level: a floor whose top is at y=12 (so a player at (0, 0) stands on it), fresh stats.
func new_level() -> void:
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
	gs.refill()
	gs.gold = 0


## y = -4 puts the 32 px boss right on the floor. `frozen` = it never leaves IDLE,
## so it can't wander off or attack while we test something else.
func spawn_boss(pos: Vector2, frozen := true):
	var boss = BossScene.instantiate()
	boss.position = pos
	if frozen:
		boss.idle_time = 999.0
	level.add_child(boss)
	return boss


func frames(n: int) -> void:
	for i in n:
		await physics_frame
