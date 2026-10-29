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


func setup(kind: String, ter: TerrainBuilder, ply: Node3D, at: Vector3, wander_radius: float, tint: Color = Color(1, 1, 1)) -> Animal:
	species = kind
	name = kind.capitalize()
	terrain = ter
	player = ply
	home = at
	radius = wander_radius
	_rng.seed = hash(at)
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
	var near := global_position.distance_squared_to(player.global_position) < ACTIVE_RANGE * ACTIVE_RANGE
	if _anim != null:
		_anim.speed_scale = 1.0 if near else 0.0
	if not near:
		return
	if _moving:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.6:
			_moving = false
			_wait = _rng.randf_range(3.0, 10.0)
			play_walk(false)
		else:
			var want_yaw := atan2(-to.x, -to.z)
			rotation.y = lerp_angle(rotation.y, want_yaw, minf(1.0, 3.0 * delta))
			var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
			global_position += fwd * _speed * delta
			ground()
	else:
		_wait -= delta
		if _wait <= 0.0:
			var ang := _rng.randf() * TAU
			var r := _rng.randf_range(2.0, radius)
			_target = home + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			_moving = true
			play_walk(true)
