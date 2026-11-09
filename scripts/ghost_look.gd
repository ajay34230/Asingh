class_name GhostLook
extends RefCounted
## The look of spectral monsters (ghosts, flying skulls):
##   - a glowing rim (fresnel) round a misty body whose inside does not show through (depth pre-pass)
##   - the tail thins away to nothing and ripples slowly; the head stays still
##   - drifting mist in the body (scrolling noise) and a faint flicker
##   - dark parts of the texture (eyes, mouth) glow
##   - forming out of glowing specks when it appears ("rise"), burning away with a bright edge when it dies
##     ("dissolve"), a white flash when hit ("flash")
##   - a few wisps trailing off the tail (fewer on Low graphics)
## All procedural (no textures added), one material per surface.

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool use_tex = true;
uniform vec4 base : source_color = vec4(1.0);
uniform vec4 glow : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform float body_alpha = 0.42;
uniform float solid_bright = 0.0;   // 1: bright parts (a skull) stay solid
uniform float y0 = 0.0;             // mesh-space bottom and height, for the tail fade
uniform float ysize = 1.0;
uniform float inv_scale = 1.0;      // mesh units per metre
uniform float dissolve = 0.0;       // 0 whole .. 1 gone
uniform float rise = 0.0;           // 1 not yet formed .. 0 formed
uniform float flash = 0.0;
varying vec3 wpos;
varying float hr;
float h3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	hr = clamp((VERTEX.y - y0) / max(ysize, 0.0001), 0.0, 1.0);
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = 1.0 - smoothstep(0.12, 0.55, hr);
	VERTEX += NORMAL * sin(TIME * 3.1 + w.y * 6.0 + w.x * 2.0) * 0.035 * sway * inv_scale;
	VERTEX.x += sin(TIME * 1.7 + w.z) * 0.05 * sway * sway * inv_scale;
	wpos = w;
}
void fragment() {
	vec4 c = use_tex ? texture(tex, UV) : base;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(c.rgb, glow.rgb, 0.45);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float mist = vn(wpos * 3.0 + vec3(0.0, -TIME * 0.6, 0.0));
	float tail = smoothstep(0.0, 0.38, hr);
	float a = (body_alpha * (0.55 + 0.45 * mist) + fres * 0.9) * tail;
	a *= 0.92 + 0.08 * sin(TIME * 9.0 + wpos.x * 3.0);
	float solid = solid_bright * smoothstep(0.6, 0.8, lum);
	a = mix(a, 0.97, solid);
	float cut = max(dissolve, rise);
	float dn = vn(wpos * 5.0);
	if (dn < cut) { discard; }
	float edge = (1.0 - smoothstep(cut, cut + 0.08, dn)) * step(0.001, cut);
	float eyes = (1.0 - smoothstep(0.06, 0.24, lum)) * (1.0 - solid);
	ALBEDO = mix(col * 0.6, c.rgb, solid);
	EMISSION = glow.rgb * (0.06 + 0.85 * fres) * (1.0 - solid * 0.8) + glow.rgb * eyes * 1.4
		+ glow.rgb * edge * 3.0 + vec3(flash * 1.2);
	ALPHA = clamp(a + edge + flash * 0.3, 0.0, 1.0);
}
"""

static var _shader: Shader


## A ghost material for one surface of the model (src: the model's own material).
static func material(src: StandardMaterial3D, glow: Color, solid_bright: bool, mesh_aabb: AABB, scale: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("use_tex", src.albedo_texture != null)
	if src.albedo_texture != null:
		m.set_shader_parameter("tex", src.albedo_texture)
	m.set_shader_parameter("base", src.albedo_color)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("solid_bright", 1.0 if solid_bright else 0.0)
	m.set_shader_parameter("y0", mesh_aabb.position.y)
	m.set_shader_parameter("ysize", mesh_aabb.size.y)
	m.set_shader_parameter("inv_scale", 1.0 / maxf(scale, 0.0001))
	return m


## Wisps drifting off the lower body, left behind as the ghost moves.
static func wisps(glow: Color, height: float) -> CPUParticles3D:
	var low := int(GameSettings.v.get("quality", 0)) >= 2
	var p := CPUParticles3D.new()
	p.name = "Wisps"
	p.amount = 6 if low else 12
	p.lifetime = 1.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4 * height / 1.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, 0.35, 0)
	p.damping_min = 0.3
	p.damping_max = 0.6
	p.scale_amount_min = 0.04 * height
	p.scale_amount_max = 0.08 * height
	var curve := Curve.new()                   # grow in, then shrink away (fades without vertex colours)
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(glow.r, glow.g, glow.b, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = true
	m.disable_fog = false
	SoftDot.apply(m)
	q.material = m
	p.mesh = q
	p.position = Vector3(0, 0.18 * height, 0)
	return p
