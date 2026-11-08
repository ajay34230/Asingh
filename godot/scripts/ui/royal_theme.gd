## Shared UI look: lacquer-red panels with gold borders, jewel-like buttons, cream text.
class_name RoyalTheme
extends RefCounted

const GOLD := Color("#e2b04f")
const GOLD_LIGHT := Color("#ffd98a")
const CREAM := Color("#fff4dc")
const LACQUER := Color("#3a0a10")

static var _cached: Theme


static func build() -> Theme:
	if _cached:
		return _cached
	var t := Theme.new()
	## Cinzel: a classical inscriptional display face (SIL OFL), weight 600 for weight.
	var font := FontVariation.new()
	var cinzel: FontFile = load("res://assets/fonts/Cinzel.ttf")
	## Indian scripts fall back to Noto Sans (SIL OFL) for each script.
	cinzel.fallbacks = indic_fallbacks()
	font.base_font = cinzel
	font.variation_opentype = {"wght": 650}
	t.default_font = font
	t.default_font_size = 24

	## Panels: deep lacquer, almost opaque, a double gold frame (outer border plus an
	## inner hairline drawn by a second, inset box) and a heavy drop shadow.
	var panel := _box(Color(0.12, 0.015, 0.03, 0.98), GOLD, 4, 18)
	panel.set_content_margin_all(30)
	panel.shadow_color = Color(0, 0, 0, 0.75)
	panel.shadow_size = 28
	panel.shadow_offset = Vector2(0, 8)
	panel.border_blend = false
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	## Buttons: jewel-red with a lighter top edge (bevel), thick gold border, inner shadow.
	var normal := _button_box(Color("#7a0f1e"), Color("#4a0610"), GOLD)
	var hover := _button_box(Color("#9c1628"), Color("#5e0a16"), GOLD_LIGHT)
	hover.shadow_color = Color(1.0, 0.72, 0.25, 0.45)
	hover.shadow_size = 14
	var pressed := _button_box(Color("#4a0610"), Color("#30040a"), GOLD_LIGHT)
	pressed.shadow_size = 2
	pressed.content_margin_top += 2
	var disabled := _box(Color(0.2, 0.08, 0.08, 0.85), Color(0.45, 0.36, 0.26, 0.7), 2, 12)
	var focus := _box(Color(0, 0, 0, 0), GOLD_LIGHT, 2, 12)
	focus.draw_center = false
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, GOLD_LIGHT)
		t.set_color("font_hover_color", type, Color("#fff3c4"))
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_disabled_color", type, Color(0.7, 0.6, 0.5, 0.6))
		t.set_color("font_outline_color", type, Color(0.15, 0.02, 0.02))
		t.set_constant("outline_size", type, 6)

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0.1, 0.01, 0.02, 1.0))
	t.set_constant("outline_size", "Label", 8)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 3)

	var track := _box(Color("#1c0408"), Color("#8a6224"), 2, 6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(GOLD, GOLD_LIGHT, 1, 6)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var popup := _box(Color("#1c0408"), GOLD, 3, 10)
	popup.set_content_margin_all(10)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", GOLD_LIGHT)
	t.set_stylebox("hover", "PopupMenu", _box(Color("#7a0f1e"), GOLD, 0, 6))
	_cached = t
	return t


static func indic_fallbacks() -> Array[Font]:
	var out: Array[Font] = []
	for f in ["NotoSansDevanagari", "NotoSansBengali", "NotoSansTamil", "NotoSansTelugu"]:
		out.append(load("res://assets/fonts/%s.ttf" % f))
	return out


static func _button_box(top: Color, bottom: Color, border: Color) -> StyleBoxFlat:
	var s := _box(top.lerp(bottom, 0.4), border, 3, 12)
	s.border_width_bottom = 5          # heavier lower edge reads as a raised bevel
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 7
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


## Small rounded badge (turn indicator, messages).
static func badge(accent: Color) -> StyleBoxFlat:
	var s := _box(Color(0.1, 0.012, 0.025, 0.94), accent, 3, 22)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.7)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 4)
	return s


static func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s
