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


func setup(ter: TerrainBuilder, ply: Node3D, kind: String, points: Array[Vector2], spd: float) -> Wagon:
	terrain = ter
	player = ply
	route = points
	speed = spd
	name = "Wagon_" + kind
	for i in route.size():
		var d := route[i].distance_to(route[(i + 1) % route.size()])
		_seg.append(d)
		_len += d
	# cart
	_cart = Node3D.new()
	add_child(_cart)
	var cart := (load("res://assets/props/cart.glb") as PackedScene).instantiate() as Node3D
	_cart.add_child(cart)
	cart.scale = Vector3.ONE * 1.6
	cart.rotation.y = PI * 0.5      # the cart's long axis along our forward (-Z) after yaw; adjusted by look
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.0, 3.2)
	cs.shape = box
	cs.position = Vector3(0, 0.8, 1.2)
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
	_place(0.0)
	return self


func _point_at(s: float) -> Vector2:
	var d := fposmod(s, _len)
	for i in route.size():
		if d <= _seg[i]:
			return route[i].lerp(route[(i + 1) % route.size()], d / maxf(_seg[i], 0.001))
		d -= _seg[i]
	return route[0]


func _place(s: float) -> void:
	var p := _point_at(s)
	var q := _point_at(s + 2.0)
	var want := atan2(-(q.x - p.x), -(q.y - p.y))
	_heading = lerp_angle(_heading, want, 0.2) if s > 0.0 else want
	rotation.y = _heading
	global_position = Vector3(p.x, terrain.sample_height(p.x, p.y), p.y)
	# follow the ground slope a little
	var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var ahead := global_position + fwd * 3.0
	var behind := global_position - fwd * 3.0
	var dy := terrain.sample_height(ahead.x, ahead.z) - terrain.sample_height(behind.x, behind.z)
	rotation.x = clampf(atan2(dy, 6.0), -0.25, 0.25)


func _process(delta: float) -> void:
	if player == null:
		return
	var near := global_position.distance_squared_to(player.global_position) < ACTIVE_RANGE * ACTIVE_RANGE
	for a in _animals:
		if a._anim != null:
			a._anim.speed_scale = 1.0 if near else 0.0
	if not near:
		return
	_s += speed * delta
	_place(_s)
