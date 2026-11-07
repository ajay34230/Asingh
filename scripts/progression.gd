class_name Progression
extends Node
## Long-term goals that make every fight, harvest and ride count:
## - XP and levels: XP from coins earned, kills, missions, harvests, climbs; each level gives a skill point,
##   heals you fully and is celebrated.
## - Skill tree: three branches (Fighter, Hunter, Survivor), three skills each, up to 3 ranks.
## - Weapon upgrades at the blacksmith: +1..+3, paid with iron and monster essence.
## - Daily challenges: three small goals picked from today's date (same for the whole day), coins and XP for
##   each, a bonus chest for all three.
## - Login streak: one reward per calendar day you play, growing over 7 days; missing a day starts over.
## Everything is stored in story flags, so it saves with the game.

signal changed

const SKILLS := {
	"heavy_hands": {"branch": "Fighter", "name": "Heavy Hands", "desc": "+12% punch and kick damage per rank"},
	"combo_flow": {"branch": "Fighter", "name": "Combo Flow", "desc": "Strikes come 7% faster per rank"},
	"crusher": {"branch": "Fighter", "name": "Crusher", "desc": "+15% weapon swing damage per rank"},
	"quick_draw": {"branch": "Hunter", "name": "Quick Draw", "desc": "Draw the bow 12% faster per rank"},
	"piercing": {"branch": "Hunter", "name": "Piercing Shot", "desc": "+15% arrow damage per rank"},
	"spirit_bane": {"branch": "Hunter", "name": "Spirit Bane", "desc": "+20% damage to ghosts per rank"},
	"vitality": {"branch": "Survivor", "name": "Vitality", "desc": "+15 max health per rank"},
	"nimble": {"branch": "Survivor", "name": "Nimble", "desc": "Rolls cost 20% less, run 4% faster per rank"},
	"second_wind": {"branch": "Survivor", "name": "Second Wind", "desc": "Stamina refills 25% faster per rank"},
}
const MAX_RANK := 3
const UPGRADE_MAX := 3
const UPGRADABLE := ["fists", "hammer", "bow", "sword", "dagger", "spear", "axe"]

## Daily challenge templates: [id, text, counter, min, max, reward coins]
const DAILY := [
	["kill", "Defeat %d enemies or monsters", "kill", 8, 15, 50],
	["ghost", "Banish %d ghosts", "ghost", 5, 10, 60],
	["arrow", "Fire %d arrows", "arrow", 15, 30, 40],
	["kick", "Land %d kicks", "kick", 10, 20, 40],
	["coins", "Earn %d coins", "coins", 100, 250, 50],
	["ride", "Ride %d m on an animal", "ride", 400, 900, 45],
	["climb", "Climb or vault %d times", "climb", 4, 8, 40],
	["harvest", "Harvest %d crops", "harvest", 3, 6, 45],
	["race", "Win %d cart race", "race", 1, 1, 70],
]
## Login streak rewards for day 1..7: [coins, item, count, skill points]
const STREAK := [
	[20, "", 0, 0], [40, "herb", 2, 0], [50, "potion", 1, 0], [70, "iron", 3, 0],
	[80, "essence", 2, 0], [100, "potion", 2, 0], [150, "essence", 3, 1],
]

var story: Story
var player: Player
var hud: Node
var _last := {}
var _poll := 0.0
var _ride_acc := 0.0
var _prev_pos := Vector3.ZERO
var _today := ""


func setup(s: Story, p: Player, h: Node) -> void:
	story = s
	player = p
	hud = h
	add_to_group("progression")
	_today = today()
	apply()


static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


static func _day_number(date: String) -> int:
	var parts := date.split("-")
	if parts.size() != 3:
		return 0
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12, "minute": 0, "second": 0})
	return int(unix / 86400)


# --- XP and levels --------------------------------------------------------------------------------------

func level() -> int:
	return maxi(1, int(story.get_flag("level", 1)))


func xp() -> int:
	return int(story.get_flag("xp", 0))


static func xp_needed(lv: int) -> int:
	return 80 + 45 * (lv - 1)


func points() -> int:
	return int(story.get_flag("skill_pts", 0))


func gain(amount: int, why: String = "") -> void:
	if amount <= 0 or story == null:
		return
	var x := xp() + amount
	var lv := level()
	var ups := 0
	while x >= xp_needed(lv):
		x -= xp_needed(lv)
		lv += 1
		ups += 1
	story.flags["xp"] = x
	if ups > 0:
		story.flags["level"] = lv
		story.flags["xp"] = x
		story.flags["skill_pts"] = points() + ups
		apply()
		player.hp = player.max_hp
		player.hp_changed.emit(player.hp, player.max_hp)
		Sfx.ui("seal_found", -2.0)
		if hud != null:
			hud.call("banner", "LEVEL %d!\n+%d skill point%s. Open II > Hero" % [lv, ups, "" if ups == 1 else "s"], "seal_found")
		HitFx.burst(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), true, Color(1.0, 0.85, 0.3))
		LogCollector.event("level up %d (%s)" % [lv, why])
	story.changed.emit()
	changed.emit()


# --- skills -----------------------------------------------------------------------------------------------

func rank(id: String) -> int:
	return int(story.get_flag("sk_" + id, 0))


func can_learn(id: String) -> bool:
	return SKILLS.has(id) and points() > 0 and rank(id) < MAX_RANK


func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	story.flags["sk_" + id] = rank(id) + 1
	story.flags["skill_pts"] = points() - 1
	apply()
	Sfx.ui("ui_blip", -4.0)
	story.changed.emit()
	changed.emit()
	return true


## Push skill effects onto the player.
func apply() -> void:
	if player == null or story == null:
		return
	player.melee_mult = 1.0 + 0.12 * rank("heavy_hands")
	player.cd_mult = 1.0 - 0.07 * rank("combo_flow")
	player.heavy_mult = 1.0 + 0.15 * rank("crusher")
	player.bow_cd_mult = 1.0 - 0.12 * rank("quick_draw")
	player.arrow_mult = 1.0 + 0.15 * rank("piercing")
	player.ghost_mult = 1.0 + 0.2 * rank("spirit_bane")
	player.roll_cost_mult = 1.0 - 0.2 * rank("nimble")
	player.run_mult = 1.0 + 0.04 * rank("nimble")
	player.regen_mult = 1.0 + 0.25 * rank("second_wind")
	var mx := 100.0 + 15.0 * rank("vitality")
	if absf(player.max_hp - mx) > 0.1:
		var frac := player.hp / maxf(player.max_hp, 1.0)
		player.max_hp = mx
		player.hp = clampf(frac * mx, 1.0, mx)
		player.hp_changed.emit(player.hp, player.max_hp)


# --- weapon upgrades ----------------------------------------------------------------------------------

func up_level(w: String) -> int:
	return int(story.get_flag("up_" + w, 0))


static func upgrade_cost(next_level: int) -> Dictionary:
	return {"iron": 2 + 2 * next_level, "essence": next_level * 2 - 1, "coins": 40 * next_level}


func near_blacksmith() -> bool:
	for n in get_tree().get_nodes_in_group("npcs"):
		if String((n as Node).name) == "Blacksmith" and (n as Node3D).global_position.distance_to(player.global_position) < 8.0:
			return true
	return false


func can_upgrade(w: String) -> String:
	var lv := up_level(w) + 1
	if lv > UPGRADE_MAX:
		return "Fully upgraded"
	if not near_blacksmith():
		return "Visit Dhruv the blacksmith"
	var it := get_tree().get_first_node_in_group("items")
	var c := upgrade_cost(lv)
	if it == null or int(it.call("count", "iron")) < int(c["iron"]) or int(it.call("count", "essence")) < int(c["essence"]):
		return "Need %d iron, %d essence" % [int(c["iron"]), int(c["essence"])]
	if int(story.get_flag("coins", 0)) < int(c["coins"]):
		return "Need %d coins" % int(c["coins"])
	return ""


func upgrade(w: String) -> bool:
	if can_upgrade(w) != "":
		return false
	var lv := up_level(w) + 1
	var c := upgrade_cost(lv)
	var it := get_tree().get_first_node_in_group("items")
	it.call("take", "iron", int(c["iron"]))
	it.call("take", "essence", int(c["essence"]))
	story.add("coins", -int(c["coins"]))
	story.flags["up_" + w] = lv
	Sfx.ui("anvil", -2.0)
	if hud != null:
		hud.call("banner", "%s upgraded to +%d" % [w.capitalize(), lv], "seal_found")
	gain(30, "upgrade")
	story.changed.emit()
	changed.emit()
	return true


# --- daily challenges and login streak -------------------------------------------------------------------

## Today's three challenges: [[id, text, counter, target, coins], ...] (deterministic for the date).
func dailies() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_today + "lostkingdom")
	var pool := DAILY.duplicate()
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var i := rng.randi() % pool.size()
		var d: Array = pool[i]
		pool.remove_at(i)
		var target := rng.randi_range(int(d[3]), int(d[4]))
		if String(d[2]) in ["coins", "ride"]:
			target = int(round(target / 10.0)) * 10
		out.append([d[0], String(d[1]) % target, d[2], target, d[5]])
	return out


func _roll_day() -> void:
	if String(story.get_flag("dc_date", "")) != _today:
		story.flags["dc_date"] = _today
		for k in ["kill", "ghost", "arrow", "kick", "coins", "ride", "climb", "harvest", "race"]:
			story.flags["dc_" + k] = 0
		for i in 3:
			story.flags["dc_done%d" % i] = false
		story.flags["dc_chest"] = false


func daily_progress(i: int) -> int:
	var d: Array = dailies()[i]
	return mini(int(story.get_flag("dc_" + String(d[2]), 0)), int(d[3]))


## Count toward today's challenges. counter: kill, ghost, arrow, kick, coins, ride, climb, harvest, race.
func note(counter: String, n: int = 1) -> void:
	if story == null or n <= 0:
		return
	_roll_day()
	story.flags["dc_" + counter] = int(story.get_flag("dc_" + counter, 0)) + n
	var ds := dailies()
	var all := true
	for i in ds.size():
		var d: Array = ds[i]
		var done := bool(story.get_flag("dc_done%d" % i, false))
		if not done and int(story.get_flag("dc_" + String(d[2]), 0)) >= int(d[3]):
			story.flags["dc_done%d" % i] = true
			done = true
			story.add("coins", int(d[4]))
			gain(40, "daily")
			if hud != null:
				hud.call("banner", "DAILY CHALLENGE DONE\n%s  +%d coins" % [String(d[1]), int(d[4])], "seal_found")
		all = all and done
	if all and not bool(story.get_flag("dc_chest", false)):
		story.flags["dc_chest"] = true
		_open_chest()
	changed.emit()


func _open_chest() -> void:
	var it := get_tree().get_first_node_in_group("items")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_today + "chest")
	var coins := 80 + rng.randi_range(0, 4) * 10
	story.add("coins", coins)
	var extra: String = ["potion", "essence", "iron"][rng.randi() % 3]
	var n := 2 if extra != "iron" else 4
	if it != null:
		it.call("give", extra, n)
	gain(60, "chest")
	Sfx.ui("seal_found", 0.0)
	if hud != null:
		hud.call("banner", "BONUS CHEST!\n+%d coins, %d x %s" % [coins, n, String(Items.DEFS[extra]["name"])], "seal_found")
	LogCollector.event("daily chest opened")


## Once per calendar day: advance (or reset) the streak and hand out that day's reward.
func check_login() -> void:
	if story == null:
		return
	_today = today()
	_roll_day()
	var last := String(story.get_flag("ls_last", ""))
	if last == _today:
		return
	var streak := int(story.get_flag("ls_count", 0))
	if last != "" and _day_number(_today) - _day_number(last) == 1:
		streak += 1
	else:
		streak = 1
	story.flags["ls_last"] = _today
	story.flags["ls_count"] = streak
	var r: Array = STREAK[(streak - 1) % STREAK.size()]
	story.add("coins", int(r[0]))
	var it := get_tree().get_first_node_in_group("items")
	if String(r[1]) != "" and it != null:
		it.call("give", String(r[1]), int(r[2]))
	if int(r[3]) > 0:
		story.flags["skill_pts"] = points() + int(r[3])
	var what := "+%d coins" % int(r[0])
	if String(r[1]) != "":
		what += ", %d x %s" % [int(r[2]), String(Items.DEFS[String(r[1])]["name"])]
	if int(r[3]) > 0:
		what += ", +1 skill point"
	if hud != null:
		hud.call("banner", "DAY %d STREAK!\n%s" % [streak, what], "seal_found")
	LogCollector.event("login streak %d" % streak)
	story.changed.emit()
	changed.emit()


func streak() -> int:
	return int(story.get_flag("ls_count", 0))


# --- watching the world ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if story == null or player == null:
		return
	if player.mounted:
		var p := player.global_position
		if _prev_pos != Vector3.ZERO:
			var step := Vector2(p.x - _prev_pos.x, p.z - _prev_pos.z).length()
			if step < 20.0:
				_ride_acc += step
		_prev_pos = p
		if _ride_acc >= 10.0:
			note("ride", int(_ride_acc))
			_ride_acc = fmod(_ride_acc, 1.0)
	else:
		_prev_pos = Vector3.ZERO
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	if today() != _today:
		check_login()             # played past midnight
	var now := {
		"coins": int(story.get_flag("coins", 0)), "harvest": int(story.get_flag("harvests", 0)),
		"race": int(story.get_flag("races_won", 0)), "climb": player.climbs, "arrow": player.arrows_fired,
		"kick": player.kicks_landed, "mission": int(story.get_flag("monster_missions_done", 0)),
	}
	if _last.is_empty():
		_last = now
		return
	for k in now:
		var dv: int = int(now[k]) - int(_last.get(k, 0))
		if dv <= 0:
			continue
		match k:
			"coins":
				note("coins", dv)
				gain(int(ceil(dv * 0.5)), "coins")
			"harvest":
				note("harvest", dv)
				gain(8 * dv, "harvest")
			"race":
				note("race", dv)
			"climb":
				note("climb", dv)
				gain(2 * dv, "climb")
			"arrow":
				note("arrow", dv)
			"kick":
				note("kick", dv)
			"mission":
				gain(120 * dv, "monster mission")
	_last = now


## Called by Achievements.note_kill for every defeated enemy or monster.
func on_kill(role: String) -> void:
	note("kill")
	if role == "ghost" or role == "ghost_skull":
		note("ghost")
	var boss := role in Monster.KINDS and bool(Monster.KINDS[role].get("boss", false))
	gain(60 if boss else (12 if role in Monster.KINDS else 15), "kill " + role)
