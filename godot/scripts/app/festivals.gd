## Festival events (by calendar date) and weekly challenges.
## A festival doubles coins from games and adds its own decoration to the palace.
## Weekly challenges: three per week, picked from a pool by week number, each paying
## coins once completed.
class_name Festivals
extends RefCounted

## id -> [name, greeting, [start month, start day], [end month, end day]]
## Dates are fixed approximations; lunar festivals move a little each year.
const FESTIVALS := {
	"pongal": ["Sankranti", "Happy Sankranti! Kites fly over the palace", [1, 10], [1, 20]],
	"holi": ["Holi", "Happy Holi! Colours fill the palace", [3, 1], [3, 20]],
	"independence": ["Independence Day", "Jai Hind! Tricolour celebrations", [8, 10], [8, 20]],
	"diwali": ["Diwali", "Shubh Deepavali! The palace glows with lamps", [10, 15], [11, 15]],
	"christmas": ["Christmas", "Merry Christmas! Snow falls on the palace", [12, 20], [12, 31]],
}

static var override := ""   ## tests and screenshots: force a festival


static func current() -> String:
	if override != "":
		return override
	var d := Time.get_date_dict_from_system()
	var today := int(d["month"]) * 100 + int(d["day"])
	for id in FESTIVALS:
		var f: Array = FESTIVALS[id]
		var a: int = f[2][0] * 100 + f[2][1]
		var b: int = f[3][0] * 100 + f[3][1]
		if today >= a and today <= b:
			return id
	return ""


static func coin_multiplier() -> int:
	return 2 if current() != "" else 1


# --- weekly challenges ---------------------------------------------------------------

## id -> [description, target, stat key in the game tally, reward]
const CHALLENGES := {
	"cap5": ["Capture 5 tokens", 5, "captures", 150],
	"win2": ["Win 2 games", 2, "wins", 150],
	"six8": ["Roll 8 sixes", 8, "sixes", 120],
	"home10": ["Bring 10 tokens home", 10, "home", 150],
	"play5": ["Play 5 games", 5, "games", 100],
	"win_hard": ["Win a game on Hard or Expert", 1, "hard_wins", 200],
	"team1": ["Win a Team battle", 1, "team_wins", 200],
	"flawless1": ["Win without losing a token", 1, "flawless", 250],
}


static func week() -> int:
	return int(Time.get_unix_time_from_system() / (86400.0 * 7.0))


static func this_week() -> Array:
	var ids := CHALLENGES.keys()
	var w := week()
	var picks: Array = []
	var i := w * 3
	while picks.size() < 3:
		var id: String = ids[posmod(i * 5 + w, ids.size())]
		if not picks.has(id):
			picks.append(id)
		i += 1
	return picks


## Progress dictionary for this week (stat -> count), reset every week.
static func week_progress() -> Dictionary:
	var stored: Variant = GameSettings.load_value("progress", "week", {})
	if stored is Dictionary and int((stored as Dictionary).get("week", -1)) == week():
		return stored
	return {"week": week(), "done": []}


## Adds a finished game's numbers; returns the challenges completed by it.
static func record(game: Dictionary) -> Array:
	var p := week_progress()
	var add := {
		"captures": int(game.get("captures", 0)), "sixes": int(game.get("sixes", 0)),
		"home": int(game.get("home", 0)), "games": 1, "wins": 1 if game.get("won", false) else 0,
		"hard_wins": 1 if game.get("won", false) and int(game.get("difficulty", 0)) >= 2 else 0,
		"team_wins": 1 if game.get("won", false) and game.get("team", false) else 0,
		"flawless": 1 if game.get("won", false) and int(game.get("lost", 0)) == 0 else 0,
	}
	for k in add:
		p[k] = int(p.get(k, 0)) + add[k]
	var completed: Array = []
	var done: Array = p.get("done", [])
	for id in this_week():
		var c: Array = CHALLENGES[id]
		if not done.has(id) and int(p.get(c[2], 0)) >= int(c[1]):
			done.append(id)
			completed.append(id)
			Progress.add_coins(int(c[3]))
	p["done"] = done
	GameSettings.save_value("progress", "week", p)
	return completed
