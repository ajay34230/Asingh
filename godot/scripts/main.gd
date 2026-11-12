## Main scene: supplied board, straight top-down camera that fits any screen, dice,
## game controller and HUD.
##
## Options (after --):
##   --screenshot=PATH   save one frame after the game starts, then quit
##   --demo              play a full all-AI game without delays, print the result, quit
##   --seed=N            deterministic dice sequence
extends Node3D

const SCREEN_MARGIN := 0.04
## Tilted perspective so tokens read as 3D figures, not flat discs.
const CAMERA_FOV := 32.0
const CAMERA_ELEVATION_DEG := 64.0
const CAMERA_HEIGHT_MAX := 0.3
const DICE_POSITION := Vector3(0, 1.25, 0)
const DICE_TAP_RADIUS_PX := 120.0

var camera: Camera3D
var board: RoyalBoard
var loading: LoadingScreen
var voice: VoiceManager
var dlc: DLCManager
var tutorial: Tutorial
var net: NetPlay
var bubbles: SpeechBubbles
var _last_turn_human := false
var _decor := {}   ## first decoration of each type, for reactions
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

	I18n.setup()
	if _has_arg("--token-style="):   # tests and screenshots: robot | royal | original
		TransformerToken.style_override = _arg_value(args, "--token-style")
	if _has_arg("--festival="):
		Festivals.override = _arg_value(args, "--festival")
	## Loading screen first, so it is on screen while the palace is built.
	loading = LoadingScreen.new()
	add_child(loading)
	if not _demo and not _is_test_launch(args):
		await get_tree().process_frame
		await get_tree().process_frame
		if _has_arg("--loading-shot="):
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(_arg_value(args, "--loading-shot"))
			print("saved loading shot")
			get_tree().quit()
			return
	_build_environment()
	_build_vignette()
	board = RoyalBoard.new()
	board.name = "Board"
	add_child(board)
	_place_decorations()
	var garden := Garden.new()
	garden.name = "Garden"
	add_child(garden)
	_build_camera()
	var dice := _build_dice()
	_build_dice_holder()

	game = GameController.new()
	game.name = "Game"
	add_child(game)
	game.director = director
	var preview := MovePreview.new()
	preview.name = "MovePreview"
	add_child(preview)
	game.preview = preview
	net = NetPlay.new()
	net.name = "Net"
	add_child(net)
	net.game = game
	game.net = net
	net.game_started.connect(_start_net_game)
	net.disconnected.connect(func(reason: String) -> void:
		hud.set_message(tr(reason)))
	var specials := SpecialSquares.new()
	specials.name = "SpecialSquares"
	add_child(specials)
	game.specials = specials
	var safe := SafeSquares.new()
	safe.name = "SafeSquares"
	safe.game = game
	add_child(safe)
	safe.shield_raised.connect(func(at: Vector3) -> void:
		if not game.fast_mode:
			audio.play("shield", 0.02)
			tutorial.tip("safe")
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
	var ambience := Ambience.new()
	ambience.name = "Ambience"
	ambience.effects = effects
	add_child(ambience)
	voice = VoiceManager.new()
	voice.name = "Voice"
	voice.audio = audio
	add_child(voice)
	bubbles = SpeechBubbles.new()
	bubbles.name = "SpeechBubbles"
	add_child(bubbles)
	game.turn_changed.connect(_on_turn_voice)
	game.turn_timer.connect(board.set_turn_timer)
	game.replay.camera = camera
	game.replay.cue.connect(_on_replay_cue)
	hud.replay_pressed.connect(_play_replay)
	hud.photo_pressed.connect(_save_photo)
	tutorial = Tutorial.new()
	hud.add_child(tutorial)
	game.turn_changed.connect(func(_c: String, human: bool) -> void:
		if human and not game.fast_mode:
			tutorial.tip("roll"))

	if "--dice-face" in args:
		game.dice.setup_face(int(_arg_value(args, "--dice-face")))
	_build_menu()
	menu.net = net
	menu._build_lan()
	dlc = DLCManager.new()
	dlc.name = "DLC"
	add_child(dlc)
	menu.dlc = dlc
	menu.build_resources()
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
		if "--perf-test" in args:
			_run_perf_test()
	elif "--menu-play" in args:
		audio.start_music()
		_start_from_menu({"mode": "ai", "players": 4, "difficulty": 1, "rules": GameSettings.get_rules()})
	else:
		hud.visible = false
		if "--journey-test" in args:
			_journey_test()
		if _pending_chapter >= 0:
			## A Royal Journey chapter after the palace reload. (No early return: the
			## settings and the loading-screen reveal below must still run.)
			var idx := _pending_chapter
			_pending_chapter = -1
			hud.visible = true
			menu.visible = false
			_apply_settings()
			loading.reveal(0.7)
			_start_chapter(idx)
			return
		menu.show_page("main")
		## First launch of the day: offer the daily reward.
		if Progress.daily_status()[0] and _reopen_page == "":
			_reopen_page = "rewards"
		if _reopen_page != "":
			if _reopen_page == "rewards":
				menu._refresh_rewards()
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
	loading.reveal(0.0 if (_demo or _is_test_launch(args) or menu_shot != "") else 0.7)
	if "--fx-shot" in args:
		effects.fireworks(3.0)
		effects.confetti(4.0)
		effects.burst(Vector3(0, 1.0, 0), EffectsManager.GOLD, 60, 3.0, 1.0)
	if "--ui-test" in args:
		_run_ui_test()
	elif "--net-host-test" in args or "--net-join-test" in args:
		_run_net_test("--net-host-test" in args)
	elif "--showcase" in args:
		_run_showcase()
	elif _has_arg("--result-shot="):
		_run_result_shot(_arg_value(args, "--result-shot"))
	elif _has_arg("--preview-shot="):
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
		var page := _arg_value(args, "--menu-page") if _has_arg("--menu-page=") else ""
		if page == "settings":
			_load_settings_page()
		elif page == "profile":
			menu._refresh_profile()
		elif page == "themes":
			menu._refresh_themes()
		elif page == "rewards":
			menu._refresh_rewards()
		elif page == "journey":
			menu._refresh_journey()
		elif page == "lan":
			menu._open_lan()
		elif page == "resources":
			menu._refresh_resources()
		if page != "":
			menu.show_page(page)
		_screenshot_and_quit(menu_shot)


## 4-player game in real time with the human auto-playing: reports how heavy the scene
## is (draw calls, triangles) and how many turns went by, so a slow or stuck 4-player
## game shows up as numbers.
func _run_perf_test() -> void:
	for i in range(8):
		await get_tree().process_frame
	var seconds := float(_arg_value(OS.get_cmdline_user_args(), "--perf-seconds")) if _has_arg("--perf-seconds=") else 40.0
	var start := Time.get_ticks_msec()
	var turns := 0
	var last_color := ""
	var worst_idle := 0.0
	var idle_since := Time.get_ticks_msec()
	var draw_calls := 0
	var prims := 0
	var frames := 0
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		var c := game.current_color()
		if c != last_color:
			last_color = c
			turns += 1
		if game.is_human_turn() and not game.busy:
			if game.engine.phase == RulesEngine.PHASE_ROLL and game.dice.rollable:
				game._on_roll_requested()
			elif game.awaiting_pick:
				game.tap_token(c, game._legal[0])
		if game.busy or not game.is_human_turn():
			idle_since = Time.get_ticks_msec()
		worst_idle = maxf(worst_idle, (Time.get_ticks_msec() - idle_since) / 1000.0)
		await get_tree().process_frame
		frames += 1
		if frames == 6:   # sample the renderer once the scene has settled
			draw_calls = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			prims = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if "--perf-breakdown" in OS.get_cmdline_user_args():
		var rows := []
		for c in get_children():
			var inst := 0
			var surf := 0
			var tris := 0
			var list: Array = c.find_children("*", "MeshInstance3D", true, false)
			if c is MeshInstance3D:
				list.append(c)
			for n in list:
				var mesh: Mesh = (n as MeshInstance3D).mesh
				if mesh == null or not (n as MeshInstance3D).is_visible_in_tree():
					continue
				inst += 1
				surf += mesh.get_surface_count()
				tris += mesh.get_faces().size() / 3
			rows.append([tris, surf, inst, String(c.name), c.get_class()])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		for r in rows.slice(0, 14):
			print("  BREAKDOWN %-28s %-14s instances=%5d surfaces=%5d triangles=%8d" % [r[3], r[4], r[2], r[1], r[0]])
	print("PERF: players=%d tokens=%d draw_calls=%d triangles=%d frames=%d fps=%.1f turn_changes=%d worst_human_wait=%.1fs" % [
		game.engine.seats.size(), game.tokens.size() * 4, draw_calls, prims, frames, frames / seconds, turns, worst_idle])
	get_tree().quit()


func _is_test_launch(args: PackedStringArray) -> bool:
	for arg in args:
		if arg.begins_with("--screenshot=") or arg.begins_with("--seed="):
			return true
	return "--click-test" in args or "--ui-test" in args or "--showcase" in args or "--net-host-test" in args or "--net-join-test" in args or _has_arg("--preview-shot=") or _has_arg("--result-shot=") or "--perf-test" in args or "--capture-test" in args or "--capture-kick" in args or "--fx-shot" in args or "--dice-face" in args


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
	menu.resume_requested.connect(_resume_game)
	## A new theme rebuilds the scene; come back to the themes page afterwards.
	menu.campaign_start.connect(_begin_chapter)
	menu.board_theme_changed.connect(func() -> void:
		_reopen_page = "themes"
		_intro_seen = true
		loading.cover(func() -> void: get_tree().reload_current_scene()))
	menu.design_changed.connect(func() -> void: game.refresh_designs())
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
	get_tree().paused = false
	menu.set_resume_available(false)
	var colors: Array[String] = []
	var players: int = config["players"]
	if players == 2:
		colors = ["blue", "green"]  ## opposite corners
	elif players == 3:
		colors = ["blue", "yellow", "green"]
	else:
		colors = ["blue", "yellow", "green", "red"]
	if config.get("mode", "") == "team":
		colors = ["blue", "yellow", "green", "red"]
	if config.has("colors"):
		colors.assign(config["colors"])
	var humans: Array[String] = []
	if config["mode"] == "pass":
		humans = colors.duplicate()
	else:
		humans = ["blue"]
	menu.visible = false
	hud.visible = true
	hud.hide_result()
	game.dice.visible = true
	director.stop_attract(1.4)
	audio.start_music("game")
	_announce_later("start", 1.0, true)
	game.fast_mode = false
	game.new_game(colors, humans, config["rules"], config["difficulty"])
	_last_config = config
	_perf_guard(colors.size())


var _last_config: Dictionary = {}
static var _intro_seen := false
static var _reopen_page := ""
static var _pending_chapter := -1   ## a Royal Journey chapter to start after the reload
static var _theme_before := ""      ## the player's own theme, restored after a chapter   ## the long opening plays once per launch


## Rematch and restart use the last configuration.
func _start_new_game() -> void:
	if _last_config.is_empty():
		_start_new_game_with(["blue"], ["blue", "yellow", "green", "red"])
		return
	_start_from_menu(_last_config)


## A Wi-Fi game began (on the host and on every friend's phone).
func _start_net_game(config: Dictionary) -> void:
	var humans: Array[String] = []
	for c in config["owners"]:
		humans.append(c)
	game._seed = int(config["seed"])
	menu.visible = false
	hud.visible = true
	hud.hide_result()
	game.dice.visible = true
	director.stop_attract(1.4)
	audio.start_music("game")
	var colors: Array[String] = []
	colors.assign(config["colors"])
	game.new_game(colors, humans, config["rules"], int(config["difficulty"]))
	_last_config = {"mode": "net", "players": colors.size(), "difficulty": config["difficulty"], "rules": config["rules"]}
	if "--net-host-test" in OS.get_cmdline_user_args() or "--net-join-test" in OS.get_cmdline_user_args():
		_net_autoplay()


## UI test: every menu page opens, fits or scrolls, and closes with X; pause, then main
## menu, then Resume returns to the same game; the back button pauses and resumes.
func _run_ui_test() -> void:
	var failures := [0]
	var report := func(name: String, cond: bool) -> void:
		print(("ok   " if cond else "FAIL ") + name)
		if not cond:
			failures[0] += 1
	for i in range(10):
		await get_tree().process_frame
	menu.visible = true
	hud.visible = false
	for page in ["settings", "themes", "rewards", "profile", "journey", "modes", "howto", "setup", "lan"]:
		match page:
			"themes": menu._refresh_themes()
			"rewards": menu._refresh_rewards()
			"profile": menu._refresh_profile()
			"journey": menu._refresh_journey()
			"settings": menu._load_settings_into_controls()
			"setup": menu._open_setup("ai")
			"lan": menu._open_lan()
		menu.show_page(page)
		for k in range(4):
			await get_tree().process_frame
		var scroll: ScrollContainer = menu._scrolls.get(page)
		var panel: Control = menu._panels[page]
		var vp := get_viewport().get_visible_rect().size
		var fits: bool = panel.size.y <= vp.y + 1.0
		var content_h: float = scroll.get_child(0).get_combined_minimum_size().y
		var reachable: bool = content_h <= scroll.size.y + 1.0 or scroll.get_v_scroll_bar().max_value >= content_h - 1.0
		report.call("%s: panel fits the screen (%d <= %d)" % [page, panel.size.y, vp.y], fits)
		report.call("%s: all content reachable by scrolling" % page, reachable)
		var close: Button = null
		for b in panel.find_children("*", "Button", true, false):
			if (b as Button).text == "X":
				close = b
				break
		report.call("%s: has a close (X) button" % page, close != null)
		if close:
			close.pressed.emit()
			for k in range(3):
				await get_tree().process_frame
			report.call("%s: X returns to the title page" % page, menu._page == "main")
	## Renting a design by watching a (test) video, then customising it.
	menu.visible = true
	menu.show_page("themes")
	RewardedAds.force_test = true
	var saved_rentals := Progress.rentals()
	var saved_vp: Dictionary = GameSettings.load_value("progress", "video_progress", {})
	var saved_vd: Dictionary = GameSettings.load_value("progress", "videos_day", {})
	var saved_equip := Progress.equipped("design")
	var r0 := Progress.rentals()
	r0.erase("design_raja")
	GameSettings.save_value("progress", "rentals", r0)
	var had_raja := Progress.owns("design_raja")
	if not had_raja:
		menu._preview_design("design_raja")
		report.call("video button offered for a locked design", menu._preview_video.visible and not menu._style_box.visible)
		menu._preview_watch()
		await get_tree().create_timer(RewardedAds.TEST_SECONDS + 0.5).timeout
		var overlay := menu.find_children("*", "CanvasLayer", false, false)
		var btn: Button = null
		for l in overlay:
			for b in l.find_children("*", "Button", true, false):
				btn = b
		report.call("test video shows a collect button", btn != null and btn.text == tr("Collect reward"))
		if btn:
			btn.pressed.emit()
		await get_tree().process_frame
		report.call("watching rents the design and equips it", Progress.can_use("design_raja") and Progress.equipped("design") == "design_raja" and menu._style_box.visible)
		var metal_btn: Button = menu._metal_row.get_node("onyx")
		metal_btn.pressed.emit()
		report.call("metal choice is saved", Progress.design_style("design_raja")["metal"] == "onyx" and metal_btn.disabled)
	GameSettings.save_value("progress", "rentals", saved_rentals)
	GameSettings.save_value("progress", "video_progress", saved_vp)
	GameSettings.save_value("progress", "videos_day", saved_vd)
	Progress.equip(saved_equip)
	RewardedAds.force_test = false
	## Game, pause, main menu, resume.
	menu.visible = false
	hud.visible = true
	game.fast_mode = true
	game.new_game(["blue", "green"] as Array[String], ["blue"] as Array[String])
	game.engine.seats[0]["tokens"] = [5, 0, 0, 0]
	for k in range(5):
		await get_tree().process_frame
	hud.open_pause()
	report.call("pause opens and pauses", get_tree().paused and hud._pause_panel.visible)
	_quit_to_menu()
	for k in range(3):
		await get_tree().process_frame
	report.call("main menu keeps the game waiting", menu.visible and get_tree().paused and menu._resume_button.visible)
	menu._resume_button.pressed.emit()
	for k in range(3):
		await get_tree().process_frame
	report.call("resume returns to the same game", not menu.visible and hud.visible and not get_tree().paused and game.engine.seats[0]["tokens"][0] == 5)
	_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	report.call("back button pauses the game", get_tree().paused and hud._pause_panel.visible)
	_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	report.call("back button again resumes", not get_tree().paused and not hud._pause_panel.visible)
	print("UI TEST " + ("PASS" if failures[0] == 0 else "FAIL"))
	get_tree().quit(0 if failures[0] == 0 else 1)


## Test harness: two instances on one machine play a full game over the network; each
## prints the final board, which must match.
func _run_net_test(hosting: bool) -> void:
	game.fast_mode = true
	if hosting:
		net.host("Host")
		while net._players.size() < 2:
			await get_tree().process_frame
		var seats := int(_arg_value(OS.get_cmdline_user_args(), "--seats")) if _has_arg("--seats=") else 2
		var rules := {}
		if _has_arg("--rules="):
			for r in _arg_value(OS.get_cmdline_user_args(), "--rules").split(","):
				rules[r] = true
		net.start(1, rules, seats)
	else:
		await get_tree().create_timer(1.0).timeout
		net.join("127.0.0.1", "Guest")


func _net_autoplay() -> void:
	game.fast_mode = true
	var frames := 0
	while game.engine.phase != RulesEngine.PHASE_OVER and frames < 200000:
		var c := game.current_color()
		if net.is_local(c) and not game.busy:
			if game.engine.phase == RulesEngine.PHASE_ROLL and game.dice.rollable:
				game._on_roll_requested()
			elif game.awaiting_pick:
				game.tap_token(c, game._legal[0])
		await get_tree().process_frame
		frames += 1
	var state := []
	for seat in game.engine.seats:
		state.append([seat["color"], seat["tokens"]])
	print("NET RESULT %s ranks=%s" % [str(state), str(game.engine.rankings)])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


## Test: start a Royal Journey chapter from the menu while a game is paused behind it,
## then check that the palace loads, the loading screen lifts and the match runs.
static var _journey_stage := 0


func _journey_test() -> void:
	if _journey_stage == 0:
		_journey_stage = 1
		await get_tree().create_timer(1.0).timeout
		get_tree().paused = true
		_begin_chapter(0)
		return
	for k in range(40):   # up to 20 s on slow machines
		await get_tree().create_timer(0.5, true, false, true).timeout
		if not loading._root.visible and game.engine != null and not game.engine.seats.is_empty():
			break
	var lifted := not loading._root.visible
	var running := game.engine != null and not game.engine.seats.is_empty() and not get_tree().paused
	print("journey test: loading lifted=%s game running=%s theme=%s" % [lifted, running, BoardThemes.current_id()])
	print("JOURNEY TEST " + ("PASS" if lifted and running else "FAIL"))
	get_tree().quit(0 if lifted and running else 1)


## Royal Journey: switch to the chapter's palace (a scene reload), then play it.
func _begin_chapter(index: int) -> void:
	var ch: Dictionary = Campaign.CHAPTERS[index]
	if _theme_before == "":
		_theme_before = BoardThemes.current_id()
	_pending_chapter = index
	_intro_seen = true
	get_tree().paused = false   # a game paused behind the menu must not stay paused
	Engine.time_scale = 1.0
	BoardThemes.set_current(ch["theme"])
	loading.cover(func() -> void: get_tree().reload_current_scene())


func _start_chapter(index: int) -> void:
	var ch: Dictionary = Campaign.CHAPTERS[index]
	audio.start_music("game")
	hud.flash_banner(tr(ch["palace"]), RoyalTheme.GOLD_LIGHT, 2.2)
	hud.show_caption(tr(ch["intro"]), 4.5)
	_announce_later("journey", 0.4, true)
	await get_tree().create_timer(1.2).timeout
	_start_from_menu(Campaign.config(index))


## Main menu from a game: the game waits (paused) behind the title screen, and "Resume
## game" brings it back. After a Royal Journey chapter the scene reloads to restore
## the player's own board theme.
func _quit_to_menu() -> void:
	if _theme_before != "":
		get_tree().paused = false
		BoardThemes.set_current(_theme_before)
		_theme_before = ""
		loading.cover(func() -> void: get_tree().reload_current_scene())
		return
	var over := game.engine == null or game.engine.seats.is_empty() or game.engine.phase == RulesEngine.PHASE_OVER
	get_tree().paused = not over
	hud.close_pause_silent()
	hud.visible = false
	hud.hide_result()
	menu.set_overlay(false)
	menu.set_resume_available(not over)
	menu.visible = true
	menu._update_coin_badge()
	menu.show_page("main")
	director.start_attract(false)
	audio.start_music("menu")


func _resume_game() -> void:
	menu.visible = false
	menu.set_resume_available(false)
	hud.visible = true
	director.stop_attract(1.0)
	audio.start_music("game")
	get_tree().paused = false


## Android back button: close a page, pause/resume a game, or leave from the title.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if menu and menu.visible:
		if not menu.go_back():
			if menu._resume_button and menu._resume_button.visible:
				_resume_game()
			else:
				get_tree().quit()
	elif hud and hud.visible:
		hud.go_back()


func _on_menu_closed() -> void:
	menu.visible = false
	if get_tree().paused:
		hud.open_pause()


func _load_settings_page() -> void:
	menu._load_settings_into_controls()


## Applies graphics, camera and animation settings. Called at start and after changes.
## First launch: pick a quality that suits the device (the player can change it later).
func _detect_quality() -> void:
	if bool(GameSettings.get_option("graphics_auto")):
		return
	GameSettings.set_option("graphics_auto", true)
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var cores := OS.get_processor_count()
	var strong_gpu := false
	for key in ["adreno (tm) 7", "adreno (tm) 8", "mali-g7", "mali-g9", "apple", "nvidia", "radeon"]:
		if gpu.contains(key):
			strong_gpu = true
	var weak_gpu := gpu.contains("llvmpipe") or gpu.contains("mali-t") or gpu.contains("adreno (tm) 3") or gpu.contains("adreno (tm) 4") or gpu.contains("powervr")
	var quality := "medium"
	if cores <= 4 or weak_gpu:
		quality = "low"
	elif strong_gpu and cores >= 8:
		quality = "high"
	GameSettings.set_option("graphics", quality)
	GameSettings.set_option("fps_cap", 30 if quality == "low" else 60)
	print("device check: gpu='%s' cores=%d -> %s" % [gpu, cores, quality])


## Dynamic resolution: the perf guard lowers this first, before it drops a quality level.
var _res_scale := 1.0


func _apply_settings() -> void:
	if not _is_test_launch(OS.get_cmdline_user_args()) and not _demo:
		_detect_quality()
	var quality: String = GameSettings.get_option("graphics")
	## Ultra Realistic Graphics always gets the full effects, whatever the quality level.
	var high := quality == "high" or String(GameSettings.get_option("graphics_style")) == "ultra"
	Engine.max_fps = int(GameSettings.get_option("fps_cap")) if not _is_test_launch(OS.get_cmdline_user_args()) else 0
	var medium := quality != "low"
	var env: Environment = null
	for child in get_children():
		if child is WorldEnvironment:
			env = (child as WorldEnvironment).environment
		if child is DirectionalLight3D:
			(child as DirectionalLight3D).shadow_enabled = medium
	if env:
		env.glow_enabled = medium
	get_viewport().scaling_3d_scale = minf(0.75 if quality == "low" else 1.0, _res_scale)
	## Budget phones: Low drops the garden, drifting petals and reflections, and uses
	## simpler distant meshes; Medium keeps everything but the reflection probe.
	get_viewport().mesh_lod_threshold = 4.0 if quality == "low" else (2.0 if medium and not high else 1.0)
	for child in get_children():
		if child.name == "Garden":
			(child as Node3D).visible = quality != "low"
		elif child.name == "Ambience":
			for fx in child.get_children():
				if fx is GPUParticles3D:
					(fx as GPUParticles3D).emitting = quality != "low"
					(fx as GPUParticles3D).visible = quality != "low"
		elif child is ReflectionProbe:
			(child as ReflectionProbe).visible = high
	## Decoration (plants, statues, lamps, the fountain) does not cast shadows below High:
	## nobody sees them, and each one is drawn again in every shadow pass.
	for child in get_children():
		if child.name in ["Garden", "Peacock", "Elephant", "Statue", "Fountain", "Lamp", "DiceHolder"] or String(child.name).begins_with("@Node3D@"):
			_set_shadows(child, high)
	get_viewport().msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_DISABLED
	_camera_tilt = GameSettings.get_option("camera_tilt")
	game.anim_scale = [1.6, 1.0, 0.6][int(GameSettings.get_option("anim_speed"))]
	hud.set_fps_visible(GameSettings.get_option("show_fps"))
	if voice:
		voice.enabled = GameSettings.get_option("voice")
	game.relaxed = bool(GameSettings.get_option("relaxed_ai"))
	if game.engine and not game.engine.seats.is_empty():
		game.set_shape_markers(bool(GameSettings.get_option("colorblind")))
	get_window().content_scale_factor = 1.15 if bool(GameSettings.get_option("large_text")) else 1.0
	game.turn_seconds = 20.0 if GameSettings.get_option("turn_timer") and not _is_test_launch(OS.get_cmdline_user_args()) else 0.0
	_fit_camera()


## Slow phone? If the game stays below ~26 fps for a few seconds, drop one graphics level
## (Settings shows the change) so the match stays playable. Games with more players are
## heavier, so they are checked too.
var _guard_id := 0


func _perf_guard(player_count: int) -> void:
	if _demo or _is_test_launch(OS.get_cmdline_user_args()):
		return
	_guard_id += 1
	var my_id := _guard_id
	await get_tree().create_timer(8.0).timeout    # let the opening camera move and loading settle
	for round in range(3):                        # up to three drops, a check every ~6 s
		if my_id != _guard_id or get_tree().paused or not hud.visible:
			return
		var frames := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
			frames += 1
		var fps := frames / 3.0
		var quality: String = GameSettings.get_option("graphics")
		if fps >= 26.0 or (quality == "low" and _res_scale <= 0.72):
			return
		if _res_scale > 0.72:   # first lower the resolution a step, which costs the least
			_res_scale = maxf(0.7, _res_scale - 0.15)
			_apply_settings()
			print("perf guard: %.0f fps, resolution scale -> %.2f" % [fps, _res_scale])
			await get_tree().create_timer(3.0).timeout
			continue
		var lower := "low" if quality == "medium" else "medium"
		GameSettings.set_option("graphics", lower)
		_apply_settings()
		hud.show_caption(tr("Graphics lowered for smooth play. You can change this in Settings."), 4.0)
		print("perf guard: %.0f fps with %d players, graphics %s -> %s" % [fps, player_count, quality, lower])
		await get_tree().create_timer(3.0).timeout


func _set_shadows(node: Node, on: bool) -> void:
	if node is GeometryInstance3D:
		var g := node as GeometryInstance3D
		if on:
			if g.has_meta("shadow_orig"):   # back to what it was before it was switched off
				g.cast_shadow = g.get_meta("shadow_orig")
				g.remove_meta("shadow_orig")
		elif not g.has_meta("shadow_orig"):
			g.set_meta("shadow_orig", g.cast_shadow)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_set_shadows(c, on)


func _start_new_game_test() -> void:
	game.fast_mode = _demo
	var seat_list := ["blue", "yellow", "green", "red"]
	if _has_arg("--seats-n="):   # tests: fewer seats (2 = blue and green)
		var n := int(_arg_value(OS.get_cmdline_user_args(), "--seats-n"))
		seat_list = ["blue", "green"] if n == 2 else (["blue", "yellow", "green"] if n == 3 else seat_list)
	_start_new_game_with(["blue"], seat_list)
	if game.specials:
		game.specials.sync_powerups(game.engine.powerups)


func _start_new_game_with(humans: Array, seats: Array) -> void:
	var typed_humans: Array[String] = []
	for h in humans:
		typed_humans.append(h)
	var typed_seats: Array[String] = []
	for s in seats:
		typed_seats.append(s)
	var rules := {}
	if _has_arg("--rules="):
		for r in _arg_value(OS.get_cmdline_user_args(), "--rules").split(","):
			rules[r] = true
	game.new_game(typed_seats, typed_humans, rules)


## Royal decorations, placed beside the board (outside the playfield, so they never
## obstruct the track). Each one gets its matching idle animation script.
const DECORATIONS := [
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Elephant.glb", "pos": Vector3(-12.7, RoyalBoard.WING_TOP, 0.0), "yaw": 90, "type": "elephant", "scale": 0.75},
	{"path": "res://assets/models/06_Decorations/Royal_India_Lotus_Fountain.glb", "pos": Vector3(12.7, RoyalBoard.WING_TOP, 0.0), "yaw": 0, "type": "fountain", "scale": 0.9},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Peacock_HighPoly_Textured.glb", "pos": Vector3(-17.3, RoyalBoard.WING_TOP, 0.6), "yaw": 60, "type": "peacock", "scale": 0.7},
	{"path": "res://assets/models/06_Decorations/Royal_India_Deepam_Lamp_Set.glb", "pos": Vector3(-17.3, RoyalBoard.WING_TOP, 7.2), "yaw": 0, "type": "lamp", "scale": 0.7},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Peacock_Statue.glb", "pos": Vector3(17.3, RoyalBoard.WING_TOP, 0.6), "yaw": -60, "type": "statue", "scale": 1.0},
	{"path": "res://assets/models/05_Animals_and_Statues/Royal_India_Elephant_Statue.glb", "pos": Vector3(17.3, RoyalBoard.WING_TOP, 7.2), "yaw": -90, "type": "statue", "scale": 1.1},
]

func _place_decorations() -> void:
	for deco in DECORATIONS:
		var root := Node3D.new()
		root.name = String(deco["type"]).capitalize()
		root.position = deco["pos"]
		root.rotation_degrees.y = deco["yaw"]
		root.scale = Vector3.ONE * float(deco["scale"])
		add_child(root)
		var model := (load(deco["path"]) as PackedScene).instantiate()
		root.add_child(model)
		_repair_meshes(model)
		if not _decor.has(deco["type"]):
			_decor[deco["type"]] = root
		var animator := RoyalEnvironmentAnimator.new()
		animator.animation_type = deco["type"]
		root.add_child(animator)


## Some supplied models have no normals or no texture coordinates. Without UVs a
## texture is sampled at one point (often black), so those surfaces keep their material
## colour instead; missing normals are generated so the phone renderer can light them.
static func _repair_meshes(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not (m.mesh is ArrayMesh):
			continue
		var src := m.mesh as ArrayMesh
		var fixed := ArrayMesh.new()
		var changed := false
		for i in range(src.get_surface_count()):
			var arrays := src.surface_get_arrays(i)
			var mat := m.get_active_material(i)
			var has_uv: bool = arrays[Mesh.ARRAY_TEX_UV] != null
			var has_normals: bool = arrays[Mesh.ARRAY_NORMAL] != null
			if not has_normals:
				var st := SurfaceTool.new()
				st.create_from_arrays(arrays)
				st.generate_normals()
				arrays = st.commit_to_arrays()
				changed = true
			fixed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if mat is BaseMaterial3D and not has_uv and (mat as BaseMaterial3D).albedo_texture:
				var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.albedo_texture = null
				copy.albedo_color = copy.albedo_color * Color(0.62, 0.6, 0.58)   # the texture darkened it
				copy.normal_texture = null
				copy.roughness_texture = null
				fixed.surface_set_material(i, copy)
				changed = true
			else:
				fixed.surface_set_material(i, mat)
		if changed:
			m.mesh = fixed
			for i in range(fixed.get_surface_count()):
				m.set_surface_override_material(i, null)


## Routes presentation cues from the game to sound, haptics and effects.
func _on_game_event(event_name: String, data: Dictionary) -> void:
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var up := Vector3(0, 0.45, 0)
	match event_name:
		"roll_start":
			audio.play("dice_shake", 0.05)
			effects.sparkle_trail(pos + up)
			if int(data.get("value", 0)) == 6 and not game.fast_mode:
				_dice_trail(1.3)
			elif Progress.equipped("trail") != "trail_none" and not game.fast_mode and game.is_human_turn():
				_dice_trail(1.1, Progress.equipped("trail"))
			audio.vibrate(15)
		"roll_land":
			if game.is_human_turn():
				var v := int(data.get("value", 0))
				if v == 6:
					audio.vibrate_pattern([25, 70, 25])
				elif game.engine.seats[game.engine.current]["tokens"].all(func(p: int) -> bool: return p == 0):
					tutorial.tip("need_six")
			audio.play("dice_land")
			effects.burst(pos, EffectsManager.GOLD, 14, 1.2, 0.6)
			if int(data.get("value", 0)) == 6 and not game.fast_mode:
				hud.flash_banner("SIX!", Color("#ffd24a"), 0.5)
				_announce("six")
				_elephant_salute()
				audio.play("six", 0.0)
				effects.burst(pos + up, EffectsManager.GOLD, 40, 2.8, 0.9)
		"select":
			tutorial.tip("pick")
			audio.play("token_select")
		"hop":
			var walker: Node3D = data.get("token")
			if walker and walker.find_child("DesignGearAura", false, false) and not game.fast_mode:
				var ring := walker.get_node("DesignGearAura") as MeshInstance3D
				var col: Color = ring.material_override.albedo_color
				var trail: Variant = ring.get_meta("trail", false)
				if trail is String and trail == "holi":   # every hop a new colour cloud
					effects.burst(walker.global_position + Vector3(0, 0.3, 0), [Color("#ff2a8a"), Color("#20c0ff"), Color("#ffd020"), Color("#30e070"), Color("#a040ff")].pick_random(), 16, 1.0, 0.7, -0.2)
				elif trail is bool and trail:   # legendary and festival designs leave sparks
					effects.burst(walker.global_position + Vector3(0, 0.3, 0), Color(col, 1.0), 10, 0.8, 0.6, -0.3)
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
				tutorial.tip("capture")
		"swing":
			audio.play("swish", 0.1, 0.0 if data.get("heavy", false) else -5.0)
		"jab":
			audio.play("punch", 0.08, -5.0)
			effects.hit_spark(pos, false)
			_shake(0.03, 0.12)
			audio.vibrate(12)
		"impact":
			if data.get("big", false) or not data.has("big"):
				hud.impact_frame(camera.unproject_position(pos))
			audio.play(data.get("kind", "punch"), 0.05)
			audio.play("impact", 0.06, -4.0)  ## low boom under the recorded hit
			effects.hit_spark(pos, true)
			effects.burst(pos, EffectsManager.TEAM.get(data.get("color", "red"), EffectsManager.GOLD), 18, 2.2, 0.7)
			audio.vibrate(60)
			hud.flash_banner(["KNOCKOUT!", "BOOM!", "SMASH!"].pick_random(), Color("#ffd24a"))
			_token_says(data.get("victim_token"), "hurt", data.get("color", ""))
			_announce_later("capture_" + game.current_color() if randf() < 0.5 else "capture", 1.4)
		"block":
			audio.vibrate(15)
			audio.play("thud", 0.1, -6.0)
			effects.burst(pos, Color("#bfe3ff"), 18, 2.2, 0.4)
			_shake(0.02, 0.1)
		"whiff":
			audio.play("swish", 0.05, -3.0)
		"faceoff":
			if not game.fast_mode:
				hud.set_skip_hint(true)
		"burst":   # signature finishers: fire, feathers, sunlight, smoke
			effects.burst(pos, data.get("color", EffectsManager.GOLD), int(data.get("amount", 30)), float(data.get("speed", 2.4)), float(data.get("life", 0.8)), float(data.get("gravity", 2.0)))
		"signature":
			hud.flash_banner(tr(data.get("name", "")), Color("#ffd24a"), 0.9)
			audio.play("confirm", 0.0, -2.0)
		"quake":
			effects.shockwave(pos)
			_shake(0.3, 0.5)
		"crash":
			audio.play("thud", 0.05, -2.0)
			effects.dust(pos)
		"spin":
			audio.play("swish", 0.0, -2.0)
		"throw":
			audio.play("swish", 0.08)
		"replay_ready":
			hud.offer_replay()
		"thrown_home":
			hud.set_skip_hint(false)
			audio.play("thud", 0.05)
			effects.burst(pos + Vector3(0, 0.15, 0), EffectsManager.TEAM.get(data.get("color", "red"), EffectsManager.GOLD), 24, 1.6, 0.7)
			effects.shockwave(pos)
			audio.vibrate(25)
		"ladder":
			audio.play("confirm", 0.0, -3.0)
			effects.burst(pos + up, Color("#7cff7a"), 24, 2.0, 0.8, -1.0)
			hud.flash_banner(tr("LADDER!"), Color("#9dff8a"), 0.5)
			_announce("ladder", true)
		"snake":
			audio.play("swish", 0.0, -2.0)
			audio.play("error", 0.0, -8.0)
			effects.burst(pos + up, Color("#3fae4a"), 24, 1.6, 0.8)
			hud.flash_banner(tr("SNAKE!"), Color("#ff7a7a"), 0.5)
			_announce("snake", true)
		"powerup":
			audio.play("shield" if data.get("type") == "shield" else "coins", 0.02)
			effects.burst(pos + up, Color("#4fc3ff") if data.get("type") == "shield" else EffectsManager.GOLD, 40, 2.4, 0.9)
			hud.flash_banner(tr("SHIELD!") if data.get("type") == "shield" else tr("EXTRA ROLL!"), Color("#9fd8ff") if data.get("type") == "shield" else Color("#ffd24a"), 0.6)
			_announce("shield" if data.get("type") == "shield" else "star", true)
		"leave_yard":
			tutorial.tip("six")
			audio.vibrate(20)
			effects.burst(pos + Vector3(0, 0.1, 0), Color("#ff6f91"), 26, 1.8, 0.9, 2.0)
			effects.burst(pos + Vector3(0, 0.1, 0), Color("#ffb347"), 16, 1.5, 0.9, 2.0)
			audio.play("token_land", 0.05)
		"high_five":
			effects.burst(pos + Vector3(0, 0.9, 0), EffectsManager.GOLD, 16, 1.4, 0.5)
			audio.play("punch", 0.2, -12.0)
		"finish":
			tutorial.tip("home")
			_dome_fireworks()
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
			tutorial.finish()
			var won: bool = not (data.get("ranking", []) as Array).is_empty() and data["ranking"][0]["human"]
			var any_human: bool = (data.get("ranking", []) as Array).any(func(r: Dictionary) -> bool: return r["human"])
			var team_game: bool = not (data.get("ranking", []) as Array).is_empty() and int(data["ranking"][0].get("team", -1)) >= 0
			if team_game:
				for r in data["ranking"]:
					if r["human"]:
						won = int(r["team"]) == int(data["ranking"][0]["team"])
			if any_human:
				_announce_later(("team_win" if team_game else "win") if won else "lose", 0.6)
				if won:
					audio.vibrate_pattern([40, 80, 40, 80, 140])
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


func _process(delta: float) -> void:
	_update_dice_holder(delta)


func _log_message(text: String) -> void:
	if _demo:
		print("[game] " + text)


const COIN_REWARD := [100, 50, 25, 10]


func _on_game_finished(ranking: Array) -> void:
	var reward := 0
	for entry in ranking:
		if entry["human"]:
			var place := int(entry["place"])
			if int(entry.get("team", -1)) >= 0:
				place = 1 if int(entry["team"]) == int(ranking[0]["team"]) else 3
			reward = maxi(reward, COIN_REWARD[mini(place - 1, 3)])
	reward *= Festivals.coin_multiplier()
	var total := GameSettings.add_coins(reward) if reward > 0 and not _demo else GameSettings.get_coins()
	var unlocked: Array = []
	var humans := ranking.filter(func(r: Dictionary) -> bool: return r["human"])
	if humans.size() == 1 and not _demo:
		var t: Dictionary = game.tally.duplicate()
		t["won"] = int(humans[0]["place"]) == 1 or (int(humans[0].get("team", -1)) >= 0 and int(humans[0]["team"]) == int(ranking[0]["team"]))
		t["place"] = humans[0]["place"]
		t["difficulty"] = game.difficulty
		t["team"] = int(humans[0].get("team", -1)) >= 0
		unlocked = Progress.record_game(t)
		for cid in Festivals.record(t):
			unlocked.append("challenge:" + cid)
		if _last_config.get("mode", "") == "campaign":
			unlocked.append_array(Campaign.finish(int(_last_config["chapter"]), t["won"]))
		## Collection rewards: shards towards a design, mastery for the one worn.
		var sh := Progress.add_shards(3 if t["won"] else 1)
		if not sh.is_empty():
			unlocked.append("shards:%s:%d:%d:%d" % [sh[0], sh[1], sh[2], 1 if sh[3] else 0])
		var worn := Progress.equipped("design")
		if Progress.add_design_game(worn):
			unlocked.append("mastery:%s:%d" % [worn, Progress.mastery_level(worn)])
		for set_id in Progress.check_sets():
			unlocked.append("set:" + set_id)
		var lv := Progress.add_game_xp(t)
		hud.xp_info = lv
		total = Progress.coins()
	_celebrate(ranking)
	## Let the 3D celebration play before the results panel slides in.
	if not _demo:
		await get_tree().create_timer(2.2).timeout
	hud.show_result(ranking, reward, total, unlocked)
	if _demo and not _demo_done:
		_demo_done = true
		print("DEMO RESULT: " + str(ranking))
		get_tree().quit(0)


## Golden sparks streaming behind the dice while it tumbles towards a six.
func _dice_trail(seconds: float, style := "trail_gold") -> void:
	var model: Node3D = game.dice.get_node("DiceModel")
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	var colors := {"trail_gold": [EffectsManager.GOLD], "trail_petals": [Color("#ff5f86"), Color("#ffa040")], "trail_stars": [Color("#bfe3ff"), Color.WHITE]}
	var list: Array = colors.get(style, colors["trail_gold"])
	while Time.get_ticks_msec() < end and is_instance_valid(model):
		effects.burst(model.global_position, list.pick_random(), 6, 0.6, 0.5, 0.5 if style != "trail_petals" else -0.3)
		await get_tree().create_timer(0.06, true, false, true).timeout


## On a six the elephant rears up and lifts its head, then settles.
func _elephant_salute() -> void:
	var e: Node3D = _decor.get("elephant")
	if e == null:
		return
	var base_rot := e.rotation
	var t := e.create_tween()
	t.tween_property(e, "rotation:z", base_rot.z + 0.22, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(e, "position:y", e.position.y + 0.15, 0.35)
	t.tween_interval(0.25)
	t.tween_property(e, "rotation:z", base_rot.z, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(e, "position:y", e.position.y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## On a win the peacock struts: a turn and a few proud hops.
func _peacock_dance() -> void:
	var p: Node3D = _decor.get("peacock")
	if p == null:
		return
	var y := p.position.y
	var t := p.create_tween()
	for i in range(4):
		t.tween_property(p, "position:y", y + 0.25, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "rotation:y", p.rotation.y + PI * 0.5 * (i + 1), 0.36)
		t.tween_property(p, "position:y", y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	effects.burst(p.global_position + Vector3(0, 1.5, 0), Color("#29b6a6"), 40, 2.5, 1.2)


## Victory effects from the shop.
func _gold_rain(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		effects.burst(Vector3(randf_range(-7, 7), 6.0, randf_range(-6, 6)), EffectsManager.GOLD, 14, 0.5, 2.0, 3.0)
		await get_tree().create_timer(0.08).timeout


func _lotus_bloom() -> void:
	for ring in range(3):
		for i in range(12):
			var a := TAU * i / 12.0 + ring * 0.26
			var at := Vector3(cos(a), 0.0, sin(a)) * (0.8 + ring * 0.9) + Vector3(0, 0.4, 0)
			effects.burst(at, [Color("#ff7fb0"), Color("#ffd1e3"), EffectsManager.GOLD][ring], 10, 1.4, 1.2, -0.5)
		await get_tree().create_timer(0.25).timeout


## A token home: each chhatri dome launches a firework.
func _dome_fireworks() -> void:
	if game.fast_mode:
		return
	for color in BoardPath.COLORS:
		var home: Vector2i = BoardPath.PLAYERS[color]["home"]
		var c := BoardPath.to_world(home.x + 3, home.y + 3)
		var at := Vector3(c.x, 2.4, c.z)
		effects.burst(at, EffectsManager.TEAM[color], 30, 3.0, 1.0, 2.5)
		effects.burst(at, EffectsManager.GOLD, 18, 2.2, 0.8, 2.5)
		await get_tree().create_timer(0.12).timeout


## Replay: the game waits (timer paused, input blocked) while the fight plays again.
func _play_replay() -> void:
	if game.replay.playing or not game.replay.has_replay():
		return
	hud.hide_replay()
	var was_busy := game.busy
	game.busy = true
	var timer_was := game.timer_active
	game.timer_active = false
	hud.flash_banner(tr("REPLAY"), Color("#9fd8ff"), 0.6)
	_announce("replay", true)
	await game.replay.play(0.5)
	game.busy = was_busy
	game.timer_active = timer_was
	hud.offer_replay(4.0)


func _on_replay_cue(cue_name: String, data: Dictionary) -> void:
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	match cue_name:
		"impact":
			hud.impact_frame(camera.unproject_position(pos))
			audio.play(data.get("kind", "punch"), 0.05)
			effects.hit_spark(pos, true)
		"jab":
			audio.play("punch", 0.08, -5.0)
			effects.hit_spark(pos, false)
		"block":
			audio.play("thud", 0.1, -6.0)
		"crash":
			audio.play("thud", 0.05, -2.0)
			effects.dust(pos)
		"swing", "whiff":
			audio.play("swish", 0.1, -4.0)


## Saves the current frame as a photo (Pictures/RoyalIndiaLudo on the phone, or the
## game's own folder when the gallery is not writable).
func _save_photo() -> void:
	hud.hide_replay()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dirs := [OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("RoyalIndiaLudo"), OS.get_user_data_dir().path_join("photos")]
	for d in dirs:
		if d == "" or DirAccess.make_dir_recursive_absolute(d) != OK and not DirAccess.dir_exists_absolute(d):
			continue
		var path: String = d.path_join("fight_%s.png" % stamp)
		if img.save_png(path) == OK:
			hud.set_message(tr("Photo saved"))
			audio.play("confirm", 0.0, -4.0)
			return
	hud.set_message(tr("Could not save the photo"))


## Winner's tokens gather in the centre and dance: camera closes in, hops and spins.
func _celebrate(ranking: Array) -> void:
	if _demo or ranking.is_empty():
		return
	var color: String = ranking[0]["color"]
	if not game.tokens.has(color):
		return
	director.focus(Vector3(0, 0.3, 0), 1.2, 0.45)
	_peacock_dance()
	game.dice.visible = false   # clear the centre for the dance
	match Progress.equipped("victory"):
		"victory_goldrain":
			_gold_rain(4.0)
		"victory_lotus":
			_lotus_bloom()
	var design: String = TokenDesigns.parse(game.design_for(color))[0]
	var pose: String = TokenDesigns.POSES.get(design, "dance")
	for i in range(BoardPath.TOKENS_PER_PLAYER):
		var token: TransformerToken = game.tokens[color][i]
		token.transform_out(0.2)
		_dance(token, i * 0.15, pose)
	## The winner's design says its own line, with a speech bubble.
	if voice and voice.has_design_line(design):
		await get_tree().create_timer(0.9).timeout
		var caption := voice.design_line(design)
		if caption != "" and is_instance_valid(game.tokens[color][0]):
			bubbles.say(game.tokens[color][0], caption, color)


func _dance(token: TransformerToken, delay: float, pose := "dance") -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(token):
		RoboPawn.celebrate(token)
	if pose != "dance":
		await _victory_pose(token, pose)
	for n in range(6 if pose == "dance" else 3):
		if not is_instance_valid(token):
			return
		var t := token.create_tween().set_parallel(true)
		t.tween_property(token.body_node, "position:y", 0.3, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(token, "rotation:y", token.rotation.y + PI, 0.36)
		for side in ["L", "R"]:
			var arm: Dictionary = token.arm_pivots[side]
			t.tween_property(arm["shoulder"], "rotation", Vector3(-2.8, 0, 0.5 if side == "L" else -0.5), 0.18)
		t.chain().tween_property(token.body_node, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished


## A design's own victory pose, played before the dance.
func _victory_pose(token: TransformerToken, pose: String) -> void:
	if not is_instance_valid(token):
		return
	RoboPawn.celebrate(token)   # robots: ears spin, the fan spreads, fins rise
	var arms: Dictionary = token.arm_pivots
	match pose:
		"raise":   # weapon arm thrust high, other fist on the hip, three proud stamps
			var t := token.create_tween().set_parallel(true)
			t.tween_property(arms["R"]["shoulder"], "rotation", Vector3(-3.0, 0, -0.25), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(arms["R"]["elbow"], "rotation", Vector3(-0.2, 0, 0), 0.25)
			t.tween_property(arms["L"]["shoulder"], "rotation", Vector3(-0.3, 0, 0.9), 0.25)
			t.tween_property(arms["L"]["elbow"], "rotation", Vector3(-1.6, 0, 0), 0.25)
			await t.finished
			for i in range(3):
				var s := token.create_tween()
				s.tween_property(token.body_node, "position:y", 0.12, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				s.tween_property(token.body_node, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await s.finished
		"whirl":   # rises and whirls twice in the air, arms spread like wings
			var t := token.create_tween().set_parallel(true)
			for side in ["L", "R"]:
				t.tween_property(arms[side]["shoulder"], "rotation", Vector3(-1.5, 0, 1.3 if side == "L" else -1.3), 0.3)
			t.tween_property(token.body_node, "position:y", 0.7, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(token, "rotation:y", token.rotation.y + TAU * 2.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.chain().tween_property(token.body_node, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			await t.finished
		"bow":   # a royal bow to the court, then arms open wide
			var t := token.create_tween()
			t.tween_property(token.body_node, "rotation:x", 0.45, 0.35).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(arms["R"]["shoulder"], "rotation", Vector3(-1.2, 0, 0.6), 0.35)
			t.tween_interval(0.35)
			t.tween_property(token.body_node, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(arms["R"]["shoulder"], "rotation", Vector3(-2.4, 0, -0.9), 0.3)
			t.parallel().tween_property(arms["L"]["shoulder"], "rotation", Vector3(-2.4, 0, 0.9), 0.3)
			await t.finished


## Tilted perspective camera. The camera distance is chosen so the whole board spans
## the screen width (or height, whichever is the limit), so it fills the phone screen.
func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "BoardCamera"
	director = CameraDirector.new()
	director.process_mode = Node.PROCESS_MODE_ALWAYS   # the title-screen orbit runs while a game waits paused
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


var _holder_rim: StandardMaterial3D
var _holder_pulse := false
var _holder_time := 0.0


## Gold dish on a stem under the dice. Its rim glows in the current player's colour
## and pulses while a human may roll.
func _build_dice_holder() -> void:
	var root := Node3D.new()
	root.name = "DiceHolder"
	root.position = Vector3(0, RoyalBoard.CENTRE_TOP, 0)
	add_child(root)
	var gold := RoyalBoard.metal(BoardThemes.current()["gold"], 0.22)
	var stem := Monuments.lathe(Monuments.smooth_profile(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.2, 0.04), Vector2(0.09, 0.1), Vector2(0.07, 0.22),
		Vector2(0.12, 0.27), Vector2(0.55, 0.36), Vector2(0.7, 0.42), Vector2(0.66, 0.44), Vector2(0.0, 0.4)]), 6), 96)
	var m := MeshInstance3D.new()
	m.mesh = stem
	m.material_override = gold
	root.add_child(m)
	_holder_rim = StandardMaterial3D.new()
	_holder_rim.albedo_color = Color("#ffe6a0")
	_holder_rim.emission_enabled = true
	_holder_rim.emission = Color("#ffcc55")
	_holder_rim.emission_energy_multiplier = 1.5
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.64
	torus.outer_radius = 0.72
	torus.rings = 96
	torus.ring_segments = 16
	rim.mesh = torus
	rim.material_override = _holder_rim
	rim.position.y = 0.43
	rim.scale = Vector3(1, 0.6, 1)
	root.add_child(rim)
	for i in range(8):
		var a := TAU * i / 8.0
		var gem := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.05
		sphere.height = 0.1
		gem.mesh = sphere
		gem.material_override = RoyalBoard.gem_material(Color("#c0182c"))
		gem.position = Vector3(cos(a) * 0.5, 0.36, sin(a) * 0.5)
		root.add_child(gem)


func _update_dice_holder(delta: float) -> void:
	if _holder_rim == null or game == null or game.engine == null or game.engine.seats.is_empty():
		return
	_holder_time += delta
	var color: Color = RoyalBoard.PALETTE.get(game.current_color(), Color("#ffcc55"))
	_holder_rim.emission = _holder_rim.emission.lerp(color.lightened(0.25), minf(1.0, delta * 4.0))
	var pulse := game.dice.rollable
	_holder_rim.emission_energy_multiplier = (2.0 + 2.5 * absf(sin(_holder_time * 4.0))) if pulse else 1.2


func _build_dice() -> DiceController:
	var dice := DiceController.new()
	dice.name = "Dice"
	dice.position = DICE_POSITION
	## Custom royal dice (the supplied dice model renders black on the phone renderer
	## after some rolls).
	var model := RoyalDice.build(Progress.equipped("dice"))
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
		hdri.energy_multiplier = 0.55
		sky.sky_material = hdri
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(theme["ambient"]) * 0.5
	env.ambient_light_sky_contribution = 0.7   ## less pale sky light in the shadows
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.tonemap_white = 6.0
	## Glow (bloom) is supported by the Mobile renderer, with its lower HDR range.
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.6   ## only gems and lamps glow, not the whole board
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
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
	env.adjustment_contrast = 1.08
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = float(theme["sun_energy"]) * 0.85
	sun.light_color = theme["sun"]
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.shadow_enabled = true
	## Late-afternoon sun: lower and warmer, so domes, trees and tokens cast long, soft
	## shadows that show their shape. Four cascades keep near shadows sharp.
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = (theme["sun"] as Color).lerp(Color("#ffc98a"), 0.35)
	sun.shadow_blur = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 1.5   ## soft penumbra like a real sun disc
	add_child(sun)
	## Cool fill from the opposite side, so shadows are not black.
	var fill := DirectionalLight3D.new()
	fill.light_energy = float(theme["fill_energy"]) * 1.3   ## cool sky fill opens the shadows
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
	## A tap during a fight skips the rest of it.
	if game.fight and game.fight._active:
		game.fight.skip()
		hud.set_skip_hint(false)
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
	if _has_arg("--finisher="):
		game.fight.forced_finisher = _arg_value(OS.get_cmdline_user_args(), "--finisher")
	if _has_arg("--exchange="):
		game.fight.forced_exchange = _arg_value(OS.get_cmdline_user_args(), "--exchange")
	e.roll_with_value(3)
	await game._execute(mover)
	var sent_home: bool = e.seats[1]["tokens"][0] == 0
	if "--replay" in OS.get_cmdline_user_args():
		var a_before: Vector3 = game.tokens["blue"][mover].global_position
		var v_before: Vector3 = game.tokens["green"][0].global_position
		var frames := game.replay._frames.size()
		await _play_replay()
		var restored: bool = game.tokens["blue"][mover].global_position.distance_to(a_before) < 0.01 \
			and game.tokens["green"][0].global_position.distance_to(v_before) < 0.01
		print("replay test: frames=%d restored=%s" % [frames, str(restored)])
		sent_home = sent_home and restored and frames > 10
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


## Recording helper: a six (trail, slow motion), a token leaping out, idle life. Counts
## frames, not wall time, so it works with the movie writer.
func _run_showcase() -> void:
	for i in range(45):
		await get_tree().process_frame
	game.forced_roll = int(_arg_value(OS.get_cmdline_user_args(), "--roll")) if _has_arg("--roll=") else 6
	if "--no-fx" in OS.get_cmdline_user_args():
		effects.visible = false
	game._roll_now()
	var n := 0
	while not game.awaiting_pick and n < 400:
		await get_tree().process_frame
		n += 1
	if game.awaiting_pick:
		game.tap_token("blue", 0)
	for i in range(150):
		await get_tree().process_frame
		if i % 30 == 0 and "--probe" in OS.get_cmdline_user_args():
			var m: Node3D = game.dice.get_node("DiceModel")
			print("PROBE basis det=%s scale=%s rot=%s gscale=%s" % [m.global_basis.determinant(), m.scale, m.rotation_degrees, m.global_basis.get_scale()])
	print("SHOWCASE DONE")
	get_tree().quit()


## Ends a staged game (you first) and saves a screenshot of the celebration and results.
func _run_result_shot(path: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	game.new_game(["blue", "yellow", "green", "red"] as Array[String], ["blue"] as Array[String], GameSettings.get_rules(), 1)
	game.engine.seats[0]["tokens"] = [57, 57, 57, 57]
	game.engine.seats[2]["tokens"] = [57, 57, 40, 12]
	_place_tokens_from_engine()
	var ranking := [{"place": 1, "color": "blue", "human": true}, {"place": 2, "color": "green", "human": false},
		{"place": 3, "color": "yellow", "human": false}, {"place": 4, "color": "red", "human": false}]
	game.event.emit("game_over", {"ranking": ranking})
	_on_game_finished(ranking)
	await get_tree().create_timer(float(_arg_value(OS.get_cmdline_user_args(), "--shot-delay")) if _has_arg("--shot-delay") else 5.0).timeout
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
	if "--no-ui" in OS.get_cmdline_user_args():
		hud.visible = false
		for c in get_children():
			if c is CanvasLayer and c != hud:
				(c as CanvasLayer).visible = false
	## Optional test camera: --cam=x,y,z,tx,ty,tz (position, then look-at target).
	if _has_arg("--cam="):
		var v := _arg_value(OS.get_cmdline_user_args(), "--cam").split(",")
		if v.size() == 6:
			director.set_process(false)
			camera.look_at_from_position(Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3(float(v[3]), float(v[4]), float(v[5])), Vector3.UP)
	if "--lineup" in OS.get_cmdline_user_args():
		## The four characters side by side in the centre, facing the camera.
		game.visible = false
		game.dice.visible = false
		var cols := ["green", "red", "blue", "yellow"]
		for i in range(cols.size()):
			var t := TransformerToken.new()
			add_child(t)
			t.configure(cols[i])
			t.position = Vector3(-1.65 + i * 1.1, RoyalBoard.TILE_TOP + 0.05, 0.4)
			t.scale = Vector3.ONE * 1.25
			if "--transformed" in OS.get_cmdline_user_args():
				t.transform_out(0.01)
			if _has_arg("--lineup-designs="):   # dress the four in chosen token designs
				var ds := _arg_value(OS.get_cmdline_user_args(), "--lineup-designs").split(",")
				if i < ds.size() and ds[i] != "":
					TokenDesigns.apply(t, ds[i], RoyalBoard.PALETTE[cols[i]])
			if "--celebrate" in OS.get_cmdline_user_args():
				get_tree().create_timer(2.0 + i * 0.25).timeout.connect(func() -> void: RoboPawn.celebrate(t))
	if "--design-gallery" in OS.get_cmdline_user_args():
		## All designs in a grid on the board (game tokens hidden), for checking them.
		game.visible = false
		var ids := TokenDesigns.DESIGNS.keys()
		var colors := ["blue", "yellow", "green", "red"]
		for i in range(ids.size()):
			var t := TransformerToken.new()
			add_child(t)
			t.configure(colors[i % 4])
			t.transform_out(0.01)
			var per_row := 7
			t.position = Vector3(-3.0 + (i % per_row) * 1.2, RoyalBoard.TILE_TOP, -3.6 + (i / per_row) * 2.0)
			t.scale = Vector3.ONE * 0.95
			TokenDesigns.apply(t, "%s|gold|rarity|%d" % [ids[i], i % 4], RoyalBoard.PALETTE[colors[i % 4]])   # mastery 0-3 too
	if "--statues" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		_elephant_salute()
		_peacock_dance()
	## Wait in real time, so effects that run for seconds are still on screen.
	await get_tree().create_timer(float(_arg_value(OS.get_cmdline_user_args(), "--shot-delay")) if _has_arg("--shot-delay") else 1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
	get_tree().quit()
