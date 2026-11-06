class_name TitleScreen
extends CanvasLayer
## Title menu shown on launch: Continue (when a save exists), New Game, and a language switch.

signal chosen(continue_game: bool)

var has_save := false
var crash_info := ""
var _root: Control
var _lang_btn: Button


func _ready() -> void:
	layer = 80
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	_root.add_child(box)
	var t := Label.new()
	t.text = "The Lost Kingdom"
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := Label.new()
	s.text = "A story of the Valley of Sands"
	s.add_theme_font_size_override("font_size", 24)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	if crash_info != "":
		var w := Label.new()
		w.text = "The game closed unexpectedly last time.\nLast known state: " + crash_info
		w.add_theme_font_size_override("font_size", 18)
		w.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD
		w.custom_minimum_size = Vector2(700, 0)
		box.add_child(w)
		var cp := _button("Copy crash report", func() -> void: pass)
		cp.pressed.connect(func() -> void:
			var n := LogCollector.copy_report()
			cp.text = "Copied (%d characters). Paste it to the developer." % n)
		cp.add_theme_font_size_override("font_size", 24)
		box.add_child(cp)
	if has_save:
		box.add_child(_button("Continue", func() -> void: _pick(true)))
	box.add_child(_button("New Game", func() -> void: _pick(false)))
	_lang_btn = _button("", _toggle_lang)
	box.add_child(_lang_btn)
	_refresh_lang()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 84)
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(cb)
	return b


func _toggle_lang() -> void:
	var to := "en" if Loc.hindi() else "hi"
	GameSettings.set_value("lang", 1 if to == "hi" else 0)
	_refresh_lang()


func _refresh_lang() -> void:
	_lang_btn.text = "Language: हिन्दी" if Loc.hindi() else "Language: English"
	for c in _root.find_children("*", "Button", true, false):
		var b := c as Button
		if b == _lang_btn:
			continue
		if not b.has_meta("en"):
			b.set_meta("en", b.text)
		b.text = Loc.t(String(b.get_meta("en")))


func _pick(cont: bool) -> void:
	chosen.emit(cont)
	queue_free()
