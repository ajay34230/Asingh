## In-game HUD: turn, messages, pause menu, result panel and frame rate.
class_name Hud
extends CanvasLayer

signal new_game_pressed
signal rematch_pressed
signal menu_pressed
signal settings_pressed
signal help_pressed
signal button_sound      ## any HUD button was pressed (the main scene plays the click)

const COLOR_HEX := {"red": "#e0444c", "green": "#43b861", "yellow": "#f7cd55", "blue": "#4f8ce6"}

var _turn: Label
var _message: Label
var _roll: Label
var _fps: Label
var _pause_panel: PanelContainer
var _result: PanelContainer
var _result_list: Label
var _pause_button: Button
var _banner: Label
var _caption: Label
var _caption_tween: Tween
var _banner_tween: Tween


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

	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 96)
	_banner.add_theme_constant_override("outline_size", 22)
	_banner.add_theme_color_override("font_outline_color", Color(0.2, 0.02, 0.02))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	root.add_child(_banner)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color("#fff1c8"))
	_caption.add_theme_stylebox_override("normal", RoyalTheme.badge(RoyalTheme.GOLD))
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.offset_top = 86
	_caption.visible = false
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_caption)

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
	b.pressed.connect(func() -> void: button_sound.emit())
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
	b.pressed.connect(func() -> void: button_sound.emit())
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


## Big title that pops in the middle of the screen (KNOCKOUT!, SIX!, HOME!).
func flash_banner(text: String, color: Color, seconds := 1.1) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 2.2
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_speed_scale(1.0 / maxf(Engine.time_scale, 0.05))  ## pops at normal speed during slow motion
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.parallel().tween_property(_banner, "modulate:a", 1.0, 0.12)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)


## Subtitle for the announcer, under the top bar: speaker icon text and a short fade.
func show_caption(text: String, seconds := 1.8) -> void:
	if text == "":
		return
	_caption.text = "~ " + text + " ~"
	_caption.visible = true
	_caption.modulate.a = 0.0
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.15)
	_caption_tween.tween_interval(seconds)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.4)
	_caption_tween.tween_callback(func() -> void: _caption.visible = false)
