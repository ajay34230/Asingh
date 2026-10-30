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
void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * speed + wp.x * 0.7 + wp.z * 0.5) * amp * h;
	VERTEX.z += cos(TIME * speed * 0.8 + wp.z * 0.6) * amp * h * 0.6;
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
