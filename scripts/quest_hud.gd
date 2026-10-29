class_name QuestHUD
extends CanvasLayer
## Mission tracker (top-left), Journal button and panel, mission banners, a progress bar for
## actions like digging, and a world marker pointing at the current objective.

var story: Story
var player: Player
var world: Node3D
var _tracker: PanelContainer
var _t_title: Label
var _t_lines: VBoxContainer
var _journal_btn: Button
var _journal: PanelContainer
var _j_list: VBoxContainer
var _banner: Label
var _banner_t := 0.0
var _bar_root: Control
var _bar: ProgressBar
var _bar_label: Label
var _bar_t := 0.0
var _bar_dur := 0.0
var _bar_cb := Callable()
var _marker: Label3D
var _tick := 0.0
var _queue: Array = []


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# tracker
	_tracker = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.04, 0.62)
	sb.border_color = Color(0.85, 0.65, 0.28, 0.9)
	sb.border_width_left = 4
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_tracker.add_theme_stylebox_override("panel", sb)
	_tracker.position = Vector2(16, 72)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tracker)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_tracker.add_child(vb)
	_t_title = Label.new()
	_t_title.add_theme_font_size_override("font_size", 24)
	_t_title.add_theme_color_override("font_color", Color(0.95, 0.74, 0.32))
	vb.add_child(_t_title)
	_t_lines = VBoxContainer.new()
	vb.add_child(_t_lines)
	# journal button
	_journal_btn = Button.new()
	_journal_btn.text = "Journal"
	_journal_btn.add_theme_font_size_override("font_size", 26)
	_journal_btn.custom_minimum_size = Vector2(150, 62)
	_journal_btn.anchor_left = 1.0
	_journal_btn.anchor_right = 1.0
	_journal_btn.offset_left = -170
	_journal_btn.offset_right = -16
	_journal_btn.offset_top = 14
	_journal_btn.offset_bottom = 76
	_journal_btn.pressed.connect(_toggle_journal)
	root.add_child(_journal_btn)
	# journal panel
	_journal = PanelContainer.new()
	var jb := sb.duplicate() as StyleBoxFlat
	jb.bg_color = Color(0.09, 0.07, 0.05, 0.95)
	jb.set_border_width_all(3)
	jb.content_margin_left = 24
	jb.content_margin_right = 24
	jb.content_margin_top = 18
	jb.content_margin_bottom = 18
	_journal.add_theme_stylebox_override("panel", jb)
	_journal.anchor_left = 0.08
	_journal.anchor_right = 0.92
	_journal.anchor_top = 0.1
	_journal.anchor_bottom = 0.9
	_journal.visible = false
	root.add_child(_journal)
	var sc := ScrollContainer.new()
	_journal.add_child(sc)
	_j_list = VBoxContainer.new()
	_j_list.add_theme_constant_override("separation", 10)
	_j_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_j_list)
	# banner
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 38)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 110
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)
	# progress bar
	_bar_root = Control.new()
	_bar_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar_root.anchor_left = 0.3
	_bar_root.anchor_right = 0.7
	_bar_root.anchor_top = 0.72
	_bar_root.anchor_bottom = 0.72
	_bar_root.visible = false
	root.add_child(_bar_root)
	_bar_label = Label.new()
	_bar_label.add_theme_font_size_override("font_size", 28)
	_bar_label.anchor_right = 1.0
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_root.add_child(_bar_label)
	_bar = ProgressBar.new()
	_bar.anchor_right = 1.0
	_bar.offset_top = 44
	_bar.offset_bottom = 78
	_bar.show_percentage = false
	_bar_root.add_child(_bar)
	# world marker
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.fixed_size = true
	_marker.pixel_size = 0.0011
	_marker.font_size = 60
	_marker.outline_size = 16
	_marker.modulate = Color(1.0, 0.82, 0.3)
	_marker.outline_modulate = Color(0.1, 0.05, 0.0)
	world.add_child(_marker)
	story.changed.connect(_on_changed)
	story.mission_event.connect(_on_event)
	_refresh()


func _on_changed() -> void:
	story.refresh()
	_refresh()


func _on_event(kind: String, title: String) -> void:
	match kind:
		"new":
			_queue.append(["NEW MISSION\n" + title, "mission_new"])
		"done":
			_queue.append(["MISSION COMPLETE\n" + title, "seal_found"])


func banner(text: String, sfx: String = "") -> void:
	_queue.append([text, sfx])


func _refresh() -> void:
	var objs := story.active_objectives(4)
	for c in _t_lines.get_children():
		c.queue_free()
	if objs.is_empty():
		_t_title.text = "Journal"
		var l := Label.new()
		l.text = "No active mission"
		l.add_theme_font_size_override("font_size", 22)
		_t_lines.add_child(l)
		return
	_t_title.text = objs[0]["quest"]
	for o in objs:
		var l := Label.new()
		l.text = "• " + o["text"]
		l.add_theme_font_size_override("font_size", 22)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(430, 0)
		_t_lines.add_child(l)
	_tracker.reset_size()
	if _journal.visible:
		_fill_journal()


func _toggle_journal() -> void:
	_journal.visible = not _journal.visible
	if _journal.visible:
		_fill_journal()
	Sfx.ui("page_turn", -6.0)


func _fill_journal() -> void:
	for c in _j_list.get_children():
		c.queue_free()
	var h := Label.new()
	h.text = "JOURNAL"
	h.add_theme_font_size_override("font_size", 34)
	h.add_theme_color_override("font_color", Color(0.95, 0.74, 0.32))
	_j_list.add_child(h)
	for q in story.quests:
		if not (q["show"] as Callable).call():
			continue
		var done := story.quest_done(q)
		var t := Label.new()
		t.text = ("[done] " if done else "") + q["title"]
		t.add_theme_font_size_override("font_size", 30)
		t.add_theme_color_override("font_color", Color(0.6, 0.75, 0.55) if done else Color(0.97, 0.9, 0.7))
		_j_list.add_child(t)
		var b := Label.new()
		b.text = q["blurb"]
		b.add_theme_font_size_override("font_size", 22)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size = Vector2(700, 0)
		_j_list.add_child(b)
		for o in q["objs"]:
			var ol := Label.new()
			var od: bool = (o["done"] as Callable).call()
			ol.text = ("   [x] " if od else "   [ ] ") + (o["text"] as Callable).call()
			ol.add_theme_font_size_override("font_size", 24)
			ol.add_theme_color_override("font_color", Color(0.55, 0.65, 0.5) if od else Color(1, 1, 1))
			_j_list.add_child(ol)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 62)
	close.add_theme_font_size_override("font_size", 28)
	close.pressed.connect(func() -> void: _journal.visible = false)
	_j_list.add_child(close)


## Show a progress bar for `dur` seconds, locking the player; calls `done` at the end.
func progress(label: String, dur: float, done: Callable) -> void:
	_bar_label.text = label
	_bar_dur = dur
	_bar_t = 0.0
	_bar_cb = done
	_bar.max_value = dur
	_bar.value = 0.0
	_bar_root.visible = true
	player.locked = true


func _process(delta: float) -> void:
	if _bar_root.visible:
		_bar_t += delta
		_bar.value = _bar_t
		if _bar_t >= _bar_dur:
			_bar_root.visible = false
			player.locked = false
			if _bar_cb.is_valid():
				_bar_cb.call()
	# banners play one after another
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(minf(_banner_t, 3.2 - _banner_t) * 2.5, 0.0, 1.0) if _banner_t < 3.2 else 0.0
		if _banner_t <= 0.0:
			_banner.modulate.a = 0.0
	elif not _queue.is_empty():
		var b: Array = _queue.pop_front()
		_banner.text = b[0]
		_banner_t = 3.2
		if b[1] != "":
			Sfx.ui(b[1], -3.0)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_update_marker()


func _update_marker() -> void:
	var objs := story.active_objectives(1)
	if objs.is_empty() or player == null:
		_marker.visible = false
		return
	var tgt: Vector3 = objs[0]["target"]
	if tgt == Vector3.ZERO:
		_marker.visible = false
		return
	var d := player.global_position.distance_to(tgt)
	_marker.visible = d > 4.0
	_marker.global_position = tgt + Vector3(0, 3.0, 0)
	_marker.text = "◆\n%dm" % int(d)
