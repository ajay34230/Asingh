class_name RiverBuilder
extends Node3D
## The valley's seasonal river and its waterfall. The riverbed is dry in fair weather; after rain (and
## in a story storm) water fills it and flows south from the waterfall on the north cliff, then
## slowly drains again. The waterfall always carries a thin trickle and swells with the rain.
## Sound: a rushing-water loop that follows how full the river is.

const Z_TOP := -176.0
const Z_END := 188.0
const STEP := 4.0
const WIDTH := 9.0

const RIVER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float level = 0.0;
uniform float speed = 0.45;
void fragment() {
	vec2 uv = UV * vec2(2.0, 14.0);
	float n1 = texture(noise, uv + vec2(0.0, TIME * speed)).r;
	float n2 = texture(noise, uv * 1.9 + vec2(0.31, TIME * speed * 1.7)).r;
	float foam = smoothstep(0.66, 0.82, n1 * n2 * 1.9);
	float edge = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	vec3 deep = vec3(0.10, 0.30, 0.38);
	vec3 shallow = vec3(0.32, 0.52, 0.55);
	ALBEDO = mix(deep, shallow, n1) + vec3(foam * 0.55);
	ROUGHNESS = 0.12;
	METALLIC = 0.25;
	ALPHA = clamp(level * (0.5 + 0.35 * n2 + foam * 0.3) * (0.4 + 0.6 * edge), 0.0, 0.92);
}
"""

const FALL_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float level = 0.35;
void fragment() {
	float a = texture(noise, vec2(UV.x * 5.0, UV.y * 1.6 - TIME * 1.5)).r;
	float b = texture(noise, vec2(UV.x * 11.0 + 0.4, UV.y * 2.4 - TIME * 2.3)).r;
	float streak = smoothstep(0.35, 0.8, a * 0.6 + b * 0.55);
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	ALBEDO = mix(vec3(0.62, 0.78, 0.86), vec3(1.0), streak);
	ALPHA = clamp(level * (0.25 + 0.75 * streak) * edge, 0.0, 0.85);
}
"""

var terrain: TerrainBuilder
var player: Player
var atmo: Atmosphere
var wet := 0.0                      # 0 dry .. 1 in spate; rises in rain, drains slowly
var river_mat: ShaderMaterial
var fall_mat: ShaderMaterial
var river_node: MeshInstance3D
var fall_pos := Vector3.ZERO
var fall_h := 0.0
var _loop: AudioStreamPlayer3D
var _fall_loop: AudioStreamPlayer3D
var _mist: CPUParticles3D


func _init(t: TerrainBuilder, p: Player, a: Atmosphere) -> void:
	terrain = t
	player = p
	atmo = a
	name = "River"


func _noise_tex() -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.04
	fn.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = fn
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	return tex


func build(parent: Node3D) -> void:
	parent.add_child(self)
	var tex := _noise_tex()
	river_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RIVER_SHADER
	river_mat.shader = sh
	river_mat.set_shader_parameter("noise", tex)
	fall_mat = ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = FALL_SHADER
	fall_mat.shader = sh2
	fall_mat.set_shader_parameter("noise", tex)
	_ribbon()
	_waterfall()


func _ribbon() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int((Z_END - Z_TOP) / STEP)
	for i in n:
		var z0 := Z_TOP + i * STEP
		var z1 := z0 + STEP
		var p0 := _row(z0)
		var p1 := _row(z1)
		var v0 := float(i) / float(n)
		var v1 := float(i + 1) / float(n)
		# quad: left0, right0, left1, right1
		var quad := [[p0[0], Vector2(0, v0)], [p0[1], Vector2(1, v0)], [p1[0], Vector2(0, v1)], [p1[1], Vector2(1, v1)]]
		for idx in [0, 1, 2, 1, 3, 2]:
			st.set_uv(quad[idx][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[idx][0])
	river_node = MeshInstance3D.new()
	river_node.name = "RiverWater"
	river_node.mesh = st.commit()
	river_node.material_override = river_mat
	river_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	river_node.extra_cull_margin = 400.0
	river_node.visible = false
	add_child(river_node)
	_loop = Sfx.emitter(self, "water_splash_loop", Vector3(terrain.river_x(0.0), 0.5, 0.0), -80.0, 60.0, 14.0)
	_loop.stream_paused = true


func _row(z: float) -> Array:
	var cx := terrain.river_x(z)
	var wl := terrain.sample_height(cx, z) + 0.45      # the bed is the lowest ground at the channel centre
	var l := Vector3(cx - WIDTH * 0.5, wl, z)
	var r := Vector3(cx + WIDTH * 0.5, wl, z)
	return [l, r]


func _waterfall() -> void:
	var cx := terrain.river_x(Z_TOP)
	var base_y := terrain.sample_height(cx, Z_TOP) + 0.2
	var top_y := base_y + 46.0
	var q := QuadMesh.new()
	q.size = Vector2(5.0, top_y - base_y)
	var m := MeshInstance3D.new()
	m.name = "Waterfall"
	m.mesh = q
	m.material_override = fall_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin = 200.0
	# the cliff leans back to the north; hang the sheet just in front of its face, facing the valley
	fall_h = top_y - base_y
	fall_pos = Vector3(cx, (base_y + top_y) * 0.5, Z_TOP - 8.5)
	m.position = fall_pos
	m.rotation_degrees = Vector3(0, 0, 0)
	add_child(m)
	_mist = CPUParticles3D.new()
	_mist.position = Vector3(cx, base_y + 1.0, Z_TOP - 6.0)
	_mist.amount = 40
	_mist.lifetime = 2.2
	_mist.direction = Vector3(0, 1, 0.5)
	_mist.spread = 40.0
	_mist.initial_velocity_min = 1.0
	_mist.initial_velocity_max = 2.4
	_mist.gravity = Vector3(0, 0.4, 0)
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_mist.emission_box_extents = Vector3(2.4, 0.4, 0.8)
	_mist.scale_amount_min = 1.2
	_mist.scale_amount_max = 2.6
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 1.6)
	_mist.mesh = qm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.9, 0.95, 1.0, 0.18)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mist.material_override = pm
	add_child(_mist)
	_fall_loop = Sfx.emitter(self, "water_splash_loop", Vector3(cx, base_y + 2.0, Z_TOP - 6.0), -9.0, 70.0, 10.0)
	_fall_loop.stream_paused = true


func _process(delta: float) -> void:
	if atmo != null:
		if atmo.rain > 0.3:
			wet = minf(1.0, wet + delta / 45.0 * atmo.rain)
		else:
			wet = maxf(0.0, wet - delta / 240.0)
	var fall_level := clampf(0.3 + wet * 0.7, 0.0, 1.0)
	river_mat.set_shader_parameter("level", clampf(wet * 1.25, 0.0, 1.0))
	river_mat.set_shader_parameter("speed", 0.3 + 0.5 * wet)
	fall_mat.set_shader_parameter("level", fall_level)
	river_node.visible = wet > 0.04
	_mist.emitting = wet > 0.05 or true
	(_mist.material_override as StandardMaterial3D).albedo_color.a = 0.10 + 0.14 * wet
	var d := player.global_position.distance_to(fall_pos)
	var near := d < 150.0 or river_node.visible and absf(player.global_position.x - terrain.river_x(player.global_position.z)) < 70.0
	for a in [_loop, _fall_loop]:
		(a as AudioStreamPlayer3D).stream_paused = not near
		if near and not (a as AudioStreamPlayer3D).playing:
			(a as AudioStreamPlayer3D).play()
	# the river sound follows the player along the channel so it always sits at the nearest bank
	var pz := clampf(player.global_position.z, Z_TOP, Z_END)
	_loop.global_position = Vector3(terrain.river_x(pz), terrain.sample_height(terrain.river_x(pz), pz) + 0.8, pz)
	_loop.volume_db = -80.0 if wet < 0.05 else lerpf(-22.0, -5.0, wet)
	_fall_loop.volume_db = lerpf(-14.0, -3.0, fall_level)
