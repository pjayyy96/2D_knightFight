extends Enemy
## Patrols back and forth on its platform, turning at walls and ledges.
## It "feels" the world with two RayCast2D nodes (invisible lines that report what they touch):
##   FloorRay: from just past our front edge, straight down. Nothing there = ledge ahead.
##   WallRay:  straight ahead. Something there = wall ahead.

@export var speed := 40.0

var direction := -1.0 # -1 = left, 1 = right

@onready var floor_ray: RayCast2D = $FloorRay
@onready var wall_ray: RayCast2D = $WallRay


func _physics_process(delta: float) -> void:
	_aim_rays()
	# Only real walls (StaticBody2D) turn us. The ray also sees the player's body, and
	# turning away from the player would make walkers harmless from the side.
	if wall_ray.get_collider() is StaticBody2D or not floor_ray.is_colliding():
		direction = -direction
		# Re-aim right away. Otherwise next frame still reads the OLD side's answer,
		# turns again, and the walker gets stuck jittering at the ledge.
		_aim_rays()
	position.x += direction * speed * delta


func _aim_rays() -> void:
	floor_ray.position.x = direction * 9.0
	wall_ray.target_position.x = direction * 12.0
	floor_ray.force_raycast_update() # ask now, don't wait for the next physics step
	wall_ray.force_raycast_update()
