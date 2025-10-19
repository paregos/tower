extends Resource
class_name MobArchetype

@export var key: StringName            # "skeleton", "bat"
@export var scene: PackedScene         # e.g. res://Actors/Skeleton.tscn

# baseline stats (MobBase will use these unless overridden by config)
@export var base_health: int = 20
@export var base_damage: int = 5
@export var base_speed: float = 3.0
@export var base_attack_speed: float = 1.0
@export var base_attack_range: float = 1.0
@export var tint: Color = Color.WHITE
@export var scale: float = 1.0
