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

const TOKEN_SCALE := 0.75
const TRACK_Y := 0.44          ## measured track tile height on the supplied board
const DISC_Y := 0.40           ## courtyard gold disc (token spots 0 and 1)
const FLOOR_Y := 0.30          ## courtyard floor (token spots 2 and 3)
const FINISH_Y := 0.60         ## centre lotus height
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

func new_game(seat_colors: Array[String] = ["blue", "yellow", "green", "red"], humans: Array[String] = ["blue"]) -> void:
	human_colors = humans
	var seats: Array = []
	for color in seat_colors:
		seats.append({"color": color, "human": humans.has(color)})
	engine.setup(seats, _seed)
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
	var outcome := engine.roll()     ## the engine decides; the dice only shows it
	await dice.roll_to(outcome["value"])
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
		var choice := AiController.choose_move(engine, _legal)
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
	_execute(index)

func _execute(token_index: int) -> void:
	busy = true
	var move := engine.apply_move(token_index)
	await _animate_move(move)
	busy = false
	_start_turn()

func _animate_move(move: Dictionary) -> void:
	var color: String = engine.seats[move["seat"]]["color"]
	var token: TransformerToken = tokens[color][move["token"]]
	var from: int = move["from"]
	var to: int = move["to"]
	for progress in range(from + 1 if from > 0 else 1, to + 1):
		await token.move_to_world(_track_world(color, progress, move["token"]), _hop())
	for victim in move["captured"]:
		var victim_color: String = engine.seats[victim["seat"]]["color"]
		var victim_token: TransformerToken = tokens[victim_color][victim["token"]]
		message.emit("%s token sent home!" % victim_color.capitalize())
		await victim_token.move_to_world(_base_world(victim_color, victim["token"]), _hop(2.0))
	if move["finishes"]:
		message.emit("%s token reached home" % color.capitalize())
		await token.move_to_world(_track_world(color, BoardPath.FINISH_PROGRESS, move["token"]), _hop(1.5))
	if move["seat_finished"]:
		message.emit("%s finished!" % color.capitalize())

## Seconds for one animation step; zero-length tweens are not allowed, so use a tiny value in fast mode.
func _hop(scale: float = 1.0) -> float:
	return 0.01 if fast_mode else HOP_SECONDS * scale

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

func _finish_game() -> void:
	var ranking: Array = []
	for i in range(engine.rankings.size()):
		var seat := engine.seats[engine.rankings[i]]
		ranking.append({"place": i + 1, "color": seat["color"], "human": seat["human"]})
	message.emit("Game over")
	game_finished.emit(ranking)
