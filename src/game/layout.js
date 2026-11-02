/**
 * Board topology: the single source of truth for every cell on the board.
 *
 * Rendering and rules both read from this module, so the visuals and the
 * gameplay can never drift apart.
 *
 * Grid: 15 x 15 cells. (c, r) = (column, row); row 0 is the top edge.
 * Continuous grid coordinates: cell (c, r) covers [c, c + 1] x [r, r + 1].
 *
 * Progress model (per token, per colour):
 *   0            token is in its base (home courtyard)
 *   1 .. 51      common ring cells, starting at the colour's start square
 *   52 .. 56     the five cells of the colour's home lane
 *   57           finished (centre pad)
 */

export const GRID_SIZE = 15;
export const RING_LENGTH = 52;
export const COMMON_STEPS = 51;
export const LANE_STEPS = 5;
export const FINISH_PROGRESS = 57;
export const TOKENS_PER_PLAYER = 4;

/** Turn order is clockwise on screen: red -> green -> yellow -> blue. */
export const COLORS = Object.freeze(['red', 'green', 'yellow', 'blue']);

const key = (c, r) => `${c},${r}`;

/**
 * Builds the 52 outer-ring cells clockwise, starting at the left arm's top row.
 * The four inner corners of the plus-shaped cross are diagonal steps, which is
 * the standard Ludo topology (the 3x3 centre is never part of the track).
 */
function buildRing() {
  const cells = [];
  const add = (c, r) => cells.push([c, r]);
  for (let c = 0; c <= 5; c++) add(c, 6); //        left arm, top row
  for (let r = 5; r >= 0; r--) add(6, r); //        top arm, left column
  add(7, 0); add(8, 0); //                          top arm, top row
  for (let r = 1; r <= 5; r++) add(8, r); //        top arm, right column
  for (let c = 9; c <= 14; c++) add(c, 6); //       right arm, top row
  add(14, 7); add(14, 8); //                        right arm, outer end
  for (let c = 13; c >= 9; c--) add(c, 8); //       right arm, bottom row
  for (let r = 9; r <= 14; r++) add(8, r); //       bottom arm, right column
  add(7, 14); add(6, 14); //                        bottom arm, bottom row
  for (let r = 13; r >= 9; r--) add(6, r); //       bottom arm, left column
  for (let c = 5; c >= 0; c--) add(c, 8); //        left arm, bottom row
  add(0, 7); //                                     left arm, outer end
  return Object.freeze(cells.map(([c, r]) => Object.freeze({ c, r })));
}

/** The 52 common ring cells, index 0 .. 51 clockwise. */
export const RING = buildRing();

const ringIndexByKey = new Map(RING.map((cell, i) => [key(cell.c, cell.r), i]));

/** Derived start and star indices for a colour, given its entry ring index. */
function deriveTrack(entry) {
  const start = (entry + 2) % RING_LENGTH;
  return { start, star: (start + 8) % RING_LENGTH };
}

/**
 * Per-colour configuration. Each colour owns the arm that sits in front of its
 * courtyard, enters its home lane from the outer end of that arm, and starts
 * two ring cells clockwise after its entry.
 */
export const PLAYERS = Object.freeze({
  red: Object.freeze({
    color: 'red', index: 0, home: Object.freeze({ c: 0, r: 0 }),
    entry: 51, ...deriveTrack(51),
    lane: Object.freeze([[1, 7], [2, 7], [3, 7], [4, 7], [5, 7]]),
  }),
  green: Object.freeze({
    color: 'green', index: 1, home: Object.freeze({ c: 9, r: 0 }),
    entry: 12, ...deriveTrack(12),
    lane: Object.freeze([[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]]),
  }),
  yellow: Object.freeze({
    color: 'yellow', index: 2, home: Object.freeze({ c: 9, r: 9 }),
    entry: 25, ...deriveTrack(25),
    lane: Object.freeze([[13, 7], [12, 7], [11, 7], [10, 7], [9, 7]]),
  }),
  blue: Object.freeze({
    color: 'blue', index: 3, home: Object.freeze({ c: 0, r: 9 }),
    entry: 38, ...deriveTrack(38),
    lane: Object.freeze([[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]]),
  }),
});

/** Ring indices that are safe from capture: every start square plus the star squares. */
export const SAFE_RING_INDICES = Object.freeze(
  COLORS.flatMap((color) => [PLAYERS[color].start, PLAYERS[color].star]).sort((a, b) => a - b),
);
const safeSet = new Set(SAFE_RING_INDICES);

export const CENTER_CELL = Object.freeze({ c: 7, r: 7 });

export function isSafeRing(index) {
  return safeSet.has(index);
}

export function ringIndexOf(c, r) {
  const i = ringIndexByKey.get(key(c, r));
  return i === undefined ? -1 : i;
}

/** Ring index visited at a given common-track progress (1 .. 51). */
export function ringIndexForProgress(color, progress) {
  if (!Number.isInteger(progress) || progress < 1 || progress > COMMON_STEPS) {
    throw new RangeError(`progress ${progress} is not a common-track step`);
  }
  return (PLAYERS[color].start + progress - 1) % RING_LENGTH;
}

/** Cell descriptor for a progress value, or null for base / finish. */
export function trackCell(color, progress) {
  if (progress <= 0 || progress >= FINISH_PROGRESS) return null;
  if (progress <= COMMON_STEPS) {
    const index = ringIndexForProgress(color, progress);
    return { kind: 'ring', index, ...RING[index] };
  }
  const [c, r] = PLAYERS[color].lane[progress - COMMON_STEPS - 1];
  return { kind: 'lane', c, r };
}

/** Continuous grid position of a token's courtyard spot (token index 0 .. 3). */
export function baseSpot(color, tokenIndex) {
  const { home } = PLAYERS[color];
  const dx = tokenIndex % 2 === 0 ? 1.5 : 4.5;
  const dy = tokenIndex < 2 ? 1.5 : 4.5;
  return { gx: home.c + dx, gy: home.r + dy };
}

/** Courtyard centre of a colour, where the pavilion stands. */
export function courtyardCentre(color) {
  const { home } = PLAYERS[color];
  return { gx: home.c + 3, gy: home.r + 3 };
}

/**
 * Continuous grid position a token should occupy for a given progress.
 * Used by both the renderer and the tests, so animation paths match the rules.
 */
export function progressPoint(color, progress, tokenIndex = 0) {
  if (progress <= 0) return baseSpot(color, tokenIndex);
  if (progress >= FINISH_PROGRESS) {
    return { gx: CENTER_CELL.c + 0.5 + (tokenIndex % 2 ? 0.22 : -0.22), gy: CENTER_CELL.r + 0.5 + (tokenIndex < 2 ? -0.22 : 0.22) };
  }
  const cell = trackCell(color, progress);
  return { gx: cell.c + 0.5, gy: cell.r + 0.5 };
}

/**
 * Width of the drawn board relative to its height. The logical grid stays square;
 * only the world-space X axis is stretched, so the board reads wider like the reference.
 */
export const BOARD_ASPECT_X = 1.25;

/** Convert continuous grid coordinates to world space (board centred on origin, top surface at y = 0). */
export function toWorld(gx, gy) {
  return { x: (gx - GRID_SIZE / 2) * BOARD_ASPECT_X, z: gy - GRID_SIZE / 2 };
}
