## "Knight" token: a chibi armoured robot knight standing on a machined round base.
## Gunmetal armour with blue light (the reference design), and for the other colours
## the same armour with that colour's light, so players stay easy to tell apart:
##   - oversized rounded helmet with pointed cat ears, glowing ear discs, a V forehead
##     plate with a raised emblem, an angled brow over big glowing eyes, a faceplate
##     with a mouth slit and panel lines;
##   - rounded spiked shoulder guards, a round glowing chest core, chevron abdomen
##     plates, segmented forearms and armoured fists;
##   - a kite shield on the left forearm with a glowing hexagon emblem;
##   - a layered round base with a front emblem plate and crackling energy.
## The legs stand on the base, so its pivots differ from the pawns' (LAYOUT).
class_name KnightPawn
extends RefCounted

## Pivot positions (token units) for TransformerToken._build_pivots.
const LAYOUT := {
	"shoulder": Vector3(0.2, 0.535, 0.0), "elbow": Vector3(0.235, 0.405, 0.02), "wrist": Vector3(0.22, 0.295, 0.05),
	"hip": Vector3(0.075, 0.3, 0.0), "knee": Vector3(0.085, 0.2, 0.025), "ankle": Vector3(0.085, 0.112, 0.01),
}
const HEAD_CENTER := Vector3(0, 0.735, 0.0)
const HEAD_SCALE := 0.9
## Which of the four warriors of each colour is built (0 = the master). Set by the game
## before the tokens are made; see variants in GameController.
static var variants := {}

const WARRIORS := {"blue": "Thunder Titan", "green": "Venom Striker", "red": "Inferno Destroyer", "yellow": "Solar Guardian"}
const VARIANT_NAMES := ["Master", "Heavy", "Striker", "Commander"]


## Key part for the merged-mesh cache: colour and warrior type.
static func _ck(color_name: String) -> String:
	return "%s%d" % [color_name, int(variants.get(color_name, 0))]


## "Thunder Titan Striker" and so on: 4 colours x 4 types = 16 warriors.
static func warrior_name(color_name: String, variant: int) -> String:
	return "%s %s" % [WARRIORS.get(color_name, "Warrior"), VARIANT_NAMES[clampi(variant, 0, 3)]]
const HEAD_MOUNT_Y := 0.885   ## where token-design head gear sits on the knight
const GLOW := {"blue": Color("#2f9dff"), "red": Color("#ff5a4a"), "green": Color("#5dff9a"), "yellow": Color("#ffc94a")}

static var _meshes := {}
static var _mats := {}


# --- materials ----------------------------------------------------------------------------

## Gunmetal: dark satin metal with fine wear.
static func gunmetal(shade := 0) -> StandardMaterial3D:
	var key := "gun_%d" % shade
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color("#9aa1ab"), Color("#737a85"), Color("#3e424a")][shade]
		m.metallic = 0.5
		m.roughness = 0.36 + shade * 0.06
		m.metallic_specular = 0.6
		m.roughness_texture = RoboPawn._noise_tex()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(7, 7, 7)
		m.clearcoat_enabled = shade == 0
		m.clearcoat = 0.4
		m.clearcoat_roughness = 0.2
		m.rim_enabled = true
		m.rim = 0.18
		m.rim_tint = 0.8
		_mats[key] = m
	return _mats[key]


## Team-colour anodized stripes on the armour (colour code of each player).
const STRIPE := {"blue": Color("#1f6bff"), "red": Color("#e0182a"), "green": Color("#12b85a"), "yellow": Color("#ffb400")}


static func stripe(color_name: String) -> StandardMaterial3D:
	var key := "stripe_" + color_name
	if not _mats.has(key):
		var c: Color = STRIPE.get(color_name, Color.WHITE)
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.6
		m.roughness = 0.28
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
		m.emission_enabled = true   # a faint self-light so the colour reads on any board
		m.emission = c
		m.emission_energy_multiplier = 0.35
		_mats[key] = m
	return _mats[key]


static func glow(color_name: String, energy := 4.0) -> StandardMaterial3D:
	return RoboPawn.glow(GLOW.get(color_name, Color("#6cc8ff")), energy)


static func gold() -> StandardMaterial3D:
	return RoboPawn.gold()


# --- mesh helpers -------------------------------------------------------------------------

static func _mesh(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


## Tessellation is kept modest: 16 knights are on screen in a 4-player game.
const DETAIL := 0.6


static func _q(segs: int, least := 8) -> int:
	return maxi(least, int(segs * DETAIL))


static func _sphere(r: float, segs := 28) -> Mesh:
	return RoboPawn._sphere(r, _q(segs, 10))


static func _cyl(top: float, bottom: float, h: float, segs := 24) -> Mesh:
	return RoboPawn._cyl(top, bottom, h, _q(segs))


static func _box(size: Vector3) -> Mesh:
	return _mesh("box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z], func() -> Mesh:
		var b := BoxMesh.new()
		b.size = size
		return b)


static func _torus(major: float, minor: float, rings := 40) -> Mesh:
	return RoboPawn._torus(major, minor, _q(rings, 14))


static func _capsule(r: float, h: float) -> Mesh:
	return RoboPawn._capsule(r, h)


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	return RoboPawn._mi(parent, mesh, mat, at, rot, scl)


static func _glow_mi(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := _mi(parent, mesh, mat, at, rot, scl)
	m.set_meta("no_skin", true)
	return m


static func _segment(parent: Node3D, from: Vector3, to: Vector3, r: float, mat: Material) -> MeshInstance3D:
	return RoboPawn._segment(parent, from, to, r, mat)


## A flat outline (XY, facing +Z) extruded to a slab with a bevelled front.
static func _slab(key: String, outline: PackedVector2Array, depth: float, bevel: float) -> Mesh:
	return _mesh("slab_" + key, func() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var inner := Geometry2D.offset_polygon(outline, -bevel)
		var front: PackedVector2Array = inner[0] if inner.size() > 0 else outline
		var tri := Geometry2D.triangulate_polygon(front)
		var zf := depth * 0.5 + bevel * 0.6
		for i in range(0, tri.size(), 3):   # front face (raised centre)
			for k in [0, 2, 1]:
				var p := front[tri[i + k]]
				st.set_normal(Vector3(0, 0, 1))
				st.add_vertex(Vector3(p.x, p.y, zf))
		var tri_b := Geometry2D.triangulate_polygon(outline)
		for i in range(0, tri_b.size(), 3):   # back face
			for k in [0, 1, 2]:
				var p := outline[tri_b[i + k]]
				st.set_normal(Vector3(0, 0, -1))
				st.add_vertex(Vector3(p.x, p.y, -depth * 0.5))
		var n := outline.size()
		## Side walls and the bevel from the outline up to the raised front.
		for i in range(n):
			var a := outline[i]
			var b := outline[(i + 1) % n]
			var e := (b - a).normalized()
			var out := Vector3(e.y, -e.x, 0)
			var quad := [Vector3(a.x, a.y, -depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(a.x, a.y, depth * 0.5)]
			var c: Vector3 = (quad[1] - quad[0]).cross(quad[2] - quad[0])
			var order := [0, 1, 2, 0, 2, 3] if c.dot(out) < 0.0 else [0, 2, 1, 0, 3, 2]
			for k in order:
				st.set_normal(out)
				st.add_vertex(quad[k])
		if front.size() == n:
			for i in range(n):
				var a := outline[i]
				var b := outline[(i + 1) % n]
				var fa := front[i]
				var fb := front[(i + 1) % n]
				var e := (b - a).normalized()
				var nrm := (Vector3(e.y, -e.x, 0) + Vector3(0, 0, 1.2)).normalized()
				var quad := [Vector3(a.x, a.y, depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(fb.x, fb.y, zf), Vector3(fa.x, fa.y, zf)]
				var c: Vector3 = (quad[1] - quad[0]).cross(quad[2] - quad[0])
				var order := [0, 1, 2, 0, 2, 3] if c.dot(nrm) < 0.0 else [0, 2, 1, 0, 3, 2]
				for k in order:
					st.set_normal(nrm)
					st.add_vertex(quad[k])
		return st.commit())


# --- body -----------------------------------------------------------------------------------

static func build_body(color_name: String) -> Node3D:
	var body := Node3D.new()
	_base(body, color_name)
	_torso(body, color_name)
	_head(body, color_name)
	_variant_body(body, color_name)
	_bake_body(body, color_name)
	var anim := KnightAnimator.new()
	anim.name = "KnightAnimator"
	body.add_child(anim)
	return body


## The four types of each colour. 0 = the master; the others change the silhouette so
## they read at a glance: Heavy (back cannons, armoured shoulders), Striker (forearm blades,
## helmet and back fins), Commander (a cape, a gold crown ring and a chest plate).
static func _variant_body(body: Node3D, color_name: String) -> void:
	var v := int(variants.get(color_name, 0))
	if v == 0:
		return
	var head: Node3D = body.get_node("KnightHead")
	var g0 := gunmetal(0)
	var g1 := gunmetal(1)
	var g2 := gunmetal(2)
	var st := stripe(color_name)
	match v:
		1:   # Heavy
			for side in [-1.0, 1.0]:
				var pod := _mi(body, _cyl(0.05, 0.06, 0.26, 16), g1, Vector3(side * 0.1, 0.56, -0.2), Vector3(-0.35, 0, side * 0.12))
				_mi(pod, _torus(0.055, 0.01, 20), st, Vector3(0, 0.1, 0))
				_glow_mi(pod, _cyl(0.035, 0.035, 0.012, 14), glow(color_name, 4.0), Vector3(0, 0.133, 0))
			_mi(body, _box(Vector3(0.3, 0.09, 0.1)), g0, Vector3(0, 0.6, -0.15))
			_mi(body, _box(Vector3(0.2, 0.025, 0.02)), st, Vector3(0, 0.44, 0.17))   # chest bar
		2:   # Striker
			for side in [-1.0, 1.0]:
				var fin := _mi(head, _box(Vector3(0.012, 0.15, 0.1)), g0, Vector3(side * 0.205, 0.04, -0.03), Vector3(0.2, 0, side * -0.35))
				_mi(fin, _box(Vector3(0.014, 0.03, 0.1)), st, Vector3(0, 0.07, 0))
				_mi(body, _box(Vector3(0.012, 0.3, 0.16)), g0, Vector3(side * 0.07, 0.72, -0.23), Vector3(-0.25, 0, side * -0.5))
		3:   # Commander
			var cape := _mi(body, _box(Vector3(0.34, 0.46, 0.014)), g2, Vector3(0, 0.4, -0.2), Vector3(0.1, 0, 0))
			_mi(cape, _box(Vector3(0.34, 0.025, 0.018)), st, Vector3(0, -0.22, 0))
			_mi(body, _torus(0.17, 0.014, 32), gold(), Vector3(0, 0.665, 0), Vector3(0, 0, 0))   # gold collar ring
			var ring := _mi(head, _torus(0.12, 0.012, 28), gold(), Vector3(0, 0.15, 0), Vector3.ZERO)
			ring.set_meta("crown", true)
			_mi(body, _cyl(0.05, 0.05, 0.012, 6), gold(), Vector3(0, 0.44, 0.17), Vector3(PI * 0.5, 0, 0))   # chest plate


static func _variant_limbs(color_name: String, arm_pivots: Dictionary, _leg_pivots: Dictionary) -> void:
	var v := int(variants.get(color_name, 0))
	if v == 0:
		return
	for side_name in ["L", "R"]:
		var side := -1.0 if side_name == "L" else 1.0
		var a: Dictionary = arm_pivots[side_name]
		match v:
			1:   # Heavy: a second layer of shoulder armour and a thicker forearm guard
				_mi(a["shoulder"], _sphere(0.11, 24), gunmetal(1), Vector3(side * 0.025, 0.035, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
				_mi(a["elbow"], _cyl(0.07, 0.07, 0.07, 18), gunmetal(0), Vector3(0, -0.05, 0.02))
			2:   # Striker: a blade along each forearm, past the fist
				var blade := _mi(a["wrist"], _box(Vector3(0.02, 0.012, 0.2)), RoboPawn.chrome(), Vector3(0, -0.03, 0.12))
				_mi(blade, _box(Vector3(0.022, 0.014, 0.04)), stripe(color_name), Vector3(0, 0, -0.08))
			3:   # Commander: gold shoulder tips
				_mi(a["shoulder"], _cyl(0.0, 0.03, 0.09, 10), gold(), Vector3(side * 0.12, 0.07, 0.0), Vector3(0, 0, side * -1.1))


## Merges the knight's hundreds of parts into a few meshes (see MeshMerge): the body, the
## head, its crest, the chest core and each spark. Moving parts keep their own node.
static func _bake_body(body: Node3D, color_name: String) -> void:
	var head: Node3D = body.get_node("KnightHead")
	var crest: Node3D = head.get_node("HeadCrest")
	var sparks: Node3D = body.get_node("Sparks")
	var core: Node3D = body.get_node("ChestCore")
	var bolts: Array = sparks.get_children().filter(func(n: Node) -> bool: return n.get_class() == "Node3D")
	MeshMerge.bake(crest, "kn_crest_" + _ck(color_name), [], false)
	MeshMerge.bake(head, "kn_head_" + _ck(color_name), [crest])
	MeshMerge.bake(core, "kn_core_" + _ck(color_name), [], false)
	MeshMerge.bake(sparks, "kn_cracks_" + _ck(color_name), bolts, false)
	for i in range(bolts.size()):
		MeshMerge.bake(bolts[i], "kn_bolt%d_%s" % [i, _ck(color_name)], [], false)
	MeshMerge.bake(body, "kn_body_" + _ck(color_name), [head, sparks, core])


static func _base(body: Node3D, color_name: String) -> void:
	var g0 := gunmetal(0)
	var g1 := gunmetal(1)
	var g2 := gunmetal(2)
	## Layered round base: wide chamfered foot, recessed band, raised top disc.
	_mi(body, _mesh("kb_foot", func() -> Mesh:
		return Monuments.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.33, 0), Vector2(0.342, 0.012),
			Vector2(0.342, 0.03), Vector2(0.325, 0.042), Vector2(0, 0.042)]), 40)), g2)
	_mi(body, _cyl(0.3, 0.31, 0.022, 64), g1, Vector3(0, 0.053, 0))
	_mi(body, _torus(0.306, 0.007, 64), stripe(color_name), Vector3(0, 0.053, 0))   # colour band
	_mi(body, _mesh("kb_top", func() -> Mesh:
		return Monuments.lathe(PackedVector2Array([Vector2(0, 0.064), Vector2(0.29, 0.064), Vector2(0.298, 0.07),
			Vector2(0.298, 0.084), Vector2(0.288, 0.092), Vector2(0, 0.092)]), 40)), g0)
	_mi(body, _torus(0.24, 0.004, 64), g2, Vector3(0, 0.092, 0))       # engraved rings on top
	_mi(body, _torus(0.15, 0.003, 48), g2, Vector3(0, 0.092, 0))
	## Front emblem plate (a chevron-shaped block) and side medallions.
	var plate := PackedVector2Array([Vector2(-0.11, 0.0), Vector2(0.11, 0.0), Vector2(0.075, -0.034), Vector2(0.02, -0.042), Vector2(0, -0.05), Vector2(-0.02, -0.042), Vector2(-0.075, -0.034)])
	_mi(body, _slab("kb_plate", plate, 0.03, 0.006), g1, Vector3(0, 0.043, 0.33), Vector3(-0.15, 0, 0))
	_mi(body, _cyl(0.014, 0.018, 0.012, 6), g0, Vector3(0, 0.022, 0.352), Vector3(PI * 0.5 - 0.15, 0, 0))
	for side in [-1.0, 1.0]:
		var a: float = PI * 0.5 + side * 1.05
		_mi(body, _cyl(0.02, 0.02, 0.01, 20), gold(), Vector3(cos(a) * 0.344, 0.022, sin(a) * 0.344), Vector3(0, -a, PI * 0.5))
	## Crackling energy around the feet: glowing cracks on the top and a few bolts.
	var sparks := Node3D.new()
	sparks.name = "Sparks"
	body.add_child(sparks)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(14):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.14, 0.27)
		var crack := _glow_mi(sparks, _box(Vector3(0.05, 0.003, 0.004)), glow(color_name, 3.0), Vector3(cos(a) * r, 0.094, sin(a) * r), Vector3(0, rng.randf() * TAU, 0))
		crack.scale.x = rng.randf_range(0.6, 1.4)
	for i in range(5):
		var a := TAU * i / 5.0 + 0.4
		var bolt := Node3D.new()
		bolt.position = Vector3(cos(a) * 0.2, 0.1, sin(a) * 0.2)
		bolt.rotation.y = -a
		sparks.add_child(bolt)
		var y := 0.0
		for k in range(3):   # a zigzag streak rising off the base
			var seg := _glow_mi(bolt, _box(Vector3(0.004, 0.035, 0.004)), glow(color_name, 5.0), Vector3(0.012 * (1 if k % 2 == 0 else -1), y + 0.016, 0), Vector3(0, 0, 0.6 * (1 if k % 2 == 0 else -1)))
			y += 0.03


static func _torso(body: Node3D, color_name: String) -> void:
	var g0 := gunmetal(0)
	var g1 := gunmetal(1)
	var g2 := gunmetal(2)
	## Pelvis and hip armour.
	_mi(body, _capsule(0.07, 0.24), g1, Vector3(0, 0.31, 0), Vector3(0, 0, PI * 0.5))
	_mi(body, _box(Vector3(0.11, 0.06, 0.03)), g0, Vector3(0, 0.3, 0.07), Vector3(0.1, 0, 0))
	_mi(body, _box(Vector3(0.112, 0.012, 0.032)), stripe(color_name), Vector3(0, 0.318, 0.072), Vector3(0.1, 0, 0))   # belt stripe
	## Abdomen: dark core with three chevron plates on the front.
	_mi(body, _cyl(0.12, 0.1, 0.12, 32), g2, Vector3(0, 0.38, 0))
	for k in range(3):
		var y := 0.345 + k * 0.034
		for side in [-1.0, 1.0]:
			var p := _mi(body, _box(Vector3(0.085 - k * 0.006, 0.024, 0.03)), g0 if k != 1 else stripe(color_name), Vector3(side * 0.04, y, 0.095 + k * 0.006), Vector3(0.05, side * 0.35, side * 0.32))
	## Chest: rounded breastplate, pectoral plates and a back pack.
	_mi(body, _sphere(0.165, 32), g1, Vector3(0, 0.48, -0.01), Vector3.ZERO, Vector3(1.12, 0.78, 0.8))
	var pec := PackedVector2Array([Vector2(0.0, 0.05), Vector2(0.1, 0.06), Vector2(0.13, 0.0), Vector2(0.1, -0.05), Vector2(0.03, -0.065), Vector2(0.0, -0.03)])
	for side in [-1.0, 1.0]:
		var plate := _mi(body, _slab("k_pec", pec, 0.03, 0.01), g0, Vector3(side * 0.025, 0.49, 0.1), Vector3(-0.1, side * 0.42, 0), Vector3(side, 1, 1))
		_mi(body, _box(Vector3(0.1, 0.008, 0.008)), stripe(color_name), Vector3(side * 0.085, 0.455, 0.118), Vector3(0, side * 0.4, side * 0.25))   # chest stripe
	_mi(body, _box(Vector3(0.2, 0.15, 0.06)), g2, Vector3(0, 0.48, -0.12))
	## Chest core: a ring and a glowing lens.
	var core := Node3D.new()
	core.name = "ChestCore"
	core.position = Vector3(0, 0.5, 0.118)
	core.rotation.x = PI * 0.5 - 0.15
	body.add_child(core)
	_mi(core, _torus(0.036, 0.009, 32), g0)
	_glow_mi(core, _cyl(0.03, 0.03, 0.012, 28), glow(color_name, 4.0), Vector3(0, 0.002, 0))
	_glow_mi(core, _sphere(0.032, 20), RoboPawn.glass(), Vector3(0, 0.004, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	## Collar.
	_mi(body, _cyl(0.07, 0.085, 0.04, 28), g2, Vector3(0, 0.565, 0))
	_mi(body, _torus(0.082, 0.007, 32), stripe(color_name), Vector3(0, 0.56, 0))   # collar stripe


static func _head(body: Node3D, color_name: String) -> void:
	var g0 := gunmetal(0)
	var g1 := gunmetal(1)
	var g2 := gunmetal(2)
	var head := Node3D.new()
	head.name = "KnightHead"
	head.position = HEAD_CENTER
	head.scale = Vector3.ONE * HEAD_SCALE
	body.add_child(head)
	## Big rounded helmet.
	_mi(head, _sphere(0.2, 40), g0, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.95, 0.98))
	## Panel lines: grooves around the helmet.
	_mi(head, _torus(0.193, 0.004, 56), g2, Vector3(0, 0.02, -0.01), Vector3(0.25, 0, 0))
	_mi(head, _torus(0.19, 0.004, 56), g2, Vector3(0.0, 0.0, -0.02), Vector3(0, 0, PI * 0.5), Vector3(1, 1, 0.98))
	## Centre ridge over the crown, and raised side panels around the ear discs.
	_mi(head, _torus(0.198, 0.012, 56), stripe(color_name), Vector3(0, 0.0, -0.01), Vector3(0, PI * 0.5, PI * 0.5), Vector3(1, 0.96, 1))
	for side in [-1.0, 1.0]:
		var panel := _mi(head, RoboPawn.shell("k_side", PackedVector2Array([Vector2(0.205, 0.09), Vector2(0.212, 0.0), Vector2(0.2, -0.08)]), -0.45, 0.45, 12, 0.018), g1)
		panel.rotation.y = 0.0 if side > 0 else PI
	## Forehead: a raised V plate with an emblem, and a small gem below it.
	for side in [-1.0, 1.0]:
		_mi(head, _box(Vector3(0.05, 0.14, 0.03)), g0, Vector3(side * 0.03, 0.105, 0.172), Vector3(-0.6, 0, side * 0.42))
	_mi(head, _box(Vector3(0.042, 0.009, 0.012)), g2, Vector3(0, 0.14, 0.18), Vector3(-0.65, 0, 0))   # emblem bar
	_mi(head, _box(Vector3(0.01, 0.042, 0.012)), g2, Vector3(0, 0.122, 0.187), Vector3(-0.65, 0, 0))   # emblem stem
	_mi(head, _box(Vector3(0.02, 0.02, 0.018)), g0, Vector3(0, 0.055, 0.205), Vector3(0, 0, PI * 0.25))
	## Eye recess: a dark band across the face.
	_mi(head, RoboPawn.shell("k_visor", PackedVector2Array([Vector2(0.206, 0.024), Vector2(0.212, -0.008), Vector2(0.206, -0.036)]), PI * 0.5 - 0.62, PI * 0.5 + 0.62, 22, 0.02), g2)
	## Big glowing eyes under an angled, frowning brow.
	for side in [-1.0, 1.0]:
		var eye := _glow_mi(head, _sphere(0.046, 28), glow(color_name, 4.5), Vector3(side * 0.068, -0.01, 0.206), Vector3(0, side * 0.3, side * -0.25), Vector3(1.15, 0.78, 0.45))
		eye.name = "Eye"
		_glow_mi(head, _sphere(0.018, 14), RoboPawn.glow(GLOW.get(color_name, Color.WHITE).lightened(0.75), 7.0), Vector3(side * 0.066, -0.01, 0.224), Vector3.ZERO, Vector3(1.2, 1.0, 0.5))
		_glow_mi(head, _sphere(0.048, 24), RoboPawn.glass(), Vector3(side * 0.068, -0.01, 0.211), Vector3(0, side * 0.3, side * -0.25), Vector3(1.15, 0.78, 0.42))
		var brow := _mi(head, _box(Vector3(0.12, 0.034, 0.06)), g0, Vector3(side * 0.07, 0.026, 0.205), Vector3(-0.35, side * 0.35, side * 0.32))
		brow.name = "Brow"
	## Faceplate: lower mask with a mouth slit and cheek plates.
	_mi(head, RoboPawn.shell("k_mask", PackedVector2Array([Vector2(0.21, -0.044), Vector2(0.204, -0.09), Vector2(0.172, -0.14), Vector2(0.12, -0.175)]), PI * 0.5 - 0.95, PI * 0.5 + 0.95, 22, 0.022), g0)
	## Muzzle: a raised snout plate with the mouth slit, framed by grooves.
	var muzzle := PackedVector2Array([Vector2(-0.055, 0.03), Vector2(0.055, 0.03), Vector2(0.065, -0.01), Vector2(0.04, -0.06), Vector2(0.0, -0.075), Vector2(-0.04, -0.06), Vector2(-0.065, -0.01)])
	_mi(head, _sphere(0.08, 28), g0, Vector3(0, -0.095, 0.15), Vector3(0.25, 0, 0), Vector3(1.1, 0.68, 0.75))
	_mi(head, _box(Vector3(0.046, 0.008, 0.012)), g2, Vector3(0, -0.108, 0.207), Vector3(-0.2, 0, 0))   # mouth slit
	_mi(head, _box(Vector3(0.13, 0.006, 0.01)), g2, Vector3(0, -0.05, 0.207), Vector3(-0.1, 0, 0))     # groove under the visor
	for side in [-1.0, 1.0]:
		_mi(head, _box(Vector3(0.012, 0.065, 0.012)), g2, Vector3(side * 0.1, -0.09, 0.178), Vector3(-0.3, side * 0.55, side * 0.2))
		## Ear discs ("headphones") with glowing centres.
		var disc := Node3D.new()
		disc.position = Vector3(side * 0.19, -0.005, -0.005)
		disc.rotation.z = PI * 0.5
		head.add_child(disc)
		_mi(disc, _cyl(0.06, 0.066, 0.04, 32), g1)
		_mi(disc, _torus(0.05, 0.009, 32), stripe(color_name), Vector3(0, side * -0.022, 0))
		_glow_mi(disc, _cyl(0.034, 0.034, 0.012, 28), glow(color_name, 4.0), Vector3(0, side * -0.022, 0))
	## Each colour's own crest.
	var crest := Node3D.new()
	crest.name = "HeadCrest"
	head.add_child(crest)
	match color_name:
		"red":
			_crest_peacock(crest, color_name)
		"green":
			_crest_round_ears(crest, color_name)
		"yellow":
			_crest_sun(crest, color_name)
		_:
			_crest_cat_ears(crest, color_name)


## Blue, the reference: pointed cat ears.
static func _crest_cat_ears(crest: Node3D, color_name: String) -> void:
	for side in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.name = "CatEarL" if side < 0.0 else "CatEarR"
		ear.position = Vector3(side * 0.12, 0.15, -0.01)
		ear.rotation = Vector3(-0.1, 0, side * -0.42)
		crest.add_child(ear)
		_mi(ear, _cyl(0.0, 0.06, 0.15, 4), gunmetal(0), Vector3(0, 0.07, 0), Vector3(0, PI * 0.25, 0), Vector3(1.0, 1.0, 0.45))
		_mi(ear, _cyl(0.0, 0.035, 0.1, 4), stripe(color_name), Vector3(0, 0.055, 0.012), Vector3(0, PI * 0.25, 0), Vector3(1.0, 1.0, 0.3))


## Red, Peacock Knight: a fan of articulated metal feathers with glowing tips, and
## short swept-back horns.
static func _crest_peacock(crest: Node3D, color_name: String) -> void:
	var fan := Node3D.new()
	fan.name = "Fan"
	fan.position = Vector3(0, 0.06, -0.15)
	fan.rotation.x = -0.4
	crest.add_child(fan)
	_mi(fan, _cyl(0.05, 0.055, 0.03, 20), gunmetal(1), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	for i in range(9):
		var f := Node3D.new()
		f.rotation.z = lerpf(-1.2, 1.2, i / 8.0)
		fan.add_child(f)
		var y := 0.04
		for k in range(4):
			var len := 0.07 - k * 0.006
			_mi(f, _box(Vector3(0.03 - k * 0.003, len, 0.01)), gunmetal(0) if k % 2 == 0 else stripe(color_name), Vector3(0, y + len * 0.5, 0))
			_mi(f, _cyl(0.007, 0.007, 0.024, 8), gunmetal(2), Vector3(0, y, 0), Vector3(0, 0, PI * 0.5))
			y += len + 0.004
		_mi(f, _torus(0.036, 0.007, 24), gold(), Vector3(0, y + 0.03, 0), Vector3(PI * 0.5, 0, 0))
		_glow_mi(f, _cyl(0.03, 0.03, 0.008, 20), RoboPawn.glow(Color("#14d8c8"), 2.5), Vector3(0, y + 0.03, 0), Vector3(PI * 0.5, 0, 0))
		_glow_mi(f, _cyl(0.014, 0.014, 0.011, 16), glow(color_name, 4.0), Vector3(0, y + 0.03, 0), Vector3(PI * 0.5, 0, 0))
	for side in [-1.0, 1.0]:
		_mi(crest, _cyl(0.0, 0.035, 0.12, 12), gunmetal(0), Vector3(side * 0.1, 0.15, -0.04), Vector3(-0.7, 0, side * -0.5))


## Green, Guardian Knight: round mechanical ears with sensor dishes.
static func _crest_round_ears(crest: Node3D, color_name: String) -> void:
	for side in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(side * 0.14, 0.15, -0.02)
		ear.rotation = Vector3(PI * 0.5 - 0.15, 0, side * -0.5)
		crest.add_child(ear)
		_mi(ear, _cyl(0.02, 0.02, 0.05, 12), gunmetal(2), Vector3(0, -0.02, 0))
		_mi(ear, _cyl(0.088, 0.094, 0.032, 36), gunmetal(0), Vector3(0, 0, -0.055))
		_mi(ear, _torus(0.09, 0.009, 40), stripe(color_name), Vector3(0, 0.017, -0.055))
		_mi(ear, _cyl(0.066, 0.052, 0.01, 32), gunmetal(1), Vector3(0, 0.019, -0.055))
		_mi(ear, _cyl(0.013, 0.017, 0.03, 12), gunmetal(0), Vector3(0, 0.032, -0.055))
		_glow_mi(ear, _sphere(0.011, 10), glow(color_name, 5.0), Vector3(0, 0.05, -0.055))


## Yellow, Sun Knight: a crown of golden rays around a glowing halo behind the helmet.
static func _crest_sun(crest: Node3D, color_name: String) -> void:
	var halo := Node3D.new()
	halo.name = "Halo"
	halo.position = Vector3(0, 0.08, -0.12)
	crest.add_child(halo)
	_mi(halo, _torus(0.2, 0.012, 56), gold())
	_glow_mi(halo, _torus(0.18, 0.005, 56), glow(color_name, 3.0))
	halo.rotation.x = PI * 0.5 - 0.25
	for i in range(14):
		var a := TAU * i / 14.0
		var ray := _mi(halo, _cyl(0.0, 0.022, 0.09 if i % 2 == 0 else 0.06, 8), gold() if i % 2 == 0 else stripe(color_name), Vector3(cos(a) * 0.24, 0.0, sin(a) * 0.24))
		ray.rotation = Vector3(0, -a, -PI * 0.5)


# --- limbs ------------------------------------------------------------------------------------

static func dress_limbs(color_name: String, arm_pivots: Dictionary, leg_pivots: Dictionary) -> void:
	var g0 := gunmetal(0)
	var g1 := gunmetal(1)
	var g2 := gunmetal(2)
	for side_name in ["L", "R"]:
		var side := -1.0 if side_name == "L" else 1.0
		var a: Dictionary = arm_pivots[side_name]
		var sh: Vector3 = LAYOUT["shoulder"] * Vector3(side, 1, 1)
		var el: Vector3 = LAYOUT["elbow"] * Vector3(side, 1, 1)
		var wr: Vector3 = LAYOUT["wrist"] * Vector3(side, 1, 1)
		## Rounded shoulder guard with a spike pointing out and up, and a smaller one behind.
		_mi(a["shoulder"], _sphere(0.085, 28), g0, Vector3(side * 0.01, 0.01, 0), Vector3.ZERO, Vector3(1.1, 0.85, 1.0))
		_mi(a["shoulder"], _torus(0.074, 0.009, 32), stripe(color_name), Vector3(side * 0.012, -0.02, 0), Vector3(0, 0, side * -0.3))
		_mi(a["shoulder"], _sphere(0.07, 24), g1, Vector3(side * 0.03, 0.045, 0), Vector3(0, 0, side * -0.4), Vector3(1.15, 0.55, 1.0))   # upper layer
		_mi(a["shoulder"], _cyl(0.0, 0.05, 0.2, 16), g0, Vector3(side * 0.07, 0.09, -0.02), Vector3(-0.35, 0, side * -0.7))
		_mi(a["shoulder"], _cyl(0.0, 0.03, 0.12, 12), g1, Vector3(side * 0.04, 0.06, -0.07), Vector3(-0.9, 0, side * -0.5))
		## Upper arm, elbow, then a bulky segmented forearm.
		_segment(a["shoulder"], Vector3.ZERO, el - sh, 0.042, g1)
		_mi(a["elbow"], _sphere(0.046, 18), g2)
		var fore := wr - el
		for k in range(3):
			var t := 0.15 + k * 0.3
			var ring := _mi(a["elbow"], _cyl(0.058 - k * 0.004, 0.062 - k * 0.004, 0.035, 24), g0 if k != 1 else stripe(color_name), fore * t)
			ring.basis = RoboPawn._basis_y(fore)
		## Armoured fist: knuckles, fingers curled, thumb.
		var fist := _mi(a["wrist"], _sphere(0.05, 20), g0, Vector3(0, -0.035, 0.005), Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
		fist.name = "Fist"
		for k in range(4):
			_mi(a["wrist"], _box(Vector3(0.018, 0.022, 0.026)), g1, Vector3((k - 1.5) * 0.02, -0.065, 0.03))
		_mi(a["wrist"], _capsule(0.012, 0.04), g1, Vector3(side * -0.035, -0.035, 0.035), Vector3(0.4, 0, side * 0.5))
		## Legs: hip joint, armoured thigh, knee guard, shin with a front plate, boot.
		var l: Dictionary = leg_pivots[side_name]
		var hp: Vector3 = LAYOUT["hip"] * Vector3(side, 1, 1)
		var kn: Vector3 = LAYOUT["knee"] * Vector3(side, 1, 1)
		var an: Vector3 = LAYOUT["ankle"] * Vector3(side, 1, 1)
		_mi(l["hip"], _sphere(0.05, 16), g2)
		_segment(l["hip"], Vector3.ZERO, kn - hp, 0.055, g0)
		_mi(l["hip"], _box(Vector3(0.02, 0.07, 0.012)), stripe(color_name), (kn - hp) * 0.5 + Vector3(0, 0, 0.052))   # thigh stripe
		_mi(l["knee"], _sphere(0.05, 18), g1, Vector3(0, 0, 0.02), Vector3.ZERO, Vector3(1, 0.9, 0.9))
		_segment(l["knee"], Vector3.ZERO, an - kn, 0.058, g0)
		_mi(l["knee"], _box(Vector3(0.06, 0.06, 0.02)), g1, (an - kn) * 0.5 + Vector3(0, 0, 0.055), Vector3(-0.1, 0, 0))
		## Boot: chunky, with a rounded toe and a sole that sits on the base.
		_mi(l["ankle"], _box(Vector3(0.11, 0.05, 0.13)), g0, Vector3(0, -0.005, 0.02))
		_mi(l["ankle"], _sphere(0.055, 18), g0, Vector3(0, -0.01, 0.075), Vector3.ZERO, Vector3(1.0, 0.55, 0.8))
		_mi(l["ankle"], _box(Vector3(0.12, 0.012, 0.15)), g2, Vector3(0, -0.028, 0.03))
		_mi(l["ankle"], _box(Vector3(0.112, 0.01, 0.1)), stripe(color_name), Vector3(0, 0.02, 0.02))   # boot stripe
	## Each colour's shield (and the Peacock Knight's sword).
	var shield := Node3D.new()
	shield.name = "KnightShield"
	shield.position = (LAYOUT["wrist"] - LAYOUT["elbow"]) * 0.5 + Vector3(0.07, 0.0, 0.04)
	shield.rotation = Vector3(0.05, 0.55, -0.06)
	arm_pivots["R"]["elbow"].add_child(shield)
	match color_name:
		"red":
			_round_shield(shield, color_name, false)
			_sword(arm_pivots["L"]["wrist"], color_name)
		"green":
			_tower_shield(shield, color_name)
		"yellow":
			_round_shield(shield, color_name, true)
		_:
			_kite_shield(shield, color_name)
	_variant_limbs(color_name, arm_pivots, leg_pivots)
	## Merge each limb segment (and the shield and sword) into one mesh.
	MeshMerge.bake(shield, "kn_shield_" + _ck(color_name), [], false)
	var sword: Node3D = arm_pivots["L"]["wrist"].get_node_or_null("KnightSword")
	if sword:
		MeshMerge.bake(sword, "kn_sword_" + _ck(color_name), [], false)
	for side_name in ["L", "R"]:
		var pa: Dictionary = arm_pivots[side_name]
		var pl: Dictionary = leg_pivots[side_name]
		var extra_elbow: Array = [pa["wrist"]]
		if pa["elbow"].has_node("KnightShield"):
			extra_elbow.append(pa["elbow"].get_node("KnightShield"))
		var extra_wrist: Array = []
		if pa["wrist"].has_node("KnightSword"):
			extra_wrist.append(pa["wrist"].get_node("KnightSword"))
		MeshMerge.bake(pa["wrist"], "kn_wrist_%s_%s" % [_ck(color_name), side_name], extra_wrist)
		MeshMerge.bake(pa["elbow"], "kn_elbow_%s_%s" % [_ck(color_name), side_name], extra_elbow)
		MeshMerge.bake(pa["shoulder"], "kn_shoulder_%s_%s" % [_ck(color_name), side_name], [pa["elbow"]])
		MeshMerge.bake(pl["ankle"], "kn_ankle_%s_%s" % [_ck(color_name), side_name])
		MeshMerge.bake(pl["knee"], "kn_knee_%s_%s" % [_ck(color_name), side_name], [pl["ankle"]])
		MeshMerge.bake(pl["hip"], "kn_hip_%s_%s" % [_ck(color_name), side_name], [pl["knee"]])


static func _emblem(shield: Node3D, color_name: String, z: float) -> void:
	_glow_mi(shield, _cyl(0.042, 0.042, 0.008, 6), glow(color_name, 3.5), Vector3(0, 0.0, z), Vector3(PI * 0.5, 0, 0))
	_mi(shield, _cyl(0.033, 0.033, 0.01, 6), gunmetal(2), Vector3(0, 0.0, z + 0.003), Vector3(PI * 0.5, 0, 0))
	_glow_mi(shield, _box(Vector3(0.006, 0.03, 0.004)), glow(color_name, 4.0), Vector3(-0.01, 0, z + 0.01))
	_glow_mi(shield, _box(Vector3(0.006, 0.03, 0.004)), glow(color_name, 4.0), Vector3(0.01, 0, z + 0.01))
	_glow_mi(shield, _box(Vector3(0.026, 0.006, 0.004)), glow(color_name, 4.0), Vector3(0, 0.012, z + 0.01))


## Blue: the reference kite shield with a colour border.
static func _kite_shield(shield: Node3D, color_name: String) -> void:
	var kite := PackedVector2Array([Vector2(-0.1, 0.11), Vector2(0.0, 0.135), Vector2(0.1, 0.11), Vector2(0.095, -0.02), Vector2(0.06, -0.1), Vector2(0.0, -0.16), Vector2(-0.06, -0.1), Vector2(-0.095, -0.02)])
	_mi(shield, _slab("kite", kite, 0.02, 0.014), gunmetal(0))
	var mid := PackedVector2Array([Vector2(-0.085, 0.1), Vector2(0.0, 0.12), Vector2(0.085, 0.1), Vector2(0.081, -0.017), Vector2(0.051, -0.088), Vector2(0.0, -0.142), Vector2(-0.051, -0.088), Vector2(-0.081, -0.017)])
	_mi(shield, _slab("kite_mid", mid, 0.012, 0.004), stripe(color_name), Vector3(0, 0, 0.013))
	var inner := PackedVector2Array([Vector2(-0.075, 0.09), Vector2(0.0, 0.108), Vector2(0.075, 0.09), Vector2(0.07, -0.015), Vector2(0.044, -0.078), Vector2(0.0, -0.125), Vector2(-0.044, -0.078), Vector2(-0.07, -0.015)])
	_mi(shield, _slab("kite_in", inner, 0.012, 0.006), gunmetal(1), Vector3(0, 0, 0.018))
	_emblem(shield, color_name, 0.032)
	_mi(shield, _box(Vector3(0.006, 0.18, 0.006)), gunmetal(2), Vector3(-0.045, 0.0, 0.033), Vector3(0, 0, 0.12))
	_mi(shield, _box(Vector3(0.006, 0.18, 0.006)), gunmetal(2), Vector3(0.045, 0.0, 0.033), Vector3(0, 0, -0.12))


## Red buckler / Yellow sun-disc shield.
static func _round_shield(shield: Node3D, color_name: String, sun: bool) -> void:
	_mi(shield, _cyl(0.12, 0.12, 0.022, 40), gunmetal(0), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	_mi(shield, _torus(0.112, 0.01, 48), stripe(color_name), Vector3(0, 0, 0.012), Vector3(PI * 0.5, 0, 0))
	_mi(shield, _cyl(0.09, 0.098, 0.014, 40), gunmetal(1), Vector3(0, 0, 0.014), Vector3(PI * 0.5, 0, 0))
	if sun:
		for i in range(12):   # sun rays around a glowing boss
			var a := TAU * i / 12.0
			var ray := _mi(shield, _cyl(0.0, 0.012, 0.05, 6), gold(), Vector3(cos(a) * 0.06, sin(a) * 0.06, 0.024))
			ray.rotation.z = a - PI * 0.5
		_glow_mi(shield, _sphere(0.03, 20), glow(color_name, 4.0), Vector3(0, 0, 0.024), Vector3.ZERO, Vector3(1, 1, 0.5))
	else:
		for i in range(8):   # rivets
			var a := TAU * i / 8.0
			_mi(shield, _sphere(0.009, 8), gold(), Vector3(cos(a) * 0.075, sin(a) * 0.075, 0.023))
		_emblem(shield, color_name, 0.024)


## Green: a tall tower shield.
static func _tower_shield(shield: Node3D, color_name: String) -> void:
	var tower := PackedVector2Array([Vector2(-0.085, 0.12), Vector2(0.0, 0.15), Vector2(0.085, 0.12), Vector2(0.085, -0.13), Vector2(0.0, -0.17), Vector2(-0.085, -0.13)])
	_mi(shield, _slab("tower", tower, 0.022, 0.012), gunmetal(0))
	var mid := PackedVector2Array([Vector2(-0.07, 0.108), Vector2(0.0, 0.134), Vector2(0.07, 0.108), Vector2(0.07, -0.118), Vector2(0.0, -0.152), Vector2(-0.07, -0.118)])
	_mi(shield, _slab("tower_mid", mid, 0.012, 0.004), stripe(color_name), Vector3(0, 0, 0.014))
	var inner := PackedVector2Array([Vector2(-0.06, 0.098), Vector2(0.0, 0.12), Vector2(0.06, 0.098), Vector2(0.06, -0.108), Vector2(0.0, -0.138), Vector2(-0.06, -0.108)])
	_mi(shield, _slab("tower_in", inner, 0.012, 0.006), gunmetal(1), Vector3(0, 0, 0.019))
	_emblem(shield, color_name, 0.033)
	for y in [0.08, -0.08]:
		_mi(shield, _box(Vector3(0.13, 0.008, 0.006)), gunmetal(2), Vector3(0, y, 0.034))


## Red: a curved talwar held in the free hand.
static func _sword(wrist: Node3D, color_name: String) -> void:
	var sword := Node3D.new()
	sword.name = "KnightSword"
	sword.position = Vector3(0, -0.04, 0.03)
	sword.rotation = Vector3(PI - 1.1, 0, 0.15)   # held low, pointing forward
	wrist.add_child(sword)
	_mi(sword, _cyl(0.012, 0.012, 0.07, 10), gunmetal(2), Vector3(0, 0, 0))        # grip
	_mi(sword, _box(Vector3(0.02, 0.012, 0.09)), gold(), Vector3(0, 0.04, 0))       # guard
	_mi(sword, _sphere(0.016, 10), gold(), Vector3(0, -0.04, 0))                     # pommel
	for k in range(5):   # a gently curved blade in segments
		var b := _mi(sword, _box(Vector3(0.034 - k * 0.004, 0.06, 0.008)), RoboPawn.chrome(), Vector3(k * k * 0.004, 0.075 + k * 0.055, 0), Vector3(0, 0, -0.08 * k))
	_glow_mi(sword, _box(Vector3(0.004, 0.25, 0.01)), glow(color_name, 2.5), Vector3(0.014, 0.18, 0), Vector3(0, 0, -0.12))


# --- knight editions of the token designs -------------------------------------------------

## design id -> [armour colour, metallic, roughness, stripe colour, glow colour]
## Every design turns the knight into its own edition: armour finish, colour stripes and
## the light of the eyes, core, ear discs, shield emblem and sparks. The design's gear
## (turban, crown, mace, wings...) is added on the helmet by TokenDesigns.
const FINISH := {
	"design_raja": [Color("#e9e1d0"), 0.3, 0.35, Color("#ff9a1f"), Color("#3bff90")],
	"design_tiger": [Color("#d8741e"), 0.45, 0.4, Color("#1a1410"), Color("#ffb020")],
	"design_peacock": [Color("#138080"), 0.7, 0.3, Color("#1a3aa8"), Color("#14d8c8")],
	"design_lotus": [Color("#f2c4d4"), 0.4, 0.3, Color("#ff5a9a"), Color("#ffd0e8")],
	"design_maharaja": [Color("#e6b552"), 0.9, 0.25, Color("#c0102a"), Color("#ffd040")],
	"design_warrior": [Color("#b8c0c8"), 0.85, 0.3, Color("#a0101a"), Color("#ff6a3a")],
	"design_shadow": [Color("#18161e"), 0.35, 0.7, Color("#4a1466"), Color("#ff2040")],
	"design_surya": [Color("#f0c050"), 0.9, 0.22, Color("#ff7a10"), Color("#ffe060")],
	"design_maratha": [Color("#e0802a"), 0.5, 0.35, Color("#f4f0e6"), Color("#ffb040")],
	"design_hampi": [Color("#8a857c"), 0.0, 0.95, Color("#4a7a2a"), Color("#9fd06a")],
	"design_mughal": [Color("#f4ecd8"), 0.25, 0.3, Color("#138a4a"), Color("#ffd060")],
	"design_rani": [Color("#8a1020"), 0.6, 0.3, Color("#e6b552"), Color("#ff6060")],
	"design_chola": [Color("#c47e40"), 0.85, 0.38, Color("#3fbf9f"), Color("#ffb060")],
	"design_snowleopard": [Color("#e8eaee"), 0.4, 0.35, Color("#3a3a40"), Color("#a8e8ff")],
	"design_banyan": [Color("#6a4a2a"), 0.1, 0.85, Color("#4a9a2a"), Color("#9fff6a")],
	"design_lion": [Color("#c08a40"), 0.6, 0.35, Color("#7a4a1a"), Color("#ffcf5a")],
	"design_monsoon": [Color("#5a6a80"), 0.6, 0.3, Color("#3a8aff"), Color("#9fd0ff")],
	"design_chai": [Color("#8a5a30"), 0.4, 0.45, Color("#f4e6c8"), Color("#ffcf8a")],
	"design_bollywood": [Color("#1a1a22"), 0.8, 0.15, Color("#e6b552"), Color("#ff4ab0")],
	"design_cricket": [Color("#1a2a6a"), 0.5, 0.35, Color("#2aa8ff"), Color("#ffffff")],
	"design_naga": [Color("#1f6a3a"), 0.7, 0.3, Color("#e6b552"), Color("#3bff6a")],
	"design_airavata": [Color("#f2efe8"), 0.2, 0.3, Color("#e6b552"), Color("#fff0c0")],
	"design_hanuman": [Color("#c8401a"), 0.6, 0.32, Color("#e6b552"), Color("#ffb020")],
	"design_garuda": [Color("#e6b552"), 0.9, 0.25, Color("#c4102e"), Color("#ffb020")],
	"design_nataraja": [Color("#6a4020"), 0.8, 0.35, Color("#ff7a1a"), Color("#ff7a1a")],
	"design_robo": [Color("#dfe4ea"), 0.95, 0.12, Color("#2ae0ff"), Color("#2ae0ff")],
	"design_ghost": [Color("#bfeaff"), 0.1, 0.2, Color("#7ad8ff"), Color("#9ff0ff")],
	"design_diya": [Color("#b4582a"), 0.2, 0.6, Color("#e6b552"), Color("#ffb030")],
	"design_holi": [Color("#f4f4f4"), 0.2, 0.4, Color("#ff2a8a"), Color("#20c0ff")],
	"design_kite": [Color("#4aa8e8"), 0.5, 0.3, Color("#ffd020"), Color("#ff2a5a")],
	"design_tiranga": [Color("#f4f4f4"), 0.3, 0.3, Color("#ff9933"), Color("#138808")],
	"design_star": [Color("#c01a2a"), 0.6, 0.3, Color("#f4f4f4"), Color("#ffe060")],
}


static func _finish_mat(id: String, shade: int) -> StandardMaterial3D:
	var key := "fin_%s_%d" % [id, shade]
	if not _mats.has(key):
		var f: Array = FINISH[id]
		var base: Color = f[0]
		var m := StandardMaterial3D.new()
		m.albedo_color = [base, base.darkened(0.22), base.darkened(0.58)][shade]
		m.metallic = f[1]
		m.roughness = clampf(float(f[2]) + shade * 0.05, 0.0, 1.0)
		m.roughness_texture = RoboPawn._noise_tex()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(7, 7, 7)
		m.rim_enabled = true
		m.rim = 0.2
		m.rim_tint = 0.7
		if id == "design_ghost":   # spectral: see-through, softly glowing armour
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = [0.42, 0.34, 0.26][shade]
			m.emission_enabled = true
			m.emission = Color("#5ac8ff")
			m.emission_energy_multiplier = 0.7 - shade * 0.15
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		elif id == "design_hampi":   # carved granite
			var n := NoiseTexture2D.new()
			n.noise = FastNoiseLite.new()
			n.noise.frequency = 0.09
			n.color_ramp = Gradient.new()
			n.color_ramp.set_color(0, base.darkened(0.45 + shade * 0.1))
			n.color_ramp.set_color(1, base.lightened(0.1 - shade * 0.1))
			m.albedo_texture = n
			m.albedo_color = Color.WHITE
		_mats[key] = m
	return _mats[key]


static func _finish_stripe(id: String) -> StandardMaterial3D:
	var key := "fin_stripe_" + id
	if not _mats.has(key):
		var c: Color = FINISH[id][3]
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.6
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.3
		if id == "design_ghost":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.6
			m.emission_energy_multiplier = 1.5
		_mats[key] = m
	return _mats[key]


## Dresses (or undresses, for the classic look) a knight in a design's edition.
static func apply_design(token: Node3D, id: String) -> void:
	var team := String(token.get("team"))
	var meshes: Array = []
	for m in token.body_node.find_children("*", "MeshInstance3D", true, false):
		if not String(token.get_path_to(m)).contains("DesignGear"):
			meshes.append(m)
	for m in meshes:   # back to the plain knight first (surface overrides are per instance)
		for i in range(m.mesh.get_surface_count()):
			m.set_surface_override_material(i, null)
		if m.has_meta("kd_orig"):
			m.material_override = m.get_meta("kd_orig")
			m.remove_meta("kd_orig")
	if not FINISH.has(id):
		return
	var team_glow: Color = GLOW.get(team, Color.WHITE)
	var new_glow: Color = FINISH[id][4]
	var shades := [gunmetal(0), gunmetal(1), gunmetal(2)]
	var team_stripe := stripe(team)
	for m in meshes:
		for i in range(m.mesh.get_surface_count()):
			var mat: Material = m.mesh.surface_get_material(i)
			if mat == null:
				continue
			var repl: Material = null
			var k := shades.find(mat)
			if k >= 0:
				repl = _finish_mat(id, k)
			elif mat == team_stripe:
				repl = _finish_stripe(id)
			elif mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled \
					and (mat as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
					and (mat as StandardMaterial3D).emission.is_equal_approx(team_glow):
				repl = RoboPawn.glow(new_glow, float(mat.get_meta("base_energy", 4.0)))
			if repl:
				m.set_surface_override_material(i, repl)
	if id == "design_ghost":
		_ghost_wisps(token)


## Ghost edition: pale wisps drift up around the knight.
static func _ghost_wisps(token: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.name = "DesignGearWisps"
	p.amount = 18
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.15
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.036
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.95, 1.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color("#9ff0ff")
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	p.mesh = mesh
	p.position = Vector3(0, 0.35, 0)
	token.body_node.add_child(p)


## Far level of detail: beyond LOD_DISTANCE the ~20 detailed meshes of a knight are swapped
## for ONE merged copy (~8 surfaces), which is what most tokens look like from the normal
## board camera. Close-ups (fights, the shop) keep the full detail. The crest, sparks and
## chest core stay as they are; limbs are frozen in the rest pose at a distance.
const LOD_DISTANCE := 16.0   # the board camera is ~34 away; fights and close-ups are under 10


static func add_lod(token: Node3D, color_name: String) -> void:
	var body: Node3D = token.body_node
	var keep: Array = []
	for path in ["KnightHead/HeadCrest", "Sparks", "ChestCore"]:
		var n := body.get_node_or_null(path)
		if n:
			keep.append(n)
	var detail: Array[MeshInstance3D] = []
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var inside_keep := false
		for k in keep:
			if k.is_ancestor_of(m):
				inside_keep = true
		if inside_keep:
			continue
		detail.append(m)
	var far := MeshMerge.bake(body, "kn_lod_%s_%d" % [color_name, int(variants.get(color_name, 0))], keep, true, false)
	if far == null:
		return
	far.visibility_range_begin = LOD_DISTANCE
	far.visibility_range_begin_margin = 1.0
	far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for m in detail:
		if m != far:
			m.visibility_range_end = LOD_DISTANCE
			m.visibility_range_end_margin = 1.0
			m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


static func is_knight(token: Node3D) -> bool:
	return token.body_node != null and token.body_node.has_node("KnightAnimator")


## Idle life: the head tilts and looks around, eyes and core pulse, sparks crackle.
class KnightAnimator extends Node3D:
	var _t := randf() * 10.0
	var _head: Node3D
	var _sparks: Node3D
	var _core: Node3D

	func _ready() -> void:
		var body := get_parent()
		_head = body.get_node_or_null("KnightHead")
		_sparks = body.get_node_or_null("Sparks")
		_core = body.get_node_or_null("ChestCore")

	func _process(delta: float) -> void:
		_t += delta
		var token := get_parent().get_parent()
		var plain := token == null or String(token.get_meta("design", "design_classic")) == "design_classic"
		if _head and plain:
			_head.rotation.y = sin(_t * 0.5) * 0.22
			_head.rotation.z = sin(_t * 0.33) * 0.05
		if _core:
			_core.scale = Vector3.ONE * (1.0 + 0.1 * sin(_t * 3.0))
		if _sparks:
			var i := 0
			for c in _sparks.get_children():
				c.visible = fmod(_t * (1.3 + i * 0.17) + i * 0.37, 1.0) < 0.55
				i += 1
