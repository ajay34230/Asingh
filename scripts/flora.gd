class_name Flora
extends RefCounted
## Procedural plants: palm trees (curved trunk + drooping fronds), grass clumps and reeds. Meshes are
## built once from code (no imported assets) and scattered with MultiMesh, so hundreds of plants
## cost only a few draw calls. A tiny vertex shader sways them in the wind.

const SWAY_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float amp = 0.1;
uniform float speed = 1.4;
global uniform float wind_strength;
void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float w = 0.45 + wind_strength;
	VERTEX.x += sin(TIME * speed * (0.8 + 0.5 * w) + wp.x * 0.7 + wp.z * 0.5) * amp * h * w;
	VERTEX.z += cos(TIME * speed * 0.8 + wp.z * 0.6) * amp * h * 0.6 * w;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.85;
	BACKLIGHT = COLOR.rgb * 0.35;
}
"""

static var _mats := {}


static func sway_material(id: String, amp: float, speed: float = 1.4) -> ShaderMaterial:
	if _mats.has(id):
		return _mats[id]
	var sh := Shader.new()
	sh.code = SWAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("speed", speed)
	_mats[id] = m
	return m


## A palm tree about 7 m tall: bent trunk with growth rings and a crown of 12 drooping fronds.
static func palm_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 14
	var seg := 10
	var height := 7.0
	var bend := 1.5
	var prev: Array[Vector3] = []
	var prev_n: Array[Vector3] = []
	var top := Vector3.ZERO
	for r in rings + 1:
		var t := float(r) / rings
		var c := Vector3(bend * t * t, height * t, 0.25 * sin(t * 2.0))
		var rad := lerpf(0.30, 0.15, t) + 0.07 * (1.0 - smoothstep(0.0, 0.2, t))
		var band := 0.78 + 0.22 * float(r % 2)
		var col := Color(0.42, 0.30, 0.19) * band
		var cur: Array[Vector3] = []
		var cur_n: Array[Vector3] = []
		for k in seg + 1:
			var a := TAU * k / seg
			var nrm := Vector3(cos(a), 0.0, sin(a))
			cur.append(c + nrm * rad * (1.0 + 0.06 * sin(a * 3.0)))
			cur_n.append(nrm)
		if r > 0:
			for k in seg:
				var quad := [prev[k], prev[k + 1], cur[k], cur[k + 1]]
				var qn := [prev_n[k], prev_n[k + 1], cur_n[k], cur_n[k + 1]]
				for idx in [0, 2, 1, 1, 2, 3]:
					st.set_color(col)
					st.set_normal(qn[idx])
					st.add_vertex(quad[idx])
		prev = cur
		prev_n = cur_n
		top = c
	# Crown: coconut cluster and fronds.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in 12:
		var yaw := TAU * f / 12.0 + rng.randf_range(-0.15, 0.15)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var length := rng.randf_range(2.6, 3.4)
		var lift := rng.randf_range(0.5, 0.85)
		var pts_l: Array[Vector3] = []
		var pts_r: Array[Vector3] = []
		var cols: Array[Color] = []
		var segs := 8
		for s in segs + 1:
			var u := float(s) / segs
			var spine := top + dir * (u * length) + Vector3(0.0, length * (lift * u - 0.95 * u * u) + 0.25, 0.0)
			var w := 0.62 * pow(sin(PI * clampf(u * 0.92 + 0.04, 0.0, 1.0)), 0.7) + 0.02
			var fold := 0.12 * w
			pts_l.append(spine + side * w + Vector3(0.0, fold, 0.0) - Vector3(0.0, 0.25 * u * u, 0.0))
			pts_r.append(spine - side * w + Vector3(0.0, fold, 0.0) - Vector3(0.0, 0.25 * u * u, 0.0))
			cols.append(Color(0.10, 0.30, 0.08).lerp(Color(0.36, 0.55, 0.14), u))
		for s in segs:
			var nrm2 := Vector3(0.0, 1.0, 0.0)
			var tri := [pts_l[s], pts_r[s], pts_l[s + 1], pts_r[s], pts_r[s + 1], pts_l[s + 1]]
			var tc := [cols[s], cols[s], cols[s + 1], cols[s], cols[s + 1], cols[s + 1]]
			for i in 6:
				st.set_color(tc[i])
				st.set_normal(nrm2)
				st.add_vertex(tri[i])
	return st.commit()


## A tuft of `blades` grass blades, each bent a little, dark at the root and bright at the tip.
static func clump_mesh(blades: int, h_min: float, h_max: float, seed_value: int, tint: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for b in blades:
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var base := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
		var h := rng.randf_range(h_min, h_max)
		var lean := rng.randf_range(0.05, 0.28) * h
		var w := 0.035 * (h / maxf(h_min, 0.01)) * 0.6 + 0.02
		var c0 := tint * 0.45
		var c1 := tint * rng.randf_range(0.95, 1.25)
		var p0 := base - side * w
		var p1 := base + side * w
		var mid := base + dir * lean * 0.4 + Vector3(0, h * 0.55, 0)
		var tip := base + dir * lean + Vector3(0, h, 0)
		var n := Vector3.UP
		var tris := [[p0, c0], [p1, c0], [mid - side * w * 0.55, c0.lerp(c1, 0.6)],
			[p1, c0], [mid + side * w * 0.55, c0.lerp(c1, 0.6)], [mid - side * w * 0.55, c0.lerp(c1, 0.6)],
			[mid - side * w * 0.55, c0.lerp(c1, 0.6)], [mid + side * w * 0.55, c0.lerp(c1, 0.6)], [tip, c1]]
		for v in tris:
			st.set_color(v[1])
			st.set_normal(n)
			st.add_vertex(v[0])
	return st.commit()


static func scatter(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array[Transform3D], nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Like `scatter`, but splits the instances into square cells so each cell is its own MultiMesh.
## That lets the engine cull cells outside the view and hide far cells (`visibility_range_end`),
## which is how foliage density and view distance are controlled per graphics tier.
static func scatter_cells(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array[Transform3D],
		nm: String, group: String, cell: float = 40.0) -> void:
	var buckets := {}
	for t in xforms:
		var key := Vector2i(floori(t.origin.x / cell), floori(t.origin.z / cell))
		if not buckets.has(key):
			buckets[key] = [] as Array[Transform3D]
		buckets[key].append(t)
	for key in buckets:
		var centre := Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell)
		var local: Array[Transform3D] = []
		for t in buckets[key]:
			var lt: Transform3D = t
			lt.origin -= centre
			local.append(lt)
		var mi := scatter(parent, mesh, mat, local, "%s_%d_%d" % [nm, key.x, key.y])
		mi.position = centre
		mi.add_to_group(group)


## Appends a squashed sphere (a lumpy canopy / bush blob / flower head) to a SurfaceTool.
static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, segs: int = 8, rings: int = 5) -> void:
	for j in rings:
		var a0 := PI * float(j) / rings
		var a1 := PI * float(j + 1) / rings
		for i in segs:
			var b0 := TAU * float(i) / segs
			var b1 := TAU * float(i + 1) / segs
			var p00 := Vector3(sin(a0) * cos(b0), cos(a0), sin(a0) * sin(b0))
			var p01 := Vector3(sin(a0) * cos(b1), cos(a0), sin(a0) * sin(b1))
			var p10 := Vector3(sin(a1) * cos(b0), cos(a1), sin(a1) * sin(b0))
			var p11 := Vector3(sin(a1) * cos(b1), cos(a1), sin(a1) * sin(b1))
			for v in [p00, p10, p01, p01, p10, p11]:
				var vv: Vector3 = v
				var shade := 0.75 + 0.25 * clampf(vv.y * 0.5 + 0.5, 0.0, 1.0)
				st.set_color(Color(col.r * shade, col.g * shade, col.b * shade))
				st.set_normal(vv)
				st.add_vertex(c + vv * r)


## Tapered branch segment from a to b (used by trees).
static func _branch(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, col: Color, seg: int = 6) -> void:
	var axis := (b - a).normalized()
	var up := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var s1 := axis.cross(up).normalized()
	var s2 := axis.cross(s1).normalized()
	for i in seg:
		var t0 := TAU * float(i) / seg
		var t1 := TAU * float(i + 1) / seg
		var n0 := s1 * cos(t0) + s2 * sin(t0)
		var n1 := s1 * cos(t1) + s2 * sin(t1)
		var q := [[a + n0 * ra, n0], [b + n0 * rb, n0], [a + n1 * ra, n1], [a + n1 * ra, n1], [b + n0 * rb, n0], [b + n1 * rb, n1]]
		for v in q:
			st.set_color(col)
			st.set_normal(v[1])
			st.add_vertex(v[0])


## Flat-topped acacia: forked trunk and a wide umbrella of leafy blobs.
static func acacia_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.34, 0.25, 0.17)
	_branch(st, Vector3.ZERO, Vector3(0.3, 2.6, 0.0), 0.28, 0.18, bark, 8)
	_branch(st, Vector3(0.3, 2.6, 0.0), Vector3(-1.2, 4.2, 0.5), 0.17, 0.08, bark)
	_branch(st, Vector3(0.3, 2.6, 0.0), Vector3(1.8, 4.0, -0.4), 0.15, 0.08, bark)
	_branch(st, Vector3(0.3, 2.6, 0.0), Vector3(0.5, 4.5, 0.2), 0.12, 0.06, bark)
	var leaf := Color(0.30, 0.42, 0.14)
	_blob(st, Vector3(-1.2, 4.5, 0.5), Vector3(2.2, 0.7, 2.0), leaf, 9, 5)
	_blob(st, Vector3(1.8, 4.3, -0.4), Vector3(2.4, 0.7, 2.1), leaf * 1.1, 9, 5)
	_blob(st, Vector3(0.5, 4.8, 0.2), Vector3(2.0, 0.65, 1.8), leaf * 0.95, 9, 5)
	return st.commit()


static func dead_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.50, 0.44, 0.36)
	_branch(st, Vector3.ZERO, Vector3(0.2, 2.4, 0.1), 0.24, 0.13, wood, 7)
	_branch(st, Vector3(0.2, 2.4, 0.1), Vector3(-1.1, 3.6, 0.3), 0.11, 0.04, wood)
	_branch(st, Vector3(0.2, 2.4, 0.1), Vector3(1.2, 3.4, -0.3), 0.10, 0.04, wood)
	_branch(st, Vector3(0.1, 1.6, 0.0), Vector3(-0.9, 2.3, -0.5), 0.08, 0.03, wood)
	_branch(st, Vector3(0.2, 2.4, 0.1), Vector3(0.4, 3.9, 0.2), 0.09, 0.03, wood)
	return st.commit()


static func bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := Color(0.26, 0.38, 0.16)
	_blob(st, Vector3(0, 0.35, 0), Vector3(0.7, 0.45, 0.65), g, 8, 5)
	_blob(st, Vector3(0.5, 0.28, 0.2), Vector3(0.5, 0.35, 0.5), g * 1.15, 8, 4)
	_blob(st, Vector3(-0.45, 0.3, -0.15), Vector3(0.5, 0.38, 0.45), g * 0.9, 8, 4)
	return st.commit()


## Wildflowers: thin stems with coloured round heads.
static func flower_mesh(head: Color, seed_value: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 6:
		var base := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var h := rng.randf_range(0.35, 0.6)
		var tip := base + Vector3(rng.randf_range(-0.05, 0.05), h, rng.randf_range(-0.05, 0.05))
		_branch(st, base, tip, 0.012, 0.008, Color(0.22, 0.4, 0.14), 4)
		_blob(st, tip, Vector3(0.07, 0.05, 0.07), head, 6, 3)
	return st.commit()
