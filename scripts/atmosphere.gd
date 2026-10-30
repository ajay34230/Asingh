class_name Atmosphere
extends RefCounted
## Sky, directional sunlight, distance fog and a light drift of dust.
## Uses only features available in both the Mobile and Compatibility renderers.

var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var time_of_day := 0.33          # 0..1, 0.5 = noon, 0 / 1 = midnight
var night := 0.0                 # 0 (day) .. 1 (deep night), read by Sfx
var day_length := 1200.0         # real seconds per full day
var running := false
signal thunder
var rain := 0.0                  # 0 clear .. 1 downpour (smoothed)
var rain_target := 0.0
var _rain_p: GPUParticles3D
var _weather_t := 120.0          # seconds until the weather changes
var _bolt_t := 6.0
var _flash := 0.0
var _rainbow: Node3D
var _base_fog := 0.0009
var _world: Node3D
var environment: Environment


func build(parent: Node3D) -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.26, 0.47, 0.80)
	sky_mat.sky_horizon_color = Color(0.88, 0.78, 0.62)
	sky_mat.sky_curve = 0.14
	sky_mat.ground_horizon_color = Color(0.82, 0.70, 0.54)
	sky_mat.ground_bottom_color = Color(0.58, 0.46, 0.32)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.12

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Shadows are lit by a blend of blue sky and warm light bounced off the sand.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.64, 0.52)
	environment.ambient_light_sky_contribution = 0.55
	environment.ambient_light_energy = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.84, 0.74, 0.60)
	environment.fog_density = 0.0009
	environment.fog_sky_affect = 0.45
	environment.fog_sun_scatter = 0.25
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.1

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	parent.add_child(we)

	# Low afternoon sun from the south-west rakes across the south-facing entrance.
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-30.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.68)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	parent.add_child(sun)
	_world = parent


## A small cloud of slow dust motes that follows `follow` (usually the player).
func make_dust(follow: Node3D) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(38.0, 6.0, 38.0)
	pm.direction = Vector3(1.0, 0.04, 0.35)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.92, 0.82, 0.64, 0.32)
	mat.disable_receive_shadows = true
	quad.material = mat

	var p := GPUParticles3D.new()
	p.name = "Dust"
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-60, -15, -60), Vector3(120, 30, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = Vector3(0, 4, 0)
	follow.add_child(p)
	return p


## Advance the day/night cycle. Colours are blended between day, dusk and night palettes.
func update(delta: float) -> void:
	if sun == null:
		return
	if running:
		time_of_day = fposmod(time_of_day + delta / day_length, 1.0)
		_update_weather(delta)
	if running or rain > 0.01:
		apply_time()


## Rain: a particle curtain that follows the player, plus thunder and lightning while it pours.
func make_rain(follow: Node3D) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16.0, 0.5, 16.0)
	pm.direction = Vector3(0.12, -1.0, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -12.0, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.78, 0.86, 1.0, 0.5)
	mat.disable_receive_shadows = true
	quad.material = mat
	_rain_p = GPUParticles3D.new()
	_rain_p.name = "Rain"
	_rain_p.amount = 1400
	_rain_p.lifetime = 0.9
	_rain_p.local_coords = false
	_rain_p.visibility_aabb = AABB(Vector3(-30, -25, -30), Vector3(60, 40, 60))
	_rain_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_p.process_material = pm
	_rain_p.draw_pass_1 = quad
	_rain_p.position = Vector3(0, 14, 0)
	_rain_p.emitting = false
	follow.add_child(_rain_p)


func _update_weather(delta: float) -> void:
	_weather_t -= delta
	if _weather_t <= 0.0:
		if rain_target < 0.5:
			rain_target = randf_range(0.6, 1.0)
			_weather_t = randf_range(50.0, 90.0)
		else:
			rain_target = 0.0
			_weather_t = randf_range(150.0, 300.0)
			_show_rainbow()
	var was := rain
	rain = move_toward(rain, rain_target, delta / 12.0)
	if _rain_p != null:
		_rain_p.emitting = rain > 0.03
		_rain_p.amount_ratio = clampf(rain, 0.05, 1.0)
	if rain > 0.6:
		_bolt_t -= delta
		if _bolt_t <= 0.0:
			_bolt_t = randf_range(7.0, 18.0)
			_flash = 1.0
			thunder.emit()
	_flash = maxf(0.0, _flash - delta * 3.0)
	if was != rain or _flash > 0.0:
		apply_time()


func _show_rainbow() -> void:
	if _world == null or time_of_day < 0.25 or time_of_day > 0.75:
		return
	if _rainbow != null and is_instance_valid(_rainbow):
		_rainbow.queue_free()
	_rainbow = Node3D.new()
	_rainbow.position = Vector3(60, 0, -520)
	_world.add_child(_rainbow)
	var cols := [Color(1, 0.15, 0.15), Color(1, 0.55, 0.1), Color(1, 0.95, 0.2), Color(0.25, 0.9, 0.3), Color(0.2, 0.6, 1), Color(0.35, 0.3, 0.9), Color(0.7, 0.3, 0.85)]
	for i in cols.size():
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.outer_radius = 300.0 - i * 7.0
		tm.inner_radius = 300.0 - i * 7.0 - 7.0
		tm.rings = 48
		tm.ring_segments = 4
		t.mesh = tm
		t.rotation_degrees.x = 90.0
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(cols[i].r, cols[i].g, cols[i].b, 0.0)
		m.no_depth_test = false
		t.material_override = m
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rainbow.add_child(t)
		var tw := t.create_tween()
		tw.tween_property(m, "albedo_color:a", 0.33, 6.0)
		tw.tween_interval(55.0)
		tw.tween_property(m, "albedo_color:a", 0.0, 10.0)
	get_tree_free_later(_rainbow, 80.0)


func get_tree_free_later(n: Node, secs: float) -> void:
	n.get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


func apply_time() -> void:
	var e := sin(TAU * (time_of_day - 0.25)) * 62.0           # sun elevation in degrees
	sun.rotation_degrees = Vector3(-e, -35.0 + (time_of_day - 0.5) * 140.0, 0.0)
	var day_k := clampf((e + 4.0) / 26.0, 0.0, 1.0)             # 0 below the horizon .. 1 high sun
	var dusk_k := clampf(1.0 - absf(e) / 14.0, 0.0, 1.0)         # strongest at sunrise / sunset
	night = clampf(1.0 - (e + 10.0) / 14.0, 0.0, 1.0)
	sun.light_energy = 1.1 * day_k
	sun.light_color = Color(1.0, 0.88, 0.68).lerp(Color(1.0, 0.55, 0.28), dusk_k)
	if e < 0.0:        # moonlight: the same light, cool and dim, shining from above
		sun.rotation_degrees.x = -42.0
		sun.light_color = Color(0.55, 0.65, 1.0)
		sun.light_energy = maxf(sun.light_energy, 0.3 * night)
	var top_day := Color(0.26, 0.47, 0.80)
	var top_night := Color(0.02, 0.03, 0.09)
	var hor_day := Color(0.88, 0.78, 0.62)
	var hor_dusk := Color(0.96, 0.52, 0.30)
	var hor_night := Color(0.05, 0.06, 0.12)
	sky_mat.sky_top_color = top_night.lerp(top_day, day_k)
	var hor := hor_night.lerp(hor_day, day_k)
	sky_mat.sky_horizon_color = hor.lerp(hor_dusk, dusk_k * 0.8)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.58, 0.46, 0.32).lerp(Color(0.03, 0.03, 0.05), night)
	environment.ambient_light_color = Color(0.74, 0.64, 0.52).lerp(Color(0.16, 0.20, 0.38), night)
	environment.ambient_light_energy = lerpf(1.0, 0.55, night)
	environment.fog_light_color = Color(0.84, 0.74, 0.60).lerp(Color(0.06, 0.08, 0.16), night)
	environment.tonemap_exposure = lerpf(0.85, 1.1, night)
	# weather: overcast, desaturated, foggier, with a lightning flash
	if rain > 0.0 or _flash > 0.0:
		sun.light_energy *= 1.0 - 0.6 * rain
		sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.32, 0.35, 0.4) * (1.0 - night * 0.8), rain * 0.8)
		sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color(0.45, 0.47, 0.5) * (1.0 - night * 0.8), rain * 0.8)
		environment.fog_density = lerpf(_base_fog, 0.0038, rain)
		environment.ambient_light_energy *= 1.0 - 0.25 * rain
		environment.adjustment_saturation = lerpf(1.1, 0.8, rain)
		if _flash > 0.0:
			environment.ambient_light_energy += 2.5 * _flash
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.9, 0.92, 1.0), _flash * 0.6)
	else:
		environment.fog_density = _base_fog
		environment.adjustment_saturation = 1.1
