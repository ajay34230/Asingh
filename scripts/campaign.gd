class_name Campaign
extends Node3D
## Acts 3-5. Act 3 "The Kingdom Beneath": the buried city of Veyra, built as a stone hall far off the map.
## Light three braziers, read three royal tablets, judge Karan, defeat the Stone Warden.
## Later acts add their quests to the same story via add_quest() and share the helpers here.

const ORIGIN := Vector3(700.0, 0.0, 700.0)     # Veyra, far outside the valley
const HALL_W := 40.0
const HALL_L := 130.0

var main: Node3D
var story: Story
var player: Player
var hud: Node
var dlg: DialogueUI
var combat: CombatBuilder
var terrain: TerrainBuilder
var cin: Cinematic
var gate_pos := Vector3.ZERO
var flames: Array[Node3D] = []
var brazier_its: Array[Interactable] = []
var karan_npc: Npc
var karan_it: Interactable
var warden: Enemy
var _warden_started := false
var act4: Act4
var act5: Act5

const TABLETS := [
	"TABLET I: Queen Ila raised Veyra beneath the reach of the sun, to keep the Sun Heart from those who would own it.",
	"TABLET II: The council begged her to wake the Heart and rule the world. Ila refused, and the council tried to take it by force.",
	"TABLET III: 'I chose the dark over a crown. Whoever opens this door must decide what the light is for.' - Ila",
]


func _o(x: float, y: float, z: float) -> Vector3:
	return ORIGIN + Vector3(x, y, z)


func build() -> void:
	add_to_group("campaign")
	gate_pos = story.refs.get("gate", Vector3(0, 8, -172))
	_build_hall()
	_build_braziers()
	_build_tablets()
	_build_karan()
	_entrances()
	_add_act3_quest()
	story.changed.connect(_on_changed)
	_on_changed()
	act4 = Act4.new()
	act4.camp = self
	add_child(act4)
	act4.build()
	act5 = Act5.new()
	act5.camp = self
	add_child(act5)
	act5.build()


# --- Veyra ---------------------------------------------------------------------------------

func _build_hall() -> void:
	var stone := PropFactory.stone(Color(0.55, 0.47, 0.36))
	var dark := PropFactory.stone(Color(0.38, 0.32, 0.26))
	var root := Node3D.new()
	root.name = "Veyra"
	add_child(root)
	PropFactory.box(root, Vector3(HALL_W, 1.0, HALL_L), _o(0, -0.5, 0), stone, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(1.2, 12.0, HALL_L), _o(-HALL_W * 0.5, 6.0, 0), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(1.2, 12.0, HALL_L), _o(HALL_W * 0.5, 6.0, 0), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(HALL_W, 12.0, 1.2), _o(0, 6.0, -HALL_L * 0.5), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(HALL_W, 12.0, 1.2), _o(0, 6.0, HALL_L * 0.5), dark, Vector3.ZERO, true, false)
	PropFactory.box(root, Vector3(HALL_W, 1.0, HALL_L), _o(0, 12.5, 0), dark, Vector3.ZERO, false, false)
	for i in 8:
		for sx in [-1.0, 1.0]:
			PropFactory.cylinder(root, 0.7, 0.8, 12.0, _o(sx * 12.0, 6.0, -55.0 + i * 15.0), stone, Vector3.ZERO, true, 10, 0, false)
	# warm light along the hall: a few real lights, the rest are glowing glass
	var glow := PropFactory.glow_lamp()
	for i in 6:
		var lp := _o(0.0, 9.0, -50.0 + i * 20.0)
		PropFactory.sphere(root, 0.35, lp, glow)
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.75, 0.45)
			l.omni_range = 26.0
			l.light_energy = 2.2
			root.add_child(l)
			l.global_position = lp


func _build_braziers() -> void:
	var iron := PropFactory.iron()
	var glow := PropFactory.glow_lamp()
	var spots := [Vector3(-8, 0, 30), Vector3(8, 0, 5), Vector3(-8, 0, -20)]
	for i in 3:
		var b := Node3D.new()
		b.name = "Brazier%d" % i
		add_child(b)
		b.global_position = _o(spots[i].x, 0, spots[i].z)
		PropFactory.cylinder(b, 0.15, 0.25, 1.2, Vector3(0, 0.6, 0), iron, Vector3.ZERO, false, 8, 0, false)
		PropFactory.cylinder(b, 0.6, 0.3, 0.4, Vector3(0, 1.35, 0), iron, Vector3.ZERO, false, 10, 0, false)
		var fl := PropFactory.sphere(b, 0.38, Vector3(0, 1.8, 0), glow, Vector3(1, 1.6, 1))
		fl.visible = false
		flames.append(fl)
		var it := Interactable.new()
		it.position = Vector3(0, 1.2, 0)
		it.prompt = "Light the brazier"
		it.reach = 3.0
		b.add_child(it)
		brazier_its.append(it)
		var idx := i
		it.on_interact = func(_by: Node3D, me: Interactable) -> void: light_brazier(idx, me)


func light_brazier(i: int, it: Interactable) -> bool:
	if story.get_flag("brazier_%d" % i, false):
		return false
	story.set_flag("brazier_%d" % i, true)
	story.add("braziers", 1)
	flames[i].visible = true
	it.enabled = false
	Sfx.ui_at("reveal", -4.0)
	return true


func _build_tablets() -> void:
	var stone := PropFactory.stone(Color(0.7, 0.62, 0.48))
	for i in 3:
		var t := Node3D.new()
		add_child(t)
		t.global_position = _o(-HALL_W * 0.5 + 1.0, 0, 25.0 - i * 22.0)
		PropFactory.box(t, Vector3(0.4, 2.4, 1.6), Vector3(0, 1.2, 0), stone, Vector3.ZERO, false, false)
		var it := Interactable.new()
		it.position = Vector3(0.8, 1.3, 0)
		it.prompt = "Read the tablet"
		it.reach = 3.0
		t.add_child(it)
		var idx := i
		it.on_interact = func(_by: Node3D, _me: Interactable) -> void: read_tablet(idx)


func read_tablet(i: int) -> void:
	var first: bool = not story.get_flag("tablet_%d" % i, false)
	if first:
		story.set_flag("tablet_%d" % i, true)
		story.add("tablets", 1)
	var nodes := {"n": {"who": "Tablet", "text": TABLETS[i], "choices": [{"t": "Continue.", "go": ""}]}}
	dlg.open({"start": "n", "nodes": nodes}, null, "old")


func _build_karan() -> void:
	var pr: Dictionary = (NpcBuilder.PRESETS["guard"] as Dictionary).duplicate()
	pr["tint"] = Color(0.5, 0.18, 0.16)
	karan_npc = Npc.new().setup(pr, "idle", "Captain Karan")
	karan_npc.player = player
	main.add_child(karan_npc)
	karan_npc.global_position = _o(0, 0.05, -38.0)
	karan_npc.rotation.y = 0.0
	karan_it = Interactable.new()
	karan_it.position = Vector3(0, 1.1, 0)
	karan_it.prompt = "Speak to Karan"
	karan_it.reach = 3.2
	karan_npc.add_child(karan_it)
	karan_it.on_interact = func(_by: Node3D, _me: Interactable) -> void: karan_talk()
	karan_it.enabled = false


func karan_talk() -> void:
	var n := {
		"a": {"who": "Captain Karan", "text": "I followed you down, hammer-bearer. Bound by my own men's rope. The Ashen Host serves a master who wants the Sun Heart, and I swore him my sword.",
			"go": "b"},
		"b": {"who": "Captain Karan", "text": "But I have read Ila's last words in this place. A crown is not worth the sun. I break my oath. Judge me as you must.",
			"choices": [
				{"t": "Live. Fight beside us.", "go": "", "set": {"karan_fate": "spared", "karan_met": true}},
				{"t": "Your crimes need an answer.", "go": "", "set": {"karan_fate": "condemned", "karan_met": true}, "add": {"coins": 100}},
			]},
	}
	dlg.open({"start": "a", "nodes": n}, karan_npc, "deep")


func _entrances() -> void:
	var down := Interactable.new()
	down.prompt = "Descend into Veyra"
	down.reach = 4.0
	down.position = gate_pos + Vector3(0, 0.0, 6.0)
	main.add_child(down)
	down.on_interact = func(_by: Node3D, _me: Interactable) -> void: descend()
	down.set_meta("veyra_down", true)
	var up := Interactable.new()
	up.prompt = "Return to the valley"
	up.reach = 4.0
	up.position = _o(0, 1.0, HALL_L * 0.5 - 3.0)
	add_child(up)
	up.on_interact = func(_by: Node3D, _me: Interactable) -> void: ascend()


func descend() -> bool:
	if not story.get_flag("captain_down", false):
		hud.banner(Loc.t("The way down is still sealed."), "")
		return false
	player.global_position = _o(0, 1.0, HALL_L * 0.5 - 8.0)
	player.velocity = Vector3.ZERO
	story.set_flag("v_entered", true)
	Sfx.ui_at("stone_boom", -4.0)
	return true


func ascend() -> void:
	player.global_position = gate_pos + Vector3(0, 1.0, 10.0)
	player.velocity = Vector3.ZERO


# --- warden boss ---------------------------------------------------------------------------

func _on_changed() -> void:
	if karan_it != null:
		karan_it.enabled = int(story.get_flag("braziers", 0)) >= 3 and int(story.get_flag("tablets", 0)) >= 3 and not story.get_flag("karan_met", false)
	if story.get_flag("karan_met", false) and not _warden_started:
		_warden_started = true
		spawn_warden.call_deferred()
	if story.get_flag("warden_down", false) and not story.get_flag("act3_done", false):
		story.set_flag("act3_done", true)
		story.set_flag("coins", int(story.get_flag("coins", 0)) + 300)
		var itm := main.get("items") as Items
		if itm != null:
			itm.give("chain")
		hud.banner("ACT 3 COMPLETE", "mission_new")
		Sfx.sting("victory", -3.0)


func spawn_warden() -> Enemy:
	warden = combat.spawn_enemy(_o(0, 0.3, -55.0), true, 60.0, "warden")
	warden.name = "StoneWarden"
	warden.hp = 480.0
	warden.max_hp = 480.0
	warden.damage = 20.0
	warden.scale = Vector3.ONE * 1.35
	warden._refresh_bar()
	hud.banner(Loc.t("The Stone Warden awakens!"), "reveal")
	return warden


# --- quests --------------------------------------------------------------------------------

func add_quest(q: Dictionary) -> void:
	story.quests.append(q)


func _add_act3_quest() -> void:
	var s := story
	add_quest({
		"id": "veyra", "title": "ACT 3: The Kingdom Beneath",
		"blurb": "Captain Karan is beaten, and the way below the Sun Gate is open. Find out what Queen Ila hid in Veyra.",
		"show": func() -> bool: return s.get_flag("captain_down"),
		"objs": [
			{"text": func() -> String: return "Descend into Veyra at the Sun Gate",
			 "done": func() -> bool: return s.get_flag("v_entered"), "target": func() -> Vector3: return gate_pos + Vector3(0, 0, 6)},
			{"text": func() -> String: return "Light the three braziers (%d/3)" % int(s.get_flag("braziers", 0)),
			 "done": func() -> bool: return int(s.get_flag("braziers", 0)) >= 3, "target": func() -> Vector3: return _o(0, 0, 5)},
			{"text": func() -> String: return "Read the royal tablets (%d/3)" % int(s.get_flag("tablets", 0)),
			 "done": func() -> bool: return int(s.get_flag("tablets", 0)) >= 3, "target": func() -> Vector3: return _o(-19, 0, 5)},
			{"text": func() -> String: return "Judge Captain Karan",
			 "done": func() -> bool: return s.get_flag("karan_met"), "target": func() -> Vector3: return _o(0, 0, -38)},
			{"text": func() -> String: return "Defeat the Stone Warden",
			 "done": func() -> bool: return s.get_flag("warden_down"), "target": func() -> Vector3: return _o(0, 0, -55)},
		],
	})
