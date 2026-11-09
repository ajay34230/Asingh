## The player token, built in code: a lathe-turned royal pawn in metallic team paint
## with a clear-coat shine, polished gold trims, a jewelled chest medallion and gem eyes,
## plus smooth jointed arms and legs (gold gloves and boots) on the token's pivots.
##
## Replaces the supplied token models, whose wire-cage body, blotchy vertex-coloured
## limbs and black-rendering gold looked rough up close (and cost ~140k vertices each;
## this one is about 12k). Meshes are shared by every token; materials per colour.
class_name RoyalPawn
extends RefCounted

const GOLD := Color("#f2c662")
const HEAD_CENTER := Vector3(0, 0.79, 0)
const HEAD_RADIUS := 0.165
const HEAD_SCALE := Vector3(1.12, 0.95, 1.05)

static var _meshes := {}
static var _mats := {}


# --- materials ----------------------------------------------------------------------------

## Car-paint style metal: team colour, metallic flake, glossy clear coat on top.
static func paint(color_name: String) -> StandardMaterial3D:
	var key := "paint_" + color_name
	if not _mats.has(key):
		var base: Color = RoyalBoard.PALETTE.get(color_name, Color("#c0c0c0"))
		var m := StandardMaterial3D.new()
		m.albedo_color = base.lightened(0.08)
		m.metallic = 0.62
		m.metallic_specular = 0.7
		m.roughness = 0.26
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.06
		m.rim_enabled = true      # a soft edge light keeps the silhouette readable
		m.rim = 0.25
		m.rim_tint = 0.6
		_mats[key] = m
	return _mats[key]


static func gold() -> StandardMaterial3D:
	if not _mats.has("gold"):
		var m := StandardMaterial3D.new()
		m.albedo_color = GOLD
		m.metallic = 1.0
		m.roughness = 0.24
		m.metallic_specular = 0.8
		_mats["gold"] = m
		## The medallion's flat face mirrors the dark sky if fully metallic: satin gold.
		var satin := m.duplicate() as StandardMaterial3D
		satin.metallic = 0.75
		satin.roughness = 0.38
		satin.albedo_color = GOLD.lightened(0.1)
		_mats["gold_satin"] = satin
	return _mats["gold"]


static func gem(color_name: String) -> StandardMaterial3D:
	var key := "gem_" + color_name
	if not _mats.has(key):
		var c: Color = RoyalBoard.PALETTE.get(color_name, Color.WHITE)
		_mats[key] = RoyalBoard.gem_material(c.lightened(0.15))
	return _mats[key]


static func _eye_mat() -> StandardMaterial3D:
	if not _mats.has("eye"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#0c0a10")
		m.metallic = 0.3
		m.roughness = 0.05
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		_mats["eye"] = m
		var h := StandardMaterial3D.new()
		h.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		h.albedo_color = Color(1, 1, 1)
		_mats["eye_glint"] = h
	return _mats["eye"]


# --- shared meshes ------------------------------------------------------------------------

static func _mesh(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func _body_mesh() -> Mesh:
	return _mesh("body", func() -> Mesh:
		## (radius, height): a wide plinth, a slim waist, a rounded chest and a neck.
		var ctrl := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.27, 0.0), Vector2(0.302, 0.018), Vector2(0.306, 0.045),
			Vector2(0.285, 0.072), Vector2(0.235, 0.098), Vector2(0.188, 0.15), Vector2(0.168, 0.22),
			Vector2(0.182, 0.31), Vector2(0.198, 0.4), Vector2(0.19, 0.48), Vector2(0.16, 0.545),
			Vector2(0.11, 0.6), Vector2(0.075, 0.635), Vector2(0.0, 0.65)])
		return Monuments.lathe(Monuments.smooth_profile(ctrl, 5), 56))


static func _sphere(key: String, r: float, segs := 28) -> Mesh:
	return _mesh(key, func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = segs
		s.rings = segs / 2
		return s)


static func _torus(key: String, major: float, minor: float) -> Mesh:
	return _mesh(key, func() -> Mesh:
		var t := TorusMesh.new()
		t.inner_radius = major - minor
		t.outer_radius = major + minor
		t.rings = 56
		t.ring_segments = 12
		return t)


static func _capsule(key: String, r: float, h: float) -> Mesh:
	return _mesh(key, func() -> Mesh:
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(h, r * 2.0)
		c.radial_segments = 20
		c.rings = 6
		return c)


static func _disc(key: String, r: float, h: float) -> Mesh:
	return _mesh(key, func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = 32
		return c)


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO, node_name := "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	if node_name != "":
		m.name = node_name
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


## A capsule spanning two points (a limb segment).
static func _segment(parent: Node3D, from: Vector3, to: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var d := to - from
	var length := d.length()
	var key := "cap_%.3f_%.3f" % [r, length]
	var m := _mi(parent, _capsule(key, r, length + r * 2.0), mat, (from + to) * 0.5)
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	m.basis = Basis(x, y, x.cross(y).normalized()).orthonormalized()
	return m


# --- building -----------------------------------------------------------------------------

## The pawn's body (everything that squashes, spins and wears head gear).
static func build_body(color_name: String) -> Node3D:
	var body := Node3D.new()
	var p := paint(color_name)
	var g := gold()
	_mi(body, _body_mesh(), p, Vector3.ZERO, "PawnBody")
	## Gold trims: base rim, belt and collar.
	_mi(body, _torus("rim", 0.3, 0.016), g, Vector3(0, 0.045, 0))
	_mi(body, _torus("base_band", 0.262, 0.01), g, Vector3(0, 0.085, 0))
	_mi(body, _torus("belt", 0.172, 0.019), g, Vector3(0, 0.22, 0))
	_mi(body, _torus("collar", 0.128, 0.02), g, Vector3(0, 0.565, 0))
	## Jewelled medallion on the chest.
	var med := _mi(body, _disc("medallion", 0.062, 0.016), _mats["gold_satin"], Vector3(0, 0.39, 0.193))
	med.rotation.x = PI * 0.5 - 0.12
	_mi(body, _sphere("med_gem", 0.032, 20), gem(color_name), Vector3(0, 0.392, 0.204))
	for i in range(8):   # little gold beads around the medallion
		var a := TAU * i / 8.0
		_mi(body, _sphere("bead", 0.011, 10), g, Vector3(cos(a) * 0.075, 0.39 + sin(a) * 0.075, 0.19 - absf(sin(a)) * 0.01))
	## Head with a face.
	var head := _mi(body, _sphere("head", HEAD_RADIUS, 36), p, HEAD_CENTER, "PawnHead")
	head.scale = HEAD_SCALE
	var eye := _eye_mat()
	for x in [-0.058, 0.058]:
		var e := _mi(body, _sphere("eye", 0.032, 18), eye, HEAD_CENTER + Vector3(x, 0.012, 0.158), "PawnEye")
		e.scale = Vector3(0.95, 1.25, 0.55)
		e.set_meta("no_skin", true)
		var glint := _mi(body, _sphere("glint", 0.009, 8), _mats["eye_glint"], HEAD_CENTER + Vector3(x + 0.01, 0.03, 0.172), "PawnGlint")
		glint.set_meta("no_skin", true)
	## Gold finial on top (hidden when a design puts gear on the head).
	var finial := Node3D.new()
	finial.name = "HeadFinial"
	body.add_child(finial)
	_mi(finial, _torus("finial_ring", 0.05, 0.012), g, Vector3(0, 0.935, 0))
	_mi(finial, _sphere("finial_ball", 0.032, 18), g, Vector3(0, 0.965, 0))
	_mi(finial, _sphere("finial_gem", 0.018, 12), gem(color_name), Vector3(0, 1.0, 0))
	return body


## Arms and legs on the token's pivots; positions match TransformerToken._build_pivots.
static func dress_limbs(token: Node3D, color_name: String, arm_pivots: Dictionary, leg_pivots: Dictionary) -> void:
	var p := paint(color_name)
	var g := gold()
	for side_name in ["L", "R"]:
		var side := -1.0 if side_name == "L" else 1.0
		var arm: Dictionary = arm_pivots[side_name]
		var shoulder_pos := Vector3(side * 0.245, 0.575, 0.0)
		var elbow_pos := Vector3(side * 0.275, 0.375, 0.045)
		var wrist_pos := Vector3(side * 0.125, 0.275, 0.135)
		## Shoulder: a strut into the body and a gold pauldron.
		_segment(arm["shoulder"], Vector3(-side * 0.11, 0.0, 0.0), Vector3.ZERO, 0.04, p)
		var pad := _mi(arm["shoulder"], _sphere("pauldron", 0.07, 24), g, Vector3(0, 0.01, 0))
		pad.scale = Vector3(1.1, 0.85, 1.0)
		_segment(arm["shoulder"], Vector3.ZERO, elbow_pos - shoulder_pos, 0.046, p)
		_mi(arm["elbow"], _sphere("elbow", 0.05, 18), g)
		_segment(arm["elbow"], Vector3.ZERO, wrist_pos - elbow_pos, 0.042, p)
		_mi(arm["wrist"], _torus("cuff", 0.045, 0.012), g, Vector3(0, 0.02, 0))
		_mi(arm["wrist"], _sphere("fist", 0.056, 20), g)   # gold gauntlet
		var leg: Dictionary = leg_pivots[side_name]
		var hip_pos := Vector3(side * 0.115, 0.215, 0.005)
		var knee_pos := Vector3(side * 0.17, 0.105, 0.055)
		var ankle_pos := Vector3(side * 0.095, 0.07, 0.145)
		_segment(leg["hip"], Vector3.ZERO, knee_pos - hip_pos, 0.05, p)
		_mi(leg["knee"], _sphere("knee", 0.052, 18), g)
		_segment(leg["knee"], Vector3.ZERO, ankle_pos - knee_pos, 0.044, p)
		var boot := _mi(leg["ankle"], _sphere("boot", 0.06, 20), g, Vector3(0, -0.01, 0.03))
		boot.scale = Vector3(0.9, 0.6, 1.4)
