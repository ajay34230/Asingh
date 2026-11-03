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

const TOKEN_SCALE := 0.75
const TRACK_Y := 0.12          ## top of the track tiles (RoyalBoard.TILE_TOP)
const DISC_Y := 0.13           ## courtyard token disc (spots 0 and 1)
const FLOOR_Y := 0.10          ## courtyard floor (spots 2 and 3)
const FINISH_Y := 0.24         ## top of the centre lotus medallion
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
	dice.roll_requested.connect(_on_roll_requested)

var difficulty := 1            ## AiController.Difficulty
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
	var outcome := engine.roll()     ## the engine decides; the dice only shows it
	await dice.roll_to(outcome["value"])
	event.emit("roll_land", {"position": dice.global_position, "value": outcome["value"]})
	if outcome["forfeited"]:
		message.emit("Three sixes: turn lost")
	elif outcome["passed"]:
		message.emit("No legal move")
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

## Called by the input layer when a token is tapped.
func tap_token(color: String, index: int) -> void:
	if not awaiting_pick or busy or color != current_color():
		return
	if not _legal.has(index):
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
	## Walk square by square: the limb cycle runs alongside each hop.
	for progress in range(from + 1 if from > 0 else 1, to + 1):
		var step_point := _track_world(color, progress, index)
		token.ground_y = step_point.y
		event.emit("hop", {"position": token.global_position})
		if not fast_mode:
			token.play_walk(_hop() * 0.9)
		await token.move_to_world(step_point, _hop())
	token.ground_y = _track_world(color, to, index).y
	token.global_position = _track_world(color, to, index)
	event.emit("land", {"position": token.global_position})

	## Captures: the attacker strikes, then grabs the victim and throws it home.
	for victim in move["captured"]:
		var victim_color: String = engine.seats[victim["seat"]]["color"]
		var victim_token: TransformerToken = tokens[victim_color][victim["token"]]
		var base := _base_world(victim_color, victim["token"])
		message.emit("%s token sent home!" % victim_color.capitalize())
		if director and not fast_mode:
			var mid := token.global_position.lerp(victim_token.global_position, 0.5)
			director.focus(mid, 0.3, 0.45)
			director.punch_in(6.0, 1.2)
		event.emit("capture", {"position": victim_token.global_position, "color": victim_color})
		victim_token.ground_y = base.y
		if fast_mode:
			await victim_token.move_to_world(base, _hop(2.0))
		else:
			await _capture_sequence(token, victim_token, base, index % 2 == 0, color, to, index)
		victim_token.global_position = base
		victim_token.ground_y = base.y

	if move["finishes"]:
		message.emit("%s token reached home" % color.capitalize())
		var centre := _track_world(color, BoardPath.FINISH_PROGRESS, index)
		token.ground_y = centre.y
		await token.move_to_world(centre, _hop(1.5))
		event.emit("finish", {"position": token.global_position, "color": color})
		if not fast_mode:
			await token.play_home_bounce()
		token.global_position = centre
	if director and not fast_mode:
		director.release(0.5)
	if move["seat_finished"]:
		message.emit("%s finished!" % color.capitalize())

## Capture choreography, split into small phases with a short hold between each:
## approach -> strike (punch or kick) -> hold -> grab and throw home -> recover.
func _capture_sequence(attacker: TransformerToken, victim: TransformerToken, base: Vector3, use_punch: bool, color: String, to: int, index: int) -> void:
	await _beat(0.18)                                   ## approach: square up to the opponent
	if use_punch:
		await attacker.play_punch(victim)               ## wind-up, strike, victim recoils, recover
	else:
		await attacker.play_kick(victim)
	await _beat(0.22)                                   ## hold the impact on screen
	attacker.ground_y = _track_world(color, to, index).y
	await attacker.play_grab_throw(victim, base)        ## grab, lift, rotate, throw, land home
	await _beat(0.15)                                   ## settle
	attacker.ground_y = _track_world(color, to, index).y


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
	w.y = DISC_Y if token_index < 2 else FLOOR_Y
	return w

func _track_world(color: String, progress: int, token_index: int) -> Vector3:
	if progress <= 0:
		return _base_world(color, token_index)
	if progress >= BoardPath.FINISH_PROGRESS:
		var f := BoardPath.progress_point(color, progress, token_index)
		var fw := BoardPath.to_world(f.x, f.y)
		fw.y = FINISH_Y
		return fw
	var c := BoardPath.progress_point(color, progress, token_index)
	var w := BoardPath.to_world(c.x, c.y)
	w.y = TRACK_Y
	return w

func _highlight(on: bool) -> void:
	for index in range(BoardPath.TOKENS_PER_PLAYER):
		var token: TransformerToken = tokens[current_color()][index]
		var vfx: RoyalTokenVFX = token.get_meta("vfx")
		vfx.set_selected(on and _legal.has(index))
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
