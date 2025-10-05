extends Node3D

@export var enemy_count: int = 3
@export var margin_from_edge: float = 0.1
@export var up_offset: float = 0
@export var ground_collision_mask: int = 1
@export_node_path("MeshInstance3D") var grass_path: NodePath
@export var monster_scene: PackedScene = preload("res://Scenes/skeleton.tscn")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	spawn_enemies()

func spawn_enemies() -> void:
	var grass: MeshInstance3D = get_node(grass_path) as MeshInstance3D
	var center: Vector3 = _island_center(grass)
	var radius: float = _island_radius(grass)

	for i in range(enemy_count):
		var pos: Vector3 = _spawn_point(center, radius)
		_spawn_monster(pos)

func _island_center(mesh: MeshInstance3D) -> Vector3:
	var aabb: AABB = mesh.get_aabb()
	var center_local: Vector3 = aabb.position + aabb.size * 0.5
	return mesh.to_global(center_local)

func _island_radius(mesh: MeshInstance3D) -> float:
	var aabb: AABB = mesh.get_aabb()
	var s: Vector3 = mesh.global_transform.basis.get_scale()
	var world_x: float = aabb.size.x * absf(s.x)
	var world_z: float = aabb.size.z * absf(s.z)
	return 0.5 * minf(world_x, world_z)

func _spawn_point(center: Vector3, radius: float) -> Vector3:
	var r: float = maxf(0.1, radius - margin_from_edge)
	var theta: float = rng.randf_range(0.0, TAU)
	var x: float = center.x + r * sin(theta)
	var z: float = center.z + r * cos(theta)
	var from: Vector3 = Vector3(x, center.y + 200.0, z)
	var to: Vector3   = Vector3(x, center.y - 200.0, z)
	return _raycast_down(from, to, center.y)

func _raycast_down(from: Vector3, to: Vector3, fallback_y: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = ground_collision_mask
	var hit: Dictionary = space.intersect_ray(params)

	if hit.has("position"):
		return hit["position"] + Vector3(0.0, up_offset, 0.0)

	# fallback if ray misses
	return Vector3(from.x, fallback_y + up_offset, from.z)

func _spawn_monster(pos: Vector3) -> void:
	var m: Node3D = monster_scene.instantiate() as Node3D
	add_child(m)
	m.global_position = pos
	print("spawn at ", pos)
	m.scale = Vector3(0.1, 0.1, 0.1)
