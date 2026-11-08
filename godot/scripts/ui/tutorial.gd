## First-game coach: short tips that appear at the moment they matter (first roll, first
## choice, leaving the yard, safe squares, captures, reaching home). Each tip shows once;
## the whole tutorial is marked done when the first game ends. Replayable from the menu.
class_name Tutorial
extends Control

const TIPS := {
	"roll": "Your turn! Tap the dice to roll it.",
	"pick": "Glowing tokens can move. The rings show where each would land. Tap one to move it.",
	"need_six": "A token leaves its courtyard only on a six. Keep rolling!",
	"six": "A six! Your token is out, and a six earns you another roll.",
	"safe": "Star and start squares are safe: a token there is shielded and cannot be captured.",
	"capture": "Land on an opponent to fight! The loser goes back to its courtyard, and you roll again.",
	"home": "Home! Bring all four tokens to the centre to win. Each one home earns another roll.",
}

var _shown := {}
var _panel: PanelContainer
var _text: Label
var _hide_tween: Tween
var active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = RoyalTheme.build()
	active = not bool(GameSettings.get_option("tutorial_done"))
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 70
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.visible = false
	add_child(_panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)
	var icon := Label.new()
	icon.text = "Tip"
	icon.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	icon.add_theme_font_size_override("font_size", 26)
	box.add_child(icon)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(430, 0)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 21)
	box.add_child(_text)
	var ok := Button.new()
	ok.text = "Got it"
	ok.pressed.connect(func() -> void: _panel.visible = false)
	box.add_child(ok)
	UiFx.button(ok)


## Shows a tip once (only while the tutorial is active).
func tip(key: String) -> void:
	if not active or _shown.has(key) or not TIPS.has(key):
		return
	_shown[key] = true
	_text.text = TIPS[key]
	_panel.visible = true
	UiFx.pop_in(_panel)
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(7.0)
	_hide_tween.tween_callback(func() -> void: _panel.visible = false)


func finish() -> void:
	if active:
		active = false
		GameSettings.set_option("tutorial_done", true)
		_panel.visible = false
