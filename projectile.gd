extends Node3D

@export var speed: float = 20.0
@export var lifetime: float = 2.0
@export var damage: int = 1
var target: Node3D = null

@onready var particles: CPUParticles3D = $CPUParticles3D

func _ready() -> void:
	if particles: particles.restart()   # fire the one-shot burst
	# auto-despawn after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta: float) -> void:
	# vanish if target disappeared
	if not target or not target.is_inside_tree():
		queue_free()
		return

	# fly toward target
	var dir := (target.global_position - global_position).normalized()
	global_position += dir * speed * delta
	look_at(target.global_position)

	# simple proximity hit
	if global_position.distance_to(target.global_position) < 0.5:
		if "take_damage" in target:
			target.take_damage(damage)
		queue_free()
