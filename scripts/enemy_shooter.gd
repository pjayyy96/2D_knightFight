extends Enemy
## Stands still and fires a bullet every `fire_interval` seconds toward `direction`.

const BulletScene = preload("res://scenes/bullet.tscn") # load once, spawn many

@export var direction := -1.0 # -1 = shoots left, 1 = right
@export var fire_interval := 2.0


func _ready() -> void:
	super() # run Enemy._ready() too (groups + signals). Overriding replaces it otherwise!
	var timer := Timer.new()
	timer.wait_time = fire_interval
	timer.autostart = true
	timer.timeout.connect(_fire)
	add_child(timer)


func _fire() -> void:
	var bullet := BulletScene.instantiate()
	bullet.direction = direction
	bullet.position = position + Vector2(direction * 12.0, 0.0) # spawn just outside our body
	get_parent().add_child(bullet) # a sibling, so it doesn't move with us or die with us
