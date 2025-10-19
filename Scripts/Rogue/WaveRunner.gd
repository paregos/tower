# res://Rogue/WaveRunner.gd
extends Node
class_name WaveRunner

# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal options_ready(options: Array[Dictionary])   # emitted when options are generated for UI


# -----------------------------------------------------------------------------
# Exports / Config
# -----------------------------------------------------------------------------
@export var spawner_path: NodePath
@export var picker_path: NodePath
@export var auto_start_first_option: bool = true   # false when you have a UI picker


# -----------------------------------------------------------------------------
# Internal State
# -----------------------------------------------------------------------------
var _current_options: Array[Dictionary] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _enter_tree() -> void:
	add_to_group("wave_runner")  # earlier than _ready, so UI can find it


func _ready() -> void:
	add_to_group("wave_runner")

	var GM := _get_game_manager()
	if GM != null:
		_connect_to_game_manager(GM)
		# If the game already started before this scene loaded, begin immediately
		if GM.state == GM.State.PLAYING:
			_on_game_started()
	else:
		push_warning("WaveRunner: GameManager not found; starting immediately.")
		_request_and_maybe_start()


# -----------------------------------------------------------------------------
# GameManager hooks
# -----------------------------------------------------------------------------
func _get_game_manager() -> Node:
	# Autoloads live directly under the root viewport
	return get_tree().root.get_node_or_null("GameManager")

func _connect_to_game_manager(GM: Node) -> void:
	if not GM.game_started.is_connected(_on_game_started):
		GM.game_started.connect(_on_game_started)
	if not GM.game_over.is_connected(_on_game_over):
		GM.game_over.connect(_on_game_over)

func _on_game_started() -> void:
	print("WaveRunner: game_started detected")
	_request_and_maybe_start()

func _on_game_over() -> void:
	print("WaveRunner: game_over detected")
	_current_options.clear()


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
func request_options() -> void:
	_request_options()

func start_encounter_by_index(index: int) -> void:
	if index < 0 or index >= _current_options.size():
		push_warning("WaveRunner: option index out of range: %d" % index)
		return

	var id_str: String = String(_current_options[index].get("id", ""))
	if id_str == "":
		push_warning("WaveRunner: chosen option missing id.")
		return

	await start_encounter(StringName(id_str))

func start_encounter(encounter_id: StringName) -> void:
	var picker := _get_picker()
	var spawner := _get_spawner()
	if picker == null or spawner == null:
		push_warning("WaveRunner: picker or spawner not set.")
		return

	# Find the correct encounter by ID
	var enc: Resource = null
	var encs: Array = picker.get("encounters")
	if typeof(encs) == TYPE_ARRAY:
		for e in encs:
			if e.id == encounter_id:
				enc = e
				break
	if enc == null:
		push_warning("WaveRunner: encounter not found: %s" % String(encounter_id))
		return

	# Build entries for the spawner
	var entries: Array = []
	for s in enc.spawns:
		var cfg: Dictionary = {}

		cfg["health"]        = s.health_override       if s.health_override        >= 0    else int(s.mob.base_health)
		cfg["damage"]        = s.damage_override       if s.damage_override        >= 0    else int(s.mob.base_damage)
		cfg["speed"]         = s.speed_override        if s.speed_override         >= 0.0  else float(s.mob.base_speed)
		cfg["attack_speed"]  = s.attack_speed_override if s.attack_speed_override  >= 0.0  else float(s.mob.base_attack_speed)
		cfg["attack_range"]  = s.attack_range_override if s.attack_range_override  >= 0.0  else float(s.mob.base_attack_range)
		cfg["scale"]         = s.scale_override        if s.scale_override         >= 0.0  else float(s.mob.scale)
		cfg["tint"]          = s.tint_override         if s.tint_override.a        >  0.0  else s.mob.tint

		var entry := {
			"scene": s.mob.scene,             # direct scene from MobArchetype
			"count": int(s.count),
			"config": cfg,
			"key": StringName(s.mob.key)      # optional
		}
		entries.append(entry)

	print("WaveRunner: starting encounter '%s' with %d spawn groups" % [String(encounter_id), entries.size()])
	await spawner.call("spawn_wave", entries)


# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------
func _get_spawner() -> Node:
	return get_node_or_null(spawner_path)

func _get_picker() -> Node:
	return get_node_or_null(picker_path)

func _request_and_maybe_start() -> void:
	_request_options()
	if auto_start_first_option and _current_options.size() > 0:
		var id_str: String = String(_current_options[0].get("id", ""))
		if id_str != "":
			await start_encounter(StringName(id_str))

func _request_options() -> void:
	var picker := _get_picker()
	if picker == null:
		push_warning("WaveRunner: picker not set.")
		_current_options = []
		emit_signal("options_ready", _current_options)
		return

	# Expect EncounterPicker.get_random_options() -> Array[Encounter]
	var encs: Array = picker.call("get_random_options")
	var out: Array[Dictionary] = []

	for e in encs:
		var preview: Array[Dictionary] = []
		for s in e.spawns:
			var hp: int    = s.health_override  if s.health_override  >= 0    else int(s.mob.base_health)
			var dmg: int   = s.damage_override  if s.damage_override  >= 0    else int(s.mob.base_damage)
			var spd: float = s.speed_override   if s.speed_override   >= 0.0  else float(s.mob.base_speed)

			preview.append({
				"mob": String(s.mob.key),
				"count": int(s.count),
				"health": hp,
				"damage": dmg,
				"speed": spd
			})

		out.append({
			"id": String(e.id),
			"title": String(e.title),
			"description": String(e.description),
			"spawns": preview,
			"rewards": {
				"gold": int(e.reward_gold),
				"cards": int(e.reward_cards)
			}
		})

	_current_options = out
	print("WaveRunner: generated %d encounter options" % _current_options.size())
	emit_signal("options_ready", _current_options)
