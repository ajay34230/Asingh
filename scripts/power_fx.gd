class_name PowerFx
extends Node3D
## Visual effects for the power-ups and for sprinting, attached to the player:
##   speed  : "Flash" look. Yellow lightning arcs crackle over the body, a glowing streak trail follows,
##            a yellow light flickers and a bright flash fires when it is picked up.
##   power  : fiery orange aura, embers rising and a pulsing red-orange light.
##   shield : a shimmering blue bubble with a cool light.
##   plain sprint: a faint white wind streak and a light dust kick.

var player: Player
var _light: OmniLight3D
var _arcs: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _arc_mat: StandardMaterial3D
var _trail: CPUParticles3D
var _embers: CPUParticles3D
var _aura: MeshInstance3D
var _aura_mat: StandardMaterial3D
var _bubble: MeshInstance3D
var _bubble_mat: StandardMaterial3D
var _arc_t := 0.0
var _flash := 0.0
var _had := {}
var speed_on := false
var power_on := false
var shield_on := false


func _init(p: Player) -> void:
	player = p
	name = "PowerFx"


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.0, 0)
	_light.omni_range = 7.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_arc_mesh = ImmediateMesh.new()
	_arc_mat = StandardMaterial3D.new()
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.albedo_color = Color(1.0, 0.95, 0.5)
	_arc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_arc_mat.no_depth_test = false
	_arc_mat.vertex_color_use_as_albedo = false
	_arcs = MeshInstance3D.new()
	_arcs.mesh = _arc_mesh
	_arcs.material_override = _arc_mat
	_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arcs.top_level = false
	add_child(_arcs)
	_trail = _make_particles(Color(1.0, 0.92, 0.45), 0.05, 0.4, 28)
	_trail.local_coords = false
	add_child(_trail)
	_embers = _make_particles(Color(1.0, 0.5, 0.12), 0.05, 1.0, 22)
	_embers.local_coords = false
	_embers.gravity = Vector3(0, 2.2, 0)
	_embers.direction = Vector3.UP
	_embers.spread = 35.0
	_embers.initial_velocity_min = 0.4
	_embers.initial_velocity_max = 1.2
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.5
	_embers.position = Vector3(0, 0.9, 0)
	add_child(_embers)
	_aura_mat = _glow_material(Color(1.0, 0.5, 0.12), 0.0)
	_aura = _make_shell(_aura_mat, Vector3(0.95, 1.25, 0.95))
	add_child(_aura)
	_bubble_mat = _glow_material(Color(0.35, 0.65, 1.0), 0.0)
	_bubble = _make_shell(_bubble_mat, Vector3(1.15, 1.35, 1.15))
	add_child(_bubble)
	player.powerup_changed.connect(_on_power_changed)
	_on_power_changed()


func _glow_material(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


func _make_shell(m: Material, r: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.scale = r
	mi.position = Vector3(0, 0.95, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func _make_particles(c: Color, size: float, life: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.gravity = Vector3.ZERO
	p.explosiveness = 0.0
	var q := QuadMesh.new()
	q.size = Vector2(size, size * 6.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(c.r, c.g, c.b, 0.6), Color(c.r, c.g, c.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = g
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	return p


func _on_power_changed() -> void:
	for k in ["speed", "power", "shield"]:
		var has := player.power.has(k)
		if has and not bool(_had.get(k, false)):
			_flash = 1.0                       # picked up: a burst of light
			Sfx.ui("powerup", -6.0)
		_had[k] = has
	speed_on = player.power.has("speed")
	power_on = player.power.has("power")
	shield_on = player.power.has("shield")


func _bolt(p0: Vector3, dir: Vector3, length: float, jitter: float) -> void:
	var prev := p0
	var segs := 5
	for i in segs:
		var nxt := p0 + dir * length * float(i + 1) / segs + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter
		_arc_mesh.surface_add_vertex(prev)
		_arc_mesh.surface_add_vertex(nxt)
		prev = nxt


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var moving := hv.length() > 2.0 and not player.locked
	var t := Time.get_ticks_msec() * 0.001
	_flash = maxf(0.0, _flash - delta * 2.5)
	# light: flicker for speed, pulse for power, steady glow for shield; flash on pickup
	var e := 0.0
	var col := Color(1, 0.9, 0.4)
	if speed_on:
		e = 1.4 + 1.2 * absf(sin(t * 38.0)) * (1.0 if moving else 0.5)
		col = Color(1.0, 0.92, 0.4)
	elif power_on:
		e = 1.0 + 0.5 * sin(t * 5.0)
		col = Color(1.0, 0.45, 0.15)
	elif shield_on:
		e = 0.9
		col = Color(0.4, 0.7, 1.0)
	_light.light_color = col
	_light.light_energy = e + 6.0 * _flash
	# lightning arcs (speed)
	_arc_t -= delta
	if speed_on and _arc_t <= 0.0:
		_arc_t = 0.045
		_arc_mesh.clear_surfaces()
		_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _arc_mat)
		var n := 6 if moving else 3
		for i in n:
			var a := randf() * TAU
			var h := randf_range(0.1, 1.7)
			var p0 := Vector3(cos(a) * 0.35, h, sin(a) * 0.35)
			var d := Vector3(cos(a), randf_range(-0.6, 0.6), sin(a)).normalized()
			_bolt(p0, d, randf_range(0.5, 1.3), 0.14)
		_arc_mesh.surface_end()
	elif not speed_on and _arc_mesh.get_surface_count() > 0:
		_arc_mesh.clear_surfaces()
	_arcs.visible = speed_on
	# streak trail: speed power-up = strong yellow; plain sprint = faint white wisps
	var sprint := hv.length() > 4.6
	_trail.emitting = (speed_on and moving) or (sprint and not speed_on)
	if _trail.emitting:
		var back := -hv.normalized() if hv.length() > 0.1 else Vector3.BACK
		_trail.direction = back
		_trail.spread = 12.0 if speed_on else 25.0
		_trail.initial_velocity_min = 3.0 if speed_on else 1.0
		_trail.initial_velocity_max = 7.0 if speed_on else 2.5
		_trail.amount = 28 if speed_on else 8
		_trail.position = Vector3(randf_range(-0.3, 0.3), randf_range(0.15, 1.6), 0.0) if speed_on else Vector3(0, 0.1, 0)
		var c := Color(1.0, 0.92, 0.45) if speed_on else Color(1, 1, 1, 0.5)
		(_trail.mesh.material as StandardMaterial3D).albedo_color = c
	# power: aura + embers
	_embers.emitting = power_on
	_aura.visible = power_on
	if power_on:
		_aura_mat.albedo_color.a = 0.16 + 0.08 * sin(t * 6.0)
		_aura.scale = Vector3(0.95, 1.25, 0.95) * (1.0 + 0.04 * sin(t * 9.0))
	# shield: bubble
	_bubble.visible = shield_on
	if shield_on:
		_bubble_mat.albedo_color.a = 0.14 + 0.07 * sin(t * 3.0 + 1.0)
