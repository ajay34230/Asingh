class_name ForestBuilder
extends Node
## The Sal forest and the mission "The Forest Road". After the temple reveals the council coins,
## Pandit Rishi's scribe Tara goes to the forest shrine for the old ledger and is cornered by Reaver
## men at the clearing. The player stops them; the ledger then drives the main plot forward.
## (The scene is told through dialogue and staging, not shown graphically.)

var main: Node3D
var story: Story
var hud: QuestHUD
var dlg: DialogueUI
var cin: Cinematic
var terrain: TerrainBuilder
var player: Player
var combat: CombatBuilder
var tara: Npc
var enemies: Array[Enemy] = []
var state := "dormant"      # dormant, waiting, scene, fight, done
var _root: Node3D
var _c := Vector3.ZERO
var _fear_t := 0.0
var _fire_light: OmniLight3D


func _init(m: Node3D, s: Story, h: QuestHUD, d: DialogueUI, c: Cinematic, t: TerrainBuilder, p: Player, cb: CombatBuilder) -> void:
	main = m
	story = s
	hud = h
	dlg = d
	cin = c
	terrain = t
	player = p
	combat = cb
	name = "ForestBuilder"


func build() -> void:
	main.add_child(self)
	var cc := TerrainBuilder.FOREST_C
	_c = Vector3(cc.x, terrain.forest_y, cc.y)
	_root = Node3D.new()
	_root.name = "SalForest"
	main.add_child(_root)
	_trees()
	_camp()
	_shrine()
	_quest()
	story.refs["forest"] = _c
	story.changed.connect(_on_changed)
	_on_changed()


func _on_changed() -> void:
	if state == "dormant" and story.get_flag("temple_blessed") and not story.get_flag("tara_saved"):
		_activate()
	elif state == "fight" and int(story.get_flag("forest_down", 0)) >= 4:
		_won()


# --- scenery -----------------------------------------------------------------------------------

func _trail_dist(x: float, z: float) -> float:
	# distance to the trail that leads from the clearing towards the village
	var a := Vector2(_c.x, _c.z)
	var d := (Vector2(-90.0, 12.0) - a).normalized()
	var p := Vector2(x, z) - a
	var along := p.dot(d)
	if along < 0.0:
		return 99.0
	return absf(p.x * d.y - p.y * d.x)


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var R := TerrainBuilder.FOREST_R
	var body := StaticBody3D.new()
	body.name = "TreeTrunks"
	_root.add_child(body)
	var acacias: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var deads: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	for i in 420:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * R
		var x := _c.x + cos(a) * r
		var z := _c.z + sin(a) * r
		var d_c := Vector2(x - _c.x, z - _c.z).length()
		if d_c < 11.0 or _trail_dist(x, z) < 2.6:
			continue
		var y := terrain.sample_height(x, z)
		var sc := rng.randf_range(1.5, 2.5)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * sc)
		if rng.randf() < 0.28:
			palms.append(Transform3D(basis.scaled(Vector3.ONE * 0.8), Vector3(x, y - 0.1, z)))
		else:
			acacias.append(Transform3D(basis, Vector3(x, y - 0.1, z)))
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.32 * sc
		cy.height = 4.0
		cs.shape = cy
		cs.position = Vector3(x, y + 2.0, z)
		body.add_child(cs)
	for i in 14:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * R
		var x := _c.x + cos(a) * r
		var z := _c.z + sin(a) * r
		if Vector2(x - _c.x, z - _c.z).length() < 12.0 or _trail_dist(x, z) < 2.6:
			continue
		deads.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), Vector3(x, terrain.sample_height(x, z) - 0.1, z)))
	for i in 260:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (R + 6.0)
		var x := _c.x + cos(a) * r
		var z := _c.z + sin(a) * r
		if Vector2(x - _c.x, z - _c.z).length() < 9.0:
			continue
		var t := Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)), Vector3(x, terrain.sample_height(x, z) - 0.05, z))
		if i % 3 == 0:
			bushes.append(t)
		else:
			grass.append(t)
	Flora.scatter_cells(_root, Flora.acacia_mesh(), Flora.sway_material("acacia", 0.006, 0.9), acacias, "SalTree", "foliage_palm", 60.0)
	Flora.scatter_cells(_root, Flora.palm_mesh(), Flora.sway_material("palm", 0.012, 1.1), palms, "SalPalm", "foliage_palm", 60.0)
	Flora.scatter_cells(_root, Flora.dead_tree_mesh(), Flora.sway_material("dead", 0.0, 1.0), deads, "SalDead", "foliage_palm", 60.0)
	Flora.scatter_cells(_root, Flora.bush_mesh(), Flora.sway_material("bush", 0.05, 1.3), bushes, "SalBush", "foliage_grass", 30.0)
	Flora.scatter_cells(_root, Flora.clump_mesh(7, 0.4, 0.9, 12, Color(0.2, 0.36, 0.12)), Flora.sway_material("grass", 0.18, 1.8), grass, "SalGrass", "foliage_grass", 30.0)


func _camp() -> void:
	var fire := Node3D.new()
	fire.position = _c + Vector3(0, 0.05, 0)
	_root.add_child(fire)
	for k in 8:
		var a := k * TAU / 8.0
		PropFactory.box(fire, Vector3(0.4, 0.3, 0.3), Vector3(cos(a) * 0.8, 0.15, sin(a) * 0.8), PropFactory.stone(Color(0.35, 0.33, 0.3)), Vector3(0, -rad_to_deg(a), 0), false, false)
	for k in 3:
		PropFactory.cylinder(fire, 0.07, 0.07, 1.0, Vector3(0, 0.2, 0), PropFactory.wood(), Vector3(80, k * 60.0, 0), false, 8)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.8
	flame.mesh = sm
	flame.material_override = PropFactory.glow_lamp()
	flame.position = Vector3(0, 0.5, 0)
	fire.add_child(flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.6, 0.25)
	_fire_light.omni_range = 12.0
	_fire_light.light_energy = 2.0
	_fire_light.position = Vector3(0, 1.2, 0)
	fire.add_child(_fire_light)
	Atmosphere.make_smoke(fire, Vector3(0, 0.8, 0), 0.9)
	# tents, crates and bedrolls
	for sp in [[Vector3(6.5, 0, -3.5), 25.0], [Vector3(-6.0, 0, 4.0), 205.0]]:
		var tent := Node3D.new()
		tent.position = _c + (sp[0] as Vector3)
		tent.rotation_degrees.y = sp[1]
		_root.add_child(tent)
		var pm := PrismMesh.new()
		pm.size = Vector3(3.0, 2.2, 3.6)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = PropFactory.cloth(Color(0.42, 0.3, 0.2))
		mi.position = Vector3(0, 1.1, 0)
		tent.add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	PropsExtra.crate_stack(_root, _c + Vector3(-3.0, 0.0, -6.0), 40.0, rng)
	PropsExtra.crate_stack(_root, _c + Vector3(4.0, 0.0, 6.5), 100.0, rng)
	for k in 3:
		var a := 0.9 + k * 2.1
		PropFactory.cylinder(_root, 0.22, 0.22, 1.6, _c + Vector3(cos(a) * 3.0, 0.25, sin(a) * 3.0), PropFactory.wood(), Vector3(0, rad_to_deg(a), 90), false, 8)


## A small forest shrine on the trail with the twelve-rayed sun: where the ledger was kept.
func _shrine() -> void:
	var a := Vector2(_c.x, _c.z)
	var d := (Vector2(-90.0, 12.0) - a).normalized()
	var p := a + d * 24.0 + Vector2(-d.y, d.x) * 3.5
	var sh := Node3D.new()
	sh.position = Vector3(p.x, terrain.sample_height(p.x, p.y), p.y)
	_root.add_child(sh)
	PropFactory.box(sh, Vector3(1.6, 0.3, 1.6), Vector3(0, 0.15, 0), PropFactory.sandstone_dark(), Vector3.ZERO, true)
	PropFactory.box(sh, Vector3(1.1, 1.0, 1.1), Vector3(0, 0.8, 0), PropFactory.sandstone(), Vector3.ZERO, true)
	PropFactory.box(sh, Vector3(1.5, 0.18, 1.5), Vector3(0, 1.4, 0), PropFactory.sandstone_dark(), Vector3.ZERO, false)
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	lamp.mesh = sm
	lamp.material_override = PropFactory.glow_lamp()
	lamp.position = Vector3(0, 1.15, 0.58)
	sh.add_child(lamp)


# --- mission -----------------------------------------------------------------------------------

func _quest() -> void:
	story.quests.append({
		"id": "forest", "title": "The Forest Road",
		"blurb": "Pandit Rishi's scribe Tara went to the forest shrine for the old temple ledger and has not come back. The Reavers who took the council's gold may be hunting the same book.",
		"show": func() -> bool: return story.get_flag("temple_blessed"),
		"objs": [
			{"text": func() -> String: return "Find Tara in the Sal forest, north-west of the village",
			 "done": func() -> bool: return story.get_flag("forest_started"), "target": func() -> Vector3: return _c},
			{"text": func() -> String: return "Stop the men attacking her (%d/4)" % int(story.get_flag("forest_down", 0)),
			 "done": func() -> bool: return int(story.get_flag("forest_down", 0)) >= 4, "target": func() -> Vector3: return _c},
			{"text": func() -> String: return "Speak to Tara",
			 "done": func() -> bool: return story.get_flag("tara_talked"), "target": func() -> Vector3: return tara.global_position if tara != null else _c},
			{"text": func() -> String: return "Take the ledger to Pandit Rishi in the village",
			 "done": func() -> bool: return story.get_flag("ledger_given"), "target": func() -> Vector3: return _npc_pos("Priest")},
		],
	})
	story.changed.emit()


func _npc_pos(nm: String) -> Vector3:
	for n in main.npcs:
		if n.name == nm:
			return n.global_position
	return _c


func _activate() -> void:
	state = "waiting"
	tara = Npc.new().setup(NpcBuilder.PRESETS["lady_green"], "idle", "Tara")
	tara.player = player
	main.add_child(tara)
	var tp := _c + Vector3(-2.2, 0, 1.0)
	tp.y = terrain.sample_height(tp.x, tp.z) + 0.05
	tara.global_position = tp
	tara.rotation.y = atan2(-(_c.x - tp.x), -(_c.z - tp.z)) + PI
	tara.home_yaw = tara.rotation.y
	main.npcs.append(tara)
	story.refs["Tara"] = tara
	var it := Interactable.new()
	it.position = Vector3(0, 1.1, 0)
	it.prompt = "Talk to Tara"
	it.reach = 3.3
	tara.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
		dlg.open(story.dialogue_for("Tara"), tara, "woman")
	# four Reaver men around her; they stay put until the scene ends
	for k in 4:
		var a := 0.6 + k * TAU / 4.0
		var pos := tp + Vector3(cos(a) * 3.0, 0.2, sin(a) * 3.0)
		var e := combat.spawn_enemy(pos, false, 0.0, "forest")
		enemies.append(e)
		if k == 0:
			e.confesses = true
			e.on_surrender = func(_en: Enemy) -> void:
				story.set_flag("garr_confessed", true)
				hud.banner("CLUE: a council ring with the sun", "reveal")
		e.rotation.y = atan2(-(tp.x - pos.x), -(tp.z - pos.z))


func _process(delta: float) -> void:
	if _fire_light != null:
		_fire_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.021) * 0.35 + sin(Time.get_ticks_msec() * 0.043) * 0.2
	if state == "waiting" or state == "fight":
		_fear_t -= delta
		if _fear_t <= 0.0 and tara != null:
			_fear_t = 3.0
			tara.rig.play_action("startle", 1.0)
	if state == "waiting" and player.global_position.distance_to(_c) < 30.0 and not cin.playing and not dlg.is_open:
		_scene()


func _scene() -> void:
	state = "scene"
	story.set_flag("forest_started", true)
	Sfx.sting("surprise", -4.0)
	var tp := tara.global_position
	var lead := enemies[0].global_position
	var y := Vector3(0, 1.6, 0)
	var shots := [
		{"from": _c + Vector3(20, 8, 20), "to": _c + Vector3(11, 4.5, 11), "look": _c + Vector3(0, 1.2, 0), "dur": 3.5},
		{"from": tp + Vector3(2.6, 1.0, 2.4), "to": tp + Vector3(1.8, 0.9, 1.6), "look": tp + y, "dur": 5.0, "who": "Tara", "voice": "woman",
		 "text": "Please, let go of me! The ledger is not yours, and I am not yours either!"},
		{"from": lead + Vector3(-1.5, 1.7, 3.0), "to": lead + Vector3(-1.0, 1.6, 2.2), "look": lead + y, "dur": 5.0, "who": "Reaver Garr", "voice": "deep",
		 "text": "Nobody walks this road at dusk, girl. Scream all you like. The trees do not listen."},
		{"from": tp + Vector3(-3.0, 1.8, -2.5), "look": tp + y, "dur": 6.0, "who": "Reaver Naag", "voice": "man",
		 "text": "Hold her still. The priest's little scribe, alone in the dark with the book we want. We take the book, and then we take our time."},
		{"from": player.global_position + Vector3(0, 1.7, 2.8), "to": player.global_position + Vector3(0, 1.6, 1.4), "look": player.global_position + Vector3(0, 1.5, -3.0), "dur": 3.5,
		 "who": "You", "voice": "man", "text": "Take your hands off her. Now."},
		{"from": lead + Vector3(1.5, 1.7, 3.0), "look": lead + y, "dur": 4.0, "who": "Reaver Garr", "voice": "deep",
		 "text": "Walk away, stranger. This is none of your business."},
		{"from": player.global_position + Vector3(3.0, 1.5, 3.0), "to": player.global_position + Vector3(2.0, 1.4, 2.0), "look": player.global_position + Vector3(0, 1.5, 0), "dur": 5.5,
		 "who": "You", "voice": "man", "text": "A woman cried out for help. That makes it my business. Let her go, or answer to my hammer."},
	]
	cin.play(shots, "THE FOREST ROAD", func() -> void:
		state = "fight"
		Sfx.set_mood("tension")
		for e in enemies:
			if is_instance_valid(e):
				e.aggro = 45.0
		hud.banner("PROTECT TARA", "raid_horn"))


func _won() -> void:
	state = "done"
	Sfx.set_mood("")
	story.set_flag("tara_saved", true)
	Sfx.sting("victory", -3.0)
	hud.banner("TARA IS SAFE", "seal_found")
	StoryFX.sun_burst(main, tara.global_position + Vector3(0, 1.0, 0), 0.7)
	tara.rig.play_action("namaste", 2.5)
