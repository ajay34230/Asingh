class_name TreeFactory
extends RefCounted
## Realistic procedural trees and bushes (own work, no imported assets). Each tree grows recursively
## (trunk, forking limbs, twigs) with a bark texture, and carries hundreds of alpha-cut leaf cards drawn
## from a procedurally painted leaf-spray texture. Leaf normals point away from the crown centre so the
## canopy shades like a soft sphere. Foliage sways in the wind through the same global wind value as grass.

const LEAF_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float amp = 0.06;
uniform float speed = 1.6;
global uniform float wind_strength;
void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float w = 0.35 + wind_strength;
	float ph = wp.x * 0.7 + wp.z * 0.5 + VERTEX.x * 0.9;
	VERTEX.x += sin(TIME * speed * (0.8 + 0.5 * w) + ph) * amp * h * 0.18 * w;
	VERTEX.z += cos(TIME * speed * 0.9 + ph * 1.3) * amp * h * 0.14 * w;
	VERTEX.y += sin(TIME * speed * 2.1 + ph * 2.0) * amp * 0.12 * w;
}
void fragment() {
	vec4 t = texture(leaf_tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.78;
	BACKLIGHT = ALBEDO * 0.45;
}
"""

const KINDS := {
	# trunk length, trunk radius, depth, children, spread (rad), length decay, taper, upward bias, cluster size, cards per cluster, flatten, leaf colour, bark tint
	"neem": {"len": 2.3, "r": 0.26, "depth": 3, "kids": 3, "spread": 0.75, "decay": 0.74, "taper": 0.58, "up": 0.28, "cluster": 1.75, "cards": 7, "flat": 0.85, "leaf": Color(0.30, 0.46, 0.14), "bark": Color(0.55, 0.45, 0.36)},
	"acacia": {"len": 2.7, "r": 0.24, "depth": 2, "kids": 3, "spread": 1.05, "decay": 0.9, "taper": 0.6, "up": 0.05, "cluster": 2.1, "cards": 8, "flat": 0.45, "leaf": Color(0.38, 0.46, 0.15), "bark": Color(0.45, 0.36, 0.28)},
	"sal": {"len": 5.2, "r": 0.24, "depth": 3, "kids": 3, "spread": 0.55, "decay": 0.72, "taper": 0.6, "up": 0.55, "cluster": 1.55, "cards": 7, "flat": 1.2, "leaf": Color(0.16, 0.34, 0.12), "bark": Color(0.40, 0.33, 0.28)},
	"dead": {"len": 2.4, "r": 0.2, "depth": 3, "kids": 2, "spread": 0.8, "decay": 0.72, "taper": 0.55, "up": 0.3, "cluster": 0.0, "cards": 0, "flat": 1.0, "leaf": Color(0.4, 0.4, 0.3), "bark": Color(0.72, 0.66, 0.58)},
}

static var _leaf_mats := {}
static var _bark_mat: StandardMaterial3D
static var _bark_dead_mat: StandardMaterial3D
static var _meshes := {}


# --- textures and materials ---------------------------------------------------------------------

static func _leaf_texture(base: Color, seed_value: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sz := 128
	var img := Image.create(sz, sz, true, Image.FORMAT_RGBA8)
	img.fill(Color(base.r, base.g, base.b, 0.0))     # transparent, but with the right colour so mip edges do not halo
	for i in 62:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 54.0
		var c := Vector2(64.0 + cos(a) * d, 64.0 + sin(a) * d)
		var th := rng.randf() * TAU
		var L := rng.randf_range(11.0, 19.0)
		var W := rng.randf_range(4.5, 7.5)
		var v := rng.randf_range(0.7, 1.15)
		var tint := Color(base.r * v * rng.randf_range(0.92, 1.08), base.g * v, base.b * v * rng.randf_range(0.85, 1.1))
		var ca := cos(th)
		var sa := sin(th)
		for yy in range(int(c.y) - 20, int(c.y) + 21):
			for xx in range(int(c.x) - 20, int(c.x) + 21):
				if xx < 0 or yy < 0 or xx >= sz or yy >= sz:
					continue
				var dx := float(xx) - c.x
				var dy := float(yy) - c.y
				var u := dx * ca + dy * sa
				var w := -dx * sa + dy * ca
				if absf(u) > L:
					continue
				var prof := W * sin(PI * (u / L * 0.5 + 0.5))
				if absf(w) <= prof:
					var rib := 1.18 if absf(w) < 0.7 else 1.0
					var edge := 0.88 + 0.12 * (1.0 - absf(w) / maxf(prof, 0.1))
					img.set_pixel(xx, yy, Color(minf(1.0, tint.r * rib * edge), minf(1.0, tint.g * rib * edge), minf(1.0, tint.b * rib * edge), 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func leaf_material(kind: String) -> ShaderMaterial:
	if _leaf_mats.has(kind):
		return _leaf_mats[kind]
	var sh := Shader.new()
	sh.code = LEAF_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var base: Color = KINDS[kind]["leaf"]
	m.set_shader_parameter("leaf_tex", _leaf_texture(base, hash(kind)))
	m.set_shader_parameter("amp", 0.7 if kind != "sal" else 0.5)
	_leaf_mats[kind] = m
	return m


static func _bark_texture(base: Color) -> ImageTexture:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.09
	var fn2 := FastNoiseLite.new()
	fn2.frequency = 0.35
	fn2.seed = 9
	var w := 64
	var h := 128
	var img := Image.create(w, h, true, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var n := fn.get_noise_2d(x * 3.0, y * 0.35) * 0.5 + 0.5          # long vertical streaks
			var g := fn2.get_noise_2d(x * 2.0, y * 0.5)
			var groove := 0.65 if g > 0.45 else 1.0
			var v := (0.55 + 0.6 * n) * groove
			img.set_pixel(x, y, Color(base.r * v, base.g * v, base.b * v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func bark_material(dead: bool) -> StandardMaterial3D:
	if dead and _bark_dead_mat != null:
		return _bark_dead_mat
	if not dead and _bark_mat != null:
		return _bark_mat
	var m := StandardMaterial3D.new()
	m.albedo_texture = _bark_texture(Color(0.72, 0.66, 0.58) if dead else Color(0.48, 0.38, 0.30))
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if dead:
		_bark_dead_mat = m
	else:
		_bark_mat = m
	return m


# --- geometry -----------------------------------------------------------------------------------

static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, col: Color, seg: int, v0: float) -> float:
	var axis := (b - a).normalized()
	var up := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var s1 := axis.cross(up).normalized()
	var s2 := axis.cross(s1).normalized()
	var v1 := v0 + (b - a).length() * 0.6
	for i in seg:
		var t0 := TAU * float(i) / seg
		var t1 := TAU * float(i + 1) / seg
		var n0 := s1 * cos(t0) + s2 * sin(t0)
		var n1 := s1 * cos(t1) + s2 * sin(t1)
		var u0 := float(i) / seg * 2.0
		var u1 := float(i + 1) / seg * 2.0
		var pts := [[a + n0 * ra, n0, Vector2(u0, v0)], [b + n0 * rb, n0, Vector2(u0, v1)], [a + n1 * ra, n1, Vector2(u1, v0)],
			[a + n1 * ra, n1, Vector2(u1, v0)], [b + n0 * rb, n0, Vector2(u0, v1)], [b + n1 * rb, n1, Vector2(u1, v1)]]
		for p in pts:
			st.set_color(col)
			st.set_normal(p[1])
			st.set_uv(p[2])
			st.add_vertex(p[0])
	return v1


static func _grow(ctx: Dictionary, p0: Vector3, dir: Vector3, length: float, r0: float, depth: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var p: Dictionary = ctx["p"]
	var jit := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.5), rng.randf_range(-1, 1)) * 0.22
	var d2 := (dir + jit).normalized()
	var mid := p0 + dir * length * 0.5
	var p1 := mid + d2 * length * 0.5
	var r1 := r0 * float(p["taper"])
	var seg := 8 if depth == 0 else (6 if depth == 1 else 4)
	var bark: Color = ctx["bark"]
	var shade := 0.8 + 0.2 * float(depth) / maxf(1.0, float(p["depth"]))
	var col := Color(bark.r * shade, bark.g * shade, bark.b * shade)
	var vv := _limb(ctx["st"], p0, mid, r0, lerpf(r0, r1, 0.5), col, seg, float(ctx["v"]) * 0.0 + rng.randf())
	_limb(ctx["st"], mid, p1, lerpf(r0, r1, 0.5), r1, col, seg, vv)
	if depth >= int(p["depth"]):
		if float(p["cluster"]) > 0.0:
			(ctx["clusters"] as Array).append([p1, float(p["cluster"])])
		return
	if depth >= 1 and float(p["cluster"]) > 0.0 and rng.randf() < 0.55:
		(ctx["clusters"] as Array).append([mid + d2 * length * 0.1, float(p["cluster"]) * 0.7])
	var nb := int(p["kids"]) + (1 if depth == 0 and rng.randf() < 0.5 else 0)
	var az0 := rng.randf() * TAU
	var u := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := dir.cross(u).normalized()
	for i in nb:
		var az := az0 + TAU * float(i) / nb + rng.randf_range(-0.4, 0.4)
		var pol := float(p["spread"]) * rng.randf_range(0.75, 1.25)
		var cd := (d2 * cos(pol) + (u * cos(az) + v * sin(az)) * sin(pol))
		cd.y += float(p["up"]) * 0.5
		cd = cd.normalized()
		_grow(ctx, p1, cd, length * float(p["decay"]) * rng.randf_range(0.85, 1.1), r1 * 0.92, depth + 1)


static func _cards(st: SurfaceTool, clusters: Array, p: Dictionary, rng: RandomNumberGenerator, tint: Color) -> void:
	if clusters.is_empty():
		return
	var centre := Vector3.ZERO
	for c in clusters:
		centre += (c[0] as Vector3)
	centre /= clusters.size()
	var flat: float = p["flat"]
	for c in clusters:
		var cp: Vector3 = c[0]
		var size: float = c[1]
		for k in int(p["cards"]):
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1) * flat * 0.7, rng.randf_range(-1, 1)).limit_length(1.0) * size * 0.5
			var pos := cp + off
			var n := Basis.from_euler(Vector3(rng.randf() * PI, rng.randf() * TAU, rng.randf() * PI))
			var hx := n.x * size * rng.randf_range(0.5, 0.75)
			var hy := n.y * size * rng.randf_range(0.5, 0.75)
			var out := ((pos - centre) * Vector3(1.0, 0.7, 1.0)).normalized()
			var nrm := (out * 0.75 + Vector3.UP * 0.35).normalized()
			var v := rng.randf_range(0.78, 1.15)
			var col := Color(tint.r * v, tint.g * v, tint.b * v * rng.randf_range(0.9, 1.1))
			var corners := [pos - hx - hy, pos + hx - hy, pos + hx + hy, pos - hx + hy]
			var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(col)
				st.set_normal(nrm)
				st.set_uv(uvs[idx])
				st.add_vertex(corners[idx])


static func tree_mesh(kind: String, seed_value: int) -> ArrayMesh:
	var key := "%s_%d" % [kind, seed_value]
	if _meshes.has(key):
		return _meshes[key]
	var p: Dictionary = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + hash(kind)
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ctx := {"rng": rng, "p": p, "st": bark_st, "clusters": [], "bark": p["bark"], "v": 0.0}
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12)).normalized()
	_grow(ctx, Vector3.ZERO, lean, float(p["len"]), float(p["r"]), 0)
	# a flared root collar so the trunk does not just stab into the ground
	_limb(bark_st, Vector3(0, -0.15, 0), Vector3(0, 0.5, 0), float(p["r"]) * 1.35, float(p["r"]) * 1.05, Color(p["bark"]) * 0.85, 8, 0.0)
	var mesh := ArrayMesh.new()
	bark_st.commit(mesh)
	mesh.surface_set_material(0, bark_material(kind == "dead"))
	if (ctx["clusters"] as Array).size() > 0:
		var leaf_st := SurfaceTool.new()
		leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_cards(leaf_st, ctx["clusters"], p, rng, Color(1, 1, 1))
		leaf_st.commit(mesh)
		mesh.surface_set_material(1, leaf_material(kind))
	_meshes[key] = mesh
	return mesh


## A leafy shrub: a few woody stems and a dome of leaf cards.
static func bush_mesh(seed_value: int) -> ArrayMesh:
	var key := "bush_%d" % seed_value
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clusters: Array = []
	for i in 5:
		var a := TAU * float(i) / 5.0 + rng.randf_range(-0.3, 0.3)
		var tip := Vector3(cos(a) * rng.randf_range(0.25, 0.55), rng.randf_range(0.6, 1.0), sin(a) * rng.randf_range(0.25, 0.55))
		_limb(bark_st, Vector3(cos(a) * 0.05, 0.0, sin(a) * 0.05), tip, 0.035, 0.015, Color(0.40, 0.30, 0.22), 4, 0.0)
		clusters.append([tip * 0.92, 0.62])
		clusters.append([tip * 0.55 + Vector3(0, 0.1, 0), 0.55])
	var mesh := ArrayMesh.new()
	bark_st.commit(mesh)
	mesh.surface_set_material(0, bark_material(false))
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cards(leaf_st, clusters, {"flat": 0.8, "cards": 4}, rng, Color(1, 1, 1))
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_material("neem"))
	_meshes[key] = mesh
	return mesh


## Scatter a tree kind as three different grown variants so a grove does not look cloned.
static func scatter_trees(parent: Node3D, kind: String, xforms: Array[Transform3D], nm: String, group: String, cell: float = 60.0) -> void:
	for v in 3:
		var part: Array[Transform3D] = []
		for i in xforms.size():
			if i % 3 == v:
				part.append(xforms[i])
		if part.is_empty():
			continue
		Flora.scatter_cells(parent, tree_mesh(kind, v + 1), null, part, "%s%d" % [nm, v], group, cell)


static func scatter_bushes(parent: Node3D, xforms: Array[Transform3D], nm: String, group: String, cell: float = 30.0) -> void:
	for v in 2:
		var part: Array[Transform3D] = []
		for i in xforms.size():
			if i % 2 == v:
				part.append(xforms[i])
		if part.is_empty():
			continue
		Flora.scatter_cells(parent, bush_mesh(v + 1), null, part, "%s%d" % [nm, v], group, cell)
