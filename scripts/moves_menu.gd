class_name MovesMenu
extends CanvasLayer
## The MOVES menu: every captured animation in the game, sorted into tabs; tap one and the hero does it.
## Opened from the MOVES button on the touch controls (or the N key).

const TABS := ["Fight", "Sword", "Bow", "Creature", "Life", "Moves"]
# Anachronisms (pistols, a phone) are left out of the menu.
const HIDDEN := ["ual_pistol_aim_down", "ual_pistol_aim_neutral", "ual_pistol_aim_up", "ual_pistol_idle", "ual_pistol_reload",
	"ual_pistol_shoot", "ual_idle_talkingphone"]
const NAMES := {
	"walk": "Walk", "run_fast": "Fast run", "jump_down": "Jump down", "dying": "Dying",
	"ual_punch_jab": "Jab", "ual_punch_cross": "Cross punch", "ual_melee_hook": "Hook", "ual_melee_hook_rec": "Hook and recover",
	"ss_kick": "Kick", "ual_roll": "Roll", "ual_hit_knockback": "Knocked down", "ual_laytoidle": "Get up",
	"ual_death01": "Fall dead", "ual_dance": "Dance", "ual_yes": "Nod yes", "ual_idle_no": "Shake head",
	"ual_idle_foldarms": "Fold arms", "ual_sitting_enter": "Sit down", "ual_sitting_exit": "Stand up",
	"ual_sitting_idle": "Sit", "ual_sitting_talking": "Sit and talk", "ual_spell_simple_shoot": "Cast spell",
	"ual_overhandthrow": "Throw", "ual_treechopping": "Chop wood", "ual_consume": "Eat / drink",
	"mutant_flexing_muscles": "Flex muscles", "mutant_swiping": "Claw swipe", "ual_ninjajump_start": "Ninja jump",
}

var player: Player
var _panel: PanelContainer
var _grid: GridContainer
var _tab := "Fight"
var _tab_btns := {}
var _note: Label


func _ready() -> void:
	layer = 100
	add_to_group("moves_menu")
	visible = false
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.98)
	sb.border_color = Color(0.85, 0.65, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = Loc.t("MOVES")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := _button(Loc.t("CLOSE"), 26)
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in TABS:
		var b := _button(Loc.t(t), 26)
		b.toggle_mode = true
		b.pressed.connect(_show_tab.bind(t))
		tabs.add_child(b)
		_tab_btns[t] = b
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 22)
	_note.add_theme_color_override("font_color", Color(1, 0.75, 0.6))
	v.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	return b


func toggle() -> void:
	visible = not visible
	if visible:
		_note.text = ""
		_show_tab(_tab)


## Which tab a clip belongs in.
static func tab_of(n: String) -> String:
	if n.begins_with("bow_"):
		return "Bow"
	if n.begins_with("mutant_") or n.begins_with("ual_zombie"):
		return "Creature"
	if n.begins_with("ss_") or n.begins_with("ual_sword") or n.begins_with("ual_shield") or n.begins_with("ual_idle_shield") or n.begins_with("sheath"):
		return "Sword" if n != "ss_kick" and not n.begins_with("ss_impact") and not n.begins_with("ss_death") else "Fight"
	for w in ["punch", "hook", "kick", "roll", "hit_", "death", "dying", "knockback", "laytoidle", "slide", "ninjajump"]:
		if n.contains(w):
			return "Fight"
	for w in ["walk", "run", "jog", "sprint", "jump", "swim", "crouch", "climb", "driving"]:
		if n.contains(w):
			return "Moves"
	return "Life"


static func label_of(n: String) -> String:
	if NAMES.has(n):
		return NAMES[n]
	var s := n
	for p in ["ual_", "ss_", "bow_", "mutant_"]:
		s = s.trim_prefix(p)
	return s.replace("_", " ").capitalize()


## Every clip the menu offers, by tab.
static func entries(tab: String) -> Array:
	var out: Array = []
	var lib := MocapLibrary.get_lib()
	if lib == null:
		return out
	var names: Array = lib.clips.keys()
	names.sort()
	for n in names:
		if not n in HIDDEN and tab_of(n) == tab:
			out.append(n)
	return out


func _show_tab(t: String) -> void:
	_tab = t
	for k in _tab_btns:
		(_tab_btns[k] as Button).button_pressed = k == t
	for c in _grid.get_children():
		c.queue_free()
	for n in entries(t):
		var b := _button(Loc.t(label_of(n)), 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick.bind(n))
		_grid.add_child(b)


func _pick(n: String) -> void:
	if player == null:
		return
	var why := player.play_emote(n)
	if why == "":
		visible = false
	else:
		_note.text = Loc.t(why)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_N:
		toggle()
