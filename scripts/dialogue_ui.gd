class_name DialogueUI
extends CanvasLayer
## Touch-friendly dialogue box: speaker name, typewriter text, big choice buttons. Tap the box
## to finish the line or continue. Locks the player while open and makes the speaker "talk".

signal closed

var player: Player
var touch: Control
var story: Story
var voice_node: Node3D
var voice := "man"
var _nodes: Dictionary = {}
var _cur: Dictionary = {}
var _root: Control
var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _typing := false
var _chars := 0.0
var _on_end: Callable = Callable()
var is_open := false
var _hist: Array = []
var _cur_id := ""
var _row: HBoxContainer
var _back: Button
var _next: Button
var _exit: Button


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.05, 0.92)
	sb.border_color = Color(0.85, 0.65, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.03
	_panel.anchor_right = 0.97
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -400
	_panel.offset_bottom = -18
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.gui_input.connect(_on_panel_input)
	_root.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 30)
	_name.add_theme_color_override("font_color", Color(0.95, 0.74, 0.32))
	vb.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 96)
	_text.add_theme_font_size_override("normal_font_size", 28)
	_text.add_theme_color_override("default_color", Color(0.97, 0.93, 0.84))
	vb.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	vb.add_child(_choices)
	_hint = Label.new()
	_hint.visible = false
	vb.add_child(_hint)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	vb.add_child(_row)
	_back = _nav_button("< Back", _go_back)
	_next = _nav_button("Next >", _go_next)
	_exit = _nav_button("Close X", close)
	_row.add_child(_back)
	_row.add_child(_next)
	_row.add_child(_exit)
	_panel.visible = false


## data = {start, nodes}; speaker_node is where the voice babble comes from (may be null).
func open(data: Dictionary, speaker_node: Node3D = null, voice_name: String = "man", on_end: Callable = Callable()) -> void:
	if data.is_empty() or is_open:
		return
	_nodes = data["nodes"]
	_hist.clear()
	_cur_id = ""
	voice_node = speaker_node
	voice = voice_name
	_on_end = on_end
	is_open = true
	player.locked = true
	if touch != null:
		touch.visible = false
	player.move_input = Vector2.ZERO
	_panel.visible = true
	_show(data["start"])


func _nav_button(t: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(fn)
	return b


func _go_back() -> void:
	if _hist.is_empty():
		return
	Sfx.ui("ui_blip", -10.0)
	_show(_hist.pop_back(), true, false)


func _go_next() -> void:
	if _typing:
		_finish_typing()
		return
	if not _cur.get("choices", []).is_empty():
		return
	var go: String = _cur.get("go", "")
	Sfx.ui("ui_blip", -10.0)
	if go == "" or not _nodes.has(go):
		close()
	else:
		_show(go)


func _update_nav() -> void:
	_back.visible = not _hist.is_empty()
	var has_choices: bool = not _cur.get("choices", []).is_empty()
	_next.visible = not has_choices
	var go: String = _cur.get("go", "")
	_next.text = "Next >" if (go != "" and _nodes.has(go)) else "Done"


func _show(id: String, replay: bool = false, push: bool = true) -> void:
	if push and _cur_id != "" and not replay:
		_hist.append(_cur_id)
	_cur_id = id
	_cur = _nodes[id]
	if not replay:
		var st: Dictionary = _cur.get("set", {})
		for k in st:
			story.set_flag(k, st[k])
		var ad: Dictionary = _cur.get("add", {})
		for k in ad:
			story.add(k, ad[k])
		if _cur.has("sfx"):
			Sfx.ui(_cur["sfx"], -4.0)
	_name.text = _cur.get("who", "")
	_text.text = _cur["text"]
	_text.visible_characters = 0
	_chars = 0.0
	_typing = true
	for c in _choices.get_children():
		c.queue_free()
	_hint.visible = false
	_update_nav()
	var vn: Node3D = voice_node if (voice_node != null and is_instance_valid(voice_node)) else null
	Sfx.speak(voice, _cur["text"], vn, -2.0, true)


func _process(delta: float) -> void:
	if not is_open or not _typing:
		return
	_chars += delta * 62.0
	_text.visible_characters = int(_chars)
	if _chars >= _text.get_total_character_count():
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	var ch: Array = _cur.get("choices", [])
	if ch.is_empty():
		_hint.visible = true
		return
	for c in ch:
		var b := Button.new()
		b.text = c["t"]
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_font_size_override("font_size", 27)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_choose.bind(c))
		_choices.add_child(b)


func _choose(c: Dictionary) -> void:
	Sfx.ui("ui_blip", -8.0)
	var st: Dictionary = c.get("set", {})
	for k in st:
		story.set_flag(k, st[k])
	var ad: Dictionary = c.get("add", {})
	for k in ad:
		story.add(k, ad[k])
	if c.has("sfx"):
		Sfx.ui(c["sfx"], -4.0)
	var go: String = c.get("go", "")
	if go == "" or not _nodes.has(go):
		close()
	else:
		_show(go)


func _on_panel_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if not tap or not is_open:
		return
	if _typing:
		_finish_typing()
	elif _cur.get("choices", []).is_empty():
		var go: String = _cur.get("go", "")
		if go == "" or not _nodes.has(go):
			close()
		else:
			Sfx.ui("ui_blip", -10.0)
			_show(go)


func close() -> void:
	Sfx.stop_speech()
	is_open = false
	_panel.visible = false
	player.locked = false
	if touch != null:
		touch.visible = true
	story.refresh()
	if _on_end.is_valid():
		_on_end.call()
	closed.emit()
