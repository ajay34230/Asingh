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


static func _sphere(r: float, segs := 28) -> Mesh:
	return RoboPawn._sphere(r, segs)


static func _cyl(top: float, bottom: float, h: float, segs := 24) -> Mesh:
	return RoboPawn._cyl(top, bottom, h, segs)


static func _box(size: Vector3) -> Mesh:
	return _mesh("box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z], func() -> Mesh:
		var b := BoxMesh.new()
		b.size = size
		return b)


static func _torus(major: float, minor: float, rings := 40) -> Mesh:
	return RoboPawn._torus(major, minor, rings)


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
		st.generate_tangents()
		return st.commit())


# --- body -----------------------------------------------------------------------------------

static func build_body(color_name: String) -> Node3D:
	var body := Node3D.new()
	_base(body, color_name)
	_torso(body, color_name)
	_head(body, color_name)
	var anim := KnightAnimator.new()
	anim.name = "KnightAnimator"
	body.add_child(anim)
	return body


static func _base(body: Node3D, color_name: String) -> void:
	var g0 := gunmetal(0)
	var g1 := gunmetal(1)
	var g2 := gunmetal(2)
	## Layered round base: wide chamfered foot, recessed band, raised top disc.
	_mi(body, _mesh("kb_foot", func() -> Mesh:
		return Monuments.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.33, 0), Vector2(0.342, 0.012),
			Vector2(0.342, 0.03), Vector2(0.325, 0.042), Vector2(0, 0.042)]), 64)), g2)
	_mi(body, _cyl(0.3, 0.31, 0.022, 64), g1, Vector3(0, 0.053, 0))
	_mi(body, _torus(0.306, 0.007, 64), stripe(color_name), Vector3(0, 0.053, 0))   # colour band
	_mi(body, _mesh("kb_top", func() -> Mesh:
		return Monuments.lathe(PackedVector2Array([Vector2(0, 0.064), Vector2(0.29, 0.064), Vector2(0.298, 0.07),
			Vector2(0.298, 0.084), Vector2(0.288, 0.092), Vector2(0, 0.092)]), 64)), g0)
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
