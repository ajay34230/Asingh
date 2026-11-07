## Loading screen and screen fades: deep lacquer backdrop, a slowly turning gold
## mandala, the logo and a rotating gameplay tip. Also used as a fade-to-black curtain
## between the menu and the game.
class_name LoadingScreen
extends CanvasLayer

const TIPS := [
	"Roll a six to bring a token out of its courtyard.",
	"Star squares and start squares are safe: no one can capture you there.",
	"Capture an opponent to earn a bonus roll.",
	"Three sixes in a row and your turn is lost.",
	"Tokens on a safe square glow inside a protective shield.",
	"Reaching home earns you a bonus roll.",
	"Tap a glowing token to see where it will land.",
	"Try the Diwali Night theme for lamps and night lighting.",
]

var _root: Control
var _mandala: Control
var _tip: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = RoyalTheme.build()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("#170307")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_mandala = Mandala.new()
	_mandala.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mandala.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mandala)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_root.add_child(box)
	var title := Label.new()
	title.text = "Royal India Ludo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var deco := FontVariation.new()
	deco.base_font = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	title.add_theme_font_override("font", deco)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", RoyalTheme.GOLD_LIGHT)
	box.add_child(title)
	var loading := Label.new()
	loading.text = "Preparing the palace..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_font_size_override("font_size", 22)
	loading.add_theme_color_override("font_color", Color("#d8b878"))
	box.add_child(loading)
	_tip = Label.new()
	_tip.text = "Tip: " + TIPS.pick_random()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(700, 0)
	_tip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tip.add_theme_font_size_override("font_size", 20)
	_tip.add_theme_color_override("font_color", Color("#f3e3c0"))
	box.add_child(_tip)


func _process(delta: float) -> void:
	if _mandala and _root.visible:
		_mandala.set("spin", float(_mandala.get("spin")) + delta * 0.25)
		_mandala.queue_redraw()


## Fades the loading screen away to show the scene.
func reveal(seconds := 0.6) -> void:
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, seconds)
	t.tween_callback(func() -> void: _root.visible = false)


## Curtain: fades in (to cover the screen), runs `then`, used before a scene reload.
func cover(then: Callable, seconds := 0.35) -> void:
	_tip.text = "Tip: " + TIPS.pick_random()
	_root.visible = true
	_root.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 1.0, seconds)
	t.tween_callback(then)


class Mandala extends Control:
	var spin := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.62
		var gold := Color(0.89, 0.69, 0.31, 0.16)
		for ring in range(5):
			var rr := r * (0.35 + ring * 0.16)
			var petals := 8 + ring * 4
			var dir := 1.0 if ring % 2 == 0 else -1.0
			for i in range(petals):
				var a := spin * dir + TAU * i / petals
				var tip := c + Vector2(cos(a), sin(a)) * rr
				var l := c + Vector2(cos(a - PI / petals), sin(a - PI / petals)) * rr * 0.82
				var rgt := c + Vector2(cos(a + PI / petals), sin(a + PI / petals)) * rr * 0.82
				draw_polyline(PackedVector2Array([l, tip, rgt]), gold, 2.0, true)
			draw_arc(c, rr * 0.82, 0, TAU, 96, gold, 1.5, true)
