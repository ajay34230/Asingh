## The royal jewel dice, built in code: a rounded ivory-marble cube with polished gold
## edging and corner bosses, an engraved gold frame on every face, and pips that are
## cut gems in gold bezels (rubies, with a large lotus ruby for the one, as on
## traditional Indian dice). Face N points the way DiceController.FACE_OUTWARD expects.
class_name RoyalDice
extends RefCounted

const HALF := 0.6          ## half the edge length
const ROUND := 0.11        ## corner and edge rounding radius


## Skins: ivory marble (default), jade, ebony, lapis. Same build, different stone.
const SKINS := {
	"dice_ivory": ["marble_white", Color("#f1e6d0")],
	"dice_jade": ["onyx_white", Color("#3fae74")],
	"dice_ebony": ["granite_dark", Color("#c8b8a8")],
	"dice_lapis": ["travertine_blue", Color("#3a62d8")],
}


static func build(skin := "dice_ivory") -> Node3D:
	var root := Node3D.new()
	root.name = "DiceModel"
	var stone: Array = SKINS.get(skin, SKINS["dice_ivory"])
	var ivory := RoyalBoard.pbr(stone[0], stone[1], 1.4, 0.45, 0.7)
	## Satin gold with a faint warm glow, so it stays golden even where it reflects the
	## dark table (polished gold close up otherwise turns almost black).
	var gold := RoyalBoard.metal(Color("#f0c060"), 0.34)
	gold.emission_enabled = true
	gold.emission = Color("#8a5a10")
	gold.emission_energy_multiplier = 0.6
	var ruby := RoyalBoard.gem_material(Color("#d0142e"))
	var sapphire := RoyalBoard.gem_material(Color("#1f5fd6"))
	_mesh(root, _rounded_cube(HALF, ROUND, 10), ivory)
	_edges(root, gold)
	var faces := {
		1: Vector3(0, 0, 1), 2: Vector3(1, 0, 0), 3: Vector3(0, 1, 0),
		4: Vector3(0, -1, 0), 5: Vector3(-1, 0, 0), 6: Vector3(0, 0, -1),
	}
	for n in faces:
		_face(root, faces[n], n, gold, ruby if n == 1 or n == 4 else sapphire)
	return root


## Cube with rounded edges: each vertex of a subdivided cube is pulled onto a sphere of
## radius `r` around the nearest point of the inner box. Smooth normals follow.
static func _rounded_cube(h: float, r: float, div: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := h - r
	var axes := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	var shape := func(v: Vector3) -> Array:
		var c := Vector3(clampf(v.x, -inner, inner), clampf(v.y, -inner, inner), clampf(v.z, -inner, inner))
		var d := v - c
		var n := d.normalized() if d.length_squared() > 1e-8 else v.normalized()
		return [c + n * r, n]
	for f in axes:
		var normal: Vector3 = f[0]
		var u: Vector3 = f[1]
		var w: Vector3 = f[2]
		for i in range(div):
			for j in range(div):
				var corners: Array[Vector3] = []
				for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
					var a := lerpf(-h, h, float(k[0]) / div)
					var b := lerpf(-h, h, float(k[1]) / div)
					corners.append(normal * h + u * a + w * b)
				var quad := [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]]
				## Wind each triangle so it faces outward.
				var tri_n := (corners[1] - corners[0]).cross(corners[2] - corners[0])
				if tri_n.dot(normal) > 0.0:   # Godot's front faces wind clockwise
					quad = [corners[0], corners[2], corners[1], corners[0], corners[3], corners[2]]
				for v in quad:
					var sv: Array = shape.call(v)
					st.set_normal(sv[1])
					st.set_uv(Vector2(v.x + v.z, v.y + v.z))
					st.add_vertex(sv[0])
	return st.commit()


## Gold piping along the twelve edges and a gold boss on each corner.
static func _edges(root: Node3D, gold: Material) -> void:
	var inner := HALF - ROUND
	var out := ROUND * 0.72
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.028
	pipe.bottom_radius = 0.028
	pipe.height = inner * 2.0
	pipe.radial_segments = 16
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		var others := [Vector3.RIGHT, Vector3.UP, Vector3.BACK].filter(func(a: Vector3) -> bool: return a != axis)
		for s1 in [-1.0, 1.0]:
			for s2 in [-1.0, 1.0]:
				var dir: Vector3 = (others[0] * s1 + others[1] * s2).normalized()
				var pos: Vector3 = (others[0] * s1 + others[1] * s2) * inner + dir * out
				var m := _mesh(root, pipe, gold)
				m.position = pos
				if axis == Vector3.RIGHT:
					m.rotation.z = PI * 0.5
				elif axis == Vector3.BACK:
					m.rotation.x = PI * 0.5
	var boss := SphereMesh.new()
	boss.radius = 0.065
	boss.height = 0.13
	boss.radial_segments = 20
	boss.rings = 10
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var c := Vector3(x, y, z)
				var m := _mesh(root, boss, gold)
				m.position = c * inner + c.normalized() * ROUND * 0.85


static func _face(root: Node3D, normal: Vector3, n: int, gold: Material, gem: Material) -> void:
	var face := Node3D.new()
	face.set_meta("face", n)
	root.add_child(face)
	## Orient a local frame: +Y out of the face.
	var up := normal
	var side := Vector3.RIGHT if absf(normal.x) < 0.9 else Vector3.BACK
	var fwd := side.cross(up).normalized()
	side = up.cross(fwd).normalized()
	face.basis = Basis(side, up, fwd)
	face.position = normal * HALF
	## Engraved gold frame inset on the face.
	var e := HALF - ROUND - 0.04
	for s in [-1.0, 1.0]:
		var bar := BoxMesh.new()
		bar.size = Vector3(e * 2.0, 0.012, 0.025)
		_mesh(face, bar, gold).position = Vector3(0, 0.002, s * e)
		var bar2 := BoxMesh.new()
		bar2.size = Vector3(0.025, 0.012, e * 2.0)
		_mesh(face, bar2, gold).position = Vector3(s * e, 0.002, 0)
	## Small gold dots in the frame corners.
	var dot := SphereMesh.new()
	dot.radius = 0.022
	dot.height = 0.03
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_mesh(face, dot, gold).position = Vector3(x * e, 0.004, z * e)
	var g := 0.24
	var layouts := {
		1: [Vector2(0, 0)],
		2: [Vector2(-g, -g), Vector2(g, g)],
		3: [Vector2(-g, -g), Vector2(0, 0), Vector2(g, g)],
		4: [Vector2(-g, -g), Vector2(g, -g), Vector2(-g, g), Vector2(g, g)],
		5: [Vector2(-g, -g), Vector2(g, -g), Vector2(0, 0), Vector2(-g, g), Vector2(g, g)],
		6: [Vector2(-g, -g), Vector2(-g, 0), Vector2(-g, g), Vector2(g, -g), Vector2(g, 0), Vector2(g, g)],
	}
	var big := n == 1
	for p in layouts[n]:
		_pip(face, Vector3(p.x, 0, p.y), 0.13 if big else 0.075, gold, gem, big)


## A cut gem in a gold bezel; the big one also gets a ring of gold lotus petals.
static func _pip(face: Node3D, at: Vector3, r: float, gold: Material, gem: Material, lotus: bool) -> void:
	var bezel := TorusMesh.new()
	bezel.inner_radius = r * 0.92
	bezel.outer_radius = r * 1.22
	bezel.rings = 32
	bezel.ring_segments = 12
	var b := _mesh(face, bezel, gold)
	b.position = at + Vector3(0, 0.005, 0)
	b.scale = Vector3(1, 0.6, 1)
	var stone := SphereMesh.new()
	stone.radius = r
	stone.height = r * 2.0
	stone.radial_segments = 8          # facets catch the light like a cut stone
	stone.rings = 4
	var s := _mesh(face, stone, gem)
	s.position = at + Vector3(0, -r * 0.35, 0)
	s.scale = Vector3(1, 0.75, 1)
	if lotus:
		var petal := SphereMesh.new()
		petal.radius = 0.5
		petal.height = 1.0
		for i in range(8):
			var a := TAU * i / 8.0
			var pm := _mesh(face, petal, gold)
			pm.position = at + Vector3(cos(a) * r * 1.6, 0.004, sin(a) * r * 1.6)
			pm.rotation.y = -a
			pm.scale = Vector3(r * 1.0, 0.03, r * 0.6)


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	parent.add_child(m)
	return m
