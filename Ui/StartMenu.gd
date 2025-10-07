# StartMenu.gd
extends Control

@onready var start_btn: Button = $CenterContainer/VBoxContainer/StartButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	# Let this UI still receive input while paused (so ESC works if you use it here)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Buttons
	start_btn.pressed.connect(_on_start)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	# Visibility rules:
	# - Hide on game start
	# - (Optional) show when paused, hide when resumed
	# - Show on game over / back to menu
	GameManager.game_started.connect(func(): _set_menu_visible(false))
	GameManager.game_paused.connect(func(): _set_menu_visible(true))
	GameManager.game_resumed.connect(func(): _set_menu_visible(false))
	GameManager.game_over.connect(func(): _set_menu_visible(true))

	# On boot (MENU), menu should be visible
	_set_menu_visible(true)

func _set_menu_visible(show: bool) -> void:
	visible = show
	# When hidden, ignore mouse so gameplay UI beneath is clickable
	mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE

func _on_start() -> void:
	GameManager.start_game()  # the signal above will hide us

func _on_settings() -> void:
	var d := AcceptDialog.new()
	d.dialog_text = "Settings are coming soon! (mock)"
	add_child(d)
	d.popup_centered()

func _on_quit() -> void:
	get_tree().quit()

# If you want ESC to toggle pause from here (optional; you can also do this in GameManager)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if GameManager.state == GameManager.State.PLAYING:
			GameManager.pause_game()
		elif GameManager.state == GameManager.State.PAUSED:
			GameManager.resume_game()
