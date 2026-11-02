/**
 * Pure Ludo rules engine. No rendering, timing or DOM code lives here, so the
 * whole game can be exercised headlessly by the test suite.
 *
 * Standard rules implemented:
 *  - A token leaves its base only on a 6, landing on its start square.
 *  - Exact roll required to reach the centre; overshooting is not a legal move.
 *  - Landing on an opponent's token outside a safe square sends it to base.
 *  - Safe squares (start squares and stars) cannot be captured on.
 *  - Rolling a 6 grants a bonus roll after a move.
 *  - Three consecutive 6s forfeit the turn.
 *  - Players finish in order; the game ends when one player remains.
 */
import {
  COLORS, COMMON_STEPS, FINISH_PROGRESS, TOKENS_PER_PLAYER,
  isSafeRing, ringIndexForProgress,
} from './layout.js';

/** Deterministic PRNG (mulberry32) so tests and replays can be seeded. */
export function createRng(seed) {
  let a = seed >>> 0;
  return function next() {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * @param {{ seats: Array<{ color: string, human: boolean }>, rng?: () => number }} options
 */
export function createGame({ seats, rng = Math.random }) {
  if (!Array.isArray(seats) || seats.length < 2 || seats.length > 4) {
    throw new RangeError('a game needs between 2 and 4 seats');
  }
  const seen = new Set();
  for (const seat of seats) {
    if (!COLORS.includes(seat.color) || seen.has(seat.color)) {
      throw new RangeError(`invalid or duplicate colour: ${seat.color}`);
    }
    seen.add(seat.color);
  }
  return {
    seats: seats.map((seat) => ({
      color: seat.color,
      human: Boolean(seat.human),
      tokens: Array(TOKENS_PER_PLAYER).fill(0),
      rank: null,
    })),
    current: 0,
    phase: 'roll', // 'roll' | 'move' | 'over'
    dice: 0,
    consecutiveSixes: 0,
    rankings: [],
    rng,
  };
}

export function rollValue(rng) {
  return 1 + Math.floor(rng() * 6);
}

export function currentSeat(game) {
  return game.seats[game.current];
}

/** Token indices that may legally move with the given roll for the current seat. */
export function legalMoves(game, value = game.dice) {
  const seat = currentSeat(game);
  const moves = [];
  seat.tokens.forEach((progress, token) => {
    if (progress === 0) {
      if (value === 6) moves.push(token);
    } else if (progress + value <= FINISH_PROGRESS) {
      moves.push(token);
    }
  });
  return moves;
}

/**
 * Describes what a move would do without changing the game.
 * Used by the AI for scoring and by the controller to plan animations.
 */
export function previewMove(game, tokenIndex, value = game.dice) {
  const seatIndex = game.current;
  const seat = game.seats[seatIndex];
  const from = seat.tokens[tokenIndex];
  const to = from === 0 ? 1 : from + value;
  const captures = [];

  if (to <= COMMON_STEPS) {
    const ring = ringIndexForProgress(seat.color, to);
    if (!isSafeRing(ring)) {
      game.seats.forEach((other, otherIndex) => {
        if (otherIndex === seatIndex) return;
        other.tokens.forEach((progress, otherToken) => {
          if (progress >= 1 && progress <= COMMON_STEPS
            && ringIndexForProgress(other.color, progress) === ring) {
            captures.push({ seat: otherIndex, token: otherToken });
          }
        });
      });
    }
  }

  return {
    seat: seatIndex,
    token: tokenIndex,
    from,
    to,
    captures,
    finishes: to === FINISH_PROGRESS,
  };
}

function isFinished(seat) {
  return seat.rank !== null;
}

function activeSeatCount(game) {
  return game.seats.filter((seat) => !isFinished(seat)).length;
}

/**
 * Rolls the dice for the current seat. The result is generated here, from the
 * game's RNG, and never from the animation.
 */
export function rollDice(game) {
  if (game.phase !== 'roll') throw new Error(`cannot roll during phase "${game.phase}"`);

  const value = rollValue(game.rng);
  game.dice = value;
  game.consecutiveSixes = value === 6 ? game.consecutiveSixes + 1 : 0;

  if (game.consecutiveSixes === 3) {
    game.consecutiveSixes = 0;
    advanceTurn(game, false);
    return { value, moves: [], forfeited: true, passed: false };
  }

  const moves = legalMoves(game, value);
  if (moves.length === 0) {
    advanceTurn(game, false);
    return { value, moves, forfeited: false, passed: true };
  }

  game.phase = 'move';
  return { value, moves, forfeited: false, passed: false };
}

/** Moves a token using the current dice value. Captures, finishing and turn flow are resolved here. */
export function applyMove(game, tokenIndex) {
  if (game.phase !== 'move') throw new Error(`cannot move during phase "${game.phase}"`);
  if (!legalMoves(game).includes(tokenIndex)) throw new Error(`token ${tokenIndex} cannot move with ${game.dice}`);

  const preview = previewMove(game, tokenIndex);
  const seat = currentSeat(game);
  seat.tokens[tokenIndex] = preview.to;

  for (const capture of preview.captures) {
    game.seats[capture.seat].tokens[capture.token] = 0;
  }

  let finishedSeat = false;
  if (preview.finishes && seat.tokens.every((p) => p === FINISH_PROGRESS)) {
    finishSeat(game, game.current);
    finishedSeat = true;
  }

  const extraTurn = game.dice === 6 && !finishedSeat && game.phase !== 'over';
  advanceTurn(game, extraTurn);

  return {
    ...preview,
    captured: preview.captures,
    seatFinished: finishedSeat,
    extraTurn,
    gameOver: game.phase === 'over',
  };
}

function finishSeat(game, seatIndex) {
  game.seats[seatIndex].rank = game.rankings.length + 1;
  game.rankings.push(seatIndex);
  if (activeSeatCount(game) === 1) {
    const last = game.seats.findIndex((seat) => !isFinished(seat));
    game.seats[last].rank = game.rankings.length + 1;
    game.rankings.push(last);
    game.phase = 'over';
  }
}

function advanceTurn(game, sameSeat) {
  if (game.phase === 'over') return;
  if (sameSeat && !isFinished(currentSeat(game))) {
    game.phase = 'roll';
    return;
  }
  game.consecutiveSixes = sameSeat ? game.consecutiveSixes : 0;
  const n = game.seats.length;
  for (let step = 1; step <= n; step++) {
    const candidate = (game.current + step) % n;
    if (!isFinished(game.seats[candidate])) {
      game.current = candidate;
      break;
    }
  }
  game.phase = 'roll';
}

/** Read-only snapshot used by the view and the UI. */
export function snapshot(game) {
  return {
    current: game.current,
    phase: game.phase,
    dice: game.dice,
    rankings: [...game.rankings],
    seats: game.seats.map((seat) => ({
      color: seat.color,
      human: seat.human,
      tokens: [...seat.tokens],
      rank: seat.rank,
    })),
  };
}
