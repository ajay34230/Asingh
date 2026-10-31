class_name NightLife
extends Node3D
## X1: warm flickering lantern light after dusk and fireflies around the player at night.
## Lights only exist for the nearest few lamps (mobile budget) and fade with Atmosphere.night.

const MAX_LIGHTS := 6

var atmo: Atmosphere
var player: Node3D
var points: Array[Vector3] = []
var lights: Array[OmniLight3D] = []
var flies: CPUParticles3D
var level := 0.0      # 0..1 how strongly the night effects are on right now
var _t := 0.0


func _ready() -> void:
	for i in MAX_LIGHTS:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.38)
		l.omni_range = 9.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		lights.append(l)
	flies = CPUParticles3D.new()
	flies.amount = 28
	flies.lifetime = 5.0
	flies.local_coords = false
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(16, 1.6, 16)
	flies.direction = Vector3(0, 1, 0)
	flies.spread = 180.0
	flies.initial_velocity_min = 0.2
	flies.initial_velocity_max = 0.6
	flies.gravity = Vector3.ZERO
	flies.scale_amount_min = 0.05
	flies.scale_amount_max = 0.09
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.85, 1.0, 0.45)
	m.emission_enabled = true
	m.emission = Color(0.8, 1.0, 0.35)
	m.emission_energy_multiplier = 3.0
	q.material = m
	flies.mesh = q
	flies.emitting = false
	add_child(flies)


func _process(delta: float) -> void:
	_t += delta
	level = 0.0 if atmo == null else clampf((atmo.night - 0.25) / 0.5, 0.0, 1.0)
	if atmo != null and atmo.rain > 0.5:
		level *= 0.7
	if player != null:
		flies.global_position = player.global_position + Vector3(0, 0.8, 0)
	flies.emitting = level > 0.2
	# the nearest lamps get a real light; the rest stay as glowing glass only
	var order: Array[Vector3] = points.duplicate()
	if player != null:
		var pp := player.global_position
		order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(pp) < b.distance_squared_to(pp))
	for i in lights.size():
		var l := lights[i]
		if i < order.size() and level > 0.02:
			l.visible = true
			l.global_position = order[i]
			var flick := 0.88 + 0.12 * sin(_t * 9.0 + float(i) * 2.3) * sin(_t * 3.7 + float(i))
			l.light_energy = 1.6 * level * flick
		else:
			l.visible = false
			l.light_energy = 0.0
