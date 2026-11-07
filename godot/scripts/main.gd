## Main scene: supplied board, straight top-down camera that fits any screen, dice,
## game controller and HUD.
##
## Options (after --):
##   --screenshot=PATH   save one frame after the game starts, then quit
##   --demo              play a full all-AI game without delays, print the result, quit
##   --seed=N            deterministic dice sequence
extends Node3D

const DICE_PATH := "res://assets/models/02_Dice/Royal_India_Royal_Jewel_Dice.glb"
const SCREEN_MARGIN := 0.04
## Tilted perspective so tokens read as 3D figures, not flat discs.
const CAMERA_FOV := 32.0
const CAMERA_ELEVATION_DEG := 64.0
const CAMERA_HEIGHT_MAX := 0.3
const DICE_POSITION := Vector3(0, 1.25, 0)
const DICE_TAP_RADIUS_PX := 120.0

var camera: Camera3D
var board: RoyalBoard
var voice: VoiceManager
var bubbles: SpeechBubbles
var _last_turn_human := false
var game: GameController
var audio: AudioManager
var effects: EffectsManager
var _shake_time := 0.0
var _shake_strength := 0.0
var _camera_base := Vector3.ZERO
var director: CameraDirector
var hud: Hud
var menu: GameMenu
var _camera_tilt := true
var _demo := false
var _demo_done := false


func _ready() -> void:
	get_viewport().physics_object_picking = true
	var args := OS.get_cmdline_user_args()
	_demo = "--demo" in args
	var seed_value := 0
	var shot := ""
	var menu_shot := ""
	for arg in args:
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--menu-screenshot="):
			menu_shot = arg.trim_prefix("--menu-screenshot=")

	_build_environment()
	_build_vignette()
	board = RoyalBoard.new()
	board.name = "Board"
	add_child(board)
	_place_decorations()
	_build_camera()
	var dice := _build_dice()

	game = GameController.new()
	game.name = "Game"
	add_child(game)
	game.director = director
	var preview := MovePreview.new()
	preview.name = "MovePreview"
	add_child(preview)
	game.preview = preview
	var safe := SafeSquares.new()
	safe.name = "SafeSquares"
	safe.game = game
	add_child(safe)
	safe.shield_raised.connect(func(at: Vector3) -> void:
		if not game.fast_mode:
			audio.play("shield", 0.02)
			if randf() < 0.6:
				_announce("safe")
			effects.burst(at + Vector3(0, 0.5, 0), EffectsManager.GOLD, 18, 1.4, 0.6))
	game.setup(dice, seed_value)
	dice.bounced.connect(func() -> void: audio.play("dice_bounce", 0.1))

	hud = Hud.new()
	add_child(hud)
	hud.new_game_pressed.connect(_start_new_game)
	hud.button_sound.connect(func() -> void: audio.play("ui_click", 0.03))
	game.message.connect(hud.set_message)
	game.message.connect(_log_message)
	game.turn_changed.connect(hud.set_turn)
	game.turn_changed.connect(func(color: String, _human: bool) -> void: board.update_plaques(game.engine.seats, color))
	game.event.connect(func(_name: String, _data: Dictionary) -> void: board.update_plaques(game.engine.seats, game.current_color() if game.engine.phase != RulesEngine.PHASE_OVER else ""))
	game.game_finished.connect(_on_game_finished)
	game.event.connect(_on_game_event)
	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	effects = EffectsManager.new()
	effects.name = "Effects"
	add_child(effects)
	voice = VoiceManager.new()
	voice.name = "Voice"
	voice.audio = audio
	add_child(voice)
	bubbles = SpeechBubbles.new()
	bubbles.name = "SpeechBubbles"
	add_child(bubbles)
	game.turn_changed.connect(_on_turn_voice)

	if "--dice-face" in args:
		game.dice.setup_face(int(_arg_value(args, "--dice-face")))
	_build_menu()
	if _demo:
		Engine.time_scale = 40.0  ## demo only: run the whole game quickly
		game.fast_mode = true
		var players := int(_arg_value(args, "--players")) if _has_arg("--players=") else 4
		var demo_colors: Array = ["blue", "yellow", "green", "red"]
		if players == 2:
			demo_colors = ["blue", "green"]
		elif players == 3:
			demo_colors = ["blue", "yellow", "green"]
		_start_new_game_with([], demo_colors)
	elif _is_test_launch(args):
		menu.visible = false
		_start_new_game_test()
	elif "--menu-play" in args:
		audio.start_music()
		_start_from_menu({"mode": "ai", "players": 4, "difficulty": 1, "rules": GameSettings.get_rules()})
	else:
		hud.visible = false
		menu.show_page("main")
		if _reopen_page != "":
			menu._refresh_themes()
			menu.show_page(_reopen_page)
			_reopen_page = ""
		audio.start_music("menu")
		## Opening: the camera rises over the palace, then the menu fades in.
		director.start_attract(not _intro_seen)
		menu.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_interval(0.0 if _intro_seen else 2.2)
		fade.tween_property(menu, "modulate:a", 1.0, 0.8)
		_intro_seen = true
	_apply_settings()
	if "--fx-shot" in args:
		effects.fireworks(3.0)
		effects.confetti(4.0)
		effects.burst(Vector3(0, 1.0, 0), EffectsManager.GOLD, 60, 3.0, 1.0)
	if _has_arg("--preview-shot="):
		_run_preview_shot(_arg_value(args, "--preview-shot"))
	elif "--capture-test" in args or "--capture-kick" in args:
		_run_capture_test()
	elif "--click-test" in args:
		_run_click_test()
	elif shot != "":
		_screenshot_and_quit(shot)
	elif menu_shot != "" and "--menu-play" in args:
		_screenshot_and_quit(menu_shot)
	elif menu_shot != "":
		if "--menu-page=settings" in args:
			menu.show_page("settings")
			_load_settings_page()
		_screenshot_and_quit(menu_shot)


func _is_test_launch(args: PackedStringArray) -> bool:
	for arg in args:
		if arg.begins_with("--screenshot=") or arg.begins_with("--seed="):
			return true
	return "--click-test" in args or _has_arg("--preview-shot=") or "--capture-test" in args or "--capture-kick" in args or "--fx-shot" in args or "--dice-face" in args


## Main menu, settings and pause overlays. The menu sits above the 3D scene.
func _build_menu() -> void:
	var layer := CanvasLayer.new()  ## Controls only draw inside a CanvasLayer
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	menu = GameMenu.new()
	menu.name = "Menu"
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(menu)
	menu.set_audio(audio)
	menu.start_game.connect(_start_from_menu)
	menu.settings_changed.connect(_apply_settings)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	menu.closed.connect(_on_menu_closed)
	## A new theme rebuilds the scene; come back to the themes page afterwards.
	menu.board_theme_changed.connect(func() -> void:
		_reopen_page = "themes"
		get_tree().reload_current_scene())
	hud.menu_pressed.connect(_quit_to_menu)
	hud.rematch_pressed.connect(func() -> void: _start_new_game())
	hud.settings_pressed.connect(func() -> void:
		menu.set_overlay(true)
		menu.show_page("settings")
		menu.visible = true)
	hud.help_pressed.connect(func() -> void:
		menu.set_overlay(true)
		menu.show_page("howto")
		menu.visible = true)


func _start_from_menu(config: Dictionary) -> void:
	var colors: Array[String] = []
	var players: int = config["players"]
	if players == 2:
		colors = ["blue", "green"]  ## opposite corners
	elif players == 3:
		colors = ["blue", "yellow", "green"]
	else:
		colors = ["blue", "yellow", "green", "red"]
	var humans: Array[String] = []
	if config["mode"] == "pass":
		humans = colors.duplicate()
	else:
		humans = ["blue"]
	menu.visible = false
	hud.visible = true
	hud.hide_result()
	director.stop_attract(1.4)
	audio.start_music("game")
	_announce_later("start", 1.0, true)
	game.fast_mode = false
	game.new_game(colors, humans, config["rules"], config["difficulty"])
	_last_config = config


var _last_config: Dictionary = {}
static var _intro_seen := false
static var _reopen_page := ""   ## the long opening plays once per launch


## Rematch and restart use the last configuration.
func _start_new_game() -> void:
	if _last_config.is_empty():
		_start_new_game_with(["blue"], ["blue", "yellow", "green", "red"])
		return
	_start_from_menu(_last_config)


func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_closed() -> void:
	menu.visible = false
	if get_tree().paused:
		hud.open_pause()


func _load_settings_page() -> void:
	menu._load_settings_into_controls()


## Applies graphics, camera and animation settings. Called at start and after changes.
func _apply_settings() -> void:
	var quality: String = GameSettings.get_option("graphics")
	var high := quality == "high"
	var medium := quality != "low"
	var env: Environment = null
	for child in get_children():
		if child is WorldEnvironment:
			env = (child as WorldEnvironment).environment
		if child is DirectionalLight3D:
			(child as DirectionalLight3D).shadow_enabled = medium
	if env:
		env.glow_enabled = medium
	get_viewport().scaling_3d_scale = 0.75 if quality == "low" else 1.0
	get_viewport().msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_DISABLED
	_camera_tilt = GameSettings.get_option("camera_tilt")
	game.anim_scale = [1.6, 1.0, 0.6][int(GameSettings.get_option("anim_speed"))]
	hud.set_fps_visible(GameSettings.get_option("show_fps"))
	if voice:
		voice.enabled = GameSettings.get_option("voice")
	_fit_camera()


func _start_new_game_test() -> void:
	game.fast_mode = _demo
	_start_new_game_with(["blue"], ["blue", "yellow", "green", "red"])


func _start_new_game_with(humans: Array, seats: Array) -> void:
	var typed_humans: Array[String] = []
	for h in humans:
		typed_humans.append(h)
	var typed_seats: Array[String] = []
	for s in seats:
		typed_seats.append(s)
	game.new_game(typed_seats, typed_humans)


## Royal decorations, placed beside the board (outside the playfield, so they never
## obstruct the track). Each one gets its matching idle animation script.
const DECORATIONS := [
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Elephant.glb", "pos": Vector3(-12.7, RoyalBoard.WING_TOP, 0.0), "yaw": 90, "type": "elephant", "scale": 0.75},
	{"path": "res://assets/models/06_Decorations/Royal_India_Lotus_Fountain.glb", "pos": Vector3(12.7, RoyalBoard.WING_TOP, 0.0), "yaw": 0, "type": "fountain", "scale": 0.9},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Peacock_HighPoly_Textured.glb", "pos": Vector3(-18.4, RoyalBoard.WING_TOP, 0.6), "yaw": 60, "type": "peacock", "scale": 0.7},
	{"path": "res://assets/models/06_Decorations/Royal_India_Deepam_Lamp_Set.glb", "pos": Vector3(-18.4, RoyalBoard.WING_TOP, 7.2), "yaw": 0, "type": "lamp", "scale": 0.7},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Peacock_Statue.glb", "pos": Vector3(18.4, RoyalBoard.WING_TOP, 0.6), "yaw": -60, "type": "statue", "scale": 1.0},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Elephant_Statue.glb", "pos": Vector3(18.4, RoyalBoard.WING_TOP, 7.2), "yaw": -90, "type": "statue", "scale": 1.1},
]

func _place_decorations() -> void:
	for deco in DECORATIONS:
		var root := Node3D.new()
		root.name = String(deco["type"]).capitalize()
		root.position = deco["pos"]
		root.rotation_degrees.y = deco["yaw"]
		root.scale = Vector3.ONE * float(deco["scale"])
		add_child(root)
		root.add_child((load(deco["path"]) as PackedScene).instantiate())
		var animator := RoyalEnvironmentAnimator.new()
		animator.animation_type = deco["type"]
		root.add_child(animator)


## Routes presentation cues from the game to sound, haptics and effects.
func _on_game_event(event_name: String, data: Dictionary) -> void:
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var up := Vector3(0, 0.45, 0)
	match event_name:
		"roll_start":
			audio.play("dice_shake", 0.05)
			effects.sparkle_trail(pos + up)
			audio.vibrate(15)
		"roll_land":
			audio.play("dice_land")
			effects.burst(pos, EffectsManager.GOLD, 14, 1.2, 0.6)
			if int(data.get("value", 0)) == 6 and not game.fast_mode:
				hud.flash_banner("SIX!", Color("#ffd24a"), 0.5)
				_announce("six")
				audio.play("six", 0.0)
				effects.burst(pos + up, EffectsManager.GOLD, 40, 2.8, 0.9)
		"select":
			audio.play("token_select")
		"hop":
			audio.play("token_step", 0.1, -2.0)
		"land":
			audio.play("token_land")
			effects.burst(pos + Vector3(0, 0.1, 0), EffectsManager.GOLD, 12, 1.0, 0.5)
		"capture":
			if game.fast_mode:
				audio.play("punch")
			else:
				audio.play("blade", 0.03)   ## steel drawn: the fight is on
				_token_says(data.get("attacker_token"), "taunt", data.get("attacker", ""))
		"swing":
			audio.play("swish", 0.1, 0.0 if data.get("heavy", false) else -5.0)
		"jab":
			audio.play("punch", 0.08, -5.0)
			effects.hit_spark(pos, false)
			_shake(0.03, 0.12)
			audio.vibrate(12)
		"impact":
			audio.play(data.get("kind", "punch"), 0.05)
			audio.play("impact", 0.06, -4.0)  ## low boom under the recorded hit
			effects.hit_spark(pos, true)
			effects.burst(pos, EffectsManager.TEAM.get(data.get("color", "red"), EffectsManager.GOLD), 18, 2.2, 0.7)
			audio.vibrate(60)
			hud.flash_banner(["KNOCKOUT!", "BOOM!", "SMASH!"].pick_random(), Color("#ffd24a"))
			_token_says(data.get("victim_token"), "hurt", data.get("color", ""))
			_announce_later("capture", 1.4)
		"crash":
			audio.play("thud", 0.05, -2.0)
			effects.dust(pos)
		"spin":
			audio.play("swish", 0.0, -2.0)
		"throw":
			audio.play("swish", 0.08)
		"thrown_home":
			audio.play("thud", 0.05)
			effects.burst(pos + Vector3(0, 0.15, 0), EffectsManager.TEAM.get(data.get("color", "red"), EffectsManager.GOLD), 24, 1.6, 0.7)
			effects.shockwave(pos)
			audio.vibrate(25)
		"finish":
			audio.play("token_finish", 0.0, -3.0)
			audio.play("coins", 0.03)
			_token_says(data.get("token"), "cheer", data.get("color", ""))
			_announce_later("home", 1.2)
			effects.burst(pos + up, EffectsManager.GOLD, 40, 2.4, 1.2)
		"click":
			audio.play("ui_click")
		"three_sixes":
			_announce("three_sixes", true)
		"no_move":
			if data.get("human", false):
				_announce("no_move")
		"invalid":
			audio.play("error", 0.0, -4.0)
		"game_over":
			audio.play("victory")
			var won: bool = not (data.get("ranking", []) as Array).is_empty() and data["ranking"][0]["human"]
			var any_human: bool = (data.get("ranking", []) as Array).any(func(r: Dictionary) -> bool: return r["human"])
			if any_human:
				_announce_later("win" if won else "lose", 0.6)
			effects.fireworks(3.0)
			var ranking: Array = data.get("ranking", [])
			if not ranking.is_empty() and ranking[0]["human"]:
				effects.confetti(4.0)


## Dialogue: the announcer speaks with a subtitle; tokens speak in a bubble.
func _announce(key: String, force := false) -> void:
	if game.fast_mode or voice == null:
		return
	hud.show_caption(voice.announce(key, force))


func _announce_later(key: String, seconds: float, force := false) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	_announce(key, force)


func _token_says(token: Variant, key: String, color: String) -> void:
	if game.fast_mode or voice == null or not (token is Node3D):
		return
	bubbles.say(token, voice.token_line(key, color), color)


func _on_turn_voice(_color: String, human: bool) -> void:
	if human and not _last_turn_human and randf() < 0.35:
		_announce("your_turn")
	_last_turn_human = human


## Short camera shake: a random offset that decays over the duration.
func _shake(strength: float, duration: float) -> void:
	director.shake(strength, duration)


func _process(_delta: float) -> void:
	pass


func _log_message(text: String) -> void:
	if _demo:
		print("[game] " + text)


func _on_game_finished(ranking: Array) -> void:
	hud.show_result(ranking)
	if _demo and not _demo_done:
		_demo_done = true
		print("DEMO RESULT: " + str(ranking))
		get_tree().quit(0)


## Tilted perspective camera. The camera distance is chosen so the whole board spans
## the screen width (or height, whichever is the limit), so it fills the phone screen.
func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "BoardCamera"
	director = CameraDirector.new()
	director.name = "CameraDirector"
	add_child(director)
	director.setup(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _fit_camera() -> void:
	var el := deg_to_rad(CAMERA_ELEVATION_DEG if _camera_tilt else 89.0)
	var dir := Vector3(0, sin(el), cos(el))
	## The square main board must fit the height and the plaque columns the width. On a
	## wide phone the height is the limit, so the wings run past both screen edges.
	var half_x := RoyalBoard.VISIBLE_HALF_X
	var half_z := RoyalBoard.outer_size().y * 0.5 + 0.2
	var plaque_z := RoyalBoard.PLAQUE_Z + RoyalBoard.PLAQUE_SIZE.y * 0.5 + 0.2
	var corners: Array[Vector3] = []
	for y in [0.0, CAMERA_HEIGHT_MAX]:
		for z in [-half_z, half_z]:
			corners.append(Vector3(0.0, y, z))
		for x in [-half_x, half_x]:
			for z in [-plaque_z, plaque_z]:
				corners.append(Vector3(x, y, z))
	## Search the look-at point along z too, so the gaps above and below the board are
	## equal (a tilted camera would otherwise leave more room at the far edge).
	var lo := -1.0
	var hi := 4.0
	for i in range(18):
		_camera_target = Vector3(0, 0, (lo + hi) * 0.5)
		_fit_distance(dir, corners)
		var top := camera.unproject_position(Vector3(0, 0, -half_z)).y
		var bottom := get_viewport().get_visible_rect().size.y - camera.unproject_position(Vector3(0, 0, half_z)).y
		if top > bottom:
			lo = _camera_target.z
		else:
			hi = _camera_target.z
	_camera_target = Vector3(0, 0, (lo + hi) * 0.5)
	var distance := _fit_distance(dir, corners)
	_camera_base = _camera_target + dir * distance
	camera.look_at_from_position(_camera_base, _camera_target, Vector3.UP)
	if director:
		director.set_base(_camera_base, _camera_target, CAMERA_FOV)


var _camera_target := Vector3.ZERO


func _fit_distance(dir: Vector3, corners: Array[Vector3]) -> float:
	var near_d := 4.0
	var far_d := 150.0
	for i in range(32):
		var mid := (near_d + far_d) * 0.5
		if _corners_fit(_camera_target + dir * mid, corners):
			far_d = mid
		else:
			near_d = mid
	_corners_fit(_camera_target + dir * far_d, corners)
	return far_d


func _corners_fit(position: Vector3, corners: Array[Vector3]) -> bool:
	camera.look_at_from_position(position, _camera_target, Vector3.UP)
	var vp := get_viewport().get_visible_rect().size
	for c in corners:
		if camera.is_position_behind(c):
			return false
		var p := camera.unproject_position(c)
		if absf(p.x - vp.x * 0.5) > vp.x * 0.5:
			return false
		if absf(p.y - vp.y * 0.5) > vp.y * 0.5:
			return false
	return true


func _build_dice() -> DiceController:
	var dice := DiceController.new()
	dice.name = "Dice"
	dice.position = DICE_POSITION
	var model := Node3D.new()
	model.name = "DiceModel"
	model.add_child((load(DICE_PATH) as PackedScene).instantiate())
	model.scale = Vector3.ONE * 1.15
	dice.add_child(model)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	dice.add_child(shape)
	add_child(dice)
	return dice


func _make_plane(size: float) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	return plane


func _build_environment() -> void:
	var env := Environment.new()
	## A warm palace sky: never seen directly (the camera looks down), but gold, gems
	## and polished marble reflect it.
	var sky_mat := ProceduralSkyMaterial.new()
	var theme := BoardThemes.current()
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.sky_horizon_color = theme["sky_horizon"]
	sky_mat.ground_horizon_color = theme["ground_horizon"]
	## A warm, fairly bright lower sky: gold and gems reflect it on every downward or
	## sideways face, so a dark ground would make all the gold look brown.
	sky_mat.ground_bottom_color = (theme["ground_bottom"] as Color).lerp(theme["ground_horizon"], 0.65)
	sky_mat.ground_horizon_color = (theme["ground_horizon"] as Color).lerp(theme["sky_horizon"], 0.35)
	sky_mat.sun_angle_max = 40.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	## Daytime themes light the board with a photographed evening sky (HDRI, CC0): real
	## light and real reflections in the marble and gold. Diwali keeps its night sky.
	if not theme.get("night", false):
		var hdri := PanoramaSkyMaterial.new()
		hdri.panorama = load("res://assets/textures/sky/evening_courtyard_1k.hdr")
		hdri.energy_multiplier = 0.7
		sky.sky_material = hdri
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(theme["ambient"]) * 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	## Glow (bloom) is supported by the Mobile renderer, with its lower HDR range.
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	## Depth fog fades the far table into darkness on low camera angles (title screen).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#1a0806")
	env.fog_density = 1.0
	env.fog_depth_begin = 38.0
	env.fog_depth_end = 80.0
	env.fog_sky_affect = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = theme["sun_energy"]
	sun.light_color = theme["sun"]
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	## Cool fill from the opposite side, so shadows are not black.
	var fill := DirectionalLight3D.new()
	fill.light_energy = theme["fill_energy"]
	fill.light_color = theme["fill"]
	fill.rotation_degrees = Vector3(-40, 150, 0)
	add_child(fill)
	_build_palace_floor()
	## Reflection probe over the board: polished marble and gold reflect the monuments
	## and tokens (Mobile and Forward+ renderers; updated once, then reused).
	var probe := ReflectionProbe.new()
	probe.size = Vector3(RoyalBoard.WING_HALF_X * 2.0, 8.0, RoyalBoard.outer_size().y + 2.0)
	probe.position = Vector3(0, 3.0, 0)
	probe.box_projection = true
	probe.intensity = 0.7
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(probe)

## Soft cinematic vignette and a slight warm grade over the 3D view (below the HUD).
func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.42;
uniform vec4 warm : source_color = vec4(1.0, 0.86, 0.66, 1.0);
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.6;                                 // wide screens: ellipse, not a circle
	float v = smoothstep(0.38, 0.95, length(p));
	COLOR = vec4(mix(vec3(0.0), warm.rgb * 0.15, 0.4), v * strength);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)


## Black-and-gold marble table under the board, seen past its long edges on 16:9 screens.
func _build_palace_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "PalaceFloor"
	floor_mesh.mesh = _make_plane(160.0)
	## Polished black-green granite table (scanned).
	var table := RoyalBoard.pbr("granite_dark", (BoardThemes.current()["table"] as Color).lerp(Color.WHITE, 0.6), 0.12, 0.6, 0.5)
	floor_mesh.material_override = table
	floor_mesh.position = Vector3(0, RoyalBoard.SLAB_BOTTOM, 0)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)


## Taps on a glowing token move it. The ray is cast to a plane just above the track.
func _unhandled_input(event: InputEvent) -> void:
	if game == null:
		return
	var screen := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		screen = event.position
	elif event is InputEventScreenTouch and event.pressed:
		screen = event.position
	else:
		return
	## Tap on the dice (screen-space radius, so it also works on touch screens).
	if game.dice.rollable:
		var dice_screen := camera.unproject_position(game.dice.global_position)
		if screen.distance_to(dice_screen) < DICE_TAP_RADIUS_PX:
			game.dice.roll_requested.emit()
			return
	if not game.awaiting_pick:
		return
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return
	var t := (GameController.TRACK_Y + 0.2 - origin.y) / dir.y
	var hit := origin + dir * t
	var color := game.current_color()
	var best := -1
	var best_dist := GameController.TOKEN_PICK_RADIUS
	for i in range(BoardPath.TOKENS_PER_PLAYER):
		var token: Node3D = game.tokens[color][i]
		var d := Vector2(token.global_position.x - hit.x, token.global_position.z - hit.z).length()
		if d < best_dist:
			best_dist = d
			best = i
	if best >= 0:
		game.tap_token(color, best)


func _has_arg(key: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(key):
			return true
	return false


func _arg_value(args: PackedStringArray, key: String) -> String:
	for arg in args:
		if arg.begins_with(key + "="):
			return arg.trim_prefix(key + "=")
	return "1"


## End-to-end input check: pushes real mouse events into the viewport, so the same
## physics picking a player's tap uses is exercised. Clicks the dice, then a legal token
## if the engine asks for a choice, and checks that the rules state changed.
## Runs one real capture at normal speed, so the punch, kick, grab and throw code runs.
func _run_capture_test() -> void:
	for i in range(10):
		await get_tree().process_frame
	game.fast_mode = false
	game.new_game(["blue", "green"] as Array[String], ["blue"] as Array[String], GameSettings.get_rules(), 1)
	var e := game.engine
	var mover := 1 if "--capture-kick" in OS.get_cmdline_user_args() else 0  ## odd index uses a kick
	e.seats[0]["tokens"] = [0, 0, 0, 0]
	e.seats[0]["tokens"][mover] = 10
	var target := BoardPath.ring_index_for_progress("blue", 13)
	e.seats[1]["tokens"] = [((target - BoardPath.start_of("green") + 52) % 52) + 1, 0, 0, 0]
	_place_tokens_from_engine()  ## put the 3D tokens where the rules now say they are
	await get_tree().create_timer(0.8).timeout
	e.roll_with_value(3)
	await game._execute(mover)
	var sent_home: bool = e.seats[1]["tokens"][0] == 0
	print("capture test: green token sent home=%s" % str(sent_home))
	print("CAPTURE TEST " + ("PASS" if sent_home else "FAIL"))
	await get_tree().create_timer(1.0).timeout  ## let the landing settle on screen (and in recordings)
	get_tree().quit(0 if sent_home else 1)


## Stages a human turn with several legal moves (one captures) and saves a screenshot.
func _run_preview_shot(path: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	game.new_game(["blue", "green"] as Array[String], ["blue"] as Array[String], GameSettings.get_rules(), 1)
	var e := game.engine
	e.seats[0]["tokens"] = [1, 12, 9, 49]  ## 1 = start square, 9 = star square (both safe)
	var target := BoardPath.ring_index_for_progress("blue", 16)
	e.seats[1]["tokens"] = [((target - BoardPath.start_of("green") + 52) % 52) + 1, 0, 0, 0]
	_place_tokens_from_engine()
	e.roll_with_value(4)
	game._legal = e.legal_moves()
	game.awaiting_pick = true
	game._highlight(true)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
	get_tree().quit()


func _place_tokens_from_engine() -> void:
	for seat in game.engine.seats:
		var color: String = seat["color"]
		for i in range(BoardPath.TOKENS_PER_PLAYER):
			var token: TransformerToken = game.tokens[color][i]
			token.global_position = game._track_world(color, seat["tokens"][i], i)
			token.ground_y = token.global_position.y


func _run_click_test() -> void:
	for i in range(30):
		await get_tree().process_frame
	var started := Time.get_ticks_msec()
	var clicks := 0
	# Click the dice on each human turn until the engine asks for a token choice.
	while not game.awaiting_pick and Time.get_ticks_msec() - started < 240000:
		if game.is_human_turn() and game.engine.phase == RulesEngine.PHASE_ROLL and not game.busy:
			_click(camera.unproject_position(game.dice.global_position))
			clicks += 1
			for i in range(5):
				await get_tree().process_frame
		await get_tree().process_frame
	print("click test: dice clicks=%d, engine rolled %d, awaiting_pick=%s" % [clicks, game.engine.dice, str(game.awaiting_pick)])
	var ok := game.awaiting_pick and game.engine.dice == 6 and clicks >= 1
	if game.awaiting_pick:
		var color := game.current_color()
		var index: int = game._legal[0]
		var before: int = game.engine.seats[game.engine.current]["tokens"][index]
		_click(camera.unproject_position(game.tokens[color][index].global_position))
		for i in range(120):
			await get_tree().process_frame
			if not game.busy:
				break
		var after: int = game.engine.seats[game.engine.current]["tokens"][index] if game.engine.current == 0 else -1
		print("click test: tapped %s_%d; progress before=%d after=%d" % [color, index, before, after])
		ok = ok and after == 1
	print("CLICK TEST " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _click(screen_pos: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = screen_pos
	move.global_position = screen_pos
	get_viewport().push_input(move)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = screen_pos
		ev.global_position = screen_pos
		get_viewport().push_input(ev)


func _screenshot_and_quit(path: String) -> void:
	## Optional test camera: --cam=x,y,z,tx,ty,tz (position, then look-at target).
	if _has_arg("--cam="):
		var v := _arg_value(OS.get_cmdline_user_args(), "--cam").split(",")
		if v.size() == 6:
			director.set_process(false)
			camera.look_at_from_position(Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3(float(v[3]), float(v[4]), float(v[5])), Vector3.UP)
	## Wait in real time, so effects that run for seconds are still on screen.
	await get_tree().create_timer(float(_arg_value(OS.get_cmdline_user_args(), "--shot-delay")) if _has_arg("--shot-delay") else 1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
	get_tree().quit()
