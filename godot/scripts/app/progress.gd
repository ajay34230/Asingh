## Offline progression, saved in user://settings.cfg under "progress":
## coins, lifetime stats, a 7-day daily reward, achievements with coin rewards, and a
## shop of themes, dice skins and token skins.
class_name Progress
extends RefCounted

const DAILY := [50, 75, 100, 125, 150, 200, 300]

## id -> [title, description, reward]
const ACHIEVEMENTS := {
	"first_win": ["First Crown", "Win a game", 100],
	"first_capture": ["First Blood", "Capture an opponent's token", 50],
	"triple_capture": ["Warlord", "Capture 3 tokens in one game", 150],
	"flawless": ["Untouchable", "Win without losing a single token", 250],
	"sixes_3": ["Lucky Hand", "Roll three sixes in one game", 75],
	"home_10": ["Homecoming", "Bring 10 tokens home in total", 100],
	"captures_25": ["Conqueror", "Capture 25 tokens in total", 200],
	"wins_10": ["Maharaja", "Win 10 games", 300],
	"streak_3": ["Unstoppable", "Win 3 games in a row", 200],
	"expert_win": ["Grandmaster", "Beat the Expert AI", 400],
	"all_themes": ["Collector", "Own every board theme", 300],
	"daily_7": ["Devotee", "Claim the daily reward 7 days in a row", 250],
}

## id -> [kind, display name, price]
const SHOP := {
	"theme_royal": ["theme", "Royal Red board", 0],
	"theme_jaipur": ["theme", "Jaipur Pink board", 300],
	"theme_mysore": ["theme", "Mysore Gold board", 500],
	"theme_kerala": ["theme", "Kerala Green board", 500],
	"theme_diwali": ["theme", "Diwali Night board", 1000],
	"dice_ivory": ["dice", "Ivory dice", 0],
	"dice_jade": ["dice", "Jade dice", 250],
	"dice_ebony": ["dice", "Ebony dice", 400],
	"dice_lapis": ["dice", "Lapis dice", 600],
	"tokens_classic": ["tokens", "Classic tokens", 0],
	"tokens_gold": ["tokens", "Gilded tokens", 500],
	"tokens_silver": ["tokens", "Silver tokens", 400],
	"tokens_crystal": ["tokens", "Crystal tokens", 800],
	"victory_fireworks": ["victory", "Fireworks victory", 0],
	"victory_goldrain": ["victory", "Gold rain victory", 400],
	"victory_lotus": ["victory", "Lotus bloom victory", 500],
	"trail_none": ["trail", "No dice trail", 0],
	"trail_gold": ["trail", "Golden dice trail", 300],
	"trail_petals": ["trail", "Rose petal dice trail", 350],
	"trail_stars": ["trail", "Starlight dice trail", 450],
}


static func _load(key: String, fallback: Variant) -> Variant:
	return GameSettings.load_value("progress", key, fallback)


static func _store(key: String, value: Variant) -> void:
	GameSettings.save_value("progress", key, value)


# --- coins ------------------------------------------------------------------------

static func coins() -> int:
	return GameSettings.get_coins()


static func add_coins(n: int) -> int:
	return GameSettings.add_coins(n)


# --- stats ------------------------------------------------------------------------

static func stats() -> Dictionary:
	var s: Variant = _load("stats", {})
	var out := {"games": 0, "wins": 0, "captures": 0, "lost": 0, "home": 0, "sixes": 0, "streak": 0, "best_streak": 0}
	if s is Dictionary:
		for k in out:
			out[k] = int((s as Dictionary).get(k, 0))
	return out


## Records a finished game for the human player and returns achievements unlocked.
## `game` holds: won, place, captures, lost, home, sixes, difficulty, humans.
static func record_game(game: Dictionary) -> Array:
	var s := stats()
	s["games"] += 1
	s["captures"] += int(game["captures"])
	s["lost"] += int(game["lost"])
	s["home"] += int(game["home"])
	s["sixes"] += int(game["sixes"])
	if game["won"]:
		s["wins"] += 1
		s["streak"] += 1
		s["best_streak"] = maxi(s["best_streak"], s["streak"])
	else:
		s["streak"] = 0
	_store("stats", s)
	var unlocked: Array = []
	var check := func(id: String, cond: bool) -> void:
		if cond and unlock(id):
			unlocked.append(id)
	check.call("first_win", game["won"])
	check.call("first_capture", int(game["captures"]) > 0)
	check.call("triple_capture", int(game["captures"]) >= 3)
	check.call("flawless", game["won"] and int(game["lost"]) == 0)
	check.call("sixes_3", int(game["sixes"]) >= 3)
	check.call("home_10", s["home"] >= 10)
	check.call("captures_25", s["captures"] >= 25)
	check.call("wins_10", s["wins"] >= 10)
	check.call("streak_3", s["streak"] >= 3)
	check.call("expert_win", game["won"] and int(game["difficulty"]) >= 3)
	return unlocked


# --- achievements -----------------------------------------------------------------

static func unlocked() -> Array:
	var a: Variant = _load("achievements", [])
	return a if a is Array else []


## Unlocks an achievement once and pays its reward. Returns true if newly unlocked.
static func unlock(id: String) -> bool:
	var list := unlocked()
	if list.has(id) or not ACHIEVEMENTS.has(id):
		return false
	list.append(id)
	_store("achievements", list)
	add_coins(int(ACHIEVEMENTS[id][2]))
	return true


# --- daily reward -----------------------------------------------------------------

static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


## [can_claim, day_index 0..6, amount]
static func daily_status() -> Array:
	var last := int(_load("daily_last", -1))
	var streak := int(_load("daily_streak", 0))
	var today := _today()
	if last == today:
		return [false, (streak - 1) % 7, DAILY[(streak - 1) % 7]]
	var next := streak if last == today - 1 else 0
	return [true, next % 7, DAILY[next % 7]]


static func claim_daily() -> int:
	var st := daily_status()
	if not st[0]:
		return 0
	var last := int(_load("daily_last", -1))
	var streak := int(_load("daily_streak", 0))
	streak = streak + 1 if last == _today() - 1 else 1
	_store("daily_streak", streak)
	_store("daily_last", _today())
	add_coins(int(st[2]))
	if streak >= 7:
		unlock("daily_7")
	return int(st[2])


# --- shop ---------------------------------------------------------------------------

static func owned() -> Array:
	var o: Variant = _load("owned", [])
	var list: Array = o if o is Array else []
	for id in SHOP:
		if int(SHOP[id][2]) == 0 and not list.has(id):
			list.append(id)
	return list


static func owns(id: String) -> bool:
	return owned().has(id)


## Buys an item if affordable. Returns "ok", "owned" or "coins".
static func buy(id: String) -> String:
	if owns(id):
		return "owned"
	var price := int(SHOP[id][2])
	if coins() < price:
		return "coins"
	GameSettings.save_value("progress", "coins", coins() - price)
	var list := owned()
	list.append(id)
	_store("owned", list)
	var all_themes := true
	for k in SHOP:
		if SHOP[k][0] == "theme" and not list.has(k):
			all_themes = false
	if all_themes:
		unlock("all_themes")
	return "ok"


static func equipped(kind: String) -> String:
	var default := {"dice": "dice_ivory", "tokens": "tokens_classic", "victory": "victory_fireworks", "trail": "trail_none"}
	return String(_load("equip_" + kind, default.get(kind, "")))


static func equip(id: String) -> void:
	if owns(id):
		_store("equip_" + String(SHOP[id][0]), id)


# --- profile: name, XP, level, title -------------------------------------------------

const FRAMES := [[1, "Bronze", Color("#cd7f45")], [5, "Silver", Color("#d8dde6")], [10, "Gold", Color("#ffd24a")], [20, "Royal", Color("#ff5ab0")]]


static func player_name() -> String:
	return String(_load("name", "Player"))


static func set_player_name(n: String) -> void:
	n = n.strip_edges().substr(0, 16)
	_store("name", n if n != "" else "Player")


static func xp() -> int:
	return int(_load("xp", 0))


## Level from total XP: each level needs 120 more XP than the last (120, 240, 360, ...).
static func level_for(total: int) -> int:
	var lvl := 1
	var need := 120
	var left := total
	while left >= need:
		left -= need
		lvl += 1
		need += 120
	return lvl


## [xp into this level, xp needed for the next]
static func level_progress() -> Array:
	var left := xp()
	var need := 120
	while left >= need:
		left -= need
		need += 120
	return [left, need]


static func level() -> int:
	return level_for(xp())


static func frame() -> Array:
	var f: Array = FRAMES[0]
	for row in FRAMES:
		if level() >= int(row[0]):
			f = row
	return f


## XP for a finished game; returns [gained, levels_gained, coins_from_levels].
static func add_game_xp(game: Dictionary) -> Array:
	var gained := 50 + (100 if game.get("won", false) else 0) + 10 * int(game.get("captures", 0)) + 15 * int(game.get("home", 0))
	var before := level()
	_store("xp", xp() + gained)
	var after := level()
	var coins := 0
	for l in range(before + 1, after + 1):
		coins += 100 * l
	if coins > 0:
		add_coins(coins)
	return [gained, after - before, coins]


## Titles come from unlocked achievements.
static func title() -> String:
	var t := String(_load("title", ""))
	return t if unlocked().has(t) else ""


static func set_title(id: String) -> void:
	if id == "" or unlocked().has(id):
		_store("title", id)
