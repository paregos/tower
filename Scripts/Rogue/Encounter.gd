extends Resource
class_name Encounter

@export var id: StringName
@export var title: String
@export var description: String = ""
@export var spawns: Array[MobSpawn] = []
@export var weight: float = 1.0        # selection weight
@export var difficulty: float = 1.0    # used for scaling if you add it later
@export var reward_gold: int = 10
@export var reward_cards: int = 0
