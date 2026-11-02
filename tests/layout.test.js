import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  RING, RING_LENGTH, PLAYERS, COLORS, SAFE_RING_INDICES, COMMON_STEPS,
  FINISH_PROGRESS, trackCell, ringIndexForProgress, ringIndexOf, isSafeRing,
  progressPoint, baseSpot,
} from '../src/game/layout.js';

const keyOf = (c, r) => `${c},${r}`;

test('ring has exactly 52 unique common cells on the outer cross perimeter', () => {
  assert.equal(RING.length, RING_LENGTH);
  assert.equal(new Set(RING.map((cell) => keyOf(cell.c, cell.r))).size, RING_LENGTH);
  for (const { c, r } of RING) {
    assert.ok(c >= 0 && c < 15 && r >= 0 && r < 15, `${c},${r} is on the grid`);
    const inCentre = c >= 6 && c <= 8 && r >= 6 && r <= 8;
    assert.ok(!inCentre, `${c},${r} is not in the 3x3 centre`);
    const inHome = (c <= 5 || c >= 9) && (r <= 5 || r >= 9);
    assert.ok(!inHome, `${c},${r} is not inside a courtyard`);
  }
});

test('ring is a closed loop: consecutive cells are adjacent, except the four inner-corner diagonals', () => {
  let diagonals = 0;
  for (let i = 0; i < RING_LENGTH; i++) {
    const a = RING[i];
    const b = RING[(i + 1) % RING_LENGTH];
    const dc = Math.abs(a.c - b.c);
    const dr = Math.abs(a.r - b.r);
    if (dc + dr === 1) continue;
    assert.equal(dc, 1, `step ${i} -> ${i + 1} is a legal step`);
    assert.equal(dr, 1, `step ${i} -> ${i + 1} is a legal step`);
    diagonals++;
  }
  assert.equal(diagonals, 4, 'exactly the four concave corners are diagonal');
});

test('each colour owns one arm; lanes lead from the outer mouth into the centre', () => {
  const laneKeys = new Set();
  for (const color of COLORS) {
    const p = PLAYERS[color];
    const mouth = RING[p.entry];
    const first = p.lane[0];
    assert.equal(Math.abs(mouth.c - first[0]) + Math.abs(mouth.r - first[1]), 1,
      `${color} lane starts next to its entry cell`);
    assert.equal(p.lane.length, 5);
    for (const [c, r] of p.lane) laneKeys.add(keyOf(c, r));
  }
  assert.equal(laneKeys.size, 20, 'four lanes of five unique cells');
});

test('every non-centre, non-courtyard cell of the cross is covered exactly once by track or lane', () => {
  const covered = new Map();
  for (const cell of RING) covered.set(keyOf(cell.c, cell.r), 'ring');
  for (const color of COLORS) {
    for (const [c, r] of PLAYERS[color].lane) {
      assert.ok(!covered.has(keyOf(c, r)), `lane cell ${c},${r} is not also ring`);
      covered.set(keyOf(c, r), `lane-${color}`);
    }
  }
  for (let c = 0; c < 15; c++) {
    for (let r = 0; r < 15; r++) {
      const inCentre = c >= 6 && c <= 8 && r >= 6 && r <= 8;
      const inHome = (c <= 5 || c >= 9) && (r <= 5 || r >= 9);
      if (inCentre || inHome) continue;
      assert.ok(covered.has(keyOf(c, r)), `cross cell ${c},${r} is playable`);
    }
  }
  assert.equal(covered.size, 72);
});

test('start squares are spaced 13 apart and each start is two cells after its entry', () => {
  const starts = COLORS.map((color) => PLAYERS[color].start).sort((a, b) => a - b);
  for (let i = 1; i < starts.length; i++) assert.equal(starts[i] - starts[i - 1], 13);
  for (const color of COLORS) {
    assert.equal(PLAYERS[color].start, (PLAYERS[color].entry + 2) % RING_LENGTH);
  }
});

test('safe squares are the four start squares plus four star squares', () => {
  assert.equal(SAFE_RING_INDICES.length, 8);
  for (const color of COLORS) {
    assert.ok(isSafeRing(PLAYERS[color].start));
    assert.ok(isSafeRing(PLAYERS[color].star));
  }
});

test('every colour walks 51 ring cells and then its five lane cells', () => {
  for (const color of COLORS) {
    const visited = new Set();
    for (let p = 1; p <= COMMON_STEPS; p++) {
      const idx = ringIndexForProgress(color, p);
      visited.add(idx);
    }
    assert.equal(visited.size, COMMON_STEPS);
    assert.equal(ringIndexForProgress(color, 1), PLAYERS[color].start);
    assert.equal(ringIndexForProgress(color, COMMON_STEPS), PLAYERS[color].entry);
    for (let p = 52; p <= 56; p++) {
      assert.equal(trackCell(color, p).kind, 'lane');
    }
    assert.equal(trackCell(color, FINISH_PROGRESS), null);
    assert.equal(trackCell(color, 0), null);
  }
});

test('ringIndexOf round-trips with RING', () => {
  RING.forEach((cell, i) => assert.equal(ringIndexOf(cell.c, cell.r), i));
  assert.equal(ringIndexOf(7, 7), -1);
});

test('courtyard spots sit inside their home and never on the track', () => {
  for (const color of COLORS) {
    const home = PLAYERS[color].home;
    for (let t = 0; t < 4; t++) {
      const { gx, gy } = baseSpot(color, t);
      assert.ok(gx > home.c && gx < home.c + 6 && gy > home.r && gy < home.r + 6);
      assert.equal(ringIndexOf(Math.floor(gx), Math.floor(gy)), -1);
    }
  }
  assert.deepEqual(progressPoint('red', 0, 0), baseSpot('red', 0));
});
