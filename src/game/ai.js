/**
 * Simple heuristic opponent. It only chooses among legal moves; it never
 * touches the rules, so it cannot cheat.
 */
import { COMMON_STEPS, FINISH_PROGRESS, isSafeRing, ringIndexForProgress } from './layout.js';
import { currentSeat, previewMove } from './rules.js';

/**
 * @param {object} game
 * @param {number[]} moves legal token indices
 * @returns {number} chosen token index
 */
export function chooseMove(game, moves) {
  const seat = currentSeat(game);
  let best = moves[0];
  let bestScore = -Infinity;

  for (const token of moves) {
    const preview = previewMove(game, token);
    let score = preview.to * 0.5;
    score += preview.captures.length * 100;
    if (preview.finishes) score += 90;
    if (preview.from === 0) score += 50;
    if (preview.to > COMMON_STEPS && !preview.finishes) score += 30;
    if (preview.to <= COMMON_STEPS && isSafeRing(ringIndexForProgress(seat.color, preview.to))) score += 15;
    if (preview.to === FINISH_PROGRESS) score += 10;

    if (score > bestScore) {
      bestScore = score;
      best = token;
    }
  }
  return best;
}
