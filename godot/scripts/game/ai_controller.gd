## Heuristic opponent. It only chooses among legal moves and never sees future dice.
class_name AiController
extends RefCounted


## Difficulty levels. Easy plays a random legal move often; Normal uses the heuristic;
## Hard adds safety; Expert also avoids squares just in front of opponents.
enum Difficulty { EASY, NORMAL, HARD, EXPERT }
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard", "Expert"]

## Personalities: named opponents with their own style. Weights scale the score terms:
## attack (captures), safety (safe squares, avoiding danger), race (progress, home).
const PERSONAS := {
	"yellow": {"name": "Rani Padmini", "title": "the Careful", "attack": 0.6, "safety": 2.2, "race": 1.0},
	"green": {"name": "Raja Vikram", "title": "the Bold", "attack": 2.2, "safety": 0.5, "race": 0.9},
	"red": {"name": "Maharaja Surya", "title": "the Swift", "attack": 1.0, "safety": 0.9, "race": 1.8},
	"blue": {"name": "Rajkumari Meera", "title": "the Wise", "attack": 1.2, "safety": 1.4, "race": 1.2},
}


static func choose_move(engine: RulesEngine, moves: Array[int], difficulty: int = Difficulty.NORMAL) -> int:
	if difficulty == Difficulty.EASY and randf() < 0.45:
		return moves[randi() % moves.size()]
	var seat := engine.current_seat()
	var p: Dictionary = PERSONAS.get(seat["color"], {"attack": 1.0, "safety": 1.0, "race": 1.0})
	var attack: float = p["attack"]
	var safety: float = p["safety"]
	var race: float = p["race"]
	## How careful: Normal looks at threats a little, Hard and Expert fully.
	var care := 0.5 if difficulty <= Difficulty.NORMAL else 1.0
	var loss_now := _expected_loss(engine, engine.current, {})
	var best: int = moves[0]
	var best_score := -INF
	for token in moves:
		var preview := engine.preview_move(token)
		## Pretend the move happened (my token moved, victims sent home) and see what
		## the position is worth: tokens saved from danger, enemies in reach.
		var after := {engine.current: {token: int(preview["to"])}}
		for cap in preview["captures"]:
			if not after.has(cap["seat"]):
				after[cap["seat"]] = {}
			after[cap["seat"]][cap["token"]] = 0
		var saved := loss_now - _expected_loss(engine, engine.current, after)   # > 0: the move protects tokens
		var score: float = float(int(preview["to"]) - int(preview["from"])) * 0.5 * race
		score += saved * 1.4 * safety * care
		## Capturing: the further the victim got, the more it hurts them.
		score += float(preview["captures"].size()) * 100.0 * attack
		for cap in preview["captures"]:
			score += float(engine.seats[cap["seat"]]["tokens"][cap["token"]]) * 0.9 * attack
		## Hunting: end within one throw of an enemy that cannot hide on a safe square.
		score += _prey_in_reach(engine, seat, int(preview["to"]), after) * 9.0 * attack * care
		if difficulty >= Difficulty.HARD:
			score += _safety_bonus(engine, preview) * safety
		if difficulty == Difficulty.EXPERT:
			score -= _danger(engine, seat, preview) * 12.0 * safety
		if preview["powerup"] != "":
			score += 25.0
		if int(preview["slide_from"]) >= 0:
			score += (float(preview["to"]) - float(preview["slide_from"])) * 4.0
		if preview["finishes"]:
			score += 90.0 * race
		if preview["from"] == 0:
			score += 40.0
		if preview["to"] > BoardPath.COMMON_STEPS and not preview["finishes"]:
			score += 30.0
		if preview["to"] <= BoardPath.COMMON_STEPS \
				and BoardPath.is_safe_ring(BoardPath.ring_index_for_progress(seat["color"], preview["to"])):
			score += 15.0 * safety
		if preview["to"] == BoardPath.FINISH_PROGRESS:
			score += 10.0
		if score > best_score:
			best_score = score
			best = token
	return best


## Progress of every token as it would be after `changes` ({seat: {token: progress}}).
static func _progress(engine: RulesEngine, seat_index: int, token: int, changes: Dictionary) -> int:
	if changes.has(seat_index) and changes[seat_index].has(token):
		return int(changes[seat_index][token])
	return int(engine.seats[seat_index]["tokens"][token])


## What my tokens are expected to lose next turn: for each token on an unsafe square,
## the chance an enemy lands on it (one throw away, about 1 in 6 each) times what it
## would lose (its progress, plus the six needed to come out again).
static func _expected_loss(engine: RulesEngine, me: int, changes: Dictionary) -> float:
	var total := 0.0
	var my_color: String = engine.seats[me]["color"]
	for t in range(4):
		var mine := _progress(engine, me, t, changes)
		if mine < 1 or mine > BoardPath.COMMON_STEPS or int(engine.seats[me]["shields"][t]) > 0:
			continue
		var ring := BoardPath.ring_index_for_progress(my_color, mine)
		if BoardPath.is_safe_ring(ring):
			continue
		var chance := 0.0
		for o in range(engine.seats.size()):
			if o == me or engine.team_of(o) == engine.team_of(me):
				continue
			for q in range(4):
				var op := _progress(engine, o, q, changes)
				if op < 1 or op > BoardPath.COMMON_STEPS:
					continue
				var behind := (ring - BoardPath.ring_index_for_progress(engine.seats[o]["color"], op) + BoardPath.RING_LENGTH) % BoardPath.RING_LENGTH
				if behind >= 1 and behind <= 6:
					chance += 1.0 / 6.0 + (0.03 if behind == 6 else 0.0)
		total += minf(chance, 1.0) * (float(mine) + 8.0)
	return total


## Enemy tokens 1-6 squares ahead of this square that are not on a safe square.
static func _prey_in_reach(engine: RulesEngine, seat: Dictionary, to: int, changes: Dictionary) -> int:
	if to < 1 or to > BoardPath.COMMON_STEPS:
		return 0
	var ring := BoardPath.ring_index_for_progress(seat["color"], to)
	var me := engine.seats.find(seat)
	var count := 0
	for o in range(engine.seats.size()):
		if o == me or engine.team_of(o) == engine.team_of(me):
			continue
		for q in range(4):
			var op := _progress(engine, o, q, changes)
			if op < 1 or op > BoardPath.COMMON_STEPS or int(engine.seats[o]["shields"][q]) > 0:
				continue
			var their := BoardPath.ring_index_for_progress(engine.seats[o]["color"], op)
			if BoardPath.is_safe_ring(their):
				continue
			var ahead := (their - ring + BoardPath.RING_LENGTH) % BoardPath.RING_LENGTH
			if ahead >= 1 and ahead <= 6:
				count += 1
	return count


## +12 for leaving a safe square is not needed; reward ending on a safe square.
static func _safety_bonus(engine: RulesEngine, preview: Dictionary) -> float:
	var to: int = preview["to"]
	if to <= BoardPath.COMMON_STEPS and BoardPath.is_safe_ring(BoardPath.ring_index_for_progress(engine.current_seat()["color"], to)):
		return 15.0
	return 0.0


## Number of opponent tokens that could land on this square next turn (1 to 6 steps behind).
static func _danger(engine: RulesEngine, seat: Dictionary, preview: Dictionary) -> int:
	var to: int = preview["to"]
	if to < 1 or to > BoardPath.COMMON_STEPS:
		return 0
	var dest := BoardPath.ring_index_for_progress(seat["color"], to)
	if BoardPath.is_safe_ring(dest):
		return 0
	var count := 0
	for other_index in range(engine.seats.size()):
		var other := engine.seats[other_index]
		if other == seat:
			continue
		for q in other["tokens"]:
			if q >= 1 and q <= BoardPath.COMMON_STEPS:
				var behind := (dest - BoardPath.ring_index_for_progress(other["color"], q) + BoardPath.RING_LENGTH) % BoardPath.RING_LENGTH
				if behind >= 1 and behind <= 6:
					count += 1
	return count
