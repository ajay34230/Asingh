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
const CELL := 1.6
const N := 250                    # cells per side: HALF * 2 / CELL (denser mesh than before)
const CHUNKS := 5
const CHUNK_CELLS := 50           # N / CHUNKS
const EDGE_Y := 32.0              # terrain border is forced to this height (skirt meets it)
const RIM_HEIGHT := 22.0
const FORECOURT := Vector2(0.0, -138.0)
const START_MOUND := Vector2(120.0, 160.0)
## Ground is levelled around these points so houses can be built on them.
const HOUSE_SITES: Array[Vector2] = [
	Vector2(-75.0, 10.0), Vector2(-102.0, -18.0), Vector2(-64.0, -38.0),
	Vector2(-98.0, 38.0), Vector2(-128.0, 8.0),
	Vector2(92.0, 150.0),
]
## Village pond: the ground is levelled around it and a basin is carved; water sits just below the rim.
const POND_C := Vector2(-60.0, 52.0)
const POND_R := 16.0
## The village temple stands on levelled ground here.
const TEMPLE_C := Vector2(-35.0, -10.0)
const SITE_FLAT_RADIUS := 13.0
const SITE_BLEND_RADIUS := 24.0

const SAND_A := Color(0.76, 0.63, 0.45)
const SAND_B := Color(0.68, 0.52, 0.34)
const CREAM := Color(0.82, 0.72, 0.55)
const ROCK := Color(0.46, 0.33, 0.24)
const GRAVEL := Color(0.56, 0.50, 0.42)
const MOUNTAIN_LOW := Color(0.40, 0.26, 0.21)
const MOUNTAIN_HIGH := Color(0.50, 0.36, 0.30)

var heights := PackedFloat32Array()
var material: StandardMaterial3D

var _dunes := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _mountain := FastNoiseLite.new()
var _site_y := PackedFloat32Array()
var pond_level := 0.0
var temple_y := 0.0
var _pond_ready := false


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

	var acc := 0.0
	for k in 8:
		var a := TAU * k / 8.0
		acc += _ground_base(POND_C.x + cos(a) * 38.0, POND_C.y + sin(a) * 38.0)
	pond_level = acc / 8.0
	_pond_ready = true
	temple_y = _ground_base(TEMPLE_C.x, TEMPLE_C.y)
	for s in HOUSE_SITES:
		_site_y.append(_ground_base(s.x, s.y))


## Centre line of the dry riverbed. It meets x = 0 at the entrance forecourt.
func river_x(z: float) -> float:
	return 80.0 * sin((z + 138.0) / 65.0)


## Height of the ground at a world position (formula, used to fill the height grid).
func height_at(x: float, z: float) -> float:
	var h := _ground_base(x, z)

	# Level ground under each house site.
	for i in HOUSE_SITES.size():
		var ds_ := Vector2(x - HOUSE_SITES[i].x, z - HOUSE_SITES[i].y).length()
		h = lerpf(_site_y[i], h, smoothstep(SITE_FLAT_RADIUS, SITE_BLEND_RADIUS, ds_))

	# Level ground for the temple.
	h = lerpf(temple_y, h, smoothstep(17.0, 32.0, Vector2(x - TEMPLE_C.x, z - TEMPLE_C.y).length()))

	# Railway cutting/embankment: a level strip along the goods line that fades out at both ends.
	var rail_w := (1.0 - smoothstep(6.0, 18.0, absf(z - 96.0))) * (1.0 - smoothstep(105.0, 150.0, absf(x)))
	h = lerpf(h, 2.0, rail_w)

	# Enclosing rim on the east, west and south sides (not the north: the cliff covers that
	# side, and a rim there would bury the entrance platform), then the steep north cliff.
	var edge := maxf(absf(x), absf(z))
	h += RIM_HEIGHT * smoothstep(160.0, 195.0, maxf(absf(x), z))
	h += smoothstep(-174.5, -190.0, z) * (57.0 + _ridge.get_noise_2d(x, z) * 8.0)

	# Border is blended to a constant so the outer skirt joins without a seam.
	h = lerpf(h, EDGE_Y, smoothstep(190.0, 200.0, edge))
	return h


## Dunes, riverbed, start mound and entrance forecourt (everything except sites, rim, cliff).
func _ground_base(x: float, z: float) -> float:
	# Sharp-crested dunes: 1 - |noise| has a ridge line wherever the noise crosses zero.
	var dn := _dunes.get_noise_2d(x, z)
	var crest := 1.0 - absf(dn)
	var h := crest * crest * 22.0 + dn * 3.0 - 2.0
	h += _detail.get_noise_2d(x, z) * 1.6

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

	# Village pond: level the surroundings, then carve the basin.
	if _pond_ready:
		var dp := Vector2(x - POND_C.x, z - POND_C.y).length()
		h = lerpf(pond_level, h, smoothstep(30.0, 52.0, dp))
		h = lerpf(pond_level - 2.8, h, smoothstep(POND_R * 0.5, POND_R * 1.25, dp))
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
	m.normal_enabled = true
	m.normal_texture = PropFactory.sand_normal_texture()
	m.normal_scale = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.07, 0.07, 0.07)
	# Fine wind ripples and grain on a second, smaller-scale triplanar layer.
	var rip := PropFactory.sand_ripple_textures()
	m.detail_enabled = true
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = rip[0]
	m.detail_normal = rip[1]
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_triplanar_sharpness = 3.0
	m.uv2_scale = Vector3(0.3, 0.3, 0.3)
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
	# Green oasis grass around the pond, darker wet earth at the water's edge.
	var dp := Vector2(p.x - POND_C.x, p.z - POND_C.y).length()
	var grass := Color(0.36, 0.45, 0.20).lerp(Color(0.50, 0.52, 0.27), t)
	c = c.lerp(grass, (1.0 - smoothstep(POND_R * 1.1, 46.0, dp)) * 0.8 * clampf(1.0 - (1.0 - n.y) * 3.0, 0.0, 1.0))
	c = c.lerp(Color(0.30, 0.22, 0.14), 1.0 - smoothstep(POND_R * 0.8, POND_R * 1.3, dp))
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
			# Cheap baked ambient occlusion from the height grid: hollows darker, crests lighter.
			var lap := (heights[gj * w + maxi(gi - 1, 0)] + heights[gj * w + mini(gi + 1, N)]
				+ heights[maxi(gj - 1, 0) * w + gi] + heights[mini(gj + 1, N) * w + gi]) * 0.25 - p.y
			var ao := clampf(1.0 - lap * 0.10, 0.68, 1.08)
			var base_c := _color_at(p, nrm)
			cols.append(Color(base_c.r * ao, base_c.g * ao, base_c.b * ao))
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
