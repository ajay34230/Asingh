## All player-facing settings and the match configuration, saved to user://settings.cfg.
## Each section is loaded, updated and saved on its own, so sections do not overwrite each other.
## A missing or corrupt file falls back to defaults.
class_name GameSettings
extends RefCounted

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"graphics": "medium",       ## low | medium | high (medium suits most phones)
	"graphics_style": "enhanced", ## classic (original look) | enhanced | ultra
	"graphics_auto": false,     ## the device has been checked once and a quality chosen
	"fps_cap": 60,              ## 30 saves battery and heat, 60 is smoother
	"warrior_variant": 0,       ## which of your colour's 4 warriors: master, heavy, striker, commander
	"token_style": "knight",    ## knight | robot | royal | original: which token model is used
	"camera_tilt": true,        ## true: tilted 3D view; false: straight top-down
	"anim_speed": 1,            ## 0 slow, 1 normal, 2 fast
	"show_fps": false,
	"voice": true,
	"turn_timer": true,
	"tutorial_done": false,
	"colorblind": false,        ## shape markers above tokens (circle, triangle, square, diamond)
	"large_text": false,        ## interface drawn 15% larger
	"relaxed_ai": false,        ## AI players take their turns more slowly     ## the first-game coach has been completed         ## 20 s per human action, then the game plays for you              ## spoken Hindi commentary and token dialogue
	"language": "en",
	"players": 4,               ## 2 | 3 | 4
	"difficulty": 1,            ## 0 Easy .. 3 Expert
	"rules": {
		"six_to_start": true,
		"three_sixes_penalty": true,
		"capture_bonus": true,
		"home_bonus": true,
		"quick_end": false,
	},
}

static func load_value(section: String, key: String, fallback: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return fallback
	return cfg.get_value(section, key, fallback)

static func save_value(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  ## keeps the other sections; a missing file just starts empty
	cfg.set_value(section, key, value)
	cfg.save(PATH)

static func get_option(key: String) -> Variant:
	return load_value("game", key, DEFAULTS[key])

static func set_option(key: String, value: Variant) -> void:
	save_value("game", key, value)

static func get_rules() -> Dictionary:
	var stored: Variant = load_value("game", "rules", DEFAULTS["rules"])
	var out: Dictionary = DEFAULTS["rules"].duplicate()
	if stored is Dictionary:
		for key in out:
			if (stored as Dictionary).has(key):
				out[key] = bool((stored as Dictionary)[key])
	return out

static func set_rules(rules: Dictionary) -> void:
	save_value("game", "rules", rules)


## Coins earned in games, kept between sessions (section "progress").
static func get_coins() -> int:
	return int(load_value("progress", "coins", 0))


static func add_coins(amount: int) -> int:
	var total := get_coins() + amount
	save_value("progress", "coins", total)
	return total
