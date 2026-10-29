class_name TerrainBuilder
extends RefCounted
## Procedural desert valley (about 400 x 400 m) plus a flat outer skirt and a ring of
## distant mountain silhouettes. Everything is generated from noise in code: no imported
## assets and no large textures, which keeps the memory cost low on a phone.
##
## Coordinate notes: X/Z are the ground plane, Y is up, units are metres.
## The ancient entrance sits at the north end (negative Z); the player starts on a
## raised viewpoint in the south-east (positive X and Z).

const HALF := 200.0
const CELL := 2.0
const N := 200                    # cells per side: HALF * 2 / CELL
const CHUNKS := 5
const CHUNK_CELLS := 40           # N / CHUNKS
const EDGE_Y := 32.0              # terrain border is forced to this height (skirt meets it)
const RIM_HEIGHT := 22.0
const FORECOURT := Vector2(0.0, -138.0)
const START_MOUND := Vector2(120.0, 160.0)

const SAND_A := Color(0.80, 0.64, 0.38)
const SAND_B := Color(0.70, 0.50, 0.27)
const CREAM := Color(0.84, 0.72, 0.50)
const ROCK := Color(0.47, 0.30, 0.19)
const GRAVEL := Color(0.58, 0.49, 0.37)
const MOUNTAIN_LOW := Color(0.40, 0.26, 0.21)
const MOUNTAIN_HIGH := Color(0.50, 0.36, 0.30)

var heights := PackedFloat32Array()
var material: StandardMaterial3D

var _dunes := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _mountain := FastNoiseLite.new()


func _init(seed_value: int = 1337) -> void:
	_dunes.seed = seed_value
	_dunes.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_dunes.frequency = 0.006
	_dunes.fractal_octaves = 3

	_detail.seed = seed_value + 11
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.035
	_detail.fractal_octaves = 2

	_ridge.seed = seed_value + 23
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.012
	_ridge.fractal_octaves = 3

	_mountain.seed = seed_value + 37
	_mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain.frequency = 0.0035
	_mountain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain.fractal_octaves = 4


## Centre line of the dry riverbed. It meets x = 0 at the entrance forecourt.
func river_x(z: float) -> float:
	return 80.0 * sin((z + 138.0) / 65.0)


## Height of the ground at a world position (formula, used to fill the height grid).
func height_at(x: float, z: float) -> float:
	var h := _dunes.get_noise_2d(x, z) * 16.0 + 8.0
	h += _detail.get_noise_2d(x, z) * 2.2

	# Dry riverbed: a wide, shallow channel that winds towards the entrance.
	var d := absf(x - river_x(z))
	var bank := smoothstep(14.0, 38.0, d)
	var bed := -1.5 + _detail.get_noise_2d(x * 2.0, z * 2.0) * 0.4
	h = lerpf(bed, h, bank)

	# Raised viewpoint where the player starts.
	var ds := Vector2(x - START_MOUND.x, z - START_MOUND.y).length()
	h += 14.0 * (1.0 - smoothstep(0.0, 45.0, ds))

	# Flat forecourt in front of the entrance.
	var df := Vector2(x - FORECOURT.x, z - FORECOURT.y).length()
	h = lerpf(0.0, h, smoothstep(26.0, 60.0, df))

	# Enclosing rim on the east, west and south sides (not the north: the cliff covers that
	# side, and a rim there would bury the entrance platform), then the steep north cliff.
	var edge := maxf(absf(x), absf(z))
	h += RIM_HEIGHT * smoothstep(160.0, 195.0, maxf(absf(x), z))
	h += smoothstep(-174.5, -190.0, z) * (57.0 + _ridge.get_noise_2d(x, z) * 8.0)

	# Border is blended to a constant so the outer skirt joins without a seam.
	h = lerpf(h, EDGE_Y, smoothstep(190.0, 200.0, edge))
	return h


## Bilinear sample of the baked height grid (matches the rendered mesh exactly).
func sample_height(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / CELL, 0.0, float(N) - 0.001)
	var fz := clampf((z + HALF) / CELL, 0.0, float(N) - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - float(i)
	var tz := fz - float(j)
	var w := N + 1
	var h00 := heights[j * w + i]
	var h10 := heights[j * w + i + 1]
	var h01 := heights[(j + 1) * w + i]
	var h11 := heights[(j + 1) * w + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func generate_heights() -> void:
	var w := N + 1
	heights.resize(w * w)
	for j in w:
		for i in w:
			heights[j * w + i] = height_at(-HALF + i * CELL, -HALF + j * CELL)


func build(parent: Node3D) -> void:
	if heights.is_empty():
		generate_heights()
	material = _make_material()

	var terrain := Node3D.new()
	terrain.name = "Terrain"
	parent.add_child(terrain)
	for cz in CHUNKS:
		for cx in CHUNKS:
			var arr := _chunk_arrays(cx, cz)
			var mesh := _to_mesh(arr[0], arr[1], arr[2], arr[3])
			mesh.surface_set_material(0, material)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cz]
			mi.mesh = mesh
			terrain.add_child(mi)
			# Collision is built from the same arrays (not read back from the mesh) so it
			# also works under the headless/dummy renderer used by automated tests.
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = _trimesh(arr[0], arr[3])
			body.add_child(cs)
			mi.add_child(body)

	_build_boundary(terrain)
	_build_skirt(terrain)
	_build_mountains(terrain)


func _make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic_specular = 0.12
	# Small tiling noise texture, applied triplanar, adds fine grain to the sand.
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.05
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.70, 0.70, 0.70), Color(1.0, 1.0, 1.0)])
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := NoiseTexture2D.new()
	tex.noise = fn
	tex.color_ramp = ramp
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.07, 0.07, 0.07)
	return m


func _normal_at(gi: int, gj: int) -> Vector3:
	var w := N + 1
	var l := heights[gj * w + maxi(gi - 1, 0)]
	var r := heights[gj * w + mini(gi + 1, N)]
	var u := heights[maxi(gj - 1, 0) * w + gi]
	var d := heights[mini(gj + 1, N) * w + gi]
	return Vector3(l - r, 2.0 * CELL, u - d).normalized()


func _color_at(p: Vector3, n: Vector3) -> Color:
	var t := clampf(_detail.get_noise_2d(p.x * 1.7, p.z * 1.7) * 0.5 + 0.5, 0.0, 1.0)
	var c := SAND_A.lerp(SAND_B, t)
	c = c.lerp(CREAM, clampf((p.y - 14.0) / 22.0, 0.0, 1.0) * 0.45)
	c = c.lerp(ROCK, smoothstep(0.22, 0.5, 1.0 - n.y))
	var rv := absf(p.x - river_x(p.z))
	c = c.lerp(GRAVEL, 1.0 - smoothstep(6.0, 20.0, rv))
	return c


func _trimesh(verts: PackedVector3Array, idx: PackedInt32Array) -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for k in idx.size():
		faces[k] = verts[idx[k]]
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape


## Returns [vertices, normals, colors, indices] for one terrain chunk.
func _chunk_arrays(cx: int, cz: int) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var n1 := CHUNK_CELLS + 1
	var w := N + 1
	for j in n1:
		for i in n1:
			var gi := cx * CHUNK_CELLS + i
			var gj := cz * CHUNK_CELLS + j
			var p := Vector3(-HALF + gi * CELL, heights[gj * w + gi], -HALF + gj * CELL)
			var nrm := _normal_at(gi, gj)
			verts.append(p)
			norms.append(nrm)
			cols.append(_color_at(p, nrm))
	for j in CHUNK_CELLS:
		for i in CHUNK_CELLS:
			var a := j * n1 + i
			var b := a + 1
			var c := a + n1
			var d := c + 1
			# Clockwise when seen from above, which is Godot's front-face winding.
			idx.append_array([a, b, c, b, d, c])
	return [verts, norms, cols, idx]


func _to_mesh(verts: PackedVector3Array, norms: PackedVector3Array,
		cols: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Invisible walls so the player cannot walk off the edge of the valley.
func _build_boundary(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	parent.add_child(body)
	var thickness := 4.0
	var span := HALF * 2.0 + thickness * 2.0
	var specs := [
		[Vector3(0.0, 100.0, -HALF - thickness * 0.5), Vector3(span, 400.0, thickness)],
		[Vector3(0.0, 100.0, HALF + thickness * 0.5), Vector3(span, 400.0, thickness)],
		[Vector3(-HALF - thickness * 0.5, 100.0, 0.0), Vector3(thickness, 400.0, span)],
		[Vector3(HALF + thickness * 0.5, 100.0, 0.0), Vector3(thickness, 400.0, span)],
	]
	for s in specs:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = s[1]
		cs.shape = shape
		cs.position = s[0]
		body.add_child(cs)


## Flat sand plain that surrounds the valley out to the horizon.
func _build_skirt(parent: Node3D) -> void:
	var outer := 1800.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var rects := [
		Rect2(Vector2(-outer, -outer), Vector2(outer * 2.0, outer - HALF)),
		Rect2(Vector2(-outer, HALF), Vector2(outer * 2.0, outer - HALF)),
		Rect2(Vector2(-outer, -HALF), Vector2(outer - HALF, HALF * 2.0)),
		Rect2(Vector2(HALF, -HALF), Vector2(outer - HALF, HALF * 2.0)),
	]
	for r in rects:
		var base := verts.size()
		var x0: float = r.position.x
		var z0: float = r.position.y
		var x1: float = r.end.x
		var z1: float = r.end.y
		for corner in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
			verts.append(Vector3(corner.x, EDGE_Y, corner.y))
			norms.append(Vector3.UP)
			cols.append(SAND_B.lerp(CREAM, 0.25))
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var mi := MeshInstance3D.new()
	mi.name = "Skirt"
	mi.mesh = _to_mesh(verts, norms, cols, idx)
	mi.mesh.surface_set_material(0, material)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _mountain_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var ang := atan2(z, x)
	var profile := exp(-pow((r - 860.0) / 170.0, 2.0))
	var n := _mountain.get_noise_2d(cos(ang) * 900.0, sin(ang) * 900.0)
	var peak := 90.0 + 260.0 * clampf(n * 0.5 + 0.55, 0.0, 1.0)
	var rough := 0.75 + 0.25 * _dunes.get_noise_2d(x * 0.5, z * 0.5)
	return maxf(0.0, peak * profile * rough - 25.0)


## Low-poly ring of mountains. Not walkable: purely a silhouette for depth.
func _build_mountains(parent: Node3D) -> void:
	var steps_a := 192
	var steps_r := 14
	var r_in := 520.0
	var r_out := 1200.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for ri in steps_r + 1:
		var r := lerpf(r_in, r_out, float(ri) / float(steps_r))
		for ai in steps_a:
			var ang := TAU * float(ai) / float(steps_a)
			var x := cos(ang) * r
			var z := sin(ang) * r
			var h := _mountain_height(x, z)
			verts.append(Vector3(x, EDGE_Y + 0.3 + h, z))
			var e := 12.0
			var nrm := Vector3(
				_mountain_height(x - e, z) - _mountain_height(x + e, z),
				2.0 * e,
				_mountain_height(x, z - e) - _mountain_height(x, z + e)).normalized()
			norms.append(nrm)
			cols.append(MOUNTAIN_LOW.lerp(MOUNTAIN_HIGH, clampf(h / 260.0, 0.0, 1.0)))
	for ri in steps_r:
		for ai in steps_a:
			var a := ri * steps_a + ai
			var b := ri * steps_a + (ai + 1) % steps_a
			var c := (ri + 1) * steps_a + ai
			var d := (ri + 1) * steps_a + (ai + 1) % steps_a
			# Ring is traversed counter-clockwise from above (angle grows towards +Z), so the
			# triangle order is flipped relative to the terrain grid to keep faces pointing up.
			idx.append_array([a, c, b, b, c, d])
	var mi := MeshInstance3D.new()
	mi.name = "DistantMountains"
	mi.mesh = _to_mesh(verts, norms, cols, idx)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.mesh.surface_set_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
