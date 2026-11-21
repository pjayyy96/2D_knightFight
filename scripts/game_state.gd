extends Node
## Global game data: health, mana, gold, and (milestone 10) which levels you've beaten.
## Registered in project.godot under [autoload] as "GameState", so ANY script can write
## `GameState.gold` without finding a node first. Autoloads live outside the level scene,
## so they survive when levels change or the player respawns.
##
## Every change emits `changed`, so the HUD redraws only when something actually happened.

signal changed

const MAX_HP := 3
const MAX_MANA := 4
const MAP_SCENE := "res://scenes/world_map.tscn"
const WIN_DELAY := 1.5 # seconds to enjoy the win before going back to the map

var hp := MAX_HP
var mana := MAX_MANA
var gold := 0

## Progress. Levels are numbered 1, 2, 3... and played in order, so ONE number holds it all:
## `unlocked` is the highest level you may enter, and every level below it has been beaten.
## shortcut: only works for a straight line of levels; a branching map needs a list of beaten ids.
var unlocked := 1

## Where progress is saved. "user://" is a per-game folder Godot picks for you
## (on Windows: %APPDATA%\Godot\app_userdata\2D Knight Fight). It's a variable, not a
## const, so tests can point it at a temp file and never overwrite your real save.
var save_path := "user://save.cfg"
var loaded := false # has the save been read yet? The world map reads it once, on first show.


## Pay mana. Returns false (and pays nothing) if there isn't enough.
func spend_mana(amount: int) -> bool:
	if mana < amount:
		return false
	mana -= amount
	changed.emit()
	return true


func add_mana(amount: int) -> void:
	mana = mini(mana + amount, MAX_MANA) # never above the max
	changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


## Pay gold. Returns false (and pays nothing) if there isn't enough. Same pattern as spend_mana.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	changed.emit()
	return true


## Lose health. Returns true if that was the last of it.
func take_damage(amount: int) -> bool:
	hp = maxi(hp - amount, 0) # never below 0
	changed.emit()
	return hp == 0


## Get health back (the heal move, milestone 12). Same "never past the max" rule as add_mana.
func heal(amount: int) -> void:
	hp = mini(hp + amount, MAX_HP)
	changed.emit()


## Full health and mana (on respawn). Gold is kept, as a reward for progress.
func refill() -> void:
	hp = MAX_HP
	mana = MAX_MANA
	changed.emit()


func is_unlocked(level_id: int) -> bool:
	return level_id <= unlocked


func is_completed(level_id: int) -> bool:
	return level_id < unlocked # you can only get past a level by beating it


## Mark a level beaten: the next one opens, and progress is saved right away.
func complete_level(level_id: int) -> void:
	unlocked = maxi(unlocked, level_id + 1) # replaying level 1 must not re-lock level 2
	save_game()


## Called by a level's exit (or its boss) when you win: save, pause a moment, back to the map.
## It lives here, not in the level, because GameState survives the scene change; the level
## that started the countdown is about to be thrown away.
func finish_level(level_id: int) -> void:
	complete_level(level_id)
	await get_tree().create_timer(WIN_DELAY).timeout
	get_tree().change_scene_to_file(MAP_SCENE)


## ConfigFile writes a small text file with [sections] and key=value lines, the same format as
## project.godot. Open the file in Notepad after beating a level to see it.
## Saved: progress and gold. Not saved: HP and mana, because every level starts with them full.
func save_game() -> void:
	var file := ConfigFile.new()
	file.set_value("progress", "unlocked", unlocked)
	file.set_value("progress", "gold", gold)
	var err := file.save(save_path)
	if err != OK:
		push_warning("could not save to %s (error %d)" % [save_path, err]) # say so, don't fail silently


func load_game() -> void:
	loaded = true
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return # no save yet (first run): keep the starting values
	# int(): the file is plain text anyone can edit, so don't trust it to hold a number.
	unlocked = maxi(int(file.get_value("progress", "unlocked", 1)), 1)
	gold = int(file.get_value("progress", "gold", 0))
	changed.emit()
