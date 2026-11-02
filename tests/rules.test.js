import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  createGame, createRng, rollDice, applyMove, legalMoves, previewMove, snapshot,
} from '../src/game/rules.js';
import { chooseMove } from '../src/game/ai.js';
import { PLAYERS, ringIndexForProgress, FINISH_PROGRESS } from '../src/game/layout.js';

const FOUR_SEATS = [
  { color: 'red', human: true },
  { color: 'green' },
  { color: 'yellow' },
  { color: 'blue' },
];

/** Game whose dice come from a fixed script (values 1..6). */
function scripted(values, seats = FOUR_SEATS) {
  const queue = [...values];
  const rng = () => {
    const v = queue.shift();
    if (v === undefined) throw new Error('dice script exhausted');
    return (v - 1 + 0.5) / 6;
  };
  return createGame({ seats, rng });
}

function setTokens(game, seatIndex, tokens) {
  game.seats[seatIndex].tokens = [...tokens];
}

/** Common-track progress that green/yellow/blue would need to stand on a given ring index. */
function progressFor(color, ringIndex) {
  const p = ((ringIndex - PLAYERS[color].start + 52) % 52) + 1;
  assert.ok(p >= 1 && p <= 51, `ring ${ringIndex} is on ${color}'s common track`);
  return p;
}

test('a token only leaves base on a six, onto its start square', () => {
  const game = scripted([5, 6]);
  const first = rollDice(game);
  assert.equal(first.passed, true, 'a 5 with every token in base passes the turn');
  assert.equal(game.current, 1);

  game.current = 0;
  game.phase = 'roll';
  const six = rollDice(game);
  assert.deepEqual(six.moves, [0, 1, 2, 3]);
  applyMove(game, 2);
  assert.equal(game.seats[0].tokens[2], 1);
});

test('exact roll is required to finish; overshoot is illegal', () => {
  const overshoot = scripted([3]);
  setTokens(overshoot, 0, [55, 0, 0, 0]);
  assert.equal(rollDice(overshoot).passed, true, 'no legal move, so the turn passes');
  assert.deepEqual(legalMoves(overshoot), [], 'token at 55 cannot take a 3 (58 > 57)');

  const exact = scripted([2]);
  setTokens(exact, 0, [55, 0, 0, 0]);
  rollDice(exact);
  assert.deepEqual(legalMoves(exact), [0]);
  const result = applyMove(exact, 0);
  assert.equal(result.to, FINISH_PROGRESS);
  assert.equal(result.finishes, true);
});

test('landing on an opponent outside a safe square captures it', () => {
  const game = scripted([3]);
  setTokens(game, 0, [20, 0, 0, 0]); // red lands on progress 23
  const target = ringIndexForProgress('red', 23);
  setTokens(game, 1, [progressFor('green', target), 0, 0, 0]);
  rollDice(game);
  const result = applyMove(game, 0);
  assert.deepEqual(result.captured, [{ seat: 1, token: 0 }]);
  assert.equal(game.seats[1].tokens[0], 0, 'captured token returns to base');
});

test('an opponent standing on a star square cannot be captured', () => {
  const game = scripted([3]);
  setTokens(game, 0, [6, 0, 0, 0]); // red lands on progress 9, which is red's star square
  assert.equal(ringIndexForProgress('red', 9), PLAYERS.red.star);
  setTokens(game, 1, [progressFor('green', PLAYERS.red.star), 0, 0, 0]);
  rollDice(game);
  const preview = previewMove(game, 0);
  assert.equal(preview.to, 9);
  assert.equal(preview.captures.length, 0, 'the star square is safe');
});

test('a six grants a bonus roll after a move; other values pass the turn', () => {
  const game = scripted([6, 6, 4]);
  rollDice(game);
  const first = applyMove(game, 0);
  assert.equal(first.extraTurn, true);
  assert.equal(game.current, 0);
  assert.equal(game.phase, 'roll');

  rollDice(game);
  applyMove(game, 0);
  rollDice(game);
  applyMove(game, 0);
  assert.equal(game.current, 1, 'turn passes after a non-six');
});

test('three consecutive sixes forfeit the turn and the third six is void', () => {
  const game = scripted([6, 6, 6]);
  setTokens(game, 0, [5, 0, 0, 0]);
  rollDice(game);
  applyMove(game, 0); // 5 -> 11
  rollDice(game);
  applyMove(game, 0); // 11 -> 17
  const third = rollDice(game);
  assert.equal(third.forfeited, true);
  assert.equal(game.current, 1);
  assert.equal(game.seats[0].tokens[0], 17);
});

test('a roll with no legal move passes the turn', () => {
  const game = scripted([2]);
  const outcome = rollDice(game);
  assert.equal(outcome.passed, true);
  assert.equal(game.current, 1);
});

test('finishing all four tokens ranks the seat', () => {
  const game = scripted([2, 2]);
  setTokens(game, 0, [57, 57, 57, 55]);
  rollDice(game);
  applyMove(game, 3);
  assert.equal(game.seats[0].rank, 1);
  assert.deepEqual(game.rankings, [0]);
  assert.equal(game.phase, 'roll');
  assert.notEqual(game.current, 0, 'a finished seat no longer takes turns');
});

test('game over when all but one seat has finished, and the last seat is ranked', () => {
  const game = scripted([2], [{ color: 'red', human: true }, { color: 'yellow' }]);
  setTokens(game, 0, [57, 57, 57, 55]);
  setTokens(game, 1, [57, 57, 57, 0]);
  rollDice(game);
  const result = applyMove(game, 3);
  assert.equal(result.gameOver, true);
  assert.equal(game.phase, 'over');
  assert.deepEqual(game.rankings, [0, 1]);
});

test('rolls and moves are rejected in the wrong phase', () => {
  const game = scripted([6]);
  assert.throws(() => applyMove(game, 0), /cannot move/);
  rollDice(game);
  assert.throws(() => rollDice(game), /cannot roll/);
});

test('dice results are reproducible from a seed', () => {
  const seats = [{ color: 'red', human: true }, { color: 'blue' }];
  const a = createGame({ seats, rng: createRng(42) });
  const b = createGame({ seats, rng: createRng(42) });
  const rollsA = [];
  const rollsB = [];
  for (let i = 0; i < 50 && a.phase !== 'over'; i++) {
    rollsA.push(rollDice(a).value);
    if (a.phase === 'move') applyMove(a, legalMoves(a)[0]);
    rollsB.push(rollDice(b).value);
    if (b.phase === 'move') applyMove(b, legalMoves(b)[0]);
  }
  assert.deepEqual(rollsA, rollsB);
  assert.ok(rollsA.every((v) => v >= 1 && v <= 6));
});

test('AI only plays legal moves and full AI games finish', () => {
  for (let seed = 1; seed <= 20; seed++) {
    const game = createGame({
      seats: FOUR_SEATS.map((s) => ({ ...s, human: false })),
      rng: createRng(seed),
    });
    for (let turn = 0; turn < 20000 && game.phase !== 'over'; turn++) {
      const outcome = rollDice(game);
      if (game.phase === 'move') {
        const choice = chooseMove(game, outcome.moves);
        assert.ok(outcome.moves.includes(choice), 'AI choice is one of the legal moves');
        applyMove(game, choice);
      }
    }
    assert.equal(game.phase, 'over', `seed ${seed} finishes`);
    assert.equal(game.rankings.length, 4);
    assert.ok(game.seats.every((seat) => seat.rank !== null));
    assert.ok(game.seats.every((seat) => seat.tokens.every((p) => p === FINISH_PROGRESS)
      || seat.rank !== null), 'ranked seats have finished');
  }
});

test('snapshot is a detached copy of the state', () => {
  const game = scripted([6]);
  const snap = snapshot(game);
  snap.seats[0].tokens[0] = 99;
  assert.equal(game.seats[0].tokens[0], 0);
});
