class_name ClothLook
extends RefCounted
## Makes clothes read as real fabric, leather and metal instead of flat colour:
## - Each surface is classed as cloth, leather, metal or skin (by material name; on painted atlas bodies by
##   where the pixel sits in the atlas: the clothing block vs the skin block), and gets matching shading:
##   woven cotton with a soft sheen, grained leather, polished metal, and skin that stays natural.
## - Dyes recolour only garments, keeping the painted folds and shadows (no more red faces under a red dye).
## - A fine woven or grained surface detail, faded out with distance so it never shimmers.
## Also builds the cloth accessories: turban (safa), waist sash and a cape that drapes, folds and sways.

const GARMENT := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform vec4 base : source_color = vec4(0.6, 0.5, 0.4, 1.0);
uniform int kind = 0;            // 0 cloth, 1 leather, 2 metal, 3 skin, 4 painted atlas (decide per pixel)
uniform vec4 dye_a : source_color = vec4(1.0);
uniform vec4 dye_b : source_color = vec4(1.0);
uniform float dye_on = 0.0;      // 0 none, 1 = dye_a, 2 = dye_b (flat surfaces); atlas: luminance picks
uniform float unit = 1.0;        // metres per mesh unit
varying vec3 opos;
varying vec3 onrm;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { opos = VERTEX * unit; onrm = NORMAL; }
void fragment() {
	vec4 c = use_tex ? texture(tex, UV) : base;
	int k = kind;
	bool garment = true;
	if (k == 4) {
		garment = UV.y > 0.625 && UV.x < 0.5;
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
		k = garment ? ((sat < 0.12 && mx > 0.35) ? 2 : (mx < 0.22 ? 1 : 0)) : 3;
	} else if (k == 3) {
		garment = false;
	}
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (garment && dye_on > 0.0 && k != 2) {
		vec3 d = dye_on > 1.5 ? dye_b.rgb : dye_a.rgb;
		if (kind == 4) {
			d = mix(dye_b.rgb, dye_a.rgb, smoothstep(0.12, 0.35, lum));
			c.rgb = mix(c.rgb, d * clamp(lum * 2.4, 0.25, 1.35), 0.82);
		} else {
			c.rgb = d;
		}
	}
	vec3 an = abs(onrm);
	vec2 q = (an.x > an.y && an.x > an.z) ? opos.yz : ((an.y > an.z) ? opos.xz : opos.xy);
	float detail = 0.0;
	vec2 grad = vec2(0.0);
	if (k == 0) {
		vec2 w = q * 260.0;
		detail = 0.5 * (sin(w.x) * sin(w.y + sin(w.x * 0.5) * 0.6)) + 0.5 * (vnoise(q * 40.0) - 0.5);
		grad = vec2(cos(w.x) * sin(w.y), sin(w.x) * cos(w.y));
	} else if (k == 1) {
		float n0 = vnoise(q * 90.0);
		detail = n0 - 0.5 + 0.5 * (vnoise(q * 300.0) - 0.5);
		grad = vec2(vnoise(q * 90.0 + vec2(0.3, 0.0)) - n0, vnoise(q * 90.0 + vec2(0.0, 0.3)) - n0) * 6.0;
	} else if (k == 2) {
		detail = vnoise(vec2(q.x * 600.0, q.y * 8.0)) - 0.5;
	} else {
		detail = vnoise(q * 160.0) - 0.5;
	}
	float fade = clamp(1.0 - length(fwidth(q * 260.0)) * 0.35, 0.0, 1.0);
	float amt = (k == 0 ? 0.16 : (k == 1 ? 0.2 : (k == 2 ? 0.08 : 0.04))) * fade;
	ALBEDO = c.rgb * (1.0 + detail * amt);
	vec3 pert = vec3(grad.x, 0.0, grad.y) * amt * 0.35;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(pert, 0.0)).xyz);
	if (k == 0) { ROUGHNESS = 0.86; SPECULAR = 0.3; RIM = 0.3; RIM_TINT = 0.6; }
	else if (k == 1) { ROUGHNESS = 0.55 - detail * 0.2; SPECULAR = 0.45; }
	else if (k == 2) { METALLIC = 0.88; ROUGHNESS = 0.3 + detail * 0.2; SPECULAR = 0.7; }
	else { ROUGHNESS = 0.52; SPECULAR = 0.35; BACKLIGHT = vec3(0.35, 0.12, 0.08) * 0.35; }
}
"""
const CAPE := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 col : source_color = vec4(0.1, 0.18, 0.6, 1.0);
uniform vec4 trim : source_color = vec4(0.95, 0.78, 0.3, 1.0);
uniform float swing = 0.0;
uniform float t_off = 0.0;
varying float v;
varying vec3 lp;
void vertex() {
	v = UV.y;
	float xn = UV.x * 2.0 - 1.0;
	VERTEX.x *= mix(0.62, 1.08, smoothstep(0.0, 0.5, v));
	VERTEX.z -= 0.11 * xn * xn * (0.4 + 0.6 * v);
	VERTEX.z += sin(xn * 9.42 + 0.7) * 0.022 * smoothstep(0.1, 1.0, v);
	float flutter = sin(TIME * (2.5 + swing * 7.0) + xn * 4.0 + v * 6.0 + t_off) * (0.02 + swing * 0.07) * v;
	VERTEX.z += v * v * (0.06 + swing * 0.55) + flutter;
	VERTEX.y += v * v * swing * 0.25;
	lp = VERTEX;
}
void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = FRONT_FACING ? n : -n;
	float edge = step(0.95, v) + step(0.96, abs(UV.x * 2.0 - 1.0));
	vec3 c = mix(col.rgb, trim.rgb, clamp(edge, 0.0, 1.0));
	float w = sin(lp.x * 520.0) * sin(lp.y * 520.0);
	ALBEDO = c * (0.94 + 0.06 * w) * (FRONT_FACING ? 1.0 : 0.75);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	RIM = 0.35;
	RIM_TINT = 0.5;
}
"""

static var _garment: Shader
static var _cape: Shader


static func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


static func _kind_for(mat_name: String, has_tex: bool) -> int:
	var n := mat_name.to_lower()
	if has_tex:
		return 4
	if n.contains("skin") or n.contains("eye") or n.contains("hair") or n.contains("teeth") or n.contains("mouth") or n.contains("beard"):
		return 3
	if n.contains("metal") or n.contains("gold") or n.contains("armor") or n.contains("armour") or n.contains("iron") or n.contains("silver"):
		return 2
	if n.contains("brown") or n.contains("boot") or n.contains("black") or n.contains("leather") or n.contains("belt"):
		return 1
	return 0


## Restyle every surface of a rig. dye: [main, trim] colours, or [] to keep the outfit's own colours.
static func dress(rig: RealHuman, dye: Array) -> void:
	if _garment == null:
		_garment = _shader(GARMENT)
	var meshes := rig._inner.find_children("*", "MeshInstance3D", true, false)
	var tallest := 0.0
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh != null:
			var sz := mi.mesh.get_aabb().size
			tallest = maxf(tallest, maxf(sz.x, maxf(sz.y, sz.z)))
	var unit := 1.75 / maxf(tallest, 0.000001)
	var alt := 0
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var src := mi.mesh
		var mats: Array = []
		for s in src.get_surface_count():
			mats.append(mi.get_active_material(s))
		mi.mesh = FurLook.smooth_mesh(src)
		for s in mi.mesh.get_surface_count():
			var sm := mats[s] as StandardMaterial3D
			if sm == null:
				continue
			var has_tex := sm.albedo_texture != null
			var k := _kind_for(sm.resource_name, has_tex)
			var mat := ShaderMaterial.new()
			mat.shader = _garment
			mat.set_shader_parameter("use_tex", has_tex)
			if has_tex:
				mat.set_shader_parameter("tex", sm.albedo_texture)
			mat.set_shader_parameter("base", sm.albedo_color)
			mat.set_shader_parameter("kind", k)
			mat.set_shader_parameter("unit", unit)
			if dye.size() >= 2 and k != 3 and k != 2:
				mat.set_shader_parameter("dye_a", dye[0])
				mat.set_shader_parameter("dye_b", dye[1])
				var which := 1.0 if (has_tex or alt % 2 == 0) else 2.0
				if not has_tex and k == 1:
					which = 0.0          # keep belts and boots their own leather colour
				mat.set_shader_parameter("dye_on", which)
				alt += 1
			mi.set_surface_override_material(s, mat)


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	return m


## A wrapped turban (safa) with a pleated crown, a gold band, a jewel and a plume (0.27 m wide head).
static func turban(main_c: Color, trim_c: Color) -> Node3D:
	var root := Node3D.new()
	var cloth := _mat(main_c)
	for i in 4:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.085 - i * 0.004
		tm.outer_radius = 0.135 - i * 0.008
		tm.rings = 24
		tm.ring_segments = 10
		t.mesh = tm
		t.material_override = cloth
		t.position = Vector3(0, -0.035 + i * 0.03, 0.005 * i)
		t.rotation_degrees = Vector3(8.0 + i * 3.0, 0, (4.0 if i % 2 == 0 else -4.0))
		root.add_child(t)
	var crown := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.11
	sp.height = 0.16
	crown.mesh = sp
	crown.material_override = cloth
	crown.position = Vector3(0, 0.05, 0.01)
	root.add_child(crown)
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.118
	bm.outer_radius = 0.132
	band.mesh = bm
	band.material_override = _mat(trim_c, 0.4)
	band.position = Vector3(0, -0.04, 0)
	band.rotation_degrees.x = 8.0
	root.add_child(band)
	var jewel := MeshInstance3D.new()
	var jm := SphereMesh.new()
	jm.radius = 0.016
	jm.height = 0.032
	jewel.mesh = jm
	var jmat := _mat(Color(0.75, 0.05, 0.1), 0.15)
	jmat.metallic_specular = 0.9
	jewel.material_override = jmat
	jewel.position = Vector3(0, 0.0, -0.13)
	root.add_child(jewel)
	var plume := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.004
	pm.bottom_radius = 0.012
	pm.height = 0.12
	plume.mesh = pm
	plume.material_override = _mat(trim_c, 0.5)
	plume.position = Vector3(0, 0.08, -0.11)
	plume.rotation_degrees.x = -20.0
	root.add_child(plume)
	return root


## A wide waist sash (kamarband) tied at the side with hanging ends.
static func sash(c: Color) -> Node3D:
	var root := Node3D.new()
	var m := _mat(c)
	var t := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.168
	tm.outer_radius = 0.19
	tm.rings = 28
	t.mesh = tm
	t.material_override = m
	t.scale = Vector3(1.0, 3.2, 0.82)
	root.add_child(t)
	for i in 2:
		var e := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.07, 0.3, 0.015)
		e.mesh = em
		e.material_override = m
		e.position = Vector3(0.17, -0.15 - i * 0.02, -0.04 + i * 0.05)
		e.rotation_degrees.z = 8.0 + i * 6.0
		root.add_child(e)
	return root


## A cape hanging from the shoulders (a 16 x 18 grid so it can drape and bend), swaying in the shader.
static func cape(c: Color, trim_c: Color, length: float = 1.05) -> Node3D:
	if _cape == null:
		_cape = _shader(CAPE)
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.62, length)
	pm.subdivide_width = 16
	pm.subdivide_depth = 18
	pm.orientation = PlaneMesh.FACE_Z
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _cape
	mat.set_shader_parameter("col", c)
	mat.set_shader_parameter("trim", trim_c)
	mat.set_shader_parameter("t_off", randf() * 6.0)
	mi.material_override = mat
	mi.position = Vector3(0, -length * 0.5, 0)       # hang from the top edge
	var holder := Node3D.new()
	holder.add_child(mi)
	return holder
