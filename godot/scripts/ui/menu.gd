## Front-end menus: main menu, game setup (mode, players, AI difficulty, house rules),
## settings (graphics, camera, animation, audio, haptics, language) and how-to-play.
## Online play is shown but disabled: it needs a server, which is not built yet.
class_name GameMenu
extends Control

signal start_game(config: Dictionary)
signal settings_changed
signal quit_requested
signal closed
signal board_theme_changed
signal design_changed            ## token design or its style changed: re-dress the tokens
signal campaign_start(index: int)
signal resume_requested

const HOW_TO_PLAY := """Royal India Ludo

GOAL
Move all four of your tokens from your courtyard, around the board and into the centre.

ROLLING
Tap the dice. The number is decided by the game.

LEAVING THE COURTYARD
A six brings a token onto the start square (house rule: can be turned off).

MOVING
Tap a glowing token to move it by the number you rolled. A token in the home column must land exactly on the centre.

CAPTURING
Land on an opponent's token on a normal square to send it back to its courtyard. Stars and start squares are safe.

BONUS ROLLS
Rolling a six gives another roll. Capturing and reaching the centre can also give one (house rules).

THREE SIXES
Three sixes in a row lose your turn (house rule).

WINNING
The first to bring all four tokens home ranks first. The game ends when one player is left.
"""

const RULE_LABELS := {
	"six_to_start": "A six is needed to leave the courtyard",
	"three_sixes_penalty": "Three sixes in a row lose the turn",
	"capture_bonus": "Capturing gives another roll",
	"home_bonus": "Reaching the centre gives another roll",
	"quick_end": "Quick game: ends at the first finish",
}

var _pages: Dictionary = {}
var _page := ""
var _players: OptionButton
var _difficulty: OptionButton
var _rule_boxes: Dictionary = {}
var _graphics: OptionButton
var _camera: CheckButton
var _anim: OptionButton
var _fps: CheckButton
var _music: HSlider
var _sfx: HSlider
var _mute: CheckButton
var _haptics: CheckButton
var _language: OptionButton
var _voice: CheckButton
var _timer: CheckButton
var _cb: CheckButton
var _big: CheckButton
var _relax: CheckButton
var _mode := "ai"
var _audio: AudioManager
var _overlay := false
var _resume_button: Button
var _panels := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = RoyalTheme.build()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.01, 0.01, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_add_petals()
	_build_main()
	_build_setup()
	_build_settings()
	_build_howto()
	_build_themes()
	_build_rewards()
	_build_profile()
	_build_journey()
	_build_modes()
	show_page("main")


## The menu covers the whole window. Controls inside a CanvasLayer need an explicit size.
func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func set_audio(manager: AudioManager) -> void:
	_audio = manager


## Overlay mode: opened from the pause menu. Back returns to the game instead of the main menu.
func set_overlay(on: bool) -> void:
	_overlay = on


func _back() -> void:
	if _overlay:
		_overlay = false
		closed.emit()
	else:
		show_page("main")


func show_page(name: String) -> void:
	if _audio and name != _page:
		_audio.play("ui_back" if name == "main" else "ui_open", 0.02, -4.0)
	_page = name
	for key in _pages:
		(_pages[key] as Control).visible = key == name
	if _panels.has(name) and is_inside_tree():
		var panel: Control = _panels[name]
		await get_tree().process_frame   # sizes are ready one frame after showing
		_fit_scroll(name)
		UiFx.pop_in(panel)
		UiFx.cascade(panel.find_children("*", "Button", true, false).slice(0, 14))
		if name == "main" and _logo:
			_logo.modulate.a = 0.0
			_logo.position.x -= 60.0
			var t := _logo.create_tween().set_parallel(true)
			t.tween_property(_logo, "modulate:a", 1.0, 0.6)
			t.tween_property(_logo, "position:x", _logo.position.x + 60.0, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Every page: a panel with a close (X) button and a scrolling content area. Pages that
## fit need no scrolling; longer ones scroll by swiping or by the gold scrollbar.
var _scrolls := {}


func _page_root(name: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	panel.add_child(frame)
	var top := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 52)
	close.tooltip_text = "Close"
	close.pressed.connect(func() -> void:
		if _audio:
			_audio.play("ui_click", 0.03)
		_back())
	top.add_child(close)
	frame.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	UiFx.ornaments(panel)
	_panels[name] = panel
	_pages[name] = center
	_scrolls[name] = scroll
	center.visible = false
	return box


## Fits a page's scroll area to its content, up to most of the screen height.
## The page frame (outside the scroll area) that holds a scroll page's content.
static func _frame_of(inner: Control) -> VBoxContainer:
	var n: Node = inner
	while n and not (n is ScrollContainer):
		n = n.get_parent()
	return n.get_parent() as VBoxContainer


func _fit_scroll(name: String) -> void:
	if not _scrolls.has(name):
		return
	var scroll: ScrollContainer = _scrolls[name]
	var content: Control = scroll.get_child(0)
	var panel: Control = _panels[name]
	## Room left for the list = screen height minus everything else on the panel.
	var overhead := panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	var limit := get_viewport_rect().size.y * 0.95 - overhead
	scroll.custom_minimum_size = Vector2(maxf(600.0, content.get_combined_minimum_size().x), clampf(content.get_combined_minimum_size().y, 120.0, maxf(limit, 120.0)))
	scroll.scroll_vertical = 0


func _title(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	l.add_theme_constant_override("outline_size", 10)
	box.add_child(l)


func _button(box: VBoxContainer, text: String, callback: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.disabled = not enabled
	b.pressed.connect(func() -> void:
		if _audio:
			_audio.play("ui_click", 0.03))
	b.pressed.connect(callback)
	b.mouse_filter = Control.MOUSE_FILTER_PASS   # a swipe that starts on a button still scrolls
	box.add_child(b)
	UiFx.button(b)
	return b


func _option(box: VBoxContainer, label: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		o.add_item(str(item))
	row.add_child(o)
	box.add_child(row)
	return o


func _check(box: VBoxContainer, text: String, value: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	box.add_child(c)
	return c


func _slider(box: VBoxContainer, label: String, lo: float, hi: float, value: float) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1.0
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	box.add_child(row)
	return s


const LOGO_SHADER := """
shader_type canvas_item;
// Gold leaf: a vertical gradient with a bright band near the top, plus a shimmer
// sweeping across. Only the light fill is coloured; the dark outline is kept.
uniform vec4 deep : source_color = vec4(0.78, 0.5, 0.14, 1.0);
uniform vec4 mid : source_color = vec4(0.95, 0.76, 0.32, 1.0);
uniform vec4 bright : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform float top = 0.0;
uniform float height = 100.0;
void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.33));
	float y = clamp((SCREEN_UV.y - top) / height, 0.0, 1.0);
	vec3 g = y < 0.35 ? mix(bright.rgb, mid.rgb, y / 0.35) : mix(mid.rgb, deep.rgb, (y - 0.35) / 0.65);
	float sweep = fract(TIME * 0.18) * 3.0 - 1.0;
	float shine = smoothstep(0.08, 0.0, abs(SCREEN_UV.x - sweep - (y - 0.5) * 0.2));
	g = mix(g, bright.rgb, shine * 0.8);
	COLOR = vec4(mix(c.rgb, g, step(0.45, lum)), c.a);
}
"""

var _logo: Control


func _build_main() -> void:
	## Title screen: logo on the left over the live 3D palace, menu column on the right.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_pages["main"] = root
	root.visible = false

	## Soft dark glow behind the logo so it reads over the busy board.
	var glow := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.05, 0.0, 0.01, 0.8), Color(0.05, 0.0, 0.01, 0.0)])
	grad.gradient = g
	glow.texture = grad
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.anchor_left = -0.05
	glow.anchor_right = 0.62
	glow.anchor_top = 0.12
	glow.anchor_bottom = 0.88
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	var logo := VBoxContainer.new()
	logo.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	logo.anchor_left = 0.04
	logo.anchor_right = 0.56
	logo.anchor_top = 0.16
	logo.anchor_bottom = 0.84
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	_logo = logo
	var deco := FontVariation.new()
	deco.base_font = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	(deco.base_font as FontFile).fallbacks = RoyalTheme.indic_fallbacks()
	var shader := Shader.new()
	shader.code = LOGO_SHADER
	for line in [["ROYAL", 70], ["INDIA LUDO", 96]]:
		var l := Label.new()
		l.text = line[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", deco)
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.22, 0.05, 0.02))
		l.add_theme_constant_override("outline_size", 18)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 8)
		l.add_theme_constant_override("shadow_outline_size", 22)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		l.material = mat
		l.resized.connect(func() -> void:
			var vh := get_viewport_rect().size.y
			mat.set_shader_parameter("top", (l.global_position.y + l.size.y * 0.18) / vh)
			mat.set_shader_parameter("height", l.size.y * 0.64 / vh))
		logo.add_child(l)
	var rule := HBoxContainer.new()
	rule.alignment = BoxContainer.ALIGNMENT_CENTER
	rule.add_theme_constant_override("separation", 14)
	for part in ["line", "gem", "line"]:
		var r := ColorRect.new()
		r.color = RoyalTheme.GOLD if part == "line" else Color("#c0182c")
		r.custom_minimum_size = Vector2(150, 3) if part == "line" else Vector2(14, 14)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.rotation = 0.0 if part == "line" else PI / 4.0
		rule.add_child(r)
	logo.add_child(rule)
	var fest := Festivals.current()
	if fest != "":
		var fl := Label.new()
		fl.text = tr(Festivals.FESTIVALS[fest][1]) + "\n" + tr("Double coins this festival!")
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.add_theme_font_size_override("font_size", 24)
		fl.add_theme_color_override("font_color", Color("#ffd27a"))
		logo.add_child(fl)
		logo.move_child(fl, 0)
	var sub := Label.new()
	sub.text = "The Game of Maharajas"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color("#f6dfb0"))
	logo.add_child(sub)

	_coin_badge = Label.new()
	_coin_badge.add_theme_stylebox_override("normal", RoyalTheme.badge(RoyalTheme.GOLD))
	_coin_badge.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	_coin_badge.add_theme_font_size_override("font_size", 24)
	_coin_badge.position = Vector2(24, 18)
	root.add_child(_coin_badge)
	_update_coin_badge()
	var panel := PanelContainer.new()
	panel.anchor_left = 0.6
	panel.anchor_right = 0.96
	panel.anchor_top = 0.03
	panel.anchor_bottom = 0.97
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	UiFx.ornaments(panel)
	_panels["main"] = panel
	_resume_button = _button(box, "Resume game", func() -> void: resume_requested.emit())
	_resume_button.visible = false
	_button(box, "Royal Journey", func() -> void: _refresh_journey(); show_page("journey"))
	_button(box, "Play vs AI", func() -> void: _open_setup("ai"))
	_button(box, "Pass and play", func() -> void: _open_setup("pass"))
	_button(box, "More modes", func() -> void: show_page("modes"))
	_button(box, "Royal Bazaar", func() -> void: _refresh_themes(); show_page("themes"))
	_button(box, "Rewards", func() -> void: _refresh_rewards(); show_page("rewards"))
	_button(box, "Profile", func() -> void: _refresh_profile(); show_page("profile"))
	_button(box, "How to play", func() -> void: show_page("howto"))
	_button(box, "Settings", func() -> void: _load_settings_into_controls(); show_page("settings"))
	_button(box, "Quit", func() -> void: quit_requested.emit())
	for b in box.get_children():
		(b as Button).custom_minimum_size = Vector2(0, 44)   # ten choices must fit a phone screen


func _build_setup() -> void:
	var box := _page_root("setup")
	_title(box, "Game setup")
	_players = _option(box, "Players", ["2 players", "3 players", "4 players"])
	_difficulty = _option(box, "AI difficulty", AiController.DIFFICULTY_NAMES)
	var rules := GameSettings.get_rules()
	for key in RULE_LABELS:
		_rule_boxes[key] = _check(box, RULE_LABELS[key], rules[key])
	_button(box, "Start", _start_from_setup)
	_button(box, "Back", func() -> void: _back())


func _build_settings() -> void:
	var box := _scroll_page("settings", "Settings")
	var page_box: VBoxContainer = _frame_of(box)
	_graphics = _option(box, "Graphics", ["Low", "Medium", "High"])
	_camera = _check(box, "Tilted 3D camera", true)
	_anim = _option(box, "Animation speed", ["Slow", "Normal", "Fast"])
	_fps = _check(box, "Show frame rate", false)
	_music = _slider(box, "Music volume", -40, 0, -10)
	_sfx = _slider(box, "Sound effects", -40, 0, -2)
	_mute = _check(box, "Mute all sound", false)
	_haptics = _check(box, "Vibration", true)
	_voice = _check(box, "Voice commentary (Hindi)", true)
	_timer = _check(box, "Turn timer (20 s)", true)
	_cb = _check(box, "Colour-blind symbols", false)
	_big = _check(box, "Larger text", false)
	_relax = _check(box, "Relaxed AI pace", false)
	var names: Array = []
	for l in I18n.LANGUAGES:
		names.append(l[1])
	_language = _option(box, "Language", names)
	for c in [_graphics, _anim, _language]:
		(c as OptionButton).item_selected.connect(func(_i: int) -> void: _save_settings())
	for c in [_camera, _fps, _mute, _haptics, _voice, _timer, _cb, _big, _relax]:
		(c as CheckButton).toggled.connect(func(_b: bool) -> void: _save_settings())
	_music.value_changed.connect(func(_v: float) -> void: _save_settings())
	_sfx.value_changed.connect(func(_v: float) -> void: _save_settings())
	_button(page_box, "Back", func() -> void: _back())


var _shop_rows: Dictionary = {}
var _shop_coins: Label
var _preview_token: TransformerToken
var _preview_pivot: Node3D
var _preview_label: Label
var _preview_action: Button          ## equip ("Use this design" / "Equipped")
var _preview_buy: Button
var _preview_video: Button
var _preview_ticket: Button
var _preview_trial: Button
var _preview_status: Label
var _style_box: VBoxContainer
var _metal_row: HBoxContainer
var _aura_row: HBoxContainer
var _status_tick := 0.0
var _preview_id := "design_classic"
var _rewards_box: VBoxContainer
var _coin_badge: Label


func _scroll_page(name: String, title: String) -> VBoxContainer:
	## The title sits above the scrolling list; Back goes below it (callers use the frame).
	var box := _page_root(name)
	var frame: VBoxContainer = box.get_parent().get_parent()
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 40)
	head.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	head.add_theme_constant_override("outline_size", 10)
	frame.add_child(head)
	frame.move_child(head, 1)
	var holder := VBoxContainer.new()   # keeps get_parent().get_parent() == frame for callers
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 8)
	box.add_child(holder)
	return holder


## Royal Bazaar: themes, dice and token skins. Owned items are equipped with a tap;
## others are bought with coins.
func _build_themes() -> void:
	var inner := _scroll_page("themes", "Royal Bazaar")
	var page_box: VBoxContainer = _frame_of(inner)
	_shop_coins = Label.new()
	_shop_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_coins.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	page_box.add_child(_shop_coins)
	page_box.move_child(_shop_coins, 1)
	_build_design_preview(inner)
	for kind in [["design", "Token designs"], ["theme", "Board themes"], ["dice", "Dice"], ["tokens", "Your tokens"], ["victory", "Victory effect"], ["trail", "Dice trail"]]:
		var head := Label.new()
		head.text = kind[1]
		head.add_theme_font_size_override("font_size", 26)
		head.add_theme_color_override("font_color", Color("#f3d9a8"))
		inner.add_child(head)
		for id in Progress.SHOP:
			if Progress.SHOP[id][0] != kind[0]:
				continue
			var b := _button(inner, "", func() -> void: _shop_pressed(id))
			b.custom_minimum_size = Vector2(600, 54)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_shop_rows[id] = b
	_button(page_box, "Back", func() -> void: _back())


func _shop_pressed(id: String) -> void:
	var kind: String = Progress.SHOP[id][0]
	if kind == "design":
		_preview_design(id)
		return
	if not Progress.owns(id):
		var r := Progress.buy(id)
		if r == "coins":
			_shop_coins.text = "Not enough coins: win games and claim daily rewards"
			if _audio:
				_audio.play("error", 0.0, -4.0)
			return
		if _audio:
			_audio.play("coins", 0.03)
	if kind == "theme":
		BoardThemes.set_current(id.trim_prefix("theme_"))
	else:
		Progress.equip(id)
	_refresh_themes()
	board_theme_changed.emit()   # rebuild the scene with the new look


func _refresh_themes() -> void:
	if _shop_coins == null:
		return
	_shop_coins.text = tr("Treasury: %d coins") % Progress.coins() + "   ·   " + tr("Royal Tickets: %d") % Progress.tickets()
	for id in _shop_rows:
		var item: Array = Progress.SHOP[id]
		var equipped := false
		if item[0] == "theme":
			equipped = BoardThemes.current_id() == id.trim_prefix("theme_")
		else:
			equipped = Progress.equipped(item[0]) == id
		if item[0] == "design":
			var r: Array = TokenDesigns.RARITY[TokenDesigns.rarity_of(id)]
			(_shop_rows[id] as Button).add_theme_color_override("font_color", (r[1] as Color).lightened(0.2))
			item = [item[0], "%s  [%s]" % [tr(item[1]), tr(r[0])], item[2]]
		var state := tr("Equipped") if equipped else (tr("Owned: tap to use") if Progress.owns(id) else tr("%d coins") % item[2])
		if not Progress.owns(id) and Progress.time_left(id) > 0:
			state = (tr("Equipped") + ", " if equipped else "") + tr("Rented: %s left") % Progress.format_time(Progress.time_left(id))
		(_shop_rows[id] as Button).text = "   %s      -      %s" % [tr(item[1]), state]


## Rewards: daily reward, achievements and lifetime stats.
func _build_rewards() -> void:
	_rewards_box = _scroll_page("rewards", "Rewards")
	var page_box: VBoxContainer = _frame_of(_rewards_box)
	_button(page_box, "Back", func() -> void: _back())


func _refresh_rewards() -> void:
	for c in _rewards_box.get_children():
		c.queue_free()
	var daily := Progress.daily_status()
	var claim := _button(_rewards_box, (tr("Claim daily reward: day %d, %d coins") % [int(daily[1]) + 1, daily[2]]) if daily[0] else tr("Daily reward claimed. Come back tomorrow!"), func() -> void:
		var got := Progress.claim_daily()
		if got > 0 and _audio:
			_audio.play("coins", 0.03)
		_refresh_rewards()
		_update_coin_badge())
	claim.disabled = not daily[0]
	var days := Label.new()
	var parts: Array[String] = []
	for i in range(7):
		parts.append(("[%d]" if i == int(daily[1]) else "%d") % Progress.DAILY[i])
	days.text = tr("7-day streak:") + "  " + "  ".join(parts)
	days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days.add_theme_font_size_override("font_size", 18)
	_rewards_box.add_child(days)
	var fest := Festivals.current()
	if fest != "":
		var fl := Label.new()
		fl.text = tr(Festivals.FESTIVALS[fest][1]) + "  ·  " + tr("Double coins this festival!")
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.add_theme_color_override("font_color", Color("#ffd27a"))
		_rewards_box.add_child(fl)
	var wh := Label.new()
	wh.text = tr("This week's challenges")
	wh.add_theme_font_size_override("font_size", 26)
	wh.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	_rewards_box.add_child(wh)
	var wp := Festivals.week_progress()
	for id in Festivals.this_week():
		var c: Array = Festivals.CHALLENGES[id]
		var done: bool = (wp.get("done", []) as Array).has(id)
		var row := Label.new()
		row.text = ("[done]  " if done else "[    ]  ") + "%s   %d/%d   (+%d)" % [tr(c[0]), mini(int(wp.get(c[2], 0)), int(c[1])), c[1], c[3]]
		row.add_theme_font_size_override("font_size", 19)
		row.add_theme_color_override("font_color", Color("#ffe39a") if done else Color("#f3e3c0"))
		_rewards_box.add_child(row)
	var st := Progress.stats()
	var stats := Label.new()
	stats.text = (tr("Games %d   Wins %d   Win rate %d%%   Best streak %d") % [st["games"], st["wins"], (100 * st["wins"] / maxi(1, st["games"])), st["best_streak"]]) \
		+ "\n" + (tr("Captures %d   Tokens lost %d   Tokens home %d   Sixes %d") % [st["captures"], st["lost"], st["home"], st["sixes"]])
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", Color("#f3e3c0"))
	_rewards_box.add_child(stats)
	var unlocked := Progress.unlocked()
	var head := Label.new()
	head.text = tr("Achievements  %d / %d") % [unlocked.size(), Progress.ACHIEVEMENTS.size()]
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	_rewards_box.add_child(head)
	for id in Progress.ACHIEVEMENTS:
		var a: Array = Progress.ACHIEVEMENTS[id]
		var row := Label.new()
		var done := unlocked.has(id)
		row.text = ("[done]  " if done else "[    ]  ") + "%s: %s   (+%d)" % [tr(a[0]), tr(a[1]), a[2]]
		row.add_theme_font_size_override("font_size", 19)
		row.add_theme_color_override("font_color", Color("#ffe39a") if done else Color(0.85, 0.75, 0.65, 0.75))
		_rewards_box.add_child(row)


## Extra modes, each with a one-line description.
func _build_modes() -> void:
	var box := _page_root("modes")
	_title(box, "More modes")
	var modes := [
		["Quick play", "2 players, ends at the first token home", {"quick_end": true}, 2, "ai"],
		["Team battle 2v2", "You and a partner against two rivals", {"teams": true}, 4, "team"],
		["Snakes & Ludo", "Ladders lift you, snakes drop you back", {"snakes": true}, 4, "ai"],
		["Power-up Ludo", "Collect shields and extra rolls on the track", {"powerups": true}, 4, "ai"],
		["Blitz", "8 seconds a turn: think fast!", {"blitz": true}, 4, "ai"],
	]
	for m in modes:
		var spec: Array = m
		_button(box, spec[0], func() -> void:
			var rules := GameSettings.get_rules()
			for k in ["quick_end", "teams", "snakes", "powerups", "blitz"]:
				rules[k] = false
			for k in spec[2]:
				rules[k] = spec[2][k]
			start_game.emit({"mode": spec[4], "players": spec[3], "difficulty": GameSettings.get_option("difficulty"), "rules": rules}))
		var d := Label.new()
		d.text = spec[1]
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 16)
		d.add_theme_color_override("font_color", Color("#e8cfa0"))
		box.add_child(d)
	_button(box, "Play with friends (Wi-Fi)", func() -> void: _open_lan())
	_button(box, "Back", func() -> void: _back())


var net: NetPlay
var _lan_box: VBoxContainer
var _lan_hosts: VBoxContainer
var _lan_lobby: Label
var _lan_start: Button
var _lan_ip: LineEdit
var _lan_status: Label


func _build_lan() -> void:
	_lan_box = _scroll_page("lan", "Play with friends")
	var page_box: VBoxContainer = _frame_of(_lan_box)
	_lan_status = Label.new()
	_lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lan_status.custom_minimum_size = Vector2(600, 0)
	_lan_box.add_child(_lan_status)
	_button(_lan_box, "Host a game", func() -> void:
		if net.host(Progress.player_name()) == OK:
			_lan_status.text = tr("Hosting. Friends on the same Wi-Fi can join. Your address: %s") % NetPlay.local_address()
		else:
			_lan_status.text = tr("Could not host a game"))
	var found := Label.new()
	found.text = tr("Games nearby")
	found.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	_lan_box.add_child(found)
	_lan_hosts = VBoxContainer.new()
	_lan_box.add_child(_lan_hosts)
	var row := HBoxContainer.new()
	_lan_ip = LineEdit.new()
	_lan_ip.placeholder_text = "192.168.1.20"
	_lan_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_lan_ip)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(func() -> void: _join(_lan_ip.text.strip_edges()))
	row.add_child(join)
	_lan_box.add_child(row)
	_lan_lobby = Label.new()
	_lan_box.add_child(_lan_lobby)
	_lan_start = _button(_lan_box, "Start the game", func() -> void:
		var rules := GameSettings.get_rules()
		for k in ["quick_end", "teams", "snakes", "powerups", "blitz"]:
			rules[k] = false
		net.start(GameSettings.get_option("difficulty"), rules, 4 if net._players.size() > 2 else 2))
	_lan_start.visible = false
	_button(page_box, "Back", func() -> void:
		net.discover(false)
		net.leave()
		_back())
	net.hosts_found.connect(_show_hosts)
	net.lobby_changed.connect(func(players: Array) -> void:
		var names: Array[String] = []
		for pl in players:
			names.append(String(pl["name"]))
		_lan_lobby.text = tr("Players: %s") % ", ".join(names)
		_lan_start.visible = net.is_host and players.size() >= 2)
	net.disconnected.connect(func(reason: String) -> void: _lan_status.text = tr(reason))


func _open_lan() -> void:
	_lan_status.text = tr("Host a game, or join a friend's game on the same Wi-Fi.")
	_lan_lobby.text = ""
	_lan_start.visible = false
	net.discover(true)
	show_page("lan")


func _join(address: String) -> void:
	if address == "":
		return
	if net.join(address, Progress.player_name()) == OK:
		_lan_status.text = tr("Joining %s... the host will start the game.") % address
	else:
		_lan_status.text = tr("Could not connect")


func _show_hosts(hosts: Array) -> void:
	for c in _lan_hosts.get_children():
		c.queue_free()
	for h in hosts:
		var addr: String = h["ip"]
		_button(_lan_hosts, "%s   (%d)" % [h["name"], h["players"]], func() -> void: _join(addr))


var _journey_box: VBoxContainer


func _build_journey() -> void:
	_journey_box = _scroll_page("journey", "Royal Journey")
	var page_box: VBoxContainer = _frame_of(_journey_box)
	_button(page_box, "Back", func() -> void: _back())


func _refresh_journey() -> void:
	for c in _journey_box.get_children():
		c.queue_free()
	var done := Campaign.completed()
	for i in range(Campaign.CHAPTERS.size()):
		var ch: Dictionary = Campaign.CHAPTERS[i]
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		var theme_cols: Dictionary = BoardThemes.THEMES[ch["theme"]]
		style.bg_color = (theme_cols["lacquer"] as Color).darkened(0.3) if Campaign.unlocked(i) else Color(0.12, 0.08, 0.08)
		style.border_color = RoyalTheme.GOLD if Campaign.unlocked(i) else Color(0.4, 0.33, 0.28)
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", style)
		var col := VBoxContainer.new()
		card.add_child(col)
		var head := Label.new()
		var state := tr("Completed") if i < done else (tr("Unlocked") if Campaign.unlocked(i) else tr("Locked"))
		head.text = "%d. %s   ·   %s" % [i + 1, tr(ch["palace"]), state]
		head.add_theme_font_size_override("font_size", 22)
		head.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT if Campaign.unlocked(i) else Color(0.6, 0.55, 0.5))
		col.add_child(head)
		var body := Label.new()
		body.text = "%s\n%s   ·   %s %d" % [tr(ch["intro"]), tr(ch["twist"]), tr("Reward"), ch["reward"]]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(560, 0)
		body.add_theme_font_size_override("font_size", 17)
		col.add_child(body)
		if Campaign.unlocked(i):
			var idx := i
			var b := _button(col, "Play this chapter" if i >= done else "Play again", func() -> void: campaign_start.emit(idx))
			b.custom_minimum_size = Vector2(0, 44)
		_journey_box.add_child(card)


var _profile_box: VBoxContainer


func _build_profile() -> void:
	_profile_box = _scroll_page("profile", "Profile")
	var page_box: VBoxContainer = _frame_of(_profile_box)
	_button(page_box, "Back", func() -> void: _back())


func _refresh_profile() -> void:
	for c in _profile_box.get_children():
		c.queue_free()
	var frame: Array = Progress.frame()
	## Header: medallion in the frame colour, name field, level and XP bar.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_profile_box.add_child(head)
	var medal := Medallion.new()
	medal.custom_minimum_size = Vector2(96, 96)
	medal.ring = frame[2]
	medal.label = str(Progress.level())
	head.add_child(medal)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	var name_edit := LineEdit.new()
	name_edit.text = Progress.player_name()
	name_edit.max_length = 16
	name_edit.placeholder_text = tr("Your name")
	name_edit.text_submitted.connect(func(t: String) -> void: Progress.set_player_name(t))
	name_edit.focus_exited.connect(func() -> void: Progress.set_player_name(name_edit.text))
	col.add_child(name_edit)
	var lv := Label.new()
	var t := Progress.title()
	lv.text = tr("Level %d") % Progress.level() + "   ·   " + tr(frame[1]) + ("   ·   " + tr(Progress.ACHIEVEMENTS[t][0]) if t != "" else "")
	lv.add_theme_color_override("font_color", frame[2])
	col.add_child(lv)
	var prog := Progress.level_progress()
	var bar := ProgressBar.new()
	bar.max_value = prog[1]
	bar.value = prog[0]
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	col.add_child(bar)
	var xl := Label.new()
	xl.text = tr("%d / %d XP to the next level") % [prog[0], prog[1]]
	xl.add_theme_font_size_override("font_size", 17)
	col.add_child(xl)
	## Title picker (from unlocked achievements).
	var titles := ["(none)"]
	var ids := [""]
	for id in Progress.unlocked():
		titles.append(Progress.ACHIEVEMENTS[id][0])
		ids.append(id)
	var pick := _option(_profile_box, "Title", titles)
	pick.select(maxi(0, ids.find(Progress.title())))
	pick.item_selected.connect(func(i: int) -> void:
		Progress.set_title(ids[i])
		_refresh_profile())
	## Badge gallery: a medallion per achievement, gold when earned.
	var gl := Label.new()
	gl.text = tr("Badges")
	gl.add_theme_font_size_override("font_size", 26)
	gl.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	_profile_box.add_child(gl)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_profile_box.add_child(grid)
	var have := Progress.unlocked()
	for id in Progress.ACHIEVEMENTS:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(96, 0)
		var m := Medallion.new()
		m.custom_minimum_size = Vector2(70, 70)
		m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		m.ring = Color("#ffd24a") if have.has(id) else Color(0.4, 0.33, 0.28)
		m.label = String(Progress.ACHIEVEMENTS[id][0]).left(1)
		m.dim = not have.has(id)
		cell.add_child(m)
		var nl := Label.new()
		nl.text = tr(Progress.ACHIEVEMENTS[id][0])
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.add_theme_font_size_override("font_size", 14)
		cell.add_child(nl)
		grid.add_child(cell)


## A drawn gold medallion: rim, rays, inner disc and a letter or number.
class Medallion extends Control:
	var ring := Color("#ffd24a")
	var label := ""
	var dim := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.48
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.45))
		for i in range(16):
			var a := TAU * i / 16.0
			draw_line(c + Vector2(cos(a), sin(a)) * r * 0.62, c + Vector2(cos(a), sin(a)) * r, ring.darkened(0.25), 3.0, true)
		draw_circle(c, r * 0.78, ring)
		draw_circle(c, r * 0.64, Color("#5a0d17") if not dim else Color(0.18, 0.12, 0.1))
		draw_arc(c, r * 0.64, 0, TAU, 40, ring.lightened(0.3), 2.0, true)
		var font := get_theme_default_font()
		var fs := int(r * 0.7)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ring.lightened(0.2) if not dim else Color(0.5, 0.45, 0.4))


func _update_coin_badge() -> void:
	if _coin_badge:
		_coin_badge.text = "%s  ·  %s  ·  %s" % [Progress.player_name(), tr("Level %d") % Progress.level(), tr("%d coins") % Progress.coins()]


func _build_howto() -> void:
	var box := _page_root("howto")
	_title(box, "How to play")
	var text := Label.new()
	text.text = HOW_TO_PLAY
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(420, 0)
	box.add_child(text)
	_button(box, "Replay the tutorial next game", func() -> void:
		GameSettings.set_option("tutorial_done", false)
		_back())
	_button(box, "Back", func() -> void: _back())


func _open_setup(mode: String) -> void:
	_mode = mode
	_players.select(GameSettings.get_option("players") - 2)
	_difficulty.select(GameSettings.get_option("difficulty"))
	_difficulty.get_parent().visible = mode == "ai"
	show_page("setup")


func _start_from_setup() -> void:
	var rules := {}
	for key in _rule_boxes:
		rules[key] = (_rule_boxes[key] as CheckButton).button_pressed
	GameSettings.set_rules(rules)
	GameSettings.set_option("players", _players.selected + 2)
	GameSettings.set_option("difficulty", _difficulty.selected)
	start_game.emit({
		"mode": _mode,
		"players": _players.selected + 2,
		"difficulty": _difficulty.selected,
		"rules": rules,
	})


func _quick_play() -> void:
	var rules := GameSettings.get_rules()
	rules["quick_end"] = true
	start_game.emit({"mode": "ai", "players": 2, "difficulty": 1, "rules": rules})


func _load_settings_into_controls() -> void:
	_graphics.select(["low", "medium", "high"].find(GameSettings.get_option("graphics")))
	_camera.button_pressed = GameSettings.get_option("camera_tilt")
	_anim.select(GameSettings.get_option("anim_speed"))
	_fps.button_pressed = GameSettings.get_option("show_fps")
	_music.value = _audio.music_volume_db if _audio else -10
	_sfx.value = _audio.sfx_volume_db if _audio else -2
	_mute.button_pressed = _audio.muted if _audio else false
	_haptics.button_pressed = _audio.haptics if _audio else true
	_voice.button_pressed = GameSettings.get_option("voice")
	_timer.button_pressed = GameSettings.get_option("turn_timer")
	_cb.button_pressed = GameSettings.get_option("colorblind")
	_big.button_pressed = GameSettings.get_option("large_text")
	_relax.button_pressed = GameSettings.get_option("relaxed_ai")
	var code := String(GameSettings.get_option("language"))
	for i in range(I18n.LANGUAGES.size()):
		if I18n.LANGUAGES[i][0] == code:
			_language.select(i)


func _save_settings() -> void:
	GameSettings.set_option("graphics", ["low", "medium", "high"][_graphics.selected])
	GameSettings.set_option("camera_tilt", _camera.button_pressed)
	GameSettings.set_option("anim_speed", _anim.selected)
	GameSettings.set_option("show_fps", _fps.button_pressed)
	GameSettings.set_option("voice", _voice.button_pressed)
	var lang: String = I18n.LANGUAGES[maxi(_language.selected, 0)][0]
	if lang != String(GameSettings.get_option("language")):
		GameSettings.set_option("language", lang)
		I18n.apply(lang)
	GameSettings.set_option("turn_timer", _timer.button_pressed)
	GameSettings.set_option("colorblind", _cb.button_pressed)
	GameSettings.set_option("large_text", _big.button_pressed)
	GameSettings.set_option("relaxed_ai", _relax.button_pressed)
	if _audio:
		_audio.set_music_volume_db(_music.value)
		_audio.set_sfx_volume_db(_sfx.value)
		_audio.haptics = _haptics.button_pressed
		_audio.set_muted(_mute.button_pressed)
	settings_changed.emit()


## Rose and marigold petals drifting down behind the menu panels.
func _add_petals() -> void:
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(24):
			var u := (x - 11.5) / 12.0
			var v := (y - 7.5) / 8.0
			var d := u * u + v * v
			img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 3.0, 0.0, 1.0)))
	var petals := CPUParticles2D.new()
	petals.texture = ImageTexture.create_from_image(img)
	petals.amount = 40
	petals.lifetime = 9.0
	petals.preprocess = 9.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.direction = Vector2(0.3, 1)
	petals.spread = 25.0
	petals.gravity = Vector2(6, 22)
	petals.initial_velocity_min = 20.0
	petals.initial_velocity_max = 55.0
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	petals.angle_min = 0.0
	petals.angle_max = 360.0
	petals.scale_amount_min = 0.6
	petals.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color("#ff6f91"), Color("#ffb347"), Color("#ff4f6d")])
	petals.color_initial_ramp = ramp
	add_child(petals)
	var place := func() -> void:
		var vp := get_viewport_rect().size
		petals.position = Vector2(vp.x * 0.5, -20)
		petals.emission_rect_extents = Vector2(vp.x * 0.6, 10)
	place.call()
	get_viewport().size_changed.connect(place)


## Shows or hides "Resume game" on the title page (a game is waiting behind the menu).
func set_resume_available(on: bool) -> void:
	if _resume_button:
		_resume_button.visible = on


## Android back button: close the current page; on the title page, report false.
func go_back() -> bool:
	if _page != "main":
		_back()
		return true
	return false


## A turning 3D token in its own little world, wearing the selected design.
func _build_design_preview(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(220, 220)
	holder.stretch = true
	row.add_child(holder)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	holder.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#ffe8c8")
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.6
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.8
	rim.light_color = Color("#ffc080")
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 32
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.95, 2.9), Vector3(0, 0.6, 0), Vector3.UP)
	_preview_pivot = Node3D.new()
	vp.add_child(_preview_pivot)
	_preview_token = TransformerToken.new()
	_preview_pivot.add_child(_preview_token)
	_preview_token.configure("blue")
	_preview_token.transform_out(0.01)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_preview_label = Label.new()
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.add_theme_font_size_override("font_size", 24)
	col.add_child(_preview_label)
	_preview_status = Label.new()
	_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status.add_theme_font_size_override("font_size", 18)
	_preview_status.add_theme_color_override("font_color", Color("#f3d9a8"))
	col.add_child(_preview_status)
	_preview_action = _small_button(col, _preview_use)
	_preview_buy = _small_button(col, _preview_purchase)
	_preview_video = _small_button(col, _preview_watch)
	_preview_ticket = _small_button(col, _preview_use_ticket)
	_preview_trial = _small_button(col, _preview_try)
	## Customise: metal finish for every design, aura colour for Epic and Legendary.
	_style_box = VBoxContainer.new()
	_style_box.add_theme_constant_override("separation", 6)
	parent.add_child(_style_box)
	var sh := Label.new()
	sh.text = tr("Customise your design")
	sh.add_theme_font_size_override("font_size", 22)
	sh.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	_style_box.add_child(sh)
	_metal_row = _style_row(_style_box, "Metal", TokenDesigns.METALS, "metal")
	_aura_row = _style_row(_style_box, "Aura", TokenDesigns.AURAS, "aura")
	_preview_design(Progress.equipped("design"))


func _small_button(parent: Control, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	UiFx.button(b)
	return b


## One row of style choices; each button shows its colour.
func _style_row(parent: Control, label: String, options: Dictionary, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := Label.new()
	l.text = tr(label)
	l.custom_minimum_size = Vector2(90, 0)
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	for opt in options:
		var b := Button.new()
		b.name = opt
		b.text = tr(options[opt][0])
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 16)
		var c: Color = options[opt][1]
		if c.a > 0.0:
			b.add_theme_color_override("font_color", c.lightened(0.2))
		b.pressed.connect(func() -> void:
			Progress.set_design_style(_preview_id, key, opt)
			if _audio:
				_audio.play("token_select")
			_preview_design(_preview_id)
			if Progress.equipped("design") == _preview_id:
				design_changed.emit())   # the tokens on the board change too
		row.add_child(b)
		UiFx.button(b)
	return row


func _preview_design(id: String) -> void:
	_preview_id = id
	var style := Progress.design_style(id)
	TokenDesigns.apply(_preview_token, "%s|%s|%s" % [id, style["metal"], style["aura"]], RoyalBoard.PALETTE["blue"])
	var d: Array = TokenDesigns.DESIGNS[id]
	var r: Array = TokenDesigns.RARITY[d[1]]
	_preview_label.text = "%s\n%s" % [tr(d[0]), tr(r[0])]
	_preview_label.add_theme_color_override("font_color", (r[1] as Color).lightened(0.25))
	var owned := Progress.owns(id)
	var usable := Progress.can_use(id)
	var left := Progress.time_left(id)
	## Equip
	_preview_action.visible = usable
	_preview_action.disabled = Progress.equipped("design") == id
	_preview_action.text = tr("Equipped") if _preview_action.disabled else tr("Use this design")
	## Buy for good (also offered while renting)
	_preview_buy.visible = not owned
	_preview_buy.text = (tr("Keep it forever: %d coins") if usable else tr("Buy for %d coins")) % d[2]
	## Watch videos to rent it
	var need := Progress.videos_needed(id)
	var got := Progress.video_progress(id)
	_preview_video.visible = not owned and RewardedAds.available()
	_preview_video.disabled = Progress.videos_left_today() <= 0
	_preview_video.text = tr("Watch video (%d/%d): %dh rental") % [got, need, Progress.rent_hours(id)] if not _preview_video.disabled else tr("No more videos today")
	## Royal Ticket
	_preview_ticket.visible = not owned
	_preview_ticket.disabled = Progress.tickets() <= 0
	_preview_ticket.text = tr("Royal Ticket: %dh rental (you have %d)") % [Progress.TICKET_HOURS, Progress.tickets()]
	## Free trial, once per design
	_preview_trial.visible = not usable and not Progress.trial_used(id)
	_preview_trial.text = tr("Free %d-minute trial") % Progress.TRIAL_MINUTES
	## Status
	if owned:
		_preview_status.text = tr("Yours to keep") if id != "design_classic" else ""
	elif left > 0:
		_preview_status.text = tr("Rented: %s left") % Progress.format_time(left)
	else:
		_preview_status.text = tr("Unlock it for good, or rent it for a while")
	## Customise (only once you can use it, and not for the plain classic)
	_style_box.visible = usable and id != "design_classic"
	_aura_row.visible = d[1] == "epic" or d[1] == "legendary"
	for row in [_metal_row, _aura_row]:
		var key := "metal" if row == _metal_row else "aura"
		for b in row.get_children():
			if b is Button:
				b.disabled = b.name == style[key]   # the chosen one shows as pressed in


func _preview_use() -> void:
	Progress.equip(_preview_id)
	if _audio:
		_audio.play("token_select")
	_after_design_change()


func _preview_purchase() -> void:
	var r := Progress.buy(_preview_id)
	if r == "coins":
		_shop_coins.text = tr("Not enough coins: win games and claim daily rewards")
		if _audio:
			_audio.play("error", 0.0, -4.0)
		return
	if _audio:
		_audio.play("coins", 0.03)
	Progress.equip(_preview_id)
	_after_design_change()


func _preview_watch() -> void:
	var id := _preview_id
	RewardedAds.show(self, func(rewarded: bool) -> void:
		if not rewarded:
			return
		if Progress.watched_video(id):
			Progress.equip(id)
			if _audio:
				_audio.play("coins", 0.03)
		_preview_design(id)
		_after_design_change())


func _preview_use_ticket() -> void:
	if Progress.use_ticket(_preview_id):
		Progress.equip(_preview_id)
		if _audio:
			_audio.play("coins", 0.03)
		_after_design_change()


func _preview_try() -> void:
	if Progress.start_trial(_preview_id):
		Progress.equip(_preview_id)
		if _audio:
			_audio.play("token_select")
		_after_design_change()


func _after_design_change() -> void:
	_refresh_themes()
	_preview_design(_preview_id)
	design_changed.emit()


func _process(delta: float) -> void:
	if _preview_pivot and is_instance_valid(_preview_pivot) and visible and _page == "themes":
		_preview_pivot.rotation.y += delta * 0.9
		## Keep the rental countdown ticking.
		_status_tick -= delta
		if _status_tick <= 0.0:
			_status_tick = 1.0
			_preview_design(_preview_id)
			_refresh_themes()
