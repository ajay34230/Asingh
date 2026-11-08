## The Royal Journey: five palaces, each with its ruler, board, rule twist and reward.
## Beat a chapter to unlock the next. Progress is the number of chapters completed.
class_name Campaign
extends RefCounted

const CHAPTERS := [
	{"id": "jaipur", "palace": "Hawa Mahal, Jaipur", "theme": "jaipur", "ruler": "yellow",
		"intro": "Rani Padmini guards the Pink City. She plays carefully: strike when she leaves a safe square.",
		"twist": "Classic rules, one on one",
		"colors": ["blue", "yellow"], "difficulty": 1, "rules": {}, "reward": 200, "unlock": "theme_jaipur"},
	{"id": "mysore", "palace": "Amba Vilas, Mysore", "theme": "mysore", "ruler": "green",
		"intro": "Raja Vikram loves a brawl. In his palace the gates are always open.",
		"twist": "Open gates: any roll brings a token out",
		"colors": ["blue", "yellow", "green"], "difficulty": 1, "rules": {"six_to_start": false}, "reward": 300, "unlock": "theme_mysore"},
	{"id": "kerala", "palace": "Padmanabhapuram, Kerala", "theme": "kerala", "ruler": "red",
		"intro": "The backwater lords fight as a team. Raja Vikram joins your side.",
		"twist": "Team battle: you and Raja Vikram against two rivals",
		"colors": ["blue", "yellow", "green", "red"], "difficulty": 2, "rules": {"teams": true}, "reward": 400, "unlock": "theme_kerala"},
	{"id": "delhi", "palace": "Red Fort, Delhi", "theme": "royal", "ruler": "red",
		"intro": "Maharaja Surya races like the wind. The first to bring a token home wins.",
		"twist": "Race: the game ends at the first player home",
		"colors": ["blue", "yellow", "green", "red"], "difficulty": 2, "rules": {"quick_end": true}, "reward": 500, "unlock": "dice_lapis"},
	{"id": "diwali", "palace": "The Palace of Lamps", "theme": "diwali", "ruler": "yellow",
		"intro": "On Diwali night all four rulers meet. Only a true maharaja wins.",
		"twist": "Finale: every rival plays at Expert level",
		"colors": ["blue", "yellow", "green", "red"], "difficulty": 3, "rules": {}, "reward": 1000, "unlock": "theme_diwali"},
]


static func completed() -> int:
	return int(GameSettings.load_value("progress", "campaign", 0))


static func unlocked(index: int) -> bool:
	return index <= completed()


## Called when a chapter game ends. Returns the reward text lines.
static func finish(index: int, won: bool) -> Array:
	if not won:
		return []
	var ch: Dictionary = CHAPTERS[index]
	var lines: Array = []
	if index >= completed():
		GameSettings.save_value("progress", "campaign", index + 1)
		Progress.add_coins(int(ch["reward"]))
		lines.append("campaign:%d" % index)
		var item: String = ch["unlock"]
		if not Progress.owns(item):
			var list := Progress.owned()
			list.append(item)
			GameSettings.save_value("progress", "owned", list)
	return lines


## Game config for the main scene's start function.
static func config(index: int) -> Dictionary:
	var ch: Dictionary = CHAPTERS[index]
	var rules := GameSettings.get_rules()
	for k in ch["rules"]:
		rules[k] = ch["rules"][k]
	if not ch["rules"].has("teams"):
		rules["teams"] = false
	if not ch["rules"].has("quick_end"):
		rules["quick_end"] = false
	return {"mode": "campaign", "players": ch["colors"].size(), "colors": ch["colors"], "difficulty": ch["difficulty"],
		"rules": rules, "chapter": index}
