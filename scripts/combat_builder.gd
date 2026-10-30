class_name CombatBuilder
extends RefCounted
## Enemies, power-ups, the Night of the Reavers raid (Act 2 finale) and the bandit-camp bounty.

const REAVER := {"role": "enemy", "voice": "deep", "robe": false, "scale": 1.0, "tool": "hammer"}
const BODIES := ["brute", "whelp", "thief", "veteran"]

var main: Node3D
var story: Story
var hud: QuestHUD
var player: Player
var terrain: TerrainBuilder
var _wave := 0
var _raid_started := false
var _n := 0


func _init(m: Node3D, s: Story, h: QuestHUD) -> void:
	main = m
	story = s
	hud = h
	player = m.player
	terrain = m.terrain


func build() -> void:
	player.checkpoint = Vector3(-84.0, terrain.sample_height(-84.0, 20.0), 20.0)
	for spot in [[Vector2(-80, 2), "health"], [Vector2(40, 38), "shield"], [Vector2(-30, 104), "speed"],
			[Vector2(30, -60), "power"], [Vector2(108, 150), "health"], [Vector2(14, -128), "health"],
			[Vector2(-60, 40), "power"], [Vector2(70, 100), "speed"]]:
		var p: Vector2 = spot[0]
		spawn_pickup(Vector3(p.x, terrain.sample_height(p.x, p.y), p.y), spot[1], 150.0)
	_camp()
	story.changed.connect(_on_story_changed)


func spawn_pickup(pos: Vector3, kind: String, respawn: float = 0.0) -> void:
	var pk := Pickup.new().setup(kind, player, pos, respawn)
	main.add_child(pk)


func spawn_enemy(pos: Vector3, boss: bool = false, aggro: float = 15.0, tag: String = "") -> Enemy:
	_n += 1
	var pr: Dictionary = REAVER.duplicate()
	pr["body"] = BODIES[_n % BODIES.size()]
	pr["tint"] = Color(0.62, 0.3, 0.26).lerp(Color(0.4, 0.4, 0.45), (_n % 3) * 0.25)
	var e := Enemy.new()
	if boss:
		pr["body"] = "brute"
		pr["scale"] = 1.3
		pr["tint"] = Color(0.34, 0.1, 0.1)
		e.hp = 280.0
		e.max_hp = 280.0
		e.damage = 16.0
		e.speed = 3.8
		e.attack_cd = 1.2
		e.is_boss = true
	e.player = player
	e.aggro = aggro
	e.setup(pr, pos, "Reaver%d" % _n if not boss else "CaptainKaran")
	e._spawn_pickup = func(p: Vector3, k: String) -> void: spawn_pickup(p, k)
	e.set_meta("tag", tag)
	e.died.connect(_on_enemy_died)
	main.add_child(e)
	e.global_position = pos
	return e


func _g(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.sample_height(x, z) + 0.3, z)


# --- bandit camp (side mission) -----------------------------------------------------------------

func _camp() -> void:
	var c := Vector2(-140.0, 96.0)
	var base := _g(c.x, c.y)
	story.refs["camp"] = base
	# campfire and crates
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.55, 0.2)
	fire.omni_range = 10.0
	fire.light_energy = 1.4
	fire.position = base + Vector3(0, 1.0, 0)
	main.add_child(fire)
	var tw := fire.create_tween().set_loops()
	tw.tween_property(fire, "light_energy", 1.0, 0.27)
	tw.tween_property(fire, "light_energy", 1.7, 0.21)
	var flame := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.28
	cm.height = 0.8
	flame.mesh = cm
	flame.material_override = PropFactory.glow_lamp()
	flame.position = base + Vector3(0, 0.55, 0)
	main.add_child(flame)
	PropFactory.cylinder(main, 0.5, 0.5, 0.12, base + Vector3(0, 0.08, 0), PropFactory.material(Color(0.2, 0.18, 0.16)), Vector3.ZERO, false, 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	PropsExtra.crate_stack(main, base + Vector3(4.0, -0.3, 2.0), 30.0, rng)
	PropsExtra.crate_stack(main, base + Vector3(-4.5, -0.3, -2.5), 120.0, rng)
	for k in 4:
		var a := k * TAU / 4.0 + 0.5
		spawn_enemy(base + Vector3(cos(a) * 4.0, 0.0, sin(a) * 4.0), false, 13.0, "camp")


# --- raid -----------------------------------------------------------------------------------------

func _on_enemy_died(e: Enemy) -> void:
	var tag: String = e.get_meta("tag", "")
	if tag == "camp":
		story.add("camp_down", 1)
	elif tag == "forest":
		story.add("forest_down", 1)
	elif tag == "raid":
		story.add("reavers_down", 1)
		var d := int(story.get_flag("reavers_down", 0))
		if d == 3 and _wave == 1:
			_start_wave(2)
		elif d == 7 and _wave == 2:
			_start_wave(3)
	elif tag == "boss":
		story.set_flag("captain_down", true)
		hud.banner("CAPTAIN KARAN DEFEATED", "seal_found")
		for k in ["health", "power", "shield"]:
			spawn_pickup(e.global_position + Vector3(randf_range(-1.5, 1.5), 0.6, randf_range(-1.5, 1.5)), k)


func _on_story_changed() -> void:
	if story.get_flag("arin_done") and not _raid_started:
		_raid_started = true
		start_raid()


func start_raid() -> void:
	_raid_started = true
	Sfx.ui("raid_horn", -2.0)
	Sfx.sting("danger", -2.0)
	hud.banner("THE DUST REAVERS HAVE FOUND THE GATE!\nDefend the platform", "mission_new")
	_start_wave(1)


func _wave_spots(n: int) -> Array:
	var out: Array = []
	for i in n:
		var x := -9.0 + 18.0 * (float(i) / maxf(1.0, n - 1.0))
		out.append(_g(x, -122.0 - (i % 2) * 5.0))
	return out


func _start_wave(w: int) -> void:
	_wave = w
	if w == 1:
		main.atmosphere.set_weather("drizzle", 150.0)       # dark skies over the Reaver raid
		for p in _wave_spots(3):
			spawn_enemy(p, false, 90.0, "raid")
	elif w == 2:
		hud.banner("SECOND WAVE", "raid_horn")
		Sfx.sting("surprise", -3.0)
		for p in _wave_spots(4):
			spawn_enemy(p, false, 90.0, "raid")
	else:
		hud.banner("CAPTAIN KARAN APPROACHES", "raid_horn")
		spawn_enemy(_g(0.0, -118.0), true, 90.0, "boss")
