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
uniform int kind = 0;            // 0 cloth, 1 leather, 2 metal, 3 skin, 4 painted atlas (decide per pixel), 5 hair
uniform vec4 dye_a : source_color = vec4(1.0);
uniform vec4 dye_b : source_color = vec4(1.0);
uniform float dye_on = 0.0;      // 0 none, 1 = dye_a, 2 = dye_b (flat surfaces); atlas: luminance picks
uniform float unit = 1.0;        // metres per mesh unit
uniform bool all_garment = false;
uniform float shrink = 0.0;      // metres: pull a body under a tunic inward so it never pokes through // painted atlas that is all clothing (the tunic overlays): no skin block
varying vec3 opos;
varying vec3 onrm;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	if (shrink > 0.0) {
		float below_neck = 1.0 - smoothstep(1.34, 1.46, VERTEX.y * unit);
		VERTEX -= NORMAL * (shrink / unit) * below_neck;
	}
	opos = VERTEX * unit; onrm = NORMAL;
}
void fragment() {
	vec4 c = use_tex ? texture(tex, UV) : base;
	int k = kind;
	bool garment = true;
	if (k == 4) {
		garment = all_garment || (UV.y > 0.625 && UV.x < 0.5);
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
		k = garment ? ((sat < 0.12 && mx > 0.35) ? 2 : (mx < 0.22 ? 1 : 0)) : 3;
	} else if (k == 3 || k == 5) {
		garment = false;                 // skin and hair keep their own colours
	}
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (k == 3) {
		// skin: pull the painted orange toward a natural warm tone
		c.rgb = mix(c.rgb, vec3(lum) * vec3(1.14, 0.93, 0.80) * 1.04, 0.2);
	}
	if (garment && dye_on > 0.0 && k != 2) {
		vec3 d = dye_on > 1.5 ? dye_b.rgb : dye_a.rgb;
		if (kind == 4) {
			d = mix(dye_b.rgb, dye_a.rgb, smoothstep(0.12, 0.35, lum));
			c.rgb = mix(c.rgb, d * clamp(lum * 2.0, 0.25, 1.05), 0.78);   // rich, not neon; keeps the weave
		} else {
			c.rgb = d;
		}
	}
	vec3 an = abs(onrm);
	vec2 q = (an.x > an.y && an.x > an.z) ? opos.yz : ((an.y > an.z) ? opos.xz : opos.xy);
	float detail = 0.0;
	vec2 grad = vec2(0.0);
	if (k == 5) {
		// hair: fine strands along one direction, no weave
		detail = vnoise(vec2(q.x * 700.0, q.y * 30.0)) - 0.5;
		grad = vec2(0.0);
	} else if (k == 0) {
		vec2 w = q * 520.0;              // a fine weave: felt up close, gone at a few metres
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
	float amt = (k == 0 ? 0.07 : (k == 1 ? 0.16 : (k == 2 ? 0.08 : (k == 5 ? 0.12 : 0.04)))) * fade;
	ALBEDO = c.rgb * (1.0 + detail * amt);
	vec3 pert = vec3(grad.x, 0.0, grad.y) * amt * 0.35;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(pert, 0.0)).xyz);
	if (k == 0) { ROUGHNESS = 0.86; SPECULAR = 0.3; RIM = 0.3; RIM_TINT = 0.6; }
	else if (k == 1) { ROUGHNESS = 0.55 - detail * 0.2; SPECULAR = 0.45; }
	else if (k == 2) { METALLIC = 0.88; ROUGHNESS = 0.3 + detail * 0.2; SPECULAR = 0.7; }
	else if (k == 5) { ROUGHNESS = 0.42; SPECULAR = 0.55; RIM = 0.15; RIM_TINT = 0.7; }
	else { ROUGHNESS = 0.5; SPECULAR = 0.38; BACKLIGHT = vec3(0.4, 0.14, 0.09) * 0.4; RIM = 0.22; RIM_TINT = 0.8; }
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


## True for meshes that came from a tunic overlay file (robe_*.glb).
static func _from_robe(mi: Node) -> bool:
	var n := mi
	while n != null:
		if n.scene_file_path.get_file().begins_with("robe_"):
			return true
		n = n.get_parent()
	return false


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
	var has_robe := false
	for m in meshes:
		if _from_robe(m):
			has_robe = true
			break
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
			if not has_tex and k != 3 and mi.name.to_lower().contains("head"):
				k = 5      # on the villagers' head meshes anything but skin and eyes is hair (named by colour)
			var mat := ShaderMaterial.new()
			mat.shader = _garment
			mat.set_shader_parameter("use_tex", has_tex)
			if has_tex:
				mat.set_shader_parameter("tex", sm.albedo_texture)
				# the tunic overlays (robe_*.glb) are cloth all over; their pale patches are not skin
				var tp := sm.albedo_texture.resource_path.get_file()
				mat.set_shader_parameter("all_garment", tp.begins_with("robe_") or mi.get_parent().name.begins_with("robe_") or _from_robe(mi))
			mat.set_shader_parameter("base", sm.albedo_color)
			mat.set_shader_parameter("kind", k)
			if has_robe and not _from_robe(mi) and mi.name.to_lower().begins_with("superhero"):
				mat.set_shader_parameter("shrink", 0.018)     # the bare body stays under the tunic
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


static func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.9
	m.roughness = 0.28
	return m


static func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = sc
	return mi


## A gold kada (bangle) for the wrist.
static func kada(c: Color = Color(0.95, 0.75, 0.3)) -> Node3D:
	var root := Node3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.034
	t.outer_radius = 0.046
	t.rings = 20
	t.ring_segments = 8
	root.add_child(_mesh(t, _metal(c), Vector3.ZERO))
	return root


## A bead mala hanging on the chest with a pendant: rudraksha brown, or gold for royalty.
static func mala(bead: Color, pendant: Color) -> Node3D:
	var root := Node3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.014
	bm.height = 0.028
	bm.radial_segments = 8
	bm.rings = 4
	var mat := _mat(bead, 0.45)
	for i in 17:
		var a := lerpf(-1.25, 1.25, float(i) / 16.0)
		root.add_child(_mesh(bm, mat, Vector3(sin(a) * 0.1, -cos(a) * 0.13 + 0.12, -0.035 * cos(a))))
	var pm := SphereMesh.new()
	pm.radius = 0.022
	pm.height = 0.03
	root.add_child(_mesh(pm, _metal(pendant), Vector3(0, -0.035, -0.045)))
	return root


## A leather belt pouch with a flap and a brass button.
static func pouch() -> Node3D:
	var root := Node3D.new()
	var leather := _mat(Color(0.36, 0.22, 0.12), 0.6)
	var b := BoxMesh.new()
	b.size = Vector3(0.1, 0.13, 0.055)
	root.add_child(_mesh(b, leather, Vector3(0, -0.06, 0)))
	var f := BoxMesh.new()
	f.size = Vector3(0.105, 0.05, 0.06)
	root.add_child(_mesh(f, _mat(Color(0.3, 0.18, 0.1), 0.6), Vector3(0, 0.0, -0.003), Vector3(-8, 0, 0)))
	var btn := SphereMesh.new()
	btn.radius = 0.008
	btn.height = 0.016
	root.add_child(_mesh(btn, _metal(Color(0.85, 0.65, 0.3)), Vector3(0, -0.02, -0.032)))
	return root


## A leather quiver worn across the back with fletched arrows sticking out.
static func quiver() -> Node3D:
	var root := Node3D.new()
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(0, 0, 28)
	root.add_child(tilt)
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.05
	c.height = 0.58
	c.radial_segments = 12
	tilt.add_child(_mesh(c, _mat(Color(0.4, 0.24, 0.12), 0.6), Vector3.ZERO))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.055
	rim.outer_radius = 0.066
	tilt.add_child(_mesh(rim, _metal(Color(0.8, 0.6, 0.28)), Vector3(0, 0.29, 0)))
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.004
	shaft.bottom_radius = 0.004
	shaft.height = 0.2
	var feather := BoxMesh.new()
	feather.size = Vector3(0.028, 0.07, 0.003)
	var wood := _mat(Color(0.55, 0.42, 0.25), 0.7)
	for i in 6:
		var x := -0.03 + (i % 3) * 0.03
		var z := -0.015 + int(i / 3) * 0.03
		tilt.add_child(_mesh(shaft, wood, Vector3(x, 0.38, z)))
		var fm := _mat([Color(0.8, 0.15, 0.1), Color(0.95, 0.95, 0.9)][i % 2], 0.8)
		tilt.add_child(_mesh(feather, fm, Vector3(x, 0.45, z), Vector3(0, 30 * i, 0)))
	return root


## A scabbard (for the talwar) or a short sheath (dagger) hanging from the hip, angled back.
static func scabbard(long_blade: bool) -> Node3D:
	var root := Node3D.new()
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(-32 if long_blade else -20, 0, 6)
	root.add_child(tilt)
	var length := 0.82 if long_blade else 0.3
	var b := BoxMesh.new()
	b.size = Vector3(0.022, length, 0.06)
	tilt.add_child(_mesh(b, _mat(Color(0.18, 0.08, 0.06), 0.45), Vector3(0, -length * 0.5, 0)))
	var tip := BoxMesh.new()
	tip.size = Vector3(0.026, 0.07, 0.064)
	tilt.add_child(_mesh(tip, _metal(Color(0.85, 0.66, 0.3)), Vector3(0, -length + 0.035, 0)))
	var throat := BoxMesh.new()
	throat.size = Vector3(0.028, 0.05, 0.068)
	tilt.add_child(_mesh(throat, _metal(Color(0.85, 0.66, 0.3)), Vector3(0, -0.02, 0)))
	return root
