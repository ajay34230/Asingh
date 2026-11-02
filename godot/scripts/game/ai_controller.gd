## Heuristic opponent. It only chooses among legal moves and never sees future dice.
class_name AiController
extends RefCounted


## Returns the token index to move from the engine's legal moves.
static func choose_move(engine: RulesEngine, moves: Array[int]) -> int:
	var seat := engine.current_seat()
	var best: int = moves[0]
	var best_score := -INF
	for token in moves:
		var preview := engine.preview_move(token)
		var score: float = float(preview["to"]) * 0.5
		score += float(preview["captures"].size()) * 100.0
		if preview["finishes"]:
			score += 90.0
		if preview["from"] == 0:
			score += 50.0
		if preview["to"] > BoardPath.COMMON_STEPS and not preview["finishes"]:
			score += 30.0
		if preview["to"] <= BoardPath.COMMON_STEPS \
				and BoardPath.is_safe_ring(BoardPath.ring_index_for_progress(seat["color"], preview["to"])):
			score += 15.0
		if preview["to"] == BoardPath.FINISH_PROGRESS:
			score += 10.0
		if score > best_score:
			best_score = score
			best = token
	return best
