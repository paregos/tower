# Autoload: GameManager.gd
extends Node

enum State { MENU, PLAYING, PAUSED, GAMEOVER }
var state: State = State.MENU : set = _set_state

signal game_started
signal game_paused
signal game_resumed
signal game_over
signal settings_opened

func _ready() -> void:
	_set_state(State.MENU)

func start_game() -> void:
	_set_state(State.PLAYING)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
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
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		game_resumed.emit()

func end_game() -> void:
	_set_state(State.GAMEOVER)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_over.emit()

func _set_state(value: State) -> void:
	state = value
	if state == State.PAUSED:
		get_tree().paused = true
	else:
		get_tree().paused = false
