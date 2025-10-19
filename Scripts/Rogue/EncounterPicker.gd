extends Node
class_name EncounterPicker

@export var encounters: Array[Encounter] = []
@export var options_per_node: int = 3

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func get_random_options() -> Array[Encounter]:
	var pool: Array[Encounter] = encounters.duplicate()
	var picks: Array[Encounter] = []
	var k: int = int(min(options_per_node, pool.size()))

	for i in range(k):
		var total: float = 0.0
		for e in pool:
			total += max(e.weight, 0.0001)

		if total <= 0.0:
			break

		var roll: float = _rng.randf() * total
		var acc: float = 0.0
		var chosen_index: int = -1

		for j in range(pool.size()):
			acc += max(pool[j].weight, 0.0001)
			if roll <= acc:
				chosen_index = j
				break

		if chosen_index == -1:
			chosen_index = pool.size() - 1

		picks.append(pool[chosen_index])
		pool.remove_at(chosen_index)

	return picks
