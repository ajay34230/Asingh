class_name AmbientLife
extends Node3D
## X3/X4: water ripples where the player steps in water, plus daytime butterflies near pond/forest/town
## and drifting leaves in the forest. Everything is cheap: one particle node each, rings freed after ~1 s.

var player: Player
var sfx: Sfx
var atmo: Atmosphere
var butterflies: CPUParticles3D
var leaves: CPUParticles3D
var ripples := 0       # total ripples spawned (selftest)
var _zone := "desert"
var _zone_t := 0.0


func _ready() -> void:
	butterflies = _particles(10, Color(1.0, 0.65, 0.2), 0.14, Vector3(14, 1.2, 14), 0.5, 1.4, 6.0)
	butterflies.color_ramp = null
	leaves = _particles(16, Color(0.62, 0.5, 0.2), 0.1, Vector3(14, 3.0, 14), 0.05, 0.3, 8.0)
	leaves.gravity = Vector3(0.3, -0.35, 0.1)
	if player != null:
		player.stepped.connect(_on_step)


func _particles(n: int, col: Color, size: float, ext: Vector3, v0: float, v1: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 180.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector3.ZERO
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	q.material = m
	p.mesh = q
	p.color_initial_ramp = _palette(col)
	p.emitting = false
	add_child(p)
	return p


func _palette(base: Color) -> Gradient:
	var g := Gradient.new()
	if base.r > 0.9:   # butterflies: orange, yellow, white, blue
		g.colors = PackedColorArray([Color(1, 0.6, 0.15), Color(1, 0.9, 0.3), Color(0.95, 0.95, 1), Color(0.4, 0.6, 1)])
	else:              # leaves: ochre, olive, brown
		g.colors = PackedColorArray([Color(0.62, 0.5, 0.2), Color(0.45, 0.5, 0.2), Color(0.5, 0.32, 0.15), Color(0.7, 0.6, 0.25)])
	g.offsets = PackedFloat32Array([0.0, 0.34, 0.67, 1.0])
	return g


func _process(delta: float) -> void:
	if player == null:
		return
	var at := player.global_position
	butterflies.global_position = at + Vector3(0, 0.8, 0)
	leaves.global_position = at + Vector3(0, 2.0, 0)
	_zone_t -= delta
	if _zone_t <= 0.0:
		_zone_t = 1.0
		_zone = sfx._zone_at(at) if sfx != null else "desert"
	var day := atmo == null or (atmo.night < 0.2 and atmo.rain < 0.2)
	butterflies.emitting = day and (_zone == "pond" or _zone == "forest" or _zone == "town")
	leaves.emitting = _zone == "forest" and (atmo == null or atmo.rain < 0.5)


func _on_step(run: bool) -> void:
	if sfx == null or sfx._surface_at(player.global_position) != "water":
		return
	spawn_ripple(player.global_position, 1.6 if run else 1.1)


func spawn_ripple(at: Vector3, size: float) -> MeshInstance3D:
	ripples += 1
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.5
	t.rings = 24
	t.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.97, 1.0, 0.55)
	t.material = mat
	m.mesh = t
	m.scale = Vector3(0.2, 0.02, 0.2)
	add_child(m)
	m.global_position = at + Vector3(0, 0.04, 0)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(size, 0.02, size), 0.9)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(m.queue_free)
	return m
