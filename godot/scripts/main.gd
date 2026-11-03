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
const CAMERA_FOV := 36.0
const CAMERA_ELEVATION_DEG := 52.0
const CAMERA_HEIGHT_MAX := 1.2
## Outer edge of the palace terraces. The camera is fitted to this, so the scene spans the screen width.
const DECOR_DEPTH := 2.4   ## room for front and back decorations in the camera fit
const DICE_POSITION := Vector3(0, 1.25, 0)
const DICE_TAP_RADIUS_PX := 120.0

var camera: Camera3D
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
	add_child(RoyalBoard.new())
	_place_decorations()
	_build_camera()
	var dice := _build_dice()

	game = GameController.new()
	game.name = "Game"
	add_child(game)
	game.director = director
	game.setup(dice, seed_value)

	hud = Hud.new()
	add_child(hud)
	hud.new_game_pressed.connect(_start_new_game)
	hud.new_game_pressed.connect(func() -> void: audio.play("ui_click"))
	game.message.connect(hud.set_message)
	game.message.connect(_log_message)
	game.turn_changed.connect(hud.set_turn)
	game.game_finished.connect(_on_game_finished)
	game.event.connect(_on_game_event)
	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	effects = EffectsManager.new()
	effects.name = "Effects"
	add_child(effects)

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
		_start_new_game_test()
	elif "--menu-play" in args:
		audio.start_music()
		_start_from_menu({"mode": "ai", "players": 4, "difficulty": 1, "rules": GameSettings.get_rules()})
	else:
		hud.visible = false
		menu.show_page("main")
		audio.start_music()
	_apply_settings()
	if "--fx-shot" in args:
		effects.fireworks(3.0)
		effects.confetti(4.0)
		effects.burst(Vector3(0, 1.0, 0), EffectsManager.GOLD, 60, 3.0, 1.0)
	if "--capture-test" in args or "--capture-kick" in args:
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
	return "--click-test" in args or "--capture-test" in args or "--capture-kick" in args or "--fx-shot" in args or "--dice-face" in args


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
	game.fast_mode = false
	game.new_game(colors, humans, config["rules"], config["difficulty"])
	_last_config = config


var _last_config: Dictionary = {}


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
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Elephant.glb", "pos": Vector3(-6.2, 0, 7.6), "yaw": 0, "type": "elephant", "scale": 0.5},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Elephant_Statue.glb", "pos": Vector3(6.2, 0, 7.6), "yaw": 0, "type": "statue", "scale": 1.1},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Peacock_HighPoly_Textured.glb", "pos": Vector3(-7.4, 0, -7.6), "yaw": 180, "type": "peacock", "scale": 0.6},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Peacock_Statue.glb", "pos": Vector3(7.4, 0, -7.6), "yaw": 180, "type": "statue", "scale": 1.0},
	{"path": "res://assets/models/06_Decorations/Royal_India_Lotus_Fountain.glb", "pos": Vector3(0, 0, 8.1), "yaw": 0, "type": "fountain", "scale": 0.9},
	{"path": "res://assets/models/06_Decorations/Royal_India_Deepam_Lamp_Set.glb", "pos": Vector3(0, 0, -8.1), "yaw": 180, "type": "lamp", "scale": 0.7},
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
			audio.play("dice_roll")
			effects.sparkle_trail(pos + up)
			audio.vibrate(15)
		"roll_land":
			audio.play("dice_land")
			effects.burst(pos, EffectsManager.GOLD, 14, 1.2, 0.6)
		"select":
			audio.play("token_select")
		"hop":
			audio.play("token_step", 0.08)
		"land":
			audio.play("token_land")
			effects.burst(pos + Vector3(0, 0.1, 0), EffectsManager.GOLD, 12, 1.0, 0.5)
		"capture":
			audio.play("capture")
			effects.burst(pos + up, EffectsManager.TEAM.get(data.get("color", "red"), EffectsManager.GOLD), 50, 3.2, 1.0)
			effects.shockwave(pos)
			_shake(0.12, 0.4)
			audio.vibrate(40)
		"finish":
			audio.play("token_finish")
			effects.burst(pos + up, EffectsManager.GOLD, 40, 2.4, 1.2)
		"click":
			audio.play("ui_click")
		"game_over":
			audio.play("victory")
			effects.fireworks(3.0)
			var ranking: Array = data.get("ranking", [])
			if not ranking.is_empty() and ranking[0]["human"]:
				effects.confetti(4.0)


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
	var outer := RoyalBoard.outer_size()
	var half_x := outer.x * 0.5
	var half_z := outer.y * 0.5 + DECOR_DEPTH
	var corners: Array[Vector3] = []
	for x in [-half_x, half_x]:
		for y in [0.0, CAMERA_HEIGHT_MAX]:
			for z in [-half_z, half_z]:
				corners.append(Vector3(x, y, z))
	var near_d := 4.0
	var far_d := 150.0
	for i in range(40):
		var mid := (near_d + far_d) * 0.5
		if _corners_fit(dir * mid, corners):
			far_d = mid
		else:
			near_d = mid
	_camera_base = dir * far_d
	camera.look_at_from_position(_camera_base, Vector3(0, 0.3, 0), Vector3.UP)
	if director:
		director.set_base(_camera_base, Vector3(0, 0.3, 0), CAMERA_FOV)


func _corners_fit(position: Vector3, corners: Array[Vector3]) -> bool:
	camera.look_at_from_position(position, Vector3(0, 0.3, 0), Vector3.UP)
	var vp := get_viewport().get_visible_rect().size
	for c in corners:
		if camera.is_position_behind(c):
			return false
		var p := camera.unproject_position(c)
		if absf(p.x - vp.x * 0.5) > vp.x * 0.5 * 0.995:
			return false
		## Width is the limit: the board may run slightly past the top and bottom of the screen.
		if absf(p.y - vp.y * 0.5) > vp.y * 0.5 * 1.25:
			return false
	return true


func _build_dice() -> DiceController:
	var dice := DiceController.new()
	dice.name = "Dice"
	dice.position = DICE_POSITION
	var model := Node3D.new()
	model.name = "DiceModel"
	model.add_child((load(DICE_PATH) as PackedScene).instantiate())
	model.scale = Vector3.ONE * 0.9
	dice.add_child(model)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	dice.add_child(shape)
	add_child(dice)
	return dice


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a120c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff1d6")
	env.ambient_light_energy = 0.6
	## Glow (bloom) is supported by the Mobile renderer, with its lower HDR range.
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.light_color = Color("#ffe7bf")
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	_build_palace_floor()

## A large marble palace floor under the board. Board and decorations sit on it, so
## wide phone screens are filled edge to edge instead of showing a dark border.
func _build_palace_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "PalaceFloor"
	var plane := _make_plane(160.0)
	floor_mesh.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#8a6a4c")
	stone.roughness = 0.35
	stone.clearcoat_enabled = true
	stone.clearcoat = 0.3
	var grain := FastNoiseLite.new()
	grain.frequency = 0.012
	grain.fractal_octaves = 3
	var grain_tex := NoiseTexture2D.new()
	grain_tex.noise = grain
	grain_tex.seamless = true
	grain_tex.width = 512
	grain_tex.height = 512
	stone.albedo_texture = grain_tex
	stone.uv1_scale = Vector3(4, 4, 4)
	floor_mesh.material_override = stone
	floor_mesh.position = Vector3(0, -0.62, 0)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)

func _make_plane(size: float) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	return plane


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
	e.roll_with_value(3)
	await game._execute(mover)
	var sent_home: bool = e.seats[1]["tokens"][0] == 0
	print("capture test: green token sent home=%s" % str(sent_home))
	print("CAPTURE TEST " + ("PASS" if sent_home else "FAIL"))
	get_tree().quit(0 if sent_home else 1)


func _run_click_test() -> void:
	for i in range(30):
		await get_tree().process_frame
	var started := Time.get_ticks_msec()
	var clicks := 0
	# Click the dice on each human turn until the engine asks for a token choice.
	while not game.awaiting_pick and Time.get_ticks_msec() - started < 90000:
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
	## Wait in real time, so effects that run for seconds are still on screen.
	await get_tree().create_timer(float(_arg_value(OS.get_cmdline_user_args(), "--shot-delay")) if _has_arg("--shot-delay") else 1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
	get_tree().quit()
