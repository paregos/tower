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
	emit_signal("game_started")

func open_settings() -> void:
	emit_signal("settings_opened")

func pause_game() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)
		emit_signal("game_paused")

func resume_game() -> void:
	print("resumed game outer")
	if state == State.PAUSED:
		_set_state(State.PLAYING)
		print("resumed game")
		emit_signal("game_resumed")

func end_game() -> void:
	_set_state(State.GAMEOVER)
	emit_signal("game_over")

func _set_state(value: State) -> void:
	state = value
	# Optional: route UI visibility or pause tree here if you like
	get_tree().paused = (state == State.PAUSED)
