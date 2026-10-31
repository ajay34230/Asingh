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
	q.material = m
	p.mesh = q
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	var tm := parent.get_tree().create_timer(1.0)
	tm.timeout.connect(p.queue_free)
	return p
