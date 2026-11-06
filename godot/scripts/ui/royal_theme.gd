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
	t.default_font_size = 22

	var panel := _box(Color(0.16, 0.03, 0.05, 0.94), GOLD, 3, 20)
	panel.set_content_margin_all(26)
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var normal := _box(Color("#6a1420"), GOLD, 2, 14)
	normal.bg_color = Color("#6a1420")
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)
	var hover := _box(Color("#8c1c2b"), GOLD_LIGHT, 2, 14)
	hover.shadow_color = Color(1.0, 0.75, 0.3, 0.35)
	hover.shadow_size = 10
	var pressed := _box(Color("#4a0d15"), GOLD_LIGHT, 3, 14)
	var disabled := _box(Color(0.25, 0.12, 0.12, 0.7), Color(0.5, 0.4, 0.3, 0.6), 1, 14)
	var focus := _box(Color(0, 0, 0, 0), GOLD_LIGHT, 2, 14)
	focus.draw_center = false
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, CREAM)
		t.set_color("font_hover_color", type, GOLD_LIGHT)
		t.set_color("font_pressed_color", type, GOLD_LIGHT)
		t.set_color("font_disabled_color", type, Color(0.75, 0.65, 0.55, 0.6))
		t.set_color("font_outline_color", type, Color(0.1, 0.02, 0.02))
		t.set_constant("outline_size", type, 4)

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0.12, 0.03, 0.02, 0.95))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	t.set_constant("shadow_offset_y", "Label", 2)

	var track := _box(Color("#2a070c"), Color("#7a5520"), 1, 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(GOLD, GOLD, 0, 6)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var popup := _box(Color("#2a070c"), GOLD, 2, 10)
	popup.set_content_margin_all(8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", GOLD_LIGHT)
	t.set_stylebox("hover", "PopupMenu", _box(Color("#6a1420"), GOLD, 0, 6))
	_cached = t
	return t


## Small rounded badge (turn indicator, messages).
static func badge(accent: Color) -> StyleBoxFlat:
	var s := _box(Color(0.14, 0.03, 0.05, 0.85), accent, 2, 22)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
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
