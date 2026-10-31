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
var _headlow := ""               # head-down idle: sniffing, drinking, dozing
var _idle2 := ""                 # alert / ear-flick idle
var _kick := ""                  # kick or paw
var _butt := ""                  # headbutt or snort
var _hop := ""                   # rear or pounce
var _gjump := ""                 # leap while running
var back_y := 1.2                # height of the saddle point above the ground (measured from the model)
static var _back_cache := {}
var _act := {}                   # the current species activity (see _start_act)
var _spd := 1.0                  # animation speed of the current activity

## Behaviour: "prey" flees, "dog" befriends, "grazer" grazes and calls, "pack" = camels/horses (calm, curious).
const BEHAVIOUR := {
	"deer": "prey", "stag": "prey", "fox": "prey", "dog": "dog", "shiba": "dog",
	"cow": "grazer", "bull": "grazer", "donkey": "grazer", "horse": "grazer", "horse_white": "grazer", "camel": "grazer",
}
const CALLS := {
	"cow": ["cow_moo"], "bull": ["bull_moo"], "donkey": ["donkey_bray"], "horse": ["horse_whinny"],
	"horse_white": ["horse_whinny"], "camel": ["camel_grunt"], "fox": ["fox_yip"], "deer": ["deer_call"], "stag": ["deer_call"],
	"dog": ["dog_bark_0", "dog_bark_1", "dog_bark_2"], "shiba": ["dog_bark_0", "dog_bark_1", "dog_bark_2"],
}


func setup(kind: String, ter: TerrainBuilder, ply: Node3D, at: Vector3, wander_radius: float, tint: Color = Color(1, 1, 1)) -> Animal:
	species = kind
	add_to_group("animals")
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
	if _back_cache.has(kind):
		back_y = float(_back_cache[kind])
	else:
		# the saddle point: the highest part of the middle of the body (not the neck or head), above the feet
		var zmid := (zlo + zhi) * 0.5
		var win := (zhi - zlo) * 0.14
		var top := -INF
		for m2 in inst.find_children("*", "MeshInstance3D", true, false):
			var mi2 := m2 as MeshInstance3D
			if mi2.mesh == null:
				continue
			var xf2 := Transform3D.IDENTITY
			var n2: Node = mi2
			while n2 != null and n2 != _inner:
				if n2 is Node3D:
					xf2 = (n2 as Node3D).transform * xf2
				n2 = n2.get_parent()
			for s2 in mi2.mesh.get_surface_count():
				var arr: Array = mi2.mesh.surface_get_arrays(s2)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				for v in vs:
					var pv := xf2 * v
					if absf(pv.z - zmid) < win:
						top = maxf(top, pv.y)
		back_y = (top - lo) * float(sp["height"]) / h if top > -INF else float(sp["height"]) * 0.7
		_back_cache[kind] = back_y
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
	_texture_coat(inst)
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
			elif a.ends_with("|Gallop_Jump"):
				_gjump = a
			elif a.ends_with("|Idle_Headlow") or a.ends_with("|Idle_2_HeadLow"):
				_headlow = a
			elif a.ends_with("|Idle_2"):
				_idle2 = a
			elif a.ends_with("|Attack_Kick") or a.ends_with("|Attack"):
				_kick = a
			elif a.ends_with("|Attack_Headbutt"):
				_butt = a
			elif a.ends_with("|Jump_toIdle") or a.ends_with("|Jump_ToIdle"):
				_hop = a
			elif a.ends_with("|Eating"):
				_eating = a
				_has_eating = true
			var an := _anim.get_animation(a)
			if a.ends_with("|Walk") or a.ends_with("|Idle") or a.ends_with("|Eating") or a.ends_with("|Gallop") or a.ends_with("|Idle_2") \
					or a.ends_with("|Idle_Headlow") or a.ends_with("|Idle_2_HeadLow") or a.ends_with("|Attack_Kick") or a.ends_with("|Attack") \
					or a.ends_with("|Attack_Headbutt") or a.ends_with("|Jump_toIdle") or a.ends_with("|Jump_ToIdle"):
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
		_anim.speed_scale = _spd if near else 0.0
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
		_act = {}
		_spd = 1.0
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
		_act = {}
		_spd = 1.0
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
		if not _act.is_empty():
			_act_step(delta)
			return
		_wait -= delta
		if _wait > 0.0 and _anim != null and _anim.current_animation != _idle:
			_play(_idle)
		if _wait <= 0.0:
			if _rng.randf() < 0.65 and _start_act():
				return
			var ang := _rng.randf() * TAU
			var r := _rng.randf_range(2.0, radius)
			_target = home + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			_moving = true
			_play(_walk)


# --- species activities ---------------------------------------------------------------------
## Weighted choices per species: [activity, weight]. At night the sleepers doze instead.
const ACTS := {
	"cow": [["graze", 4], ["ruminate", 3], ["drink", 1], ["swat", 1], ["moo", 1]],
	"bull": [["graze", 3], ["paw", 3], ["snort", 2], ["ruminate", 1], ["drink", 1]],
	"donkey": [["graze", 3], ["bray", 1], ["swat", 2], ["doze", 1], ["drink", 1]],
	"horse": [["graze", 3], ["canter", 3], ["paw", 1], ["rear", 1], ["drink", 1]],
	"horse_white": [["graze", 3], ["canter", 3], ["paw", 1], ["rear", 1], ["drink", 1]],
	"camel": [["chew", 4], ["rest", 3], ["groan", 1], ["drink", 1]],
	"dog": [["sniff", 3], ["dig", 2], ["scratch", 1], ["tail_chase", 1], ["bark", 1], ["doze", 1]],
	"shiba": [["sniff", 3], ["dig", 2], ["scratch", 1], ["tail_chase", 1], ["bark", 1], ["doze", 1]],
	"deer": [["graze", 4], ["alert", 3], ["drink", 2], ["doze", 1]],
	"stag": [["graze", 3], ["alert", 3], ["drink", 2], ["display", 1]],
	"fox": [["stalk", 4], ["sniff", 2], ["dig", 1], ["rest", 2], ["yip", 1]],
}
const SLEEPERS := ["cow", "bull", "donkey", "horse", "horse_white", "camel", "dog", "shiba", "deer", "stag"]


func _pond_edge() -> Vector3:
	var pc := Vector3(TerrainBuilder.POND_C.x, 0.0, TerrainBuilder.POND_C.y)
	var d := global_position - pc
	d.y = 0.0
	if d.length() > 85.0 or d.length() < 0.1:
		return Vector3.INF
	var e := pc + d.normalized() * (TerrainBuilder.POND_R + 1.2)
	e.y = terrain.sample_height(e.x, e.z)
	return e


func _act_of(anim: String, dur: float, spd: float = 1.0) -> Dictionary:
	return {"anim": anim if anim != "" else _idle, "t": dur, "spd": spd}


## Start one activity for this species. Returns false when none applies (the animal wanders instead).
func _start_act() -> bool:
	var night := Npc.atmo.night if Npc.atmo != null else 0.0
	var pick := ""
	if night > 0.65 and SLEEPERS.has(species):
		pick = "sleep"
	else:
		var table: Array = ACTS.get(species, [])
		if table.is_empty():
			return false
		var total := 0
		for e in table:
			total += int(e[1])
		var r := _rng.randi() % total
		for e in table:
			r -= int(e[1])
			if r < 0:
				pick = e[0]
				break
	var a := {}
	match pick:
		"graze", "chew":
			a = _act_of(_eating, _rng.randf_range(6.0, 12.0), 0.6 if pick == "chew" else 1.0)
		"ruminate", "rest", "doze":
			a = _act_of(_headlow, _rng.randf_range(8.0, 14.0), 0.35)
		"sleep":
			a = _act_of(_headlow, _rng.randf_range(30.0, 60.0), 0.15)
		"swat", "alert":
			a = _act_of(_idle2, _rng.randf_range(3.0, 5.0))
		"moo", "bray", "groan", "yip", "bark":
			a = _act_of(_idle2 if pick != "bark" else _kick, 2.2)
			var snd := {"moo": "cow_moo", "bray": "donkey_bray", "groan": "camel_grunt", "yip": "fox_yip", "bark": "dog_bark_%d" % _rng.randi_range(0, 2)}
			a["snd"] = snd[pick]
			a["st"] = 0.4
			a["every"] = 99.0
		"paw":
			a = _act_of(_kick, _rng.randf_range(3.5, 5.5), 0.8)
			a["snd"] = "hoof_%d" % _rng.randi_range(0, 1)
			a["st"] = 0.5
			a["every"] = 1.2
		"snort", "display":
			a = _act_of(_butt, 2.4, 0.9)
			a["snd"] = "bull_moo" if pick == "snort" else "deer_call"
			a["st"] = 0.3
			a["every"] = 99.0
		"rear":
			a = _act_of(_hop, 1.8)
			a["snd"] = "horse_whinny"
			a["st"] = 0.3
			a["every"] = 99.0
		"canter":
			var ang := _rng.randf() * TAU
			var rr := _rng.randf_range(radius * 0.8, radius * 1.6 + 8.0)
			var tg := home + Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
			a = _act_of(_idle2, 2.0)
			a["go"] = tg
			a["run"] = true
			a["snd"] = "horse_whinny"
			a["st"] = 0.2
			a["every"] = 99.0
		"drink":
			var e := _pond_edge()
			if e == Vector3.INF:
				return false
			a = _act_of(_headlow, _rng.randf_range(6.0, 10.0), 0.5)
			a["go"] = e
			a["face"] = Vector3(TerrainBuilder.POND_C.x, 0.0, TerrainBuilder.POND_C.y)
		"sniff":
			a = _act_of(_headlow, _rng.randf_range(4.0, 7.0), 0.9)
		"scratch":
			a = _act_of(_idle2, 3.0, 1.3)
		"dig":
			a = _act_of(_eating, _rng.randf_range(4.0, 6.0), 1.5)
			a["snd"] = "dig_%d" % _rng.randi_range(0, 2)
			a["st"] = 0.3
			a["every"] = 0.85
		"tail_chase":
			a = _act_of(_walk, 3.5, 1.6)
			a["spin"] = true
		"stalk":
			# crouch low, then spring forward on the prey
			a = _act_of(_headlow, 3.0, 0.5)
			a["next"] = {"anim": _kick if _kick != "" else _hop, "t": 0.9, "spd": 1.4, "lunge": 4.5}
		_:
			return false
	if str(a["anim"]) == "":
		return false
	a["n"] = pick
	_act = a
	_spd = float(a.get("spd", 1.0))
	return true


func _act_step(delta: float) -> void:
	var a := _act
	if a.has("go"):
		var to: Vector3 = (a["go"] as Vector3) - global_position
		to.y = 0.0
		a["go_t"] = float(a.get("go_t", 0.0)) + delta
		if to.length() < 0.9 or float(a["go_t"]) > 28.0:
			a.erase("go")
			if a.has("run"):
				home = global_position
		else:
			var run := a.has("run") and _has_gallop
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, 4.0 * delta))
			var fw := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
			global_position += fw * _speed * (4.2 if run else 1.0) * delta
			ground()
			_spd = 1.0
			_play(_gallop if run else _walk)
			return
	if a.has("face"):
		var fv: Vector3 = (a["face"] as Vector3) - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-fv.x, -fv.z), minf(1.0, 3.0 * delta))
	_spd = float(a.get("spd", 1.0))
	_play(str(a["anim"]))
	if a.has("snd"):
		a["st"] = float(a["st"]) - delta
		if float(a["st"]) <= 0.0:
			a["st"] = float(a["every"])
			Sfx.at(str(a["snd"]), global_position + Vector3(0, 0.8, 0), -5.0, _rng.randf_range(0.92, 1.08))
	if a.has("spin"):
		rotation.y += 5.5 * delta
	if a.has("lunge"):
		var fw2 := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		global_position += fw2 * float(a["lunge"]) * delta
		ground()
	a["t"] = float(a["t"]) - delta
	if float(a["t"]) <= 0.0:
		if a.has("next"):
			_act = a["next"]
			return
		_act = {}
		_spd = 1.0
		_wait = _rng.randf_range(2.0, 6.0)
		play_walk(false)


const HUNT_HP := {"deer": 40.0, "stag": 60.0, "fox": 25.0}
var hp := 0.0
var dead := false
static var story_ref: Story           # set by Main; carcasses add meat and hides to the story flags
const LOOT := {"deer": [2, 1], "stag": [3, 2], "fox": [1, 1]}     # meat, hides


## Only huntable wild animals can be hurt, and only by a player carrying the hunter's knife.
func huntable() -> bool:
	return HUNT_HP.has(species) and not dead and not driven


func take_hit(dmg: float, dir: Vector3) -> void:
	if not huntable():
		return
	if hp <= 0.0:
		hp = float(HUNT_HP[species])
	hp -= dmg
	Sfx.at("animal_pain", global_position + Vector3(0, 1, 0), 0.0, randf_range(0.85, 1.2))
	if hp > 0.0:
		_flee_t = 6.0
		return
	dead = true
	driven = true
	set_process(false)
	if _anim != null:
		_anim.stop()
	Sfx.at("animal_thud", global_position, -2.0)
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", deg_to_rad(88.0) * (1.0 if randf() < 0.5 else -1.0), 0.45).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(12.0)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 1.5)
	tw.tween_callback(queue_free)
	_carcass()
	var pl := player as Player
	if pl != null:
		pl.hunted += 1
		pl.say("You bring down the %s." % species)


## A hunted animal can be skinned for meat and hides, which sell at the bazaar's leather stall.
func _carcass() -> void:
	var loot: Array = LOOT.get(species, [1, 1])
	var it := Interactable.new()
	it.position = Vector3(0, 0.5, 0)
	it.prompt = "Skin the %s" % species
	it.reach = 3.0
	add_child(it)
	it.on_interact = func(_by: Node3D, me: Interactable) -> void:
		me.enabled = false
		me.queue_free()
		if story_ref != null:
			story_ref.add("meat", int(loot[0]))
			story_ref.add("hides", int(loot[1]))
		Sfx.at("cloth_grab", global_position, -2.0)
		var pl2 := player as Player
		if pl2 != null:
			pl2.say("Meat x%d, hide x%d. The bazaar leather stall buys these." % [loot[0], loot[1]])


func _play(clip: String) -> void:
	if _anim != null and _anim.current_animation != clip:
		_anim.play(clip, 0.25)


static var _coat_tex := {}


## Fur and hide texture: mottled noise on every coat surface (object-space triplanar, so no UVs are
## needed), plus patches on cows and bulls, dapples on deer and stripes of darker hair on the rest.
func _texture_coat(inst: Node) -> void:
	var patches := species in ["cow", "bull"]
	var key := "patch" if patches else ("dapple" if species == "deer" else "fur")
	if not _coat_tex.has(key):
		var fn := FastNoiseLite.new()
		fn.seed = 7
		fn.noise_type = FastNoiseLite.TYPE_CELLULAR if key == "dapple" else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.9 if key == "patch" else (2.2 if key == "dapple" else 5.0)
		fn.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.noise = fn
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		var g := Gradient.new()
		if key == "patch":
			g.offsets = PackedFloat32Array([0.0, 0.46, 0.54, 1.0])
			g.colors = PackedColorArray([Color(0.35, 0.28, 0.24), Color(0.4, 0.32, 0.27), Color(1.0, 1.0, 1.0), Color(1.0, 0.98, 0.95)])
		elif key == "dapple":
			g.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 1.0])
			g.colors = PackedColorArray([Color(1.5, 1.45, 1.4), Color(1.4, 1.35, 1.3), Color(0.8, 0.75, 0.7), Color(0.75, 0.7, 0.65)])
		else:
			g.offsets = PackedFloat32Array([0.0, 1.0])
			g.colors = PackedColorArray([Color(0.62, 0.58, 0.55), Color(1.12, 1.08, 1.04)])
		tex.color_ramp = g
		_coat_tex[key] = tex
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for sidx in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(sidx)
			if mat == null:
				mat = mi.mesh.surface_get_material(sidx)
			if mat is StandardMaterial3D and (mat.resource_name.begins_with("Main") or mat.resource_name == "Fur"):
				var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_texture = _coat_tex[key]
				d.uv1_triplanar = true
				d.uv1_scale = Vector3.ONE * (0.55 if key == "patch" else 1.2)
				d.roughness = 0.92
				mi.set_surface_override_material(sidx, d)
