class_name Traveller
extends Node3D
## A rider on horseback or camelback travelling along a road, out and back. Stops and waits when the
## player stands in the way, and sits the saddle in the same riding pose the player uses.

var terrain: TerrainBuilder
var player: Node3D
var route: Array[Vector2] = []
var speed := 3.5
var animal: Animal
var rider: Npc
var _s := 0.0
var _len := 0.0
var _seg: Array[float] = []
var _heading := 0.0
var blocked := false
var _bell_t := 0.0
var _call_t := 8.0


func _init(ter: TerrainBuilder, ply: Node3D, kind: String, pts: Array[Vector2], spd: float, preset: Dictionary) -> void:
	terrain = ter
	player = ply
	route = pts
	speed = spd
	name = "Traveller_" + kind
	for i in route.size():
		var d := route[i].distance_to(route[(i + 1) % route.size()])
		_seg.append(d)
		_len += d
	animal = Animal.new().setup(kind, ter, ply, Vector3.ZERO, 1.0)
	animal.driven = true
	add_child(animal)
	var h: float = float(Animal.SPECIES[kind]["height"])
	rider = Npc.new().setup(preset, "idle", "Rider_" + kind)
	rider.player = ply
	animal.add_child(rider)
	rider.position = Vector3(0, h * 0.8 - 0.42, 0)
	rider.rig.set_react("ride")
	animal.play_walk(true)
	_s = randf() * _len
	_place(_s)


func _point_at(s: float) -> Vector2:
	var d := fposmod(s, _len)
	for i in _seg.size():
		if d <= _seg[i]:
			return route[i].lerp(route[(i + 1) % route.size()], d / maxf(_seg[i], 0.001))
		d -= _seg[i]
	return route[0]


func _place(s: float) -> void:
	var p := _point_at(s)
	var q := _point_at(s + 2.0)
	var want := atan2(-(q.x - p.x), -(q.y - p.y))
	_heading = lerp_angle(_heading, want, 0.25)
	animal.rotation.y = _heading
	animal.position = Vector3(p.x, terrain.sample_height(p.x, p.y), p.y)


func _process(delta: float) -> void:
	if player == null:
		return
	var pp := player.global_position
	var d := Vector2(animal.position.x - pp.x, animal.position.z - pp.z).length()
	if d > 170.0:
		animal._anim.speed_scale = 0.0 if animal._anim != null else 1.0
		return
	if animal._anim != null:
		animal._anim.speed_scale = 1.0
	# stand still if the player blocks the road a few metres ahead
	var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var to := pp - animal.position
	to.y = 0.0
	blocked = to.length() < 5.5 and to.normalized().dot(fwd) > 0.5
	_bell_t = maxf(0.0, _bell_t - delta)
	if blocked:
		animal.play_walk(false)
		if _bell_t <= 0.0:
			_bell_t = 6.0
			Sfx.at("bicycle_bell", animal.global_position + Vector3(0, 2.0, 0), -3.0)
		return
	animal.play_walk(true)
	_s += speed * delta
	_place(_s)
	_call_t -= delta
	if _call_t <= 0.0:
		_call_t = randf_range(14.0, 34.0)
		if d < 40.0 and Animal.CALLS.has(animal.species):
			Sfx.at(Animal.CALLS[animal.species][0], animal.global_position + Vector3(0, 1.0, 0), -6.0)
