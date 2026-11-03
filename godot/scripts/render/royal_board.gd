## Procedural Royal India Ludo board, built from BoardPath so the drawn cells are the
## logical cells. Wider than tall: the playfield is 15 x 15 cells of 1.17 x 0.73 m.
## Materials: generated marble (veins from noise), polished gold, and team colours.
## Everything here is visual; nothing changes the rules.
class_name RoyalBoard
extends Node3D

## Heights (metres) used by the animation layer for tokens standing on the board.
const TILE_TOP := 0.12
const FLOOR_TOP := 0.10       ## courtyard floor and token discs
const CENTRE_TOP := 0.22      ## lotus medallion
const FRAME_TOP := 0.05

const FRAME_MARGIN := Vector2(1.5, 1.1)   ## gold frame around the playfield (x, z)

var _marble_tex: ImageTexture
var _ivory: StandardMaterial3D
var _gold: StandardMaterial3D
var _team: Dictionary = {}
var _dark: StandardMaterial3D


func _ready() -> void:
	_marble_tex = _make_marble_texture()
	_ivory = _marble_material(Color("#f3ecdc"))
	_gold = _metal(Color("#d9a441"))
	_dark = _solid(Color("#4a1218"), 0.55)
	for color in BoardPath.COLORS:
		_team[color] = _marble_material(PALETTE[color])
	_build_frame()
	_build_tiles()
	_build_courtyards()
	_build_centre()
	_build_markers()


## Full playfield size in metres, including the frame. Used by the camera fit.
static func outer_size() -> Vector2:
	return Vector2(BoardPath.GRID_SIZE * BoardPath.CELL_X, BoardPath.GRID_SIZE * BoardPath.CELL_Z) + FRAME_MARGIN * 2.0


const PALETTE := {
	"red": Color("#c8323c"), "green": Color("#2e9d4f"),
	"yellow": Color("#e9b430"), "blue": Color("#2f6fd0"),
}


func _make_marble_texture() -> ImageTexture:
	var size := 512
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var warp := FastNoiseLite.new()
	warp.seed = 11
	warp.frequency = 0.006
	warp.fractal_octaves = 3
	var grain := FastNoiseLite.new()
	grain.seed = 23
	grain.frequency = 0.25
	grain.fractal_octaves = 2
	for y in range(size):
		for x in range(size):
			var w := warp.get_noise_2d(x, y)
			## Veins: thin dark lines where a warped diagonal sine crosses zero.
			var phase := (x * 0.035 + y * 0.012) + w * 14.0
			var vein := pow(1.0 - absf(sin(phase)), 14.0)
			var cloud := 0.5 + 0.5 * warp.get_noise_2d(x * 0.5, y * 0.5 + 300.0)
			var g := grain.get_noise_2d(x, y) * 0.025
			var v := clampf(0.97 - vein * 0.42 - (1.0 - cloud) * 0.06 + g, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.95))
	return ImageTexture.create_from_image(img)


func _marble_material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _marble_tex
	mat.albedo_color = tint
	mat.roughness = 0.22
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return mat


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _metal(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 1.0
	mat.roughness = 0.28
	return mat


func _box(at: Vector3, size: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


func _cyl(at: Vector3, radius: float, height: float, mat: Material, parent: Node3D = self, sides := 24) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	m.mesh = c
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


## Flat polygon at height y, triangulated as a fan from its centre. Works for convex and
## star-shaped outlines (stars, arrows, lotus petals, triangles).
func _flat(points: PackedVector2Array, y: float, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		for v in [centre, a, b]:
			st.set_uv(Vector2((v.x + 10.0) / 20.0, (v.y + 10.0) / 20.0))
			st.add_vertex(Vector3(v.x, y, v.y))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	parent.add_child(m)
	return m


func _build_frame() -> void:
	var outer := outer_size()
	_box(Vector3(0, -0.22, 0), Vector3(outer.x, 0.44, outer.y), _dark)
	## Gold rim around the frame, and a raised lip on top.
	var t := 0.22
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (outer.x * 0.5 - t * 0.5), FRAME_TOP, 0), Vector3(t, 0.12, outer.y), _gold)
		_box(Vector3(0, FRAME_TOP, side * (outer.y * 0.5 - t * 0.5)), Vector3(outer.x, 0.12, t), _gold)
	## Bead rim along the top edge: small gold spheres.
	var bead := SphereMesh.new()
	bead.radius = 0.06
	bead.height = 0.12
	var count := 60
	for i in range(count):
		var f := float(i) / count
		var x := lerpf(-outer.x * 0.5 + 0.25, outer.x * 0.5 - 0.25, f)
		for z in [-outer.y * 0.5 + 0.22, outer.y * 0.5 - 0.22]:
			var m := MeshInstance3D.new()
			m.mesh = bead
			m.material_override = _gold
			m.position = Vector3(x, FRAME_TOP + 0.08, z)
			add_child(m)


func _tile_material(color: String) -> Material:
	if color == "":
		return _ivory
	return _team[color]


func _build_tiles() -> void:
	var size := Vector3(BoardPath.CELL_X * 0.9, TILE_TOP, BoardPath.CELL_Z * 0.9)
	for index in range(BoardPath.RING_LENGTH):
		var cell: Vector2i = BoardPath.ring()[index]
		var colour := ""
		for color in BoardPath.COLORS:
			if BoardPath.start_of(color) == index:
				colour = color
		_tile_at(cell, size, colour)
	for color in BoardPath.COLORS:
		for cell in BoardPath.PLAYERS[color]["lane"]:
			_tile_at(cell, size, color)


func _tile_at(cell: Vector2i, size: Vector3, colour: String) -> void:
	var world := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
	_box(Vector3(world.x, TILE_TOP * 0.5, world.z), size, _tile_material(colour))


func _build_courtyards() -> void:
	for color in BoardPath.COLORS:
		var home: Vector2i = BoardPath.PLAYERS[color]["home"]
		var centre := BoardPath.to_world(home.x + 3, home.y + 3)
		var w := 6.0 * BoardPath.CELL_X
		var d := 6.0 * BoardPath.CELL_Z
		_box(Vector3(centre.x, FLOOR_TOP * 0.5, centre.z), Vector3(w * 0.96, FLOOR_TOP, d * 0.96), _team[color])
		## Gold inlay frame around the floor.
		for s in [-1.0, 1.0]:
			_box(Vector3(centre.x + s * (w * 0.48 - 0.04), FLOOR_TOP + 0.01, centre.z), Vector3(0.08, 0.02, d * 0.96), _gold)
			_box(Vector3(centre.x, FLOOR_TOP + 0.01, centre.z + s * (d * 0.48 - 0.04)), Vector3(w * 0.96, 0.02, 0.08), _gold)
		_pavilion(Vector3(centre.x, FLOOR_TOP, centre.z), BoardPath.COLORS.find(color))
		## Token discs (the same spots the rules use).
		for token in range(BoardPath.TOKENS_PER_PLAYER):
			var p := BoardPath.base_spot(color, token)
			var at := BoardPath.to_world(p.x, p.y)
			_cyl(Vector3(at.x, FLOOR_TOP + 0.01, at.z), 0.32, 0.03, _gold)
			_cyl(Vector3(at.x, FLOOR_TOP + 0.03, at.z), 0.22, 0.02, _team[color])


## Pavilion: two-tier plinth, four columns with gold capitals, a dome, a gold drum and a
## finial. Built from primitives; faces a board direction given by `facing`.
func _pavilion(base: Vector3, facing: int) -> void:
	var white := _marble_material(Color("#fbf6ea"))
	var p := Node3D.new()
	p.position = base
	p.rotation.y = facing * PI * 0.5
	add_child(p)
	_box(Vector3(0, 0.05, 0), Vector3(2.0, 0.1, 2.0), white, p)
	_box(Vector3(0, 0.13, 0), Vector3(1.7, 0.06, 1.7), white, p)
	_box(Vector3(0, 0.2, 0), Vector3(1.5, 0.03, 1.5), _gold, p)
	## Four columns on the corners, with gold capitals.
	for x in [-0.62, 0.62]:
		for z in [-0.62, 0.62]:
			_cyl(Vector3(x, 0.75, z), 0.09, 1.1, white, p, 18)
			_cyl(Vector3(x, 0.24, z), 0.13, 0.08, _gold, p, 18)
			_box(Vector3(x, 1.32, z), Vector3(0.28, 0.07, 0.28), _gold, p)
	## Gold entablature ring, then the dome on it.
	_cyl(Vector3(0, 1.42, 0), 0.82, 0.12, _gold, p, 32)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	sphere.radial_segments = 32
	sphere.rings = 16
	dome.mesh = sphere
	dome.material_override = white
	dome.position = Vector3(0, 1.48, 0)
	dome.scale = Vector3(1.0, 0.75, 1.0)
	p.add_child(dome)
	## Finial: a thin stem and a gold orb.
	_cyl(Vector3(0, 2.0, 0), 0.035, 0.36, _gold, p, 8)
	var orb := MeshInstance3D.new()
	var o := SphereMesh.new()
	o.radius = 0.09
	o.height = 0.18
	orb.mesh = o
	orb.material_override = _gold
	orb.position = Vector3(0, 2.2, 0)
	p.add_child(orb)


func _build_centre() -> void:
	var w := 3.0 * BoardPath.CELL_X
	var d := 3.0 * BoardPath.CELL_Z
	_box(Vector3(0, TILE_TOP * 0.5, 0), Vector3(w, TILE_TOP, d), _gold)
	## Four colour triangles point at each arm's home lane.
	var half_w := w * 0.5
	var half_d := d * 0.5
	var tris := {
		"green": PackedVector2Array([Vector2(-half_w, -half_d), Vector2(half_w, -half_d), Vector2(0, 0)]),
		"yellow": PackedVector2Array([Vector2(half_w, -half_d), Vector2(half_w, half_d), Vector2(0, 0)]),
		"blue": PackedVector2Array([Vector2(half_w, half_d), Vector2(-half_w, half_d), Vector2(0, 0)]),
		"red": PackedVector2Array([Vector2(-half_w, half_d), Vector2(-half_w, -half_d), Vector2(0, 0)]),
	}
	for color in tris:
		_flat(_shrink(tris[color], 0.92), TILE_TOP + 0.005, _team[color])
	## Lotus medallion: eight gold petals around a ruby.
	for ring in [[8, 0.0, 0.62, 0.3], [8, PI / 8.0, 0.95, 0.22]]:
		var count: int = ring[0]
		for i in range(count):
			var a: float = ring[1] + TAU * i / count
			var len: float = ring[2]
			var wid: float = ring[3]
			var petal := PackedVector2Array([Vector2(0, 0), Vector2(wid, len * 0.45), Vector2(0, len), Vector2(-wid, len * 0.45)])
			var pts := PackedVector2Array()
			for q in petal:
				pts.append(Vector2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a)))
			_flat(pts, CENTRE_TOP - 0.04 - float(ring[3]) * 0.0, _gold)
	var ruby := MeshInstance3D.new()
	var rs := SphereMesh.new()
	rs.radius = 0.16
	rs.height = 0.32
	ruby.mesh = rs
	var rmat := _solid(Color("#c1121f"), 0.1)
	rmat.emission_enabled = true
	rmat.emission = Color("#8a0010")
	ruby.material_override = rmat
	ruby.position = Vector3(0, CENTRE_TOP, 0)
	add_child(ruby)


static func _shrink(points: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in points:
		c += p
	c /= points.size()
	var out := PackedVector2Array()
	for p in points:
		out.append(c + (p - c) * k)
	return out


## Safe-square stars and home-lane arrows.
func _build_markers() -> void:
	var star := PackedVector2Array()
	for i in range(10):
		var r := 0.2 if i % 2 == 0 else 0.09
		var a := TAU * i / 10.0 - PI * 0.5
		star.append(Vector2(cos(a), sin(a)) * r)
	for index in BoardPath.safe_ring_indices():
		if BoardPath.COLORS.any(func(c: String) -> bool: return BoardPath.start_of(c) == index):
			continue
		var cell: Vector2i = BoardPath.ring()[index]
		var at := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
		var m := _flat(star, TILE_TOP + 0.01, _gold)
		m.position = Vector3(at.x, 0, at.z)
	for color in BoardPath.COLORS:
		var entry: Vector2i = BoardPath.ring()[BoardPath.PLAYERS[color]["entry"]]
		var at := BoardPath.to_world(entry.x + 0.5, entry.y + 0.5)
		var toward := -at.normalized()
		var arrow := PackedVector2Array([Vector2(0, 0.3), Vector2(0.22, -0.05), Vector2(0.08, -0.05), Vector2(0.08, -0.3), Vector2(-0.08, -0.3), Vector2(-0.08, -0.05), Vector2(-0.22, -0.05)])
		var m := _flat(arrow, TILE_TOP + 0.01, _team[color])
		m.position = Vector3(at.x, 0, at.z)
		m.rotation.y = atan2(-toward.x, -toward.z)
