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
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	for y in range(size):
		for x in range(size):
			var n := noise.get_noise_2d(x, y)
			var vein := absf(sin((x * 0.09 + y * 0.05) + n * 9.0))
			vein = pow(1.0 - vein, 10.0)
			var grain := noise.get_noise_2d(x * 3.0, y * 3.0) * 0.03
			var v := clampf(0.96 - vein * 0.28 + grain, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.985, v * 0.97))
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


## Domed pavilion with columns, a plinth and gold finial, standing on the courtyard floor.
func _pavilion(base: Vector3, facing: int) -> void:
	var white := _marble_material(Color("#fbf6ea"))
	var p := Node3D.new()
	p.position = base
	p.rotation.y = facing * PI * 0.5
	add_child(p)
	_box(Vector3(0, 0.07, 0), Vector3(1.9, 0.14, 1.9), white, p)
	_box(Vector3(0, 0.16, 0), Vector3(1.6, 0.04, 1.6), _gold, p)
	for x in [-0.7, 0.7]:
		for z in [-0.7, 0.7]:
			_cyl(Vector3(x, 0.7, z), 0.08, 1.2, white, p, 16)
			_box(Vector3(x, 1.34, z), Vector3(0.26, 0.08, 0.26), _gold, p)
	_cyl(Vector3(0, 1.45, 0), 0.9, 0.16, _gold, p, 32)
	## Hemispherical dome: a sphere flattened so only its top half shows above the drum.
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 0.8
	dome.mesh = sphere
	dome.material_override = white
	dome.position = Vector3(0, 1.5, 0)
	p.add_child(dome)
	_cyl(Vector3(0, 2.35, 0), 0.04, 0.5, _gold, p, 8)
	var ball := MeshInstance3D.new()
	var b := SphereMesh.new()
	b.radius = 0.1
	b.height = 0.2
	ball.mesh = b
	ball.material_override = _gold
	ball.position = Vector3(0, 2.6, 0)
	p.add_child(ball)


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
	for i in range(8):
		var a := TAU * i / 8.0
		var petal := PackedVector2Array([Vector2(0, 0), Vector2(0.22, 0.5), Vector2(0, 1.05), Vector2(-0.22, 0.5)])
		var pts := PackedVector2Array()
		for q in petal:
			pts.append(Vector2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a)) * 0.5)
		_flat(pts, CENTRE_TOP - 0.04, _gold)
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
