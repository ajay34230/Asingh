class_name MonsterLook
extends RefCounted
## Surface detail for the solid monsters, all procedural on top of their flat painted colours:
##   skeleton      grimy, cracked old bone, sickly green glint at the edges
##   yeti          streaky fur with frost on the tips, icy rim
##   mushroom_king a spotted cap whose spots glow and pulse, toxic green rim
##   demon         glowing lava cracks that pulse (hotter when enraged), ember rim
##   dragon        overlapping scales with a sheen, embers smouldering between them
## Every one: the darkest painted parts (eyes, pupils, mouths) glow in the monster's colour, and a white flash
## when hit. One shader, a "style" per kind.

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform int style = 0;
uniform vec4 rim_col : source_color = vec4(0.5, 1.0, 0.5, 1.0);
uniform vec4 eye_col : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform float unit = 1.0;       // metres per mesh unit
uniform float tall = 2.0;       // metres
uniform float flash = 0.0;
uniform float rage = 0.0;
varying vec3 op;
float h3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { op = VERTEX * unit; }
void fragment() {
	vec3 c = texture(tex, UV).rgb * tint.rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float n = vn(op * 6.0) * 0.65 + vn(op * 13.0) * 0.35;
	vec3 alb = c;
	vec3 em = vec3(0.0);
	float rough = 0.7;
	float spec = 0.4;
	float hy = clamp(op.y / max(tall, 0.01), 0.0, 1.0);
	if (style == 0) {
		alb *= 0.82 + 0.32 * n;
		float dirt = smoothstep(0.55, 0.8, vn(op * 3.0));
		alb = mix(alb, alb * vec3(0.72, 0.66, 0.5), dirt * 0.6);
		float crack = 1.0 - smoothstep(0.0, 0.03, abs(vn(op * 9.0) - 0.5));
		alb *= 1.0 - crack * 0.45;
		rough = 0.82;
	} else if (style == 1) {
		float fur = vn(vec3(op.x * 70.0, op.y * 10.0, op.z * 70.0));
		alb *= 0.8 + 0.32 * fur;
		alb = mix(alb, vec3(0.9, 0.97, 1.0), 0.18 * smoothstep(0.55, 0.9, n));
		rough = 0.92;
		spec = 0.25;
	} else if (style == 2) {
		float cap = smoothstep(0.66, 0.74, hy);
		float sp = smoothstep(0.6, 0.66, vn(op * 4.5)) * cap;
		alb = mix(alb * (0.88 + 0.2 * n), vec3(0.96, 0.95, 0.86), sp);
		em += vec3(0.45, 1.0, 0.55) * sp * (0.55 + 0.35 * sin(TIME * 2.2 + op.x * 5.0 + op.z * 3.0));
		rough = 0.6;
	} else if (style == 3) {
		float r = abs(vn(op * 4.5) - 0.5) + abs(vn(op * 9.0) - 0.5) * 0.4;
		float crack = 1.0 - smoothstep(0.0, 0.06, r);
		alb = mix(alb * (0.85 + 0.25 * n), alb * 0.45, crack);
		em += vec3(1.0, 0.33, 0.05) * crack * (1.1 + 0.7 * sin(TIME * 3.0 + op.y * 4.0)) * (1.0 + rage);
		rough = 0.55;
		spec = 0.5;
	} else {
		vec3 q = op * 13.0;
		float row = floor(q.y * 1.2);
		vec2 g = fract(vec2(q.x + q.z + row * 0.5, q.y * 1.2)) - 0.5;
		float sc = smoothstep(0.32, 0.5, length(g));
		alb *= 0.82 + 0.22 * (1.0 - sc) + 0.08 * n;
		em += vec3(1.0, 0.42, 0.1) * sc * smoothstep(0.62, 0.9, n) * 0.5 * (1.0 + rage);
		rough = 0.42 - 0.15 * (1.0 - sc);
		spec = 0.6;
	}
	float eye = 1.0 - smoothstep(0.03, 0.09, lum);
	em += eye_col.rgb * eye * (1.8 + rage);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	em += rim_col.rgb * fres * 0.55;
	em += vec3(flash);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = em;
}
"""

const STYLES := {
	"skeleton": [0, Color(0.55, 1.0, 0.4), Color(0.6, 1.0, 0.3)],
	"yeti": [1, Color(0.55, 0.85, 1.0), Color(0.4, 0.8, 1.0)],
	"mushroom_king": [2, Color(0.4, 1.0, 0.5), Color(0.5, 1.0, 0.3)],
	"demon": [3, Color(1.0, 0.35, 0.1), Color(1.0, 0.75, 0.1)],
	"dragon": [4, Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.2)],
}

static var _shader: Shader


static func has_style(kind: String) -> bool:
	return STYLES.has(kind)


static func material(src: StandardMaterial3D, kind: String, tint: Color, tall: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var st: Array = STYLES[kind]
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", src.albedo_texture)
	m.set_shader_parameter("tint", src.albedo_color * tint)
	m.set_shader_parameter("style", int(st[0]))
	m.set_shader_parameter("rim_col", st[1])
	m.set_shader_parameter("eye_col", st[2])
	m.set_shader_parameter("tall", tall)
	return m
