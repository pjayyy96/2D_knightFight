extends SceneTree
## Self-check for the shield state machine. No window, no input — we step it by hand.
## Run from the project folder:
##   godot --headless --path . --script tests/test_shield.gd
## Prints "shield tests: OK" and exits 0, or prints each FAIL and exits with the fail count.

const Shield = preload("res://scripts/shield.gd")
const DT := 1.0 / 60.0 # one physics frame

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame # let _ready() run (player links itself to the shield there)
	var shield = player.get_node("Shield")

	shield._physics_process(DT)
	check(shield.state == Shield.State.HELD, "starts in hand")
	check(shield.global_position.x > player.global_position.x, "held on the facing (right) side")

	check(shield.throw(1.0), "throw from hand succeeds")
	check(not shield.throw(1.0), "second throw refused while flying")

	var start_x: float = shield.global_position.x
	for i in 10:
		shield._physics_process(DT)
	check(shield.state == Shield.State.OUT, "still flying after 10 frames")
	check(shield.global_position.x > start_x + 50.0, "moved right ~60 px")

	var frames := 0
	while shield.state == Shield.State.OUT and frames < 300:
		shield._physics_process(DT)
		frames += 1
	check(shield.state == Shield.State.RETURNING, "turns back after max_distance")

	frames = 0
	while shield.state == Shield.State.RETURNING and frames < 300:
		shield._physics_process(DT)
		frames += 1
	check(shield.state == Shield.State.HELD, "comes back to the hand")
	check(shield.throw(-1.0), "can throw again once caught")

	print("shield tests: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(failures)
