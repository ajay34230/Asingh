## Realistic robotic Ludo characters, built in code with hard-surface detail:
##   Green  - Emerald Guardian: mechanical mouse ears with sensor dishes.
##   Red    - Crimson Peacock: a deployable fan of articulated metal feathers.
##   Blue   - Sapphire Frost: a pink segmented crest, pink-lit pedestal.
##   Yellow - Golden Sentinel: twin sensor antennae (same family, own identity).
## Shared manufacturing language: anodized armour shells with real thickness and panel
## gaps over a carbon-fibre core, polished gold trims, brushed titanium faceplates,
## bolts, vents, hydraulic pistons, ball joints and glowing joint rings, a chest reactor
## (concentric rings, glass, pulsing core, circuit lines) and a machined pedestal whose
## inner ring turns. Eyes are optical sensors (housing, glass lens, glowing iris) with
## mechanical eyelids that blink. The pivots match TransformerToken, so every animation,
## fight and design keeps working. Meshes are shared; materials are per colour.
class_name RoboPawn
extends RefCounted

const HEAD_CENTER := Vector3(0, 0.79, 0)
const ACCENT := {"green": Color("#34ff8a"), "red": Color("#ff3a3a"), "blue": Color("#ff6ad5"), "yellow": Color("#ffc23a")}
const CORE := {"green": Color("#3bff90"), "red": Color("#ff2a2a"), "blue": Color("#38a8ff"), "yellow": Color("#ffb020")}
const ARMOUR := {"green": Color("#0f8a4a"), "red": Color("#b0101e"), "blue": Color("#1846c8"), "yellow": Color("#d89a18")}

static var _meshes := {}
static var _mats := {}


# --- materials ----------------------------------------------------------------------------

static func _noise_tex() -> Texture2D:
	if not _mats.has("noise"):
		var n := NoiseTexture2D.new()
		n.width = 256
		n.height = 256
		n.seamless = true
		var f := FastNoiseLite.new()
		f.frequency = 0.045
		f.fractal_octaves = 4
		n.noise = f
		_mats["noise"] = n
	return _mats["noise"]


## Carbon-fibre weave as a small tiling texture.
static func _carbon_tex() -> Texture2D:
	if not _mats.has("carbon_tex"):
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		for y in range(32):
			for x in range(32):
				var cell := ((x / 8) + (y / 8)) % 2
				var t := float((y % 8) if cell == 0 else (x % 8)) / 7.0
				var v := 0.07 + 0.09 * sin(t * PI)
				img.set_pixel(x, y, Color(v, v, v * 1.05))
		_mats["carbon_tex"] = ImageTexture.create_from_image(img)
	return _mats["carbon_tex"]


## Anodized aluminium armour in the character colour, with fine roughness variation
## (machining marks and wear) and a clear coat.
static func armour(color_name: String) -> StandardMaterial3D:
	var key := "armour_" + color_name
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = ARMOUR.get(color_name, Color("#888888"))
		m.metallic = 0.82
		m.metallic_specular = 0.7
		m.roughness = 0.34
		m.roughness_texture = _noise_tex()
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(6, 6, 6)
		m.clearcoat_enabled = true
		m.clearcoat = 0.6
		m.clearcoat_roughness = 0.12
		m.rim_enabled = true
		m.rim = 0.2
		m.rim_tint = 0.7
		_mats[key] = m
	return _mats[key]


static func gold() -> StandardMaterial3D:
	if not _mats.has("gold"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#f0c35e")
		m.metallic = 0.92
		m.roughness = 0.22
		m.roughness_texture = _noise_tex()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(9, 9, 9)
		_mats["gold"] = m
	return _mats["gold"]


## Brushed titanium (faceplates, pistons, hinges).
static func titanium() -> StandardMaterial3D:
	if not _mats.has("titanium"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#c4ccd4")
		m.metallic = 0.65
		m.roughness = 0.34
		m.roughness_texture = _noise_tex()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(14, 2, 14)
		_mats["titanium"] = m
	return _mats["titanium"]


## Dark smoked glass for the visor band the eyes look through.
static func visor() -> StandardMaterial3D:
	if not _mats.has("visor"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#07080c")
		m.metallic = 0.5
		m.roughness = 0.06
		m.metallic_specular = 1.0
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.02
		_mats["visor"] = m
	return _mats["visor"]


static func chrome() -> StandardMaterial3D:
	if not _mats.has("chrome"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#dfe4ea")
		m.metallic = 1.0
		m.roughness = 0.08
		_mats["chrome"] = m
	return _mats["chrome"]


static func carbon() -> StandardMaterial3D:
	if not _mats.has("carbon"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _carbon_tex()
		m.albedo_color = Color(1, 1, 1)
		m.metallic = 0.4
		m.roughness = 0.42
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(18, 18, 18)
		_mats["carbon"] = m
	return _mats["carbon"]


static func rubber() -> StandardMaterial3D:
	if not _mats.has("rubber"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#16161a")
		m.roughness = 0.88
		_mats["rubber"] = m
	return _mats["rubber"]


static func glass() -> StandardMaterial3D:
	if not _mats.has("glass"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.7, 0.85, 1.0, 0.1)
		m.metallic = 0.0
		m.roughness = 0.02
		m.metallic_specular = 1.0
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		_mats["glass"] = m
	return _mats["glass"]


## Emissive light (energy core, joint rings, indicators); shared per colour and pulsed.
static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "glow_%s_%.1f" % [color.to_html(false), energy]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.set_meta("base_energy", energy)
		_mats[key] = m
	return _mats[key]


# --- geometry helpers ---------------------------------------------------------------------

static func _mesh(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func _sphere(r: float, segs := 24) -> Mesh:
	return _mesh("sph_%.3f_%d" % [r, segs], func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = segs
		s.rings = maxi(6, segs / 2)
		return s)


static func _cyl(top: float, bottom: float, h: float, segs := 24) -> Mesh:
	return _mesh("cyl_%.3f_%.3f_%.3f_%d" % [top, bottom, h, segs], func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = segs
		c.rings = 1
		return c)


static func _box(size: Vector3) -> Mesh:
	return _mesh("box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z], func() -> Mesh:
		var b := BoxMesh.new()
		b.size = size
		return b)


static func _torus(major: float, minor: float, rings := 48) -> Mesh:
	return _mesh("tor_%.3f_%.3f_%d" % [major, minor, rings], func() -> Mesh:
		var t := TorusMesh.new()
		t.inner_radius = major - minor
		t.outer_radius = major + minor
		t.rings = rings
		t.ring_segments = 10
		return t)


static func _capsule(r: float, h: float) -> Mesh:
	return _mesh("cap_%.3f_%.3f" % [r, h], func() -> Mesh:
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(h, r * 2.0)
		c.radial_segments = 18
		c.rings = 5
		return c)


## A curved armour plate with real thickness: the profile (radius, height) swept from
## angle a0 to a1 around Y, with an inner face and closed edges, so panel gaps read.
static func shell(key: String, ctrl: PackedVector2Array, a0: float, a1: float, segs: int, thick: float) -> Mesh:
	return _mesh("shell_" + key, func() -> Mesh:
		var prof := Monuments.smooth_profile(ctrl, 3)
		var n := prof.size()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pn := func(i: int) -> Vector2:   # outward 2D normal of the profile at point i
			var a := prof[maxi(i - 1, 0)]
			var b := prof[mini(i + 1, n - 1)]
			var t := (b - a).normalized()
			return Vector2(t.y, -t.x)
		var pt := func(p: Vector2, ang: float, off: float, nrm: Vector2) -> Vector3:
			var r := p.x + nrm.x * off
			return Vector3(r * cos(ang), p.y + nrm.y * off, r * sin(ang))
		var quad := func(v: Array, nr: Array) -> void:
			## Front faces wind so that cross(v1 - v0, v2 - v0) points against the normal
			## (as Monuments.lathe does); flip any quad given the other way round.
			var c: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
			if c.length_squared() < 1e-14:
				c = (v[2] - v[0]).cross(v[3] - v[0])
			if c.dot(nr[0] + nr[2]) > 0.0:
				v = [v[0], v[3], v[2], v[1]]
				nr = [nr[0], nr[3], nr[2], nr[1]]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nr[k])
				st.set_uv(Vector2(v[k].x + v[k].z, v[k].y))
				st.add_vertex(v[k])
		for i in range(n - 1):
			var n0: Vector2 = pn.call(i)
			var n1: Vector2 = pn.call(i + 1)
			for j in range(segs):
				var b0 := lerpf(a0, a1, float(j) / segs)
				var b1 := lerpf(a0, a1, float(j + 1) / segs)
				var o := [pt.call(prof[i], b0, 0.0, n0), pt.call(prof[i], b1, 0.0, n0), pt.call(prof[i + 1], b1, 0.0, n1), pt.call(prof[i + 1], b0, 0.0, n1)]
				var on := [Vector3(n0.x * cos(b0), n0.y, n0.x * sin(b0)), Vector3(n0.x * cos(b1), n0.y, n0.x * sin(b1)), Vector3(n1.x * cos(b1), n1.y, n1.x * sin(b1)), Vector3(n1.x * cos(b0), n1.y, n1.x * sin(b0))]
				quad.call([o[1], o[0], o[3], o[2]], [on[1], on[0], on[3], on[2]])
				var inn := [pt.call(prof[i], b0, -thick, n0), pt.call(prof[i], b1, -thick, n0), pt.call(prof[i + 1], b1, -thick, n1), pt.call(prof[i + 1], b0, -thick, n1)]
				quad.call(inn, [-on[0], -on[1], -on[2], -on[3]])
			## Side edges at a0 and a1.
			for e in [[a0, -1.0], [a1, 1.0]]:
				var ang: float = e[0]
				var sn := Vector3(-sin(ang), 0, cos(ang)) * float(e[1])
				var v := [pt.call(prof[i], ang, 0.0, n0), pt.call(prof[i + 1], ang, 0.0, n1), pt.call(prof[i + 1], ang, -thick, n1), pt.call(prof[i], ang, -thick, n0)]
				if e[1] < 0.0:
					v = [v[0], v[3], v[2], v[1]]
				quad.call(v, [sn, sn, sn, sn])
		## Top and bottom edges.
		for e in [[0, -1.0], [n - 1, 1.0]]:
			var i: int = e[0]
			var nr: Vector2 = pn.call(i)
			var tan := Vector2(-nr.y, nr.x) * float(e[1])   # along the profile, away from the plate
			for j in range(segs):
				var b0 := lerpf(a0, a1, float(j) / segs)
				var b1 := lerpf(a0, a1, float(j + 1) / segs)
				var en0 := Vector3(tan.x * cos(b0), tan.y, tan.x * sin(b0))
				var en1 := Vector3(tan.x * cos(b1), tan.y, tan.x * sin(b1))
				var v := [pt.call(prof[i], b0, 0.0, nr), pt.call(prof[i], b1, 0.0, nr), pt.call(prof[i], b1, -thick, nr), pt.call(prof[i], b0, -thick, nr)]
				if e[1] < 0.0:
					v = [v[0], v[3], v[2], v[1]]
					quad.call(v, [en0, en0, en1, en1])
				else:
					quad.call(v, [en0, en1, en1, en0])
		return st.commit())


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	m.scale = scl
	parent.add_child(m)
	return m


static func _no_skin(m: MeshInstance3D) -> MeshInstance3D:
	m.set_meta("no_skin", true)
	return m


## A capsule spanning two points.
static func _segment(parent: Node3D, from: Vector3, to: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var d := to - from
	var m := _mi(parent, _capsule(r, d.length() + r * 2.0), mat, (from + to) * 0.5)
	m.basis = _basis_y(d)
	return m


## A cylinder spanning two points (piston housing, rod, cable).
static func _rod(parent: Node3D, from: Vector3, to: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var d := to - from
	var m := _mi(parent, _cyl(r, r, d.length(), 10), mat, (from + to) * 0.5)
	m.basis = _basis_y(d)
	return m


static func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized()).orthonormalized()


## A ring of small bolts.
static func _bolts(parent: Node3D, count: int, radius: float, y: float, mat: Material, phase := 0.0) -> void:
	for i in range(count):
		var a := phase + TAU * i / count
		_mi(parent, _cyl(0.007, 0.007, 0.008, 6), mat, Vector3(cos(a) * radius, y, sin(a) * radius))


# --- the character --------------------------------------------------------------------------

static func build_body(color_name: String) -> Node3D:
	var body := Node3D.new()
	var arm := armour(color_name)
	var g := gold()
	var ti := titanium()
	var accent: Color = ACCENT.get(color_name, Color.WHITE)
	_pedestal(body, color_name)
	## Carbon-fibre core, seen through the gaps between armour plates.
	_mi(body, _mesh("core_lathe", func() -> Mesh:
		return Monuments.lathe(Monuments.smooth_profile(PackedVector2Array([
			Vector2(0.0, 0.08), Vector2(0.2, 0.08), Vector2(0.165, 0.16), Vector2(0.15, 0.24),
			Vector2(0.165, 0.34), Vector2(0.18, 0.44), Vector2(0.15, 0.53), Vector2(0.09, 0.6),
			Vector2(0.0, 0.62)]), 4), 32)), carbon())
	## Hip skirt: eight plates with gaps, gold-edged.
	var skirt := PackedVector2Array([Vector2(0.235, 0.085), Vector2(0.2, 0.14), Vector2(0.178, 0.2)])
	for i in range(8):
		var a := TAU * i / 8.0
		var plate := _mi(body, shell("skirt", skirt, -0.33, 0.33, 4, 0.014), arm)
		plate.rotation.y = -a
		_mi(plate, _box(Vector3(0.012, 0.016, 0.01)), g, Vector3(0.22, 0.1, 0.0))   # rivet
	## Abdomen: articulated rings like vertebrae.
	for k in range(3):
		_mi(body, _torus(0.162 - k * 0.004, 0.012, 40), ti if k % 2 == 0 else rubber(), Vector3(0, 0.215 + k * 0.026, 0))
	## Chest armour: left and right plates leave room for the reactor; a back plate.
	var chest := PackedVector2Array([Vector2(0.172, 0.29), Vector2(0.195, 0.36), Vector2(0.2, 0.44), Vector2(0.18, 0.5), Vector2(0.14, 0.55)])
	_mi(body, shell("chest_r", chest, PI * 0.5 - 1.25, PI * 0.5 - 0.3, 10, 0.016), arm)
	_mi(body, shell("chest_l", chest, PI * 0.5 + 0.3, PI * 0.5 + 1.25, 10, 0.016), arm)
	_mi(body, shell("back", chest, -PI * 0.5 - 1.0, -PI * 0.5 + 1.0, 14, 0.016), arm)
	## Gold trims along the plate edges, side vents and bolts.
	_mi(body, _torus(0.2, 0.009, 48), g, Vector3(0, 0.43, 0))
	_mi(body, _torus(0.16, 0.013, 40), g, Vector3(0, 0.55, 0))
	for side in [-1.0, 1.0]:
		for k in range(4):   # cooling vents under the arms
			_mi(body, _box(Vector3(0.006, 0.008, 0.06)), rubber(), Vector3(side * 0.197, 0.33 + k * 0.022, -0.02))
		_mi(body, _cyl(0.012, 0.012, 0.01, 8), ti, Vector3(side * 0.165, 0.5, 0.1), Vector3(0, 0, PI * 0.5))
	_bolts(body, 10, 0.195, 0.45, ti, 0.2)
	_reactor(body, color_name)
	## Neck: stacked rings and two cables.
	for k in range(3):
		_mi(body, _cyl(0.07 - k * 0.006, 0.075 - k * 0.006, 0.018, 20), ti if k != 1 else rubber(), Vector3(0, 0.6 + k * 0.02, 0))
	for x in [-0.045, 0.045]:
		_rod(body, Vector3(x, 0.57, -0.05), Vector3(x * 0.8, 0.68, -0.07), 0.008, rubber())
	_head(body, color_name)
	return body


static func _pedestal(body: Node3D, color_name: String) -> void:
	var arm := armour(color_name)
	var g := gold()
	var ti := titanium()
	var accent: Color = ACCENT.get(color_name, Color.WHITE)
	## Machined gold foot with a bevelled edge.
	_mi(body, _mesh("ped_foot", func() -> Mesh:
		return Monuments.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0), Vector2(0.312, 0.008),
			Vector2(0.312, 0.022), Vector2(0.302, 0.03), Vector2(0, 0.03)]), 64)), g)
	## Segmented anodized armour ring (12 panels with locking gaps).
	var ring := PackedVector2Array([Vector2(0.298, 0.03), Vector2(0.29, 0.05), Vector2(0.265, 0.075)])
	for i in range(12):
		var p := _mi(body, shell("ped_ring", ring, -0.24, 0.24, 4, 0.03), arm)
		p.rotation.y = -TAU * i / 12.0
	## Locking clamps between the panels.
	for i in range(12):
		var a := TAU * (i + 0.5) / 12.0
		var c := _mi(body, _box(Vector3(0.022, 0.03, 0.014)), ti, Vector3(cos(a) * 0.29, 0.052, sin(a) * 0.29))
		c.rotation.y = -a
	## Engraved gold top ring with bolts.
	_mi(body, _torus(0.262, 0.012, 64), g, Vector3(0, 0.078, 0))
	_bolts(body, 16, 0.248, 0.086, ti)
	## Energy channel and the turning inner ring with notches.
	_no_skin(_mi(body, _torus(0.225, 0.006, 64), glow(accent, 3.0), Vector3(0, 0.085, 0)))
	var spin := Node3D.new()
	spin.name = "PedestalSpin"
	spin.position = Vector3(0, 0.088, 0)
	body.add_child(spin)
	_mi(spin, _torus(0.205, 0.01, 56), ti)
	for i in range(18):
		var a := TAU * i / 18.0
		var tooth := _mi(spin, _box(Vector3(0.016, 0.012, 0.012)), g, Vector3(cos(a) * 0.205, 0.006, sin(a) * 0.205))
		tooth.rotation.y = -a


static func _reactor(body: Node3D, color_name: String) -> void:
	var core: Color = CORE.get(color_name, Color.WHITE)
	var root := Node3D.new()
	root.name = "Reactor"
	root.position = Vector3(0, 0.4, 0.192)
	root.rotation.x = PI * 0.5 - 0.1   # faces forward
	body.add_child(root)
	_mi(root, _cyl(0.064, 0.07, 0.022, 32), titanium())          # housing
	_mi(root, _torus(0.062, 0.008, 40), gold(), Vector3(0, 0.012, 0))
	_mi(root, _torus(0.047, 0.006, 36), chrome(), Vector3(0, 0.014, 0))
	_no_skin(_mi(root, _torus(0.034, 0.005, 32), glow(core, 4.0), Vector3(0, 0.016, 0)))
	var heart := _no_skin(_mi(root, _sphere(0.026, 20), glow(core.lightened(0.35), 6.0), Vector3(0, 0.014, 0)))
	heart.name = "ReactorCore"
	_no_skin(_mi(root, _sphere(0.04, 24), glass(), Vector3(0, 0.008, 0), Vector3.ZERO, Vector3(1, 0.55, 1)))   # glass dome
	for i in range(6):   # mounting bolts and capacitor blocks
		var a := TAU * i / 6.0 + 0.26
		_mi(root, _cyl(0.007, 0.007, 0.012, 6), gold(), Vector3(cos(a) * 0.076, 0.004, sin(a) * 0.076))
	for i in range(4):
		var a := TAU * i / 4.0
		var cap := _mi(root, _box(Vector3(0.016, 0.01, 0.01)), rubber(), Vector3(cos(a) * 0.084, 0.0, sin(a) * 0.084))
		cap.rotation.y = -a
	## Illuminated circuits running from the reactor across the chest.
	for side in [-1.0, 1.0]:
		for k in range(2):
			var line := _no_skin(_mi(body, _box(Vector3(0.06, 0.004, 0.004)), glow(core, 2.5), Vector3(side * (0.1 + k * 0.012), 0.37 + k * 0.05, 0.178 - k * 0.012)))
			line.rotation.y = side * 0.45
			line.rotation.z = side * (0.25 - k * 0.5)


static func _head(body: Node3D, color_name: String) -> void:
	var arm := armour(color_name)
	var ti := titanium()
	var g := gold()
	var accent: Color = ACCENT.get(color_name, Color.WHITE)
	var head := Node3D.new()
	head.name = "RoboHead"
	head.position = HEAD_CENTER
	body.add_child(head)
	## Segmented helmet: crown shell, two side shells, a back shell, gold seams.
	var dome := PackedVector2Array([Vector2(0.0, 0.165), Vector2(0.09, 0.145), Vector2(0.15, 0.09), Vector2(0.172, 0.02), Vector2(0.168, -0.03)])
	_mi(head, shell("helm_top", dome, -PI, PI, 28, 0.02), arm)
	var cheek := PackedVector2Array([Vector2(0.168, -0.03), Vector2(0.16, -0.08), Vector2(0.13, -0.12), Vector2(0.09, -0.145)])
	_mi(head, shell("helm_l", cheek, PI * 0.5 + 0.55, PI * 1.5 - 0.15, 10, 0.02), arm)
	_mi(head, shell("helm_r", cheek, -PI * 0.5 + 0.15, PI * 0.5 - 0.55, 10, 0.02), arm)
	_mi(head, _torus(0.168, 0.008, 48), g, Vector3(0, -0.03, 0))
	## Inner skull (dark) behind the faceplate gaps.
	_mi(head, _sphere(0.15, 24), rubber(), Vector3(0, -0.01, 0))
	## Gold seam over the crown of the helmet, front to back.
	_mi(head, _torus(0.17, 0.006, 48), g, Vector3(0, -0.005, 0), Vector3(0, PI * 0.5, PI * 0.5), Vector3(1, 1, 1))
	## Smoked-glass visor band across the eyes, framed in titanium.
	var band := PackedVector2Array([Vector2(0.17, 0.055), Vector2(0.176, 0.01), Vector2(0.17, -0.04)])
	_no_skin(_mi(head, shell("visor", band, PI * 0.5 - 0.95, PI * 0.5 + 0.95, 20, 0.012), visor()))
	_mi(head, shell("visor_top", PackedVector2Array([Vector2(0.174, 0.068), Vector2(0.176, 0.055)]), PI * 0.5 - 0.98, PI * 0.5 + 0.98, 20, 0.02), ti)
	_mi(head, shell("visor_bot", PackedVector2Array([Vector2(0.172, -0.04), Vector2(0.168, -0.052)]), PI * 0.5 - 0.98, PI * 0.5 + 0.98, 20, 0.02), ti)
	## Titanium jaw plate with a mouth grille and cheek vents.
	var jaw := PackedVector2Array([Vector2(0.168, -0.052), Vector2(0.155, -0.09), Vector2(0.12, -0.128)])
	_mi(head, shell("jaw", jaw, PI * 0.5 - 0.7, PI * 0.5 + 0.7, 16, 0.016), ti)
	for k in range(4):
		var y := -0.07 - k * 0.012
		var r := 0.162 - k * 0.009
		_mi(head, _box(Vector3(0.06 - k * 0.008, 0.005, 0.008)), rubber(), Vector3(0, y, r + 0.004))
	for side in [-1.0, 1.0]:
		for k in range(3):
			var v := _mi(head, _box(Vector3(0.022, 0.004, 0.008)), rubber(), Vector3(side * 0.1, -0.07 - k * 0.011, 0.135 - k * 0.006))
			v.rotation.y = side * 0.62
		## Ear sensor ports.
		var port := _mi(head, _cyl(0.03, 0.034, 0.02, 20), ti, Vector3(side * 0.172, -0.01, 0.0), Vector3(0, 0, PI * 0.5))
		_no_skin(_mi(port, _cyl(0.014, 0.014, 0.022, 12), glow(accent, 2.5)))
	## Forehead indicator lights.
	for k in range(3):
		_no_skin(_mi(head, _sphere(0.006, 8), glow(accent, 4.0), Vector3((k - 1) * 0.022, 0.078, 0.148)))
	## Optical sensors with eyelids.
	var lids: Array = []
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.name = "Eye"
		eye.position = Vector3(side * 0.062, 0.008, 0.168)
		eye.rotation = Vector3(PI * 0.5, side * 0.18, 0)
		head.add_child(eye)
		_mi(eye, _cyl(0.04, 0.044, 0.022, 28), ti)                                  # housing
		_mi(eye, _torus(0.039, 0.0055, 32), g, Vector3(0, 0.011, 0))                # bezel
		_no_skin(_mi(eye, _cyl(0.033, 0.033, 0.004, 28), rubber(), Vector3(0, 0.011, 0)))
		## Iris: a glowing ring with aperture blades and a bright pupil.
		var iris := _no_skin(_mi(eye, _torus(0.02, 0.0065, 28), glow(CORE.get(color_name, Color.WHITE).lightened(0.25), 4.5), Vector3(0, 0.014, 0)))
		iris.name = "Iris"
		for k in range(6):
			var a := TAU * k / 6.0
			_no_skin(_mi(eye, _box(Vector3(0.004, 0.002, 0.012)), glow(CORE.get(color_name, Color.WHITE), 2.0), Vector3(cos(a) * 0.011, 0.0145, sin(a) * 0.011), Vector3(0, -a, 0)))
		_no_skin(_mi(eye, _cyl(0.007, 0.007, 0.004, 16), glow(Color.WHITE, 6.0), Vector3(0, 0.016, 0)))
		_no_skin(_mi(eye, _sphere(0.035, 22), glass(), Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1, 0.5, 1)))   # lens
		## Eyelid: a thin shell above the eye that drops to blink.
		var lid_pivot := Node3D.new()
		lid_pivot.name = "Lid"
		lid_pivot.position = Vector3(0, 0.02, 0)
		eye.add_child(lid_pivot)
		var lid := _mi(lid_pivot, shell("lid", PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, -0.006), Vector2(0.044, -0.02)]), -PI, 0.0, 14, 0.004), arm, Vector3(0, -0.012, 0), Vector3(PI * 0.5, 0, 0))
		lid.name = "LidPlate"
		lid_pivot.rotation.x = -1.55   # open
		lids.append(lid_pivot)
	var crest := Node3D.new()
	crest.name = "HeadCrest"
	head.add_child(crest)
	match color_name:
		"green":
			_mouse_ears(crest, color_name)
		"red":
			_peacock(crest, color_name)
		"blue":
			_frost_crest(crest, color_name)
		_:
			_antennae(crest, color_name)
	var anim := RoboAnimator.new()
	anim.name = "RoboAnimator"
	anim.head = head
	anim.lids = lids
	anim.crest = crest
	anim.kind = color_name
	body.add_child(anim)


# --- character crests -------------------------------------------------------------------

## Green: rounded mechanical mouse ears, metal shells with sensor dishes inside.
static func _mouse_ears(crest: Node3D, color_name: String) -> void:
	var arm := armour(color_name)
	for side in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.name = "Ear"
		ear.position = Vector3(side * 0.13, 0.12, -0.02)
		ear.rotation = Vector3(PI * 0.5 - 0.15, 0, side * -0.45)
		crest.add_child(ear)
		_mi(ear, _rod_mesh_hinge(), titanium(), Vector3(0, -0.02, 0))
		_mi(ear, _cyl(0.085, 0.09, 0.03, 36), arm, Vector3(0, 0.0, -0.05))            # outer shell
		_mi(ear, _torus(0.086, 0.008, 40), gold(), Vector3(0, 0.016, -0.05))
		_mi(ear, _cyl(0.064, 0.05, 0.01, 32), titanium(), Vector3(0, 0.018, -0.05))  # sensor dish
		_mi(ear, _cyl(0.012, 0.016, 0.03, 12), gold(), Vector3(0, 0.03, -0.05))      # receiver
		_no_skin(_mi(ear, _sphere(0.01, 10), glow(ACCENT["green"], 5.0), Vector3(0, 0.048, -0.05)))
		for k in range(4):
			var a := TAU * k / 4.0
			_mi(ear, _box(Vector3(0.004, 0.006, 0.05)), rubber(), Vector3(cos(a) * 0.03, 0.022, -0.05 + sin(a) * 0.03), Vector3(0, -a, 0))


static func _rod_mesh_hinge() -> Mesh:
	return _cyl(0.018, 0.018, 0.05, 12)


## Red: a deployable peacock fan; each feather is articulated metal segments with an
## optical eye at the tip.
static func _peacock(crest: Node3D, color_name: String) -> void:
	var fan := Node3D.new()
	fan.name = "Fan"
	fan.position = Vector3(0, 0.04, -0.13)
	fan.rotation.x = -0.35
	crest.add_child(fan)
	_mi(fan, _cyl(0.045, 0.05, 0.03, 20), titanium(), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))   # deployment hub
	_mi(fan, _torus(0.046, 0.008, 32), gold(), Vector3(0, 0, 0.0), Vector3(PI * 0.5, 0, 0))
	for i in range(9):
		var a := lerpf(-1.15, 1.15, i / 8.0)
		var feather := Node3D.new()
		feather.name = "Feather"
		feather.rotation.z = a
		fan.add_child(feather)
		var y := 0.03
		for s in range(4):   # articulated segments with hinge pins
			var len := 0.07 - s * 0.006
			_mi(feather, _box(Vector3(0.03 - s * 0.003, len, 0.01)), armour(color_name) if s % 2 == 0 else gold(), Vector3(0, y + len * 0.5, 0))
			_mi(feather, _box(Vector3(0.008, len * 0.8, 0.012)), titanium(), Vector3(0, y + len * 0.5, -0.004))   # spine
			_mi(feather, _cyl(0.007, 0.007, 0.022, 8), titanium(), Vector3(0, y, 0), Vector3(0, 0, PI * 0.5))
			y += len + 0.004
		var tip := Node3D.new()
		tip.position = Vector3(0, y + 0.03, 0)
		feather.add_child(tip)
		_mi(tip, _torus(0.038, 0.007, 28), gold(), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
		_no_skin(_mi(tip, _cyl(0.033, 0.033, 0.006, 24), glow(Color("#14d8c8"), 2.2), Vector3.ZERO, Vector3(PI * 0.5, 0, 0)))
		_no_skin(_mi(tip, _cyl(0.016, 0.016, 0.009, 18), glow(Color("#1a4aff"), 4.0), Vector3.ZERO, Vector3(PI * 0.5, 0, 0)))
		_no_skin(_mi(tip, _sphere(0.036, 16), glass(), Vector3(0, 0, 0.004), Vector3.ZERO, Vector3(1, 1, 0.35)))
	## Gold support arc behind the feathers.
	for i in range(15):
		var a := lerpf(-1.1, 1.1, i / 14.0)
		_mi(fan, _sphere(0.008, 8), gold(), Vector3(-sin(a) * 0.13, cos(a) * 0.13, -0.008))


## Blue: a pink segmented crest of articulated fins along the top of the helmet.
static func _frost_crest(crest: Node3D, _color_name: String) -> void:
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color("#ff6aa8")
	pink.metallic = 0.8
	pink.roughness = 0.3
	pink.clearcoat_enabled = true
	pink.clearcoat = 0.8
	for i in range(5):
		var fin := Node3D.new()
		fin.name = "Fin"
		var t := (i - 2) / 2.0
		fin.position = Vector3(0, 0.168 - absf(t) * 0.035, 0.07 - i * 0.045)
		fin.rotation.x = -0.25 - t * 0.3
		fin.rotation.z = 0.16 if i % 2 == 0 else -0.16   # alternate so each segment reads
		crest.add_child(fin)
		_mi(fin, _cyl(0.012, 0.012, 0.03, 10), gold(), Vector3.ZERO, Vector3(0, 0, PI * 0.5))   # hinge
		_mi(fin, _sphere(0.5, 20), pink, Vector3(0, 0.075, -0.01), Vector3.ZERO, Vector3(0.05, 0.16 - absf(t) * 0.04, 0.075))
		_mi(fin, _box(Vector3(0.034, 0.008, 0.05)), gold(), Vector3(0, 0.02, -0.005))   # mounting shoe
		_mi(fin, _box(Vector3(0.03, 0.006, 0.02)), titanium(), Vector3(0, 0.012, 0))
		_no_skin(_mi(fin, _sphere(0.007, 8), glow(ACCENT["blue"], 4.0), Vector3(0, 0.03, 0.022)))


## Yellow: twin sensor antennae with amber beacons.
static func _antennae(crest: Node3D, color_name: String) -> void:
	for side in [-1.0, 1.0]:
		var ant := Node3D.new()
		ant.name = "Antenna"
		ant.position = Vector3(side * 0.08, 0.13, -0.02)
		ant.rotation.z = -side * 0.35
		crest.add_child(ant)
		_mi(ant, _cyl(0.02, 0.024, 0.03, 12), titanium())
		_mi(ant, _cyl(0.006, 0.008, 0.16, 8), chrome(), Vector3(0, 0.09, 0))
		_mi(ant, _torus(0.014, 0.004, 16), gold(), Vector3(0, 0.07, 0))
		_no_skin(_mi(ant, _sphere(0.018, 14), glow(ACCENT.get(color_name, Color.ORANGE), 5.0), Vector3(0, 0.18, 0)))
		_mi(ant, _box(Vector3(0.004, 0.06, 0.04)), armour(color_name), Vector3(side * 0.012, 0.03, -0.02))


# --- limbs -----------------------------------------------------------------------------------

static func dress_limbs(color_name: String, arm_pivots: Dictionary, leg_pivots: Dictionary) -> void:
	var arm := armour(color_name)
	var g := gold()
	var ti := titanium()
	var accent: Color = ACCENT.get(color_name, Color.WHITE)
	for side_name in ["L", "R"]:
		var side := -1.0 if side_name == "L" else 1.0
		var a: Dictionary = arm_pivots[side_name]
		var shoulder_pos := Vector3(side * 0.245, 0.575, 0.0)
		var elbow_pos := Vector3(side * 0.275, 0.375, 0.045)
		var wrist_pos := Vector3(side * 0.125, 0.275, 0.135)
		var to_elbow := elbow_pos - shoulder_pos
		var to_wrist := wrist_pos - elbow_pos
		## Shoulder: servo housing, ball joint and a layered gold guard.
		_rod(a["shoulder"], Vector3(-side * 0.1, 0, 0), Vector3.ZERO, 0.03, ti)
		_mi(a["shoulder"], _sphere(0.048, 20), rubber())
		var guard := _mi(a["shoulder"], shell("pauldron", PackedVector2Array([Vector2(0.0, 0.075), Vector2(0.05, 0.062), Vector2(0.075, 0.02), Vector2(0.078, -0.03)]), -PI, PI, 18, 0.012), g, Vector3(0, 0.0, 0))
		guard.scale = Vector3(0.82, 0.7, 0.82)
		guard.rotation.z = -side * 0.35
		_mi(a["shoulder"], shell("pauldron2", PackedVector2Array([Vector2(0.0, 0.088), Vector2(0.04, 0.08), Vector2(0.062, 0.05)]), -PI, PI, 16, 0.01), arm, Vector3(-side * 0.012, 0.03, 0), Vector3(0, 0, -side * 0.35), Vector3(0.62, 0.55, 0.62))
		_bolts(a["shoulder"], 6, 0.07, 0.0, ti)
		## Upper arm: armour sleeve over a carbon core, with a hydraulic piston.
		_segment(a["shoulder"], Vector3.ZERO, to_elbow, 0.03, carbon())
		_segment(a["shoulder"], to_elbow * 0.2, to_elbow * 0.75, 0.042, arm)
		var off := Vector3(-side * 0.035, 0, 0.02)
		_rod(a["shoulder"], to_elbow * 0.1 + off, to_elbow * 0.55 + off, 0.011, ti)
		_rod(a["shoulder"], to_elbow * 0.5 + off, to_elbow * 0.92 + off, 0.006, chrome())
		## Elbow: hinge with a glowing joint ring.
		_mi(a["elbow"], _cyl(0.034, 0.034, 0.07, 16), ti, Vector3.ZERO, Vector3(0, 0, PI * 0.5))
		_no_skin(_mi(a["elbow"], _torus(0.036, 0.004, 24), glow(accent, 2.5), Vector3.ZERO, Vector3(0, 0, PI * 0.5)))
		## Forearm: armour, a cable, and the wrist ring.
		_segment(a["elbow"], Vector3.ZERO, to_wrist, 0.026, carbon())
		_segment(a["elbow"], to_wrist * 0.15, to_wrist * 0.8, 0.038, arm)
		_rod(a["elbow"], to_wrist * 0.1 + Vector3(0, 0.03, 0), to_wrist * 0.9 + Vector3(0, 0.03, 0), 0.006, rubber())
		_mi(a["wrist"], _torus(0.034, 0.008, 24), ti, Vector3(0, 0.02, 0))
		## Mechanical gold hand: palm and three knuckled fingers.
		var hand := _mi(a["wrist"], _sphere(0.045, 18), g, Vector3(0, -0.01, 0.005), Vector3.ZERO, Vector3(1.0, 0.85, 1.1))
		hand.name = "Hand"
		for k in range(3):
			_mi(a["wrist"], _capsule(0.011, 0.045), ti, Vector3((k - 1) * 0.02, -0.04, 0.03), Vector3(0.6, 0, 0))
		## Legs: ball hip, thigh armour, glowing knee hinge, shin piston, armoured boot.
		var l: Dictionary = leg_pivots[side_name]
		var hip_pos := Vector3(side * 0.115, 0.215, 0.005)
		var knee_pos := Vector3(side * 0.17, 0.105, 0.055)
		var ankle_pos := Vector3(side * 0.095, 0.07, 0.145)
		_mi(l["hip"], _sphere(0.045, 16), rubber())
		_segment(l["hip"], Vector3.ZERO, knee_pos - hip_pos, 0.04, arm)
		_mi(l["knee"], _cyl(0.034, 0.034, 0.07, 14), ti, Vector3.ZERO, Vector3(0, 0, PI * 0.5))
		_no_skin(_mi(l["knee"], _torus(0.036, 0.004, 20), glow(accent, 2.5), Vector3.ZERO, Vector3(0, 0, PI * 0.5)))
		_segment(l["knee"], Vector3.ZERO, ankle_pos - knee_pos, 0.034, arm)
		var boot := _mi(l["ankle"], _sphere(0.055, 18), g, Vector3(0, -0.01, 0.03), Vector3.ZERO, Vector3(1.0, 0.6, 1.5))
		boot.name = "Boot"
		_mi(l["ankle"], _box(Vector3(0.07, 0.012, 0.06)), arm, Vector3(0, 0.012, 0.045))


# --- reactions ---------------------------------------------------------------------------------

static func is_robo(token: Node3D) -> bool:
	return token.body_node != null and token.body_node.has_node("RoboAnimator")


## Victory: the crest performs (ears spin, fan spreads, fins rise, antennae flash).
static func celebrate(token: Node3D) -> void:
	if not is_robo(token):
		return
	(token.body_node.get_node("RoboAnimator") as RoboAnimator).celebrate()


## Defeat: eyes flicker and dim, the head droops.
static func defeated(token: Node3D, seconds: float) -> void:
	if not is_robo(token):
		return
	(token.body_node.get_node("RoboAnimator") as RoboAnimator).defeated(seconds)
