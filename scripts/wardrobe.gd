class_name Wardrobe
extends CanvasLayer
## Clothes and warrior uniforms: something to spend coins on.
## Three shops with different stock: the cloth stalls in Bazaar Town (everyday clothes, royal robes, dyes,
## supplies), the tailor at Kesar Sarai (travel and hunting sets), the armourer at Dhoopgarh (heavy warrior
## uniforms). An outfit changes the whole look (body model, colours, helmet, shoulder pads) and gives armour
## and a small bonus. Bought outfits can be worn anywhere from the pause menu (II > Wardrobe).
## Ownership and the worn outfit are story flags, so they save with the game.

const OUTFITS := [
	{"id": "explorer", "name": "Explorer's Mail", "shop": "", "price": 0, "body": {"body": "striker_mail", "robe": true, "scale": 0.99},
	 "dye": [Color(0.7, 0.2, 0.12), Color(0.35, 0.22, 0.12)], "armor": 1.0, "bonus": {}, "desc": "Your trusty travelling mail."},
	{"id": "kurta", "name": "Village Kurta", "shop": "bazaar", "price": 60, "body": {"body": "m_Farmer", "scale": 1.0},
	 "dye": [Color(0.95, 0.93, 0.86), Color(0.95, 0.55, 0.12)], "turban": [Color(0.95, 0.55, 0.1), Color(0.85, 0.2, 0.15)],
	 "sash": Color(0.15, 0.45, 0.25), "armor": 1.0, "bonus": {"run": 0.05}, "desc": "White cotton kurta, saffron safa. Run 5% faster."},
	{"id": "adventurer", "name": "Adventurer's Gear", "shop": "bazaar", "price": 120, "body": {"body": "m_Adventurer", "scale": 1.0, "natural": true},
	 "armor": 0.95, "bonus": {"regen": 0.1}, "desc": "Leather straps and a good pack. 5% armour, stamina +10%."},
	{"id": "maharaja", "name": "Maharaja's Robes", "shop": "bazaar", "price": 1000, "body": {"body": "m_King", "scale": 1.0, "natural": true},
	 "sash": Color(0.95, 0.76, 0.25), "cape": [Color(0.5, 0.05, 0.1), Color(0.95, 0.78, 0.25), 1.2],
	 "armor": 0.9, "bonus": {"xp": 0.15}, "desc": "Silk, gold and a royal cape. 10% armour, +15% XP."},
	{"id": "shadow", "name": "Shadow Garb", "shop": "sarai", "price": 220, "body": {"body": "thief", "robe": true, "scale": 1.0},
	 "dye": [Color(0.1, 0.1, 0.12), Color(0.6, 0.62, 0.68)], "sash": Color(0.3, 0.3, 0.34), "armor": 0.92, "bonus": {"run": 0.08}, "desc": "Dark and quiet. 8% armour, run 8% faster."},
	{"id": "ghost_hunter", "name": "Ghost Hunter Set", "shop": "sarai", "price": 480, "body": {"body": "thief", "robe": true, "scale": 1.0},
	 "dye": [Color(0.16, 0.18, 0.24), Color(0.55, 0.8, 0.95)], "helmet": "Helmet2", "pads": true, "cape": [Color(0.14, 0.16, 0.22), Color(0.55, 0.8, 0.95), 0.8], "armor": 0.8,
	 "bonus": {"ghost": 0.2, "arrow": 0.1}, "desc": "Silvered trims. 20% armour, +20% vs ghosts, +10% arrows."},
	{"id": "rajput", "name": "Rajput Warrior", "shop": "dhoop", "price": 350, "body": {"body": "veteran", "robe": true, "scale": 1.0},
	 "dye": [Color(0.92, 0.5, 0.1), Color(0.6, 0.08, 0.08)], "turban": [Color(0.93, 0.45, 0.08), Color(0.95, 0.78, 0.25)],
	 "sash": Color(0.65, 0.08, 0.1), "pads": true, "armor": 0.8,
	 "bonus": {"melee": 0.05}, "desc": "Saffron angrakha, safa and sash, steel pauldrons. 20% armour, +5% melee."},
	{"id": "royal_guard", "name": "Royal Guard Uniform", "shop": "dhoop", "price": 450, "body": {"body": "striker_mail", "robe": true, "scale": 1.0},
	 "dye": [Color(0.1, 0.18, 0.6), Color(0.06, 0.1, 0.32)], "helmet": "Helmet2", "pads": true,
	 "cape": [Color(0.1, 0.16, 0.55), Color(0.95, 0.78, 0.25), 1.05], "sash": Color(0.95, 0.76, 0.25), "armor": 0.75,
	 "bonus": {}, "desc": "Blue and gold of the palace guard. 25% armour."},
	{"id": "warlord", "name": "Brute Warlord", "shop": "dhoop", "price": 650, "body": {"body": "brute", "robe": true, "scale": 1.0},
	 "dye": [Color(0.4, 0.05, 0.05), Color(0.7, 0.5, 0.25)], "helmet": "Helmet1", "pads": true,
	 "cape": [Color(0.25, 0.04, 0.03), Color(0.55, 0.4, 0.2), 0.85], "armor": 0.72,
	 "bonus": {"melee": 0.1}, "desc": "Heavy hide and iron. 28% armour, +10% melee."},
	{"id": "knight", "name": "Knight of Veyra", "shop": "dhoop", "price": 800, "body": {"body": "knight", "scale": 1.0, "natural": true},
	 "helmet": "Helmet3", "cape": [Color(0.6, 0.05, 0.08), Color(0.95, 0.78, 0.25), 1.1], "armor": 0.62, "bonus": {"run": -0.04}, "desc": "Full plate. 38% armour, but 4% slower."},
]
const DYES := [
	["Saffron", Color(0.95, 0.55, 0.1)], ["Crimson", Color(0.75, 0.1, 0.12)], ["Royal blue", Color(0.12, 0.2, 0.62)],
	["Emerald", Color(0.1, 0.5, 0.28)], ["Indigo", Color(0.25, 0.15, 0.45)], ["Ivory", Color(0.94, 0.92, 0.85)],
	["Charcoal", Color(0.14, 0.14, 0.16)], ["Gold", Color(0.95, 0.76, 0.25)],
]
const DYE_PRICE := 25
const SUPPLIES := [["potion", 40], ["herb", 12], ["iron", 30], ["essence", 70]]
const SHOP_NAMES := {"bazaar": "Bazaar Cloth Merchant", "sarai": "Tailor of Kesar Sarai", "dhoop": "Dhoopgarh Armourer", "": "Wardrobe"}

var story: Story
var player: Player
var hud: Node
var _root: Control
var _list: VBoxContainer
var _title: Label
var _money: Label
var _shop := ""
var open := false
var _tried := false
var _cam_d := -1.0


static func outfit(id: String) -> Dictionary:
	for o in OUTFITS:
		if String(o["id"]) == id:
			return o
	return OUTFITS[0]


func setup(s: Story, p: Player, h: Node) -> void:
	story = s
	player = p
	hud = h
	layer = 30
	add_to_group("wardrobe")
	_root = Panel.new()
	_root.anchor_left = 0.4             # the left side stays clear so you can see yourself in the clothes
	_root.anchor_right = 0.98
	_root.anchor_top = 0.06
	_root.anchor_bottom = 0.94
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.93)
	sb.border_color = Color(0.85, 0.65, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	_root.add_theme_stylebox_override("panel", sb)
	_root.visible = false
	add_child(_root)
	var vb := VBoxContainer.new()
	vb.anchor_right = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left = 22
	vb.offset_right = -22
	vb.offset_top = 16
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 10)
	_root.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.95, 0.74, 0.32))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 26)
	top.add_child(_money)
	var x := Button.new()
	x.text = "  Close X  "
	x.add_theme_font_size_override("font_size", 26)
	x.pressed.connect(close)
	top.add_child(x)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 12
	sc.get_v_scroll_bar().custom_minimum_size = Vector2(40, 0)
	vb.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	sc.add_child(_list)


func owns(id: String) -> bool:
	return id == "explorer" or bool(story.get_flag("own_" + id, false))


func worn() -> String:
	return String(story.get_flag("outfit_worn", "explorer"))


## Dress the player in an outfit (and its colours / armour pieces / bonuses).
func wear(id: String, keep_flag: bool = true) -> void:
	var o := outfit(id)
	player.set_body(o["body"])
	var main_c: Variant = story.get_flag("dye_" + id + "_main", null)
	var trim_c: Variant = story.get_flag("dye_" + id + "_trim", null)
	var dye: Array = []
	if o.has("dye") or main_c != null:
		var d: Array = o.get("dye", [Color(0.5, 0.5, 0.5), Color(0.9, 0.75, 0.3)])
		dye = [_col(main_c, d[0]), _col(trim_c, d[1])]
	# real-looking fabric, leather and metal; dyes only touch the garments
	ClothLook.dress(player._rig, dye)
	var main_dye: Color = dye[0] if not dye.is_empty() else Color(0.6, 0.15, 0.1)
	var helmet_on := o.has("helmet") and bool(story.get_flag("show_helmet", true))
	if helmet_on:
		player._rig.add_gear(String(o["helmet"]), "helmet")
	if o.has("turban") and not helmet_on:
		var tc: Array = o["turban"]
		player._rig.add_gear_node(ClothLook.turban(tc[0], tc[1]), "turban")
	if bool(o.get("pads", false)):
		player._rig.add_gear("ShoulderPads", "pads")
	if o.has("sash"):
		player._rig.add_gear_node(ClothLook.sash(o["sash"]), "sash")
	if o.has("cape"):
		var cc: Array = o["cape"]
		player._rig.add_gear_node(ClothLook.cape(cc[0] if main_c == null else main_dye, cc[1], float(cc[2]) if cc.size() > 2 else 1.05), "cape")
	player.outfit_armor = float(o["armor"])
	player.outfit_bonus = o["bonus"]
	if keep_flag:
		story.set_flag("outfit_worn", id)
	var pg := get_tree().get_first_node_in_group("progression")
	if pg != null:
		pg.call("apply")


static func _col(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is String and String(v).begins_with("#"):
		return Color(String(v))
	return fallback


func buy(id: String) -> bool:
	var o := outfit(id)
	if owns(id) or int(story.get_flag("coins", 0)) < int(o["price"]):
		return false
	story.add("coins", -int(o["price"]))
	story.set_flag("own_" + id, true)
	Sfx.ui("coin_clink", -2.0)
	LogCollector.event("bought outfit " + id)
	wear(id)
	if hud != null:
		hud.call("banner", "New outfit: " + String(o["name"]), "seal_found")
	return true


func dye(main_c: Color) -> bool:
	if int(story.get_flag("coins", 0)) < DYE_PRICE:
		return false
	story.add("coins", -DYE_PRICE)
	var id := worn()
	story.set_flag("dye_" + id + "_main", "#" + main_c.to_html(false))
	if story.get_flag("dye_" + id + "_trim", null) == null:
		story.set_flag("dye_" + id + "_trim", "#" + Color(0.95, 0.78, 0.3).to_html(false))
	Sfx.ui("ui_blip", -4.0)
	wear(id)
	return true


func buy_supply(item: String, price: int) -> bool:
	if int(story.get_flag("coins", 0)) < price:
		return false
	var it := get_tree().get_first_node_in_group("items")
	if it == null:
		return false
	story.add("coins", -price)
	it.call("give", item)
	Sfx.ui("coin_clink", -4.0)
	return true


## Open a shop ("bazaar", "sarai", "dhoop") or the plain wardrobe ("") with owned outfits only.
func open_shop(shop: String) -> void:
	_shop = shop
	open = true
	_root.visible = true
	player.locked = true
	# turn the camera round to look at you from the front, standing on the left of the screen
	_cam_d = player._target_distance
	player.set_look(player._model.rotation.y + PI - 0.5, -0.08)
	player.set_distance(3.2)
	_fill()


func close() -> void:
	open = false
	_root.visible = false
	player.locked = false
	if _cam_d > 0.0:
		player.set_distance(_cam_d)
	if _tried:
		_tried = false
		wear(worn())            # tried something on without buying: back to your own clothes


func _row(text: String, size: int = 22, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _btn(text: String, fn: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 22)
	b.disabled = disabled
	b.pressed.connect(fn)
	return b


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	_title.text = Loc.t(String(SHOP_NAMES.get(_shop, "Wardrobe")))
	var coins := int(story.get_flag("coins", 0))
	_money.text = "%d coins   " % coins
	var gold := Color(0.95, 0.74, 0.32)
	_list.add_child(_row("OUTFITS" if _shop != "" else "YOUR OUTFITS", 26, gold))
	for o in OUTFITS:
		var id: String = o["id"]
		var own := owns(id)
		if _shop == "" and not own:
			continue
		if _shop != "" and String(o["shop"]) != _shop and not (own and id == worn()):
			continue
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var info := _row("%s%s\n%s" % [String(o["name"]), "   (wearing)" if id == worn() else "", String(o["desc"])], 22,
			Color(0.6, 1.0, 0.6) if id == worn() else Color.WHITE)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		if own:
			hb.add_child(_btn("Wear", func() -> void:
				wear(id)
				_fill(), id == worn()))
		else:
			var price := int(o["price"])
			hb.add_child(_btn("Try on", func() -> void:
				_tried = true
				wear(id, false)))
			hb.add_child(_btn("Buy %d" % price, func() -> void:
				if buy(id):
					_fill(), coins < price))
		_list.add_child(hb)
	if _shop != "":
		_list.add_child(_row("DYE YOUR CLOTHES (%d coins)" % DYE_PRICE, 26, gold))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for d in DYES:
			var c: Color = d[1]
			var b := _btn(String(d[0]), func() -> void:
				if dye(c):
					_fill(), coins < DYE_PRICE)
			b.custom_minimum_size = Vector2(190, 52)
			var st := StyleBoxFlat.new()
			st.bg_color = c.darkened(0.15)
			st.set_corner_radius_all(8)
			b.add_theme_stylebox_override("normal", st)
			var st_off := st.duplicate() as StyleBoxFlat
			st_off.bg_color = c.darkened(0.55)
			b.add_theme_stylebox_override("disabled", st_off)
			b.add_theme_color_override("font_color", Color.BLACK if c.get_luminance() > 0.5 else Color.WHITE)
			grid.add_child(b)
		_list.add_child(grid)
		var hel := _btn("Helmet: " + ("shown" if bool(story.get_flag("show_helmet", true)) else "hidden"), func() -> void:
			story.set_flag("show_helmet", not bool(story.get_flag("show_helmet", true)))
			wear(worn())
			_fill())
		_list.add_child(hel)
	if _shop == "bazaar":
		_list.add_child(_row("SUPPLIES", 26, gold))
		for sp in SUPPLIES:
			var item: String = sp[0]
			var price2: int = sp[1]
			_list.add_child(_btn("%s   %d coins" % [String(Items.DEFS[item]["name"]), price2], func() -> void:
				if buy_supply(item, price2):
					_fill(), coins < price2))
	if _shop == "":
		var hel2 := _btn("Helmet: " + ("shown" if bool(story.get_flag("show_helmet", true)) else "hidden"), func() -> void:
			story.set_flag("show_helmet", not bool(story.get_flag("show_helmet", true)))
			wear(worn())
			_fill())
		_list.add_child(hel2)
	Loc.apply_to_tree(_root)


