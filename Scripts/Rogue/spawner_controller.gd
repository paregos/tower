# res://Scripts/Rogue/spawner_controller.gd
extends Node3D

@export var spawn_interval: float = 0.2  # seconds between mobs
@export var margin_from_edge: float = 0.1
@export var up_offset: float = 0.0
@export var ground_collision_mask: int = 1
@export_node_path("MeshInstance3D") var grass_path: NodePath

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()


# -----------------------------------------------------------------------------
# Public API: spawn_wave(entries)
# entries = [
#   {
#     "scene": PackedScene,   # from MobArchetype.scene
#     "count": int,
#     "config": Dictionary,   # passed into mob.setup()
#   },
#   ...
# ]
# -----------------------------------------------------------------------------
func spawn_wave(entries: Array) -> void:
	var grass: MeshInstance3D = get_node_or_null(grass_path) as MeshInstance3D
	if grass == null:
		push_warning("Spawner: grass_path not set; using node origin for spawn positions.")
	var center: Vector3 = _island_center(grass) if grass else global_transform.origin
	var radius: float = _island_radius(grass) if grass else 10.0

	for e in entries:
		var count: int = int(e.get("count", 1))
		for i in range(count):
			var pos: Vector3 = _spawn_point(center, radius)
			_spawn_one_entry_at(e, pos)
			if i < count - 1 and spawn_interval > 0.0:
				await get_tree().create_timer(spawn_interval).timeout


# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------
func _spawn_one_entry_at(e: Dictionary, pos: Vector3) -> void:
	var scene: PackedScene = e.get("scene", null)
	if scene == null:
		push_warning("Spawner: missing scene in entry: %s" % [e])
		return

	var mob := scene.instantiate()
	if mob.has_method("setup"):
		mob.setup(e.get("config", {}))
	add_child(mob)
	mob.global_position = pos
	# print("Spawned:", mob.name, "at", pos)


# -----------------------------------------------------------------------------
# Spawn point calculation (kept from your original)
# -----------------------------------------------------------------------------
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
