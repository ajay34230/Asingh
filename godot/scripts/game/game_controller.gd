## Game flow. The RulesEngine decides every outcome; this node only sequences the
## presentation (dice, token hops, captures, finishing) and reads the player's input.
##
## Turn flow: roll (engine decides) -> show the dice -> choose a move (tap for the
## human, heuristic for AI) -> apply in the engine -> animate -> next turn.
class_name GameController
extends Node3D

signal turn_changed(color: String, human: bool)
signal message(text: String)
signal game_finished(rankings: Array)
## Presentation cues for sound and effects. The data is read-only; nothing here changes state.
signal event(event_name: String, data: Dictionary)

const TOKEN_SCALE := 0.95
const TRACK_Y := 0.12          ## top of the track tiles (RoyalBoard.TILE_TOP)
const BASE_Y := 0.15           ## courtyard pedestals (RoyalBoard.PEDESTAL_TOP)
const HOP_SECONDS := 0.2
const AI_DELAY := 0.6
const TOKEN_PICK_RADIUS := 0.55

var engine := RulesEngine.new()
var human_colors: Array[String] = ["blue"]
var tokens: Dictionary = {}     ## colour -> Array[TransformerToken]
var dice: DiceController
var busy := false
var awaiting_pick := false
var _legal: Array[int] = []
var _seed := 0
var fast_mode := false          ## set by the demo run: no delays

func setup(dice_node: DiceController, seed_value: int = 0) -> void:
	dice = dice_node
	_seed = seed_value
	fight = FightChoreography.new()
	fight.name = "Fight"
	add_child(fight)
	fight.cue.connect(_on_fight_cue)
	replay = FightReplay.new()
	replay.name = "Replay"
	add_child(replay)
	life = TokenLife.new()
	life.name = "TokenLife"
	life.game = self
	add_child(life)
	dice.roll_requested.connect(_on_roll_requested)

var difficulty := 1            ## AiController.Difficulty
var fight: FightChoreography
var life: TokenLife
var replay: FightReplay
var specials: SpecialSquares
var blitz := false
var relaxed := false
var net: NetPlay   ## set by the main scene   ## accessibility: slower AI turns   ## set by the main scene for snakes / power-up games
var forced_roll := -1   ## test/showcase only: the next roll's value
var _moving_index := 0
var preview: MovePreview        ## set by the main scene; shows where legal moves land
var director: CameraDirector    ## set by the main scene; frames the action
var anim_scale := 1.0
## Turn timer for human players: when it runs out the game rolls or moves for them
## (the best move, as Ludo apps do). 0 turns it off.
var turn_seconds := 20.0
var timer_left := 0.0
var timer_active := false
signal turn_timer(left: float, total: float)         ## 1.0 normal; >1 slower, <1 faster

func new_game(seat_colors: Array[String] = ["blue", "yellow", "green", "red"], humans: Array[String] = ["blue"], rules: Dictionary = {}, ai_difficulty: int = 1) -> void:
	human_colors = humans
	difficulty = ai_difficulty
	var seats: Array = []
	for color in seat_colors:
		seats.append({"color": color, "human": humans.has(color)})
	engine.setup(seats, _seed, rules)
	tally = {"captures": 0, "lost": 0, "home": 0, "sixes": 0}
	_spawn_tokens(seat_colors)
	set_shape_markers(bool(GameSettings.get_option("colorblind")))
	if specials:
		for c in specials.get_children():
			c.queue_free()
		if engine.rules["snakes"]:
			specials.build_jumps()
		specials._orbs.clear()
		specials.sync_powerups(engine.powerups)
	blitz = engine.rules["blitz"]
	busy = false
	awaiting_pick = false
	message.emit("New game")
	_start_turn()

func _spawn_tokens(seat_colors: Array[String]) -> void:
	for child in get_children():
		if child is TransformerToken:
			child.queue_free()
	tokens.clear()
	for color in seat_colors:
		var list: Array = []
		for i in range(BoardPath.TOKENS_PER_PLAYER):
			var token := TransformerToken.new()
			token.name = "%s_%d" % [color, i]
			add_child(token)
			token.configure(color)
			if humans_skin(color):
				_apply_token_skin(token, Progress.equipped("tokens"))
			token.scale = Vector3.ONE * TOKEN_SCALE
			token.add_child(_contact_shadow())
			var vfx := RoyalTokenVFX.new()
			token.add_child(vfx)
			token.set_meta("vfx", vfx)
			token.set_meta("index", i)
			token.set_meta("color", color)
			token.position = _base_world(color, i)
			token.ground_y = token.position.y
			list.append(token)
		tokens[color] = list

static var _shadow_mat: StandardMaterial3D


## Soft dark disc under a token, so it sits on the board instead of floating above it
## (stands in for ambient occlusion, which the Mobile renderer does not have).
func _contact_shadow() -> MeshInstance3D:
	if _shadow_mat == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in range(size):
			for x in range(size):
				var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
				img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d, 0.0, 1.0) ** 1.6 * 0.6))
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_texture = ImageTexture.create_from_image(img)
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var m := MeshInstance3D.new()
	m.name = "ContactShadow"
	m.mesh = quad
	m.material_override = _shadow_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 0.006, 0)
	return m


## Token skins dress only the (first) human player's tokens.
func humans_skin(color: String) -> bool:
	return not human_colors.is_empty() and human_colors[0] == color


static var _skin_mats := {}


func _apply_token_skin(token: TransformerToken, skin: String) -> void:
	if skin == "tokens_classic" or skin == "":
		return
	if not _skin_mats.has(skin):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 1.0
		match skin:
			"tokens_gold":
				m.albedo_color = Color(1.0, 0.78, 0.3, 0.55)
				m.roughness = 0.25
			"tokens_silver":
				m.albedo_color = Color(0.85, 0.88, 0.95, 0.5)
				m.roughness = 0.2
			"tokens_crystal":
				m.albedo_color = Color(0.75, 0.9, 1.0, 0.35)
				m.metallic = 0.2
				m.roughness = 0.02
				m.emission_enabled = true
				m.emission = Color(0.4, 0.7, 1.0)
				m.emission_energy_multiplier = 0.6
		_skin_mats[skin] = m
	for mesh in token.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = _skin_mats[skin]


## Per-game tally for the human player (rewards and achievements).
var tally := {"captures": 0, "lost": 0, "home": 0, "sixes": 0}


## Colour-blind markers: a gold-rimmed shape floats above each token (blue circle,
## yellow triangle, green square, red diamond), so colours never need telling apart.
func set_shape_markers(on: bool) -> void:
	for color in tokens:
		for token in tokens[color]:
			var old: Node = (token as Node3D).get_node_or_null("ShapeMarker")
			if old:
				old.queue_free()
			if on:
				(token as Node3D).add_child(_shape_marker(color))


static func _shape_marker(color: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ShapeMarker"
	root.position = Vector3(0, 1.3, 0)
	root.scale = Vector3.ONE * 2.2
	var mesh: Mesh
	match color:
		"blue":
			var c := CylinderMesh.new()
			c.top_radius = 0.13
			c.bottom_radius = 0.13
			c.height = 0.05
			c.radial_segments = 32
			mesh = c
		"yellow":
			var t := CylinderMesh.new()
			t.top_radius = 0.16
			t.bottom_radius = 0.16
			t.height = 0.05
			t.radial_segments = 3
			mesh = t
		"green":
			var b := BoxMesh.new()
			b.size = Vector3(0.22, 0.05, 0.22)
			mesh = b
		_:
			var d := BoxMesh.new()
			d.size = Vector3(0.2, 0.05, 0.2)
			mesh = d
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 1.2
	m.material_override = mat
	if color == "red":
		m.rotation.y = PI / 4.0
	m.rotation.x = PI * 0.5 - 0.6   # tilted towards the camera
	root.add_child(m)
	return root


func current_color() -> String:
	return engine.current_seat()["color"]

func is_human_turn() -> bool:
	return engine.current_seat()["human"]

func _start_turn() -> void:
	if engine.phase == RulesEngine.PHASE_OVER:
		_finish_game()
		return
	turn_changed.emit(current_color(), is_human_turn())
	if director and not fast_mode:
		_glance(current_color())
	if net and net.active:
		## Network game: only this phone's own seat takes input; the host plays the AI.
		dice.set_rollable(net.is_local(current_color()))
		if net.is_local(current_color()):
			message.emit(tr("Your turn: tap the dice"))
		elif net.is_ai(current_color()):
			message.emit(tr("%s is rolling") % AiController.PERSONAS[current_color()]["name"])
			if net.is_host:
				if not fast_mode:
					await get_tree().create_timer(AI_DELAY).timeout
				net.ai_roll()
		else:
			message.emit(tr("Waiting for %s") % current_color().capitalize())
		return
	if is_human_turn():
		message.emit(tr("Your turn: tap the dice"))
		dice.set_rollable(true)
		_start_timer()
	else:
		message.emit(tr("%s is rolling") % AiController.PERSONAS.get(current_color(), {"name": current_color().capitalize()})["name"])
		dice.set_rollable(false)
		if not fast_mode:
			await get_tree().create_timer(AI_DELAY * (0.35 if blitz else (2.2 if relaxed else 1.0))).timeout
		_roll_now()

func _on_roll_requested() -> void:
	if busy or not is_human_turn() or engine.phase != RulesEngine.PHASE_ROLL:
		return
	if net and net.active:
		if net.is_local(current_color()):
			dice.set_rollable(false)
			net.request_roll()
		return
	_roll_now()

func _roll_now() -> void:
	if busy or engine.phase != RulesEngine.PHASE_ROLL:
		return
	_stop_timer()
	busy = true
	dice.set_rollable(false)
	var thrower := current_color()   ## read first: a roll with no move passes the turn
	var outcome := engine.roll_with_value(forced_roll) if forced_roll > 0 else engine.roll()   ## the engine decides; the dice only shows it
	forced_roll = -1
	if outcome["value"] == 6 and humans_skin(thrower):
		tally["sixes"] += 1
	event.emit("roll_start", {"position": dice.global_position, "value": outcome["value"]})
	if outcome["value"] == 6 and not fast_mode:
		_six_slow_motion()
	await dice.roll_to(outcome["value"], Vector3.ZERO if fast_mode else _throw_offset(thrower))
	event.emit("roll_land", {"position": dice.global_position, "value": outcome["value"]})
	if outcome["forfeited"]:
		message.emit("Three sixes: turn lost")
		event.emit("three_sixes", {})
	elif outcome["passed"]:
		message.emit("No legal move")
		event.emit("no_move", {"human": is_human_turn()})
	if outcome["passed"] or outcome["forfeited"]:
		busy = false
		_start_turn()
		return
	_legal = outcome["moves"]
	if net and net.active:
		## Single choices play themselves on every phone; other choices arrive as actions.
		if _legal.size() == 1 and not net.is_ai(current_color()):
			await _execute(_legal[0])
			return
		if net.is_local(current_color()):
			awaiting_pick = true
			_highlight(true)
			message.emit(tr("Tap a glowing token"))
		elif net.is_ai(current_color()) and net.is_host:
			var pick := AiController.choose_move(engine, _legal, difficulty)
			if not fast_mode:
				await get_tree().create_timer(AI_DELAY * 0.6).timeout
			net.ai_pick(pick)
		busy = false
		return
	if is_human_turn():
		if _legal.size() == 1:
			await _execute(_legal[0])
		else:
			awaiting_pick = true
			_highlight(true)
			_start_timer()
			message.emit(tr("Tap a glowing token"))
			busy = false
	else:
		var choice := AiController.choose_move(engine, _legal, difficulty)
		if not fast_mode:
			await get_tree().create_timer(AI_DELAY * 0.6).timeout
		await _execute(choice)

## Where the dice is thrown from: the edge of the board nearest the player's courtyard.
func _throw_offset(color: String) -> Vector3:
	var home: Vector2i = BoardPath.PLAYERS[color]["home"]
	var c := BoardPath.to_world(home.x + 3, home.y + 3)
	var dir := Vector3(c.x, 0, c.z).normalized()
	return dir * 4.2 + Vector3(0, 0.9, 0)


func _start_timer() -> void:
	if net and net.active:
		return
	if fast_mode or (turn_seconds <= 0.0 and not blitz):
		return
	timer_left = 8.0 if blitz else turn_seconds
	timer_active = true


func _stop_timer() -> void:
	timer_active = false
	turn_timer.emit(0.0, 0.0)


func _process(delta: float) -> void:
	if not timer_active:
		return
	timer_left -= delta
	turn_timer.emit(maxf(timer_left, 0.0), 8.0 if blitz else turn_seconds)
	if timer_left > 0.0:
		return
	timer_active = false
	turn_timer.emit(0.0, 0.0)
	## Time is up: play for the human.
	if awaiting_pick and not busy:
		var choice := AiController.choose_move(engine, _legal, 2)
		awaiting_pick = false
		_highlight(false)
		message.emit("Time up: auto move")
		_execute(choice)
	elif is_human_turn() and engine.phase == RulesEngine.PHASE_ROLL and not busy:
		message.emit("Time up: auto roll")
		_roll_now()


## Called by the input layer when a token is tapped.
func tap_token(color: String, index: int) -> void:
	if not awaiting_pick or busy or color != current_color():
		return
	if not _legal.has(index):
		event.emit("invalid", {})
		return
	awaiting_pick = false
	_stop_timer()
	_highlight(false)
	event.emit("click", {})
	if net and net.active:
		net.request_pick(color, index)
		return
	_execute(index)


## Network games: a move confirmed by the host.
func net_execute(index: int) -> void:
	awaiting_pick = false
	_highlight(false)
	_execute(index)

func _execute(token_index: int) -> void:
	busy = true
	var move := engine.apply_move(token_index)
	await _animate_move(move)
	busy = false
	_start_turn()

func _animate_move(move: Dictionary) -> void:
	var color: String = engine.seats[move["seat"]]["color"]
	var index: int = move["token"]
	_moving_index = index
	var token: TransformerToken = tokens[color][index]
	var from: int = move["from"]
	var to: int = move["to"]
	await token.transform_out(0.2)
	if director and not fast_mode:
		director.focus(token.global_position, 0.35)
	## Walk square by square: the limb cycle runs alongside each hop. With a capture, the
	## attacker stops just short of the victim's square and squares up to fight.
	var fighting: bool = not move["captured"].is_empty() and not fast_mode
	var walk_to: int = to if int(move.get("slide_from", -1)) < 0 else int(move["slide_from"])
	var last := walk_to - 1 if fighting and walk_to == to else walk_to
	var first := from + 1 if from > 0 else 1
	if from == 0 and not fast_mode:
		## Leaving the courtyard: a leap in an arc onto the start square.
		var start_point := _track_world(color, 1, index)
		await _leap(token, start_point)
		event.emit("leave_yard", {"position": start_point, "color": color})
		first = 2
	for progress in range(first, last + 1):
		var step_point := _track_world(color, progress, index)
		token.ground_y = step_point.y
		event.emit("hop", {"position": token.global_position})
		if not fast_mode:
			token.play_walk(_hop() * 0.9)
		await token.move_to_world(step_point, _hop())
	if int(move.get("slide_from", -1)) >= 0:
		await _slide(token, color, index, int(move["slide_from"]), to, fighting)
	var landing := _track_world(color, to, index)
	if fighting:
		var approach := landing + (token.global_position - landing).normalized() * 0.74
		approach.y = landing.y
		token.ground_y = approach.y
		token.play_walk(_hop() * 0.9)
		await token.move_to_world(approach, _hop())
	else:
		token.ground_y = landing.y
		token.global_position = landing
		event.emit("land", {"position": token.global_position})

	## Captures: the attacker strikes, then grabs the victim and throws it home.
	for victim in move["captured"]:
		var victim_color: String = engine.seats[victim["seat"]]["color"]
		var victim_token: TransformerToken = tokens[victim_color][victim["token"]]
		var base := _base_world(victim_color, victim["token"])
		message.emit("%s token sent home!" % victim_color.capitalize())
		if director and not fast_mode:
			director.fight_view(token.global_position, victim_token.global_position, 0.45, 3.6, 28.0)
			director.track(token, victim_token)
		if humans_skin(color):
			tally["captures"] += 1
		if humans_skin(victim_color):
			tally["lost"] += 1
		event.emit("capture", {"position": victim_token.global_position, "color": victim_color, "attacker": color,
			"attacker_token": token, "victim_token": victim_token})
		victim_token.ground_y = base.y
		if fast_mode:
			await victim_token.move_to_world(base, _hop(2.0))
		else:
			await _capture_sequence(token, victim_token, base, index % 2 == 0, color, to, index)
		victim_token.global_position = base
		victim_token.ground_y = base.y
	if fighting:
		## The winner steps onto the square it took.
		token.ground_y = landing.y
		token.play_walk(_hop() * 0.9)
		await token.move_to_world(landing, _hop())
		event.emit("land", {"position": token.global_position})
	token.global_position = landing

	if move["finishes"]:
		message.emit("%s token reached home" % color.capitalize())
		var centre := _track_world(color, BoardPath.FINISH_PROGRESS, index)
		token.ground_y = centre.y
		await token.move_to_world(centre, _hop(1.5))
		if humans_skin(color):
			tally["home"] += 1
		event.emit("finish", {"position": token.global_position, "color": color, "token": token})
		if not fast_mode:
			await token.play_home_bounce()
		token.global_position = centre
	if director and not fast_mode:
		director.release(0.5)
	if String(move.get("powerup", "")) != "":
		event.emit("powerup", {"position": token.global_position, "type": move["powerup"], "token": token})
	if specials:
		specials.sync_powerups(engine.powerups)
		## Two of a colour on one square: high-five.
	if not move["finishes"] and to <= BoardPath.COMMON_STEPS and not fast_mode and life:
		var seat: Dictionary = engine.seats[move["seat"]]
		for i in range(BoardPath.TOKENS_PER_PLAYER):
			if i != index and int(seat["tokens"][i]) == to:
				life.high_five(token, tokens[color][i])
				event.emit("high_five", {"position": token.global_position})
				break
	if move["seat_finished"]:
		message.emit("%s finished!" % color.capitalize())

## Capture choreography, split into small phases with a short hold between each:
## approach -> strike (punch or kick) -> hold -> grab and throw home -> recover.
func _capture_sequence(attacker: TransformerToken, victim: TransformerToken, base: Vector3, use_punch: bool, _color: String, _to: int, _index: int) -> void:
	fight.director = director
	fight.anim_scale = anim_scale
	replay._game_clock = 0.0
	replay.start(attacker, victim)
	await fight.perform(attacker, victim, base, use_punch)
	replay.stop()
	if not fast_mode:
		event.emit("replay_ready", {})


## Turn start: the camera leans a little towards that player's courtyard, then back.
func _glance(color: String) -> void:
	var home: Vector2i = BoardPath.PLAYERS[color]["home"]
	var c := BoardPath.to_world(home.x + 3, home.y + 3)
	director.focus(Vector3(c.x, 0.3, c.z) * 0.35, 0.45, 0.88)
	await get_tree().create_timer(0.75).timeout
	if not busy or is_human_turn():
		director.release(0.6)


## A six: the last tumbles of the dice play in slow motion.
func _six_slow_motion() -> void:
	await get_tree().create_timer(dice.roll_duration * 1.25 * 0.62).timeout
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.45, true, false, true).timeout
	Engine.time_scale = 1.0


## Snakes & Ludo: a ladder climb (a high leap) or a snake slide (a wobbling slither back).
func _slide(token: TransformerToken, color: String, index: int, from_p: int, to_p: int, stop_short: bool) -> void:
	var climbing := to_p > from_p
	event.emit("ladder" if climbing else "snake", {"position": token.global_position, "color": color})
	if fast_mode:
		token.global_position = _track_world(color, to_p, index)
		return
	await get_tree().create_timer(0.15).timeout
	var steps: Array[Vector3] = []
	var p := from_p
	while p != to_p:
		p += 1 if climbing else -1
		steps.append(_track_world(color, p, index))
	if stop_short and not steps.is_empty():
		steps.pop_back()
	var start := token.global_position
	var arc := func(f: float) -> void:
		var pos := start
		if not steps.is_empty():
			var k := f * steps.size()
			var i := mini(int(k), steps.size() - 1)
			var a := start if i == 0 else steps[i - 1]
			pos = a.lerp(steps[i], k - i)
		if climbing:
			pos.y += sin(f * PI) * 1.4
		else:
			token.body_node.rotation.z = sin(f * PI * 8.0) * 0.4
		token.global_position = pos
	var t := token.create_tween()
	t.tween_method(arc, 0.0, 1.0, (0.7 if climbing else 0.9) * anim_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	token.body_node.rotation.z = 0.0


## Jump in an arc from the courtyard to `target`, with a crouch before and a squash after.
func _leap(token: TransformerToken, target: Vector3) -> void:
	var start := token.global_position
	var crouch := token.create_tween()
	crouch.tween_property(token.body_node, "scale", Vector3(1.12, 0.82, 1.12), 0.1 * anim_scale)
	await crouch.finished
	token.ground_y = target.y
	var flat := Vector3(target.x - start.x, 0, target.z - start.z)
	if flat.length_squared() > 0.0001:
		token.rotation.y = atan2(flat.x, flat.z)
	var arc := func(p: float) -> void:
		token.global_position = start.lerp(target, p) + Vector3.UP * sin(p * PI) * 0.9
		token.body_node.scale = Vector3.ONE.lerp(Vector3(0.9, 1.15, 0.9), sin(p * PI))
	var t := token.create_tween()
	t.tween_method(arc, 0.0, 1.0, 0.45 * anim_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	token.global_position = target
	var land := token.create_tween()
	land.tween_property(token.body_node, "scale", Vector3(1.15, 0.8, 1.15), 0.06)
	land.tween_property(token.body_node, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await land.finished


## Fight cues become game events (sound, effects, voices) with the colours filled in.
func _on_fight_cue(cue_name: String, data: Dictionary) -> void:
	if cue_name in ["impact", "jab", "block", "crash", "swing", "whiff"]:
		var d := data.duplicate()
		d.erase("victim")
		replay.note_cue(cue_name, d)
	var out := data.duplicate()
	var victim: Node3D = data.get("victim")
	if victim:
		out["color"] = victim.get_meta("color", "")
		out["victim_token"] = victim
	if cue_name == "impact" and victim and life:
		var attacker_color := current_color()
		life.react_to_capture(attacker_color, victim.get_meta("color", ""), [victim, tokens[attacker_color][_moving_index]])
	event.emit(cue_name, out)


## Engine-wide slow motion for `real_seconds` of wall-clock time.
func _slow_motion(scale: float, real_seconds: float) -> void:
	if fast_mode:
		return
	Engine.time_scale = scale
	var timer := get_tree().create_timer(real_seconds, true, false, true)  ## ignores time scale
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _emit_impact_after(game_seconds: float, victim: Node3D, kind: String) -> void:
	await get_tree().create_timer(game_seconds).timeout
	event.emit("impact", {"position": victim.global_position + Vector3(0, 0.35, 0), "color": victim.get_meta("color", ""), "kind": kind,
		"victim_token": victim})


func _emit_after(game_seconds: float, event_name: String, data: Dictionary) -> void:
	await get_tree().create_timer(game_seconds).timeout
	event.emit(event_name, data)


func _beat(seconds: float) -> void:
	if fast_mode:
		return
	await get_tree().create_timer(seconds).timeout


## Seconds for one animation step; zero-length tweens are not allowed, so use a tiny value in fast mode.
func _hop(scale: float = 1.0) -> float:
	return 0.01 if fast_mode else HOP_SECONDS * scale * anim_scale

func _base_world(color: String, token_index: int) -> Vector3:
	var p := BoardPath.base_spot(color, token_index)
	var w := BoardPath.to_world(p.x, p.y)
	w.y = BASE_Y
	return w

func _track_world(color: String, progress: int, token_index: int) -> Vector3:
	if progress <= 0:
		return _base_world(color, token_index)
	if progress >= BoardPath.FINISH_PROGRESS:
		return RoyalBoard.finish_world(color, token_index)
	var c := BoardPath.progress_point(color, progress, token_index)
	var w := BoardPath.to_world(c.x, c.y)
	w.y = TRACK_Y
	return w

func _highlight(on: bool) -> void:
	for index in range(BoardPath.TOKENS_PER_PLAYER):
		var token: TransformerToken = tokens[current_color()][index]
		var vfx: RoyalTokenVFX = token.get_meta("vfx")
		vfx.set_selected(on and _legal.has(index))
	if preview:
		if on:
			var moves: Array = []
			for index in _legal:
				moves.append(engine.preview_move(index))
			preview.show_moves(current_color(), moves, _track_world)
		else:
			preview.clear()
	if on and not _legal.is_empty():
		var first: TransformerToken = tokens[current_color()][_legal[0]]
		event.emit("select", {"position": first.global_position})

func _finish_game() -> void:
	var ranking: Array = []
	for i in range(engine.rankings.size()):
		var seat := engine.seats[engine.rankings[i]]
		ranking.append({"place": i + 1, "color": seat["color"], "human": seat["human"],
			"team": engine.team_of(engine.rankings[i]) if engine.rules["teams"] else -1})
	message.emit("Game over")
	event.emit("game_over", {"ranking": ranking})
	game_finished.emit(ranking)
