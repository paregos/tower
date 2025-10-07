extends Control

# Panels
@onready var main_panel: VBoxContainer  = $CenterContainer/MainPanel
@onready var pause_panel: VBoxContainer = $CenterContainer/PausePanel

# Main panel buttons
@onready var start_btn: Button         = $CenterContainer/MainPanel/StartButton
@onready var settings_btn_main: Button = $CenterContainer/MainPanel/SettingsButton
@onready var quit_btn_app: Button      = $CenterContainer/MainPanel/QuitButton

# Pause panel buttons
@onready var settings_btn_pause: Button = $CenterContainer/PausePanel/SettingsButton
@onready var quit_to_menu_btn: Button   = $CenterContainer/PausePanel/QuitToMenuButton

func _ready() -> void:
	# Let this UI still receive input while paused (so ESC works if you use it here)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Buttons
	start_btn.pressed.connect(_on_start)
	settings_btn_main.pressed.connect(_on_settings)
	quit_btn_app.pressed.connect(_on_quit_app)

	settings_btn_pause.pressed.connect(_on_settings)
	quit_to_menu_btn.pressed.connect(_on_quit_to_menu)

	# Visibility rules driven by GameManager
	GameManager.game_started.connect(_refresh_panels)
	GameManager.game_paused.connect(_refresh_panels)
	GameManager.game_resumed.connect(_refresh_panels)
	GameManager.game_over.connect(_refresh_panels)

	# On boot (MENU), menu should be visible
	_set_menu_visible(true)
	_refresh_panels()

func _set_menu_visible(show: bool) -> void:
	visible = show
	# When hidden, ignore mouse so gameplay UI beneath is clickable
	mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
	if show:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _refresh_panels() -> void:
	# Overlay shown whenever not PLAYING
	var overlay_on := GameManager.state != GameManager.State.PLAYING
	_set_menu_visible(overlay_on)

	# Which panel to show?
	var in_menu := GameManager.state == GameManager.State.MENU or GameManager.state == GameManager.State.GAMEOVER
	main_panel.visible  = in_menu
	pause_panel.visible = (GameManager.state == GameManager.State.PAUSED)

func _on_start() -> void:
	GameManager.start_game() # signal triggers _refresh_panels

func _on_settings() -> void:
	var d := AcceptDialog.new()
	d.dialog_text = "Settings are coming soon! (mock)"
	add_child(d)
	d.popup_centered()

func _on_quit_app() -> void:
	get_tree().quit()

func _on_quit_to_menu() -> void:
	GameManager.reset_to_menu()

# ESC toggles pause here 
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if GameManager.state == GameManager.State.PLAYING:
			GameManager.pause_game()
		elif GameManager.state == GameManager.State.PAUSED:
			GameManager.resume_game()
