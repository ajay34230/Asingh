class_name BazaarQuest
extends Node
## Side mission "Whispers in the Bazaar". After Pandit Rishi reads the ledger (a single K), the player
## asks Raju the chaiwala and Pansari Lal the spice-seller what they have heard, learns that a clerk hid
## a box behind the Musafir Inn, fights the Reaver hirelings guarding it, takes the receipt inside and
## brings it to Pandit Rishi (the Priest dialogue) for 200 coins.

var main: Node3D
var story: Story
var hud: QuestHUD
var dlg: DialogueUI
var terrain: TerrainBuilder
var player: Player
var combat: CombatBuilder
var town: TownBuilder
var raju: Npc
var lal: Npc
var enemies: Array[Enemy] = []
var crate_pos := Vector3.ZERO
var state := "dormant"      # dormant, active, fight, cleared, looted
var _crate: Node3D
var _crate_it: Interactable


func _init(m: Node3D, s: Story, h: QuestHUD, d: DialogueUI, t: TerrainBuilder, p: Player, cb: CombatBuilder, tw: TownBuilder) -> void:
	main = m
	story = s
	hud = h
	dlg = d
	terrain = t
	player = p
	combat = cb
	town = tw
	name = "BazaarQuest"


func build() -> void:
	main.add_child(self)
	_quest()
	story.changed.connect(_on_changed)
	_on_changed()


func _on_changed() -> void:
	if state == "dormant" and story.get_flag("ledger_given"):
		_activate()
	elif state == "fight" and int(story.get_flag("bazaar_down", 0)) >= 3:
		state = "cleared"
		hud.banner("The guards are down. Search the box.", "reveal")
		if _crate_it != null:
			_crate_it.enabled = true


func _stall_spot(kind: String) -> Vector3:
	for s in town.stalls:
		if s["kind"] == kind:
			var p: Vector3 = (s["node"] as Node3D).global_position + (s["fwd"] as Vector3) * 2.6 + Vector3(1.3, 0, 0)
			p.y = terrain.sample_height(p.x, p.z) + 0.05
			return p
	return town.inn_pos


func _spawn_npc(key: String, label: String, kind: String, who: String) -> Npc:
	var n := Npc.new().setup(NpcBuilder.PRESETS[key], "idle", label)
	n.player = player
	main.add_child(n)
	var p := _stall_spot(kind)
	n.global_position = p
	n.rotation.y = atan2(-(town.root.global_position.x - p.x), -(town.root.global_position.z - p.z)) + PI
	n.home_yaw = n.rotation.y
	main.npcs.append(n)
	var it := Interactable.new()
	it.position = Vector3(0, 1.1, 0)
	it.prompt = "Talk to %s" % label
	it.reach = 3.0
	n.add_child(it)
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
		dlg.open(story.dialogue_for(who), n, "man")
	return n


func _activate() -> void:
	state = "active"
	raju = _spawn_npc("potter", "Raju", "tea", "BzRaju")
	lal = _spawn_npc("trader", "Lal", "spice", "BzLal")
	var back := Basis(Vector3.UP, town.inn_yaw) * Vector3(0, 0, -1)
	crate_pos = town.inn_pos + back * 7.5
	crate_pos.y = terrain.sample_height(crate_pos.x, crate_pos.z)
	_crate = Node3D.new()
	_crate.name = "InnCrate"
	main.add_child(_crate)
	_crate.global_position = crate_pos
	PropsExtra.crate_stack(_crate, Vector3.ZERO, 0.4, RandomNumberGenerator.new())
	_crate_it = Interactable.new()
	_crate_it.position = Vector3(0, 0.9, 0)
	_crate_it.prompt = "Search the box under the sacks"
	_crate_it.reach = 3.0
	_crate_it.enabled = false
	_crate.add_child(_crate_it)
	_crate_it.on_interact = func(_by: Node3D, _me: Interactable) -> void:
		story.set_flag("bz_receipt", true)
		state = "looted"
		_crate_it.enabled = false
		hud.banner("RECEIPT FOUND: signed K. Vasu", "seal_found")
	var done: bool = story.get_flag("bz_done") or story.get_flag("bz_receipt")
	if done:
		_crate_it.enabled = false
		return
	if story.get_flag("bz_lal"):
		_spawn_guards()


func _spawn_guards() -> void:
	if not enemies.is_empty():
		return
	state = "fight"
	story.flags["bazaar_down"] = 0
	for k in 3:
		var a := 0.5 + k * TAU / 3.0
		var pos := crate_pos + Vector3(cos(a) * 2.6, 0.2, sin(a) * 2.6)
		pos.y = terrain.sample_height(pos.x, pos.z) + 0.2
		var e := combat.spawn_enemy(pos, false, 14.0, "bazaar")
		e.rotation.y = atan2(-(crate_pos.x - pos.x), -(crate_pos.z - pos.z))
		enemies.append(e)


func _process(_delta: float) -> void:
	# the guards only appear once Lal has told the player where the box is, so wait for that
	if state == "active" and story.get_flag("bz_lal") and enemies.is_empty():
		_spawn_guards()


func _quest() -> void:
	story.quests.append({
		"id": "bazaar", "title": "Side: Whispers in the Bazaar",
		"blurb": "The ledger carries one letter, K. Somewhere in the bazaar a council clerk paid the Reavers. Chai-sellers and spice-sellers hear everything.",
		"show": func() -> bool: return story.get_flag("ledger_given"),
		"objs": [
			{"text": func() -> String: return "Ask Raju at the chai stall what he has heard",
			 "done": func() -> bool: return story.get_flag("bz_raju"), "target": func() -> Vector3: return raju.global_position if raju != null else Vector3.ZERO},
			{"text": func() -> String: return "Ask Pansari Lal at the spice stall",
			 "done": func() -> bool: return story.get_flag("bz_lal"), "target": func() -> Vector3: return lal.global_position if lal != null else Vector3.ZERO},
			{"text": func() -> String: return "Beat the guards behind the Musafir Inn (%d/3)" % mini(3, int(story.get_flag("bazaar_down", 0))),
			 "done": func() -> bool: return int(story.get_flag("bazaar_down", 0)) >= 3 or story.get_flag("bz_receipt"), "target": func() -> Vector3: return crate_pos},
			{"text": func() -> String: return "Search the box for the clerk's receipt",
			 "done": func() -> bool: return story.get_flag("bz_receipt"), "target": func() -> Vector3: return crate_pos},
			{"text": func() -> String: return "Take the receipt to Pandit Rishi",
			 "done": func() -> bool: return story.get_flag("bz_done"), "target": func() -> Vector3: return _rishi()},
		],
	})
	story.changed.emit()


func _rishi() -> Vector3:
	for n in main.npcs:
		if n.name == "Priest":
			return n.global_position
	return Vector3.ZERO
