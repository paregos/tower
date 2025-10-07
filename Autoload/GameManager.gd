# Autoload: GameManager.gd
extends Node

enum State { MENU, PLAYING, PAUSED, GAMEOVER }
var state: State = State.MENU : set = _set_state

signal game_started
signal game_paused
signal game_resumed
signal game_over
signal settings_opened

@export var main_scene_path: String = "res://Scenes/main.tscn"

func _ready() -> void:
	# Let this autoload keep receiving input even while paused (ESC to unpause etc.)
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_set_state(State.MENU)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func start_game() -> void:
	_set_state(State.PLAYING)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # or VISIBLE if not FPS
	game_started.emit()

func open_settings() -> void:
	settings_opened.emit()

func pause_game() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		game_paused.emit()

func resume_game() -> void:
	if state == State.PAUSED:
		_set_state(State.PLAYING)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # or VISIBLE if not FPS
		game_resumed.emit()

func end_game() -> void:
	_set_state(State.GAMEOVER)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_over.emit()

func reset_to_menu() -> void:
	# Central reset: unpause, go to MENU state, reload the main scene
	get_tree().paused = false
	_set_state(State.MENU)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# If we’re already on main, just reload; else, change to it.
	var current := get_tree().current_scene
	if current and current.scene_file_path == main_scene_path:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(main_scene_path)

func _set_state(value: State) -> void:
	state = value
	get_tree().paused = (state == State.PAUSED)
