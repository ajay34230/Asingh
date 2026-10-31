class_name GameSettings
extends RefCounted
## All player-adjustable options in one place: audio mixer buses, video, controls and gameplay.
## Values live in `v`, are saved to user://settings.cfg and applied to the running game by `apply()`.
## GameMenu builds its Settings screen from SPEC, so a new option is one line here plus a case in apply().

const PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Voice", "Ambience"]

## tab, key, label, kind (slider|toggle|choice), default, extra (slider: [min, max, step]; choice: option names)
const SPEC: Array = [
	["Audio", "vol_master", "Master volume", "slider", 1.0, [0.0, 1.0, 0.05]],
	["Audio", "vol_music", "Music", "slider", 0.8, [0.0, 1.0, 0.05]],
	["Audio", "vol_sfx", "Sound effects", "slider", 1.0, [0.0, 1.0, 0.05]],
	["Audio", "vol_voice", "Voices", "slider", 1.0, [0.0, 1.0, 0.05]],
	["Audio", "vol_ambience", "Ambience (wind, rain, crowds)", "slider", 1.0, [0.0, 1.0, 0.05]],
	["Audio", "voices", "Spoken NPC voices", "toggle", true, null],
	["Video", "quality", "Graphics preset", "choice", 0, ["High", "Medium", "Low"]],
	["Video", "render_scale", "Resolution scale (0% = automatic)", "slider", 0.0, [0.0, 1.0, 0.05]],
	["Video", "shadows", "Shadows", "choice", 2, ["Off", "Low", "High"]],
	["Video", "aa", "Anti-aliasing", "choice", 0, ["Off", "FXAA", "MSAA 2x", "MSAA 4x"]],
	["Video", "fps_cap", "Frame rate limit", "choice", 2, ["30", "45", "60", "90", "Unlimited"]],
	["Video", "vsync", "VSync", "toggle", true, null],
	["Video", "view_dist", "Foliage draw distance", "slider", 1.0, [0.4, 1.6, 0.1]],
	["Video", "bloom", "Bloom / glow", "toggle", true, null],
	["Video", "brightness", "Brightness", "slider", 1.0, [0.7, 1.4, 0.05]],
	["Video", "contrast", "Contrast", "slider", 1.1, [0.8, 1.4, 0.05]],
	["Video", "saturation", "Colour saturation", "slider", 1.1, [0.6, 1.5, 0.05]],
	["Video", "show_fps", "Show FPS counter", "toggle", true, null],
	["Controls", "sens", "Look speed", "slider", 1.0, [0.4, 2.5, 0.05]],
	["Controls", "sens_y", "Vertical look speed", "slider", 1.0, [0.4, 2.0, 0.05]],
	["Controls", "invert", "Invert look up/down", "toggle", false, null],
	["Controls", "lefty", "Left-handed layout", "toggle", false, null],
	["Controls", "btnsize", "Button size", "slider", 1.0, [0.8, 1.4, 0.05]],
	["Controls", "btnalpha", "Button opacity", "slider", 1.0, [0.3, 1.6, 0.05]],
	["Controls", "autosprint", "Auto-sprint at full stick", "toggle", true, null],
	["Controls", "haptics", "Vibration when hurt", "toggle", true, null],
	["Language", "lang", "Language / भाषा", "choice", 0, ["English", "हिन्दी"]],
	["Gameplay", "outfit", "Outfit colour", "choice", 0, ["Default", "Crimson", "Indigo", "Forest", "Saffron", "Teal", "Violet"]],
	["Gameplay", "difficulty", "Difficulty", "choice", 1, ["Easy", "Normal", "Hard"]],
	["Gameplay", "fov", "Field of view", "slider", 70.0, [60.0, 95.0, 1.0]],
	["Gameplay", "fp", "First-person view", "toggle", false, null],
	["Gameplay", "shake", "Camera shake", "toggle", true, null],
	["Gameplay", "tracker", "Mission tracker on screen", "toggle", true, null],
	["Gameplay", "minimap", "Minimap on screen", "toggle", true, null],
	["Gameplay", "hint", "Control hints", "toggle", true, null],
]
const TABS := ["Language", "Audio", "Video", "Controls", "Gameplay"]
const DAMAGE_BY_DIFFICULTY := [0.6, 1.0, 1.5]

static var v: Dictionary = {}
static var main: Node3D = null


static func defaults() -> Dictionary:
	var d := {}
	for s in SPEC:
		d[s[1]] = s[4]
	return d


static func get_v(key: String) -> Variant:
	if v.is_empty():
		v = defaults()
	return v[key]


static func damage_scale() -> float:
	return DAMAGE_BY_DIFFICULTY[clampi(int(get_v("difficulty")), 0, 2)]


## Create the Music / SFX / Voice / Ambience buses under Master (once).
static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


static func load_file() -> void:
	v = defaults()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in v.keys():
		if cfg.has_section_key("s", k):
			var val: Variant = cfg.get_value("s", k, v[k])
			if typeof(val) == typeof(v[k]) or (typeof(v[k]) == TYPE_FLOAT and typeof(val) == TYPE_INT):
				v[k] = val
	# older saves stored "volume" for the master level
	if cfg.has_section_key("s", "volume") and not cfg.has_section_key("s", "vol_master"):
		v["vol_master"] = float(cfg.get_value("s", "volume", 1.0))


static func save_file() -> void:
	var cfg := ConfigFile.new()
	for k in v.keys():
		cfg.set_value("s", k, v[k])
	cfg.save(PATH)


static func set_value(key: String, val: Variant) -> void:
	if v.is_empty():
		v = defaults()
	v[key] = val
	apply(key)
	save_file()


static func reset_tab(tab: String) -> void:
	var d := defaults()
	for s in SPEC:
		if tab == "" or s[0] == tab:
			v[s[1]] = d[s[1]]
	apply_all()
	save_file()


static func _bus_db(bus: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))


static func apply_all() -> void:
	if v.is_empty():
		v = defaults()
	for s in SPEC:
		if s[1] != "quality":
			apply(s[1])
	apply("quality")


## Push one value to the running game. Safe before the world exists (nodes are looked up lazily).
static func apply(key: String) -> void:
	var player: Player = main.get("player") as Player if main != null else null
	var atmo: Atmosphere = main.get("atmosphere") as Atmosphere if main != null else null
	var touch: Object = main.get("touch") if main != null else null
	match key:
		"vol_master": _bus_db("Master", float(v[key]))
		"vol_music": _bus_db("Music", float(v[key]))
		"vol_sfx": _bus_db("SFX", float(v[key]))
		"vol_voice": _bus_db("Voice", float(v[key]))
		"vol_ambience": _bus_db("Ambience", float(v[key]))
		"voices":
			if Sfx.instance != null:
				Sfx.instance.voices_on = bool(v[key])
				if not bool(v[key]):
					Sfx.stop_speech()
		"outfit":
			if main != null and main.get("player") != null:
				(main.get("player") as Player).set_outfit(int(v[key]))
		"lang":
			Loc.set_language("hi" if int(v[key]) == 1 else "en")
		"quality":
			if main != null:
				main.call("apply_quality", int(v[key]))
				for k2 in ["shadows", "render_scale", "bloom", "view_dist"]:
					apply(k2)
		"render_scale":
			if main != null:
				var s := float(v[key])
				if s > 0.0:
					main.get_viewport().scaling_3d_scale = clampf(s, 0.4, 1.0)
				else:
					main.get_viewport().scaling_3d_scale = [1.0, 0.8, 0.62][clampi(int(v["quality"]), 0, 2)]
		"shadows":
			if atmo != null:
				var sh := int(v[key])
				atmo.sun.shadow_enabled = sh > 0
				if sh == 1:
					atmo.sun.directional_shadow_max_distance = 70.0
					atmo.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				elif sh == 2:
					var tier := clampi(int(v["quality"]), 0, 2)
					atmo.sun.directional_shadow_max_distance = [260.0, 150.0, 90.0][tier]
					atmo.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		"aa":
			if main != null:
				var vp := main.get_viewport()
				var a := int(v[key])
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if a == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
				vp.msaa_3d = Viewport.MSAA_2X if a == 2 else (Viewport.MSAA_4X if a == 3 else Viewport.MSAA_DISABLED)
		"fps_cap": Engine.max_fps = [30, 45, 60, 90, 0][clampi(int(v[key]), 0, 4)]
		"vsync": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(v[key]) else DisplayServer.VSYNC_DISABLED)
		"view_dist":
			if main != null:
				var k := float(v[key])
				var tier := clampi(int(v["quality"]), 0, 2)
				var ranges := {"foliage_grass": [130.0, 75.0, 40.0], "foliage_reeds": [160.0, 100.0, 60.0], "foliage_palm": [420.0, 260.0, 150.0], "foliage_stone": [220.0, 130.0, 75.0]}
				for g in ranges:
					for n in main.get_tree().get_nodes_in_group(g):
						(n as GeometryInstance3D).visibility_range_end = float(ranges[g][tier]) * k
		"bloom":
			if atmo != null:
				atmo.environment.glow_enabled = bool(v[key]) and int(v["quality"]) < 2
		"brightness":
			if atmo != null:
				atmo.environment.adjustment_brightness = float(v[key])
		"contrast":
			if atmo != null:
				atmo.environment.adjustment_contrast = float(v[key])
		"saturation":
			if atmo != null:
				atmo.environment.adjustment_saturation = float(v[key])
		"show_fps":
			if touch != null:
				touch.set("show_fps", bool(v[key]))
		"sens":
			if player != null:
				player.look_sens = float(v[key])
		"sens_y":
			if player != null:
				player.look_sens_y = float(v[key])
		"invert":
			if player != null:
				player.invert_y = bool(v[key])
		"lefty", "btnsize", "btnalpha":
			if touch != null:
				touch.set("left_handed", bool(v["lefty"]))
				touch.set("btn_scale", float(v["btnsize"]))
				touch.set("btn_alpha", float(v["btnalpha"]))
				(touch as Control).queue_redraw()
		"autosprint":
			if player != null:
				player.auto_sprint = bool(v[key])
		"haptics":
			if player != null:
				player.haptics = bool(v[key])
		"fov":
			if player != null:
				player.base_fov = float(v[key])
		"fp":
			if player != null:
				player.set_first_person(bool(v[key]))
		"shake":
			StoryFX.shake_on = bool(v[key])
		"tracker":
			var hud: Object = main.get("hud") if main != null else null
			if hud != null:
				hud.call("set_tracker_visible", bool(v[key]))
		"minimap":
			var mp: Object = main.get("map_ui") if main != null else null
			if mp != null:
				mp.call("set_minimap_visible", bool(v[key]))
		"hint":
			if touch != null:
				touch.set("hints_on", bool(v[key]))
