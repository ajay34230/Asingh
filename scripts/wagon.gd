class_name Wagon
extends Node3D
## A goods cart drawn by two animals along a looped route: the bailgaadi (two bulls) or the
## uthgaadi (camel-style, the alpaca stand-in). Placeholder ambient life: it just keeps moving.

const ACTIVE_RANGE := 120.0

var terrain: TerrainBuilder
var player: Node3D
var route: Array[Vector2] = []
var speed := 1.3
var _s := 0.0
var _len := 0.0
var _seg: Array[float] = []
var _animals: Array[Animal] = []
var _cart: Node3D
var _heading := 0.0
var open_route := false          # true: runs once from first to last point (rideable cart)
var running := true
var seat: Node3D
var rider: Player
var yields_to_player := false       # slows and rings a bell when the player stands in the road ahead
var driver: Node3D
var blocked := false
var _bell_t := 0.0
var _call_t := 12.0
signal arrived


func setup(ter: TerrainBuilder, ply: Node3D, kind: String, points: Array[Vector2], spd: float) -> Wagon:
	terrain = ter
	player = ply
	route = points
	speed = spd
	name = "Wagon_" + kind
	for i in (route.size() - 1 if open_route else route.size()):
		var d := route[i].distance_to(route[(i + 1) % route.size()])
		_seg.append(d)
		_len += d
	# cart
	_cart = Node3D.new()
	add_child(_cart)
	var cart := (load("res://assets/props/cart.glb") as PackedScene).instantiate() as Node3D
	_cart.add_child(cart)
	cart.scale = Vector3.ONE * 2.4                 # was 1.6: about 1.5 m long next to a 1.75 m bull; now about 2.2 m
	cart.rotation.y = PI            # the model is long along Z with its shafts at +Z (glTF front): turn them to the animals (-Z). PI/2 left it sideways
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.0, 2.3)
	cs.shape = box
	cs.position = Vector3(0, 0.8, -0.3)
	body.add_child(cs)
	_cart.add_child(body)
	# two draught animals ahead of the cart (forward = -Z)
	for i in 2:
		var a := Animal.new().setup(kind, ter, ply, Vector3.ZERO, 0.0)
		a.driven = true
		add_child(a)
		a.position = Vector3(-0.55 + 1.1 * i, 0, -2.6)
		a.play_walk(true)
		_animals.append(a)
	# yoke beam
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.08, 0.1)
	beam.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.33, 0.22, 0.12)
	beam.material_override = wm
	beam.position = Vector3(0, 1.25, -2.4)
	add_child(beam)
	seat = Node3D.new()
	seat.position = Vector3(0, 1.1, 0.2)     # standing on the cart bed behind the shafts
	_cart.add_child(seat)
	# anyone can take the reins: stand on the cart and steer it with the stick
	var take := Interactable.new()
	take.prompt = "Drive the cart"
	take.reach = 3.2
	take.position = Vector3(1.0, 1.0, 0.2)
	take.on_interact = func(by: Node3D, _me: Interactable) -> void:
		if by is Player and not _driving and rider == null:
			start_drive(by as Player)
	_cart.add_child(take)
	_place(0.0)
	return self


## Rideable cart: the player climbs on and is carried to the end of the route.
func start_run(p: Player) -> void:
	rider = p
	running = true
	p.carried_by = seat
	for a in _animals:
		a.play_walk(true)


func _finish_run() -> void:
	running = false
	for a in _animals:
		a.play_walk(false)
	if rider != null:
		rider.carried_by = null
		var out := seat.global_position + Vector3(2.6, 0.0, 0.0)
		out.y = terrain.sample_height(out.x, out.z) + 0.4
		rider.global_position = out
		rider.velocity = Vector3.ZERO
		rider = null
	arrived.emit()


func _point_at(s: float) -> Vector2:
	var d := clampf(s, 0.0, _len) if open_route else fposmod(s, _len)
	for i in _seg.size():
		if d <= _seg[i]:
			return route[i].lerp(route[(i + 1) % route.size()], d / maxf(_seg[i], 0.001))
		d -= _seg[i]
	return route[route.size() - 1] if open_route else route[0]


func _place(s: float) -> void:
	var p := _point_at(s)
	var q := _point_at(s + 2.0)
	var want := atan2(-(q.x - p.x), -(q.y - p.y))
	_heading = lerp_angle(_heading, want, 0.2) if s > 0.0 else want
	rotation.y = _heading
	position = Vector3(p.x, terrain.sample_height(p.x, p.y), p.y)     # local: the parent sits at the origin, and _place also runs before we are in the tree
	# follow the ground slope a little
	var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var ahead := position + fwd * 3.0
	var behind := position - fwd * 3.0
	var dy := terrain.sample_height(ahead.x, ahead.z) - terrain.sample_height(behind.x, behind.z)
	rotation.x = clampf(atan2(dy, 6.0), -0.25, 0.25)


var _snd: AudioStreamPlayer3D


func _start_sound() -> void:
	var st := load("res://assets/audio/cart_loop.wav") as AudioStreamWAV
	if st == null:
		return
	st = st.duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2
	_snd = AudioStreamPlayer3D.new()
	_snd.bus = "SFX"
	_snd.stream = st
	_snd.unit_size = 6.0
	_snd.max_distance = 45.0
	_snd.volume_db = -9.0
	add_child(_snd)
	_snd.play()


func _process(delta: float) -> void:
	if _snd == null and is_inside_tree():
		_start_sound()
	if _driving:
		_drive(delta)
		return
	if player == null:
		return
	var near := global_position.distance_squared_to(player.global_position) < ACTIVE_RANGE * ACTIVE_RANGE
	for a in _animals:
		if a._anim != null:
			a._anim.speed_scale = 1.0 if near else 0.0
	if not near:
		return
	if not running:
		return
	if yields_to_player:
		var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
		var to := player.global_position - global_position
		to.y = 0.0
		blocked = to.length() < 6.5 and to.normalized().dot(fwd) > 0.5
		_bell_t = maxf(0.0, _bell_t - delta)
		for a in _animals:
			a.play_walk(not blocked)
		if blocked:
			if _bell_t <= 0.0:
				_bell_t = 6.0
				Sfx.at("bicycle_bell", global_position + Vector3(0, 2.0, 0), -3.0)
			return
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = randf_range(15.0, 35.0)
			if not _animals.is_empty() and Animal.CALLS.has(_animals[0].species) and global_position.distance_to(player.global_position) < 45.0:
				Sfx.at(Animal.CALLS[_animals[0].species][0], global_position + Vector3(0, 1.0, -2.0), -6.0)
	_s += speed * delta
	_place(_s)
	if open_route and _s >= _len:
		_finish_run()


# --- driving: the player stands on the cart holding the reins and steers it with the stick -------------------

const DRIVE_SPEED := 4.2           # m/s at full stick
var _driving := false
var _drive_v := 0.0


func start_drive(p: Player) -> void:
	rider = p
	_driving = true
	running = false
	p.carried_by = seat
	p.drive_wagon = self
	p._rig.set_react("reins")
	if driver != null and is_instance_valid(driver):
		driver.visible = false
	p.say(Loc.t("Stick to drive. JUMP to get off."))


func stop_drive() -> void:
	if rider == null:
		return
	_driving = false
	_drive_v = 0.0
	for a in _animals:
		a.play_walk(false)
	var p := rider
	p.carried_by = null
	p.drive_wagon = null
	p._rig.set_react("")
	p._rig.ride_k = 0.0
	p._rig.ride_turn = 0.0
	var side := global_transform.basis.x.normalized()
	var out := seat.global_position + side * 2.2
	out.y = terrain.sample_height(out.x, out.z) + 0.4
	p.global_position = out
	p.velocity = Vector3.ZERO
	rider = null
	if driver != null and is_instance_valid(driver):
		driver.visible = true


func _drive(delta: float) -> void:
	if rider == null or not is_instance_valid(rider):
		_driving = false
		return
	var inp: Vector2 = rider.move_input
	if inp.length() < 0.05:
		inp = rider._keyboard_input()
	_drive_v = move_toward(_drive_v, clampf(inp.y, -0.35, 1.0) * DRIVE_SPEED, 2.5 * delta)
	var turn_k := clampf(absf(_drive_v) / 2.0, 0.25, 1.0) * signf(_drive_v if absf(_drive_v) > 0.05 else 1.0)
	_heading -= inp.x * 1.1 * delta * turn_k
	rotation.y = _heading
	var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var np := position + fwd * _drive_v * delta
	np.y = terrain.sample_height(np.x, np.z)
	position = np
	var ahead := position + fwd * 3.0
	var behind := position - fwd * 3.0
	rotation.x = clampf(atan2(terrain.sample_height(ahead.x, ahead.z) - terrain.sample_height(behind.x, behind.z), 6.0), -0.25, 0.25)
	var moving := absf(_drive_v) > 0.2
	for a in _animals:
		a.play_walk(moving)
		if a._anim != null:
			a._anim.speed_scale = clampf(absf(_drive_v) / 1.3, 0.6, 2.2) if moving else 1.0
	rider._rig.ride_k = clampf(absf(_drive_v) / DRIVE_SPEED, 0.0, 1.0)
	rider._rig.ride_turn = clampf(inp.x, -1.0, 1.0)
