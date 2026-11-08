class_name MonsterMissions
extends Node3D
## Ghost and monster missions, played one after another. Walk (or ride) into a mission area and it begins:
## a short cinematic of the monsters rising, then waves to beat. "Protect" missions also have a village
## that loses heart while ghosts haunt its centre; let it fall and the mission restarts.
## Rewards every time: coins, a new weapon or supplies, a star rating, and the next mission unlocked.
## Kill streaks pay extra. Story text is kept to a line or two.

const MISSIONS := [
	{"id": "m_ghost1", "title": "The Restless Dead", "short": "Ghosts rise from the old graveyard. Protect the village!",
	 "at": Vector2(-122.0, 56.0), "goal": Vector2(-90.0, 12.0), "night": true, "place": "the village graveyard", "protect": "the village",
	 "waves": [[["ghost", 3]], [["ghost", 4]], [["ghost", 3], ["ghost_skull", 2]]],
	 "gift": "bow", "coins": 60, "line": "Chief Bhairav: Take my bow! Arrows hurt ghosts the most."},
	{"id": "m_bones", "title": "Bones of the Old Road", "short": "Skeleton raiders block the Southern Road.",
	 "at": Vector2(-24.0, 290.0), "goal": Vector2.ZERO, "night": false, "place": "the Southern Road",
	 "waves": [[["skeleton", 3]], [["skeleton", 4]]],
	 "gift": "sword", "coins": 90, "line": "A talwar lies among the bones. It is yours now."},
	{"id": "m_skulls", "title": "Skulls over Kesar Sarai", "short": "Flying skulls circle the caravan inn. Save it!",
	 "at": FrontierBuilder.SARAI_C, "goal": FrontierBuilder.SARAI_C, "night": true, "place": "Kesar Sarai",
	 "waves": [[["ghost_skull", 4]], [["ghost", 3], ["ghost_skull", 3]], [["ghost_skull", 6]]],
	 "gift": "dagger", "coins": 110, "line": "Gulzar: A silver dagger, for the one who saved my inn."},
	{"id": "m_yeti", "title": "The Beast of Sal Forest", "short": "Something huge hunts in the forest.",
	 "at": TerrainBuilder.FOREST_C, "goal": Vector2.ZERO, "night": false, "place": "the Sal Forest",
	 "waves": [[["skeleton", 3]], [["yeti", 1]]],
	 "gift": "potion", "coins": 150, "line": ""},
	{"id": "m_mush", "title": "The Mushroom King", "short": "A giant fungus king is poisoning the forest edge.",
	 "at": Vector2(-150.0, -55.0), "goal": Vector2.ZERO, "night": true, "place": "the forest edge",
	 "waves": [[["ghost_skull", 3], ["skeleton", 2]], [["mushroom_king", 1]]],
	 "gift": "potion", "coins": 160, "line": ""},
	{"id": "m_demon", "title": "The Demon of Dhoopgarh", "short": "A demon walks into Dhoopgarh. Stand with the village!",
	 "at": FrontierBuilder.DHOOP_C, "goal": FrontierBuilder.DHOOP_C, "night": true, "place": "Dhoopgarh",
	 "waves": [[["skeleton", 4]], [["ghost", 4], ["ghost_skull", 2]], [["demon", 1]]],
	 "gift": "axe", "coins": 250, "line": "Headman Ratan: Dhoopgarh will sing your name."},
	{"id": "m_dragon", "title": "Wings over the Dunes", "short": "A dragon nests on the plateau. End it.",
	 "at": Vector2(40.0, 520.0), "goal": Vector2.ZERO, "night": false, "place": "the dragon's dune",
	 "waves": [[["ghost_skull", 4]], [["dragon", 1]]],
	 "gift": "potion", "coins": 300, "line": ""},
]
const START_RADIUS := 26.0

var main: Node3D
var story: Story
var player: Player
var terrain: TerrainBuilder
var hud: Node
var cin: Cinematic
var combat: CombatBuilder
var running := ""                 # id of the mission in progress
var wave := 0
var village := 100.0              # "protect" missions: the village's heart, 0 = lost
var alive: Array = []
var _m: Dictionary = {}
var _tick := 0.0
var _wave_wait := -1.0
var _t0 := 0.0
var _hp_lost := 0.0
var _hp_last := 0.0
var _streak := 0
var _streak_t := 0.0
var _saved_tod := -1.0
var _graves: Node3D


func build() -> void:
	add_to_group("monster_missions")
	_build_graveyard()
	for i in MISSIONS.size():
		var m: Dictionary = MISSIONS[i]
		var prev: String = "" if i == 0 else String(MISSIONS[i - 1]["id"])
		var id: String = m["id"]
		var q := {
			"id": id, "title": String(m["title"]), "blurb": String(m["short"]),
			"show": func() -> bool: return prev == "" or bool(story.get_flag(prev + "_done", false)),
			"objs": [
				{"text": func() -> String: return Loc.tf("Go to %s", [String(m["place"])]),
				 "done": func() -> bool: return bool(story.get_flag(id + "_started", false)) or bool(story.get_flag(id + "_done", false)),
				 "target": func() -> Vector3: return _ground(m["at"])},
				{"text": func() -> String: return _obj_text(m),
				 "done": func() -> bool: return bool(story.get_flag(id + "_done", false)),
				 "target": func() -> Vector3: return _ground(m["at"])},
			],
		}
		if i == 0:
			story.quests.insert(0, q)       # the first thing to do in a new game
		else:
			story.quests.append(q)
	story.quests.insert(1, {
		"id": "raid", "title": "Night Raid", "blurb": "Ghosts attack a settlement.",
		"show": func() -> bool: return not pending_raid.is_empty() or running == "raid",
		"objs": [
			{"text": func() -> String: return Loc.tf("Hurry to %s", [String(pending_raid["place"])]) if not pending_raid.is_empty() else "Hurry to the raid",
			 "done": func() -> bool: return running == "raid",
			 "target": func() -> Vector3: return _ground(pending_raid["at"]) if not pending_raid.is_empty() else (_ground(_m["at"]) if running == "raid" else Vector3.ZERO)},
			{"text": func() -> String: return _obj_text(_m) if running == "raid" else "Drive the ghosts away",
			 "done": func() -> bool: return pending_raid.is_empty() and running != "raid",
			 "target": func() -> Vector3: return _ground(_m["at"]) if running == "raid" else Vector3.ZERO},
		],
	})


func _obj_text(m: Dictionary) -> String:
	var n: int = (m["waves"] as Array).size()
	if running == String(m["id"]):
		var left := alive.size()
		var s := Loc.t("Wave %d/%d: %d left" % [wave + 1, n, left])
		if Vector2(m["goal"]) != Vector2.ZERO:
			s = Loc.tf("Protect %s (%d%%).", [String(m.get("protect", m["place"])), int(village)]) + " " + s
		return s
	return String(m["short"])


func _ground(p: Variant) -> Vector3:
	var v: Vector2 = p
	return Vector3(v.x, terrain.sample_height(v.x, v.y), v.y)


## The village graveyard (Kenney Graveyard Kit, CC0): where the first ghosts rise.
func _build_graveyard() -> void:
	_graves = Node3D.new()
	_graves.name = "Graveyard"
	add_child(_graves)
	var c: Vector2 = MISSIONS[0]["at"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var stones := ["gravestoneCross", "gravestoneRound", "gravestoneBroken", "gravestoneCross", "gravestoneRound"]
	for i in 14:
		var p := c + Vector2((i % 5) * 2.6 - 5.2, int(i / 5) * 3.2 - 3.2) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4))
		_prop(stones[i % stones.size()], p, rng.randf_range(-12.0, 12.0) + 180.0, 1.6)
	_prop("crypt", c + Vector2(0.0, -9.0), 180.0, 4.0)
	for k in 6:
		_prop("fenceDamaged", c + Vector2(-8.0 + k * 3.2, 7.0), 0.0, 1.9)
	_prop("lanternCandle", c + Vector2(6.5, 6.0), 0.0, 0.9)
	_prop("fireBasket", c + Vector2(-7.0, -6.0), 0.0, 1.2)
	_prop("coffinOld", c + Vector2(3.5, -5.0), 70.0, 1.0)
	_prop("pumpkinCarved", c + Vector2(-3.0, 5.5), 30.0, 0.55)


func _prop(file: String, p: Vector2, yaw_deg: float, size: float) -> void:
	var path := "res://assets/graveyard/%s.glb" % file
	if not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != inst:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb := xf * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var holder := Node3D.new()
	_graves.add_child(holder)
	holder.add_child(inst)
	var sc := size / maxf(box.size.y, 0.01)
	inst.scale = Vector3.ONE * sc
	inst.position = Vector3(-box.get_center().x * sc, -box.position.y * sc, -box.get_center().z * sc)
	holder.global_position = _ground(p)
	holder.rotation_degrees.y = yaw_deg
	if size > 1.5:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(box.size.x * sc, box.size.y * sc, box.size.z * sc)
		cs.shape = bs
		cs.position.y = bs.size.y * 0.5
		body.add_child(cs)
		holder.add_child(body)


func available() -> Dictionary:
	for i in MISSIONS.size():
		var m: Dictionary = MISSIONS[i]
		if bool(story.get_flag(String(m["id"]) + "_done", false)):
			continue
		if i > 0 and not bool(story.get_flag(String(MISSIONS[i - 1]["id"]) + "_done", false)):
			return {}
		return m
	return {}


func _process(delta: float) -> void:
	if player == null:
		return
	if running != "":
		_run(delta)
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.3
	_check_raids()
	if player.dead or player.locked or (cin != null and cin.playing):
		return
	if not pending_raid.is_empty():
		var ra: Vector2 = pending_raid["at"]
		if Vector2(player.global_position.x - ra.x, player.global_position.z - ra.y).length() < START_RADIUS:
			var pr := pending_raid
			pending_raid = {}
			start(pr)
			return
	var m := available()
	if m.is_empty():
		return
	var at: Vector2 = m["at"]
	if Vector2(player.global_position.x - at.x, player.global_position.z - at.y).length() < START_RADIUS:
		start(m)


# --- night raids: after the first mission, some nights ghosts attack a settlement on their own ----------
const RAID_SPOTS := [
	["the village", Vector2(-90.0, 12.0)], ["Bazaar Town", Vector2(22.0, -42.0)],
	["Kesar Sarai", FrontierBuilder.SARAI_C], ["Dhoopgarh", FrontierBuilder.DHOOP_C],
]
var pending_raid: Dictionary = {}
var _raid_rolled := false
var raid_chance := 0.6


static func is_night(tod: float) -> bool:
	return tod > 0.8 or tod < 0.18


func _check_raids() -> void:
	var atmo: Object = main.get("atmosphere")
	if atmo == null or not bool(story.get_flag("m_ghost1_done", false)):
		return
	var night := is_night(float(atmo.get("time_of_day")))
	if not night:
		_raid_rolled = false
		if not pending_raid.is_empty():
			pending_raid = {}
			if hud != null:
				hud.call("banner", "Dawn. The raiders faded away.", "")
			story.changed.emit()
		return
	if _raid_rolled or running != "":
		return
	_raid_rolled = true
	if randf() < raid_chance:
		raid_now()


## Announce a raid on a random settlement (it starts when the player gets there).
func raid_now(spot_index: int = -1) -> void:
	var sp: Array = RAID_SPOTS[spot_index if spot_index >= 0 else randi() % RAID_SPOTS.size()]
	var lv := 1
	var pg := get_tree().get_first_node_in_group("progression")
	if pg != null:
		lv = int(pg.call("level"))
	var extra := mini(lv / 3, 4)
	pending_raid = {
		"id": "raid", "title": Loc.tf("Night Raid: %s", [String(sp[0]).capitalize()]), "short": Loc.tf("Ghosts are raiding %s! Hurry!", [String(sp[0])]),
		"at": sp[1], "goal": sp[1], "night": false, "place": String(sp[0]), "protect": String(sp[0]),
		"waves": [[["ghost", 3 + extra]], [["ghost", 2 + extra], ["ghost_skull", 2]]],
		"gift": "", "coins": 50 + 10 * lv, "line": "", "repeat": true,
	}
	Sfx.ui("sting_danger", -4.0)
	if hud != null:
		hud.call("banner", "NIGHT RAID!\n" + Loc.tf("Ghosts are attacking %s", [String(sp[0])]), "mission_new")
	story.changed.emit()


func start(m: Dictionary, skip_intro: bool = false) -> void:
	_m = m
	running = String(m["id"])
	wave = 0
	village = 100.0
	alive.clear()
	_t0 = Time.get_ticks_msec() / 1000.0
	_hp_lost = 0.0
	_hp_last = player.hp
	_streak = 0
	story.set_flag(running + "_started", true)
	LogCollector.event("monster mission start " + running)
	var atmo: Object = main.get("atmosphere")
	if bool(m["night"]) and atmo != null:
		_saved_tod = float(atmo.get("time_of_day"))
		atmo.set("time_of_day", 0.9)
		atmo.call("apply_time")
	var gift: String = m["gift"]
	if running == "m_ghost1":
		var it := get_tree().get_first_node_in_group("items")
		if it != null and int(it.call("count", "bow")) < 1:
			it.call("give", "bow")
		player.set_weapon("bow")
	_spawn_wave(true)
	var at := _ground(m["at"])
	if skip_intro or cin == null:
		_announce()
		return
	var pp := player.global_position
	var shots := [
		{"from": pp + Vector3(0, 3.0, 0) + (pp - at).normalized() * 5.0, "to": pp + Vector3(0, 2.4, 0) + (pp - at).normalized() * 2.0,
		 "look": at + Vector3(0, 1.2, 0), "dur": 2.6, "text": String(m["short"])},
		{"from": at + Vector3(7.0, 2.5, 7.0), "to": at + Vector3(4.0, 1.8, 4.0), "look": at + Vector3(0, 1.6, 0), "dur": 2.6,
		 "text": String(m["line"]) if String(m["line"]) != "" and gift == "bow" else ""},
	]
	Sfx.ui("sting_danger", -2.0)
	cin.play(shots, String(m["title"]).to_upper(), func() -> void: _announce())


func _announce() -> void:
	if hud != null:
		hud.call("banner", "%s\nWave 1/%d" % [Loc.t(String(_m["title"])), (_m["waves"] as Array).size()], "mission_new")


func _spawn_wave(rise: bool) -> void:
	var at: Vector2 = _m["at"]
	var waves: Array = _m["waves"]
	var list: Array = waves[wave]
	var n := 0
	for grp in list:
		for k in int(grp[1]):
			var a := TAU * float(n) / 7.0 + float(wave) * 0.7
			var r := 6.0 + float(n % 3) * 2.5
			var p := Vector2(at.x + cos(a) * r, at.y + sin(a) * r)
			var mon := Monster.new()
			mon.player = player
			main.add_child(mon)
			mon.setup_monster(String(grp[0]), _ground(p), "%s_%s_%d_%d" % [running, String(grp[0]), wave, n])
			mon.global_position = _ground(p)
			if combat != null:
				mon._spawn_pickup = func(pp: Vector3, kk: String) -> void: combat.spawn_pickup(pp, kk)
			if Vector2(_m["goal"]) != Vector2.ZERO:
				mon.set_meta("goal", _ground(_m["goal"]))
			mon.died.connect(_on_kill)
			if rise:
				# out of the ground (or out of thin air for spirits)
				var m3 := mon.get_node("Model") as Node3D
				m3.position.y = -2.2
				m3.create_tween().tween_property(m3, "position:y", 0.0, 1.6 + 0.2 * float(n)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			alive.append(mon)
			n += 1
	if n > 0:
		Sfx.at("scream", _ground(at) + Vector3(0, 2, 0), -6.0, 0.6)
	LogCollector.event("monster mission %s wave %d spawned %d" % [running, wave + 1, n])
	story.changed.emit()                  # the tracker shows the new count


## A boss calls for help: one minion rises from the ground beside it and joins the current wave.
var _summons := 0


func summon(kind: String, at: Vector3) -> Monster:
	var mon := Monster.new()
	mon.player = player
	main.add_child(mon)
	_summons += 1
	var g := _ground(Vector2(at.x, at.z))
	mon.setup_monster(kind, g, "%s_summon_%d" % [running if running != "" else "wild", _summons])
	mon.global_position = g
	if combat != null:
		mon._spawn_pickup = func(pp: Vector3, kk: String) -> void: combat.spawn_pickup(pp, kk)
	mon.died.connect(_on_kill)
	var m3 := mon.get_node("Model") as Node3D
	if m3 != null:
		m3.position.y = -2.2
		m3.create_tween().tween_property(m3, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if running != "":
		alive.append(mon)
		story.changed.emit()
	HitFx.burst(main, g + Vector3(0, 0.3, 0), true, Color(0.5, 0.4, 0.35))
	return mon


func _on_kill(e: Enemy) -> void:
	alive.erase(e)
	_streak = _streak + 1 if _streak_t > 0.0 else 1
	_streak_t = 3.0
	if _streak >= 2 and hud != null:
		var bonus := mini(3 * _streak, 15)
		var coins: Object = main.get("coin_sys")
		if coins != null:
			coins.call("add", bonus, "streak")
		hud.call("banner", "x%d STREAK  +%d coins" % [_streak, bonus], "")
	story.add("monster_kills", 1)


func _run(delta: float) -> void:
	_streak_t -= delta
	if player.hp < _hp_last:
		_hp_lost += _hp_last - player.hp
	_hp_last = player.hp
	# the player fell: the mission resets and can be retried by coming back
	if player.dead:
		_abort(Loc.tf("You fell. Return to %s to try again.", [String(_m["place"])]))
		return
	# haunting: monsters near the village centre drain its heart
	var goal: Vector2 = _m["goal"]
	if goal != Vector2.ZERO:
		for mon in alive:
			if not is_instance_valid(mon):
				continue
			var g := (mon as Node3D).global_position
			if Vector2(g.x - goal.x, g.z - goal.y).length() < 6.0:
				village -= delta * 2.2
		if village <= 0.0:
			_abort(Loc.tf("%s has fallen to the dead. Return and try again.", [String(_m["place"])]).capitalize())
			return
	alive = alive.filter(func(x: Variant) -> bool: return is_instance_valid(x) and not (x as Enemy).dead)
	if not alive.is_empty():
		return
	if _wave_wait < 0.0:
		_wave_wait = 2.5
		var waves: Array = _m["waves"]
		if wave + 1 < waves.size() and hud != null:
			hud.call("banner", "Wave %d/%d" % [wave + 2, waves.size()], "")
	_wave_wait -= delta
	if _wave_wait > 0.0:
		return
	_wave_wait = -1.0
	wave += 1
	if wave >= (_m["waves"] as Array).size():
		_complete()
	else:
		_spawn_wave(true)


func _complete() -> void:
	var id := running
	running = ""
	if bool(_m.get("repeat", false)):
		story.add("raids_won", 1)
	else:
		story.set_flag(id + "_done", true)
	story.add("monster_missions_done", 1)
	var secs := Time.get_ticks_msec() / 1000.0 - _t0
	var stars := 1
	if _hp_lost < player.max_hp * 0.6:
		stars += 1
	if _hp_lost < player.max_hp * 0.25 and secs < 150.0:
		stars += 1
	if Vector2(_m["goal"]) != Vector2.ZERO and village < 50.0:
		stars = mini(stars, 2)
	story.set_flag(id + "_stars", maxi(stars, int(story.get_flag(id + "_stars", 0))))
	var coins := int(_m["coins"]) + 20 * (stars - 1)
	var cs: Object = main.get("coin_sys")
	if cs != null:
		cs.call("add", coins, id)
	var gift: String = _m["gift"]
	var it := get_tree().get_first_node_in_group("items")
	if it != null and gift != "" and gift != "bow":
		it.call("give", gift, 3 if gift == "potion" else 1)
	if hud != null:
		hud.call("banner", "%s  %s\n+%d %s" % [Loc.t("MISSION COMPLETE"), "★".repeat(stars) + "☆".repeat(3 - stars), coins, Loc.t("coins")], "seal_found")
		if String(_m["line"]) != "" and gift != "bow":
			hud.call("banner", String(_m["line"]), "")
		var nx := available()
		if not nx.is_empty():
			hud.call("banner", Loc.tf("NEXT: %s", [String(nx["title"])]), "mission_new")
	var ach := get_tree().get_first_node_in_group("achievements")
	if ach != null and id == "m_ghost1":
		ach.call("unlock", "ghostbuster")
	_restore_time()
	LogCollector.event("monster mission done %s stars=%d time=%ds" % [id, stars, int(secs)])
	story.refresh()


func _abort(msg: String) -> void:
	for mon in alive:
		if is_instance_valid(mon):
			(mon as Node).queue_free()
	alive.clear()
	story.set_flag(running + "_started", false)
	LogCollector.event("monster mission failed %s wave=%d" % [running, wave])
	running = ""
	_wave_wait = -1.0
	_restore_time()
	if hud != null:
		hud.call("banner", msg, "")


func _restore_time() -> void:
	var atmo: Object = main.get("atmosphere")
	if _saved_tod >= 0.0 and atmo != null:
		atmo.set("time_of_day", 0.25)        # the night ends: dawn after the fight
		atmo.call("apply_time")
	_saved_tod = -1.0
