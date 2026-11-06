## Board themes: colours for the lacquer, gold, tiles, wings and table, plus the lighting.
## The rules and layout never change between themes.
class_name BoardThemes
extends RefCounted

const ORDER := ["royal", "jaipur", "mysore", "kerala", "diwali"]

const THEMES := {
	"royal": {
		"name": "Royal Red", "blurb": "Crimson lacquer and gold",
		"ivory": Color("#fbf6ec"), "lacquer": Color("#5c0d17"), "gold": Color("#e2b04f"),
		"wing_base": Color("#3a0710"), "wing_ink": Color("#80551f"), "table": Color.WHITE,
		"sky_top": Color("#3d2b52"), "sky_horizon": Color("#ffd9a0"),
		"ground_horizon": Color("#c2874a"), "ground_bottom": Color("#2a140a"),
		"sun": Color("#ffe9c4"), "sun_energy": 1.5, "ambient": 0.55,
		"fill": Color("#c9d6ff"), "fill_energy": 0.35, "night": false,
	},
	"jaipur": {
		"name": "Jaipur Pink", "blurb": "The Pink City's sandstone palaces",
		"ivory": Color("#fff3ee"), "lacquer": Color("#b0475f"), "gold": Color("#eab07a"),
		"wing_base": Color("#a8445f"), "wing_ink": Color("#f0c2a2"), "table": Color("#ffd0c8"),
		"sky_top": Color("#5a3a6a"), "sky_horizon": Color("#ffc6b0"),
		"ground_horizon": Color("#e09a8a"), "ground_bottom": Color("#40201c"),
		"sun": Color("#ffe2d0"), "sun_energy": 1.45, "ambient": 0.6,
		"fill": Color("#d8c8ff"), "fill_energy": 0.35, "night": false,
	},
	"mysore": {
		"name": "Mysore Gold", "blurb": "Royal purple and the palace's gold",
		"ivory": Color("#fff8e6"), "lacquer": Color("#3c1452"), "gold": Color("#f2c04a"),
		"wing_base": Color("#2a0f3a"), "wing_ink": Color("#c99a36"), "table": Color("#d8c0ff"),
		"sky_top": Color("#2a1c4a"), "sky_horizon": Color("#ffe0a0"),
		"ground_horizon": Color("#b08a4a"), "ground_bottom": Color("#1a0c20"),
		"sun": Color("#fff0c8"), "sun_energy": 1.55, "ambient": 0.55,
		"fill": Color("#c0b8ff"), "fill_energy": 0.4, "night": false,
	},
	"kerala": {
		"name": "Kerala Green", "blurb": "Teak, palms and backwater green",
		"ivory": Color("#fbf8ee"), "lacquer": Color("#5a3418"), "gold": Color("#d9aa52"),
		"wing_base": Color("#0f3a28"), "wing_ink": Color("#b8953f"), "table": Color("#c8ffd8"),
		"sky_top": Color("#2c4a5a"), "sky_horizon": Color("#e8f2c8"),
		"ground_horizon": Color("#7aa070"), "ground_bottom": Color("#10201a"),
		"sun": Color("#fff6dc"), "sun_energy": 1.5, "ambient": 0.6,
		"fill": Color("#c8f0ff"), "fill_energy": 0.4, "night": false,
	},
	"diwali": {
		"name": "Diwali Night", "blurb": "A night of lamps and fireworks",
		"ivory": Color("#f6efe2"), "lacquer": Color("#2a0a3a"), "gold": Color("#f0b84a"),
		"wing_base": Color("#140826"), "wing_ink": Color("#a8782a"), "table": Color("#9a8aff"),
		"sky_top": Color("#05030f"), "sky_horizon": Color("#3a1a40"),
		"ground_horizon": Color("#2a1020"), "ground_bottom": Color("#05030a"),
		"sun": Color("#9fb4ff"), "sun_energy": 0.45, "ambient": 0.32,
		"fill": Color("#ffb060"), "fill_energy": 0.55, "night": true,
	},
}


static func current_id() -> String:
	var id: String = GameSettings.load_value("game", "theme", "royal")
	return id if THEMES.has(id) else "royal"


static func current() -> Dictionary:
	return THEMES[current_id()]


static func set_current(id: String) -> void:
	if THEMES.has(id):
		GameSettings.save_value("game", "theme", id)
