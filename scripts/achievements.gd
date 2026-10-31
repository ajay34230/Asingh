class_name Achievements
extends Node
## X24: milestones tracked from story flags and play state. Saved to user://achievements.json,
## shown as a banner when earned and listed on the pause menu's Journal page.

const PATH := "user://achievements.json"

## id -> [title, description]
const DEFS := {
	"chief": ["Welcome, Musafir", "Meet the village chief."],
	"temple": ["Blessed Traveller", "Receive the temple's blessing."],
	"forest": ["Forest Cleared", "Defeat the raiders in the forest."],
	"tara": ["Tara's Saviour", "Rescue Tara."],
	"bazaar": ["Voice of the Bazaar", "Finish Whispers in the Bazaar."],
	"rider": ["Born to Ride", "Mount an animal."],
	"slam": ["Earth Shaker", "Land a ground slam on an enemy."],
	"shield": ["Guard Breaker", "Defeat a shield-bearer."],
	"night": ["Night Walker", "Walk the world after dark."],
	"coins": ["Pockets Full", "Hold 200 coins."],
	"beasts": ["Friend of Beasts", "Feed animals three times."],
	"hunter": ["Treasure Hunter", "Find all five buried caches."],
	"ending": ["The Last Sun", "Finish the story."],
}

var story: Story
var player: Player
var atmo: Atmosphere
var hud: Node
var done := {}
var _t := 0.0


func _ready() -> void:
	add_to_group("achievements")
	load_file()


func load_file() -> void:
	done = {}
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			done = d


func save_file() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(done))


func unlock(id: String) -> bool:
	if done.has(id) or not DEFS.has(id):
		return false
	done[id] = true
	save_file()
	if hud != null and hud.has_method("banner"):
		hud.banner("Achievement: " + Loc.t(String(DEFS[id][0])), "")
	return true


func count() -> int:
	return done.size()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or story == null:
		return
	_t = 1.0
	if story.get_flag("met_chief"):
		unlock("chief")
	if story.get_flag("temple_blessed"):
		unlock("temple")
	if int(story.get_flag("forest_down", 0)) >= 4:
		unlock("forest")
	if story.get_flag("tara_saved"):
		unlock("tara")
	if story.get_flag("bz_done"):
		unlock("bazaar")
	if player != null:
		if player.mounted:
			unlock("rider")
		if int(story.get_flag("coins", 0)) >= 200:
			unlock("coins")
	if int(story.get_flag("animals_fed", 0)) >= 3:
		unlock("beasts")
	if atmo != null and atmo.night > 0.8:
		unlock("night")


## Called by enemies/player code through the group of events they already have.
func note_kill(role: String, by_slam: bool) -> void:
	if role == "shield":
		unlock("shield")
	if by_slam:
		unlock("slam")
