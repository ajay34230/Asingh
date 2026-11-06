## Procedural Royal India Ludo board, built from BoardPath so the drawn cells are the
## logical cells. The square 15 x 15 playfield sits in the middle of a wide lacquered
## table board. Its side wings carry the four player plaques and the royal decorations,
## so the whole board fills a wide phone screen without stretching any cell.
## Everything here is visual; nothing changes the rules.
class_name RoyalBoard
extends Node3D

## Heights (metres) used by the animation layer for tokens standing on the board.
const TILE_TOP := 0.12        ## top of the track tiles
const FLOOR_TOP := 0.11       ## courtyard floor
const PEDESTAL_TOP := 0.15    ## token pedestals in the courtyards
const CENTRE_TOP := 0.18      ## colour triangles in the centre (finished tokens)
const BOARD_TOP := 0.10       ## lacquer band of the main board frame
const WING_TOP := 0.02        ## wing surface, slightly below the main board
const SLAB_BOTTOM := -0.35

const FRAME_MARGIN := Vector2(1.0, 1.0)  ## lacquer and gold frame around the playfield
const WING_HALF_X := 24.0                ## half width of the whole board, wings included
const PLAQUE_X := 12.7                   ## plaque centre distance from the middle (x)
const PLAQUE_Z := 4.1                    ## plaque centre distance from the middle (z)
const PLAQUE_SIZE := Vector2(7.0, 3.3)
## The camera keeps this half width on screen, so all plaques stay visible on 16:9 too.
const VISIBLE_HALF_X := 16.3

const PALETTE := {
	"red": Color("#c8323c"), "green": Color("#2e9d4f"),
	"yellow": Color("#e9b430"), "blue": Color("#2f6fd0"),
}
const NAMES := {"red": "Ruby", "green": "Emerald", "yellow": "Topaz", "blue": "Sapphire"}

var _ivory: StandardMaterial3D
var _gold: StandardMaterial3D
var _gold_dark: StandardMaterial3D
var _lacquer: StandardMaterial3D
var _ruby: StandardMaterial3D
var _team: Dictionary = {}
var _team_floor: Dictionary = {}
var _gem: Dictionary = {}
var _plaques: Dictionary = {}   ## color -> {root, name, status, pips, glow}
var _active := ""
var theme: Dictionary = {}
var _flames: Array[MeshInstance3D] = []
var _lamps: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	var light_marble := marble_texture(false)
	theme = BoardThemes.current()
	_ivory = marble_material(light_marble, theme["ivory"])
	_gold = metal(theme["gold"], 0.24)
	_gold_dark = metal((theme["gold"] as Color).darkened(0.28), 0.38)
	_lacquer = StandardMaterial3D.new()
	_lacquer.albedo_color = theme["lacquer"]
	_lacquer.roughness = 0.18
	_lacquer.clearcoat_enabled = true
	_lacquer.clearcoat = 0.8
	_lacquer.clearcoat_roughness = 0.1
	_ruby = gem_material(Color("#d1102a"))
	for color in BoardPath.COLORS:
		_team[color] = marble_material(light_marble, PALETTE[color].lerp(Color.WHITE, 0.08))
		_team_floor[color] = marble_material(light_marble, PALETTE[color].darkened(0.12))
		_gem[color] = gem_material(PALETTE[color].lightened(0.1))
	_build_slabs()
	_build_frame()
	_build_tiles()
	_build_courtyards()
	_build_centre()
	_build_markers()
	_build_wings()
	if theme.get("night", false):
		_build_diyas()


func _process(delta: float) -> void:
	_time += delta
	for i in range(_flames.size()):
		var f: MeshInstance3D = _flames[i]
		var k := 1.0 + 0.12 * sin(_time * 13.0 + i * 1.7) + 0.06 * sin(_time * 29.0 + i)
		f.scale = Vector3(0.7, 1.3 * k, 0.7)
	for i in range(_lamps.size()):
		(_lamps[i] as OmniLight3D).light_energy = 1.6 + 0.25 * sin(_time * 11.0 + i * 2.3)
	## The active player's plaque glows and its gems pulse.
	for color in _plaques:
		var p: Dictionary = _plaques[color]
		var glow: StandardMaterial3D = p["glow"]
		var on: bool = color == _active
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		glow.emission_energy_multiplier = (1.2 + 1.6 * pulse) if on else 0.0
		var root: Node3D = p["root"]
		root.position.y = lerpf(root.position.y, 0.08 if on else 0.0, minf(1.0, delta * 8.0))


## Size of the square main board (playfield plus frame). Used for the camera fit.
static func outer_size() -> Vector2:
	return Vector2(BoardPath.GRID_SIZE * BoardPath.CELL_X, BoardPath.GRID_SIZE * BoardPath.CELL_Z) + FRAME_MARGIN * 2.0


## Where a finished token stands: inside its colour's triangle in the centre.
static func finish_world(color: String, token: int) -> Vector3:
	var d := _lane_direction(color)
	var side := Vector2(-d.y, d.x)
	var along := 0.72 if token < 2 else 1.12
	var across := (-0.3 if token % 2 == 0 else 0.3) * (1.0 if token < 2 else 1.25)
	var p := d * along + side * across
	return Vector3(p.x, CENTRE_TOP, p.y)


## Unit direction (x, z) from the board centre towards a colour's home lane.
static func _lane_direction(color: String) -> Vector2:
	var lane: Array = BoardPath.PLAYERS[color]["lane"]
	var mouth: Vector2i = lane[0]
	var w := BoardPath.to_world(mouth.x + 0.5, mouth.y + 0.5)
	return Vector2(w.x, w.z).normalized()


# --- Materials --------------------------------------------------------------

## Seamless marble: ridged, domain-warped noise mapped through a colour ramp, so the
## veins branch like real stone. Generated on a worker thread by NoiseTexture2D.
static func marble_texture(dark: bool) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 31 if dark else 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0035
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 55.0
	noise.domain_warp_frequency = 0.005
	noise.domain_warp_fractal_octaves = 3
	var ramp := Gradient.new()
	if dark:
		ramp.offsets = PackedFloat32Array([0.0, 0.6, 0.85, 0.95, 1.0])
		ramp.colors = PackedColorArray([Color("#0d0504"), Color("#170a07"), Color("#26130c"), Color("#5e4027"), Color("#a07a44")])
	else:
		ramp.offsets = PackedFloat32Array([0.0, 0.5, 0.78, 0.9, 1.0])
		ramp.colors = PackedColorArray([Color("#ffffff"), Color("#f7f2ea"), Color("#e6ddcf"), Color("#b3a796"), Color("#7d7062")])
	var tex := NoiseTexture2D.new()
	tex.width = 1024
	tex.height = 1024
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	return tex


## Polished marble, mapped in world space so neighbouring tiles show different veins.
static func marble_material(tex: Texture2D, tint: Color, scale := 0.11) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.roughness = 0.16
	mat.metallic_specular = 0.6
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.clearcoat_roughness = 0.08
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale
	return mat


static func metal(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 1.0
	mat.roughness = roughness
	return mat


static func gem_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.05
	mat.metallic_specular = 1.0
	mat.clearcoat_enabled = true
	mat.clearcoat = 1.0
	mat.emission_enabled = true
	mat.emission = color.darkened(0.55)
	mat.rim_enabled = true
	mat.rim = 0.4
	return mat


## Gold damask on deep red lacquer: a repeating quatrefoil and lattice pattern.
static func damask_texture(base: Color = Color("#3a0710"), ink: Color = Color("#80551f")) -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var u := float(x) / size
			var v := float(y) / size
			var m := 0.0
			## Diamond lattice.
			var f1 := fposmod(u + v, 1.0)
			var f2 := fposmod(u - v, 1.0)
			m = maxf(m, 1.0 - smoothstep(0.006, 0.014, minf(f1, 1.0 - f1)))
			m = maxf(m, 1.0 - smoothstep(0.006, 0.014, minf(f2, 1.0 - f2)))
			## Quatrefoil in the middle of each diamond, small rosettes on the corners.
			var p := Vector2(u - 0.5, v - 0.5)
			var r := p.length()
			var a := atan2(p.y, p.x)
			var petal := 0.16 + 0.07 * cos(4.0 * a)
			m = maxf(m, 1.0 - smoothstep(petal - 0.012, petal, r))
			m = minf(m, smoothstep(0.035, 0.045, r) * 0.6 + 0.4)  ## darker eye in the flower
			for cx in [0.0, 1.0]:
				for cy in [0.0, 1.0]:
					var q := Vector2(u - cx, v - cy)
					var rr := q.length()
					var pet := 0.07 + 0.025 * cos(8.0 * atan2(q.y, q.x))
					m = maxf(m, 1.0 - smoothstep(pet - 0.01, pet, rr))
			var grain := 0.03 * sin(x * 0.9 + y * 0.35)
			img.set_pixel(x, y, base.lerp(ink, clampf(m, 0.0, 1.0)) * (1.0 + grain))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- Mesh helpers -----------------------------------------------------------

## Box with a chamfered top edge, resting on y = 0. Flat-shaded.
static func bevel_box_mesh(size: Vector3, bevel: float) -> ArrayMesh:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	var b := minf(bevel, minf(minf(hx, hz) * 0.5, h * 0.9))
	var top := [Vector3(-hx + b, h, -hz + b), Vector3(hx - b, h, -hz + b), Vector3(hx - b, h, hz - b), Vector3(-hx + b, h, hz - b)]
	var mid := [Vector3(-hx, h - b, -hz), Vector3(hx, h - b, -hz), Vector3(hx, h - b, hz), Vector3(-hx, h - b, hz)]
	var bot := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_quad(st, top[0], top[1], top[2], top[3])
	for i in range(4):
		var j := (i + 1) % 4
		_quad(st, mid[i], mid[j], top[j], top[i])
		_quad(st, bot[i], bot[j], mid[j], mid[i])
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)


## Solid prism from a 2D outline (x, z), between heights y0 and y1.
static func extrude_mesh(points: PackedVector2Array, y0: float, y1: float) -> ArrayMesh:
	var pts := points
	var area := 0.0
	for i in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		pts = PackedVector2Array()
		for i in range(points.size() - 1, -1, -1):
			pts.append(points[i])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var tris := Geometry2D.triangulate_polygon(pts)
	for t in range(0, tris.size(), 3):
		var a := pts[tris[t]]
		var b := pts[tris[t + 1]]
		var c := pts[tris[t + 2]]
		if (b - a).cross(c - a) < 0.0:
			var tmp := b
			b = c
			c = tmp
		for v in [a, b, c]:
			st.set_uv(v)
			st.add_vertex(Vector3(v.x, y1, v.y))
	for i in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		_quad(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y))
	st.generate_normals()
	return st.commit()


func _mesh(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


func _bevel(at: Vector3, size: Vector3, bevel: float, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	return _mesh(bevel_box_mesh(size, bevel), at, mat, parent)


func _box(at: Vector3, size: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(box, at, mat, parent)


func _cyl(at: Vector3, radius: float, height: float, mat: Material, parent: Node3D = self, sides := 32, top_radius := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return _mesh(c, at, mat, parent)


func _sphere(at: Vector3, radius: float, mat: Material, parent: Node3D = self, squash := 1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 24
	s.rings = 12
	var m := _mesh(s, at, mat, parent)
	m.scale = Vector3(1, squash, 1)
	return m


## Many copies of one mesh in a single draw call.
func _multi(mesh: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	add_child(inst)


# --- Board --------------------------------------------------------------------

func _build_slabs() -> void:
	## One wide lacquered table board: the wings and the raised main board.
	var depth := outer_size().y
	var wing := StandardMaterial3D.new()
	wing.albedo_texture = damask_texture(theme["wing_base"], theme["wing_ink"])
	wing.roughness = 0.42
	wing.metallic = 0.25
	wing.clearcoat_enabled = true
	wing.clearcoat = 0.5
	wing.uv1_triplanar = true
	wing.uv1_world_triplanar = true
	wing.uv1_scale = Vector3.ONE * 0.75
	_bevel(Vector3(0, SLAB_BOTTOM, 0), Vector3(WING_HALF_X * 2.0, WING_TOP - SLAB_BOTTOM, depth + 0.4), 0.12, wing)
	## Gold edge along the long sides of the wide board.
	for s in [-1.0, 1.0]:
		_bevel(Vector3(0, SLAB_BOTTOM, s * (depth * 0.5 + 0.2)), Vector3(WING_HALF_X * 2.0, WING_TOP - SLAB_BOTTOM + 0.08, 0.3), 0.08, _gold)
	## Main board: raised lacquer slab.
	var outer := outer_size()
	_bevel(Vector3(0, WING_TOP - 0.02, 0), Vector3(outer.x, BOARD_TOP - WING_TOP + 0.02, outer.y), 0.06, _lacquer)
	## Gold grout plate under the tiles, so the gaps between tiles read as gold inlay.
	var play := outer - FRAME_MARGIN * 2.0
	_box(Vector3(0, BOARD_TOP + 0.0025, 0), Vector3(play.x, 0.005, play.y), _gold_dark)


func _build_frame() -> void:
	var outer := outer_size()
	var play := outer - FRAME_MARGIN * 2.0
	## Inner gold moulding around the playfield and a taller outer moulding.
	for s in [-1.0, 1.0]:
		_bevel(Vector3(s * (play.x * 0.5 + 0.06), BOARD_TOP, 0), Vector3(0.12, 0.08, play.y + 0.24), 0.03, _gold)
		_bevel(Vector3(0, BOARD_TOP, s * (play.y * 0.5 + 0.06)), Vector3(play.x + 0.24, 0.08, 0.12), 0.03, _gold)
		_bevel(Vector3(s * (outer.x * 0.5 - 0.14), BOARD_TOP - 0.02, 0), Vector3(0.28, 0.16, outer.y), 0.07, _gold)
		_bevel(Vector3(0, BOARD_TOP - 0.02, s * (outer.y * 0.5 - 0.14)), Vector3(outer.x, 0.16, 0.28), 0.07, _gold)
	## Gold bead row in the lacquer band.
	var bead := SphereMesh.new()
	bead.radius = 0.055
	bead.height = 0.11
	bead.radial_segments = 12
	bead.rings = 6
	var beads: Array[Transform3D] = []
	var r := (play.x * 0.5 + outer.x * 0.5 - 0.14) * 0.5
	var steps := 34
	for i in range(steps + 1):
		var f := lerpf(-r, r, float(i) / steps)
		for s in [-1.0, 1.0]:
			beads.append(Transform3D(Basis(), Vector3(f, BOARD_TOP + 0.02, s * r)))
			if i > 0 and i < steps:
				beads.append(Transform3D(Basis(), Vector3(s * r, BOARD_TOP + 0.02, f)))
	_multi(bead, beads, _gold)
	## Corner medallions: a gold boss with a ruby.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var at := Vector3(cx * (outer.x * 0.5 - 0.5), BOARD_TOP, cz * (outer.y * 0.5 - 0.5))
			_cyl(at + Vector3(0, 0.06, 0), 0.46, 0.12, _gold, self, 40, 0.4)
			_cyl(at + Vector3(0, 0.14, 0), 0.3, 0.06, _gold_dark, self, 32)
			_sphere(at + Vector3(0, 0.17, 0), 0.2, _ruby, self, 0.6)


func _build_tiles() -> void:
	var tile := bevel_box_mesh(Vector3(BoardPath.CELL_X * 0.92, TILE_TOP - BOARD_TOP + 0.02, BoardPath.CELL_Z * 0.92), 0.05)
	var groups := {"": [] as Array[Transform3D]}
	for color in BoardPath.COLORS:
		groups[color] = [] as Array[Transform3D]
	for index in range(BoardPath.RING_LENGTH):
		var cell: Vector2i = BoardPath.ring()[index]
		var colour := ""
		for color in BoardPath.COLORS:
			if BoardPath.start_of(color) == index:
				colour = color
		(groups[colour] as Array[Transform3D]).append(_tile_transform(cell))
	for color in BoardPath.COLORS:
		for cell in BoardPath.PLAYERS[color]["lane"]:
			(groups[color] as Array[Transform3D]).append(_tile_transform(cell))
	for key in groups:
		_multi(tile, groups[key], _ivory if key == "" else _team[key])


func _tile_transform(cell: Vector2i) -> Transform3D:
	var w := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
	return Transform3D(Basis(), Vector3(w.x, BOARD_TOP - 0.02, w.z))


func _build_courtyards() -> void:
	var pedestal_ring := CylinderMesh.new()
	pedestal_ring.top_radius = 0.4
	pedestal_ring.bottom_radius = 0.44
	pedestal_ring.height = PEDESTAL_TOP - FLOOR_TOP
	pedestal_ring.radial_segments = 32
	for color in BoardPath.COLORS:
		var home: Vector2i = BoardPath.PLAYERS[color]["home"]
		var c := BoardPath.to_world(home.x + 3, home.y + 3)
		var centre := Vector3(c.x, 0, c.z)
		## Coloured marble floor with an ivory inner court bordered in gold.
		_bevel(centre + Vector3(0, BOARD_TOP - 0.02, 0), Vector3(5.84, FLOOR_TOP - BOARD_TOP + 0.02, 5.84), 0.06, _team_floor[color])
		_bevel(centre + Vector3(0, FLOOR_TOP - 0.01, 0), Vector3(3.5, 0.016, 3.5), 0.01, _gold)
		_bevel(centre + Vector3(0, FLOOR_TOP - 0.01, 0), Vector3(3.36, 0.02, 3.36), 0.01, _ivory)
		## Gold corner rosettes on the coloured floor.
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				_rosette(centre + Vector3(cx * 2.35, FLOOR_TOP, cz * 2.35), 0.42)
		## Token pedestals (the same spots the rules use).
		for token in range(BoardPath.TOKENS_PER_PLAYER):
			var p := BoardPath.base_spot(color, token)
			var at := BoardPath.to_world(p.x, p.y)
			_mesh(pedestal_ring, Vector3(at.x, (FLOOR_TOP + PEDESTAL_TOP) * 0.5, at.z), _gold)
			_cyl(Vector3(at.x, PEDESTAL_TOP - 0.004, at.z), 0.32, 0.012, _team[color], self, 32)
		## A small pavilion in the middle of the court.
		var pav := Node3D.new()
		pav.position = centre + Vector3(0, FLOOR_TOP + 0.01, 0)
		pav.scale = Vector3.ONE * 0.42
		add_child(pav)
		_pavilion(pav, color)


## Flat eight-petal gold flower.
func _rosette(at: Vector3, radius: float) -> void:
	var pts := PackedVector2Array()
	for i in range(32):
		var a := TAU * i / 32.0
		var r := radius * (0.62 + 0.38 * absf(cos(a * 4.0)))
		pts.append(Vector2(cos(a), sin(a)) * r)
	_mesh(extrude_mesh(pts, 0.0, 0.02), at, _gold)
	_sphere(at + Vector3(0, 0.03, 0), radius * 0.22, _ruby, self, 0.5)


## Pavilion: stepped plinth, four columns with gold capitals, a dome on a gold drum, finial.
func _pavilion(p: Node3D, color: String) -> void:
	var white := _ivory
	_bevel(Vector3.ZERO, Vector3(2.0, 0.12, 2.0), 0.03, white, p)
	_bevel(Vector3(0, 0.12, 0), Vector3(1.7, 0.08, 1.7), 0.03, white, p)
	_bevel(Vector3(0, 0.2, 0), Vector3(1.52, 0.04, 1.52), 0.015, _gold, p)
	for x in [-0.62, 0.62]:
		for z in [-0.62, 0.62]:
			_cyl(Vector3(x, 0.78, z), 0.085, 1.08, white, p, 18, 0.075)
			_cyl(Vector3(x, 0.28, z), 0.13, 0.08, _gold, p, 18)
			_cyl(Vector3(x, 1.33, z), 0.1, 0.08, _gold, p, 18, 0.15)
	## Arches between columns (thin gold lintels) and a coloured jewel on each face.
	for s in [-1.0, 1.0]:
		_box(Vector3(0, 1.36, s * 0.62), Vector3(1.38, 0.08, 0.1), _gold, p)
		_box(Vector3(s * 0.62, 1.36, 0), Vector3(0.1, 0.08, 1.38), _gold, p)
		_sphere(Vector3(0, 1.36, s * 0.68), 0.07, _gem[color], p)
		_sphere(Vector3(s * 0.68, 1.36, 0), 0.07, _gem[color], p)
	_cyl(Vector3(0, 1.46, 0), 0.82, 0.12, _gold, p, 40)
	_cyl(Vector3(0, 1.55, 0), 0.7, 0.08, white, p, 40)
	var dome := _sphere(Vector3(0, 1.58, 0), 0.66, white, p, 0.85)
	dome.scale = Vector3(1, 0.85, 1)
	## Lotus-bud top: gold ring, small bud, finial and orb.
	_cyl(Vector3(0, 2.12, 0), 0.16, 0.06, _gold, p, 24)
	_sphere(Vector3(0, 2.2, 0), 0.12, _gold, p, 1.3)
	_cyl(Vector3(0, 2.42, 0), 0.025, 0.3, _gold, p, 8)
	_sphere(Vector3(0, 2.58, 0), 0.06, _gem[color], p)


func _build_centre() -> void:
	_bevel(Vector3(0, BOARD_TOP - 0.02, 0), Vector3(3.0, TILE_TOP - BOARD_TOP + 0.03, 3.0), 0.05, _gold)
	## Four colour triangles, each pointing out along its colour's home lane.
	for color in BoardPath.COLORS:
		var d := _lane_direction(color)
		var side := Vector2(-d.y, d.x)
		var tri := PackedVector2Array([Vector2.ZERO, d * 1.5 + side * 1.5, d * 1.5 - side * 1.5])
		var shrunk := _shrink(tri, 0.9)
		_mesh(extrude_mesh(shrunk, TILE_TOP, CENTRE_TOP), Vector3.ZERO, _team[color])
	## Lotus: two rings of curved 3D petals around a ruby.
	var petal_white := marble_material(marble_texture(false), Color("#fff3f0"))
	for ring in [[8, 0.0, 0.46, 0.17, 18.0, _gold], [8, PI / 8.0, 0.36, 0.14, 42.0, petal_white]]:
		var count: int = ring[0]
		for i in range(count):
			var a: float = ring[1] + TAU * i / count
			var holder := Node3D.new()
			holder.position = Vector3(0, CENTRE_TOP + 0.02, 0)
			holder.rotation.y = a
			add_child(holder)
			var tilt := Node3D.new()
			tilt.rotation.x = -deg_to_rad(ring[4])
			holder.add_child(tilt)
			var len: float = ring[2]
			var petal := _sphere(Vector3(0, 0, len * 0.5), 0.5, ring[5], tilt)
			petal.scale = Vector3(float(ring[3]) * 2.0, 0.06, len)
	_sphere(Vector3(0, CENTRE_TOP + 0.1, 0), 0.14, _ruby)


static func _shrink(points: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in points:
		c += p
	c /= points.size()
	var out := PackedVector2Array()
	for p in points:
		out.append(c + (p - c) * k)
	return out


## Safe-square stars and home-lane arrows, raised in gold and colour.
func _build_markers() -> void:
	var star := PackedVector2Array()
	for i in range(10):
		var r := 0.3 if i % 2 == 0 else 0.13
		var a := TAU * i / 10.0 - PI * 0.5
		star.append(Vector2(cos(a), sin(a)) * r)
	var star_mesh := extrude_mesh(star, 0.0, 0.03)
	for index in BoardPath.safe_ring_indices():
		if BoardPath.COLORS.any(func(c: String) -> bool: return BoardPath.start_of(c) == index):
			continue
		var cell: Vector2i = BoardPath.ring()[index]
		var at := BoardPath.to_world(cell.x + 0.5, cell.y + 0.5)
		_mesh(star_mesh, Vector3(at.x, TILE_TOP, at.z), _gold)
	## Arrow on each colour's entry square, pointing into its home lane.
	var arrow := PackedVector2Array([Vector2(0, 0.34), Vector2(0.24, 0.02), Vector2(0.09, 0.02), Vector2(0.09, -0.3), Vector2(-0.09, -0.3), Vector2(-0.09, 0.02), Vector2(-0.24, 0.02)])
	var arrow_mesh := extrude_mesh(arrow, 0.0, 0.03)
	for color in BoardPath.COLORS:
		var entry: Vector2i = BoardPath.ring()[BoardPath.PLAYERS[color]["entry"]]
		var mouth: Vector2i = BoardPath.PLAYERS[color]["lane"][0]
		var at := BoardPath.to_world(entry.x + 0.5, entry.y + 0.5)
		var to := BoardPath.to_world(mouth.x + 0.5, mouth.y + 0.5)
		var toward := (to - at).normalized()
		var m := _mesh(arrow_mesh, Vector3(at.x, TILE_TOP, at.z), _team[color])
		m.rotation.y = atan2(toward.x, toward.z)  ## the outline points along +Z
		## Start squares get a gold ring so they read as each colour's gate.
		var start: Vector2i = BoardPath.ring()[BoardPath.start_of(color)]
		var s := BoardPath.to_world(start.x + 0.5, start.y + 0.5)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.26
		ring.outer_radius = 0.33
		ring.rings = 32
		ring.ring_segments = 8
		var tm := _mesh(ring, Vector3(s.x, TILE_TOP + 0.01, s.z), _gold)
		tm.scale = Vector3(1, 0.35, 1)


# --- Wings and player plaques ----------------------------------------------

func _build_wings() -> void:
	var outer := outer_size()
	## Gold-lined panels framing each wing's plaque column.
	for s in [-1.0, 1.0]:
		var cx: float = s * PLAQUE_X
		var w := 8.6
		var d := outer.y - 0.9
		for e in [-1.0, 1.0]:
			_bevel(Vector3(cx + e * w * 0.5, WING_TOP, 0), Vector3(0.1, 0.05, d), 0.02, _gold)
			_bevel(Vector3(cx, WING_TOP, e * d * 0.5), Vector3(w + 0.1, 0.05, 0.1), 0.02, _gold)
			for f in [-1.0, 1.0]:
				_rosette(Vector3(cx + e * w * 0.5, WING_TOP + 0.04, f * d * 0.5), 0.3)
		## Decorative lattice column beyond the plaques.
		for i in range(7):
			var z := lerpf(-outer.y * 0.5 + 1.2, outer.y * 0.5 - 1.2, i / 6.0)
			_rosette(Vector3(s * (PLAQUE_X + w * 0.5 + 1.9), WING_TOP, z), 0.26)
	for color in BoardPath.COLORS:
		_build_plaque(color)


func _build_plaque(color: String) -> void:
	var home: Vector2i = BoardPath.PLAYERS[color]["home"]
	var sx := -1.0 if home.x == 0 else 1.0
	var sz := -1.0 if home.y == 0 else 1.0
	var root := Node3D.new()
	root.name = "Plaque_" + color
	add_child(root)
	var base := Node3D.new()
	base.position = Vector3(sx * PLAQUE_X, WING_TOP, sz * PLAQUE_Z)
	root.add_child(base)
	var size := PLAQUE_SIZE
	## Glow frame under the gold frame: lit while it is this player's turn.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = PALETTE[color].lightened(0.3)
	glow.emission_enabled = true
	glow.emission = PALETTE[color].lightened(0.35)
	glow.emission_energy_multiplier = 0.0
	glow.roughness = 0.3
	_bevel(Vector3.ZERO, Vector3(size.x + 0.36, 0.06, size.y + 0.36), 0.03, glow, base)
	_bevel(Vector3(0, 0.02, 0), Vector3(size.x, 0.2, size.y), 0.06, _gold, base)
	_bevel(Vector3(0, 0.2, 0), Vector3(size.x - 0.36, 0.04, size.y - 0.36), 0.02, _team_floor[color], base)
	## Emblem: gold boss with the colour's gem on the side nearest the board.
	var ex := -sx * (size.x * 0.5 - 0.95)
	_cyl(Vector3(ex, 0.27, 0), 0.72, 0.06, _gold, base, 40)
	_cyl(Vector3(ex, 0.31, 0), 0.56, 0.03, _gold_dark, base, 40)
	_sphere(Vector3(ex, 0.33, 0), 0.38, _gem[color], base, 0.55)
	var tx := sx * 0.55
	var name_label := _label(base, Vector3(tx, 0.25, -0.6), 130, Color("#fff6dc"))
	name_label.text = NAMES[color]
	var status := _label(base, Vector3(tx, 0.25, 0.14), 88, Color("#ffe3a0"))
	status.text = ""
	## Four pips: one per token (dark in the yard, coloured on the track, gold when home).
	var pips: Array[MeshInstance3D] = []
	for i in range(BoardPath.TOKENS_PER_PLAYER):
		var px := tx + (i - 1.5) * 0.62
		_cyl(Vector3(px, 0.235, 0.85), 0.25, 0.03, _gold, base, 24)
		var pip := _sphere(Vector3(px, 0.27, 0.85), 0.17, _gold_dark, base, 0.6)
		pips.append(pip)
	_plaques[color] = {"root": root, "name": name_label, "status": status, "pips": pips, "glow": glow}


func _label(parent: Node3D, at: Vector3, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.position = at
	l.rotation_degrees.x = -90.0
	l.pixel_size = 0.0045
	l.font_size = font_size
	l.outline_size = font_size / 6
	l.modulate = color
	l.outline_modulate = Color(0.12, 0.03, 0.02, 0.9)
	l.double_sided = false
	parent.add_child(l)
	return l


## Refreshes every plaque from the rules state. `seats` is RulesEngine.seats.
func update_plaques(seats: Array, active_color: String) -> void:
	_active = active_color
	var seated := {}
	for seat in seats:
		seated[seat["color"]] = seat
	for color in _plaques:
		var p: Dictionary = _plaques[color]
		var name_label: Label3D = p["name"]
		var status: Label3D = p["status"]
		var pips: Array = p["pips"]
		if not seated.has(color):
			name_label.text = NAMES[color]
			name_label.modulate = Color(1, 1, 1, 0.45)
			status.text = "Empty seat"
			for pip in pips:
				(pip as MeshInstance3D).material_override = _gold_dark
			continue
		var seat: Dictionary = seated[color]
		name_label.modulate = Color("#fff6dc")
		name_label.text = ("You" if seat["human"] and _human_count(seats) == 1 else NAMES[color]) + ("" if seat["human"] else "  ·  AI")
		var home := 0
		for i in range(pips.size()):
			var progress: int = seat["tokens"][i]
			var mat: Material = _gold_dark
			if progress >= BoardPath.FINISH_PROGRESS:
				mat = _gold
				home += 1
			elif progress > 0:
				mat = _gem[color]
			(pips[i] as MeshInstance3D).material_override = mat
		if home == BoardPath.TOKENS_PER_PLAYER:
			status.text = "All home!"
		elif color == active_color:
			status.text = "Playing now"
		else:
			status.text = "%d of 4 home" % home


static func _human_count(seats: Array) -> int:
	var n := 0
	for seat in seats:
		if seat["human"]:
			n += 1
	return n


## Diwali: clay diyas with flickering flames around the frame, and warm lamp light.
func _build_diyas() -> void:
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color("#8a4020")
	clay.roughness = 0.8
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color("#ffd27a")
	flame.emission_enabled = true
	flame.emission = Color("#ff9a2a")
	flame.emission_energy_multiplier = 4.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var outer := outer_size()
	var spots: Array[Vector3] = []
	var h := outer.x * 0.5 + 0.35
	for i in range(9):
		var f := lerpf(-h + 1.0, h - 1.0, i / 8.0)
		for s in [-1.0, 1.0]:
			spots.append(Vector3(f, WING_TOP, s * (outer.y * 0.5 + 0.0)))
			spots.append(Vector3(s * (h + 0.1), WING_TOP, f))
	for at in spots:
		_cyl(at + Vector3(0, 0.07, 0), 0.16, 0.14, clay, self, 16, 0.2)
		var fl := _sphere(at + Vector3(0, 0.24, 0), 0.07, flame, self)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames.append(fl)
	for color in BoardPath.COLORS:
		var home: Vector2i = BoardPath.PLAYERS[color]["home"]
		var c := BoardPath.to_world(home.x + 3, home.y + 3)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#ffb060")
		lamp.omni_range = 7.0
		lamp.position = Vector3(c.x, 1.6, c.z)
		add_child(lamp)
		_lamps.append(lamp)
