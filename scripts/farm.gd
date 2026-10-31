class_name Farm
extends Node3D
## The family farm where the game starts. A farmhouse (rest and save), a field of plots where crops are planted,
## watered at each stage and, once ripe, harvested by driving the tractor over them; the harvest is sold at the
## Farmers' Market in the bazaar (which appears on the map after the first harvest) for coins. An orchard grows
## trees from saplings bought at the market. Coins also buy upgrades, goods and gear.
##
## Growth runs on the real clock and is saved, so crops keep growing while the game is closed.
## Saved as story flags: plot_<i> = "crop|state|stage|ends_unix|fert", tree_<i> = "kind|planted_unix|fruit_unix",
## counters crop_<name>, fruit_mango, timber, honey, seed_<name>, sap_<kind>, fertilizer and the upgrade flags.

const CROPS := {
	"wheat": {"name": "Wheat", "seed": 5, "stage": 22.0, "sell": 9, "col": Color(0.92, 0.78, 0.3)},
	"corn": {"name": "Corn", "seed": 8, "stage": 30.0, "sell": 13, "col": Color(1.0, 0.85, 0.2)},
	"tomato": {"name": "Tomato", "seed": 12, "stage": 36.0, "sell": 20, "col": Color(0.9, 0.2, 0.15)},
	"cotton": {"name": "Cotton", "seed": 18, "stage": 45.0, "sell": 32, "col": Color(0.96, 0.96, 0.92)},
}
const TREES := {
	"mango": {"name": "Mango sapling", "cost": 40, "timber": 2, "fruit": true, "canopy": Color(0.2, 0.46, 0.16)},
	"neem": {"name": "Neem sapling", "cost": 30, "timber": 4, "fruit": false, "canopy": Color(0.16, 0.38, 0.14)},
	"banyan": {"name": "Banyan sapling", "cost": 80, "timber": 8, "fruit": false, "canopy": Color(0.12, 0.34, 0.16)},
}
const SELL := {"wheat": 9, "corn": 13, "tomato": 20, "cotton": 32, "mango": 14, "timber": 22, "honey": 30}
const GOODS := {"wheat": "Wheat", "corn": "Corn", "tomato": "Tomatoes", "cotton": "Cotton", "mango": "Mangoes", "timber": "Timber", "honey": "Honey"}
const PLOT_SIZE := 6.0
const GROW_STAGES := 2           # watered twice: seedling -> young -> ripe
const TREE_AGE := [0.0, 60.0, 150.0]   # seconds: sapling, young, mature
const FRUIT_EVERY := 90.0
const HIVE_EVERY := 100.0
const ORCHARD_SPOTS := 8

var main: Node3D
var terrain: TerrainBuilder
var story: Story
var player: Player
var hud: Node
var coins: CoinSystem
var items: Items
var shop: ShopUI
var c: Vector2 = TerrainBuilder.FARM_C
var gy := 0.0
var plots: Array = []            # {node, pos, crop, state, stage, ends, fert, itn, soil, mm_stalk, mm_head, label, arrow}
var spots: Array = []            # orchard: {node, pos, kind, planted, fruit_at, itn, canopy, trunk, fruit}
var tractor: Node3D
var driving := false
var _t_heading := 0.0
var _t_speed := 0.0
var _wheels: Array[Node3D] = []
var _tick_t := 0.0
var _bob := 0.0
var _hive: Node3D
var _hive_itn: Interactable
var market: Node3D
var market_pos := Vector3.ZERO
var _msg_cd := 0.0
var _seed_itn: Interactable
var _hive_t := 0.0
var _soil_dry: StandardMaterial3D
var _soil_wet: StandardMaterial3D
var _stalk_mat: StandardMaterial3D
var _dismount_cd := 0.0


static func start_position(t: TerrainBuilder) -> Vector3:
	var p := TerrainBuilder.FARM_C + Vector2(0.0, 11.0)
	return Vector3(p.x, t.sample_height(p.x, p.y) + 0.3, p.y)


func now() -> float:
	return Time.get_unix_time_from_system()


func flag_n(k: String) -> int:
	return int(story.get_flag(k, 0))


func build() -> void:
	name = "Farm"
	gy = terrain.sample_height(c.x, c.y)
	_soil_dry = PropFactory.material(Color(0.42, 0.29, 0.17), 1.0)
	_soil_wet = PropFactory.material(Color(0.22, 0.15, 0.09), 1.0)
	_stalk_mat = PropFactory.material(Color(0.3, 0.55, 0.2), 0.9)
	_ensure_init()
	_build_house()
	_build_fences()
	_build_barn()
	_build_plots(6 + 3 * flag_n("plots_extra"))
	_build_orchard()
	_build_scarecrows()
	_build_hive()
	shop = ShopUI.new()
	shop.player = player
	shop.coins = coins
	main.add_child(shop)
	_load_state()
	_refresh_map()
	_build_market.call_deferred()


## After a save file replaced the flags: rebuild plots, trees, upgrades and starter stock from them.
func reload() -> void:
	_ensure_init()
	_build_plots(6 + 3 * flag_n("plots_extra"))
	for i in spots.size():
		var sp: Dictionary = spots[i]
		if sp["tree"] != null:
			(sp["tree"] as Node3D).queue_free()
			sp["tree"] = null
		sp["kind"] = ""
		_refresh_spot(i)
	for i in plots.size():
		var pl: Dictionary = plots[i]
		pl["state"] = "empty"
		pl["crop"] = ""
		pl["stage"] = 0
		_refresh_plot(i)
	_load_state()
	_update_seed_prompt()
	_refresh_map()


func _ensure_init() -> void:
	if not story.get_flag("farm_init", false):
		story.set_flag("farm_init", true)
		for k in ["wheat", "corn"]:
			story.set_flag("seed_" + k, 6 if k == "wheat" else 3)
		story.set_flag("fertilizer", 2)
		if coins.balance() < 20:
			coins.add(20 - coins.balance())


func ground(x: float, z: float) -> float:
	return terrain.sample_height(x, z)


# --- farmhouse ------------------------------------------------------------------------------------

func _build_house() -> void:
	var h := Node3D.new()
	h.name = "Farmhouse"
	h.position = Vector3(c.x, gy, c.y + 21.0)
	add_child(h)
	var wall := PropFactory.mud_brick()
	var wood := PropFactory.wood()
	var roof := PropFactory.material(Color(0.55, 0.22, 0.14), 0.9)
	var w := 9.0
	var d := 7.0
	var ht := 3.2
	PropFactory.box(h, Vector3(w + 0.6, 0.3, d + 0.6), Vector3(0, 0.15, 0), PropFactory.stone(Color(0.55, 0.5, 0.42)))   # floor slab
	PropFactory.box(h, Vector3(w, ht, 0.4), Vector3(0, ht * 0.5 + 0.3, d * 0.5), wall)                                # back
	PropFactory.box(h, Vector3(0.4, ht, d), Vector3(-w * 0.5, ht * 0.5 + 0.3, 0), wall)                               # left
	PropFactory.box(h, Vector3(0.4, ht, d), Vector3(w * 0.5, ht * 0.5 + 0.3, 0), wall)                                # right
	var door := 1.8
	var seg := (w - door) * 0.5
	PropFactory.box(h, Vector3(seg, ht, 0.4), Vector3(-(door + seg) * 0.5, ht * 0.5 + 0.3, -d * 0.5), wall)           # front-left
	PropFactory.box(h, Vector3(seg, ht, 0.4), Vector3((door + seg) * 0.5, ht * 0.5 + 0.3, -d * 0.5), wall)            # front-right
	PropFactory.box(h, Vector3(door, 0.9, 0.4), Vector3(0, ht - 0.15 + 0.3, -d * 0.5), wall)                          # lintel
	PropFactory.box(h, Vector3(w + 1.2, 0.25, d * 0.5 + 0.9), Vector3(0, ht + 1.0, -d * 0.25 - 0.1), roof, Vector3(18, 0, 0), false, false)
	PropFactory.box(h, Vector3(w + 1.2, 0.25, d * 0.5 + 0.9), Vector3(0, ht + 1.0, d * 0.25 + 0.1), roof, Vector3(-18, 0, 0), false, false)
	# porch posts and a bench by the door
	for sx in [-1.0, 1.0]:
		PropFactory.box(h, Vector3(0.22, 2.6, 0.22), Vector3(sx * 2.4, 1.6, -d * 0.5 - 1.4), wood)
	PropFactory.box(h, Vector3(6.0, 0.18, 0.3), Vector3(0, 2.95, -d * 0.5 - 1.4), wood, Vector3.ZERO, false)
	PropFactory.box(h, Vector3(1.8, 0.14, 0.5), Vector3(-3.2, 0.7, -d * 0.5 - 0.6), wood, Vector3.ZERO, false)
	# inside: bed, table and a lamp; the bed is where you sleep and save
	PropFactory.box(h, Vector3(1.4, 0.45, 2.4), Vector3(-w * 0.5 + 1.2, 0.55, d * 0.5 - 1.6), wood)
	PropFactory.box(h, Vector3(1.3, 0.2, 2.2), Vector3(-w * 0.5 + 1.2, 0.85, d * 0.5 - 1.6), PropFactory.cloth(Color(0.7, 0.25, 0.2)), Vector3.ZERO, false)
	PropFactory.box(h, Vector3(1.6, 0.9, 1.0), Vector3(w * 0.5 - 1.3, 0.75, d * 0.5 - 1.2), wood)
	PropFactory.box(h, Vector3(0.9, 0.55, 0.6), Vector3(0.0, 0.58, d * 0.5 - 0.8), wood)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.45)
	lamp.omni_range = 7.0
	lamp.light_energy = 0.9
	lamp.position = Vector3(0, 2.6, 0)
	h.add_child(lamp)
	var bed := Interactable.new()
	bed.position = Vector3(-w * 0.5 + 1.2, 1.0, d * 0.5 - 1.6)
	bed.reach = 2.4
	bed.prompt = "Sleep until morning (saves the game)"
	h.add_child(bed)
	bed.on_interact = func(_by: Node3D, _me: Interactable) -> void: rest_at_home()
	# seed bag: pick the crop you plant
	var bag := Interactable.new()
	bag.position = Vector3(w * 0.5 - 1.3, 1.3, d * 0.5 - 1.2)
	bag.reach = 2.4
	h.add_child(bag)
	_seed_itn = bag
	bag.on_interact = func(_by: Node3D, _me: Interactable) -> void: cycle_crop()
	_update_seed_prompt()
	# signboard
	var sign_l := Label3D.new()
	sign_l.text = Loc.t("HOME FARM")
	sign_l.font_size = 64
	sign_l.pixel_size = 0.01
	sign_l.outline_size = 10
	sign_l.modulate = Color(1.0, 0.9, 0.6)
	sign_l.position = Vector3(0, ht + 0.6, -d * 0.5 - 1.5)
	sign_l.rotation_degrees = Vector3(0, 180, 0)
	h.add_child(sign_l)


func selected_crop() -> String:
	var k := String(story.get_flag("sel_crop", "wheat"))
	return k if CROPS.has(k) else "wheat"


func cycle_crop() -> void:
	var keys: Array = CROPS.keys()
	var i := keys.find(selected_crop())
	story.set_flag("sel_crop", String(keys[(i + 1) % keys.size()]))
	_update_seed_prompt()
	player.say("%s: %d seeds. Plant them in the field; water twice and they ripen." % [Loc.t(String(CROPS[selected_crop()]["name"])), flag_n("seed_" + selected_crop())])


func _update_seed_prompt() -> void:
	if _seed_itn == null:
		return
	var k := selected_crop()
	_seed_itn.prompt = "Seed bag: %s (%d) - tap to change crop" % [Loc.t(String(CROPS[k]["name"])), flag_n("seed_" + k)]


func rest_at_home() -> void:
	player.hp = player.max_hp
	main.atmosphere.time_of_day = 0.32
	main.atmosphere.apply_time()
	hud.banner(Loc.t("You sleep soundly and wake at dawn. Health restored."), "")
	var mn: Variant = main.get("menu")
	if mn != null:
		(mn as GameMenu).save()


func _build_fences() -> void:
	var wood := PropFactory.wood(Color(0.42, 0.3, 0.18))
	var x0 := -17.0
	var x1 := 17.0
	var z_top := -9.0
	var z_bot := 8.0
	var posts: Array[Vector3] = []
	for x in range(int(x0), int(x1) + 1, 4):
		posts.append(Vector3(c.x + x, 0, c.y + z_bot))
	for z in range(int(z_bot), int(z_top) - 1, -4):
		posts.append(Vector3(c.x + x0, 0, c.y + z))
		posts.append(Vector3(c.x + x1, 0, c.y + z))
	for p in posts:
		if absf(p.x - c.x) < 3.0 and p.z > c.y + 6.0:
			continue                                   # gap in the fence: the farm gate
		var y := ground(p.x, p.z)
		var post := PropFactory.box(self, Vector3(0.16, 1.1, 0.16), Vector3(p.x, y + 0.55, p.z), wood, Vector3.ZERO, false, false)
		post.name = "FencePost"
	for x in range(int(x0), int(x1), 4):
		if absf(c.x + x + 2.0 - c.x) < 3.0:
			continue
		PropFactory.box(self, Vector3(4.0, 0.1, 0.08), Vector3(c.x + x + 2.0, gy + 0.8, c.y + z_bot), wood, Vector3.ZERO, false, false)


func _build_barn() -> void:
	var b := Node3D.new()
	b.name = "Barn"
	b.position = Vector3(c.x + 22.0, gy, c.y + 10.0)
	add_child(b)
	var wood := PropFactory.wood(Color(0.5, 0.2, 0.15))
	var roof := PropFactory.material(Color(0.4, 0.3, 0.24), 0.9)
	PropFactory.box(b, Vector3(7.0, 0.2, 6.0), Vector3(0, 0.1, 0), PropFactory.stone(Color(0.5, 0.46, 0.4)), Vector3.ZERO, false)
	PropFactory.box(b, Vector3(0.3, 3.6, 6.0), Vector3(3.4, 1.9, 0), wood)
	PropFactory.box(b, Vector3(7.0, 3.6, 0.3), Vector3(0, 1.9, 2.9), wood)
	PropFactory.box(b, Vector3(7.4, 0.25, 7.0), Vector3(0, 3.9, 0), roof, Vector3.ZERO, false, false)
	for sx in [-3.3]:
		PropFactory.box(b, Vector3(0.25, 3.6, 0.25), Vector3(sx, 1.9, -2.8), wood)
		PropFactory.box(b, Vector3(0.25, 3.6, 0.25), Vector3(sx, 1.9, 2.8), wood)
	# the tractor, nose pointing at the fields
	tractor = Node3D.new()
	tractor.name = "Tractor"
	tractor.position = Vector3(c.x + 20.0, gy, c.y + 8.0)
	_build_tractor(tractor)
	add_child(tractor)
	var it := Interactable.new()
	it.position = Vector3(0, 1.4, 0)
	it.reach = 3.6
	it.prompt = "Drive the tractor (harvests ripe crops)"
	tractor.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void: mount_tractor()


func _build_tractor(t: Node3D) -> void:
	var red := PropFactory.material(Color(0.78, 0.14, 0.1), 0.6, 0.2)
	var dark := PropFactory.material(Color(0.12, 0.12, 0.13), 0.9)
	var steel := PropFactory.material(Color(0.6, 0.6, 0.62), 0.5, 0.6)
	var yellow := PropFactory.material(Color(0.95, 0.78, 0.15), 0.6)
	PropFactory.box(t, Vector3(1.5, 0.7, 1.7), Vector3(0, 0.95, -0.9), red, Vector3.ZERO, false, false)      # hood
	PropFactory.box(t, Vector3(1.6, 0.25, 1.6), Vector3(0, 0.78, 0.8), red, Vector3.ZERO, false, false)      # deck
	PropFactory.box(t, Vector3(0.5, 0.35, 0.5), Vector3(0, 1.3, 0.9), dark, Vector3.ZERO, false, false)      # seat
	for sx in [-0.7, 0.7]:
		for sz in [0.25, 1.35]:
			PropFactory.box(t, Vector3(0.08, 1.4, 0.08), Vector3(sx, 1.7, sz), steel, Vector3.ZERO, false, false)
	PropFactory.box(t, Vector3(1.7, 0.1, 1.5), Vector3(0, 2.45, 0.8), red, Vector3.ZERO, false, false)       # cab roof
	PropFactory.cylinder(t, 0.06, 0.06, 0.9, Vector3(0.45, 1.6, -1.4), steel, Vector3.ZERO, false, 8, 0, false)  # exhaust
	PropFactory.box(t, Vector3(3.4, 0.25, 0.5), Vector3(0, 0.5, -2.1), yellow, Vector3.ZERO, false, false)   # harvester header
	for k in 7:
		PropFactory.box(t, Vector3(0.08, 0.5, 0.08), Vector3(-1.5 + k * 0.5, 0.3, -2.3), steel, Vector3.ZERO, false, false)
	for spec in [[-0.95, 0.9, 0.7], [0.95, 0.9, 0.7], [-0.8, -1.2, 0.42], [0.8, -1.2, 0.42]]:
		var wx: float = spec[0]
		var wz: float = spec[1]
		var wr: float = spec[2]
		var wh := Node3D.new()
		wh.position = Vector3(wx, wr, wz)
		t.add_child(wh)
		var tire := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = wr
		cm.bottom_radius = wr
		cm.height = 0.45 if wr > 0.5 else 0.3
		cm.radial_segments = 14
		tire.mesh = cm
		tire.material_override = dark
		tire.rotation.z = PI * 0.5
		wh.add_child(tire)
		var lug := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5 if wr > 0.5 else 0.34, 0.1, wr * 2.1)
		lug.mesh = bm
		lug.material_override = steel
		wh.add_child(lug)
		_wheels.append(wh)


# --- fields ---------------------------------------------------------------------------------------

func _plot_pos(i: int) -> Vector3:
	var col := i % 3
	var row := i / 3
	var x := c.x + (col - 1) * (PLOT_SIZE + 1.2)
	var z := c.y + 2.0 - row * (PLOT_SIZE + 1.2)
	return Vector3(x, ground(x, z), z)


func _build_plots(n: int) -> void:
	for i in range(plots.size(), n):
		_make_plot(i)


func _make_plot(i: int) -> void:
	var p := _plot_pos(i)
	var root := Node3D.new()
	root.name = "Plot%d" % i
	root.position = p
	add_child(root)
	var soil := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(PLOT_SIZE - 0.4, 0.14, PLOT_SIZE - 0.4)
	soil.mesh = sm
	soil.material_override = _soil_dry
	soil.position.y = 0.05
	root.add_child(soil)
	# furrow ridges
	var ridge := PropFactory.material(Color(0.34, 0.23, 0.13), 1.0)
	for k in 5:
		var rb := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.28, 0.12, PLOT_SIZE - 0.8)
		rb.mesh = rm
		rb.material_override = ridge
		rb.position = Vector3(-2.2 + k * 1.1, 0.15, 0)
		root.add_child(rb)
	var mm_s := _make_mm(root, true)
	var mm_h := _make_mm(root, false)
	var lab := Label3D.new()
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 54
	lab.pixel_size = 0.009
	lab.outline_size = 12
	lab.no_depth_test = true
	lab.position = Vector3(0, 2.3, 0)
	lab.visible = false
	root.add_child(lab)
	var arrow := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.0
	am.bottom_radius = 0.4
	am.height = 0.7
	arrow.mesh = am
	var amat := PropFactory.material(Color(1.0, 0.85, 0.2), 0.4)
	amat.emission_enabled = true
	amat.emission = Color(1.0, 0.75, 0.1)
	amat.emission_energy_multiplier = 1.0
	arrow.material_override = amat
	arrow.rotation.x = PI
	arrow.position = Vector3(0, 3.4, 0)
	arrow.visible = false
	root.add_child(arrow)
	var it := Interactable.new()
	it.position = Vector3(0, 1.0, 0)
	it.reach = 4.2
	root.add_child(it)
	var idx := i
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void: _use_plot(idx)
	plots.append({"node": root, "pos": p, "crop": "", "state": "empty", "stage": 0, "ends": 0.0, "fert": false,
		"itn": it, "soil": soil, "mm_s": mm_s, "mm_h": mm_h, "label": lab, "arrow": arrow, "water_t": 0.0})
	_refresh_plot(i)


func _make_mm(parent: Node3D, stalk: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var m := CylinderMesh.new()
	m.top_radius = 0.0 if stalk else 0.15
	m.bottom_radius = 0.09 if stalk else 0.15
	m.height = 1.0 if stalk else 0.3
	m.radial_segments = 6
	m.rings = 1
	mm.mesh = m
	mm.instance_count = 16
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _stalk_mat.duplicate() if stalk else PropFactory.material(Color(1, 1, 1), 0.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _use_plot(i: int) -> void:
	var pl: Dictionary = plots[i]
	match String(pl["state"]):
		"empty":
			var k := selected_crop()
			if flag_n("seed_" + k) <= 0:
				for alt in CROPS.keys():
					if flag_n("seed_" + String(alt)) > 0:
						k = String(alt)
						break
			if flag_n("seed_" + k) <= 0:
				player.say("No seeds left. Buy seeds at the Farmers' Market in the bazaar.")
				return
			plant(i, k)
		"dry":
			water(i)
		"grow":
			player.say("It is growing. Come back soon.")
		"ready":
			player.say("Ripe! Drive the tractor over the field to harvest it.")


func plant(i: int, crop: String) -> bool:
	var pl: Dictionary = plots[i]
	if String(pl["state"]) != "empty" or flag_n("seed_" + crop) <= 0:
		return false
	story.set_flag("seed_" + crop, flag_n("seed_" + crop) - 1)
	var fert := false
	if flag_n("fertilizer") > 0:
		story.set_flag("fertilizer", flag_n("fertilizer") - 1)
		fert = true
	pl["crop"] = crop
	pl["state"] = "dry"
	pl["stage"] = 0
	pl["fert"] = fert
	pl["ends"] = 0.0
	Sfx.at("dig_0", pl["pos"] as Vector3, -6.0, 1.2)
	_save_plot(i)
	_refresh_plot(i)
	_update_seed_prompt()
	return true


func water(i: int) -> bool:
	var pl: Dictionary = plots[i]
	if String(pl["state"]) != "dry":
		return false
	var dur := float(CROPS[String(pl["crop"])]["stage"]) * (0.5 if bool(pl["fert"]) else 1.0)
	pl["state"] = "grow"
	pl["ends"] = now() + dur
	Sfx.at("dig_0", pl["pos"] as Vector3, -8.0, 1.8)
	HitFx.burst(self, (pl["pos"] as Vector3) + Vector3(0, 0.6, 0), false, Color(0.5, 0.75, 1.0))
	_save_plot(i)
	_refresh_plot(i)
	return true


func ripe_count() -> int:
	var n := 0
	for pl in plots:
		if String((pl as Dictionary)["state"]) == "ready":
			n += 1
	return n


## Harvest one ripe plot into the stores; returns the amount.
func harvest(i: int) -> int:
	var pl: Dictionary = plots[i]
	if String(pl["state"]) != "ready":
		return 0
	var k := String(pl["crop"])
	var n := 4 + (2 if bool(pl["fert"]) else 0) + mini(flag_n("scarecrows"), 3)
	story.set_flag("crop_" + k, flag_n("crop_" + k) + n)
	story.add("harvests")
	pl["state"] = "empty"
	pl["crop"] = ""
	pl["stage"] = 0
	pl["fert"] = false
	var pos := pl["pos"] as Vector3
	HitFx.burst(self, pos + Vector3(0, 1.0, 0), true, CROPS[k]["col"] as Color)
	Sfx.at("dig_0", pos, -4.0, 0.7)
	_save_plot(i)
	_refresh_plot(i)
	if not story.get_flag("first_harvest", false):
		story.set_flag("first_harvest", true)
		hud.banner(Loc.t("First harvest! Sell it at the Farmers' Market in the bazaar. It is now marked on your map."), "seal_found")
		if main.get("map_ui") != null and market != null:
			(main.get("map_ui") as MapUI).set_waypoint(market_pos)
	elif _msg_cd <= 0.0:
		hud.banner("+%d %s" % [n, Loc.t(String(CROPS[k]["name"]))], "")
		_msg_cd = 1.2
	_refresh_map()
	return n


func _refresh_plot(i: int) -> void:
	var pl: Dictionary = plots[i]
	var st := String(pl["state"])
	var k := String(pl["crop"])
	var itn := pl["itn"] as Interactable
	var lab := pl["label"] as Label3D
	var arrow := pl["arrow"] as MeshInstance3D
	var mm_s := (pl["mm_s"] as MultiMeshInstance3D).multimesh
	var mm_h := (pl["mm_h"] as MultiMeshInstance3D).multimesh
	var stage := int(pl["stage"])
	(pl["soil"] as MeshInstance3D).material_override = _soil_wet if st == "grow" else _soil_dry
	lab.visible = st == "dry" or st == "ready"
	arrow.visible = st == "ready"
	match st:
		"empty":
			itn.prompt = "Plant %s (%d seeds)" % [Loc.t(String(CROPS[selected_crop()]["name"])), flag_n("seed_" + selected_crop())]
		"dry":
			lab.text = Loc.t("Needs water")
			lab.modulate = Color(0.55, 0.8, 1.0)
			itn.prompt = "Water the %s (%d of %d)" % [Loc.t(String(CROPS[k]["name"])), stage + 1, GROW_STAGES]
		"grow":
			itn.prompt = "%s is growing..." % Loc.t(String(CROPS[k]["name"]))
		"ready":
			lab.text = Loc.t("READY TO HARVEST")
			lab.modulate = Color(1.0, 0.9, 0.3)
			itn.prompt = "Ripe %s: drive the tractor over it" % Loc.t(String(CROPS[k]["name"]))
	# plants: seedlings, young plants and ripe crops
	if st == "empty":
		mm_s.visible_instance_count = 0
		mm_h.visible_instance_count = 0
		return
	var heights := [0.4, 0.8, 1.2]
	var h: float = heights[clampi(stage if st != "ready" else 2, 0, 2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + plots.find(pl)
	mm_s.visible_instance_count = 16
	var ripe := st == "ready"
	for j in 16:
		var gx := -2.25 + (j % 4) * 1.5 + rng.randf_range(-0.12, 0.12)
		var gz := -2.25 + (j / 4) * 1.5 + rng.randf_range(-0.12, 0.12)
		var sb := Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0))
		mm_s.set_instance_transform(j, Transform3D(sb, Vector3(gx, 0.12 + h * 0.5, gz)))
		mm_h.set_instance_transform(j, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.0)), Vector3(gx, 0.12 + h + 0.08, gz)))
	mm_h.visible_instance_count = 16 if ripe else 0
	var col: Color = CROPS[k]["col"]
	((pl["mm_h"] as MultiMeshInstance3D).material_override as StandardMaterial3D).albedo_color = col
	var sm := (pl["mm_s"] as MultiMeshInstance3D).material_override as StandardMaterial3D
	sm.albedo_color = Color(0.3, 0.55, 0.2) if not ripe else (Color(0.85, 0.72, 0.3) if k == "wheat" else Color(0.34, 0.5, 0.2))


func _save_plot(i: int) -> void:
	var pl: Dictionary = plots[i]
	story.set_flag("plot_%d" % i, "%s|%s|%d|%.0f|%d" % [pl["crop"], pl["state"], int(pl["stage"]), float(pl["ends"]), 1 if bool(pl["fert"]) else 0])


func _load_state() -> void:
	for i in plots.size():
		var s := String(story.get_flag("plot_%d" % i, ""))
		if s == "":
			continue
		var p := s.split("|")
		if p.size() < 5 or not CROPS.has(p[0]) and p[0] != "":
			continue
		var pl: Dictionary = plots[i]
		pl["crop"] = p[0]
		pl["state"] = p[1]
		pl["stage"] = int(p[2])
		pl["ends"] = float(p[3])
		pl["fert"] = p[4] == "1"
		_advance_plot(i)
	for i in ORCHARD_SPOTS:
		var ts := String(story.get_flag("tree_%d" % i, ""))
		if ts == "":
			continue
		var tp := ts.split("|")
		if tp.size() >= 3 and TREES.has(tp[0]):
			_grow_tree_node(i, tp[0], float(tp[1]), float(tp[2]))
	_hive_t = now()
	_refresh_hive()


## Grow a plot forward in time (also catches up the time the game was closed).
func _advance_plot(i: int) -> void:
	var pl: Dictionary = plots[i]
	var guard := 0
	while String(pl["state"]) == "grow" and now() >= float(pl["ends"]) and guard < 4:
		guard += 1
		pl["stage"] = int(pl["stage"]) + 1
		if int(pl["stage"]) >= GROW_STAGES:
			pl["state"] = "ready"
			Sfx.at("seal_found", pl["pos"] as Vector3, -12.0, 1.4)
		else:
			pl["state"] = "dry"
		_save_plot(i)
	_refresh_plot(i)


# --- orchard --------------------------------------------------------------------------------------

func _spot_pos(i: int) -> Vector3:
	var x := c.x + 19.0 + (i % 2) * 6.0
	var z := c.y - 2.0 - (i / 2) * 5.0
	return Vector3(x, ground(x, z), z)


func _build_orchard() -> void:
	var ring := PropFactory.material(Color(0.4, 0.3, 0.18), 1.0)
	for i in ORCHARD_SPOTS:
		var p := _spot_pos(i)
		var root := Node3D.new()
		root.name = "Spot%d" % i
		root.position = p
		add_child(root)
		var mound := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.3
		cm.height = 0.18
		cm.radial_segments = 12
		mound.mesh = cm
		mound.material_override = ring
		mound.position.y = 0.05
		root.add_child(mound)
		var itn := Interactable.new()
		itn.position = Vector3(0, 1.0, 0)
		itn.reach = 3.0
		root.add_child(itn)
		var idx := i
		itn.on_interact = func(_by: Node3D, _me: Interactable) -> void: _use_spot(idx)
		spots.append({"node": root, "pos": p, "kind": "", "planted": 0.0, "fruit_at": 0.0, "itn": itn, "tree": null})
		_refresh_spot(i)
	var lab := Label3D.new()
	lab.text = Loc.t("ORCHARD (plant saplings)")
	lab.font_size = 56
	lab.pixel_size = 0.01
	lab.outline_size = 10
	lab.modulate = Color(0.7, 1.0, 0.6)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(c.x + 22.0, gy + 3.6, c.y + 2.0)
	add_child(lab)


func tree_stage(sp: Dictionary) -> int:
	if String(sp["kind"]) == "":
		return -1
	var age := now() - float(sp["planted"])
	return 2 if age >= TREE_AGE[2] else (1 if age >= TREE_AGE[1] else 0)


func _use_spot(i: int) -> void:
	var sp: Dictionary = spots[i]
	var k := String(sp["kind"])
	if k == "":
		for kind in TREES.keys():
			if flag_n("sap_" + String(kind)) > 0:
				plant_tree(i, String(kind))
				return
		player.say("No saplings. Buy saplings at the Farmers' Market and plant them here.")
		return
	var st := tree_stage(sp)
	if st < 2:
		player.say("The young %s tree is still growing." % Loc.t(k))
		return
	if bool(TREES[k]["fruit"]) and now() >= float(sp["fruit_at"]):
		story.set_flag("fruit_mango", flag_n("fruit_mango") + 3)
		sp["fruit_at"] = now() + FRUIT_EVERY
		story.set_flag("tree_%d" % i, "%s|%.0f|%.0f" % [k, sp["planted"], sp["fruit_at"]])
		hud.banner("+3 " + Loc.t("Mangoes"), "")
		_refresh_spot(i)
		return
	fell_tree(i)


func plant_tree(i: int, kind: String) -> bool:
	var sp: Dictionary = spots[i]
	if String(sp["kind"]) != "" or flag_n("sap_" + kind) <= 0:
		return false
	story.set_flag("sap_" + kind, flag_n("sap_" + kind) - 1)
	var t0 := now()
	story.set_flag("tree_%d" % i, "%s|%.0f|%.0f" % [kind, t0, t0 + TREE_AGE[2] + FRUIT_EVERY])
	_grow_tree_node(i, kind, t0, t0 + TREE_AGE[2] + FRUIT_EVERY)
	Sfx.at("dig_0", sp["pos"] as Vector3, -4.0, 1.0)
	return true


func _grow_tree_node(i: int, kind: String, planted: float, fruit_at: float) -> void:
	var sp: Dictionary = spots[i]
	sp["kind"] = kind
	sp["planted"] = planted
	sp["fruit_at"] = fruit_at
	var root := sp["node"] as Node3D
	var tree := Node3D.new()
	tree.name = "Tree"
	root.add_child(tree)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.18
	tm.bottom_radius = 0.3
	tm.height = 3.0
	tm.radial_segments = 8
	trunk.mesh = tm
	trunk.material_override = PropFactory.wood(Color(0.36, 0.25, 0.16))
	trunk.position.y = 1.5
	tree.add_child(trunk)
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.5 if kind != "banyan" else 2.1
	sm.height = 2.4 if kind != "banyan" else 2.4
	sm.radial_segments = 10
	sm.rings = 6
	canopy.mesh = sm
	canopy.material_override = PropFactory.material(TREES[kind]["canopy"] as Color, 0.9)
	canopy.position.y = 3.3
	tree.add_child(canopy)
	var fruit := Node3D.new()
	fruit.name = "Fruit"
	tree.add_child(fruit)
	if bool(TREES[kind]["fruit"]):
		var fm := PropFactory.material(Color(1.0, 0.65, 0.1), 0.5)
		for j in 7:
			var f := MeshInstance3D.new()
			var fs := SphereMesh.new()
			fs.radius = 0.16
			fs.height = 0.32
			f.mesh = fs
			f.material_override = fm
			var a := j * TAU / 7.0
			f.position = Vector3(cos(a) * 1.25, 3.0 + 0.3 * sin(j * 2.0), sin(a) * 1.25)
			fruit.add_child(f)
	sp["tree"] = tree
	_refresh_spot(i)


func _refresh_spot(i: int) -> void:
	var sp: Dictionary = spots[i]
	var itn := sp["itn"] as Interactable
	var k := String(sp["kind"])
	if k == "":
		itn.prompt = "Plant a sapling here"
		return
	var tree := sp["tree"] as Node3D
	var st := tree_stage(sp)
	var sc: float = [0.3, 0.62, 1.0][clampi(st, 0, 2)]
	tree.scale = Vector3.ONE * sc
	var ready_fruit := bool(TREES[k]["fruit"]) and st >= 2 and now() >= float(sp["fruit_at"])
	(tree.get_node("Fruit") as Node3D).visible = ready_fruit
	if st < 2:
		itn.prompt = "Growing %s tree (stage %d of 3)" % [Loc.t(k), st + 1]
	elif ready_fruit:
		itn.prompt = "Pick ripe mangoes"
	else:
		itn.prompt = "Fell the %s tree for timber" % Loc.t(k)


func fell_tree(i: int) -> void:
	var sp: Dictionary = spots[i]
	var k := String(sp["kind"])
	if k == "" or tree_stage(sp) < 2:
		return
	var n := int(TREES[k]["timber"])
	story.set_flag("timber", flag_n("timber") + n)
	story.add("trees_grown")
	story.set_flag("tree_%d" % i, "")
	(sp["tree"] as Node3D).queue_free()
	sp["tree"] = null
	sp["kind"] = ""
	HitFx.burst(self, (sp["pos"] as Vector3) + Vector3(0, 1.5, 0), true, Color(0.5, 0.35, 0.2))
	Sfx.at("kick_hit", sp["pos"] as Vector3, -4.0, 0.6)
	hud.banner("+%d %s" % [n, Loc.t("Timber")], "")
	_refresh_spot(i)


# --- scarecrows and beehive ------------------------------------------------------------------------

func _build_scarecrows() -> void:
	for i in mini(flag_n("scarecrows"), 3):
		_scarecrow(i)


func _scarecrow(i: int) -> void:
	var xo: Array = [-12.5, 12.5, 0.0]
	var zo: Array = [-8.0, -8.0, -24.0]
	var x: float = c.x + float(xo[i])
	var z: float = c.y + float(zo[i])
	var s := Node3D.new()
	s.position = Vector3(x, ground(x, z), z)
	add_child(s)
	var wood := PropFactory.wood()
	PropFactory.box(s, Vector3(0.1, 2.0, 0.1), Vector3(0, 1.0, 0), wood, Vector3.ZERO, false, false)
	PropFactory.box(s, Vector3(1.4, 0.1, 0.1), Vector3(0, 1.6, 0), wood, Vector3.ZERO, false, false)
	PropFactory.box(s, Vector3(0.5, 0.7, 0.2), Vector3(0, 1.3, 0), PropFactory.cloth(Color(0.7, 0.3, 0.2)), Vector3.ZERO, false, false)
	PropFactory.sphere(s, 0.22, Vector3(0, 2.05, 0), PropFactory.cloth(Color(0.85, 0.75, 0.5)), Vector3.ONE, false)


func _build_hive() -> void:
	_hive = Node3D.new()
	_hive.position = Vector3(c.x - 20.0, gy, c.y + 8.0)
	add_child(_hive)
	var wood := PropFactory.wood(Color(0.7, 0.55, 0.25))
	for k in 3:
		PropFactory.box(_hive, Vector3(0.9, 0.3, 0.9), Vector3(0, 0.4 + k * 0.32, 0), wood, Vector3.ZERO, false, false)
	PropFactory.box(_hive, Vector3(1.05, 0.1, 1.05), Vector3(0, 1.4, 0), PropFactory.wood(), Vector3.ZERO, false, false)
	_hive_itn = Interactable.new()
	_hive_itn.position = Vector3(0, 0.9, 0)
	_hive_itn.reach = 2.6
	_hive.add_child(_hive_itn)
	_hive_itn.on_interact = func(_by: Node3D, _me: Interactable) -> void: collect_honey()
	_hive.visible = story.get_flag("beehive", false)
	_hive_itn.enabled = _hive.visible


func _refresh_hive() -> void:
	if not story.get_flag("beehive", false):
		_hive.visible = false
		_hive_itn.enabled = false
		return
	_hive.visible = true
	_hive_itn.enabled = true
	_hive_itn.prompt = "Collect honey (%d ready)" % flag_n("hive_honey")


func collect_honey() -> int:
	var n := flag_n("hive_honey")
	if n <= 0:
		player.say("The bees are still working. Come back later.")
		return 0
	story.set_flag("honey", flag_n("honey") + n)
	story.set_flag("hive_honey", 0)
	hud.banner("+%d %s" % [n, Loc.t("Honey")], "")
	_refresh_hive()
	return n


# --- tractor --------------------------------------------------------------------------------------

func mount_tractor() -> void:
	if driving or player.locked or player.dead or player.mounted:
		return
	driving = true
	player.locked = true
	player.mounted = true
	player.jump_requested = false
	_t_heading = tractor.rotation.y
	_t_speed = 0.0
	player._rig.set_react("ride")
	player.set_distance(7.0)
	_dismount_cd = 0.6
	Sfx.ui("powerup", -6.0)
	player.say("Tractor: stick to drive, JUMP to get off. Drive over ripe fields to harvest them.")


func dismount_tractor() -> void:
	if not driving:
		return
	driving = false
	var side := Vector3(cos(tractor.rotation.y), 0.0, -sin(tractor.rotation.y)) * 2.2
	var p := tractor.global_position + side
	p.y = ground(p.x, p.z) + 0.4
	player.global_position = p
	player.velocity = Vector3.ZERO
	player._rig.set_react("")
	player.locked = false
	player.mounted = false
	player.set_distance(6.0)
	_t_speed = 0.0


func _physics_process(delta: float) -> void:
	if not driving:
		return
	if player.dead:
		dismount_tractor()
		return
	_dismount_cd = maxf(0.0, _dismount_cd - delta)
	if _dismount_cd <= 0.0 and (player.jump_requested or Input.is_physical_key_pressed(KEY_E)):
		player.jump_requested = false
		dismount_tractor()
		return
	var inp := player.move_input
	if inp.length() < 0.05:
		inp = player._keyboard_input()
	var want := 0.0
	if inp.length() > 0.12:
		var cam_fwd := Vector3(-sin(player._yaw), 0.0, -cos(player._yaw))
		var cam_right := Vector3(cos(player._yaw), 0.0, -sin(player._yaw))
		var dir := cam_fwd * inp.y + cam_right * inp.x
		_t_heading = lerp_angle(_t_heading, atan2(-dir.x, -dir.z), 1.0 - exp(-2.6 * delta))
		want = 10.0 if (player.sprint or inp.length() > 0.85) else 6.0
	_t_speed = move_toward(_t_speed, want, (5.0 if want > _t_speed else 9.0) * delta)
	tractor.rotation.y = _t_heading
	var fwd := Vector3(-sin(_t_heading), 0.0, -cos(_t_heading))
	var step := fwd * _t_speed * delta
	if _t_speed > 0.2:
		var from := tractor.global_position + Vector3(0, 0.9, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 3.0)
		q.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] is StaticBody3D and absf((hit["normal"] as Vector3).y) < 0.6:
			step = Vector3.ZERO
			_t_speed = 0.0
	var np := tractor.global_position + step
	np.x = clampf(np.x, -190.0, 190.0)
	np.z = clampf(np.z, -190.0, 190.0)
	np.y = ground(np.x, np.z)
	var ahead := ground(np.x + fwd.x * 1.5, np.z + fwd.z * 1.5)
	var behind := ground(np.x - fwd.x * 1.5, np.z - fwd.z * 1.5)
	tractor.global_position = np
	tractor.rotation.x = lerpf(tractor.rotation.x, clampf(atan2(ahead - behind, 3.0), -0.4, 0.4), 1.0 - exp(-8.0 * delta))
	for w in _wheels:
		w.rotation.x += _t_speed * delta * 2.2
	player.global_position = tractor.global_transform * Vector3(0, 1.0, 0.9)
	player.velocity = Vector3.ZERO
	player._model.rotation.y = _t_heading
	_harvest_under_tractor()


func header_range() -> float:
	return 5.4 if story.get_flag("up_header", false) else 4.0


func _harvest_under_tractor() -> void:
	var tp := tractor.global_position
	for i in plots.size():
		var pl: Dictionary = plots[i]
		if String(pl["state"]) != "ready":
			continue
		var pp := pl["pos"] as Vector3
		if Vector2(pp.x - tp.x, pp.z - tp.z).length() < header_range():
			harvest(i)


# --- time -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_msg_cd = maxf(0.0, _msg_cd - delta)
	_bob += delta
	_tick_t -= delta
	for pl in plots:
		var ar := (pl as Dictionary)["arrow"] as MeshInstance3D
		if ar.visible:
			ar.position.y = 3.4 + sin(_bob * 3.0) * 0.25
			ar.rotation.y = _bob * 2.0
	if _tick_t > 0.0:
		return
	_tick_t = 0.5
	var changed := false
	for i in plots.size():
		var pl: Dictionary = plots[i]
		var st := String(pl["state"])
		if st == "grow":
			var before := st
			_advance_plot(i)
			if String(pl["state"]) != before:
				changed = true
		elif st == "dry" and story.get_flag("up_sprinkler", false):
			pl["water_t"] = float(pl["water_t"]) + 0.5
			if float(pl["water_t"]) >= 3.0:
				pl["water_t"] = 0.0
				water(i)
	for i in spots.size():
		if String((spots[i] as Dictionary)["kind"]) != "":
			_refresh_spot(i)
	if story.get_flag("beehive", false) and now() - _hive_t >= HIVE_EVERY:
		_hive_t = now()
		story.set_flag("hive_honey", mini(flag_n("hive_honey") + 1, 6))
		_refresh_hive()
	if changed:
		_refresh_map()


# --- map ------------------------------------------------------------------------------------------

func _refresh_map() -> void:
	var mp: Variant = main.get("map_ui")
	if mp == null:
		return
	var list: Array = [{"pos": Vector3(c.x, gy, c.y + 17.0), "col": Color(0.4, 0.9, 0.4), "label": "Home farm"}]
	if ripe_count() > 0:
		list.append({"pos": Vector3(c.x, gy, c.y - 2.0), "col": Color(1.0, 0.9, 0.2), "label": "Crops ready"})
	if story.get_flag("first_harvest", false) and market != null:
		list.append({"pos": market_pos, "col": Color(1.0, 0.65, 0.15), "label": "Farmers' Market"})
	(mp as MapUI).extra = list


# --- market ---------------------------------------------------------------------------------------

func _build_market() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tc: Vector2 = TerrainBuilder.TOWN_C
	var space := get_world_3d().direct_space_state
	var spot := Vector2(tc.x, tc.y - 9.0)
	var cands: Array[Vector2] = []
	for r in [9.0, 11.0, 7.0, 13.0]:
		for k in 8:
			var a := TAU * k / 8.0
			cands.append(tc + Vector2(cos(a), sin(a)) * r)
	for cand in cands:
		var sh := SphereShape3D.new()
		sh.radius = 2.8
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = sh
		qp.transform = Transform3D(Basis.IDENTITY, Vector3(cand.x, terrain.sample_height(cand.x, cand.y) + 1.4, cand.y))
		qp.exclude = [player.get_rid()]
		var res := space.intersect_shape(qp, 4)
		var clear := true
		for r2 in res:
			if (r2["collider"] as Node) is StaticBody3D:
				clear = false
				break
		if clear:
			spot = cand
			break
	market = Node3D.new()
	market.name = "FarmersMarket"
	market_pos = Vector3(spot.x, terrain.sample_height(spot.x, spot.y), spot.y)
	market.position = market_pos
	market.rotation.y = atan2(-(tc.x - spot.x), -(tc.y - spot.y)) + PI
	add_child(market)
	var wood := PropFactory.wood(Color(0.45, 0.3, 0.17))
	PropFactory.box(market, Vector3(3.6, 1.0, 1.2), Vector3(0, 0.5, 0), wood)
	for sx in [-1.7, 1.7]:
		PropFactory.box(market, Vector3(0.14, 2.6, 0.14), Vector3(sx, 1.3, 0.55), wood, Vector3.ZERO, false)
		PropFactory.box(market, Vector3(0.14, 2.6, 0.14), Vector3(sx, 1.3, -0.55), wood, Vector3.ZERO, false)
	var cloth_a := PropFactory.cloth(Color(0.2, 0.55, 0.25))
	var cloth_b := PropFactory.cloth(Color(0.95, 0.9, 0.7))
	for k in 6:
		PropFactory.box(market, Vector3(0.62, 0.06, 1.6), Vector3(-1.55 + k * 0.62, 2.7, 0), cloth_a if k % 2 == 0 else cloth_b, Vector3(0, 0, 0), false, false)
	for k in 5:
		var crate_col: Color = (CROPS.values()[k % 4] as Dictionary)["col"]
		PropFactory.sphere(market, 0.2, Vector3(-1.4 + k * 0.7, 1.15, 0.1), PropFactory.material(crate_col, 0.6), Vector3.ONE, false)
	var sign_l := Label3D.new()
	sign_l.text = Loc.t("FARMERS' MARKET")
	sign_l.font_size = 60
	sign_l.pixel_size = 0.01
	sign_l.outline_size = 10
	sign_l.modulate = Color(1.0, 0.85, 0.35)
	sign_l.position = Vector3(0, 3.3, 0)
	sign_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	market.add_child(sign_l)
	var it := Interactable.new()
	it.position = Vector3(0, 1.2, -1.2)
	it.reach = 3.2
	it.prompt = "Farmers' Market: sell crops, buy seeds and supplies"
	market.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void: open_market()
	_refresh_map()


func market_mult() -> float:
	var epoch := int(now() / 240.0)
	var f := fposmod(sin(float(epoch) * 12.9898) * 43758.5453, 1.0)
	return 0.85 + 0.3 * f


func price_of(good: String) -> int:
	return maxi(1, int(round(float(SELL[good]) * market_mult())))


func open_market() -> void:
	if shop == null or shop.is_open() or player.locked:
		return
	shop.open_shop("Farmers' Market", _market_rows)


func sell(good: String) -> int:
	var n := flag_n(_store_key(good))
	if n <= 0:
		return 0
	var total := n * price_of(good)
	story.set_flag(_store_key(good), 0)
	coins.add(total)
	Sfx.ui("powerup", -4.0)
	story.add("sales", total)
	return total


func _store_key(good: String) -> String:
	if CROPS.has(good):
		return "crop_" + good
	return {"mango": "fruit_mango", "timber": "timber", "honey": "honey"}.get(good, good)


func sell_all() -> int:
	var t := 0
	for g in SELL.keys():
		t += sell(String(g))
	return t


func _buy(cost: int, grant: Callable) -> bool:
	if not coins.spend(cost):
		hud.banner(Loc.t("Not enough coins."), "")
		return false
	grant.call()
	Sfx.ui("powerup", -8.0)
	return true


func _row(name_: String, desc: String, price: int, grant: Callable, enabled: bool = true, label: String = "Buy") -> Dictionary:
	return {"name": name_, "desc": desc, "price": price, "label": label, "enabled": enabled and coins.balance() >= price,
		"on_press": func() -> void: _buy(price, grant)}


func _market_rows() -> Array:
	var rows: Array = []
	var mult := market_mult()
	var any := false
	rows.append({"section": "Sell your produce (today's prices x%.2f)" % mult})
	var total := 0
	for g in SELL.keys():
		var n := flag_n(_store_key(String(g)))
		if n > 0:
			any = true
			var gg := String(g)
			var sum := n * price_of(gg)
			total += sum
			rows.append({"name": "%d %s" % [n, Loc.t(String(GOODS[gg]))], "desc": "%d coins each today" % price_of(gg), "price": sum, "label": "Sell",
				"enabled": true, "on_press": func() -> void: sell(gg)})
	if any:
		rows.append({"name": "Sell everything", "desc": "All your crops, fruit, timber and honey.", "price": total, "label": "Sell all", "enabled": true,
			"on_press": func() -> void: sell_all()})
	else:
		rows.append({"name": "Nothing to sell yet", "desc": "Grow crops, harvest with the tractor, or pick fruit and timber from the orchard.", "price": 0, "label": "-", "enabled": false, "on_press": func() -> void: pass})
	rows.append({"section": "Seeds (pack of 5)"})
	for k in CROPS.keys():
		var kk := String(k)
		var cost: int = int(CROPS[kk]["seed"]) * 5
		rows.append(_row("%s seeds x5" % Loc.t(String(CROPS[kk]["name"])), "Sells for %d each when ripe. You have %d." % [SELL[kk], flag_n("seed_" + kk)], cost,
			_add_flag.bind("seed_" + kk, 5)))
	rows.append({"section": "Farm supplies"})
	rows.append(_row("Fertilizer x2", "Crops grow twice as fast and give 2 more. You have %d." % flag_n("fertilizer"), 20, _add_flag.bind("fertilizer", 2)))
	rows.append(_row("Scarecrow", "+1 crop per field (up to 3). You have %d." % flag_n("scarecrows"), 60, _grant_scarecrow, flag_n("scarecrows") < 3))
	var owned_s := bool(story.get_flag("up_sprinkler", false))
	rows.append(_row("Sprinklers", "Dry fields water themselves.", 150, _set_flag.bind("up_sprinkler"), not owned_s, "Owned" if owned_s else "Buy"))
	var owned_h := bool(story.get_flag("up_header", false))
	rows.append(_row("Wide harvester header", "The tractor harvests a wider strip.", 120, _set_flag.bind("up_header"), not owned_h, "Owned" if owned_h else "Buy"))
	rows.append(_row("Three more fields", "A new row at the farm (up to 2 rows).", 140, _grant_plots, flag_n("plots_extra") < 2))
	var owned_b := bool(story.get_flag("beehive", false))
	rows.append(_row("Beehive", "Makes honey over time. Collect it at the farm.", 80, _grant_hive, not owned_b, "Owned" if owned_b else "Buy"))
	rows.append({"section": "Saplings for the orchard (they grow in about 3 minutes)"})
	for k in TREES.keys():
		var tk := String(k)
		var desc := "Mangoes every 90 s, then timber." if bool(TREES[tk]["fruit"]) else "Grows into %d timber." % int(TREES[tk]["timber"])
		rows.append(_row(String(TREES[tk]["name"]), desc + " You have %d." % flag_n("sap_" + tk), int(TREES[tk]["cost"]),
			_add_flag.bind("sap_" + tk, 1)))
	rows.append({"section": "Goods and gear"})
	if items != null:
		rows.append(_row("Healing potion", "Heals 70 health.", 45, _give_item.bind("potion", 1)))
		rows.append(_row("Healing herbs x3", "Heal 25 each.", 15, _give_item.bind("herb", 3)))
		rows.append(_row("Leather armour", "Takes 20% less damage.", 140, _give_item.bind("leather", 1), items.count("leather") == 0))
		rows.append(_row("Hunting bow", "Shoot enemies from a distance.", 160, _give_item.bind("bow", 1), items.count("bow") == 0))
		rows.append(_row("Spear", "Longer reach.", 110, _give_item.bind("spear", 1), items.count("spear") == 0))
	rows.append({"section": "Harvest contest"})
	rows.append({"name": "Enter the crop contest", "desc": "Hand in your best 5 crops. Win up to 200 coins; judges favour valuable crops.", "price": 0, "label": "Enter",
		"enabled": _best_crop() != "" and now() >= float(story.get_flag("contest_until", 0.0)),
		"on_press": func() -> void: enter_contest()})
	return rows


func _add_flag(k: String, n: int) -> void:
	story.set_flag(k, flag_n(k) + n)


func _set_flag(k: String) -> void:
	story.set_flag(k, true)


func _give_item(id: String, n: int) -> void:
	items.give(id, n)


func _grant_scarecrow() -> void:
	story.set_flag("scarecrows", flag_n("scarecrows") + 1)
	_scarecrow(flag_n("scarecrows") - 1)


func _grant_plots() -> void:
	story.set_flag("plots_extra", flag_n("plots_extra") + 1)
	_build_plots(6 + 3 * flag_n("plots_extra"))


func _grant_hive() -> void:
	story.set_flag("beehive", true)
	_hive_t = now()
	_refresh_hive()


func _best_crop() -> String:
	var best := ""
	var best_v := 0
	for k in CROPS.keys():
		if flag_n("crop_" + String(k)) >= 5 and int(CROPS[String(k)]["sell"]) > best_v:
			best = String(k)
			best_v = int(CROPS[String(k)]["sell"])
	return best


## Competition: hand in 5 of your best crop; the judges' score is random but rewards valuable crops.
func enter_contest() -> int:
	var k := _best_crop()
	if k == "" or now() < float(story.get_flag("contest_until", 0.0)):
		return 0
	story.set_flag("crop_" + k, flag_n("crop_" + k) - 5)
	story.set_flag("contest_until", now() + 180.0)
	var mine := 40 + int(CROPS[k]["sell"]) * 2 + randi_range(0, 40) + mini(flag_n("scarecrows"), 3) * 4
	var rival := 55 + randi_range(0, 55)
	var prize := 0
	if mine > rival:
		prize = mini(200, 80 + (mine - rival) * 3)
		coins.add(prize)
		hud.banner(Loc.t("You win the crop contest! +%d coins") % prize, "seal_found")
		story.add("contests_won")
	else:
		prize = 15
		coins.add(prize)
		hud.banner(Loc.t("The judges prefer a rival's harvest. Consolation prize: 15 coins."), "")
	return prize
