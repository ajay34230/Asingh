// Procedural polished marble, driven by world position (no UVs needed).
// Veins come from a noise-warped sine, grain from a second noise sample.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.95, 0.92, 0.84);
uniform vec3 vein_color : source_color = vec3(0.62, 0.55, 0.42);
uniform float vein_scale = 2.4;
uniform float grain_scale = 9.0;
uniform float roughness_value = 0.28;
uniform float clearcoat_amount = 0.35;
uniform sampler2D warp_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D grain_noise : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float warp = texture(warp_noise, p * 0.11).r;
	float vein = abs(sin((p.x * 0.8 + p.y * 0.55 + warp * 9.0) * vein_scale));
	vein = pow(1.0 - vein, 7.0);
	float grain = texture(grain_noise, p * grain_scale * 0.1).r;
	vec3 col = mix(base_color, vein_color, clamp(vein * 0.75 + (grain - 0.5) * 0.12, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = roughness_value + (grain - 0.5) * 0.08;
	SPECULAR = 0.5;
	CLEARCOAT = clearcoat_amount;
	CLEARCOAT_ROUGHNESS = 0.22;
}
