extends Enemy
## Flies straight. Gone when it touches any shield (held = blocked!), a wall, the player,
## or when it gets too old. Still in the "pogo" group (from Enemy), so you can bounce on it.

@export var speed := 120.0
@export var lifetime := 3.0 # seconds, so missed bullets don't fly forever

var direction := -1.0


func _init() -> void:
	gold_value = 0 # popping bullets pays nothing


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


# Override: always hurt the player's body (no stomping bullets; only the SHIELD can pogo
# them), and vanish on whatever we touched, walls included.
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(global_position)
	hit()


# Override: ANY shield stops a bullet, not just a flying one. That's how blocking works.
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("shield"):
		hit()
