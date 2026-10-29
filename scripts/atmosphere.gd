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
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 0.9

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
	if not running or sun == null:
		return
	time_of_day = fposmod(time_of_day + delta / day_length, 1.0)
	apply_time()


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
