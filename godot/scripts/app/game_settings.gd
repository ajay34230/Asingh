## All player-facing settings and the match configuration, saved to user://settings.cfg.
## Each section is loaded, updated and saved on its own, so sections do not overwrite each other.
## A missing or corrupt file falls back to defaults.
class_name GameSettings
extends RefCounted

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"graphics": "high",         ## low | medium | high
	"camera_tilt": true,        ## true: tilted 3D view; false: straight top-down
	"anim_speed": 1,            ## 0 slow, 1 normal, 2 fast
	"show_fps": false,
	"voice": true,
	"turn_timer": true,         ## 20 s per human action, then the game plays for you              ## spoken Hindi commentary and token dialogue
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
