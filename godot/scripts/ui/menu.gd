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
var _mode := "ai"
var _audio: AudioManager
var _overlay := false
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
		UiFx.pop_in(panel)
		var buttons: Array = []
		for c in panel.get_child(0).get_children():
			if c is Button:
				buttons.append(c)
		UiFx.cascade(buttons)
		if name == "main" and _logo:
			_logo.modulate.a = 0.0
			_logo.position.x -= 60.0
			var t := _logo.create_tween().set_parallel(true)
			t.tween_property(_logo, "modulate:a", 1.0, 0.6)
			t.tween_property(_logo, "position:x", _logo.position.x + 60.0, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _page_root(name: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	UiFx.ornaments(panel)
	_panels[name] = panel
	_pages[name] = center
	center.visible = false
	return box


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
	_button(box, "Play vs AI", func() -> void: _open_setup("ai"))
	_button(box, "Pass and play", func() -> void: _open_setup("pass"))
	_button(box, "Quick play", func() -> void: _quick_play())
	_button(box, "Team battle 2v2", func() -> void:
		var rules := GameSettings.get_rules()
		rules["teams"] = true
		start_game.emit({"mode": "team", "players": 4, "difficulty": GameSettings.get_option("difficulty"), "rules": rules}))
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
	var box := _page_root("settings")
	_title(box, "Settings")
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
	var names: Array = []
	for l in I18n.LANGUAGES:
		names.append(l[1])
	_language = _option(box, "Language", names)
	for c in [_graphics, _anim, _language]:
		(c as OptionButton).item_selected.connect(func(_i: int) -> void: _save_settings())
	for c in [_camera, _fps, _mute, _haptics, _voice, _timer]:
		(c as CheckButton).toggled.connect(func(_b: bool) -> void: _save_settings())
	_music.value_changed.connect(func(_v: float) -> void: _save_settings())
	_sfx.value_changed.connect(func(_v: float) -> void: _save_settings())
	_button(box, "Back", func() -> void: _back())


var _shop_rows: Dictionary = {}
var _shop_coins: Label
var _rewards_box: VBoxContainer
var _coin_badge: Label


func _scroll_page(name: String, title: String) -> VBoxContainer:
	var box := _page_root(name)
	_title(box, title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	return inner


## Royal Bazaar: themes, dice and token skins. Owned items are equipped with a tap;
## others are bought with coins.
func _build_themes() -> void:
	var inner := _scroll_page("themes", "Royal Bazaar")
	var page_box: VBoxContainer = inner.get_parent().get_parent()
	_shop_coins = Label.new()
	_shop_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_coins.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	page_box.add_child(_shop_coins)
	page_box.move_child(_shop_coins, 1)
	for kind in [["theme", "Board themes"], ["dice", "Dice"], ["tokens", "Your tokens"]]:
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
	_shop_coins.text = tr("Treasury: %d coins") % Progress.coins()
	for id in _shop_rows:
		var item: Array = Progress.SHOP[id]
		var equipped := false
		if item[0] == "theme":
			equipped = BoardThemes.current_id() == id.trim_prefix("theme_")
		else:
			equipped = Progress.equipped(item[0]) == id
		var state := tr("Equipped") if equipped else (tr("Owned: tap to use") if Progress.owns(id) else tr("%d coins") % item[2])
		(_shop_rows[id] as Button).text = "   %s      -      %s" % [tr(item[1]), state]


## Rewards: daily reward, achievements and lifetime stats.
func _build_rewards() -> void:
	_rewards_box = _scroll_page("rewards", "Rewards")
	var page_box: VBoxContainer = _rewards_box.get_parent().get_parent()
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


var _profile_box: VBoxContainer


func _build_profile() -> void:
	_profile_box = _scroll_page("profile", "Profile")
	var page_box: VBoxContainer = _profile_box.get_parent().get_parent()
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
