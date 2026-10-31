class_name TownBuilder
extends Node3D
## Suryapur Bazaar: a living market town on levelled ground between the Sun Gate and the temple.
## A paved square with a fountain, a ring of sixteen themed stalls, four streets lined with shops,
## havelis, tower houses, huts, an inn, tea houses, workshops and shrines (a few of them enterable),
## and about fifty people doing real work: hawking, haggling, scrubbing washing, sweeping,
## stirring, kneading, chopping, chatting over tea and strolling. Sounds: crowd, fountain, sizzle,
## fire, street music, and random one-shots (hens, goats, bells, coins, carts, children).

const C := TerrainBuilder.TOWN_C
const PLAZA_R := 16.0
const STALL_R := 12.6
const WALLS := [
	Color(0.95, 0.72, 0.22), Color(0.90, 0.40, 0.42), Color(0.24, 0.66, 0.78), Color(0.96, 0.86, 0.60),
	Color(0.86, 0.42, 0.22), Color(0.96, 0.60, 0.20), Color(0.38, 0.76, 0.58), Color(0.94, 0.52, 0.70),
	Color(0.36, 0.52, 0.88), Color(0.62, 0.78, 0.30),
]
const CLOTHS := [
	Color(0.80, 0.2, 0.2), Color(0.2, 0.45, 0.75), Color(0.9, 0.7, 0.15), Color(0.2, 0.6, 0.35),
	Color(0.85, 0.4, 0.1), Color(0.6, 0.2, 0.6), Color(0.1, 0.55, 0.6), Color(0.9, 0.35, 0.5),
]
## kind, label above the stall, price (0 = look only)
const STALLS := [
	["fruit", "Fresh Fruit", 3], ["spice", "Spices", 0], ["cloth", "Silk & Cotton", 0], ["sweet", "Sweets", 4],
	["pot", "Clay Pots", 0], ["tea", "Chai", 2], ["vegetable", "Vegetables", 3], ["flower", "Flower Garlands", 2],
	["fruit", "Mangoes", 3], ["bread", "Fresh Roti", 2], ["leather", "Hides & Leather", 0], ["cloth", "Turbans", 0],
	["sweet", "Jalebi", 4], ["jewel", "Bangles", 0], ["pot", "Brass & Copper", 0], ["vegetable", "Greens", 3],
]
const SHOP_NAMES := ["Spice House", "Cloth Merchant", "Grain Store", "Tailor", "Jeweller", "Barber", "Oil Press", "Sandal Shop", "Rope & Sacks", "Lamp Maker"]

var terrain: TerrainBuilder
var player: Player
var story: Story
var rng := RandomNumberGenerator.new()
var root: Node3D
var base_y := 0.0
var npcs: Array[Npc] = []
var fp_names: Array[String] = []
var footprints: Array[PackedVector2Array] = []   # for the selftest: no two buildings overlap
var stalls: Array[Dictionary] = []
var inn_pos := Vector3.ZERO     # world position of the Musafir Inn
var inn_yaw := 0.0
var buildings := 0
var enterable: Array[Dictionary] = []
var hb: HouseBuilder
var emitters: Array[AudioStreamPlayer3D] = []
var _wall_mats := {}
var _one_t := 2.0
var _active := false
var wash_spots: Array[Vector3] = []
var lamp_points: Array[Vector3] = []   # world positions of street-lamp glass, used by NightLife


func _init(t: TerrainBuilder, p: Player, s: Story) -> void:
	terrain = t
	player = p
	story = s
	rng.seed = 424242
	name = "BazaarTown"


func build(parent: Node3D) -> void:
	parent.add_child(self)
	base_y = terrain.sample_height(C.x, C.y)
	root = Node3D.new()
	root.name = "Town"
	root.position = Vector3(C.x, base_y, C.y)
	add_child(root)
	_paving()
	_fountain()
	_lamps_and_bunting()
	_stalls()
	_streets()
	_wash_corner()
	_tea_house_square()
	_extras()
	_people()
	_sounds()


# --- helpers ---------------------------------------------------------------------------------

func _wm(i: int) -> StandardMaterial3D:
	if not _wall_mats.has(i):
		var m := PropFactory.plaster().duplicate() as StandardMaterial3D
		m.albedo_color = WALLS[i % WALLS.size()]
		_wall_mats[i] = m
	return _wall_mats[i]


func _mat(c: Color, rough: float = 0.95) -> StandardMaterial3D:
	return PropFactory.material(c, rough)


func _ly(x: float, z: float) -> float:
	## local height offset of the ground at local (x, z)
	return terrain.sample_height(C.x + x, C.y + z) - base_y


func _box(p: Node3D, size: Vector3, pos: Vector3, mat: Material, collide: bool = false, rot: Vector3 = Vector3.ZERO) -> Node3D:
	return PropFactory.box(p, size, pos, mat, rot, collide, false)


func _label(p: Node3D, text: String, pos: Vector3, size: float = 0.02, col: Color = Color(0.1, 0.06, 0.03)) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = size
	l.font_size = 48
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.double_sided = false
	p.add_child(l)


func _poly(pos: Vector2, w: float, d: float, yaw: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c in [Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d)]:
		var v: Vector2 = c * 0.5
		pts.append(pos + Vector2(v.x * cos(yaw) + v.y * sin(yaw), -v.x * sin(yaw) + v.y * cos(yaw)))
	return pts


func _free(pos: Vector2, w: float, d: float, yaw: float) -> bool:
	var pl := _poly(pos, w, d, yaw)
	for f in footprints:
		if not Geometry2D.intersect_polygons(pl, f).is_empty():
			return false
	return true


func _footprint(pos: Vector2, w: float, d: float, yaw: float, tag: String = "") -> void:
	fp_names.append("%s@%d,%d" % [tag, int(pos.x), int(pos.y)])
	var pts := PackedVector2Array()
	for c in [Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d)]:
		var v: Vector2 = c * 0.5
		var cs := cos(yaw)
		var sn := sin(yaw)
		# a Node3D yawed by `yaw` maps local (x, z) to (x cos + z sin, -x sin + z cos)
		pts.append(pos + Vector2(v.x * cs + v.y * sn, -v.x * sn + v.y * cs))
	footprints.append(pts)


# --- ground, square, fountain ----------------------------------------------------------------

func _paving() -> void:
	var pale := PropFactory.sandstone_pale()
	var disc := PropFactory.cylinder(root, PLAZA_R, PLAZA_R, 0.05, Vector3(0, 0.03, 0), pale, Vector3.ZERO, false, 40, 0, false)
	disc.name = "PlazaPaving"
	var inner := PropFactory.cylinder(root, 7.0, 7.0, 0.06, Vector3(0, 0.035, 0), PropFactory.sandstone(), Vector3.ZERO, false, 32, 0, false)
	inner.name = "PlazaInner"
	var lane := _mat(Color(0.62, 0.52, 0.38))
	for k in 4:
		var a := k * PI * 0.5
		var u := Vector2(cos(a), sin(a))
		var mid := u * 30.0
		var rot := Vector3(0, -rad_to_deg(a), 0)
		var s := _box(root, Vector3(30.0, 0.05, 9.0), Vector3(mid.x, 0.03, mid.y), lane, false, rot)
		s.name = "Street_%d" % k


func _fountain() -> void:
	var stone := PropFactory.sandstone()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.45, 0.6, 0.75)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	water.metallic = 0.3
	var basin := Node3D.new()
	basin.name = "Fountain"
	root.add_child(basin)
	PropFactory.cylinder(basin, 3.4, 3.6, 0.7, Vector3(0, 0.38, 0), stone, Vector3.ZERO, true, 28, 0, false)
	var w := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.0
	cm.bottom_radius = 3.0
	cm.height = 0.05
	w.mesh = cm
	w.material_override = water
	w.position = Vector3(0, 0.66, 0)
	basin.add_child(w)
	PropFactory.cylinder(basin, 0.35, 0.5, 1.8, Vector3(0, 1.2, 0), stone, Vector3.ZERO, false, 12, 0, false)
	PropFactory.cylinder(basin, 1.3, 0.5, 0.25, Vector3(0, 2.0, 0), stone, Vector3.ZERO, false, 18, 0, false)
	PropFactory.cylinder(basin, 0.2, 0.3, 0.9, Vector3(0, 2.4, 0), stone, Vector3.ZERO, false, 10, 0, false)
	PropFactory.sphere(basin, 0.28, Vector3(0, 3.0, 0), PropFactory.bronze())
	var sp := CPUParticles3D.new()
	sp.position = Vector3(0, 3.0, 0)
	sp.amount = 36
	sp.lifetime = 1.3
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 28.0
	sp.initial_velocity_min = 2.6
	sp.initial_velocity_max = 3.6
	sp.gravity = Vector3(0, -9.0, 0)
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 0.9
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	sp.mesh = qm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.75, 0.9, 1.0, 0.7)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp.material_override = pm
	basin.add_child(sp)
	var it := Interactable.new()
	it.position = Vector3(0, 1.0, 3.9)
	it.prompt = "Drink from the fountain"
	it.reach = 2.6
	basin.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
		player.heal(15.0)
		Sfx.at("dig_0", player.global_position, -10.0, 1.6)
		player.say("Cool, sweet water. The old fountain still runs.")


func _lamps_and_bunting() -> void:
	var iron := PropFactory.iron()
	var glow := PropFactory.glow_lamp()
	var tops: Array[Vector3] = []
	for k in 8:
		var a := (k + 0.5) * TAU / 8.0
		var p := Vector3(cos(a) * 15.0, 0, sin(a) * 15.0)
		PropFactory.cylinder(root, 0.07, 0.1, 4.2, p + Vector3(0, 2.1, 0), iron, Vector3.ZERO, true, 8, 0, false)
		PropFactory.sphere(root, 0.2, p + Vector3(0, 4.35, 0), glow)
		tops.append(p + Vector3(0, 4.3, 0))
		lamp_points.append(root.to_global(p + Vector3(0, 4.35, 0)))
	var centre := Vector3(0, 3.35, 0)
	for k in tops.size():
		var tp := tops[k]
		for j in 7:
			var f := (j + 1.0) / 8.0
			var q := tp.lerp(centre, f) - Vector3(0, sin(f * PI) * 0.7, 0)
			var flag := _box(root, Vector3(0.28, 0.34, 0.02), q - Vector3(0, 0.18, 0), _mat(CLOTHS[(k + j) % CLOTHS.size()]), false, Vector3(0, -rad_to_deg(atan2(centre.z - tp.z, centre.x - tp.x)), 0))
			flag.name = "Flag"


# --- stalls ----------------------------------------------------------------------------------

func _stalls() -> void:
	for i in STALLS.size():
		var a := (i + 0.5) * TAU / STALLS.size()
		var pos := Vector2(cos(a), sin(a)) * STALL_R
		var yaw := atan2(-cos(a), -sin(a))        # front (+Z) looks toward the fountain
		var spec: Array = STALLS[i]
		var s := Node3D.new()
		s.name = "Stall_%d_%s" % [i, spec[0]]
		s.position = Vector3(pos.x, 0, pos.y)
		s.rotation.y = yaw
		root.add_child(s)
		_build_stall(s, spec[0], spec[1], i)
		_footprint(pos, 3.2, 2.8, yaw)
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var cost: int = spec[2]
		var kind: String = spec[0]
		var it := Interactable.new()
		it.position = Vector3(0, 1.2, 1.35)
		it.reach = 2.4
		it.prompt = ("Buy %s (%d coins)" % [_item(kind), cost]) if cost > 0 else (("Sell meat and hides" if kind == "leather" else "Browse the %s" % spec[1].to_lower()))
		s.add_child(it)
		it.on_interact = func(_by: Node3D, _me: Interactable) -> void: _trade(kind, cost)
		stalls.append({"node": s, "kind": kind, "pos": s.position, "yaw": yaw, "fwd": fwd, "i": i})


func _item(kind: String) -> String:
	return {"fruit": "a mango", "sweet": "hot jalebi", "tea": "a cup of chai", "vegetable": "a fresh cucumber", "flower": "a marigold garland", "bread": "warm roti"}.get(kind, "wares")


func _trade(kind: String, cost: int) -> void:
	if kind == "leather":
		var meat := int(story.get_flag("meat", 0))
		var hides := int(story.get_flag("hides", 0))
		if meat + hides <= 0:
			player.say("The tanner buys meat and hides: 6 coins a portion, 12 a hide. Bring him game from the wild.")
			return
		var pay := meat * 6 + hides * 12
		story.set_flag("meat", 0)
		story.set_flag("hides", 0)
		story.add("coins", pay)
		Sfx.at("coin_clink", player.global_position, -2.0)
		player.say("Sold %d meat and %d hides for %d coins." % [meat, hides, pay])
		return
	if cost <= 0:
		var lines := {
			"spice": "Saffron, pepper, cardamom. The air itself is gold.", "cloth": "Fine weave. The merchant names a price you can't afford yet.",
			"pot": "Cool clay jars; the potters of this valley are known for them.", "jewel": "Glass bangles, bright as sunrise.",
		}
		player.say(lines.get(kind, "A fine stall."))
		Sfx.at("tink", player.global_position, -6.0)
		return
	var coins := int(story.get_flag("coins", 0))
	if coins < cost:
		player.say("You need %d coins for that." % cost)
		Sfx.ui("ui_blip", -8.0)
		return
	story.add("coins", -cost)
	Sfx.at("coin_clink", player.global_position, -2.0)
	var heal: float = {"fruit": 20.0, "sweet": 30.0, "tea": 15.0, "vegetable": 15.0, "bread": 25.0, "flower": 0.0}.get(kind, 10.0)
	player.heal(heal)
	player.say("%s. (%d coins left)" % [("A sweet, juicy mango" if kind == "fruit" else "Delicious"), coins - cost])


func _build_stall(s: Node3D, kind: String, label: String, idx: int) -> void:
	var wood := PropFactory.wood()
	var c1: Color = CLOTHS[idx % CLOTHS.size()]
	var c2: Color = CLOTHS[(idx + 3) % CLOTHS.size()]
	for sx in [-1.4, 1.4]:
		PropFactory.cylinder(s, 0.06, 0.07, 2.7, Vector3(sx, 1.35, 1.1), wood, Vector3.ZERO, false, 8, 0, false)
		PropFactory.cylinder(s, 0.06, 0.07, 3.1, Vector3(sx, 1.55, -1.1), wood, Vector3.ZERO, false, 8, 0, false)
	for k in 4:   # striped canopy
		_box(s, Vector3(0.7, 0.04, 3.2), Vector3(-1.05 + k * 0.7, 2.92, 0.0), _mat(c1 if k % 2 == 0 else c2), false, Vector3(14, 0, 0))
	_box(s, Vector3(3.1, 0.06, 0.45), Vector3(0, 2.64, 1.62), _mat(c1), false, Vector3(0, 0, 0))
	# counter
	_box(s, Vector3(2.9, 0.85, 0.9), Vector3(0, 0.43, 1.0), wood, true)
	_box(s, Vector3(3.0, 0.07, 1.0), Vector3(0, 0.88, 1.0), _mat(Color(0.5, 0.36, 0.2)), false)
	# back shelf
	_box(s, Vector3(2.9, 0.06, 0.5), Vector3(0, 1.1, -1.0), wood, false)
	_label(s, label, Vector3(0, 2.4, 1.64), 0.012, Color(0.98, 0.95, 0.85))
	match kind:
		"fruit", "vegetable":
			var cols: Array = [Color(0.85, 0.2, 0.15), Color(0.95, 0.65, 0.1), Color(0.35, 0.65, 0.2), Color(0.9, 0.85, 0.2)] if kind == "fruit" else [Color(0.3, 0.6, 0.2), Color(0.8, 0.25, 0.15), Color(0.55, 0.3, 0.55), Color(0.85, 0.7, 0.2)]
			for b in 4:
				var bx := -1.05 + b * 0.7
				PropFactory.cylinder(s, 0.3, 0.24, 0.2, Vector3(bx, 1.0, 1.0), _mat(Color(0.65, 0.48, 0.22)), Vector3.ZERO, false, 10, 0, false)
				for j in 5:
					PropFactory.sphere(s, 0.1, Vector3(bx + rng.randf_range(-0.14, 0.14), 1.14 + (j % 2) * 0.06, 1.0 + rng.randf_range(-0.14, 0.14)), _mat(cols[b]))
		"spice":
			for b in 6:
				var bx2 := -1.15 + b * 0.46
				PropFactory.cylinder(s, 0.19, 0.17, 0.12, Vector3(bx2, 0.96, 1.0), _mat(Color(0.5, 0.4, 0.3)), Vector3.ZERO, false, 10, 0, false)
				PropFactory.cylinder(s, 0.0, 0.17, 0.26, Vector3(bx2, 1.12, 1.0), _mat([Color(0.9, 0.55, 0.1), Color(0.75, 0.15, 0.1), Color(0.9, 0.78, 0.15), Color(0.45, 0.3, 0.15), Color(0.3, 0.5, 0.2), Color(0.85, 0.8, 0.7)][b]), Vector3.ZERO, false, 10, 0, false)
		"cloth":
			for b in 8:
				_box(s, Vector3(0.28, 1.3, 0.06), Vector3(-1.2 + b * 0.34, 1.7, -1.15), _mat(CLOTHS[(b + idx) % CLOTHS.size()]), false, Vector3(0, 0, rng.randf_range(-3, 3)))
			for b in 4:
				_box(s, Vector3(0.7, 0.12 + 0.04 * b, 0.5), Vector3(-1.0 + b * 0.7, 0.95 + 0.06 * b, 1.0), _mat(CLOTHS[(b * 2 + idx) % CLOTHS.size()]), false)
		"pot":
			for b in 5:
				var px := -1.1 + b * 0.55
				var sc := 0.85 + 0.2 * (b % 2)
				PropFactory.sphere(s, 0.22, Vector3(px, 1.15, 1.0), PropFactory.clay() if idx % 2 == 0 else PropFactory.bronze(), Vector3(sc, sc * 1.1, sc))
			for b in 3:
				PropFactory.sphere(s, 0.32, Vector3(-1.6 + b * 0.0, 0.32, 1.9 + b * 0.55), PropFactory.clay(), Vector3(1, 1.15, 1))
		"tea":
			PropFactory.cylinder(s, 0.3, 0.38, 0.5, Vector3(-0.7, 1.15, 1.0), PropFactory.iron(), Vector3.ZERO, false, 10, 0, false)
			PropFactory.cylinder(s, 0.16, 0.2, 0.3, Vector3(-0.7, 1.55, 1.0), PropFactory.bronze(), Vector3.ZERO, false, 10, 0, false)
			PropFactory.sphere(s, 0.2, Vector3(0.1, 1.04, 1.0), PropFactory.glow_bronze(), Vector3(1, 0.5, 1))   # glowing brazier
			for b in 5:
				PropFactory.cylinder(s, 0.05, 0.04, 0.09, Vector3(0.6 + b * 0.18, 0.97, 1.0), _mat(Color(0.9, 0.9, 0.85)), Vector3.ZERO, false, 8, 0, false)
			var fl := OmniLight3D.new()
			fl.light_color = Color(1.0, 0.6, 0.3)
			fl.omni_range = 4.5
			fl.light_energy = 0.55
			fl.position = Vector3(0.1, 1.4, 1.3)
			s.add_child(fl)
		"sweet":
			PropFactory.cylinder(s, 0.55, 0.5, 0.14, Vector3(-0.4, 1.0, 1.0), PropFactory.iron(), Vector3.ZERO, false, 16, 0, false)
			for b in 7:
				var aa := b * 0.9
				PropFactory.cylinder(s, 0.07, 0.07, 0.03, Vector3(-0.4 + cos(aa) * 0.3, 1.09, 1.0 + sin(aa) * 0.3), _mat(Color(0.95, 0.55, 0.1)), Vector3.ZERO, false, 8, 0, false)
			for b in 3:
				PropFactory.cylinder(s, 0.3, 0.3, 0.05, Vector3(0.75 + b * 0.0, 1.0 + b * 0.15, 1.0), _mat(Color(0.8, 0.7, 0.4)), Vector3.ZERO, false, 12, 0, false)
				for j in 4:
					PropFactory.sphere(s, 0.08, Vector3(0.75 + (j - 1.5) * 0.12, 1.07 + b * 0.15, 1.0), _mat(Color(0.85, 0.5 + 0.1 * j, 0.2)))
		"flower":
			for b in 7:
				var col: Color = Color(0.98, 0.6, 0.05) if b % 2 == 0 else Color(0.95, 0.3, 0.45)
				for j in 6:
					PropFactory.sphere(s, 0.08, Vector3(-1.2 + b * 0.4, 2.3 - j * 0.28 - (b % 2) * 0.1, -0.9), _mat(col))
			PropFactory.cylinder(s, 0.35, 0.28, 0.25, Vector3(-0.4, 1.0, 1.0), _mat(Color(0.65, 0.48, 0.22)), Vector3.ZERO, false, 10, 0, false)
			for j in 8:
				PropFactory.sphere(s, 0.1, Vector3(-0.4 + rng.randf_range(-0.2, 0.2), 1.15, 1.0 + rng.randf_range(-0.2, 0.2)), _mat(Color(0.98, 0.62, 0.05)))
		"bread":
			for b in 3:
				PropFactory.cylinder(s, 0.3, 0.3, 0.04, Vector3(-0.8 + b * 0.8, 0.95 + 0.0, 1.0), _mat(Color(0.82, 0.62, 0.32)), Vector3.ZERO, false, 14, 0, false)
				PropFactory.cylinder(s, 0.25, 0.25, 0.1, Vector3(-0.8 + b * 0.8, 1.0, 1.0), _mat(Color(0.9, 0.72, 0.4)), Vector3.ZERO, false, 14, 0, false)
			PropFactory.cylinder(s, 0.5, 0.6, 0.6, Vector3(1.2, 0.3, 1.9), PropFactory.mud_brick(), Vector3.ZERO, true, 12, 0, false)   # clay tandoor
		"leather":
			for b in 5:
				_box(s, Vector3(0.5, 1.0, 0.04), Vector3(-1.1 + b * 0.55, 1.7, -1.1), _mat(Color(0.5 + 0.04 * b, 0.33, 0.2)), false, Vector3(0, 0, rng.randf_range(-4, 4)))
			for b in 3:
				_box(s, Vector3(0.7, 0.14, 0.5), Vector3(-0.8 + b * 0.8, 0.98, 1.0), _mat(Color(0.42, 0.28, 0.17)), false)
		"jewel":
			for b in 6:
				PropFactory.cylinder(s, 0.12, 0.12, 0.03, Vector3(-1.0 + b * 0.4, 0.96, 1.0), PropFactory.glow_bronze(), Vector3(80, 0, 0), false, 14, 0, false)
				PropFactory.cylinder(s, 0.1, 0.1, 0.03, Vector3(-1.0 + b * 0.4, 1.0, 1.0), _mat(CLOTHS[b % CLOTHS.size()]), Vector3(80, 0, 0), false, 14, 0, false)
	# sacks and crates beside every stall
	PropsExtra.crate_stack(s, Vector3(2.0, 0.0, -0.4), rng.randf_range(0, 40), rng)
	PropsExtra.basket(s, Vector3(-2.0, 0.0, -0.2))


# --- buildings -------------------------------------------------------------------------------

func _streets() -> void:
	# Four arms. Enterable houses replace shop slots at a few fixed places.
	var enterable_slots := {"0_1_0": [9.0, 7.0, 0], "1_-1_1": [9.0, 7.0, 1], "2_1_1": [10.0, 8.0, 2], "3_-1_2": [8.0, 7.0, 1]}
	var hi := 20
	for arm in 4:
		var a := arm * PI * 0.5
		var u := Vector2(cos(a), sin(a))
		var n := Vector2(-u.y, u.x)
		for side in [-1, 1]:
			var dist := 19.5
			var slot := 0
			while dist < 44.0:
				var key := "%d_%d_%d" % [arm, side, slot]
				var w := rng.randf_range(5.2, 8.6)
				var d := rng.randf_range(5.0, 7.0)
				var kind := _pick_kind(dist, slot)
				match kind:
					"inn":
						w = maxf(w, 10.5)
					"tower":
						w = 5.2
						d = 5.2
					"shrine":
						w = 3.6
						d = 3.6
					"hut":
						w = 4.4
						d = 4.4
				if enterable_slots.has(key):
					var es: Array = enterable_slots[key]
					w = es[0]
					d = es[1]
					kind = "house"
				var along := dist + w * 0.5
				var out := 5.2 + d * 0.5
				var pos := u * along + n * float(side) * out
				var front := -n * float(side)
				var yaw := atan2(front.x, front.y)
				if pos.length() > 49.0:
					break
				if not _free(pos, w + 1.0, d + 1.0, yaw):
					dist += 1.5
					continue
				if kind == "house":
					hb.build_extra(root, hi, C + pos, w, d, rad_to_deg(yaw), enterable_slots[key][2])
					enterable.append(hb.houses[hb.houses.size() - 1])
					hi += 1
					buildings += 1
					_footprint(pos, w + 1.0, d + 1.0, yaw)
				else:
					_building(kind, pos, yaw, w, d)
				dist += w + rng.randf_range(1.0, 2.2)
				slot += 1
	# plaza corners (diagonals): larger landmark buildings facing the square
	var corner := [["haveli", 0.25], ["inn", 0.75], ["haveli", 1.25], ["tower", 1.75]]
	for k in 4:
		var ang: float = (float(corner[k][1]) + 0.0) * PI
		var u2 := Vector2(cos(ang), sin(ang))
		var pos2 := u2 * 33.0
		var front2 := -u2
		if _free(pos2, 11.0, 9.0, atan2(front2.x, front2.y)):
			_building(corner[k][0], pos2, atan2(front2.x, front2.y), 10.0, 8.0)
	# outskirts: mud huts and sheds around the edges
	for k in 14:
		var ang2 := (k + rng.randf_range(0.1, 0.9)) * TAU / 14.0
		if absf(sin(ang2 * 2.0)) < 0.28:
			continue   # keep the street mouths free
		var rr := rng.randf_range(40.0, 47.0)
		var up := Vector2(cos(ang2), sin(ang2))
		var fr := -up
		if _free(up * rr, 5.2, 5.2, atan2(fr.x, fr.y)):
			_building("hut", up * rr, atan2(fr.x, fr.y), 4.4, 4.4)


func _pick_kind(dist: float, slot: int) -> String:
	var r := rng.randf()
	if dist < 28.0:
		return ["shop", "haveli", "shop", "inn", "tea", "shop", "workshop", "tower"][int(r * 8.0)]
	return ["shop", "haveli", "hut", "tower", "workshop", "shrine", "hut", "shop", "tea"][int(r * 9.0)]


func _building(kind: String, pos: Vector2, yaw: float, w: float, d: float) -> void:
	var gy := _ly(pos.x, pos.y)
	if kind == "inn":
		inn_pos = Vector3(C.x + pos.x, base_y + gy, C.y + pos.y)
		inn_yaw = yaw
	var h := Node3D.new()
	h.name = "%s_%d" % [kind.capitalize(), buildings]
	h.position = Vector3(pos.x, gy, pos.y)
	h.rotation.y = yaw
	root.add_child(h)
	var mi := rng.randi() % WALLS.size()
	var wall := _wm(mi)
	var wood := PropFactory.wood()
	var trim := _mat(WALLS[(mi + 4) % WALLS.size()].darkened(0.25))
	var dark := _mat(Color(0.08, 0.06, 0.05))
	var H := 3.4
	match kind:
		"haveli":
			H = 6.6
		"inn":
			H = 6.0
			w = maxf(w, 10.5)
		"tower":
			H = 9.6
			w = 5.2
			d = 5.2
		"hut":
			H = 2.3
		"tea", "workshop":
			H = 3.2
		"shrine":
			H = 3.0
			w = 3.6
			d = 3.6
	_footprint(pos, w + 0.6, d + 0.6, yaw, kind)
	buildings += 1
	# plinth sunk into the slope so nothing floats
	_box(h, Vector3(w + 0.3, 1.6, d + 0.3), Vector3(0, 0.0, 0), _wm((mi + 2) % WALLS.size()))
	if kind == "hut":
		PropFactory.cylinder(h, w * 0.5, w * 0.5, H, Vector3(0, H * 0.5, 0), PropFactory.mud_brick(), Vector3.ZERO, true, 16, 0, false)
		PropFactory.cylinder(h, 0.0, w * 0.5 + 0.8, 2.0, Vector3(0, H + 1.0, 0), _mat(Color(0.72, 0.6, 0.32)), Vector3.ZERO, false, 16, 0, false)
		_box(h, Vector3(0.9, 1.7, 0.1), Vector3(0, 0.85, w * 0.5), dark)
		_box(h, Vector3(1.2, 0.12, 0.14), Vector3(0, 1.75, w * 0.5), wood)
		PropFactory.sphere(h, 0.3, Vector3(w * 0.5 + 0.5, 0.35, 0.8), PropFactory.clay(), Vector3(1, 1.2, 1))
		if rng.randf() < 0.5:
			_clothesline(h, Vector3(-w * 0.5 - 0.4, 0, 1.5), 3.0)
		return
	if kind == "tea" or kind == "workshop":
		# open-fronted shed: back and side walls, posts, canopy
		_box(h, Vector3(w, H, 0.4), Vector3(0, H * 0.5, -d * 0.5 + 0.2), wall, true)
		_box(h, Vector3(0.4, H, d), Vector3(-w * 0.5 + 0.2, H * 0.5, 0), wall, true)
		_box(h, Vector3(0.4, H, d), Vector3(w * 0.5 - 0.2, H * 0.5, 0), wall, true)
		for sx in [-1.0, 1.0]:
			PropFactory.cylinder(h, 0.1, 0.12, H, Vector3(sx * (w * 0.5 - 0.5), H * 0.5, d * 0.5 - 0.3), wood, Vector3.ZERO, true, 8, 0, false)
		_box(h, Vector3(w + 0.8, 0.2, d + 0.8), Vector3(0, H + 0.1, 0), wood)
		_box(h, Vector3(w + 1.0, 0.06, 1.4), Vector3(0, H - 0.2, d * 0.5 + 0.8), _mat(CLOTHS[rng.randi() % CLOTHS.size()]), false, Vector3(12, 0, 0))
		if kind == "tea":
			_label(h, "Chai Ghar", Vector3(0, H - 0.5, d * 0.5 + 0.3), 0.016, Color(0.98, 0.9, 0.7))
			for sx in [-1.8, 1.8]:
				_box(h, Vector3(2.2, 0.4, 0.6), Vector3(sx, 0.5, d * 0.5 - 1.2), wood, true)
			PropFactory.cylinder(h, 0.6, 0.7, 0.8, Vector3(w * 0.5 - 1.3, 0.4, -d * 0.5 + 1.2), PropFactory.mud_brick(), Vector3.ZERO, true, 12, 0, false)
		else:
			PropFactory.cylinder(h, 1.3, 1.6, 1.6, Vector3(-w * 0.5 + 2.0, 0.8, -0.8), PropFactory.mud_brick(), Vector3.ZERO, true, 14, 0, false)   # kiln
			for j in 6:
				PropFactory.sphere(h, 0.3, Vector3(w * 0.5 - 1.6 + (j % 3) * 0.7, 0.3 + (j / 3) * 0.5, 0.8 + (j % 2) * 0.4), PropFactory.clay(), Vector3(1, 1.2, 1))
			_label(h, ["Potter", "Weaver", "Carpenter"][rng.randi() % 3], Vector3(0, H - 0.5, d * 0.5 + 0.3), 0.016, Color(0.98, 0.9, 0.7))
		return
	# enclosed building
	_box(h, Vector3(w, H, d), Vector3(0, H * 0.5, 0), wall, true)
	# door with frame and stone step
	var dx := rng.randf_range(-w * 0.2, w * 0.2)
	_box(h, Vector3(1.3, 2.3, 0.12), Vector3(dx, 1.15, d * 0.5 + 0.02), dark)
	_box(h, Vector3(1.7, 0.2, 0.2), Vector3(dx, 2.4, d * 0.5 + 0.06), wood)
	for sx in [-0.75, 0.75]:
		_box(h, Vector3(0.18, 2.4, 0.2), Vector3(dx + sx, 1.2, d * 0.5 + 0.06), wood)
	_box(h, Vector3(2.0, 0.18, 0.6), Vector3(dx, 0.1, d * 0.5 + 0.4), PropFactory.sandstone())
	# painted decoration: diamond border at the base and under the roof, mandala over the door
	var sty := rng.randi() % 3
	Murals.band(h, -w * 0.5 + 0.2, w * 0.5 - 0.2, 0.55, d * 0.5 + 0.035, 0.3, sty, dx, 2.2)
	Murals.band(h, -w * 0.5 + 0.2, w * 0.5 - 0.2, H - 0.3, d * 0.5 + 0.035, 0.28, (sty + 1) % 3)
	if H < 4.0 and kind != "shop" and kind != "inn":
		Murals.panel(h, dx, 3.0, d * 0.5 + 0.035, 0.7, sty)
	# windows with shutters on every storey
	var floors := 1 if H < 4.0 else (2 if H < 8.0 else 3)
	for fl in floors:
		var wy := 1.9 + fl * 3.0
		if fl == 0 and floors == 1:
			wy = 1.8
		var nwin := maxi(1, int(w / 2.6))
		for k in nwin:
			var wx := -w * 0.5 + (k + 0.5) * w / float(nwin)
			if fl == 0 and absf(wx - dx) < 1.4:
				continue
			_box(h, Vector3(0.8, 1.0, 0.1), Vector3(wx, wy, d * 0.5 + 0.02), dark)
			_box(h, Vector3(0.42, 1.0, 0.07), Vector3(wx - 0.62, wy, d * 0.5 + 0.08), trim)
			_box(h, Vector3(0.42, 1.0, 0.07), Vector3(wx + 0.62, wy, d * 0.5 + 0.08), trim)
			_box(h, Vector3(1.1, 0.1, 0.25), Vector3(wx, wy - 0.55, d * 0.5 + 0.1), trim)
		if fl < floors - 1:
			_box(h, Vector3(w + 0.1, 0.2, d + 0.1), Vector3(0, 3.0 + fl * 3.0 - 0.1, 0), trim, false)
	# roof slab, parapet and details per kind
	_box(h, Vector3(w + 0.5, 0.3, d + 0.5), Vector3(0, H + 0.15, 0), trim)
	for e in 4:
		var horiz := e < 2
		var sz := Vector3(w + 0.5, 0.45, 0.2) if horiz else Vector3(0.2, 0.45, d + 0.5)
		var ps := Vector3(0, H + 0.5, (d * 0.5 + 0.15) * (1 if e % 2 == 0 else -1)) if horiz else Vector3((w * 0.5 + 0.15) * (1 if e % 2 == 0 else -1), H + 0.5, 0)
		_box(h, sz, ps, wall, false)
	match kind:
		"shop":
			_box(h, Vector3(w - 0.6, 0.06, 1.6), Vector3(0, 2.7, d * 0.5 + 0.9), _mat(CLOTHS[rng.randi() % CLOTHS.size()]), false, Vector3(14, 0, 0))
			for sx in [-1.0, 1.0]:
				PropFactory.cylinder(h, 0.05, 0.06, 2.6, Vector3(sx * (w * 0.5 - 0.5), 1.3, d * 0.5 + 1.6), wood, Vector3.ZERO, false, 8, 0, false)
			_box(h, Vector3(w * 0.5, 0.9, 0.7), Vector3(-w * 0.2, 0.45, d * 0.5 + 1.1), wood, true)
			_label(h, SHOP_NAMES[rng.randi() % SHOP_NAMES.size()], Vector3(0, H - 0.7, d * 0.5 + 0.08), 0.016, Color(0.98, 0.93, 0.8))
			PropsExtra.crate_stack(h, Vector3(w * 0.5 - 1.0, 0.0, d * 0.5 + 1.0), rng.randf_range(0, 40), rng)
		"haveli":
			# jharokha balcony over the street, small chhatri with a dome on the roof
			_box(h, Vector3(2.6, 0.18, 1.1), Vector3(-w * 0.2, 3.2, d * 0.5 + 0.6), trim, false)
			for sx in [-1.2, 0.0, 1.2]:
				_box(h, Vector3(0.1, 1.0, 0.1), Vector3(-w * 0.2 + sx, 3.75, d * 0.5 + 1.05), wood, false)
			_box(h, Vector3(2.8, 0.14, 1.3), Vector3(-w * 0.2, 4.35, d * 0.5 + 0.6), trim, false)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					PropFactory.cylinder(h, 0.07, 0.09, 1.7, Vector3(sx * 1.4, H + 1.3, sz * 1.4), PropFactory.sandstone_pale(), Vector3.ZERO, false, 8, 0, false)
			PropFactory.sphere(h, 1.5, Vector3(0, H + 2.15, 0), _mat(Color(0.9, 0.86, 0.78)), Vector3(1, 0.7, 1))
			_box(h, Vector3(3.2, 0.14, 3.2), Vector3(0, H + 0.55, 0), PropFactory.sandstone_pale(), false)
		"inn":
			_label(h, "Musafir Inn", Vector3(0, H - 1.0, d * 0.5 + 0.1), 0.02, Color(0.98, 0.93, 0.8))
			for sx in [-1.0, 1.0]:
				PropFactory.sphere(h, 0.22, Vector3(sx * 1.6 + dx, 2.9, d * 0.5 + 0.4), PropFactory.glow_lamp())
			_box(h, Vector3(w * 0.6, 0.08, 1.4), Vector3(0, 3.1, d * 0.5 + 0.8), _mat(CLOTHS[rng.randi() % CLOTHS.size()]), false, Vector3(10, 0, 0))
			_clothesline(h, Vector3(-w * 0.5 - 0.3, 3.5, 0.0), d)
		"tower":
			_box(h, Vector3(1.2, 1.1, 1.2), Vector3(0, H + 0.85, 0), wall, false)
			PropFactory.cylinder(h, 0.0, 0.9, 1.2, Vector3(0, H + 2.0, 0), _mat(Color(0.65, 0.3, 0.2)), Vector3.ZERO, false, 8, 0, false)
			PropFactory.cylinder(h, 0.02, 0.02, 1.4, Vector3(0, H + 3.2, 0), wood, Vector3.ZERO, false, 6, 0, false)
			_box(h, Vector3(0.7, 0.4, 0.02), Vector3(0.38, H + 3.6, 0), _mat(CLOTHS[rng.randi() % CLOTHS.size()]), false)
		"shrine":
			PropFactory.sphere(h, 1.5, Vector3(0, H + 0.6, 0), _mat(Color(0.93, 0.88, 0.8)), Vector3(1, 0.85, 1))
			PropFactory.cylinder(h, 0.0, 0.12, 0.7, Vector3(0, H + 2.2, 0), PropFactory.bronze(), Vector3.ZERO, false, 8, 0, false)
			for j in 5:
				PropFactory.sphere(h, 0.07, Vector3(-0.8 + j * 0.4, 0.9, d * 0.5 + 0.35), _mat(Color(0.98, 0.6, 0.05)))
	if rng.randf() < 0.45 and kind != "shrine":
		_clothesline(h, Vector3(w * 0.5 + 0.3, 2.8, 0.0), d)
	if rng.randf() < 0.5:
		PropFactory.sphere(h, 0.4, Vector3(w * 0.5 - 0.9, H + 0.95, 0.5), PropFactory.clay(), Vector3(1, 1.2, 1))


func _clothesline(h: Node3D, at: Vector3, length: float) -> void:
	var wood := PropFactory.wood()
	for sz in [-1.0, 1.0]:
		PropFactory.cylinder(h, 0.04, 0.05, 2.3, at + Vector3(0, 1.15 - at.y * 0.0, sz * length * 0.5), wood, Vector3.ZERO, false, 6, 0, false)
	_box(h, Vector3(0.03, 0.03, length), at + Vector3(0, 2.2, 0), wood, false)
	for j in 4:
		_box(h, Vector3(0.04, 0.8, 0.5), at + Vector3(0, 1.75, -length * 0.35 + j * length * 0.23), _mat(CLOTHS[(j + int(at.x * 3.0)) % CLOTHS.size()]), false, Vector3(rng.randf_range(-4, 4), 0, 0))


# --- corners and extras ----------------------------------------------------------------------

func _wash_corner() -> void:
	# stone trough with water, where the washing is scrubbed
	var pos := Vector3(-6.4, 0.0, 2.6)
	var stone := PropFactory.sandstone()
	var tr := Node3D.new()
	tr.name = "WashTrough"
	tr.position = pos
	tr.rotation.y = deg_to_rad(20.0)
	root.add_child(tr)
	_box(tr, Vector3(4.0, 0.7, 1.2), Vector3(0, 0.35, 0), stone, true)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.25, 0.5, 0.65, 0.8)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(tr, Vector3(3.6, 0.04, 0.8), Vector3(0, 0.68, 0), wm, false)
	for j in 3:
		_box(tr, Vector3(0.6, 0.05, 0.5), Vector3(-1.2 + j * 1.2, 0.73, 0), _mat(CLOTHS[j * 2]), false)
	PropsExtra.bucket(tr, Vector3(2.4, 0, 0.4))
	# drying lines
	_clothesline(tr, Vector3(0, 0, -2.2), 5.0)
	wash_spots = [pos + Vector3(-1.2, 0, 1.2), pos + Vector3(0.2, 0, 1.4), pos + Vector3(1.4, 0, 1.2)]
	_footprint(Vector2(pos.x, pos.z), 4.4, 4.6, deg_to_rad(20.0))


func _tea_house_square() -> void:
	# a shaded sitting area with low benches under a cloth canopy where men talk over chai
	var pos := Vector3(5.0, 0.0, -6.0)
	var g := Node3D.new()
	g.name = "TeaCorner"
	g.position = pos
	root.add_child(g)
	var wood := PropFactory.wood()
	for sx in [-2.2, 2.2]:
		for sz in [-1.6, 1.6]:
			PropFactory.cylinder(g, 0.07, 0.09, 2.7, Vector3(sx, 1.35, sz), wood, Vector3.ZERO, false, 8, 0, false)
	for k in 5:
		_box(g, Vector3(1.0, 0.04, 3.6), Vector3(-2.0 + k * 1.0, 2.75, 0), _mat(CLOTHS[(k * 3) % CLOTHS.size()]), false, Vector3(0, 0, 4))
	for sz in [-1.2, 1.2]:
		_box(g, Vector3(3.6, 0.35, 0.7), Vector3(0, 0.26, sz), wood, true)
	_box(g, Vector3(1.2, 0.1, 1.2), Vector3(0, 0.5, 0), _mat(Color(0.6, 0.45, 0.25)), false)
	PropFactory.cylinder(g, 0.18, 0.2, 0.35, Vector3(0.0, 0.7, 0.0), PropFactory.bronze(), Vector3.ZERO, false, 10, 0, false)
	_footprint(Vector2(pos.x, pos.z), 5.0, 4.0, 0.0)


func _extras() -> void:
	# well-stocked street clutter: carts, hay, barrels, a bullock cart parked at the east mouth
	var wood := PropFactory.wood()
	for k in 4:
		var a := k * PI * 0.5 + 0.18
		var p := Vector3(cos(a) * 21.0, 0, sin(a) * 21.0)
		PropsExtra.bucket(root, p)
		PropsExtra.basket(root, p + Vector3(1.0, 0, 0.7))
	# parked hand cart
	var cart := Node3D.new()
	cart.position = Vector3(26.0, 0, -3.6)
	cart.rotation.y = deg_to_rad(8)
	root.add_child(cart)
	_box(cart, Vector3(2.6, 0.2, 1.4), Vector3(0, 0.8, 0), wood, true)
	for sz in [-0.8, 0.8]:
		PropFactory.cylinder(cart, 0.5, 0.5, 0.1, Vector3(0, 0.5, sz), wood, Vector3(90, 0, 0), false, 14, 0, false)
	for j in 5:
		PropFactory.sphere(cart, 0.2, Vector3(-0.8 + j * 0.4, 1.1, 0), _mat(Color(0.9, 0.5 + 0.1 * (j % 2), 0.1)))
	_box(cart, Vector3(2.0, 0.08, 0.08), Vector3(-2.3, 0.8, 0), wood, false)
	_footprint(Vector2(26.0, -3.6), 3.0, 1.8, deg_to_rad(8))
	# gate arch over the main western street mouth: the way to the village and temple
	for sz in [-1.0, 1.0]:
		PropFactory.cylinder(root, 0.4, 0.5, 5.0, Vector3(-46.0, 2.5, sz * 5.0), PropFactory.sandstone(), Vector3.ZERO, true, 10, 0, false)
	_box(root, Vector3(1.0, 0.7, 11.5), Vector3(-46.0, 5.2, 0), PropFactory.sandstone(), false)
	_label(root, "SURYAPUR BAZAAR", Vector3(-45.4, 5.3, 0), 0.03, Color(0.95, 0.85, 0.6))
	(root.get_child(root.get_child_count() - 1) as Label3D).rotation.y = -PI * 0.5
	for sz in [-1.0, 1.0]:
		PropFactory.sphere(root, 0.35, Vector3(-46.0, 5.8, sz * 5.0), PropFactory.glow_lamp())


# --- people ------------------------------------------------------------------------------------

func _preset(key: String, tool: String = "", tint_i: int = -1) -> Dictionary:
	var p: Dictionary = (NpcBuilder.PRESETS[key] as Dictionary).duplicate()
	if tool != "":
		p["tool"] = tool
	if tint_i >= 0:
		var c: Color = CLOTHS[tint_i % CLOTHS.size()]
		p["tint"] = c
	return p


func _npc(key: String, tool: String, mode: String, label: String, local: Vector3, yaw: float, tint_i: int = -1, stall: String = "general") -> Npc:
	var n := Npc.new().setup(_preset(key, tool, tint_i), mode, label)
	n.player = player
	n.home_yaw = yaw
	n.stall_kind = stall
	add_child(n)
	var wp := Vector3(C.x + local.x, 0, C.y + local.z)
	wp.y = terrain.sample_height(wp.x, wp.z)
	n.global_position = wp
	n.rotation.y = yaw
	npcs.append(n)
	return n


func _people() -> void:
	var men := ["villager_man", "farmer", "villager2", "shepherd", "worker2", "merchant", "trader", "scholar"]
	var women := ["weaver", "lady_green", "lady_medieval", "worker_woman", "cook", "dancer"]
	# hawkers behind the stalls; cooks work, the rest cry their wares
	for st in stalls:
		var i: int = st["i"]
		var kind: String = st["kind"]
		var fwd: Vector3 = st["fwd"]
		var sp: Vector3 = st["pos"]
		var behind := sp - fwd * 0.9
		var yaw: float = st["yaw"]
		var mode := "hawk"
		var tool := ""
		match kind:
			"sweet", "tea":
				mode = "stir"
				tool = "ladle"
			"vegetable":
				mode = "chop"
				tool = "knife"
			"bread":
				mode = "knead"
		var key: String = (women[i % women.size()] if kind in ["flower", "bread", "sweet", "cloth"] else men[i % men.size()])
		# NPC front faces -Z, the stall front faces +Z toward the fountain: turn around to face customers
		var n := _npc(key, tool, mode, "Hawker%d" % i, Vector3(behind.x, 0, behind.z), yaw + PI, i, kind)
		n.role = "trader"
		# a haggling customer in front of every second stall
		if i % 2 == 0:
			var front := sp + fwd * 2.2
			var ck: String = (women[(i + 1) % women.size()] if i % 4 == 0 else men[(i + 3) % men.size()])
			_npc(ck, "", "haggle", "Customer%d" % i, Vector3(front.x, 0, front.z), yaw, i + 2)
	# women scrubbing clothes at the trough
	var tr := Vector3(-6.4, 0.0, 2.6)
	for j in wash_spots.size():
		var ws := wash_spots[j]
		var face := atan2(-(tr.x - ws.x), -(tr.z - ws.z))
		_npc(women[(j + 2) % women.size()], "cloth", "scrub", "Washer%d" % j, ws, face, j + 1)
	# a boy scrubbing the paving by the fountain, a woman scrubbing a doorstep, sweepers on the streets
	_npc("child_b", "cloth", "scrub", "ScrubBoy", Vector3(4.6, 0, 4.2), deg_to_rad(210), 4)
	_npc("worker_woman", "cloth", "scrub", "Doorstep", Vector3(24.5, 0, 3.4), deg_to_rad(-90), 2)
	_npc("worker2", "broom", "sweep", "SweeperA", Vector3(-24.0, 0, 2.5), deg_to_rad(-90), 0)
	_npc("worker2", "broom", "sweep", "SweeperB", Vector3(2.5, 0, 26.0), deg_to_rad(180), 5)
	_npc("lady_medieval", "broom", "sweep", "SweeperC", Vector3(7.0, 0, -26.0), deg_to_rad(0), 6)
	# tea corner: men sitting and talking, an old man listening, a boy serving
	var tc := Vector3(5.0, 0.0, -6.0)
	_npc("villager_man", "", "sit_talk", "TeaTalker1", tc + Vector3(-1.2, 0, -1.2), deg_to_rad(0), 1)
	_npc("farmer", "", "sit_talk", "TeaTalker2", tc + Vector3(1.0, 0, -1.2), deg_to_rad(10), 3)
	_npc("shepherd", "", "sit", "TeaElder", tc + Vector3(-1.0, 0, 1.2), deg_to_rad(180), 7)
	_npc("merchant", "", "sit_talk", "TeaMerchant", tc + Vector3(1.3, 0, 1.2), deg_to_rad(190), 5)
	var musician := _npc("lady_medieval", "", "sit", "StreetMusician", Vector3(-3.2, 0, -6.0), deg_to_rad(40), 2)
	musician.role = "traveller"
	# strollers: walk loops around the square and along the streets
	var strollers := ["villager_man", "lady_green", "farmer", "dancer", "girl_casual", "scholar", "huntress", "weaver", "villager2", "lady_medieval"]
	for k in strollers.size():
		var arm := k % 4
		var aw := arm * PI * 0.5
		var au := Vector2(cos(aw), sin(aw))
		var an := Vector2(-au.y, au.x)
		var side := 2.2 if k % 2 == 0 else -2.2
		var path: Array[Vector3] = []
		# square-side waypoint, then out along the street lane and back
		for pp in [au * 8.0 + an * side, au * 21.0 + an * side, au * 32.0 + an * side, au * 40.0 + an * side, au * 32.0 + an * side, au * 21.0 + an * side]:
			var wp := Vector3(C.x + pp.x, 0, C.y + pp.y)
			wp.y = terrain.sample_height(wp.x, wp.z)
			path.append(wp)
		var sn := _npc(strollers[k], "", "idle", "Shopper%d" % k, Vector3(path[0].x - C.x, 0, path[0].z - C.y), 0.0, k)
		sn.routine = {"type": "walk", "points": path, "home": path[0]}
	# children playing on the square
	for k in 4:
		var ck := "child_a" if k % 2 == 0 else "child_b"
		var cn := _npc(ck, "", "idle", "TownChild%d" % k, Vector3(3.0 + k, 0, -5.0 + k), 0.0, k + 1)
		var cc := Vector3(C.x + 5.0, terrain.sample_height(C.x + 5.0, C.y + 5.0), C.y + 5.0)
		cn.routine = {"type": "play", "centre": cc, "radius": 5.5, "home": cn.global_position}
	# guards at the gate arch
	_npc("guard", "", "idle", "TownGuardA", Vector3(-44.0, 0, -3.6), deg_to_rad(90), -1)
	_npc("guard", "", "idle", "TownGuardB", Vector3(-44.0, 0, 3.6), deg_to_rad(90), -1)


# --- sound ------------------------------------------------------------------------------------

func _sounds() -> void:
	var c := Vector3(C.x, base_y, C.y)
	emitters.append(Sfx.emitter(self, "market_crowd_loop", c + Vector3(0, 1.8, 0), -4.0, 62.0, 16.0))
	emitters.append(Sfx.emitter(self, "water_splash_loop", c + Vector3(0, 1.0, 0), -1.0, 28.0, 4.0))
	for k in 4:
		var a := k * PI * 0.5
		emitters.append(Sfx.emitter(self, "street_murmur_loop", c + Vector3(cos(a) * 30.0, 1.8, sin(a) * 30.0), -9.0, 34.0, 10.0))
	for st in stalls:
		var kind: String = st["kind"]
		if kind == "sweet":
			emitters.append(Sfx.emitter(self, "sizzle_loop", (st["pos"] as Vector3) + c + Vector3(0, 1.1, 0), -7.0, 16.0, 3.0))
		elif kind == "tea":
			emitters.append(Sfx.emitter(self, "fire_crackle_loop", (st["pos"] as Vector3) + c + Vector3(0, 1.0, 0), -9.0, 14.0, 3.0))
	emitters.append(Sfx.emitter(self, "music_bazaar", c + Vector3(-3.2, 1.2, -6.0), -8.0, 42.0, 9.0))
	for e in emitters:
		e.stream_paused = true


func _process(delta: float) -> void:
	if player == null:
		return
	var d := Vector2(player.global_position.x - C.x, player.global_position.z - C.y).length()
	var near := d < TerrainBuilder.TOWN_R + 70.0
	if near != _active:
		_active = near
		for e in emitters:
			e.stream_paused = not near
			if near and not e.playing:
				e.play()
	if not near:
		return
	_one_t -= delta
	if _one_t <= 0.0:
		_one_t = rng.randf_range(1.2, 3.8)
		var pick := ["hen_cluck", "goat_bleat", "child_laugh", "cart_creak", "bicycle_bell", "coin_clink", "tink", "cloth_flap", "bird_%d" % rng.randi_range(0, 4), "coin_clink", "temple_bell"]
		var snd: String = pick[rng.randi() % pick.size()]
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, TerrainBuilder.TOWN_R - 8.0)
		var p := Vector3(C.x + cos(a) * r, base_y + 1.2, C.y + sin(a) * r)
		var vol := -5.0 if snd != "temple_bell" else -14.0
		Sfx.at(snd, p, vol, rng.randf_range(0.9, 1.1))
