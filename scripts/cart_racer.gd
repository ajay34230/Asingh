class_name CartRacer
extends Node3D
## One racing bull cart: a cart pulled by two galloping bulls along the Sand Circuit. Movement is
## along the track (distance `s`, sideways offset `lat`), but the body follows the real terrain:
## it pitches and rolls on slopes, bounces on bumps, and flies off the bumps at speed. Carts collide
## with each other, slash rivals with side blades, show a health bar, and burst into wreckage and
## flames when destroyed.

signal destroyed(racer: CartRacer)

const GRAVITY := 24.0
const MAX_LAT := 4.8
const BLADE_RANGE_S := 4.6
const BLADE_RANGE_L := 3.4

var terrain: TerrainBuilder
var is_player := false
var racer_name := "Rival"
var s := 0.0
var lat := 0.0
var speed := 0.0
var max_speed := 14.0
var hp := 100.0
var max_hp := 100.0
var lap := 0
var finished := false
var finish_time := 0.0
var dead := false
var boost_t := 0.0
var boost_cd := 0.0
var atk_cd := 0.0
var blade_damage := 22.0
var flash := 0.0
var seat: Node3D
var jumped := false            # true while airborne (read by the race for effects)
var tint := Color(1, 1, 1)

var _y := 0.0
var _vy := 0.0
var _prev_gy := 0.0
var _airborne := false
var _basis := Basis()
var _sq := 0.0
var _sqv := 0.0
var _body: Node3D
var _bulls: Array[Animal] = []
var _driver: RealHuman
var _blades: Array[Node3D] = []
var _bar_bg: MeshInstance3D
var _bar_fg: MeshInstance3D
var _dust: GPUParticles3D
var _steer_s := 0.0
var _ai_lat := 0.0
var _ai_t := 0.0
var _rng := RandomNumberGenerator.new()
var _wreck_bulls: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _time := 0.0
var prev_s := 0.0


func setup(ter: TerrainBuilder, label: String, color: Color, driver_preset: Dictionary, player_cart: bool) -> CartRacer:
	terrain = ter
	racer_name = label
	tint = color
	is_player = player_cart
	name = "Racer_" + label
	_rng.seed = hash(label)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var cart := (load("res://assets/props/cart.glb") as PackedScene).instantiate() as Node3D
	cart.scale = Vector3.ONE * 1.6
	cart.rotation.y = PI * 0.5
	_body.add_child(cart)
	for m in cart.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = d.albedo_color * color
				mi.set_surface_override_material(i, d)
	# colourful canopy and pennant so each cart is easy to tell apart
	var cloth := PropFactory.material(color, 0.9)
	PropFactory.box(_body, Vector3(2.0, 0.08, 1.4), Vector3(0, 2.55, 1.2), cloth, Vector3.ZERO, false, false)
	for sx in [-0.95, 0.95]:
		PropFactory.box(_body, Vector3(0.07, 1.4, 0.07), Vector3(sx, 1.85, 0.6), PropFactory.wood(), Vector3.ZERO, false, false)
	PropFactory.box(_body, Vector3(0.7, 0.4, 0.04), Vector3(0, 3.0, 0.4), cloth, Vector3.ZERO, false, false)
	PropFactory.box(_body, Vector3(0.04, 1.0, 0.04), Vector3(-0.3, 2.7, 0.4), PropFactory.wood(), Vector3.ZERO, false, false)
	# yoke pole to the bulls
	PropFactory.box(_body, Vector3(0.12, 0.12, 3.2), Vector3(0, 0.95, -1.7), PropFactory.wood(), Vector3.ZERO, false, false)
	# side blades (the weapons): pivot at the cart's side, spiked iron bar
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 1.05, 0.75, 0.9)
		_body.add_child(pivot)
		PropFactory.box(pivot, Vector3(0.12, 0.08, 2.4), Vector3(side * 0.55, 0, 0), PropFactory.iron(), Vector3.ZERO, false, false)
		for k in 5:
			PropFactory.box(pivot, Vector3(0.18, 0.06, 0.1), Vector3(side * 1.0, 0, -0.95 + k * 0.48), PropFactory.iron(), Vector3(0, side * 25.0, 0), false, false)
		_blades.append(pivot)
	# seat and driver
	seat = Node3D.new()
	seat.position = Vector3(0, 1.3, 1.0)
	_body.add_child(seat)
	if not is_player:
		_driver = RealHuman.new().setup(driver_preset, label)
		_driver.mode = "idle"
		seat.add_child(_driver)
	# two bulls (children of the racer, posed on the ground each frame)
	for i in 2:
		var b := Animal.new().setup("bull", terrain, null, Vector3.ZERO, 0.0, Color(0.95, 0.9, 0.85).lerp(color, 0.25))
		b.driven = true
		add_child(b)
		b.position = Vector3(-0.62 + 1.24 * i, 0, -3.5)
		b._play(b._gallop)
		_bulls.append(b)
	# health bar
	_bar_bg = _bar_quad(Vector2(1.7, 0.2), Color(0.05, 0.05, 0.05, 0.85))
	_bar_fg = _bar_quad(Vector2(1.6, 0.14), Color(0.2, 0.9, 0.25))
	_bar_fg.position.z = 0.01
	_bar_bg.add_child(_bar_fg)
	add_child(_bar_bg)
	_bar_bg.position = Vector3(0, 3.8, 0)
	_dust = _make_dust()
	add_child(_dust)
	return self


func _bar_quad(size: Vector2, col: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.no_depth_test = true
	m.render_priority = 5
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static var _dot: GradientTexture2D

static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 64
		_dot.height = 64
	return _dot


func _make_dust() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 1)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, -1.0, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.82, 0.7, 0.5, 0.0), Color(0.82, 0.7, 0.5, 0.5), Color(0.82, 0.7, 0.5, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	q.material = m
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.1
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 8, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = pm
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.15, 1.8)
	p.emitting = false
	return p


## Put the cart on the track at distance s0 and lateral offset l0, standing still.
func place(s0: float, l0: float) -> void:
	s = fposmod(s0, TerrainBuilder.track_length())
	prev_s = s
	lat = l0
	speed = 0.0
	var pos := _world_xz()
	_y = terrain.sample_height(pos.x, pos.y)
	_prev_gy = _y
	_vy = 0.0
	global_position = Vector3(pos.x, _y, pos.y)
	_basis = _target_basis(pos)
	_apply_pose(0.0)


func _world_xz() -> Vector2:
	return TerrainBuilder.track_point(s) + TerrainBuilder.track_right(s) * lat


func _heading() -> Vector2:
	var t := TerrainBuilder.track_tangent(s)
	return t.rotated(-_steer_s * 0.12)


func _ground(p: Vector2) -> float:
	return terrain.sample_height(p.x, p.y)


func _target_basis(pos: Vector2) -> Basis:
	var h := _heading()
	var f2 := Vector2(h.x, h.y)
	var r2 := Vector2(-f2.y, f2.x)
	var pf := pos + f2 * 1.4
	var pb := pos - f2 * 1.4
	var pr := pos + r2 * 0.9
	var pl := pos - r2 * 0.9
	var fv := Vector3(pf.x - pb.x, _ground(pf) - _ground(pb), pf.y - pb.y)
	var rv := Vector3(pr.x - pl.x, _ground(pr) - _ground(pl), pr.y - pl.y)
	var n := rv.cross(fv).normalized()
	if n.y < 0.3:
		n = Vector3.UP
	return Basis.looking_at(fv.normalized(), n)


## One simulation step. `steer` -1..1 (right positive), `brake` slows down, `racing` false = held at the start.
func step(delta: float, steer: float, brake: bool, racing: bool, boost_pressed: bool) -> void:
	_time += delta
	if dead:
		_update_wreck(delta)
		return
	atk_cd = maxf(0.0, atk_cd - delta)
	boost_cd = maxf(0.0, boost_cd - delta)
	boost_t = maxf(0.0, boost_t - delta)
	flash = maxf(0.0, flash - delta * 3.0)
	if racing and not finished:
		if boost_pressed and boost_cd <= 0.0:
			boost_t = 1.6
			boost_cd = 8.0
		var vmax := max_speed * (1.45 if boost_t > 0.0 else 1.0)
		if brake:
			speed = maxf(speed - 14.0 * delta, 3.0)
		else:
			speed = move_toward(speed, vmax, (6.5 if boost_t <= 0.0 else 16.0) * delta)
		_steer_s = lerpf(_steer_s, steer, 1.0 - exp(-7.0 * delta))
		lat = clampf(lat + _steer_s * (6.5 + speed * 0.12) * delta, -MAX_LAT, MAX_LAT)
	elif finished:
		speed = move_toward(speed, 4.0, 5.0 * delta)
		_steer_s = lerpf(_steer_s, 0.0, 1.0 - exp(-4.0 * delta))
	else:
		speed = 0.0
		_steer_s = 0.0
	prev_s = s
	s += speed * delta
	var P := TerrainBuilder.track_length()
	if s >= P:
		s -= P
		lap += 1
	var pos := _world_xz()
	# vertical motion: follows the ground, but flies off bumps
	var gy := _ground(pos)
	_y += _vy * delta
	_vy -= GRAVITY * delta
	if _y <= gy:
		if _airborne and _vy < -2.5:
			_land(-_vy)
		_y = gy
		_airborne = false
		_vy = clampf((gy - _prev_gy) / maxf(delta, 0.001), -4.0, 10.0)
	else:
		_airborne = (_y - gy) > 0.3
	jumped = _airborne
	_prev_gy = gy
	global_position = Vector3(pos.x, _y, pos.y)
	var tb := _target_basis(pos)
	_basis = _basis.slerp(tb, 1.0 - exp(-(5.0 if _airborne else 14.0) * delta)).orthonormalized()
	# suspension spring (visual bounce)
	_sqv += (-120.0 * _sq - 9.0 * _sqv) * delta
	_sq += _sqv * delta
	_apply_pose(delta)
	if _driver != null:
		_driver.animate(delta, 0.0, true)
	_dust.emitting = (not _airborne) and speed > 4.0 and not finished
	_dust.amount_ratio = clampf(speed / max_speed, 0.2, 1.0)
	_update_bar()


func _apply_pose(_delta: float) -> void:
	var lean := _steer_s * 0.08
	var b := _basis * Basis(Vector3.FORWARD, lean)
	var bob := sin(_time * (6.0 + speed * 0.6)) * 0.03 * clampf(speed / max_speed, 0.0, 1.0)
	_body.global_transform = Transform3D(b, global_position + Vector3(0, _sq * 0.35 + bob + 0.05, 0))
	# bulls: posed on the ground ahead of the cart, galloping in time with the speed
	var h := Vector2(-b.z.x, -b.z.z).normalized() if (b.z.x != 0.0 or b.z.z != 0.0) else Vector2(0, -1)
	var airlift := maxf(0.0, _y - _ground(Vector2(global_position.x, global_position.z))) * 0.7
	for i in _bulls.size():
		var a := _bulls[i]
		var bp := Vector2(global_position.x, global_position.z) + h * 3.6 + Vector2(-h.y, h.x) * (-0.62 + 1.24 * i) * 1.0
		var by := _ground(bp) + airlift
		a.global_position = Vector3(bp.x, by, bp.y)
		var ahead := bp + h * 1.2
		var behind := bp - h * 1.2
		var fv := Vector3(h.x * 2.4, _ground(ahead) - _ground(behind), h.y * 2.4)
		a.global_transform.basis = Basis.looking_at(fv.normalized(), Vector3.UP)
		a.global_position.y += absf(sin(_time * (5.0 + speed * 0.45) + i * 1.7)) * 0.07 * clampf(speed / max_speed, 0.0, 1.0)
		if a._anim != null:
			var want: String = a._gallop if speed > 0.5 else a._idle
			if a._anim.current_animation != want:
				a._anim.play(want, 0.2)
			a._anim.speed_scale = clampf(speed / 7.5, 0.5, 2.2)


func _land(impact: float) -> void:
	_sq = minf(0.45, impact * 0.05)
	_sqv = 0.0
	Sfx.at("hit_thud", global_position, -4.0 + minf(impact, 8.0) * 0.4, 0.8)
	_puff(global_position, 14)


func _puff(at: Vector3, n: int) -> void:
	var p := _make_dust()
	p.one_shot = true
	p.amount = n
	p.explosiveness = 0.9
	p.position = Vector3.ZERO
	get_parent().add_child(p)
	p.global_position = at + Vector3(0, 0.3, 0)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


func _update_bar() -> void:
	var f := clampf(hp / max_hp, 0.0, 1.0)
	_bar_fg.scale.x = maxf(f, 0.001)
	_bar_fg.position.x = -(1.0 - f) * 0.8
	var m := (_bar_fg.mesh as QuadMesh).material as StandardMaterial3D
	m.albedo_color = Color(0.9, 0.2, 0.15).lerp(Color(0.25, 0.9, 0.3), f)
	_bar_bg.visible = not is_player


## Distance along the track, counting laps (used to rank the racers).
func progress() -> float:
	return lap * TerrainBuilder.track_length() + s


## Slash both sides. Returns the rivals that were hit.
func attack(rivals: Array) -> Array:
	if dead or atk_cd > 0.0 or finished:
		return []
	atk_cd = 1.4
	var hit: Array = []
	for i in _blades.size():
		var pv := _blades[i]
		var side := -1.0 if i == 0 else 1.0
		var tw := pv.create_tween()
		tw.tween_property(pv, "rotation:y", side * -0.9, 0.12)
		tw.tween_property(pv, "rotation:y", 0.0, 0.3)
	Sfx.at("swing", global_position, -6.0, 1.4)
	for r in rivals:
		var o := r as CartRacer
		if o == self or o.dead:
			continue
		var ds := _delta_s(o.s, s)
		var dl := o.lat - lat
		if absf(ds) < BLADE_RANGE_S and absf(dl) < BLADE_RANGE_L:
			hit.append(o)
			o.take_hit(blade_damage, signf(dl) if dl != 0.0 else 1.0)
	return hit


static func _delta_s(a: float, b: float) -> float:
	var P := TerrainBuilder.track_length()
	return fposmod(a - b + P * 0.5, P) - P * 0.5


func take_hit(amount: float, from_side: float) -> void:
	if dead:
		return
	hp -= amount
	flash = 1.0
	lat = clampf(lat + from_side * 1.1, -MAX_LAT, MAX_LAT)
	speed *= 0.9
	_sq = 0.2
	Sfx.at("hit_thud", global_position, -2.0, 1.1)
	_sparks(global_position + Vector3(from_side * -1.0, 1.0, 0.8), Color(1.0, 0.75, 0.3))
	if hp <= 0.0:
		_explode()


## Cart-on-cart bump: both lose speed and a little health; pushed apart.
func bump(other: CartRacer, rel_speed: float) -> void:
	var dl := lat - other.lat
	var push := (0.6 if dl >= 0.0 else -0.6)
	lat = clampf(lat + push, -MAX_LAT, MAX_LAT)
	other.lat = clampf(other.lat - push, -MAX_LAT, MAX_LAT)
	var dmg := clampf(rel_speed * 0.5, 1.5, 5.0)
	if _delta_s(s, other.s) < 0.0:
		speed *= 0.85
	else:
		other.speed *= 0.85
	hp -= dmg
	other.hp -= dmg
	_sq = 0.15
	other._sq = 0.15
	Sfx.at("hit_thud", global_position, -3.0, 0.7)
	_sparks((global_position + other.global_position) * 0.5 + Vector3(0, 0.9, 0), Color(1.0, 0.85, 0.5))
	if hp <= 0.0:
		_explode()
	if other.hp <= 0.0:
		other._explode()


func _sparks(at: Vector3, col: Color) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -12.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	q.material = m
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 8, 12))
	p.process_material = pm
	p.draw_pass_1 = q
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


## Destruction: the cart bursts into planks and wheels, flames and smoke; the bulls bolt free.
func _explode() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	speed = 0.0
	Sfx.at("anvil", global_position, 0.0, 0.5)
	Sfx.at("hit_thud", global_position, 2.0, 0.5)
	_sparks(global_position + Vector3(0, 1.2, 0), Color(1.0, 0.55, 0.15))
	_puff(global_position, 30)
	_bar_bg.visible = false
	_dust.emitting = false
	# the intact cart is replaced by debris plus a charred shell
	for c in _body.get_children():
		if c is Node3D and c != seat:
			(c as Node3D).visible = false
	var wood := PropFactory.wood()
	var char_m := PropFactory.material(Color(0.08, 0.06, 0.05), 1.0)
	PropFactory.box(_body, Vector3(1.8, 0.35, 2.8), Vector3(0, 0.45, 0.9), char_m, Vector3.ZERO, false, false)
	for i in 14:
		var piece := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(_rng.randf_range(0.2, 1.0), 0.12, _rng.randf_range(0.12, 0.35))
		piece.mesh = bm
		piece.material_override = wood if i % 3 else char_m
		get_parent().add_child(piece)
		piece.global_position = global_position + Vector3(_rng.randf_range(-0.8, 0.8), 1.0, _rng.randf_range(-0.5, 1.8))
		_debris.append({"n": piece, "v": Vector3(_rng.randf_range(-5, 5), _rng.randf_range(5, 10), _rng.randf_range(-5, 5)), "w": Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8)), "t": 0.0})
	for k in 2:
		var wheel := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.55
		cm.height = 0.12
		wheel.mesh = cm
		wheel.material_override = wood
		wheel.rotation_degrees = Vector3(0, 0, 90)
		get_parent().add_child(wheel)
		wheel.global_position = global_position + Vector3((-1.0 if k == 0 else 1.0), 0.6, 1.0)
		_debris.append({"n": wheel, "v": Vector3((-1.0 if k == 0 else 1.0) * 6.0, 7.0, _rng.randf_range(-3, 3)), "w": Vector3(6, 0, 3), "t": 0.0})
	# flames and a long column of black smoke from the wreck
	var smoke := Atmosphere.make_smoke(get_parent(), global_position + Vector3(0, 1.0, 1.0), 1.8)
	smoke.lifetime = 8.0
	_sparks(global_position + Vector3(0, 0.8, 1.0), Color(1.0, 0.4, 0.1))
	# bulls break loose and run away from the track
	for a in _bulls:
		var away := Vector2(a.global_position.x - TerrainBuilder.TRACK_C.x, a.global_position.z - TerrainBuilder.TRACK_C.y).normalized()
		_wreck_bulls.append({"a": a, "dir": Vector3(away.x, 0, away.y), "t": 0.0})
	if _driver != null:
		_driver.visible = false
	destroyed.emit(self)


func _update_wreck(delta: float) -> void:
	for d in _debris:
		var n: Node3D = d["n"]
		if not is_instance_valid(n):
			continue
		d["t"] += delta
		var v: Vector3 = d["v"]
		v.y -= GRAVITY * delta
		n.global_position += v * delta
		n.rotation += (d["w"] as Vector3) * delta
		var gy := _ground(Vector2(n.global_position.x, n.global_position.z))
		if n.global_position.y < gy + 0.1:
			n.global_position.y = gy + 0.1
			v = Vector3(v.x * 0.3, absf(v.y) * 0.25 if absf(v.y) > 1.5 else 0.0, v.z * 0.3)
			d["w"] = (d["w"] as Vector3) * 0.5
		d["v"] = v
	for w in _wreck_bulls:
		var a: Animal = w["a"]
		w["t"] += delta
		if w["t"] < 4.0:
			a.global_position += (w["dir"] as Vector3) * 7.0 * delta
			a.global_position.y = _ground(Vector2(a.global_position.x, a.global_position.z))
			a.global_transform.basis = Basis.looking_at(w["dir"], Vector3.UP)
		elif a._anim != null and a._anim.current_animation != a._idle:
			a._anim.play(a._idle, 0.3)


func cleanup() -> void:
	for d in _debris:
		if is_instance_valid(d["n"]):
			(d["n"] as Node).queue_free()
	queue_free()


## Simple driver for the rival carts. Returns the steering command (-1..1).
func ai_steer(delta: float, player_cart: CartRacer) -> float:
	_ai_t -= delta
	if _ai_t <= 0.0:
		_ai_t = _rng.randf_range(1.2, 2.8)
		_ai_lat = _rng.randf_range(-3.6, 3.6)
		if player_cart != null and not player_cart.dead:
			var ds := _delta_s(player_cart.s, s)
			if absf(ds) < 14.0 and _rng.randf() < 0.65:
				_ai_lat = clampf(player_cart.lat + _rng.randf_range(-1.8, 1.8), -MAX_LAT, MAX_LAT)   # go for the player
	return clampf((_ai_lat - lat) * 0.8, -1.0, 1.0)
