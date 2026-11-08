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
	var best: int = moves[0]
	var best_score := -INF
	for token in moves:
		var preview := engine.preview_move(token)
		var score: float = float(preview["to"]) * 0.5 * race
		if difficulty >= Difficulty.HARD:
			score += _safety_bonus(engine, preview) * safety
		if difficulty == Difficulty.EXPERT:
			score -= _danger(engine, seat, preview) * 12.0 * safety
		score += float(preview["captures"].size()) * 100.0 * attack
		if preview["finishes"]:
			score += 90.0 * race
		if preview["from"] == 0:
			score += 50.0
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
