class_name CharacterMenu
extends CanvasLayer
## Choose who you play: your explorer (with the wardrobe's outfits) or one of the downloadable characters.
## A character is downloaded the first time you pick it; after that it is on the phone.

var player: Player
var wardrobe: Node
var _grid: GridContainer
var _note: Label
var _all_btn: Button
var _mon_grid: GridContainer


func _ready() -> void:
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("character_menu")
	var panel := PanelContainer.new()
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.94
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.98)
	sb.border_color = Color(0.85, 0.65, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = Loc.t("CHARACTERS")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_all_btn = Button.new()
	_all_btn.add_theme_font_size_override("font_size", 24)
	_all_btn.custom_minimum_size = Vector2(0, 60)
	_all_btn.focus_mode = Control.FOCUS_NONE
	_all_btn.pressed.connect(_download_all)
	top.add_child(_all_btn)
	var close := Button.new()
	close.text = Loc.t("CLOSE")
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 22)
	_note.text = Loc.t("Characters are downloaded when you first choose them, so the game stays small.")
	v.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 14)
	scroll.add_child(inner)
	inner.add_child(_grid)
	var ml := Label.new()
	ml.text = Loc.t("Monsters (also playable; their missions ask for them)")
	ml.add_theme_font_size_override("font_size", 26)
	ml.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	inner.add_child(ml)
	_mon_grid = GridContainer.new()
	_mon_grid.columns = 5
	_mon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mon_grid.add_theme_constant_override("h_separation", 12)
	_mon_grid.add_theme_constant_override("v_separation", 12)
	inner.add_child(_mon_grid)


func open() -> void:
	visible = true
	_refresh()


static func current() -> String:
	return String(GameSettings.v.get("hero", ""))


## Every character not on the phone yet, and their total size.
static func missing() -> Array:
	var out: Array = []
	for id in HeroStore.CATALOG:
		if not HeroStore.is_downloaded(id):
			out.append(id)
	return out


static func missing_kb() -> int:
	var kb := 0
	for id in missing():
		kb += int(HeroStore.CATALOG[id][2])
	return kb


func _refresh() -> void:
	for g in [_grid, _mon_grid]:
		for c in (g as Node).get_children():
			c.queue_free()
	_card(_grid, "", Loc.t("Explorer"), null)
	for id in HeroStore.CATALOG:
		_card(_grid if HeroStore.CATALOG[id][1] == "hero" else _mon_grid, id, HeroStore.title(id), HeroStore.portrait(id))
	var miss := missing()
	_all_btn.disabled = miss.is_empty()
	_all_btn.text = Loc.t("All downloaded") if miss.is_empty() else \
			Loc.t("Download all") + " (%d, %.0f MB)" % [miss.size(), missing_kb() / 1024.0]
	_note.text = Loc.tf("%d of %d characters on this phone. Tap a card to download or use it.", [HeroStore.CATALOG.size() - miss.size(), HeroStore.CATALOG.size()])


func _download_all() -> void:
	var miss := missing()
	if miss.is_empty():
		return
	DlcDialog.ask(self, miss, Loc.tf("Download all %d characters (%.0f MB)? Use Wi-Fi if you can.", [miss.size(), missing_kb() / 1024.0]), func(_ok: bool) -> void:
		_refresh())


func _card(grid: GridContainer, id: String, title: String, pic: Texture2D) -> void:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr := TextureRect.new()
	tr.texture = pic
	tr.custom_minimum_size = Vector2(0, 170)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(tr)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	v.add_child(l)
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	if current() == id:
		b.text = Loc.t("In use")
		b.disabled = true
	elif id == "" or HeroStore.is_downloaded(id):
		b.text = Loc.t("Use")
	else:
		b.text = Loc.t("Download") + " " + HeroStore.size_text(id)
	b.pressed.connect(_pick.bind(id))
	v.add_child(b)
	if id != "" and HeroStore.is_downloaded(id) and current() != id:
		var del := Button.new()
		del.text = Loc.t("Remove")
		del.add_theme_font_size_override("font_size", 18)
		del.custom_minimum_size = Vector2(0, 44)
		del.focus_mode = Control.FOCUS_NONE
		del.pressed.connect(func() -> void:
			HeroStore.remove(id)
			_refresh())
		v.add_child(del)
	grid.add_child(v)


func _pick(id: String) -> void:
	if id != "" and not HeroStore.is_downloaded(id):
		DlcDialog.ask(self, [id], Loc.tf("Download %s (%s)?", [HeroStore.title(id), HeroStore.size_text(id)]), func(ok: bool) -> void:
			if ok:
				_pick(id)
			else:
				_refresh())
		return
	CharacterMenu.apply(player, wardrobe, id)
	_refresh()


## Play as this character ("" = the explorer in the wardrobe's outfit). Remembered between games.
static func apply(p: Player, ward: Node, id: String) -> void:
	GameSettings.v["hero"] = id
	GameSettings.save_file()
	if id == "" or not HeroStore.is_downloaded(id):
		GameSettings.v["hero"] = ""
		if ward != null:
			ward.call("wear", String(ward.call("worn")))
		return
	p.set_body({"body": "dl:" + id, "natural": true, "scale": 1.0})
