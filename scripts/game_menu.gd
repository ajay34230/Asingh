class_name GameMenu
extends CanvasLayer
## Pause button + menu (resume, volume, graphics quality, new game, quit) and save/load.
## Save file: user://save.json holds story flags and the player position. Autosaves on every
## story change and every 20 s. Works offline, on-device only.

const SAVE_PATH := "user://save.json"
const SLOT_PATH := "user://slot_%d.json"
const CHECKPOINT_PATH := "user://checkpoint.json"      # state at the start of the current mission

var story: Story
var player: Player
var main: Node3D
var _inv: Label
var _btn: Button
var _jr: Label
var _tr_box: VBoxContainer
var _it_box: VBoxContainer
var _sl_box: VBoxContainer
var _panel: PanelContainer
var _pages: Dictionary = {}          # page name -> Control
var _controls: Dictionary = {}       # setting key -> control, refreshed on reset
var _timer := 0.0


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.main = main
	GameSettings.ensure_buses()
	GameSettings.load_file()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_btn = Button.new()
	_btn.text = "II"
	_btn.add_theme_font_size_override("font_size", 28)
	_btn.anchor_left = 1.0
	_btn.anchor_right = 1.0
	_btn.offset_left = -250
	_btn.offset_right = -184
	_btn.offset_top = 14
	_btn.offset_bottom = 76
	_btn.pressed.connect(toggle)
	root.add_child(_btn)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.97)
	sb.border_color = Color(0.85, 0.65, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	var th := Theme.new()
	th.default_font_size = 26
	_panel.theme = th
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.05
	_panel.anchor_bottom = 0.95
	_panel.visible = false
	root.add_child(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	_panel.add_child(hb)
	# left: title and navigation
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(330, 0)
	nav.add_theme_constant_override("separation", 12)
	hb.add_child(nav)
	var h := Label.new()
	h.text = "PAUSED"
	h.add_theme_font_size_override("font_size", 40)
	h.add_theme_color_override("font_color", Color(0.95, 0.74, 0.32))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(h)
	nav.add_child(_button("Resume", toggle))
	nav.add_child(_button("Inventory", func() -> void: _show_page("Inventory")))
	nav.add_child(_button("Items & crafting", func() -> void: _show_page("Items")))
	nav.add_child(_button("Journal", func() -> void: _show_page("Journal")))
	nav.add_child(_button("Fast travel", func() -> void: _show_page("Travel")))
	nav.add_child(_button("Photo mode", func() -> void:
		toggle()
		var pm: Object = main.get("photo_mode")
		if pm != null:
			pm.call("enter")))
	nav.add_child(_button("Settings", func() -> void: _show_page("Settings")))
	nav.add_child(_button("How to play", func() -> void: _show_page("Help")))
	nav.add_child(_button("Save slots", func() -> void: _show_page("Slots")))
	nav.add_child(_button("Save game", func() -> void:
		save()
		(main as Node).get("hud").banner("Game saved")))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(sp)
	nav.add_child(_button("Restart mission", restart_mission))
	nav.add_child(_button("New game", func() -> void: _show_page("Confirm")))
	nav.add_child(_button("Quit", func() -> void:
		save()
		get_tree().quit()))
	var sep := VSeparator.new()
	hb.add_child(sep)
	# right: pages
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(stack)
	_pages["Inventory"] = _build_inventory()
	_pages["Items"] = _build_items()
	_pages["Journal"] = _build_journal()
	_pages["Travel"] = _build_travel()
	_pages["Slots"] = _build_slots()
	_pages["Settings"] = _build_settings()
	_pages["Help"] = _build_help()
	_pages["Confirm"] = _build_confirm()
	for k in _pages:
		var pg: Control = _pages[k]
		pg.set_anchors_preset(Control.PRESET_FULL_RECT)
		pg.visible = false
		stack.add_child(pg)
	_show_page("Inventory")
	story.changed.connect(save)
	story.mission_event.connect(func(kind: String, _t: String) -> void:
		if kind == "new":
			_write_checkpoint.call_deferred())
	_apply_settings.call_deferred()


func _apply_settings() -> void:
	GameSettings.apply_all()
	_sync_controls()


func _show_page(n: String) -> void:
	for k in _pages:
		(_pages[k] as Control).visible = (k == n)
	if n == "Inventory" and _inv != null:
		_inv.text = _inventory_text()
	if n == "Travel":
		_fill_travel()
	if n == "Items":
		_fill_items()
	if n == "Slots":
		_fill_slots()
	if n == "Journal" and _jr != null:
		_jr.text = _journal_text()
	Loc.apply_to_tree(_panel)


func _scroll_page(title: String) -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 14)
	sc.add_child(vb)
	if title != "":
		vb.add_child(_heading(title))
	return [sc, vb]


func _heading(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Color(0.95, 0.74, 0.32))
	return l


func _build_items() -> Control:
	var pg := _scroll_page("Items & crafting")
	_it_box = pg[1]
	return pg[0]


func _fill_items() -> void:
	for c in _it_box.get_children():
		if not (c is Label and (c as Label).get_theme_font_size("font_size") == 32):
			c.queue_free()
	var it: Items = main.get("items") as Items
	if it == null:
		return
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.text = Loc.t("Weapon") + ": " + Loc.t(_item_name(it.equipped("weapon"))) + "    " + Loc.t("Armour") + ": " + Loc.t(_item_name(it.equipped("armour")))
	_it_box.add_child(info)
	for id in Items.DEFS:
		var n := it.count(id)
		if n <= 0:
			continue
		var d: Dictionary = Items.DEFS[id]
		var row := _button("%s x%d - %s" % [Loc.t(String(d["name"])), n, Loc.t(String(d["desc"]))], func() -> void:
			if String(d["type"]) == "consumable":
				it.use(id)
			elif String(d["type"]) == "weapon" or String(d["type"]) == "armour":
				it.equip(id)
			_fill_items())
		_it_box.add_child(row)
	var fb := _button(Loc.t("Feed nearby animal (1 herb)"), func() -> void:
		if not it.feed_nearest():
			(main as Node).get("hud").banner(Loc.t("No animal close enough, or no herb."))
		_fill_items())
	fb.disabled = it.count("herb") < 1
	_it_box.add_child(fb)
	_it_box.add_child(_heading("Crafting"))
	for rid in Items.RECIPES:
		var rec: Array = Items.RECIPES[rid]
		var parts: Array[String] = []
		for k in rec[1]:
			parts.append("%d %s" % [int(rec[1][k]), Loc.t(String(Items.DEFS[k]["name"]))])
		var b := _button("%s  (%s)" % [Loc.t(String(Items.DEFS[rec[0]]["name"])), ", ".join(parts)], func() -> void:
			it.craft(rid)
			_fill_items())
		b.disabled = not it.can_craft(rid)
		_it_box.add_child(b)


func _item_name(id: String) -> String:
	return String(Items.DEFS[id]["name"]) if Items.DEFS.has(id) else "None"


func _build_slots() -> Control:
	var pg := _scroll_page("Save slots")
	_sl_box = pg[1]
	return pg[0]


func _fill_slots() -> void:
	for c in _sl_box.get_children():
		if not (c is Label and (c as Label).get_theme_font_size("font_size") == 32):
			c.queue_free()
	for n in [1, 2, 3]:
		var info := Label.new()
		info.text = "%s %d:  %s" % [Loc.t("Slot"), n, slot_info(n)]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		_sl_box.add_child(info)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_sl_box.add_child(row)
		var sb := _button("Save here", func() -> void:
			if slot_save(n):
				(main as Node).get("hud").banner(Loc.t("Saved to slot %d") % n)
			_fill_slots())
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sb)
		var lb := _button("Load", func() -> void: slot_load(n))
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.disabled = SaveSystem.read(SLOT_PATH % n).is_empty()
		row.add_child(lb)


func _build_travel() -> Control:
	var pg := _scroll_page("Fast travel")
	_tr_box = pg[1]
	return pg[0]


func _fill_travel() -> void:
	for c in _tr_box.get_children():
		if not (c is Label and (c as Label).get_theme_font_size("font_size") == 32):
			c.queue_free()
	var sh: Shrines = main.get("shrines") as Shrines
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tr_box.add_child(note)
	if sh == null or sh.lit_list().is_empty():
		note.text = Loc.t("Light a shrine by touching it to unlock fast travel.")
		return
	note.text = Loc.t("Travel to a lit shrine. Not allowed during or just after a fight.")
	for s in sh.lit_list():
		var id: String = s[0]
		_tr_box.add_child(_button(Loc.t(String(s[1])), func() -> void:
			if sh.travel(id):
				toggle()
			else:
				note.text = Loc.t("Enemies are too close to travel.")))


func _build_journal() -> Control:
	var pg := _scroll_page("Journal")
	var vb: VBoxContainer = pg[1]
	_jr = Label.new()
	_jr.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_jr)
	return pg[0]


func _journal_text() -> String:
	var ach: Achievements = main.get("achievements") as Achievements
	var out := Loc.t("Achievements") + "\n"
	if ach != null:
		out += "%d / %d\n\n" % [ach.count(), Achievements.DEFS.size()]
		for id in Achievements.DEFS:
			var d: Array = Achievements.DEFS[id]
			var mark := "[x] " if ach.done.has(id) else "[  ] "
			out += mark + Loc.t(String(d[0])) + " - " + Loc.t(String(d[1])) + "\n"
	return out


func _build_inventory() -> Control:
	var pg := _scroll_page("Inventory")
	var vb: VBoxContainer = pg[1]
	_inv = Label.new()
	_inv.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_inv)
	vb.add_child(_heading("Time of day and weather"))
	var note := Label.new()
	note.text = "Tap to set the lighting; Auto resumes the day cycle and the story's own weather."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(note)
	var lg := GridContainer.new()
	lg.columns = 3
	lg.add_theme_constant_override("h_separation", 8)
	lg.add_theme_constant_override("v_separation", 8)
	vb.add_child(lg)
	for nm in Atmosphere.LIGHTS.keys():
		lg.add_child(_grid_button(nm, func() -> void: (main.get("atmosphere") as Atmosphere).apply_preset(nm)))
	lg.add_child(_grid_button("Auto", func() -> void: (main.get("atmosphere") as Atmosphere).release_weather()))
	return pg[0]


func _grid_button(t: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(fn)
	return b


func _build_settings() -> Control:
	var tabs := TabContainer.new()
	tabs.add_theme_font_size_override("font_size", 28)
	for tab in GameSettings.TABS:
		var pg := _scroll_page("")
		var sc: ScrollContainer = pg[0]
		var vb: VBoxContainer = pg[1]
		sc.name = tab
		for s in GameSettings.SPEC:
			if s[0] == tab:
				vb.add_child(_row(s))
		if tab == "Audio":
			vb.add_child(_button("Test voices", func() -> void:
				Sfx.speak("man", "Welcome, traveller. The Queen's road is waiting for you.", null, 0.0, true, "Test")
				(main as Node).get("hud").banner(Sfx.voice_status())))
		vb.add_child(_button("Reset %s to defaults" % tab, func() -> void:
			GameSettings.reset_tab(tab)
			_sync_controls()))
		tabs.add_child(sc)
	return tabs


func _row(s: Array) -> Control:
	var key: String = s[1]
	var kind: String = s[3]
	var label: String = s[2]
	match kind:
		"toggle":
			var cb := CheckButton.new()
			cb.text = label
			cb.custom_minimum_size = Vector2(0, 56)
			cb.toggled.connect(func(on: bool) -> void: GameSettings.set_value(key, on))
			_controls[key] = cb
			return cb
		"choice":
			var hb := HBoxContainer.new()
			var l := Label.new()
			l.text = label
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(l)
			var ob := OptionButton.new()
			ob.custom_minimum_size = Vector2(260, 56)
			var opts: Array = s[5]
			for i in opts.size():
				ob.add_item(opts[i], i)
			ob.item_selected.connect(func(i: int) -> void: GameSettings.set_value(key, i))
			hb.add_child(ob)
			_controls[key] = ob
			return hb
		_:
			var hb2 := HBoxContainer.new()
			hb2.add_theme_constant_override("separation", 14)
			var l2 := Label.new()
			l2.text = label
			l2.custom_minimum_size = Vector2(380, 0)
			l2.autowrap_mode = TextServer.AUTOWRAP_WORD
			hb2.add_child(l2)
			var ex: Array = s[5]
			var sl := HSlider.new()
			sl.min_value = ex[0]
			sl.max_value = ex[1]
			sl.step = ex[2]
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sl.custom_minimum_size = Vector2(0, 48)
			hb2.add_child(sl)
			var vl := Label.new()
			vl.custom_minimum_size = Vector2(90, 0)
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hb2.add_child(vl)
			sl.value_changed.connect(func(val: float) -> void:
				vl.text = _fmt(val, ex)
				GameSettings.set_value(key, val))
			_controls[key] = sl
			sl.set_meta("vl", vl)
			return hb2


func _fmt(val: float, ex: Array) -> String:
	if float(ex[1]) <= 1.0:
		return "%d%%" % int(round(val * 100.0))
	if float(ex[2]) >= 1.0:
		return "%d" % int(val)
	return "%.2f" % val


## Show the stored values in every control without re-applying them.
func _sync_controls() -> void:
	for s in GameSettings.SPEC:
		var c: Control = _controls.get(s[1])
		if c == null:
			continue
		var val: Variant = GameSettings.get_v(s[1])
		if c is CheckButton:
			(c as CheckButton).set_pressed_no_signal(bool(val))
		elif c is OptionButton:
			(c as OptionButton).select(int(val))
		elif c is HSlider:
			(c as HSlider).set_value_no_signal(float(val))
			(c.get_meta("vl") as Label).text = _fmt(float(val), s[5])


func _build_help() -> Control:
	var pg := _scroll_page("How to play")
	var vb: VBoxContainer = pg[1]
	var t := Label.new()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.text = "Move: left stick. A light push walks, a firm push runs, a full push sprints.\n" \
		+ "Look: drag on the right side. Two fingers pinch to zoom the camera.\n" \
		+ "JUMP, HIT (hammer or knife), DUCK (crouch) and RUN are the round buttons; USE appears when something is in reach.\n" \
		+ "Ride: walk up to a horse, camel, donkey or bull and press Ride. Tap JUMP to get down.\n" \
		+ "Hunting: find the hunter's knife at the forest camp; skin what you bring down and sell it at the bazaar.\n" \
		+ "Map: tap the minimap. Journal: your missions and clues. Settings: audio, video, controls and gameplay options.\n" \
		+ "On a keyboard: WASD move, Shift run, Space jump, C crouch, E use or get off."
	vb.add_child(t)
	return pg[0]


func _build_confirm() -> Control:
	var pg := _scroll_page("Start a new game?")
	var vb: VBoxContainer = pg[1]
	var t := Label.new()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.text = "This erases your saved progress. Your settings are kept."
	vb.add_child(t)
	vb.add_child(_button("Yes, erase my save and start over", _new_game))
	vb.add_child(_button("No, go back", func() -> void: _show_page("Inventory")))
	return pg[0]


func _button(t: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(fn)
	return b


func _inventory_text() -> String:
	var pl: Player = player
	var c := int(story.get_flag("coins", 0))
	var lines: Array[String] = ["Coins: %d" % c, "Sun-Seals: %d / 3" % story.seals_held()]
	if int(story.get_flag("shards", 0)) > 0:
		lines.append("Pottery shards: %d / 6" % int(story.get_flag("shards", 0)))
	var gear: Array[String] = ["Sun-hammer" + (" (re-forged with the Queen's light, x1.4)" if story.get_flag("sun_hammer") else "")]
	if int(story.get_flag("meat", 0)) + int(story.get_flag("hides", 0)) > 0:
		lines.append("Game: %d meat, %d hides (sell at the bazaar leather stall)" % [int(story.get_flag("meat", 0)), int(story.get_flag("hides", 0))])
	if story.get_flag("hunting_knife"):
		gear.append("Hunter's knife (wild game can be hunted; hunted: %d)" % (pl.hunted if pl != null else 0))
	lines.append("Gear: " + ", ".join(gear))
	var keys: Array[String] = []
	if story.get_flag("race_won"):
		keys.append("Sun Pennant")
	if story.get_flag("clue_coins"):
		keys.append("Council coin clue")
	if story.get_flag("ledger_given"):
		keys.append("Reavers' ledger (delivered)")
	elif story.get_flag("tara_talked"):
		keys.append("Reavers' ledger")
	if story.get_flag("temple_blessed"):
		keys.append("Temple blessing")
	if keys.size() > 0:
		lines.append("Story items: " + ", ".join(keys))
	lines.append("Riding: walk up to a horse, camel, donkey or bull and press the Ride prompt.")
	return "\n".join(lines)


func toggle() -> void:
	var on := not _panel.visible
	_panel.visible = on
	get_tree().paused = on
	if on:
		_show_page("Inventory")
		save()


func _process(delta: float) -> void:
	_timer += delta
	if _timer > 20.0:
		_timer = 0.0
		save()


func _state() -> Dictionary:
	var p := player.global_position
	return {"flags": story.flags.duplicate(true), "pos": [p.x, p.y, p.z], "yaw": player.look_yaw(), "tod": main.atmosphere.time_of_day, "hp": player.hp}


func _write_checkpoint() -> void:
	if player != null and story != null and story.get_flag("intro_done"):
		SaveSystem.write(CHECKPOINT_PATH, _state())


## Go back to where the current mission began (flags, position, health), then reload the world.
func restart_mission() -> void:
	var d := SaveSystem.read(CHECKPOINT_PATH)
	if d.is_empty():
		(main as Node).get("hud").banner("No mission checkpoint yet. Start a mission first.")
		return
	if not SaveSystem.write(SAVE_PATH, d):
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func save() -> void:
	if player == null or story == null or not story.get_flag("intro_done"):
		return
	var p := player.global_position
	var d := {"flags": story.flags, "pos": [p.x, p.y, p.z], "yaw": player.look_yaw(), "tod": main.atmosphere.time_of_day,
		"hp": player.hp}
	if not SaveSystem.write(SAVE_PATH, d):
		push_warning("Save failed; the previous save is untouched.")


## X23: three manual save slots. Saving copies the current save; loading copies a slot over the save and
## reloads the world (the same way Restart mission works).
func slot_save(n: int) -> bool:
	save()
	var d := SaveSystem.read(SAVE_PATH)
	if d.is_empty():
		return false
	return SaveSystem.write(SLOT_PATH % n, d)


func slot_info(n: int) -> String:
	var d := SaveSystem.read(SLOT_PATH % n)
	if d.is_empty():
		return Loc.t("Empty")
	var t := Time.get_datetime_dict_from_unix_time(int(d.get("saved_unix", 0)) + 19800)
	var fl: Dictionary = d.get("flags", {})
	var act := "1"
	if fl.get("act4_done", false):
		act = "5"
	elif fl.get("act3_done", false):
		act = "4"
	elif fl.get("captain_down", false):
		act = "3"
	elif fl.get("gate_open", false):
		act = "2"
	return "%02d/%02d %02d:%02d  -  %s %s  -  %s %d" % [t["day"], t["month"], t["hour"], t["minute"], Loc.t("Act"), act, Loc.t("Coins"), int(fl.get("coins", 0))]


func slot_load(n: int) -> bool:
	var d := SaveSystem.read(SLOT_PATH % n)
	if d.is_empty() or not SaveSystem.write(SAVE_PATH, d):
		return false
	get_tree().paused = false
	get_tree().reload_current_scene()
	return true


static func has_save() -> bool:
	return SaveSystem.exists(SAVE_PATH)


## Returns true if a save was applied.
func load_save() -> bool:
	if not has_save():
		return false
	var d := SaveSystem.read(SAVE_PATH)
	if d.is_empty():
		return false
	for k in d["flags"]:
		story.flags[k] = d["flags"][k]
	player.has_knife = bool(story.get_flag("hunting_knife"))
	var p: Array = d["pos"]
	player.global_position = Vector3(p[0], p[1] + 0.3, p[2])
	player.velocity = Vector3.ZERO
	player.set_look(float(d.get("yaw", 0.0)), -0.05)
	var saved_hp := float(d.get("hp", -1.0))
	player.hp = player.max_hp if saved_hp <= 0.0 else minf(saved_hp, player.max_hp)
	main.atmosphere.time_of_day = float(d.get("tod", 0.33))
	main.atmosphere.apply_time()
	story.changed.emit()
	return true


func _new_game() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + suffix))
	get_tree().paused = false
	get_tree().reload_current_scene()
