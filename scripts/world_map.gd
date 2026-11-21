extends Node2D
## The world map: the first screen. A/D (or ←/→) walks the knight between levels,
## Space (jump) enters the one he stands on.
##
## The whole map is DRAWN from data in _draw() (like platform.gd draws its block): the
## LEVELS list below + the progress in GameState. Nothing is placed by hand in the editor,
## so the picture can never disagree with the save file.

## One line per level. A level's id is its place in this list, counting from 1, and that
## id is what its exit / boss tells GameState when you win. Level 3 = one more line here.
const LEVELS := [
	{"name": "1: The Road", "scene": "res://scenes/main.tscn"},
	{"name": "2: The Boss", "scene": "res://scenes/boss_arena.tscn"},
]

const SPACING := 160.0  # px between two level spots
const ROW_Y := 170.0
const LOCKED := Color(0.35, 0.35, 0.4)   # grey: can't go there yet
const OPEN := Color(0.95, 0.8, 0.3)      # gold: unlocked, not beaten yet = "go here next"
const DONE := Color(0.3, 0.85, 0.4)      # green: beaten (same green as a lit checkpoint)
const KNIGHT := Color(0.35, 0.55, 0.95)  # the player's blue

var cursor := 0 # which level the knight stands on: an index into LEVELS (= level id - 1)


func _ready() -> void:
	# Read the save once per game run. Later visits already have the newest data in memory.
	if not GameState.loaded:
		GameState.load_game()
	# Start on the newest level you may play: right after beating level 1, that's level 2.
	cursor = mini(GameState.unlocked, LEVELS.size()) - 1


## _process, not _physics_process: a menu has no physics, it only reacts to keys.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("move_right"):
		move_cursor(1)
	elif Input.is_action_just_pressed("move_left"):
		move_cursor(-1)
	elif Input.is_action_just_pressed("jump"):
		enter_level()


func move_cursor(step: int) -> void:
	var next := cursor + step
	# Stop at both ends of the list, and never onto a locked level.
	if next < 0 or next >= LEVELS.size() or not GameState.is_unlocked(next + 1):
		return
	cursor = next
	queue_redraw() # ask Godot to call _draw() again: the knight moved


func enter_level() -> void:
	GameState.refill() # every level starts with full HP and mana; gold carries over
	# Throws this map away and loads the level. It happens at the end of the frame
	# ("deferred"), so the rest of this function still runs safely.
	get_tree().change_scene_to_file(LEVELS[cursor].scene)


## Where level number `index` sits on screen. The row is centered, whatever its length.
func spot(index: int) -> Vector2:
	var row_width := (LEVELS.size() - 1) * SPACING
	return Vector2(320.0 - row_width / 2.0 + index * SPACING, ROW_Y)


func _draw() -> void:
	var font := ThemeDB.fallback_font # Godot's built-in font: no font file needed
	# The road between the spots.
	for i in range(1, LEVELS.size()):
		draw_line(spot(i - 1), spot(i), LOCKED, 4.0)
	# Each level: a colored square, its name, and its state as a word (color alone is
	# easy to miss, and some players can't tell grey from green).
	for i in LEVELS.size():
		var id := i + 1
		var color := LOCKED
		var state := "locked"
		if GameState.is_completed(id):
			color = DONE
			state = "done"
		elif GameState.is_unlocked(id):
			color = OPEN
			state = "open"
		draw_rect(Rect2(spot(i) - Vector2(12, 12), Vector2(24, 24)), color)
		draw_string(font, spot(i) + Vector2(-70, 34), LEVELS[i].name,
			HORIZONTAL_ALIGNMENT_CENTER, 140, 12)
		draw_string(font, spot(i) + Vector2(-70, 48), state,
			HORIZONTAL_ALIGNMENT_CENTER, 140, 10, color)
	# The knight, standing on top of the chosen level's square.
	draw_rect(Rect2(spot(cursor) + Vector2(-7, -36), Vector2(14, 24)), KNIGHT)
	# Title, gold and controls.
	draw_string(font, Vector2(0, 40), "WORLD MAP", HORIZONTAL_ALIGNMENT_CENTER, 640, 24)
	draw_string(font, Vector2(8, 18), "GOLD %d" % GameState.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(0, 330), "A/D: choose    Space: enter",
		HORIZONTAL_ALIGNMENT_CENTER, 640, 12, LOCKED.lightened(0.4))
