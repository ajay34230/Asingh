class_name StoryFX
extends RefCounted
## Shared cinematic effects for story beats: the golden "sun burst" (shock ring, twelve rays,
## sparks, flash light) and a short camera shake.

static func sun_burst(parent: Node3D, at: Vector3, size: float = 1.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	var gold := PropFactory.glow_bronze()
	# twelve rays that stretch outward then fade
	var rays: Array[MeshInstance3D] = []
	for k in 12:
		var ray := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 1.0, 0.04)
		ray.mesh = bm
		ray.material_override = gold
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := k * TAU / 12.0
		ray.rotation = Vector3(0, 0, a - PI * 0.5)
		root.add_child(ray)
		rays.append(ray)
	# shock ring on the ground plane
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	ring.mesh = tm
	ring.material_override = gold
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	ring.scale = Vector3.ONE * 0.1
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.4)
	l.omni_range = 16.0 * size
	l.light_energy = 0.0
	root.add_child(l)
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.5 * size
	p.initial_velocity_max = 6.0 * size
	p.gravity = Vector3(0, -2.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	p.mesh = sm
	p.material_override = gold
	root.add_child(p)
	p.emitting = true
	var tw := root.create_tween().set_parallel(true)
	for i in rays.size():
		var r := rays[i]
		var a := i * TAU / 12.0
		r.position = Vector3(cos(a), sin(a), 0) * 0.3
		r.scale = Vector3(1, 0.2, 1)
		tw.tween_property(r, "scale", Vector3(1, 3.0 * size, 1), 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "position", Vector3(cos(a), sin(a), 0) * 2.4 * size, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "scale:x", 0.01, 0.5).set_delay(0.9)
	tw.tween_property(ring, "scale", Vector3.ONE * 6.0 * size, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale:y", 0.01, 0.3).set_delay(0.7)
	tw.tween_property(l, "light_energy", 6.0, 0.15)
	tw.tween_property(l, "light_energy", 0.0, 1.0).set_delay(0.3)
	tw.chain().tween_callback(root.queue_free)
	Sfx.at("chime", at, 0.0, 0.9)


static func shake(player: Player, amount: float = 0.15, dur: float = 0.5) -> void:
	if player == null or player._pivot == null:
		return
	var piv: Node3D = player._pivot
	var base := Vector3(0, 1.55, 0)
	var tw := piv.create_tween()
	var n := int(dur / 0.04)
	for i in n:
		var k := 1.0 - float(i) / n
		tw.tween_property(piv, "position", base + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * amount * k, 0.04)
	tw.tween_property(piv, "position", base, 0.05)


## Brief freeze-frame on a heavy blow.
static func hitstop(dur: float) -> void:
	if Engine.time_scale < 0.9:
		return
	Engine.time_scale = 0.12
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.create_timer(dur, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
