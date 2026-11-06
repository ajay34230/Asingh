class_name FurLook
extends RefCounted
## Makes the low-poly animals look like animals:
## 1. Smooth meshes: the faceted models get smooth normals averaged across shared corners (across
##    material seams too), so bodies read as rounded flesh instead of flat panels. Cached per mesh.
## 2. Real-looking surfaces: coat noise + a fine hair normal map on the fur, wet glossy eyes and nose,
##    waxy hooves and horns.
## 3. Fur: shell fur (a few slightly inflated copies of the coat drawn with strand-shaped holes), long and
##    soft on dogs, foxes and camels, short and sleek on horses, cattle and deer. Shells are only drawn close
##    to the camera (set_near) and are skipped on the Low preset.

const SHELLS := 5
## species -> [fur length (m), strand spacing (m), droop]
const COAT := {
	"dog": [0.03, 0.0034, 0.5], "shiba": [0.025, 0.0032, 0.4], "fox": [0.028, 0.0032, 0.45], "camel": [0.035, 0.0042, 0.55],
	"horse": [0.007, 0.0018, 0.1], "horse_white": [0.007, 0.0018, 0.1], "donkey": [0.012, 0.0024, 0.2],
	"cow": [0.008, 0.0018, 0.12], "bull": [0.007, 0.0018, 0.1], "deer": [0.01, 0.002, 0.15], "stag": [0.013, 0.0024, 0.18],
}
const FUR_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.5, 0.4, 0.3, 1.0);
uniform float layer = 0.2;
uniform float fur_len = 0.02;
uniform float density = 100.0;
uniform float droop = 0.2;
varying vec3 obj;
varying vec3 onrm;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	obj = VERTEX;
	onrm = NORMAL;
	VERTEX += NORMAL * fur_len * layer;
	VERTEX.y -= fur_len * layer * layer * droop;
}
void fragment() {
	vec3 an = abs(onrm);
	vec3 q = obj * density;
	vec2 uv = (an.x > an.y && an.x > an.z) ? q.yz : ((an.y > an.z) ? q.xz : q.xy);
	vec2 cell = floor(uv);
	vec2 f = fract(uv) - 0.5 + (vec2(h21(cell + 3.1), h21(cell + 7.7)) - 0.5) * 0.4;
	float h = h21(cell);
	float thick = (1.0 - layer * 0.8) * 0.3;     // very thin strands that taper to fine tips
	if (h < layer * 0.85 || length(f) > thick) { discard; }
	float tone = 0.62 + 0.38 * layer;
	ALBEDO = base_color.rgb * tone * (0.88 + 0.24 * h);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = base_color.rgb * 0.25;
}
"""

static var _smooth_cache := {}
static var _shader: Shader
static var _hair_normal: NoiseTexture2D


## Smooth normals for every surface of `m`, averaged by position across all surfaces.
static func smooth_mesh(m: Mesh) -> Mesh:
	if m == null or not (m is ArrayMesh):
		return m
	if _smooth_cache.has(m):
		return _smooth_cache[m]
	var am := m as ArrayMesh
	if am.get_blend_shape_count() > 0:
		_smooth_cache[m] = m
		return m
	var acc := {}
	var all: Array = []
	for s in am.get_surface_count():
		var arr: Array = am.surface_get_arrays(s)
		all.append(arr)
		if am.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri := idx.size() if not idx.is_empty() else vs.size()
		for t in range(0, tri - 2, 3):
			var a := idx[t] if not idx.is_empty() else t
			var b := idx[t + 1] if not idx.is_empty() else t + 1
			var c := idx[t + 2] if not idx.is_empty() else t + 2
			var fn := (vs[b] - vs[a]).cross(vs[c] - vs[a])      # area-weighted face normal
			for v in [a, b, c]:
				var key := Vector3i((vs[v] * 4000.0).round())
				acc[key] = acc.get(key, Vector3.ZERO) + fn
	var out := ArrayMesh.new()
	for s in am.get_surface_count():
		var arr: Array = all[s]
		if am.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns := PackedVector3Array()
			ns.resize(vs.size())
			var old: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for i in vs.size():
				var n: Vector3 = acc.get(Vector3i((vs[i] * 4000.0).round()), Vector3.ZERO)
				if n.length_squared() < 1e-12:
					n = old[i] if i < old.size() else Vector3.UP
				# keep very sharp creases (ears, horn tips) from turning inside out
				if i < old.size() and n.normalized().dot(old[i]) < 0.2:
					n = old[i]
				ns[i] = n.normalized()
			arr[Mesh.ARRAY_NORMAL] = ns
			arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(am.surface_get_primitive_type(s), arr)
		out.surface_set_material(s, am.surface_get_material(s))
		out.surface_set_name(s, am.surface_get_name(s))
	_smooth_cache[m] = out
	return out


static func _hair_tex() -> NoiseTexture2D:
	if _hair_normal == null:
		var fn := FastNoiseLite.new()
		fn.seed = 21
		fn.frequency = 0.08
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_hair_normal = NoiseTexture2D.new()
		_hair_normal.noise = fn
		_hair_normal.width = 256
		_hair_normal.height = 256
		_hair_normal.seamless = true
		_hair_normal.as_normal_map = true
		_hair_normal.bump_strength = 6.0
	return _hair_normal


static func _is_fur(name_: String, share: float) -> bool:
	var n := name_.to_lower()
	for bad in ["eye", "hoove", "hoof", "horn", "muzzle", "pupil", "nose", "black"]:
		if n.contains(bad):
			return false
	return share > 0.06


## Dress every mesh under `inst`. `world_size` = the animal's largest size in metres (length or height). Returns the per-animal shell materials
## (for set_near), or [] when fur is off.
static func dress(inst: Node, species: String, world_size: float) -> Array:
	var coat: Array = COAT.get(species, [0.015, 0.005, 0.15])
	var shells_on := int(GameSettings.v.get("quality", 0)) <= 1 and bool(GameSettings.v.get("animal_fur", true))
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FUR_SHADER
	var firsts: Array = []
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		# mesh units -> metres: compare the mesh's largest extent with the animal's largest size in the world
		var ms := mi.mesh.get_aabb().size
		var eff := maxf(world_size / maxf(maxf(ms.x, ms.y), maxf(ms.z, 0.000001)), 0.000001)
		var src := mi.mesh
		var total := 0
		for s in src.get_surface_count():
			total += int((src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		var overrides: Array = []
		for s in src.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		mi.mesh = smooth_mesh(src)
		for s in mi.mesh.get_surface_count():
			var mat: Material = overrides[s] if overrides[s] != null else mi.mesh.surface_get_material(s)
			if not (mat is StandardMaterial3D):
				continue
			var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			var nm := mat.resource_name.to_lower()
			var verts := int((mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			var fur := _is_fur(mat.resource_name, float(verts) / maxf(1.0, float(total)))
			if nm.contains("eye") or nm.contains("pupil") or nm.contains("nose") or nm.contains("muzzle"):
				d.roughness = 0.12 if nm.contains("eye") or nm.contains("pupil") else 0.35
				d.metallic_specular = 0.8
			elif nm.contains("hoove") or nm.contains("horn"):
				d.roughness = 0.45
				d.metallic_specular = 0.55
			elif fur:
				d.roughness = 0.9
				d.metallic_specular = 0.3
				d.normal_enabled = true
				d.normal_texture = _hair_tex()
				d.normal_scale = 0.55
				if not d.uv1_triplanar:
					d.uv1_triplanar = true
					d.uv1_scale = Vector3.ONE * 1.2
				d.rim_enabled = true                     # soft light scattering at the edges of a coat
				d.rim = 0.25
				d.rim_tint = 0.6
				if shells_on:
					var prev: Material = d
					for li in SHELLS:
						var sm := ShaderMaterial.new()
						sm.shader = _shader
						sm.set_shader_parameter("base_color", d.albedo_color)
						sm.set_shader_parameter("layer", float(li + 1) / float(SHELLS))
						sm.set_shader_parameter("fur_len", float(coat[0]) / eff)
						sm.set_shader_parameter("density", eff / float(coat[1]))
						sm.set_shader_parameter("droop", float(coat[2]))
						prev.next_pass = sm
						prev = sm
					firsts.append([d, d.next_pass])
			mi.set_surface_override_material(s, d)
	return firsts


## Shells are drawn only near the camera: detach them far away, put them back when close.
static func set_near(firsts: Array, near: bool) -> void:
	for f in firsts:
		var d: StandardMaterial3D = f[0]
		d.next_pass = f[1] if near else null
