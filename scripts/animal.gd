class_name Animal
extends Node3D
## An animated animal (Quaternius animals, CC0). Wanders around a home point, or follows a
## leader's pace when `driven` (cart animals). Animation and movement only run while the player is
## within ACTIVE_RANGE metres. Placeholder behaviour: no combat, no AI beyond wandering.

const DIR := "res://assets/animals/"
const ACTIVE_RANGE := 80.0
const SPECIES := {
	"bull": {"file": "Bull", "height": 1.75, "speed": 1.1},
	"cow": {"file": "Cow", "height": 1.6, "speed": 1.0},
	"donkey": {"file": "Donkey", "height": 1.45, "speed": 1.2},
	"horse": {"file": "Horse", "height": 2.0, "speed": 1.5},
	"horse_white": {"file": "Horse_White", "height": 2.0, "speed": 1.5},
	"dog": {"file": "Husky", "height": 0.8, "speed": 1.6},
	"shiba": {"file": "ShibaInu", "height": 0.6, "speed": 1.4},
	"deer": {"file": "Deer", "height": 1.7, "speed": 1.8},
	"stag": {"file": "Stag", "height": 2.0, "speed": 1.8},
	"fox": {"file": "Fox", "height": 0.55, "speed": 1.6},
	# No camel exists in the free packs: the alpaca, scaled up and sand-tinted, stands in.
	"camel": {"file": "Alpaca", "height": 2.5, "speed": 1.1, "tint": Color(0.86, 0.7, 0.46)},
}

var species := "cow"
var terrain: TerrainBuilder
var player: Node3D
var home := Vector3.ZERO
var radius := 8.0
var driven := false              # true: moved by a Wagon, only plays Walk/Idle on request
var length := 1.0                # approx body length, for the collider
var _anim: AnimationPlayer
var _walk := "Walk"
var _idle := "Idle"
var _target := Vector3.ZERO
var _wait := 0.0
var _moving := false
var _speed := 1.0
var _rng := RandomNumberGenerator.new()
var _inner: Node3D
var _call_t := 0.0
var _flee_t := 0.0
var _eat_t := 0.0
var _gallop := "Gallop"
var _eating := "Eating"
var _has_gallop := false
var _has_eating := false

## Behaviour: "prey" flees, "dog" befriends, "grazer" grazes and calls, "pack" = camels/horses (calm, curious).
const BEHAVIOUR := {
	"deer": "prey", "stag": "prey", "fox": "prey", "dog": "dog", "shiba": "dog",
	"cow": "grazer", "bull": "grazer", "donkey": "grazer", "horse": "grazer", "horse_white": "grazer", "camel": "grazer",
}
const CALLS := {
	"cow": ["cow_moo"], "bull": ["bull_moo"], "donkey": ["donkey_bray"], "horse": ["horse_whinny"],
	"horse_white": ["horse_whinny"], "camel": ["camel_grunt"], "fox": ["fox_yip"],
	"dog": ["dog_bark_0", "dog_bark_1", "dog_bark_2"], "shiba": ["dog_bark_0", "dog_bark_1", "dog_bark_2"],
}


func setup(kind: String, ter: TerrainBuilder, ply: Node3D, at: Vector3, wander_radius: float, tint: Color = Color(1, 1, 1)) -> Animal:
	species = kind
	name = kind.capitalize()
	terrain = ter
	player = ply
	home = at
	radius = wander_radius
	_rng.seed = hash(at)
	_call_t = _rng.randf_range(4.0, 25.0)
	var sp: Dictionary = SPECIES[kind]
	_speed = sp["speed"]
	_inner = Node3D.new()
	add_child(_inner)
	var ps := load(DIR + sp["file"] + ".glb") as PackedScene
	var inst := ps.instantiate() as Node3D
	inner_add(inst)
	# scale to target height, stand on y = 0
	var lo := INF
	var hi := -INF
	var zlo := INF
	var zhi := -INF
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != _inner:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb := mi.mesh.get_aabb()
		for c in 8:
			var p := xf * (bb.position + bb.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1))
			lo = minf(lo, p.y); hi = maxf(hi, p.y)
			zlo = minf(zlo, p.z); zhi = maxf(zhi, p.z)
	var h := maxf(hi - lo, 0.1)
	var k: float = float(sp["height"]) / h
	_inner.scale = Vector3.ONE * k
	_inner.position.y = -lo * k
	length = (zhi - zlo) * k
	_inner.rotation.y = PI            # models face +Z, we face -Z
	var t: Color = sp.get("tint", Color(1, 1, 1)) * tint
	if t != Color(1, 1, 1):
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D and (mat.resource_name.begins_with("Main") or mat.resource_name == "Fur"):
					var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					d.albedo_color = d.albedo_color * t
					mi.set_surface_override_material(s, d)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_anim = aps[0] as AnimationPlayer
		for a in _anim.get_animation_list():
			if a.ends_with("|Walk"):
				_walk = a
			elif a.ends_with("|Idle"):
				_idle = a
			elif a.ends_with("|Gallop"):
				_gallop = a
				_has_gallop = true
			elif a.ends_with("|Eating"):
				_eating = a
				_has_eating = true
			var an := _anim.get_animation(a)
			if a.ends_with("|Walk") or a.ends_with("|Idle") or a.ends_with("|Eating") or a.ends_with("|Gallop"):
				an.loop_mode = Animation.LOOP_LINEAR
		_anim.play(_idle)
		_anim.seek(_rng.randf() * 2.0, true)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(0.5, float(sp["height"]) * 0.32), float(sp["height"]) * 0.7, maxf(0.7, length * 0.8))
	cs.shape = box
	cs.position = Vector3(0, float(sp["height"]) * 0.4, 0)
	body.add_child(cs)
	add_child(body)
	return self


func inner_add(n: Node3D) -> void:
	_inner.add_child(n)


func play_walk(on: bool) -> void:
	if _anim == null:
		return
	var want := _walk if on else _idle
	if _anim.current_animation != want:
		_anim.play(want, 0.25)


func ground() -> void:
	global_position.y = terrain.sample_height(global_position.x, global_position.z)


func _process(delta: float) -> void:
	if driven or player == null:
		return
	var d2 := global_position.distance_squared_to(player.global_position)
	var near := d2 < ACTIVE_RANGE * ACTIVE_RANGE
	if _anim != null:
		_anim.speed_scale = 1.0 if near else 0.0
	if not near:
		return
	var dist := sqrt(d2)
	var kind: String = BEHAVIOUR.get(species, "grazer")
	var pspeed := Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length() if player is CharacterBody3D else 0.0
	# calls
	_call_t -= delta
	if _call_t <= 0.0:
		_call_t = _rng.randf_range(14.0, 40.0)
		if dist < 30.0 and CALLS.has(species):
			var l: Array = CALLS[species]
			Sfx.at(l[_rng.randi() % l.size()], global_position + Vector3(0, 1.0, 0), -4.0, _rng.randf_range(0.93, 1.07))
	# prey: bolt away when the player comes close or runs at them
	if kind == "prey" and (dist < 5.0 or (dist < 14.0 and pspeed > 4.0)):
		if _flee_t <= 0.0 and CALLS.has(species) and _rng.randf() < 0.4:
			Sfx.at(CALLS[species][0], global_position, -6.0)
		_flee_t = 3.0
	if _flee_t > 0.0:
		_flee_t -= delta
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() > 0.1:
			var want := atan2(-away.x, -away.z)
			rotation.y = lerp_angle(rotation.y, want, minf(1.0, 6.0 * delta))
			var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
			global_position += fwd * 4.6 * delta
			ground()
			_play(_gallop if _has_gallop else _walk)
			if _anim != null:
				_anim.speed_scale = 1.0
		if _flee_t <= 0.0:
			home = global_position
			_moving = false
			_wait = 2.0
			play_walk(false)
		return
	# dogs: greet and trot after the player, keeping a polite distance
	if kind == "dog" and dist < 18.0 and dist > 3.2:
		var to := player.global_position - global_position
		to.y = 0.0
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, 4.0 * delta))
		var fwd2 := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		global_position += fwd2 * (_speed * (2.2 if dist > 8.0 else 1.2)) * delta
		ground()
		_play(_gallop if (_has_gallop and dist > 8.0) else _walk)
		home = global_position
		_moving = false
		return
	if kind == "dog" and dist <= 3.2:
		var to2 := player.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to2.x, -to2.z), minf(1.0, 4.0 * delta))
		_play(_idle)
		return
	# grazers glance at a close player
	if kind == "grazer" and dist < 7.0 and not _moving:
		var to3 := player.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to3.x, -to3.z), minf(1.0, 1.5 * delta))
	if _moving:
		var to4 := _target - global_position
		to4.y = 0.0
		if to4.length() < 0.6:
			_moving = false
			_wait = _rng.randf_range(3.0, 10.0)
			play_walk(false)
		else:
			var want_yaw := atan2(-to4.x, -to4.z)
			rotation.y = lerp_angle(rotation.y, want_yaw, minf(1.0, 3.0 * delta))
			var fwd3 := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
			global_position += fwd3 * _speed * delta
			ground()
			_play(_walk)
	else:
		_wait -= delta
		if kind == "grazer" and _has_eating and _eat_t <= 0.0 and _rng.randf() < 0.004:
			_eat_t = _rng.randf_range(4.0, 9.0)
		if _eat_t > 0.0:
			_eat_t -= delta
			_play(_eating)
		elif _anim != null and _anim.current_animation == _eating:
			_play(_idle)
		if _wait <= 0.0 and _eat_t <= 0.0:
			var ang := _rng.randf() * TAU
			var r := _rng.randf_range(2.0, radius)
			_target = home + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			_moving = true
			_play(_walk)


func _play(clip: String) -> void:
	if _anim != null and _anim.current_animation != clip:
		_anim.play(clip, 0.25)
