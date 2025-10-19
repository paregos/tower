extends Control
class_name WaveChoiceUI

# ─────────────────────────────────────────────────────────────────────────────
# Refs / State
# ─────────────────────────────────────────────────────────────────────────────
var _wr: Node = null
var dialog: AcceptDialog
var scroll: ScrollContainer
var list: VBoxContainer
var _mouse_mode_before: int = Input.MOUSE_MODE_VISIBLE

const TITLE_SIZE := 20
const BODY_SIZE := 14
const CARD_SPACING := 10
const CARD_PADDING := 10


# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Let clicks pass through the root; only the dialog should capture input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

	_build_ui()
	_bind_to_wave_runner_or_wait()


# ─────────────────────────────────────────────────────────────────────────────
# Bind to WaveRunner
# ─────────────────────────────────────────────────────────────────────────────
func _bind_to_wave_runner_or_wait() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("wave_runner")
	if nodes.size() > 0:
		_wr = nodes[0]
		_bind_to_wr()
		return

	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added, CONNECT_DEFERRED)

func _on_node_added(n: Node) -> void:
	if n.is_in_group("wave_runner"):
		_wr = n
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
		_bind_to_wr()

func _bind_to_wr() -> void:
	print("WaveChoiceUI: bound to WaveRunner @", _wr.get_path())

	# Disable WaveRunner auto-start if the property exists
	for p in _wr.get_property_list():
		if p.name == "auto_start_first_option":
			_wr.set("auto_start_first_option", false)
			break

	# Connect once to options_ready
	if _wr.has_signal("options_ready") and not _wr.options_ready.is_connected(_on_options_ready):
		_wr.options_ready.connect(_on_options_ready, CONNECT_DEFERRED)

	# Wait for GM before requesting options
	_connect_gm_and_request_when_started()


# ─────────────────────────────────────────────────────────────────────────────
# GameManager gating
# ─────────────────────────────────────────────────────────────────────────────
func _get_game_manager() -> Node:
	return get_tree().root.get_node_or_null("GameManager")

func _connect_gm_and_request_when_started() -> void:
	var GM := _get_game_manager()
	if GM == null:
		push_warning("WaveChoiceUI: GameManager not found; not requesting options.")
		return

	if GM.state == GM.State.PLAYING:
		_request_options_from_wr()
	else:
		if not GM.game_started.is_connected(_on_game_started):
			GM.game_started.connect(_on_game_started, CONNECT_DEFERRED)

func _on_game_started() -> void:
	_request_options_from_wr()

func _request_options_from_wr() -> void:
	if _wr and _wr.has_method("request_options"):
		_wr.request_options()


# ─────────────────────────────────────────────────────────────────────────────
# UI: options rendering / click handling
# ─────────────────────────────────────────────────────────────────────────────
func _on_options_ready(options: Array) -> void:
	print("WaveChoiceUI: options_ready with", options.size(), "option(s)")

	# Clear previous
	for c in list.get_children():
		c.queue_free()

	if options.is_empty():
		return

	list.add_theme_constant_override("separation", CARD_SPACING)

	for i in range(options.size()):
		var o: Dictionary = options[i] as Dictionary
		list.add_child(_make_card(o, i))

	# Show dialog and free the mouse
	_mouse_mode_before = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	dialog.popup_centered()
	dialog.show()

func _choose(index: int) -> void:
	dialog.hide()
	# Pick one of these:
	# Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)   # just hides the cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)    # hides + locks to window (good for gameplay)

	if _wr and _wr.has_method("start_encounter_by_index"):
		await _wr.start_encounter_by_index(index)

# ─────────────────────────────────────────────────────────────────────────────
# Card construction (simple Controls, no custom styleboxes)
# ─────────────────────────────────────────────────────────────────────────────
func _make_card(o: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", CARD_PADDING)
	pad.add_theme_constant_override("margin_right", CARD_PADDING)
	pad.add_theme_constant_override("margin_top", CARD_PADDING)
	pad.add_theme_constant_override("margin_bottom", CARD_PADDING)
	panel.add_child(pad)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	pad.add_child(vb)

	# Title
	var title := Label.new()
	title.text = String(o.get("title", "Encounter"))
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(title)

	# Spawns
	var spawns_any = o.get("spawns", [])
	var spawns: Array = spawns_any if spawns_any is Array else []
	if spawns.size() > 0:
		var sp_box := VBoxContainer.new()
		sp_box.add_theme_constant_override("separation", 2)
		for s_i in range(spawns.size()):
			var s: Dictionary = spawns[s_i] as Dictionary
			var row := Label.new()
			row.text = "• %s × %d  (HP %d  DMG %d  SPD %.2f)" % [
				String(s.get("mob","")),
				int(s.get("count",0)),
				int(s.get("health",0)),
				int(s.get("damage",0)),
				float(s.get("speed",0.0))
			]
			row.add_theme_font_size_override("font_size", BODY_SIZE)
			sp_box.add_child(row)
		vb.add_child(sp_box)

	# Rewards (optional)
	var rewards_any = o.get("rewards", {})
	var rewards: Dictionary = rewards_any if rewards_any is Dictionary else {}
	if int(rewards.get("gold",0)) > 0 or int(rewards.get("cards",0)) > 0:
		var r_lbl := Label.new()
		var tail := ""
		if int(rewards.get("cards",0)) > 0:
			tail = ", %d card(s)" % int(rewards.get("cards",0))
		r_lbl.text = "Rewards: %d gold%s" % [int(rewards.get("gold",0)), tail]
		r_lbl.add_theme_font_size_override("font_size", BODY_SIZE)
		vb.add_child(r_lbl)

	# Button row (right-aligned)
	var row_h := HBoxContainer.new()
	row_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_h.add_child(stretch)

	var choose := Button.new()
	choose.text = "Choose"
	choose.custom_minimum_size = Vector2(120, 36)
	choose.pressed.connect(func(): _choose(index))
	row_h.add_child(choose)

	vb.add_child(row_h)

	return panel


# ─────────────────────────────────────────────────────────────────────────────
# Dialog skeleton (AcceptDialog + Scroll + VBox)
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Create or get dialog
	dialog = get_node_or_null("WaveChooser") as AcceptDialog
	if dialog == null:
		dialog = AcceptDialog.new()
		dialog.name = "WaveChooser"
		dialog.title = "Choose Your Next Encounter"
		dialog.min_size = Vector2(560, 420)
		add_child(dialog)

	# Hide default OK button; we use per-card "Choose" buttons
	dialog.get_ok_button().visible = false

	# Make it modal and not dismissible by ESC or the titlebar close button
	dialog.exclusive = true
	dialog.dialog_close_on_escape = false  # Godot 4.x: disable ESC-to-close
	# Ignore the window close button (X)
	if not dialog.close_requested.is_connected(func(): pass):
		dialog.close_requested.connect(func(): pass)

	# Godot 4.3+: AcceptDialog doesn't have get_vbox() or get_content_area()
	# so create our own VBox container as the main content.
	var content: VBoxContainer = dialog.get_node_or_null("CustomContent") as VBoxContainer
	if content == null:
		content = VBoxContainer.new()
		content.name = "CustomContent"
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dialog.add_child(content) # attach it manually
		dialog.move_child(content, 0) # ensure it appears above the OK button

	# Add a scroll for long lists
	scroll = content.get_node_or_null("Scroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "Scroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content.add_child(scroll)

	# List inside the scroll
	list = scroll.get_node_or_null("List") as VBoxContainer
	if list == null:
		list = VBoxContainer.new()
		list.name = "List"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", CARD_SPACING)
		scroll.add_child(list)
