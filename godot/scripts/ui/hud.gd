## In-game HUD: turn, messages, pause menu, result panel and frame rate.
class_name Hud
extends CanvasLayer

signal new_game_pressed
signal rematch_pressed
signal menu_pressed
signal settings_pressed
signal help_pressed

const COLOR_HEX := {"red": "#e0444c", "green": "#43b861", "yellow": "#f7cd55", "blue": "#4f8ce6"}

var _turn: Label
var _message: Label
var _roll: Label
var _fps: Label
var _pause_panel: PanelContainer
var _result: PanelContainer
var _result_list: Label
var _pause_button: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  ## keeps working while the game tree is paused
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = RoyalTheme.build()
	add_child(root)

	_turn = _label(root, 22, Vector2(16, 12))
	_turn.add_theme_stylebox_override("normal", RoyalTheme.badge(RoyalTheme.GOLD))
	_roll = _label(root, 18, Vector2(20, 64))
	_fps = _label(root, 14, Vector2(16, 0))
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps.position = Vector2(16, -28)
	_fps.visible = false

	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 22)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_stylebox_override("normal", RoyalTheme.badge(RoyalTheme.GOLD))
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message.offset_bottom = -14
	root.add_child(_message)

	_pause_button = _button(root, "Pause", Vector2(150, 48), Vector2(-166, 12))
	_pause_button.pressed.connect(open_pause)
	_button(root, "New game", Vector2(150, 48), Vector2(-330, 12)).pressed.connect(func() -> void: new_game_pressed.emit())

	_build_pause(root)
	_build_result(root)


func _label(parent: Control, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, size: Vector2, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.position = pos
	parent.add_child(b)
	return b


func _panel(parent: Control) -> Dictionary:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.visible = false
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	return {"panel": p, "box": box}


func _build_pause(root: Control) -> void:
	var parts := _panel(root)
	_pause_panel = parts["panel"]
	var box: VBoxContainer = parts["box"]
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_menu_button(box, "Resume", func() -> void: close_pause())
	_menu_button(box, "Settings", func() -> void: settings_pressed.emit())
	_menu_button(box, "How to play", func() -> void: help_pressed.emit())
	_menu_button(box, "Restart game", func() -> void:
		close_pause()
		new_game_pressed.emit())
	_menu_button(box, "Quit to main menu", func() -> void:
		close_pause()
		menu_pressed.emit())


func _build_result(root: Control) -> void:
	var parts := _panel(root)
	_result = parts["panel"]
	var box: VBoxContainer = parts["box"]
	var title := Label.new()
	title.text = "Game over"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_result_list = Label.new()
	_result_list.add_theme_font_size_override("font_size", 20)
	box.add_child(_result_list)
	_menu_button(box, "Rematch", func() -> void:
		_result.visible = false
		rematch_pressed.emit())
	_menu_button(box, "Main menu", func() -> void:
		_result.visible = false
		menu_pressed.emit())


func _menu_button(box: VBoxContainer, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.pressed.connect(callback)
	box.add_child(b)


func open_pause() -> void:
	if _result.visible:
		return
	_pause_panel.visible = true
	get_tree().paused = true


func close_pause() -> void:
	_pause_panel.visible = false
	get_tree().paused = false


func set_turn(color: String, human: bool) -> void:
	var who := "You" if human else color.capitalize()
	_turn.text = "Turn: %s (%s)" % [who, color.capitalize()]
	_turn.add_theme_color_override("font_color", Color(COLOR_HEX.get(color, "#ffffff")).lightened(0.2))
	_turn.add_theme_stylebox_override("normal", RoyalTheme.badge(Color(COLOR_HEX.get(color, "#ffffff"))))


func set_roll(text: String) -> void:
	_roll.text = text


func set_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


func set_fps_visible(on: bool) -> void:
	_fps.visible = on


func _process(_delta: float) -> void:
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()


func show_result(ranking: Array) -> void:
	var lines: Array[String] = []
	for entry in ranking:
		var who: String = "You" if entry["human"] else String(entry["color"]).capitalize()
		lines.append("%d. %s" % [entry["place"], who])
	_result_list.text = "\n".join(lines)
	_result.visible = true


func hide_result() -> void:
	_result.visible = false
