## Living scenery: silk flags waving on every chhatri, gold glints on finials, the lotus
## fountain flowing, rose petals drifting over the board and, on Diwali night, sky
## lanterns rising with fireworks now and then.
class_name Ambience
extends Node3D

const FLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
void vertex() {
	// UV.x = 0 at the pole, 1 at the free end: the wave grows towards the end.
	float k = UV.x;
	VERTEX.z += sin(TIME * 6.0 - UV.x * 7.0) * 0.06 * k;
	VERTEX.y += sin(TIME * 4.0 - UV.x * 5.0) * 0.015 * k;
}
void fragment() {
	float fold = 0.85 + 0.15 * sin(TIME * 6.0 - UV.x * 7.0);
	ALBEDO = color.rgb * fold;
	ROUGHNESS = 0.55;
	BACKLIGHT = color.rgb * 0.5;
}
"""

var _glints: Array[MeshInstance3D] = []
var _time := 0.0
var _night := false
var _next_firework := 4.0
var effects: EffectsManager


func _ready() -> void:
	_night = BoardThemes.current().get("night", false)
	var flag_shader := Shader.new()
	flag_shader.code = FLAG_SHADER
	var gold := RoyalBoard.metal(BoardThemes.current()["gold"], 0.22)
	for color in BoardPath.COLORS:
		var home: Vector2i = BoardPath.PLAYERS[color]["home"]
		var c := BoardPath.to_world(home.x + 3, home.y + 3)
		var top := Vector3(c.x, RoyalBoard.FLOOR_TOP + 2.38, c.z)
		_flag(top, RoyalBoard.PALETTE[color], flag_shader, gold)
		_glint(top + Vector3(0, -0.12, 0))
	_fountain(Vector3(12.7, RoyalBoard.WING_TOP + 1.05, 0.0))
	_petals()
	if _night:
		_lanterns()


func _process(delta: float) -> void:
	_time += delta
	## Glints: a brief star-shaped flash, each finial on its own rhythm.
	for i in range(_glints.size()):
		var g := _glints[i]
		var p := fposmod(_time * 0.35 + i * 0.27, 1.0)
		var flash := maxf(0.0, 1.0 - absf(p - 0.5) * 14.0)
		g.scale = Vector3.ONE * (0.05 + flash * 0.5)
		g.rotation.z = _time * 1.5
		g.visible = flash > 0.0
	if _night and effects:
		_next_firework -= delta
		if _next_firework <= 0.0:
			_next_firework = randf_range(3.0, 7.0)
			var colors := [EffectsManager.GOLD, Color("#ff6f91"), Color("#7fd0ff"), Color("#ffd27a")]
			var at := Vector3(randf_range(-16, 16), randf_range(6, 9), randf_range(-9, -4))
			effects.burst(at, colors.pick_random(), 60, 4.0, 1.4, 1.5)


func _flag(top: Vector3, color: Color, shader: Shader, gold: Material) -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.5
	cyl.radial_segments = 12
	pole.mesh = cyl
	pole.material_override = gold
	pole.position = top + Vector3(0, 0.25, 0)
	add_child(pole)
	## A pennant: a strip of quads, wide at the pole and pointed at the end.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 16
	var length := 0.42
	for i in range(segs):
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var h0 := 0.16 * (1.0 - u0 * 0.85)
		var h1 := 0.16 * (1.0 - u1 * 0.85)
		var a := Vector3(u0 * length, 0, 0)
		var b := Vector3(u1 * length, 0, 0)
		var quad := [[a, Vector2(u0, 0)], [b, Vector2(u1, 0)], [b + Vector3(0, -h1, 0), Vector2(u1, 1)],
			[a, Vector2(u0, 0)], [b + Vector3(0, -h1, 0), Vector2(u1, 1)], [a + Vector3(0, -h0, 0), Vector2(u0, 1)]]
		for v in quad:
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var flag := MeshInstance3D.new()
	flag.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", color)
	flag.material_override = mat
	flag.position = top + Vector3(0.012, 0.48, 0)
	add_child(flag)


func _glint(at: Vector3) -> void:
	var star := PackedVector2Array()
	for i in range(8):
		var r := 1.0 if i % 2 == 0 else 0.18
		var a := TAU * i / 8.0
		star.append(Vector2(cos(a), sin(a)) * r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(star.size()):
		for v in [Vector2.ZERO, star[i], star[(i + 1) % star.size()]]:
			st.add_vertex(Vector3(v.x, v.y, 0))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.6)
	mat.emission_energy_multiplier = 6.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	add_child(m)
	_glints.append(m)


func _fountain(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 1.1
	p.position = at
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 14.0
	mat.initial_velocity_min = 1.6
	mat.initial_velocity_max = 2.1
	mat.gravity = Vector3(0, -5.5, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	mat.color = Color(0.8, 0.9, 1.0, 0.75)
	p.process_material = mat
	var drop := SphereMesh.new()
	drop.radius = 0.025
	drop.height = 0.07
	drop.radial_segments = 6
	drop.rings = 3
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.85, 0.93, 1.0, 0.6)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.roughness = 0.05
	dm.metallic_specular = 1.0
	dm.vertex_color_use_as_albedo = true
	drop.material = dm
	p.draw_pass_1 = drop
	add_child(p)


## Rose and marigold petals drifting slowly across the whole scene.
func _petals() -> void:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.position = Vector3(0, 6.0, 0)
	p.visibility_aabb = AABB(Vector3(-30, -10, -15), Vector3(60, 20, 30))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(22, 0.5, 9)
	mat.direction = Vector3(1, -0.3, 0.2)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0.15, -0.45, 0)
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	mat.scale_min = 0.7
	mat.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("#ff5f86"), Color("#ffa040"), Color("#ff3d5a")])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_initial_ramp = tex
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.6
	mat.turbulence_noise_scale = 4.0
	p.process_material = mat
	var petal := QuadMesh.new()
	petal.size = Vector2(0.14, 0.09)
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pm.roughness = 0.6
	pm.backlight_enabled = true
	pm.backlight = Color(0.6, 0.3, 0.3)
	## Petal shape: a teardrop cut out with alpha.
	var img := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	for y in range(24):
		for x in range(32):
			var u := (x - 15.5) / 16.0
			var v := (y - 11.5) / 12.0
			var w := 1.0 - (u + 1.0) * 0.25          # narrower towards one end
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if u * u + (v / maxf(w, 0.1)) * (v / maxf(w, 0.1)) < 1.0 else 0.0))
	pm.albedo_texture = ImageTexture.create_from_image(img)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	pm.alpha_scissor_threshold = 0.5
	petal.material = pm
	p.draw_pass_1 = petal
	add_child(p)


## Diwali: glowing paper lanterns rising slowly into the night sky.
func _lanterns() -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 18.0
	p.preprocess = 18.0
	p.position = Vector3(0, 1.0, -6.0)
	p.visibility_aabb = AABB(Vector3(-30, -2, -15), Vector3(60, 30, 30))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(22, 0.2, 4)
	mat.direction = Vector3.UP
	mat.spread = 10.0
	mat.initial_velocity_min = 0.35
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0.05, 0.02, 0)
	mat.scale_min = 0.8
	mat.scale_max = 1.2
	p.process_material = mat
	var lantern := CylinderMesh.new()
	lantern.top_radius = 0.12
	lantern.bottom_radius = 0.08
	lantern.height = 0.26
	lantern.radial_segments = 12
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#ffb347")
	lm.emission_enabled = true
	lm.emission = Color("#ff9a2a")
	lm.emission_energy_multiplier = 4.0
	lantern.material = lm
	p.draw_pass_1 = lantern
	add_child(p)
