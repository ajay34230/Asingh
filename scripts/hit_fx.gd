class_name HitFx
## X8: short one-shot spark and dust bursts at the point of impact. Frees itself.

static func burst(parent: Node, at: Vector3, heavy: bool = false, tint: Color = Color(1.0, 0.82, 0.45)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18 if heavy else 9
	p.lifetime = 0.45
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5 if heavy else 3.8
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = tint
	m.emission_energy_multiplier = 2.5
	SoftDot.apply(m)
	q.material = m
	p.mesh = q
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	var tm := parent.get_tree().create_timer(1.0)
	tm.timeout.connect(p.queue_free)
	return p


static var _dust_meshes := {}


## A soft puff of dust kicked up from the ground (jumps, landings, sprinting feet).
static func dust(parent: Node, at: Vector3, amount: int = 10, size: float = 0.35, tint: Color = Color(0.78, 0.68, 0.52, 0.55)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.25, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var grow := Curve.new()
	grow.max_value = 2.0
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	var key := "%.2f" % size
	var q: QuadMesh = _dust_meshes.get(key)
	if q == null:
		q = QuadMesh.new()
		q.size = Vector2(size, size)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_color = tint
		SoftDot.apply(m)
		q.material = m
		_dust_meshes[key] = q
	p.mesh = q
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	var tm := parent.get_tree().create_timer(1.4)
	tm.timeout.connect(p.queue_free)
	return p
