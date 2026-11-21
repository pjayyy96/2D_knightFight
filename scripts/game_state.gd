extends Node
## Global game data: health, mana, gold.
## Registered in project.godot under [autoload] as "GameState", so ANY script can write
## `GameState.gold` without finding a node first. Autoloads live outside the level scene,
## so they survive when levels change or the player respawns.
##
## Every change emits `changed`, so the HUD redraws only when something actually happened.

signal changed

const MAX_HP := 3
const MAX_MANA := 4

var hp := MAX_HP
var mana := MAX_MANA
var gold := 0


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


## Lose health. Returns true if that was the last of it.
func take_damage(amount: int) -> bool:
	hp = maxi(hp - amount, 0) # never below 0
	changed.emit()
	return hp == 0


## Full health and mana (on respawn). Gold is kept, as a reward for progress.
func refill() -> void:
	hp = MAX_HP
	mana = MAX_MANA
	changed.emit()
