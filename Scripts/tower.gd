extends Node3D

@export var attack_range: float = 20.0
@export var attack_interval: float = 2.0
@export var damage: int = 1
@export var target_group: String = "monsters"
@export var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
@export_node_path("Node3D") var muzzle_path: NodePath  # optional: where to spawn from (top of tower)

var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = attack_interval
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_attack_timeout)

func _on_attack_timeout() -> void:
	var target := _find_target()
	if target:
		_spawn_projectile(target)

func _find_target() -> Node3D:
	var closest: Node3D = null
	var closest_dist := INF
	for s in get_tree().get_nodes_in_group(target_group):
		if not s.is_inside_tree():
			continue
		var dist := global_position.distance_to(s.global_position)
		if dist < attack_range and dist < closest_dist:
			closest = s
			closest_dist = dist
	return closest

func _spawn_projectile(target: Node3D) -> void:
	if projectile_scene == null: return
	var p := projectile_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(p)

	# Spawn position (muzzle if set; otherwise tower origin)
	var spawn_pos := global_position
	if muzzle_path != NodePath():
		var muzzle := get_node(muzzle_path) as Node3D
		if muzzle: spawn_pos = muzzle.global_position

	p.global_position = spawn_pos
	# If your projectile script exposes these:
	if "target" in p:      p.target = target
	if "damage" in p:      p.damage = damage
