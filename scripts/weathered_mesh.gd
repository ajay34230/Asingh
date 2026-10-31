class_name WeatheredMesh
extends RefCounted
## Generates eroded-looking stone meshes (rounded boxes, tapered/fluted cylinders, rock
## blobs) in code. Meshes are unit-sized and cached, so hundreds of props share a handful of
## meshes; callers scale the MeshInstance3D to the size they need.
## Smooth normals come from SurfaceTool (coincident vertices share a smooth group).

static var _cache := {}
static var _noise: FastNoiseLite


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.fractal_octaves = 3
		_noise.seed = 5150
	return _noise


static func _disp(p: Vector3, variant: int, freq: float) -> float:
	return _n().get_noise_3d(p.x * freq + variant * 17.3, p.y * freq + variant * 9.1, p.z * freq - variant * 5.7)


static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


## Unit cube (-0.5..0.5) with softened edges and noise-eroded surfaces.
static func box(variant: int = 0, subdiv: int = 4, round_k: float = 0.18, amp: float = 0.012) -> ArrayMesh:
	var key := "box_%d_%d_%s_%s" % [variant, subdiv, round_k, amp]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.BACK, Vector3.LEFT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for ax in axes:
		var nrm: Vector3 = ax[0]
		var u: Vector3 = ax[1]
		var v: Vector3 = ax[2]
		var grid := []
		for j in subdiv + 1:
			for i in subdiv + 1:
				var p: Vector3 = nrm * 0.5 + u * (float(i) / subdiv - 0.5) + v * (float(j) / subdiv - 0.5)
				var m := maxf(absf(p.x), maxf(absf(p.y), absf(p.z)))
				p = p.lerp(p.normalized() * m, round_k)
				p += p.normalized() * _disp(p, variant, 2.2) * amp
				grid.append(p)
		var w := subdiv + 1
		for j in subdiv:
			for i in subdiv:
				var p00: Vector3 = grid[j * w + i]
				var p10: Vector3 = grid[j * w + i + 1]
				var p01: Vector3 = grid[(j + 1) * w + i]
				var p11: Vector3 = grid[(j + 1) * w + i + 1]
				# The three axes of each face are right-handed (u x v = nrm); Godot's front
				# face is clockwise, so triangles are emitted as (p00, p01, p10).
				for q in [p00, p01, p10, p10, p01, p11]:
					st.add_vertex(q)
	var mesh := _finish(st)
	_cache[key] = mesh
	return mesh


## Unit cylinder: height 1 (y -0.5..0.5), bottom radius 0.5 * bottom_ratio, top radius
## 0.5 * top_ratio. `flutes` adds vertical grooves (for columns).
static func cylinder(top_ratio: float = 1.0, bottom_ratio: float = 1.0, variant: int = 0,
		segs: int = 16, rings: int = 5, flutes: int = 0, amp: float = 0.012) -> ArrayMesh:
	top_ratio = snappedf(top_ratio, 0.05)
	bottom_ratio = snappedf(bottom_ratio, 0.05)
	var key := "cyl_%s_%s_%d_%d_%d_%d_%s" % [top_ratio, bottom_ratio, variant, segs, rings, flutes, amp]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var side_pts := []   # [rings+1][segs+1]
	for j in rings + 1:
		var y := float(j) / rings - 0.5
		var r0 := lerpf(bottom_ratio, top_ratio, float(j) / rings) * 0.5
		var row := []
		for i in segs + 1:
			var a := TAU * float(i % segs) / segs
			var r := r0
			if flutes > 0:
				r *= 1.0 - 0.035 * (0.5 + 0.5 * cos(a * flutes))
			var p := Vector3(cos(a) * r, y, sin(a) * r)
			p += Vector3(p.x, 0.0, p.z).normalized() * _disp(p, variant, 2.5) * amp
			row.append(p)
		side_pts.append(row)
	for j in rings:
		for i in segs:
			var p00: Vector3 = side_pts[j][i]
			var p10: Vector3 = side_pts[j][i + 1]
			var p01: Vector3 = side_pts[j + 1][i]
			var p11: Vector3 = side_pts[j + 1][i + 1]
			# Angle grows from +X towards +Z; this order is clockwise when seen from outside.
			for q in [p00, p10, p01, p10, p11, p01]:
				st.add_vertex(q)

	# Caps: fans around the centre, slightly domed with noise.
	for cap in [0, 1]:
		var y := -0.5 if cap == 0 else 0.5
		var r_cap := (bottom_ratio if cap == 0 else top_ratio) * 0.5
		var centre := Vector3(0.0, y, 0.0)
		for i in segs:
			var a0 := TAU * float(i) / segs
			var a1 := TAU * float(i + 1) / segs
			var e0 := Vector3(cos(a0) * r_cap, y, sin(a0) * r_cap)
			var e1 := Vector3(cos(a1) * r_cap, y, sin(a1) * r_cap)
			if cap == 1:
				for q in [centre, e1, e0]:
					st.add_vertex(q)
			else:
				for q in [centre, e0, e1]:
					st.add_vertex(q)
	var mesh := _finish(st)
	_cache[key] = mesh
	return mesh


## Roughly unit-radius rock (flattened underneath) with strong, faceted erosion.
static func rock(variant: int = 0, rings: int = 7, segs: int = 11, amp: float = 0.28) -> ArrayMesh:
	var key := "rock_%d_%d_%d_%s" % [variant, rings, segs, amp]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in rings + 1:
		var phi := PI * float(j) / rings          # 0 = top pole, PI = bottom pole
		var row := []
		for i in segs + 1:
			var th := TAU * float(i % segs) / segs
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var p := d * (1.0 + _disp(d, variant, 1.7) * amp + _disp(d, variant + 3, 5.5) * amp * 0.3)
			if p.y < 0.0:
				p.y *= 0.45
			row.append(p)
		pts.append(row)
	for j in rings:
		for i in segs:
			var p00: Vector3 = pts[j][i]
			var p10: Vector3 = pts[j][i + 1]
			var p01: Vector3 = pts[j + 1][i]
			var p11: Vector3 = pts[j + 1][i + 1]
			for q in [p00, p10, p01, p10, p11, p01]:
				st.add_vertex(q)
	var mesh := _finish(st)
	_cache[key] = mesh
	return mesh


## Returns the fraction (0..1) of triangles whose geometric normal agrees with the
## vertex normal that SurfaceTool generated. A value near 1.0 means winding is consistent.
static func winding_agreement(mesh: ArrayMesh) -> float:
	var arrays := mesh.surface_get_arrays(0)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return -1.0
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx = arrays[Mesh.ARRAY_INDEX]
	var tris := 0
	var good := 0
	var count: int = v.size() if idx == null else (idx as PackedInt32Array).size()
	for t in range(0, count - 2, 3):
		var ia: int = t if idx == null else idx[t]
		var ib: int = t + 1 if idx == null else idx[t + 1]
		var ic: int = t + 2 if idx == null else idx[t + 2]
		var geo := Plane(v[ia], v[ib], v[ic]).normal
		var avg := (n[ia] + n[ib] + n[ic])
		tris += 1
		if geo.dot(avg) >= 0.0:
			good += 1
	return float(good) / maxf(1.0, float(tris))
