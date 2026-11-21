extends SceneTree
## Self-check for the world map: unlocking, saving/loading, the cursor, and the full loop
## map -> level -> win -> map. Run from the project folder:
##   godot --headless --path . --script tests/test_world_map.gd
## (Scenes are load()ed at runtime and GameState is `gs`; see the note in test_enemies.gd.)
##
## Every save goes to a TEMP file (gs.save_path), so running this never touches your real save.

const MAP := "res://scenes/world_map.tscn"
const ARENA := "res://scenes/boss_arena.tscn"

var failures := 0
var gs: Node


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.save_path = OS.get_temp_dir().path_join("knight_test_save.cfg")
	DirAccess.remove_absolute(gs.save_path) # a leftover from an earlier run would skew case 1

	# 1. A first run (no save file yet): only level 1 is open, nothing is beaten.
	gs.load_game()
	check(gs.is_unlocked(1) and not gs.is_unlocked(2), "only level 1 unlocked at the start")
	check(not gs.is_completed(1), "nothing completed at the start")

	# 2. Beating level 1 opens level 2, and saves at once.
	gs.complete_level(1)
	check(gs.is_completed(1) and gs.is_unlocked(2), "completing 1 unlocks 2")
	check(not gs.is_completed(2) and not gs.is_unlocked(3), "level 2 open but not beaten")
	check(FileAccess.file_exists(gs.save_path), "completing a level writes the save file")
	gs.complete_level(1) # replaying an old level...
	check(gs.is_unlocked(2), "...never locks a newer one")

	# 3. Save, wipe memory (like quitting the game), load: progress and gold come back.
	gs.gold = 7
	gs.save_game()
	gs.unlocked = 1
	gs.gold = 0
	gs.load_game()
	check(gs.is_unlocked(2) and gs.gold == 7,
		"save/load round trip (unlocked=%d gold=%d)" % [gs.unlocked, gs.gold])

	# 4. The map cursor can't walk onto a locked level.
	gs.unlocked = 1
	var map = load(MAP).instantiate()
	root.add_child(map)
	await frames(2)
	check(map.cursor == 0, "map starts on level 1")
	await press("move_right")
	check(map.cursor == 0, "can't move onto locked level 2 (cursor=%d)" % map.cursor)
	map.queue_free()

	# 5. Level 1's exit: touching it completes level 1, then returns to the map.
	gs.unlocked = 1
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level # so change_scene_to_file replaces it, like in the real game
	var floor_block := StaticBody2D.new()
	floor_block.set_script(load("res://scripts/platform.gd"))
	floor_block.size = Vector2(600, 16)
	floor_block.position = Vector2(0, 20) # top at y=12
	level.add_child(floor_block)
	var exit = load("res://scenes/level_exit.tscn").instantiate()
	exit.position = Vector2(100, -12) # 48 tall, bottom on the floor top
	level.add_child(exit)
	var player = load("res://scenes/player.tscn").instantiate()
	level.add_child(player)
	await frames(3)
	check(not gs.is_completed(1), "exit far away: not completed yet")
	player.global_position = Vector2(100, 0)
	await frames(3)
	check(gs.is_completed(1) and gs.is_unlocked(2), "touching the exit completes level 1")
	check(exit.label.text == "CLEAR!", "the exit shows the win")
	await back_on_map()

	# 6. On the map now level 2 is open: walk there, enter with jump; HP and mana refill.
	map = current_scene
	check(map.cursor == 1, "map starts on the newest level (cursor=%d)" % map.cursor)
	await press("move_left")
	check(map.cursor == 0, "can walk back to level 1")
	await press("move_right")
	check(map.cursor == 1, "can walk onto unlocked level 2")
	await press("move_right")
	check(map.cursor == 1, "stops at the end of the list")
	gs.hp = 1
	gs.mana = 0
	gs.gold = 5
	await press("jump")
	await frames(2)
	check(current_scene != null and current_scene.scene_file_path == ARENA,
		"jump enters the boss arena")
	check(gs.hp == gs.MAX_HP and gs.mana == gs.MAX_MANA, "entering a level refills HP and mana")
	check(gs.gold == 5, "gold carries into the level")

	# 7. Boss defeated in the arena: level 2 done, message shown, back to the map.
	current_scene.get_node("Boss").defeated.emit() # pretend the last hit landed
	check(gs.is_completed(2), "beating the boss completes level 2")
	check(current_scene.get_node("HUD/Message").text != "", "the arena shows the win")
	await back_on_map()

	DirAccess.remove_absolute(gs.save_path) # leave nothing behind
	print("world map tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)


## Wait out the win pause, then check the scene changed back to the map.
func back_on_map() -> void:
	await create_timer(gs.WIN_DELAY + 0.1).timeout
	await frames(2) # change_scene_to_file happens at the end of a frame
	check(current_scene != null and current_scene.scene_file_path == MAP, "back on the map")


func press(action: String) -> void:
	Input.action_press(action)
	await frames(2) # physics_frame fires BEFORE nodes process, so give everyone a full frame
	Input.action_release(action)
	await frames(1)


func frames(n: int) -> void:
	for i in n:
		await physics_frame
