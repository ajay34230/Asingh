class_name Act4
extends Node3D
## ACT 4: The Fallen Crown. The Ashen Host marches under Vessa.
## Clear three Ashen outposts, free a prisoner, hear Scholar Vikram's confession, hold the village
## against three waves, then defeat the warlord Vessa.

const OUTPOSTS := [Vector2(-130.0, 120.0), Vector2(150.0, 60.0), Vector2(-40.0, 205.0)]
const WAVES := [4, 5, 6]
const ROLES := ["grunt", "shield", "archer", "brute", "ambusher", "grunt"]

var camp: Campaign
var story: Story
var hud: Node
var combat: CombatBuilder
var terrain: TerrainBuilder
var player: Player
var town: TownBuilder
var groups: Array = []            # per outpost: Array[Enemy]
var cleared := [false, false, false]
var prisoner: Npc
var prisoner_it: Interactable
var vikram: Npc
var vikram_it: Interactable
var vessa: Enemy
var _wave := 0
var _t := 0.0
var _started := false


func build() -> void:
	story = camp.story
	hud = camp.hud
	combat = camp.combat
	terrain = camp.terrain
	player = camp.player
	town = camp.main.get("town") as TownBuilder
	add_to_group("act4")
	story.changed.connect(_on_changed)
	_add_quest()
	_on_changed()


func _gp(v: Vector2) -> Vector3:
	return Vector3(v.x, terrain.sample_height(v.x, v.y), v.y)


func _on_changed() -> void:
	if story.get_flag("act3_done", false) and not _started:
		_started = true
		_spawn_outposts()
		hud.banner(Loc.t("ACT 4: The Fallen Crown"), "mission_new")
	if story.get_flag("a4_freed", false) and vikram == null:
		_spawn_vikram()
	if story.get_flag("vikram_met", false) and _wave == 0 and not story.get_flag("siege_won", false):
		start_siege()
	if story.get_flag("vessa_down", false) and not story.get_flag("act4_done", false):
		story.set_flag("act4_done", true)
		story.set_flag("coins", int(story.get_flag("coins", 0)) + 500)
		var itm := camp.main.get("items") as Items
		if itm != null:
			itm.give("iron", 4)
			itm.give("potion", 2)
		hud.banner("ACT 4 COMPLETE", "mission_new")
		Sfx.sting("victory", -3.0)


# --- outposts ------------------------------------------------------------------------------

func _spawn_outposts() -> void:
	var cloth := PropFactory.material(Color(0.18, 0.18, 0.2), 0.9)
	var red := PropFactory.material(Color(0.6, 0.12, 0.1), 0.9)
	var glow := PropFactory.glow_lamp()
	for i in OUTPOSTS.size():
		var c := _gp(OUTPOSTS[i])
		var post := Node3D.new()
		post.name = "AshenOutpost%d" % i
		add_child(post)
		post.global_position = c
		PropFactory.cylinder(post, 0.08, 0.1, 6.0, Vector3(0, 3.0, 0), PropFactory.wood(), Vector3.ZERO, false, 6, 0, false)
		PropFactory.box(post, Vector3(1.4, 1.0, 0.04), Vector3(0.75, 5.3, 0), red, Vector3.ZERO, false, false)
		for k in 3:
			var a: float = k * TAU / 3.0 + 0.5
			PropFactory.box(post, Vector3(3.0, 1.8, 3.0), Vector3(cos(a) * 6.0, 0.9, sin(a) * 6.0), cloth, Vector3(0, rad_to_deg(a), 0), false, false)
		PropFactory.sphere(post, 0.35, Vector3(0, 0.4, 2.0), glow)
		var list: Array = []
		for k in 5:
			var a2: float = k * TAU / 5.0
			var e := combat.spawn_enemy(c + Vector3(cos(a2) * 3.5, 0.5, sin(a2) * 3.5), false, 16.0, "outpost")
			e.apply_role(ROLES[(i + k) % ROLES.size()])
			e.name = "Ashen%d_%d" % [i, k]
			list.append(e)
		groups.append(list)
	# the prisoner is held at the last outpost
	var pr: Dictionary = (NpcBuilder.PRESETS["villager_man"] as Dictionary).duplicate()
	prisoner = Npc.new().setup(pr, "idle", "Prisoner")
	prisoner.player = player
	camp.main.add_child(prisoner)
	prisoner.global_position = _gp(OUTPOSTS[2]) + Vector3(4.0, 0.2, -3.0)
	prisoner_it = Interactable.new()
	prisoner_it.position = Vector3(0, 1.1, 0)
	prisoner_it.prompt = "Cut the prisoner free"
	prisoner_it.reach = 3.0
	prisoner_it.enabled = false
	prisoner.add_child(prisoner_it)
	prisoner_it.on_interact = func(_by: Node3D, me: Interactable) -> void: free_prisoner(me)


func outposts_cleared() -> int:
	var n := 0
	for c in cleared:
		if c:
			n += 1
	return n


func _check_outposts() -> void:
	for i in groups.size():
		if cleared[i]:
			continue
		var alive := 0
		for e in groups[i]:
			if is_instance_valid(e) and not (e as Enemy).dead:
				alive += 1
		if alive == 0:
			cleared[i] = true
			story.set_flag("outposts_cleared", outposts_cleared())
			hud.banner(Loc.t("Outpost cleared!"), "seal_found")
	if outposts_cleared() >= 3 and prisoner_it != null and not story.get_flag("a4_freed", false):
		prisoner_it.enabled = true


func free_prisoner(it: Interactable) -> void:
	story.set_flag("a4_freed", true)
	it.enabled = false
	hud.banner(Loc.t("The prisoner is free: 'Vikram has been selling your secrets!'"), "reveal")


# --- betrayal ------------------------------------------------------------------------------

func _spawn_vikram() -> void:
	var pr: Dictionary = (NpcBuilder.PRESETS["scholar"] as Dictionary).duplicate()
	vikram = Npc.new().setup(pr, "idle", "Scholar Vikram")
	vikram.player = player
	camp.main.add_child(vikram)
	var p: Vector3 = town.inn_pos + Vector3(-6.0, 0.0, 6.0)
	p.y = terrain.sample_height(p.x, p.z) + 0.05
	vikram.global_position = p
	vikram_it = Interactable.new()
	vikram_it.position = Vector3(0, 1.1, 0)
	vikram_it.prompt = "Confront Scholar Vikram"
	vikram_it.reach = 3.2
	vikram.add_child(vikram_it)
	vikram_it.on_interact = func(_by: Node3D, _me: Interactable) -> void: vikram_talk()
	camp.main.npcs.append(vikram)


func vikram_talk() -> void:
	var n := {
		"a": {"who": "Scholar Vikram", "text": "So you know. Vessa promised my library would be saved. I gave her the road to the Sun Gate and the names of the seal-keepers. I did not know she would burn the roads.", "go": "b"},
		"b": {"who": "Scholar Vikram", "text": "She is coming for the village tonight, with the whole Ashen Host. I can still tell you where she will strike. What do you do with me?",
			"choices": [
				{"t": "Help us hold the village.", "go": "", "set": {"vikram_fate": "forgiven", "vikram_met": true}},
				{"t": "Leave. You are done here.", "go": "", "set": {"vikram_fate": "exiled", "vikram_met": true}},
			]},
	}
	camp.dlg.open({"start": "a", "nodes": n}, vikram, "man")


# --- siege and Vessa -----------------------------------------------------------------------

func start_siege() -> void:
	_wave = 1
	hud.banner(Loc.t("THE SIEGE BEGINS! Hold the village!"), "raid_panic")
	var itm := camp.main.get("items") as Items
	if story.get_flag("karan_fate", "") == "spared" and itm != null:
		itm.give("potion", 2)
		hud.banner(Loc.t("Karan arrives with potions for the siege."), "")
	if story.get_flag("vikram_fate", "") == "forgiven" and itm != null:
		itm.give("herb", 3)
	_spawn_wave(0)


func _spawn_wave(w: int) -> void:
	var c: Vector3 = town.inn_pos
	for k in WAVES[w]:
		var a: float = k * TAU / float(WAVES[w]) + w * 0.7
		var p := c + Vector3(cos(a) * 34.0, 0.0, sin(a) * 34.0)
		p.y = terrain.sample_height(p.x, p.z) + 0.5
		var e := combat.spawn_enemy(p, false, 90.0, "siege")
		e.apply_role(ROLES[(k + w) % ROLES.size()])


func spawn_vessa() -> Enemy:
	var c: Vector3 = town.inn_pos + Vector3(0.0, 0.0, -38.0)
	c.y = terrain.sample_height(c.x, c.z) + 0.5
	vessa = combat.spawn_enemy(c, true, 90.0, "vessa")
	vessa.name = "Vessa"
	vessa.hp = 620.0
	vessa.max_hp = 620.0
	vessa.damage = 22.0
	vessa.scale = Vector3.ONE * 1.2
	vessa._refresh_bar()
	vessa.say("The Sun Heart will be mine!")
	hud.banner(Loc.t("VESSA, the Ashen Warlord, has come!"), "war_roar")
	return vessa


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	if _started:
		_check_outposts()
	var down := int(story.get_flag("siege_down", 0))
	if _wave == 1 and down >= WAVES[0]:
		_wave = 2
		_spawn_wave(1)
		hud.banner(Loc.t("Second wave!"), "raid_panic")
	elif _wave == 2 and down >= WAVES[0] + WAVES[1]:
		_wave = 3
		_spawn_wave(2)
		hud.banner(Loc.t("Final wave!"), "raid_panic")
	elif _wave == 3 and down >= WAVES[0] + WAVES[1] + WAVES[2]:
		_wave = 4
		story.set_flag("siege_won", true)
		spawn_vessa()


# --- quest ---------------------------------------------------------------------------------

func _add_quest() -> void:
	var s := story
	camp.add_quest({
		"id": "fallen_crown", "title": "ACT 4: The Fallen Crown",
		"blurb": "The Ashen Host marches under the warlord Vessa. Break her outposts, learn who betrayed you, and hold the village.",
		"show": func() -> bool: return s.get_flag("act3_done"),
		"objs": [
			{"text": func() -> String: return "Clear the Ashen outposts (%d/3)" % int(s.get_flag("outposts_cleared", 0)),
			 "done": func() -> bool: return int(s.get_flag("outposts_cleared", 0)) >= 3, "target": func() -> Vector3: return _next_outpost()},
			{"text": func() -> String: return "Free the prisoner at the last outpost",
			 "done": func() -> bool: return s.get_flag("a4_freed"), "target": func() -> Vector3: return _gp(OUTPOSTS[2])},
			{"text": func() -> String: return "Confront Scholar Vikram at the inn",
			 "done": func() -> bool: return s.get_flag("vikram_met"), "target": func() -> Vector3: return vikram.global_position if vikram != null else Vector3.ZERO},
			{"text": func() -> String: return "Hold the village against the siege",
			 "done": func() -> bool: return s.get_flag("siege_won"), "target": func() -> Vector3: return town.inn_pos},
			{"text": func() -> String: return "Defeat Vessa, the Ashen Warlord",
			 "done": func() -> bool: return s.get_flag("vessa_down"), "target": func() -> Vector3: return vessa.global_position if vessa != null and is_instance_valid(vessa) else town.inn_pos},
		],
	})


func _next_outpost() -> Vector3:
	for i in OUTPOSTS.size():
		if not cleared[i]:
			return _gp(OUTPOSTS[i])
	return _gp(OUTPOSTS[2])
