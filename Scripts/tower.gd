# res://Scripts/Tower.gd
extends Node3D

# Outgoing attack
@export var attack_range: float = 20.0
@export var attack_interval: float = 1.0
@export var damage: int = 1
@export var target_group: String = "monsters"
@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export_node_path("Node3D") var muzzle_path: NodePath  # optional spawn point

# Incoming damage
@export var max_health: int = 20
var health: int

var _timer: Timer

func _ready() -> void:
	add_to_group("tower")
	health = max_health

	_timer = Timer.new()
	_timer.wait_time = attack_interval
	_timer.one_shot = false
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(_on_attack_timeout)

func take_damage(amount: int) -> void:
	print("tower take damage: ", amount)
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	print("Tower died (mock)")
	# queue_free()  # enable when you want towers to be removable

func _on_attack_timeout() -> void:
	var target := _find_target()
	if target:
		_spawn_projectile(target)

func _find_target() -> Node3D:
	var closest: Node3D = null
	var closest_dist := INF
	for n in get_tree().get_nodes_in_group(target_group):
		if not (n is Node3D) or not n.is_inside_tree():
			continue
		var d := global_position.distance_to((n as Node3D).global_position)
		if d < attack_range and d < closest_dist:
			closest = n
			closest_dist = d
	return closest

func _spawn_projectile(target: Node3D) -> void:
	if projectile_scene == null:
		return

	var p := projectile_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(p)

	var spawn_pos := global_position
	if muzzle_path != NodePath():
		var muzzle := get_node_or_null(muzzle_path) as Node3D
		if muzzle:
			spawn_pos = muzzle.global_position

	p.global_position = spawn_pos

	if "target" in p:
		p.target = target
	if "damage" in p:
		p.damage = damage
