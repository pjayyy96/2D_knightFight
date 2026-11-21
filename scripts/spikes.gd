@tool # draws in the editor too, like platform.gd
extends Area2D
## A strip of spikes. Touch them with your body: lose 1 HP and get knocked up and away.
## Land on them with the shield held down (S/↓ in the air): bounce!
## That works because spikes join the "pogo" group, which the shield looks for.

const HEIGHT := 12.0
const TOOTH := 8.0 # width of one spike

@export var width := 48.0:
	set(value):
		width = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("pogo")
	# Forgiving hitbox: only the lower half of the spikes hurts. Players forgive a game
	# that is a little generous, never one that kills them on a pixel they didn't touch.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, HEIGHT / 2)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position.y = HEIGHT / 4
	add_child(collision)


# Checked EVERY frame, not with the `body_entered` signal: that only fires on *entering*,
# so someone who landed in the spikes while invincible could then stand there safely forever.
# Repeated hits are fine, because the player ignores them while flickering.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return # @tool scripts run in the editor too; don't do game logic there
	for body in get_overlapping_bodies():
		# "Duck typing": we don't check *what* it is, only whether it can be hurt.
		if body.has_method("take_hit"):
			body.take_hit(global_position)


func _draw() -> void:
	for i in int(width / TOOTH):
		var x := -width / 2 + i * TOOTH
		var tooth := PackedVector2Array([
			Vector2(x, HEIGHT / 2), Vector2(x + TOOTH / 2, -HEIGHT / 2), Vector2(x + TOOTH, HEIGHT / 2)])
		draw_colored_polygon(tooth, Color(0.85, 0.85, 0.9))
