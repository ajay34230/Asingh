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
	_banner.add_theme_font_size_override("font_size", 72)
	_banner.add_theme_constant_override("outline_size", 22)
	_banner.add_theme_color_override("font_outline_color", Color(0.2, 0.02, 0.02))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	## Upper third of the screen, so it never covers the fighters in the middle.
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.anchor_top = 0.02
	_banner.anchor_bottom = 0.16
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	root.add_child(_banner)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color("#fff1c8"))
	_caption.add_theme_stylebox_override("normal", RoyalTheme.badge(RoyalTheme.GOLD))
	## Subtitles sit just above the message line at the bottom, clear of banners and fighters.
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.offset_bottom = -78
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
	UiFx.button(b)
	return b


func _panel(parent: Control) -> Dictionary:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH   # stays centred as content grows
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	UiFx.ornaments(p)
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


var _result_title: Label
var _result_sub: Label
var _podium: VBoxContainer
var _coin_label: Label
var _coin_total: Label

const MEDALS := [Color("#ffd24a"), Color("#d8dde6"), Color("#cd7f45"), Color("#7a5a48")]
const PLACE_NAMES := ["1st", "2nd", "3rd", "4th"]


func _build_result(root: Control) -> void:
	var parts := _panel(root)
	_result = parts["panel"]
	_result.custom_minimum_size = Vector2(560, 0)
	var box: VBoxContainer = parts["box"]
	box.add_theme_constant_override("separation", 12)
	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var deco := FontVariation.new()
	deco.base_font = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	_result_title.add_theme_font_override("font", deco)
	_result_title.add_theme_font_size_override("font_size", 56)
	_result_title.add_theme_constant_override("outline_size", 14)
	box.add_child(_result_title)
	_result_sub = Label.new()
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_sub.add_theme_font_size_override("font_size", 22)
	box.add_child(_result_sub)
	_podium = VBoxContainer.new()
	_podium.add_theme_constant_override("separation", 8)
	box.add_child(_podium)
	## Coin reward that counts up, and the running total.
	var coins := HBoxContainer.new()
	coins.alignment = BoxContainer.ALIGNMENT_CENTER
	coins.add_theme_constant_override("separation", 12)
	box.add_child(coins)
	coins.add_child(_coin_icon(30))
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 40)
	_coin_label.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	coins.add_child(_coin_label)
	_coin_total = Label.new()
	_coin_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_total.add_theme_font_size_override("font_size", 20)
	_coin_total.add_theme_color_override("font_color", Color("#e8c98a"))
	box.add_child(_coin_total)
	_menu_button(box, "Rematch", func() -> void:
		_result.visible = false
		rematch_pressed.emit())
	_menu_button(box, "Main menu", func() -> void:
		_result.visible = false
		menu_pressed.emit())


## A gold coin drawn as a disc with a rim and an embossed star.
func _coin_icon(radius: float) -> Control:
	var c := CoinIcon.new()
	c.radius = radius
	c.custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	return c


class CoinIcon extends Control:
	var radius := 24.0
	func _draw() -> void:
		var o := size * 0.5
		draw_circle(o + Vector2(0, 3), radius, Color(0, 0, 0, 0.4))
		draw_circle(o, radius, Color("#b8801f"))
		draw_circle(o, radius * 0.86, Color("#f2c24e"))
		draw_arc(o, radius * 0.72, 0, TAU, 32, Color("#b8801f"), 2.0, true)
		var star := PackedVector2Array()
		for i in range(10):
			var r := radius * (0.48 if i % 2 == 0 else 0.2)
			var a := TAU * i / 10.0 - PI * 0.5
			star.append(o + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(star, Color("#fff0b0"))


func _menu_button(box: VBoxContainer, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.pressed.connect(func() -> void: button_sound.emit())
	b.pressed.connect(callback)
	box.add_child(b)
	UiFx.button(b)


func open_pause() -> void:
	if _result.visible:
		return
	_pause_panel.visible = true
	get_tree().paused = true
	UiFx.pop_in(_pause_panel)


func close_pause() -> void:
	_pause_panel.visible = false
	get_tree().paused = false


func set_turn(color: String, human: bool) -> void:
	var who := "You" if human else color.capitalize()
	_turn.text = "Turn: %s (%s)" % [who, color.capitalize()]
	_turn.add_theme_color_override("font_color", Color(COLOR_HEX.get(color, "#ffffff")).lightened(0.2))
	_turn.add_theme_stylebox_override("normal", RoyalTheme.badge(Color(COLOR_HEX.get(color, "#ffffff"))))
	## Slide the turn badge in from the left each turn.
	var x := 16.0
	_turn.position.x = -_turn.size.x
	_turn.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_turn, "position:x", x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_turn, "modulate:a", 1.0, 0.2)


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


## Results: a title, one podium row per player with a medal, then the coin reward
## counting up. `reward` is what the human earned; `total` the new balance.
func show_result(ranking: Array, reward := 0, total := 0) -> void:
	var human_place := 0
	var humans := 0
	for entry in ranking:
		if entry["human"]:
			humans += 1
			if human_place == 0:
				human_place = entry["place"]
	if humans == 1 and human_place == 1:
		_result_title.text = "Victory!"
		_result_sub.text = "The maharaja's crown is yours"
	elif humans == 1:
		_result_title.text = "%s place" % PLACE_NAMES[human_place - 1]
		_result_sub.text = "A fine game. Play again?"
	else:
		_result_title.text = "Game over"
		_result_sub.text = "%s wins the crown" % String(ranking[0]["color"]).capitalize()
	_result_title.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	for child in _podium.get_children():
		child.queue_free()
	for i in range(ranking.size()):
		var entry: Dictionary = ranking[i]
		var row := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(COLOR_HEX.get(entry["color"], "#888888")).darkened(0.55)
		style.border_color = MEDALS[mini(i, 3)]
		style.set_border_width_all(2)
		style.border_width_left = 8
		style.set_corner_radius_all(10)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", style)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		row.add_child(h)
		var medal := Label.new()
		medal.text = PLACE_NAMES[i]
		medal.custom_minimum_size = Vector2(64, 0)
		medal.add_theme_color_override("font_color", MEDALS[mini(i, 3)])
		medal.add_theme_font_size_override("font_size", 26 if i == 0 else 22)
		h.add_child(medal)
		var who := Label.new()
		who.text = ("You" if entry["human"] and humans == 1 else String(entry["color"]).capitalize()) + ("" if entry["human"] else "  (AI)")
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_theme_color_override("font_color", Color(COLOR_HEX.get(entry["color"], "#ffffff")).lightened(0.35))
		who.add_theme_font_size_override("font_size", 26 if i == 0 else 22)
		h.add_child(who)
		_podium.add_child(row)
		row.modulate.a = 0.0
		var t := row.create_tween()
		t.tween_interval(0.35 + i * 0.18)
		t.tween_property(row, "modulate:a", 1.0, 0.25)
	_result.visible = true
	_message.visible = false
	UiFx.pop_in(_result)
	## Coins count up after the podium has appeared.
	_coin_label.text = "+0"
	_coin_total.text = ""
	var count := create_tween()
	count.tween_interval(0.5 + ranking.size() * 0.18)
	count.tween_callback(func() -> void: _fly_coins(mini(12, maxi(3, reward / 10))))
	count.tween_method(func(v: float) -> void: _coin_label.text = "+%d" % int(v), 0.0, float(reward), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	count.tween_callback(func() -> void: _coin_total.text = "Treasury: %d coins" % total)


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


## Coins burst from the winner's row and fly into the coin counter.
func _fly_coins(count: int) -> void:
	if _podium.get_child_count() == 0:
		return
	var from_row: Control = _podium.get_child(0)
	var start := from_row.global_position + from_row.size * 0.5
	var target := _coin_label.global_position + Vector2(-30, _coin_label.size.y * 0.5)
	for i in range(count):
		var coin := _coin_icon(14)
		coin.top_level = true
		_result.add_child(coin)
		coin.global_position = start - Vector2(14, 14)
		var mid := start.lerp(target, 0.5) + Vector2(randf_range(-160, 160), randf_range(-120, -40))
		var arc := func(p: float) -> void:
			var a := start.lerp(mid, p)
			var b := mid.lerp(target, p)
			coin.global_position = a.lerp(b, p) - Vector2(14, 14)
		var t := coin.create_tween()
		t.tween_interval(i * 0.06)
		t.tween_method(arc, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(coin.queue_free)
		if i % 3 == 0:
			t.tween_callback(func() -> void: button_sound.emit())
