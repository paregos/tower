extends CharacterBody3D

@export var speed: float = 0.1
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var target: Vector3 = Vector3.ZERO  # (0, any_y, 0)

func _physics_process(delta: float) -> void:
	# Direction to target (ignore vertical)
	var dir := target - global_position
	dir.y = 0.0
	var dist := dir.length()

	if dist > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

		# Smooth yaw rotation to face movement
		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)
	else:
		# stop once close enough
		velocity.x = 0.0
		velocity.z = 0.0

	# let Y be controlled by gravity + collisions
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	#move_and_slide()
