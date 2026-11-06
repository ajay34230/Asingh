class_name FrontierBuilder
extends RefCounted
## The Southern Road: open desert plateau south of the valley, reached through a pass in the south rim.
## A winding road (about 520 m) climbs out of the pass and runs past the third Ashen outpost to Kesar Sarai,
## a walled caravan inn, and on to Dhoopgarh, a frontier village in the foothills. Long enough that riding
## (horses and camels wait at the pass and at each stop) is the sensible way to travel.
## The ground joins the valley mesh exactly along z = 200 (same x spacing, same edge heights).

const X0 := -200.0
const X1 := 120.0
const Z0 := 200.0
const Z1 := 680.0
const CX := 1.6                      # matches the valley grid along the seam
const CZ := 3.2
const NX := 200                      # (X1 - X0) / CX
const NZ := 150                      # (Z1 - Z0) / CZ
const CHUNK_X := 50
const CHUNK_Z := 30
const PLAIN := 32.0                  # plateau level (the skirt plane around the valley)

const ROAD: Array[Vector2] = [
	Vector2(-40, 196), Vector2(-38, 235), Vector2(-26, 280), Vector2(-8, 325), Vector2(-6, 360),
	Vector2(-14, 400), Vector2(-38, 440), Vector2(-62, 485), Vector2(-66, 535), Vector2(-50, 585), Vector2(-36, 620),
]
const SARAI_C := Vector2(18.0, 396.0)
const SARAI_R := 24.0
const DHOOP_C := Vector2(-36.0, 636.0)
const DHOOP_R := 30.0
const OUTPOST_C := Vector2(-40.0, 205.0)   # Act 4's third outpost (Act4.OUTPOSTS[2]) sits at the top of the pass

var heights := PackedFloat32Array()
var _dunes := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var material: Material
var npcs: Array[Npc] = []
var animals: Array = []


func _init() -> void:
	_dunes.seed = 913
	_dunes.frequency = 0.0085
	_dunes.fractal_octaves = 3
	_detail.seed = 77
	_detail.frequency = 0.06


static func contains(x: float, z: float) -> bool:
	return x >= X0 and x <= X1 and z >= Z0 and z <= Z1


## Distance from (x, z) to the road polyline.
static func road_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1e9
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## Road surface height: climbs from the pass level to the plateau over the first 80 m, then rolls gently.
static func road_y(z: float) -> float:
	return lerpf(TerrainBuilder.PASS_Y, PLAIN - 0.5, smoothstep(200.0, 285.0, z)) + 1.2 * sin(z * 0.021) * smoothstep(260.0, 320.0, z)


func height_at(x: float, z: float) -> float:
	var edge_y := lerpf(TerrainBuilder.EDGE_Y, TerrainBuilder.PASS_Y, TerrainBuilder.pass_mask(x))
	var dn := _dunes.get_noise_2d(x, z)
	var crest := 1.0 - absf(dn)
	var h := PLAIN + crest * crest * 9.0 + dn * 2.5 - 3.5 + _detail.get_noise_2d(x, z) * 0.9
	var rd := road_dist(x, z)
	# the pass: rock walls either side of the road for the first stretch out of the valley
	var canyon := smoothstep(203.0, 214.0, z) * (1.0 - smoothstep(250.0, 300.0, z))
	h += canyon * smoothstep(9.0, 26.0, rd) * 22.0
	# road bed and settlement pads
	h = lerpf(road_y(z), h, smoothstep(4.5, 12.0, rd))
	for c in [[SARAI_C, SARAI_R], [DHOOP_C, DHOOP_R], [OUTPOST_C, 14.0]]:
		var cc: Vector2 = c[0]
		var r: float = c[1]
		var d := Vector2(x - cc.x, z - cc.y).length()
		h = lerpf(road_y(cc.y), h, smoothstep(r - 4.0, r + 12.0, d))
	# ridges along the outer edges keep the road inside; they fall back to the plateau at the very edge
	var de := minf(minf(x - X0, X1 - x), Z1 - z)
	if x - X0 < 2.0:
		de = 1e9                        # the west edge meets the valley's own boundary wall
	h += 26.0 * smoothstep(4.0, 16.0, de) * (1.0 - smoothstep(16.0, 40.0, de)) if de < 40.0 else 0.0
	h = lerpf(PLAIN, h, smoothstep(0.0, 4.0, de))
	# join the valley seam exactly
	var s := smoothstep(Z0, Z0 + 7.0, z)
	if s <= 0.0:
		return edge_y
	return lerpf(edge_y, h, s)


func generate() -> void:
	var w := NX + 1
	heights.resize(w * (NZ + 1))
	for j in NZ + 1:
		for i in w:
			heights[j * w + i] = height_at(X0 + i * CX, Z0 + j * CZ)


func sample_height(x: float, z: float) -> float:
	var fx := clampf((x - X0) / CX, 0.0, float(NX) - 0.001)
	var fz := clampf((z - Z0) / CZ, 0.0, float(NZ) - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - float(i)
	var tz := fz - float(j)
	var w := NX + 1
	var h00 := heights[j * w + i]
	var h10 := heights[j * w + i + 1]
	var h01 := heights[(j + 1) * w + i]
	var h11 := heights[(j + 1) * w + i + 1]
	# same triangle split as the mesh (a-b-c / b-d-c), so feet sit on the drawn surface
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func _color(p: Vector3, n: Vector3) -> Color:
	var t := clampf(_detail.get_noise_2d(p.x * 1.7, p.z * 1.7) * 0.5 + 0.5, 0.0, 1.0)
	var c := TerrainBuilder.SAND_A.lerp(TerrainBuilder.SAND_B, t)
	c = c.lerp(TerrainBuilder.CREAM, clampf((p.y - 33.0) / 10.0, 0.0, 1.0) * 0.4)
	c = c.lerp(TerrainBuilder.ROCK, smoothstep(0.2, 0.48, 1.0 - n.y))
	var rd := road_dist(p.x, p.z)
	if rd < 5.0:
		var rut := 0.5 + 0.5 * cos(rd * 2.4)          # two wheel ruts along the road
		var dirt := Color(0.52, 0.4, 0.28).lerp(Color(0.44, 0.33, 0.23), rut * (1.0 - smoothstep(2.5, 3.2, rd)))
		c = c.lerp(dirt, 1.0 - smoothstep(3.0, 5.0, rd))
	for cc in [SARAI_C, DHOOP_C]:
		var d := Vector2(p.x - cc.x, p.z - cc.y).length()
		if d < 30.0:
			c = c.lerp(Color(0.6, 0.48, 0.34), (1.0 - smoothstep(14.0, 30.0, d)) * 0.6)
	return c


func _normal(i: int, j: int) -> Vector3:
	var w := NX + 1
	var l := heights[j * w + maxi(i - 1, 0)]
	var r := heights[j * w + mini(i + 1, NX)]
	var u := heights[maxi(j - 1, 0) * w + i]
	var d := heights[mini(j + 1, NZ) * w + i]
	return Vector3((l - r) / (2.0 * CX), 1.0, (u - d) / (2.0 * CZ)).normalized()


## Ground mesh, collision and boundary walls. `terrain` provides the shared material and mesh helpers.
func build_ground(parent: Node3D, terrain: TerrainBuilder) -> void:
	material = terrain.material
	var root := Node3D.new()
	root.name = "Frontier"
	parent.add_child(root)
	var w := NX + 1
	for cz in NZ / CHUNK_Z:
		for cx in NX / CHUNK_X:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var n1 := CHUNK_X + 1
			for j in CHUNK_Z + 1:
				for i in n1:
					var gi := cx * CHUNK_X + i
					var gj := cz * CHUNK_Z + j
					var p := Vector3(X0 + gi * CX, heights[gj * w + gi], Z0 + gj * CZ)
					var nrm := _normal(gi, gj)
					verts.append(p)
					norms.append(nrm)
					cols.append(_color(p, nrm))
			for j in CHUNK_Z:
				for i in CHUNK_X:
					var a := j * n1 + i
					var b := a + 1
					var c := a + n1
					var d := c + 1
					idx.append_array([a, b, c, b, d, c])
			var mesh := terrain._to_mesh(verts, norms, cols, idx)
			mesh.surface_set_material(0, material)
			var mi := MeshInstance3D.new()
			mi.name = "FrontierChunk_%d_%d" % [cx, cz]
			mi.mesh = mesh
			root.add_child(mi)
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = terrain._trimesh(verts, idx)
			body.add_child(cs)
			mi.add_child(body)
	# invisible walls along the east, south and west edges (the north edge is the valley)
	var walls := StaticBody3D.new()
	walls.name = "FrontierBoundary"
	root.add_child(walls)
	var th := 4.0
	for spec in [
		[Vector3(X1 - 8.0 + th * 0.5, 100.0, (Z0 + Z1) * 0.5), Vector3(th, 400.0, Z1 - Z0)],
		[Vector3(X0 + 8.0 - th * 0.5, 100.0, (Z0 + Z1) * 0.5 + 4.0), Vector3(th, 400.0, Z1 - Z0 - 8.0)],
		[Vector3((X0 + X1) * 0.5, 100.0, Z1 - 8.0 + th * 0.5), Vector3(X1 - X0, 400.0, th)],
	]:
		var cs2 := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[1]
		cs2.shape = bs
		cs2.position = spec[0]
		walls.add_child(cs2)


func _g(x: float, z: float, up: float = 0.0) -> Vector3:
	return Vector3(x, sample_height(x, z) + up, z)


## Buildings, road dressing, people and rideable animals. Call after build_ground.
func build_places(parent: Node3D, terrain: TerrainBuilder, player: Node3D) -> void:
	var root := Node3D.new()
	root.name = "FrontierPlaces"
	parent.add_child(root)
	_milestones(root)
	_sarai(root)
	_dhoopgarh(root)
	_road_dressing(root)
	# people
	var people := [
		["merchant", "SaraiKeeper", _g(SARAI_C.x + 4.0, SARAI_C.y - 2.0), 1.4],
		["trader", "CamelDriver", _g(SARAI_C.x - 7.0, SARAI_C.y + 6.0), 3.0],
		["huntress", "Pilgrim", _g(SARAI_C.x + 2.0, SARAI_C.y + 7.0), -2.2],
		["chief", "Headman", _g(DHOOP_C.x + 3.0, DHOOP_C.y - 3.0), 0.6],
		["lady_medieval", "DhoopWoman", _g(DHOOP_C.x - 6.0, DHOOP_C.y + 4.0), 2.4],
		["guard", "BorderGuard", _g(DHOOP_C.x + 1.0, DHOOP_C.y - 22.0), 0.0],
		["child_a", "DhoopChild", _g(DHOOP_C.x - 2.0, DHOOP_C.y + 8.0), 3.6],
		["shepherd", "RoadShepherd", _g(-2.0, 352.0), 1.0],
	]
	for p in people:
		if not NpcBuilder.PRESETS.has(p[0]):
			continue
		var n := Npc.new().setup(NpcBuilder.PRESETS[p[0]], "idle", p[1])
		n.player = player
		n.home_yaw = p[3]
		root.add_child(n)
		n.global_position = p[2]
		n.rotation.y = p[3]
		npcs.append(n)
	# rideable animals at the foot of the pass, the inn and the village; camels and goats along the way
	var beasts := [
		["horse", -36.0, 168.0, 2.0], ["horse_white", -44.0, 172.0, 2.0],
		["horse", SARAI_C.x - 14.0, SARAI_C.y - 8.0, 2.0], ["camel", SARAI_C.x - 13.0, SARAI_C.y + 4.0, 3.0],
		["camel", SARAI_C.x - 16.0, SARAI_C.y + 9.0, 3.0], ["donkey", DHOOP_C.x + 12.0, DHOOP_C.y - 12.0, 3.0],
		["horse", DHOOP_C.x - 14.0, DHOOP_C.y - 14.0, 2.0], ["deer", 60.0, 470.0, 25.0], ["fox", -120.0, 380.0, 25.0],
	]
	for b in beasts:
		var a := Animal.new().setup(b[0], terrain, player, Vector3.ZERO, b[3])
		root.add_child(a)
		var x: float = b[1]
		var z: float = b[2]
		a.home = Vector3(x, 0.0, z)
		a.global_position = Vector3(x, terrain.sample_height(x, z), z)
		a.rotation.y = randf() * TAU
		animals.append(a)


func _milestones(root: Node3D) -> void:
	var stone := PropFactory.stone(Color(0.7, 0.62, 0.5))
	var paint := PropFactory.material(Color(0.85, 0.3, 0.15))
	var total := 0.0
	var next_mark := 60.0
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		var seg := a.distance_to(b)
		while total + seg >= next_mark:
			var t := (next_mark - total) / seg
			var p := a.lerp(b, t)
			var side := (b - a).normalized().orthogonal() * 4.2
			var at := _g(p.x + side.x, p.y + side.y)
			PropFactory.box(root, Vector3(0.45, 0.9, 0.3), at + Vector3(0, 0.45, 0), stone, Vector3(0, rad_to_deg(atan2(side.x, side.y)), 0), true, true)
			PropFactory.box(root, Vector3(0.47, 0.2, 0.32), at + Vector3(0, 0.78, 0), paint, Vector3(0, rad_to_deg(atan2(side.x, side.y)), 0), false, false)
			next_mark += 60.0
		total += seg


## A mud-brick house with a flat roof, a dark doorway and a parapet; solid (not enterable).
func _house(root: Node3D, c: Vector3, size: Vector3, yaw_deg: float, wall: Material, trim: Material) -> void:
	var n := Node3D.new()
	root.add_child(n)
	n.global_position = c
	n.rotation_degrees.y = yaw_deg
	PropFactory.box(n, size, Vector3(0, size.y * 0.5 - 0.2, 0), wall)
	PropFactory.box(n, Vector3(size.x + 0.3, 0.25, size.z + 0.3), Vector3(0, size.y - 0.1, 0), trim, Vector3.ZERO, false, true)
	var dark := PropFactory.material(Color(0.12, 0.08, 0.06))
	PropFactory.box(n, Vector3(1.0, 1.9, 0.08), Vector3(0, 0.95 - 0.2, size.z * 0.5 + 0.02), dark, Vector3.ZERO, false, false)
	PropFactory.box(n, Vector3(0.6, 0.5, 0.06), Vector3(size.x * 0.28, 1.6, size.z * 0.5 + 0.02), dark, Vector3.ZERO, false, false)


func _sarai(root: Node3D) -> void:
	var wall := PropFactory.aged_wall(0.6, Color(0.86, 0.72, 0.55))
	var trim := PropFactory.sandstone_dark()
	var y := road_y(SARAI_C.y)
	var c := Vector3(SARAI_C.x, y, SARAI_C.y)
	var half := 13.0
	var wh := 3.6
	# courtyard walls with a gate on the west side facing the road
	PropFactory.box(root, Vector3(half * 2.0, wh, 0.8), c + Vector3(0, wh * 0.5 - 0.3, -half), wall)
	PropFactory.box(root, Vector3(half * 2.0, wh, 0.8), c + Vector3(0, wh * 0.5 - 0.3, half), wall)
	PropFactory.box(root, Vector3(0.8, wh, half * 2.0), c + Vector3(half, wh * 0.5 - 0.3, 0), wall)
	for sz in [-1.0, 1.0]:
		PropFactory.box(root, Vector3(0.8, wh, half - 2.5), c + Vector3(-half, wh * 0.5 - 0.3, sz * (half + 2.5) * 0.5), wall)
		PropFactory.box(root, Vector3(1.4, wh + 1.6, 1.4), c + Vector3(-half, (wh + 1.6) * 0.5 - 0.3, sz * 2.5), trim)
	PropFactory.box(root, Vector3(1.2, 0.8, 6.4), c + Vector3(-half, wh + 1.1, 0), trim, Vector3.ZERO, false, true)
	# rooms along the north and south walls
	for k in 3:
		var x := -7.0 + k * 7.0
		_house(root, c + Vector3(x, 0, -half + 2.6), Vector3(5.6, 3.0, 4.2), 0.0, wall, trim)
		_house(root, c + Vector3(x, 0, half - 2.6), Vector3(5.6, 3.0, 4.2), 180.0, wall, trim)
	# well, trough and an awning stall in the courtyard
	PropFactory.cylinder(root, 1.1, 1.2, 0.9, c + Vector3(2.0, 0.45, 0), PropFactory.sandstone(), Vector3.ZERO, true, 14)
	PropFactory.cylinder(root, 0.85, 0.85, 0.05, c + Vector3(2.0, 0.86, 0), PropFactory.material(Color(0.1, 0.16, 0.2), 0.2), Vector3.ZERO, false, 14, 0, false)
	PropFactory.box(root, Vector3(3.0, 0.5, 0.7), c + Vector3(-6.0, 0.25, -6.0), PropFactory.aged_wood(Color(0.5, 0.36, 0.22)))
	for px in [-1.4, 1.4]:
		for pz in [-1.0, 1.0]:
			PropFactory.cylinder(root, 0.06, 0.07, 2.4, c + Vector3(7.0 + px, 1.2, 4.0 + pz), PropFactory.wood(), Vector3.ZERO, false, 6, 0, false)
	PropFactory.box(root, Vector3(3.4, 0.06, 2.6), c + Vector3(7.0, 2.42, 4.0), PropFactory.cloth(Color(0.75, 0.2, 0.15)), Vector3(4, 0, 0), false, false)
	PropFactory.box(root, Vector3(2.6, 0.9, 1.4), c + Vector3(7.0, 0.45, 4.0), PropFactory.aged_wood(Color(0.55, 0.4, 0.25)))


func _dhoopgarh(root: Node3D) -> void:
	var wall := PropFactory.aged_wall(0.4, Color(0.78, 0.6, 0.45))
	var trim := PropFactory.mud_brick()
	var c := Vector3(DHOOP_C.x, road_y(DHOOP_C.y), DHOOP_C.y)
	for k in 8:
		var a := TAU * float(k) / 8.0 + 0.3
		if absf(wrapf(a - PI * 1.5, -PI, PI)) < 0.45:
			continue                    # keep the road entrance (north side) open
		var r := 17.0 + (k % 2) * 3.0
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = sample_height(p.x, p.z)
		_house(root, p, Vector3(5.0 + (k % 3), 3.0 + (k % 2) * 0.6, 4.4), rad_to_deg(atan2(-cos(a), -sin(a))), wall, trim)
	# watchtower by the road gate, a small shrine and a well
	var tp := c + Vector3(7.0, 0, -15.0)
	PropFactory.box(root, Vector3(3.2, 9.0, 3.2), tp + Vector3(0, 4.3, 0), PropFactory.sandstone())
	PropFactory.box(root, Vector3(4.0, 0.4, 4.0), tp + Vector3(0, 8.9, 0), PropFactory.sandstone_dark(), Vector3.ZERO, false, true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			PropFactory.box(root, Vector3(0.5, 0.9, 0.5), tp + Vector3(sx * 1.75, 9.5, sz * 1.75), PropFactory.sandstone_dark(), Vector3.ZERO, false, true)
	var sp := c + Vector3(-8.0, 0, 6.0)
	PropFactory.box(root, Vector3(3.0, 0.5, 3.0), sp + Vector3(0, 0.25, 0), PropFactory.sandstone_pale())
	PropFactory.box(root, Vector3(2.0, 2.4, 2.0), sp + Vector3(0, 1.7, 0), PropFactory.sandstone_pale())
	PropFactory.cylinder(root, 0.0, 1.3, 1.8, sp + Vector3(0, 3.8, 0), PropFactory.plaster(), Vector3.ZERO, false, 10)
	PropFactory.sphere(root, 0.15, sp + Vector3(0, 4.8, 0), PropFactory.glow_bronze())
	PropFactory.cylinder(root, 1.0, 1.1, 0.85, c + Vector3(3.0, 0.42, 3.0), PropFactory.sandstone(), Vector3.ZERO, true, 14)


func _road_dressing(root: Node3D) -> void:
	var rock := PropFactory.stone(Color(0.5, 0.38, 0.28))
	var wood := PropFactory.aged_wood(Color(0.35, 0.27, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 70:
		var x := rng.randf_range(X0 + 30.0, X1 - 25.0)
		var z := rng.randf_range(Z0 + 20.0, Z1 - 25.0)
		if road_dist(x, z) < 10.0 or Vector2(x, z).distance_to(SARAI_C) < 30.0 or Vector2(x, z).distance_to(DHOOP_C) < 36.0:
			continue
		var s := rng.randf_range(0.5, 1.8)
		PropFactory.rock(root, Vector3(s, s * 0.7, s * 1.1), _g(x, z, s * 0.2), rock, rng.randf() * 360.0)
	# dead thorn trees beside the road
	for i in 16:
		var t := rng.randf_range(0.05, 0.95)
		var k := int(t * float(ROAD.size() - 1))
		var p: Vector2 = ROAD[k].lerp(ROAD[k + 1], fmod(t * float(ROAD.size() - 1), 1.0))
		var side := (ROAD[k + 1] - ROAD[k]).normalized().orthogonal() * rng.randf_range(8.0, 14.0) * (1.0 if i % 2 == 0 else -1.0)
		var at := _g(p.x + side.x, p.y + side.y)
		var h := rng.randf_range(2.2, 3.6)
		PropFactory.cylinder(root, 0.08, 0.14, h, at + Vector3(0, h * 0.5, 0), wood, Vector3(0, 0, rng.randf_range(-8.0, 8.0)), true, 6)
		for b in 3:
			PropFactory.cylinder(root, 0.03, 0.06, 1.4, at + Vector3(0, h * (0.55 + 0.15 * b), 0), wood, Vector3(rng.randf_range(-50.0, 50.0), rng.randf() * 360.0, rng.randf_range(40.0, 70.0)), false, 5, 0, false)
