/**
 * End-to-end smoke test: plays real turns in headless Chromium by clicking the
 * dice and tapping highlighted tokens on the 3D canvas.
 *
 *   npm run serve   (in one terminal, serves the repo on :8080)
 *   node tests/e2e/play.mjs [outDir]
 *
 * Requires Playwright. Set CHROME_PATH to a Chromium binary if the default
 * launch fails.
 */
import { createRequire } from 'module';
import { mkdirSync } from 'fs';
import { join } from 'path';

const require = createRequire(process.env.PLAYWRIGHT_FROM || import.meta.url);
const { chromium } = require('playwright');

const BASE = process.env.BASE_URL || 'http://localhost:8080/index.html';
const OUT = process.argv[2] || 'screenshots';
mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (cond, msg) => {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${msg}`);
  if (!cond) failures.push(msg);
};

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || '/opt/pw-browsers/chromium',
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

await page.goto(`${BASE}?seed=11&mode=solo&quality=medium`, { waitUntil: 'load' });
await page.waitForFunction(() => window.royalLudo && window.royalLudo.describe(), null, { timeout: 15000 });
check(true, 'page boots and exposes game state');

const state = () => page.evaluate(() => window.royalLudo.describe());
const legal = () => page.evaluate(() => window.royalLudo.legal());

let rolls = 0;
let captures = 0;
let moves = 0;
let lastProgress = null;
let shots = 0;
const startedAt = Date.now();

while (Date.now() - startedAt < 240000) {
  const s = await state();
  if (s.phase === 'over') break;
  const seat = s.seats[s.current];

  if (s.phase === 'roll' && seat.human) {
    const can = await page.evaluate(() => document.body.classList.contains('can-roll'));
    if (can) {
      const p = await page.evaluate(() => window.royalLudo.diceCentre());
      await page.mouse.click(p.x, p.y);
      rolls++;
      await sleep(1600);
      if (rolls === 1) await page.screenshot({ path: join(OUT, 'after-roll.png') });
    } else {
      await sleep(200);
    }
    continue;
  }

  if (s.phase === 'move') {
    const moveable = await legal();
    if (moveable.length > 1 && seat.human) {
      const token = moveable[0];
      if (shots < 2) {
        await page.screenshot({ path: join(OUT, `choose-${shots + 1}.png`) });
        shots++;
      }
      const p = await page.evaluate(([c, i]) => window.royalLudo.tokenCentre(c, i), [seat.color, token]);
      await page.mouse.click(p.x, p.y);
    }
    await sleep(900);
    const after = await state();
    const before = seat.tokens.reduce((a, b) => a + b, 0);
    const now = after.seats.find((x) => x.color === seat.color).tokens.reduce((a, b) => a + b, 0);
    if (now !== before) moves++;
    const enemyBefore = s.seats.flatMap((x) => x.tokens).reduce((a, b) => a + b, 0);
    const enemyAfter = after.seats.flatMap((x) => x.tokens).reduce((a, b) => a + b, 0);
    if (enemyAfter < enemyBefore + (now - before)) captures++;
    lastProgress = after;
    continue;
  }

  await sleep(250); // AI turn in progress
}

await page.screenshot({ path: join(OUT, 'final.png') });
const final = await state();
check(rolls > 0, `human rolled the dice via pointer input (${rolls} rolls)`);
check(moves > 0, `tokens advanced after human moves and AI turns (${moves} moves observed)`);
check(errors.length === 0, `no runtime errors${errors.length ? ': ' + errors.slice(0, 3).join(' | ') : ''}`);
check(final.phase === 'over' || final.seats.some((x) => x.tokens.some((p) => p > 0)), 'game state advanced');
console.log(JSON.stringify({ rolls, moves, captures, phase: final.phase, rankings: final.rankings, tokens: final.seats.map((x) => [x.color, x.tokens]) }));
await browser.close();
if (failures.length) {
  console.error(`\n${failures.length} check(s) failed`);
  process.exit(1);
}
