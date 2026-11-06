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
	dice.roll_requested.connect(_on_roll_requested)

var difficulty := 1            ## AiController.Difficulty
var fight: FightChoreography
var preview: MovePreview        ## set by the main scene; shows where legal moves land
var director: CameraDirector    ## set by the main scene; frames the action
var anim_scale := 1.0         ## 1.0 normal; >1 slower, <1 faster

func new_game(seat_colors: Array[String] = ["blue", "yellow", "green", "red"], humans: Array[String] = ["blue"], rules: Dictionary = {}, ai_difficulty: int = 1) -> void:
	human_colors = humans
	difficulty = ai_difficulty
	var seats: Array = []
	for color in seat_colors:
		seats.append({"color": color, "human": humans.has(color)})
	engine.setup(seats, _seed, rules)
	_spawn_tokens(seat_colors)
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
			token.scale = Vector3.ONE * TOKEN_SCALE
			var vfx := RoyalTokenVFX.new()
			token.add_child(vfx)
			token.set_meta("vfx", vfx)
			token.set_meta("index", i)
			token.set_meta("color", color)
			token.position = _base_world(color, i)
			token.ground_y = token.position.y
			list.append(token)
		tokens[color] = list

func current_color() -> String:
	return engine.current_seat()["color"]

func is_human_turn() -> bool:
	return engine.current_seat()["human"]

func _start_turn() -> void:
	if engine.phase == RulesEngine.PHASE_OVER:
		_finish_game()
		return
	turn_changed.emit(current_color(), is_human_turn())
	if is_human_turn():
		message.emit("Your turn: tap the dice")
		dice.set_rollable(true)
	else:
		message.emit("%s is rolling" % current_color().capitalize())
		dice.set_rollable(false)
		if not fast_mode:
			await get_tree().create_timer(AI_DELAY).timeout
		_roll_now()

func _on_roll_requested() -> void:
	if busy or not is_human_turn() or engine.phase != RulesEngine.PHASE_ROLL:
		return
	_roll_now()

func _roll_now() -> void:
	if busy or engine.phase != RulesEngine.PHASE_ROLL:
		return
	busy = true
	dice.set_rollable(false)
	event.emit("roll_start", {"position": dice.global_position})
	var thrower := current_color()   ## read first: a roll with no move passes the turn
	var outcome := engine.roll()     ## the engine decides; the dice only shows it
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
	if is_human_turn():
		if _legal.size() == 1:
			await _execute(_legal[0])
		else:
			awaiting_pick = true
			_highlight(true)
			message.emit("Tap a glowing %s token" % current_color())
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


## Called by the input layer when a token is tapped.
func tap_token(color: String, index: int) -> void:
	if not awaiting_pick or busy or color != current_color():
		return
	if not _legal.has(index):
		event.emit("invalid", {})
		return
	awaiting_pick = false
	_highlight(false)
	event.emit("click", {})
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
	var token: TransformerToken = tokens[color][index]
	var from: int = move["from"]
	var to: int = move["to"]
	await token.transform_out(0.2)
	if director and not fast_mode:
		director.focus(token.global_position, 0.35)
	## Walk square by square: the limb cycle runs alongside each hop. With a capture, the
	## attacker stops just short of the victim's square and squares up to fight.
	var fighting: bool = not move["captured"].is_empty() and not fast_mode
	var last := to - 1 if fighting else to
	for progress in range(from + 1 if from > 0 else 1, last + 1):
		var step_point := _track_world(color, progress, index)
		token.ground_y = step_point.y
		event.emit("hop", {"position": token.global_position})
		if not fast_mode:
			token.play_walk(_hop() * 0.9)
		await token.move_to_world(step_point, _hop())
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
		event.emit("finish", {"position": token.global_position, "color": color, "token": token})
		if not fast_mode:
			await token.play_home_bounce()
		token.global_position = centre
	if director and not fast_mode:
		director.release(0.5)
	if move["seat_finished"]:
		message.emit("%s finished!" % color.capitalize())

## Capture choreography, split into small phases with a short hold between each:
## approach -> strike (punch or kick) -> hold -> grab and throw home -> recover.
func _capture_sequence(attacker: TransformerToken, victim: TransformerToken, base: Vector3, use_punch: bool, _color: String, _to: int, _index: int) -> void:
	fight.director = director
	fight.anim_scale = anim_scale
	await fight.perform(attacker, victim, base, use_punch)


## Fight cues become game events (sound, effects, voices) with the colours filled in.
func _on_fight_cue(cue_name: String, data: Dictionary) -> void:
	var out := data.duplicate()
	var victim: Node3D = data.get("victim")
	if victim:
		out["color"] = victim.get_meta("color", "")
		out["victim_token"] = victim
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
		ranking.append({"place": i + 1, "color": seat["color"], "human": seat["human"]})
	message.emit("Game over")
	event.emit("game_over", {"ranking": ranking})
	game_finished.emit(ranking)
