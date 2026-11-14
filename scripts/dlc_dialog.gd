class_name DlcDialog
extends CanvasLayer
## "Download this character?" with a progress bar. Used when a mission needs a monster that is not on the
## phone yet, and by the Characters menu.

var _label: Label
var _bar: ProgressBar
var _yes: Button
var _no: Button
var _ids: Array = []
var _done := Callable()           # done(ok: bool)
var _store: HeroStore
var _was_paused := false
var _total := 0


static func ask(owner: Node, ids: Array, text: String, done: Callable) -> DlcDialog:
	var d := DlcDialog.new()
	owner.get_tree().current_scene.add_child(d)
	d._ids = ids.duplicate()
	d._done = done
	d._build(text)
	return d


func _build(text: String) -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_store = HeroStore.get_store(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.28
	panel.anchor_bottom = 0.72
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.98)
	sb.border_color = Color(0.85, 0.65, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)
	_label = Label.new()
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	v.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 30)
	_bar.visible = false
	v.add_child(_bar)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	_yes = _btn(Loc.t("Download"))
	_yes.pressed.connect(_start)
	h.add_child(_yes)
	_no = _btn(Loc.t("Not now"))
	_no.pressed.connect(func() -> void: _close(false))
	h.add_child(_no)
	_was_paused = get_tree().paused
	get_tree().paused = true


func _btn(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(240, 72)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _start() -> void:
	_yes.disabled = true
	_bar.visible = true
	_total = 0
	for id in _ids:
		if not HeroStore.is_downloaded(String(id)):
			_total += 1
	_next()


func _next() -> void:
	while not _ids.is_empty() and HeroStore.is_downloaded(String(_ids[0])):
		_ids.pop_front()
	if _ids.is_empty():
		_close(true)
		return
	var id: String = _ids[0]
	var left := 0
	for i in _ids:
		if not HeroStore.is_downloaded(String(i)):
			left += 1
	_label.text = Loc.tf("Downloading %s...", [HeroStore.title(id)])
	if _total > 1:
		_label.text += "  (%d / %d)" % [_total - left + 1, _total]
	_store.download(id, func(ok: bool, msg: String) -> void:
		if ok:
			_ids.pop_front()
			_next()
		else:
			_label.text = Loc.t(msg)
			_yes.disabled = false
			_yes.text = Loc.t("Try again")
			_bar.visible = false)


func _process(_d: float) -> void:
	if _bar.visible:
		_bar.value = _store.progress * 100.0


func _close(ok: bool) -> void:
	get_tree().paused = _was_paused
	var cb := _done
	queue_free()
	if cb.is_valid():
		cb.call(ok)
