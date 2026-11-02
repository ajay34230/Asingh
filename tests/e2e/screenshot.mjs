/**
 * Captures screenshots of the running 3D scene at several viewport sizes, for
 * visual review against the reference image.
 *
 *   npm run serve                      (serves the repo on :8080)
 *   node tests/e2e/screenshot.mjs [outDir]
 */
import { createRequire } from 'module';
import { mkdirSync } from 'fs';
import { join } from 'path';

const require = createRequire(process.env.PLAYWRIGHT_FROM || import.meta.url);
const { chromium } = require('playwright');

const BASE = process.env.BASE_URL || 'http://localhost:8080/index.html';
const OUT = process.argv[2] || 'screenshots';
mkdirSync(OUT, { recursive: true });

const VIEWPORTS = [
  { name: 'desktop-1600x900', width: 1600, height: 900 },
  { name: 'phone-landscape-844x390', width: 844, height: 390 },
  { name: 'phone-portrait-390x844', width: 390, height: 844 },
];

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || '/opt/pw-browsers/chromium',
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
});

for (const vp of VIEWPORTS) {
  const page = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(`${BASE}?seed=7&mode=pass&quality=high`, { waitUntil: 'load' });
  await page.waitForFunction(() => window.royalLudo && window.royalLudo.describe(), null, { timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: join(OUT, `${vp.name}.png`) });
  console.log(`${vp.name}: ${errors.length ? 'errors: ' + errors.join(' | ') : 'no runtime errors'}`);
  await page.close();
}

await browser.close();
