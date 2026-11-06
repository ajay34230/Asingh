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
var _mode := "ai"
var _audio: AudioManager
var _overlay := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = RoyalTheme.build()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.03, 0.02, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_add_petals()
	_build_main()
	_build_setup()
	_build_settings()
	_build_howto()
	_build_themes()
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


func _build_main() -> void:
	var box := _page_root("main")
	var title := Label.new()
	title.text = "Royal India Ludo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "~ the game of maharajas ~"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color("#f3d9a8"))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	_button(box, "Play vs AI", func() -> void: _open_setup("ai"))
	_button(box, "Pass and play (2 to 4 players)", func() -> void: _open_setup("pass"))
	_button(box, "Quick play (2 players, quick game)", func() -> void: _quick_play())
	_button(box, "Board themes", func() -> void: _refresh_themes(); show_page("themes"))
	_button(box, "How to play", func() -> void: show_page("howto"))
	_button(box, "Settings", func() -> void: _load_settings_into_controls(); show_page("settings"))
	_button(box, "Quit", func() -> void: quit_requested.emit())


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
	_language = _option(box, "Language", ["English", "Hindi (coming soon)"])
	_language.set_item_disabled(1, true)
	for c in [_graphics, _anim, _language]:
		(c as OptionButton).item_selected.connect(func(_i: int) -> void: _save_settings())
	for c in [_camera, _fps, _mute, _haptics, _voice]:
		(c as CheckButton).toggled.connect(func(_b: bool) -> void: _save_settings())
	_music.value_changed.connect(func(_v: float) -> void: _save_settings())
	_sfx.value_changed.connect(func(_v: float) -> void: _save_settings())
	_button(box, "Back", func() -> void: _back())


var _theme_buttons: Dictionary = {}


func _build_themes() -> void:
	var box := _page_root("themes")
	_title(box, "Board themes")
	for id in BoardThemes.ORDER:
		var t: Dictionary = BoardThemes.THEMES[id]
		var b := _button(box, t["name"], func() -> void:
			BoardThemes.set_current(id)
			_refresh_themes()
			board_theme_changed.emit())
		b.custom_minimum_size = Vector2(420, 60)
		## A swatch of the theme's lacquer and gold on the button.
		var sw := ColorRect.new()
		sw.color = t["lacquer"]
		sw.custom_minimum_size = Vector2(34, 34)
		sw.position = Vector2(14, 13)
		b.add_child(sw)
		var gold := ColorRect.new()
		gold.color = t["gold"]
		gold.size = Vector2(34, 8)
		gold.position = Vector2(0, 26)
		sw.add_child(gold)
		_theme_buttons[id] = b
	_button(box, "Back", func() -> void: _back())


func _refresh_themes() -> void:
	var current := BoardThemes.current_id()
	for id in _theme_buttons:
		var t: Dictionary = BoardThemes.THEMES[id]
		(_theme_buttons[id] as Button).text = ("[ chosen ]   " if id == current else "") + "%s  -  %s" % [t["name"], t["blurb"]]


func _build_howto() -> void:
	var box := _page_root("howto")
	_title(box, "How to play")
	var text := Label.new()
	text.text = HOW_TO_PLAY
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(420, 0)
	box.add_child(text)
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
	_language.select(0)


func _save_settings() -> void:
	GameSettings.set_option("graphics", ["low", "medium", "high"][_graphics.selected])
	GameSettings.set_option("camera_tilt", _camera.button_pressed)
	GameSettings.set_option("anim_speed", _anim.selected)
	GameSettings.set_option("show_fps", _fps.button_pressed)
	GameSettings.set_option("voice", _voice.button_pressed)
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
