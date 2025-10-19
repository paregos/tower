extends Resource
class_name MobSpawn

@export var mob: MobArchetype
@export var count: int = 1

# Optional per-encounter overrides (use -1 / <0 to mean “no override”)
@export var health_override: int = -1
@export var damage_override: int = -1
@export var speed_override: float = -1.0
@export var attack_speed_override: float = -1.0
@export var attack_range_override: float = -1.0
@export var scale_override: float = -1.0
@export var tint_override: Color = Color(0,0,0,0) # transparent = no override
