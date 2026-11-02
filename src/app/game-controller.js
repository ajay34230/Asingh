/**
 * Connects the rules engine to the 3D view.
 *
 * Flow per turn (async, awaits the animations):
 *   1. Roll: the rules engine decides the value, then the dice animates to it.
 *   2. Move: the human taps a highlighted token (or the only legal move is
 *      auto-played); the AI picks with its heuristic.
 *   3. Animate: the token hops square by square, captures and home entry play,
 *      then the turn passes or a bonus roll is granted.
 *
 * The rules engine is always updated first; the view only follows it, so a
 * slow animation can never desynchronise the game.
 */
import {
  createGame, rollDice, applyMove, legalMoves, currentSeat,
} from '../game/rules.js';
import { chooseMove } from '../game/ai.js';
import { COLORS, progressPoint, toWorld } from '../game/layout.js';
import { TRACK_Y, BASE_Y } from '../render/tokens.js';
import { easeInOutQuad } from '../render/effects.js';

export const MODES = Object.freeze({
  solo: {
    label: 'You vs 3 bots',
    seats: [
      { color: 'red', human: true }, { color: 'green', human: false },
      { color: 'yellow', human: false }, { color: 'blue', human: false },
    ],
  },
  duel: {
    label: 'You vs 1 bot',
    seats: [{ color: 'red', human: true }, { color: 'yellow', human: false }],
  },
  pass: {
    label: 'Pass and play (4 players)',
    seats: COLORS.map((color) => ({ color, human: true })),
  },
});

const HOP_SECONDS = 0.16;
const AI_THINK_SECONDS = 0.55;
const AUTO_MOVE_SECONDS = 0.35;
const CAPTURE_SECONDS = 0.5;

const NAMES = { red: 'Red', green: 'Green', yellow: 'Yellow', blue: 'Blue' };

export class GameController {
  /**
   * @param {object} deps
   * @param {Record<string, object[]>} deps.tokensByColor token views, 4 per colour
   * @param {object} deps.dice Dice view
   * @param {object} deps.tweens Tweens scheduler
   * @param {object} deps.sparks SparkBurst effect
   * @param {object} deps.confetti Confetti effect
   * @param {object} deps.hud UI adapter
   * @param {() => number} deps.rng uniform random source for the dice
   */
  constructor({ tokensByColor, dice, tweens, sparks, confetti, hud, rng }) {
    this.tokensByColor = tokensByColor;
    this.dice = dice;
    this.tweens = tweens;
    this.sparks = sparks;
    this.confetti = confetti;
    this.hud = hud;
    this.rng = rng;

    this.game = null;
    this.mode = 'solo';
    this.generation = 0;
    this.awaitingRoll = false;
    this.awaitingPick = null;
    this.resolveRoll = null;
    this.resolvePick = null;
    this.legalPicks = [];
  }

  get seatCount() {
    return this.game ? this.game.seats.length : 0;
  }

  /** Starts a new game in the given mode, cancelling any game in progress. */
  start(mode = 'solo') {
    this.cancelPending();
    this.generation++;
    this.mode = MODES[mode] ? mode : 'solo';
    this.game = createGame({
      seats: MODES[this.mode].seats.map((seat) => ({ ...seat })),
      rng: this.rng,
    });

    for (const color of COLORS) {
      for (const token of this.tokensByColor[color]) {
        token.progress = 0;
        token.placeAtProgress(0);
        token.setHighlight(false);
      }
    }
    this.dice.cancel();
    this.dice.setFace(1, 0);
    this.confetti.stop();
    this.hud.hideResult();
    this.hud.setRoll('');
    this.hud.announce(`New game: ${MODES[this.mode].label}`, 'info');

    const generation = this.generation;
    this.loop(generation).catch((error) => {
      console.error(error);
      this.hud.announce('Something went wrong. Start a new game.', 'error');
    });
  }

  /** Stops every pending wait so an old loop exits cleanly. */
  cancelPending() {
    this.tweens.clear();
    if (this.resolveRoll) this.resolveRoll(false);
    if (this.resolvePick) this.resolvePick(-1);
    this.resolveRoll = null;
    this.resolvePick = null;
    this.awaitingRoll = false;
    this.awaitingPick = null;
    this.legalPicks = [];
    for (const color of COLORS) {
      for (const token of this.tokensByColor[color]) token.setHighlight(false);
    }
  }

  isCurrent(generation) {
    return generation === this.generation;
  }

  async loop(generation) {
    while (this.isCurrent(generation) && this.game.phase !== 'over') {
      const seat = currentSeat(this.game);
      this.hud.setTurn(seat.color, seat.human, this.mode);

      if (seat.human) {
        const ok = await this.waitForRoll(generation);
        if (!ok || !this.isCurrent(generation)) return;
      } else {
        await this.tweens.wait(AI_THINK_SECONDS);
        if (!this.isCurrent(generation)) return;
      }

      const rolledSeat = this.game.current;
      await this.performRoll(rolledSeat, generation);
      if (!this.isCurrent(generation)) return;

      if (this.game.phase === 'move') {
        await this.resolveMove(generation, rolledSeat);
        if (!this.isCurrent(generation)) return;
      }
    }

    if (this.isCurrent(generation) && this.game.phase === 'over') {
      await this.finishGame();
    }
  }

  /** Human taps on the dice call this. Ignored unless the dice is waiting for us. */
  requestRoll() {
    if (!this.awaitingRoll || this.dice.busy) return false;
    this.awaitingRoll = false;
    const resolve = this.resolveRoll;
    this.resolveRoll = null;
    resolve(true);
    return true;
  }

  waitForRoll(generation) {
    this.awaitingRoll = true;
    this.hud.setRollEnabled(true);
    return new Promise((resolve) => {
      this.resolveRoll = (ok) => {
        this.hud.setRollEnabled(false);
        resolve(ok && this.isCurrent(generation));
      };
    });
  }

  /** Rolls via the rules engine, then animates the dice to the decided value. */
  async performRoll(seatIndex, generation) {
    const seat = this.game.seats[seatIndex];
    this.hud.setRollEnabled(false);
    const outcome = rollDice(this.game);
    // Presentation randomness (spin axis, yaw) uses Math.random, never the game RNG.
    await this.dice.roll(outcome.value);
    if (!this.isCurrent(generation)) return;

    this.hud.setRoll(`${NAMES[seat.color]} rolled ${outcome.value}`);
    if (outcome.forfeited) {
      this.hud.announce(`${NAMES[seat.color]} rolled three 6s in a row. Turn lost.`, 'warn');
    } else if (outcome.passed) {
      this.hud.announce(`No legal move for ${NAMES[seat.color]}.`, 'info');
    }
    await this.tweens.wait(0.3);
  }

  /** Chooses (human: tap or auto) and animates the move for the rolled seat. */
  async resolveMove(generation, seatIndex) {
    const seat = this.game.seats[seatIndex];
    const moves = legalMoves(this.game);
    let token;

    if (seat.human && moves.length > 1) {
      token = await this.waitForPick(generation, moves, seat.color);
      if (token < 0 || !this.isCurrent(generation)) return;
    } else if (seat.human) {
      token = moves[0];
      await this.tweens.wait(AUTO_MOVE_SECONDS);
    } else {
      token = chooseMove(this.game, moves);
      await this.tweens.wait(AI_THINK_SECONDS * 0.6);
    }
    if (!this.isCurrent(generation)) return;

    await this.animateMove(token, seat, generation);
  }

  waitForPick(generation, moves, color) {
    this.legalPicks = moves;
    this.awaitingPick = color;
    for (const token of this.tokensByColor[color]) token.setHighlight(moves.includes(token.index));
    this.hud.announce(`Tap a highlighted ${NAMES[color]} token`, 'info');
    return new Promise((resolve) => {
      this.resolvePick = (index) => {
        this.resolvePick = null;
        this.legalPicks = [];
        this.awaitingPick = null;
        for (const t of this.tokensByColor[color]) t.setHighlight(false);
        resolve(this.isCurrent(generation) ? index : -1);
      };
    });
  }

  /** Token tap from the input layer. */
  tapToken(token) {
    if (!this.awaitingPick || !this.resolvePick) return false;
    if (token.color !== this.awaitingPick || !this.legalPicks.includes(token.index)) return false;
    this.resolvePick(token.index);
    return true;
  }

  async animateMove(tokenIndex, seat, generation) {
    const view = this.tokensByColor[seat.color][tokenIndex];
    const from = seat.tokens[tokenIndex];

    // The rules are authoritative: apply first, then animate the change.
    const seatIndex = this.game.current; // read before applyMove, which may advance the turn
    const result = applyMove(this.game, tokenIndex);
    const to = result.to;

    for (let p = from + 1; p <= to; p++) {
      if (!this.isCurrent(generation)) return;
      const a = this.worldOf(seat.color, p - 1, tokenIndex);
      const b = this.worldOf(seat.color, p, tokenIndex);
      const duration = from === 0 ? 0.42 : HOP_SECONDS;
      const arc = from === 0 ? 0.7 : 0.22;
      await this.hop(view, a, b, duration, arc);
      if (!this.isCurrent(generation)) return; // a new game started; stop touching the views
      view.progress = p;
    }
    view.progress = to;
    view.placeAtProgress(to);

    const captureTasks = result.captured.map((cap) => this.capture(cap, generation));
    if (result.captured.length > 0) {
      const victim = result.captured[0];
      this.hud.announce(`Captured a ${NAMES[this.game.seats[victim.seat].color]} token!`, 'good');
    }
    await Promise.all(captureTasks);
    if (!this.isCurrent(generation)) return;

    if (result.finishes) {
      const centre = toWorld(7.5, 7.5);
      this.sparks.fire(centre.x, TRACK_Y + 0.2, centre.z, this.tweens);
      await this.tweens.wait(0.1);
    }

    if (result.seatFinished) {
      const rank = this.game.seats[seatIndex].rank;
      const ordinal = ['1st', '2nd', '3rd', '4th'][rank - 1];
      this.hud.announce(`${NAMES[seat.color]} finished ${ordinal}!`, 'good');
    } else if (result.extraTurn) {
      this.hud.announce(`${NAMES[seat.color]} gets a bonus roll`, 'good');
    }
  }

  /** Animates the victim of a capture back to its base, with a spark burst where it stood. */
  async capture(cap, generation) {
    const color = this.game.seats[cap.seat].color;
    const token = this.tokensByColor[color][cap.token];
    const oldProgress = token.progress;
    const here = this.worldOf(color, oldProgress, cap.token);
    this.sparks.fire(here.x, here.y + 0.2, here.z, this.tweens);
    const base = this.worldOf(color, 0, cap.token);
    await this.hop(token, here, base, CAPTURE_SECONDS, 0.9);
    if (!this.isCurrent(generation)) return;
    token.progress = 0;
    token.placeAtProgress(0);
  }

  /** Smooth arc from world point `a` to `b` over `duration` seconds. */
  hop(view, a, b, duration, arc) {
    return this.tweens.run(duration, (t) => {
      const e = easeInOutQuad(t);
      const x = a.x + (b.x - a.x) * e;
      const z = a.z + (b.z - a.z) * e;
      const y = a.y + (b.y - a.y) * e + Math.sin(Math.PI * t) * arc;
      view.setPosition(x, y, z);
    });
  }

  worldOf(color, progress, tokenIndex) {
    const { gx, gy } = progressPoint(color, progress, tokenIndex);
    const { x, z } = toWorld(gx, gy);
    return { x, y: progress === 0 ? BASE_Y : TRACK_Y, z };
  }

  async finishGame() {
    const ranking = this.game.rankings.map((index, i) => ({
      place: i + 1,
      color: this.game.seats[index].color,
      human: this.game.seats[index].human,
    }));
    if (ranking[0]?.human) this.confetti.start();
    this.hud.setTurn(null, false, this.mode);
    this.hud.showResult(ranking, this.mode);
  }

  /** Current snapshot for tests and the debug hook. */
  describe() {
    if (!this.game) return null;
    return {
      phase: this.game.phase,
      current: this.game.current,
      dice: this.game.dice,
      rankings: [...this.game.rankings],
      seats: this.game.seats.map((seat) => ({ color: seat.color, human: seat.human, tokens: [...seat.tokens], rank: seat.rank })),
    };
  }
}

export { NAMES };
