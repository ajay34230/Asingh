## Ludo rules engine. Pure logic: no nodes, no timers, no rendering.
## The engine decides every outcome. Animations only present the result.
##
## Standard rules: a six brings a token out; exact roll to finish; captures
## (except on safe squares) send the victim home and grant a bonus roll; a
## six grants a bonus roll; three sixes forfeit the turn; players finish in
## order and the game ends when one player is left.
class_name RulesEngine
extends RefCounted

const PHASE_ROLL := "roll"
const PHASE_MOVE := "move"
const PHASE_OVER := "over"

var seats: Array[Dictionary] = []
var current: int = 0
var phase: String = PHASE_ROLL
var dice: int = 0
var consecutive_sixes: int = 0
var rankings: Array[int] = []
var _rng := RandomNumberGenerator.new()

## House rules. Defaults are standard Ludo. Each flag is shown as a toggle in the menu.
## six_to_start: a token leaves its yard only on a six.
## three_sixes_penalty: three consecutive sixes forfeit the turn.
## capture_bonus: capturing grants another roll.
## home_bonus: moving a token into the centre grants another roll.
## quick_end: the game ends as soon as the first player finishes.
const DEFAULT_RULES := {
	"six_to_start": true,
	"three_sixes_penalty": true,
	"capture_bonus": true,
	"home_bonus": true,
	"quick_end": false,
}
var rules: Dictionary = DEFAULT_RULES.duplicate()


## seat_specs: Array of {"color": String, "human": bool}.
func setup(seat_specs: Array, rng_seed: int = 0, rule_overrides: Dictionary = {}) -> void:
	rules = DEFAULT_RULES.duplicate()
	for key in rule_overrides:
		if rules.has(key):
			rules[key] = bool(rule_overrides[key])
	assert(seat_specs.size() >= 2 and seat_specs.size() <= 4, "a game needs 2 to 4 seats")
	seats.clear()
	var used := {}
	for spec in seat_specs:
		var color: String = spec["color"]
		assert(BoardPath.COLORS.has(color) and not used.has(color), "invalid or duplicate colour")
		used[color] = true
		seats.append({
			"color": color,
			"human": bool(spec.get("human", false)),
			"tokens": [0, 0, 0, 0],
			"rank": -1,
		})
	current = 0
	phase = PHASE_ROLL
	dice = 0
	consecutive_sixes = 0
	rankings.clear()
	_rng.seed = rng_seed
	if rng_seed == 0:
		_rng.randomize()


func current_seat() -> Dictionary:
	return seats[current]


## Rolls with the engine's own RNG. The visual dice must show this value.
func roll() -> Dictionary:
	return roll_with_value(_rng.randi_range(1, 6))


## Resolves a roll with a known value (used by tests and replays).
func roll_with_value(value: int) -> Dictionary:
	assert(phase == PHASE_ROLL, "cannot roll during phase '%s'" % phase)
	assert(value >= 1 and value <= 6)
	dice = value
	consecutive_sixes = consecutive_sixes + 1 if value == 6 else 0
	if consecutive_sixes == 3 and rules["three_sixes_penalty"]:
		consecutive_sixes = 0
		_advance_turn(false)
		return {"value": value, "moves": [], "forfeited": true, "passed": false}
	var moves := legal_moves()
	if moves.is_empty():
		_advance_turn(false)
		return {"value": value, "moves": moves, "forfeited": false, "passed": true}
	phase = PHASE_MOVE
	return {"value": value, "moves": moves, "forfeited": false, "passed": false}


## Token indices that may legally move with the current dice value.
func legal_moves() -> Array[int]:
	var moves: Array[int] = []
	var tokens: Array = current_seat()["tokens"]
	for token in range(tokens.size()):
		var progress: int = tokens[token]
		if progress == 0:
			if dice == 6 or not rules["six_to_start"]:
				moves.append(token)
		elif progress + dice <= BoardPath.FINISH_PROGRESS:
			moves.append(token)
	return moves


## Describes a move without changing state. Used by the AI and the animation planner.
func preview_move(token: int) -> Dictionary:
	var seat := current_seat()
	var from: int = seat["tokens"][token]
	var to := 1 if from == 0 else from + dice
	var captures: Array[Dictionary] = []
	if to <= BoardPath.COMMON_STEPS:
		var ring := BoardPath.ring_index_for_progress(seat["color"], to)
		if not BoardPath.is_safe_ring(ring):
			for other_index in range(seats.size()):
				if other_index == current:
					continue
				var other := seats[other_index]
				for other_token in range(4):
					var q: int = other["tokens"][other_token]
					if q >= 1 and q <= BoardPath.COMMON_STEPS \
							and BoardPath.ring_index_for_progress(other["color"], q) == ring:
						captures.append({"seat": other_index, "token": other_token})
	return {
		"seat": current, "token": token, "from": from, "to": to,
		"captures": captures, "finishes": to == BoardPath.FINISH_PROGRESS,
	}


## Moves a token with the current dice value. Returns the resolved move.
func apply_move(token: int) -> Dictionary:
	assert(phase == PHASE_MOVE, "cannot move during phase '%s'" % phase)
	assert(legal_moves().has(token), "token %d cannot move with %d" % [token, dice])
	var preview := preview_move(token)
	var seat := current_seat()
	seat["tokens"][token] = preview["to"]
	for capture in preview["captures"]:
		seats[capture["seat"]]["tokens"][capture["token"]] = 0

	var finished_seat := false
	if preview["finishes"] and _all_finished(seat):
		_finish_seat(current)
		finished_seat = true

	var earned_bonus := dice == 6
	if rules["capture_bonus"] and not preview["captures"].is_empty():
		earned_bonus = true
	if rules["home_bonus"] and preview["finishes"]:
		earned_bonus = true
	var extra_turn := earned_bonus and not finished_seat and phase != PHASE_OVER
	_advance_turn(extra_turn)

	var result := preview.duplicate()
	result["captured"] = preview["captures"]
	result["seat_finished"] = finished_seat
	result["extra_turn"] = extra_turn
	result["game_over"] = phase == PHASE_OVER
	return result


func _all_finished(seat: Dictionary) -> bool:
	for p in seat["tokens"]:
		if p != BoardPath.FINISH_PROGRESS:
			return false
	return true


func _is_finished(seat: Dictionary) -> bool:
	return seat["rank"] != -1


func _active_seat_count() -> int:
	var n := 0
	for seat in seats:
		if not _is_finished(seat):
			n += 1
	return n


func _finish_seat(index: int) -> void:
	seats[index]["rank"] = rankings.size() + 1
	rankings.append(index)
	if rules["quick_end"] and rankings.size() == 1:
		_rank_remaining_by_progress()
		phase = PHASE_OVER
		return
	if _active_seat_count() == 1:
		for i in range(seats.size()):
			if not _is_finished(seats[i]):
				seats[i]["rank"] = rankings.size() + 1
				rankings.append(i)
		phase = PHASE_OVER


## Quick play: the rest of the table is ranked by how far their tokens have travelled.
func _rank_remaining_by_progress() -> void:
	var remaining: Array[int] = []
	for i in range(seats.size()):
		if not _is_finished(seats[i]):
			remaining.append(i)
	remaining.sort_custom(func(a: int, b: int) -> bool: return _progress_sum(seats[a]) > _progress_sum(seats[b]))
	for i in remaining:
		seats[i]["rank"] = rankings.size() + 1
		rankings.append(i)

func _progress_sum(seat: Dictionary) -> int:
	var total := 0
	for p in seat["tokens"]:
		total += int(p)
	return total

func _advance_turn(same_seat: bool) -> void:
	if phase == PHASE_OVER:
		return
	if same_seat and not _is_finished(current_seat()):
		phase = PHASE_ROLL
		return
	if not same_seat:
		consecutive_sixes = 0
	var n := seats.size()
	for step in range(1, n + 1):
		var candidate := (current + step) % n
		if not _is_finished(seats[candidate]):
			current = candidate
			break
	phase = PHASE_ROLL
