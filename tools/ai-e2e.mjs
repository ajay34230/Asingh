// AI features in the browser against a fake Gemini (no key, no cost). Starts its own server: node tools/ai-e2e.mjs
import http from 'node:http'; import { spawn } from 'node:child_process'; import fs from 'node:fs';
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const PORT = 4181, B = 'http://localhost:' + PORT, DIR = '/tmp/ai-e2e-data'; fs.rmSync(DIR, { recursive: true, force: true });
const seen = [];
const mock = http.createServer((rq, rs) => { let b = ''; rq.on('data', d => b += d); rq.on('end', () => { const j = JSON.parse(b || '{}'), sys = j.systemInstruction.parts[0].text; seen.push({ key: rq.headers['x-goog-api-key'], sys });
  const out = /admin panel/.test(sys) ? { reply: 'Sure — I can set that for you.', goto: 'home', changes: [{ field: 'heroTitle', value: 'Festive Edit' }], textEdit: null }
    : /product copy/.test(sys) ? { blurb: 'A soft georgette anarkali with a zari border.', details: ['Soft georgette', 'Zari border'], seoTitle: 'Georgette Anarkali Suit', seoDesc: 'Soft georgette anarkali for girls.', hiName: 'जॉर्जेट अनारकली', hiBlurb: 'ज़री बॉर्डर वाली नरम जॉर्जेट अनारकली।', cat: 'anarkali', occ: ['festive'], colors: [] }
    : /search filters/.test(sys) ? { occ: ['wedding'] } : /returns the key test/.test(sys) ? {} : { reply: 'Try this lovely piece!', products: ['jodha-gown'] };
  rs.setHeader('content-type', 'application/json'); rs.end(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(out) }] } }] })); }); });
await new Promise(r => mock.listen(5598, '127.0.0.1', r));
const srv = spawn('node', ['server/index.js'], { env: { ...process.env, DATA_DIR: DIR, ADMIN_PASSWORD: 'Admin#Pass12345', PORT: String(PORT), GEMINI_BASE: 'http://127.0.0.1:5598/v1beta', GEMINI_API_KEY: '', AI_STARTER_KEY: 'off' }, stdio: 'ignore' }); await new Promise(r => setTimeout(r, 2200));
let fails = 0; const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };
const br = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
try {
  const ap = await (await br.newContext({ viewport: { width: 1280, height: 900 } })).newPage(); const errs = []; ap.on('pageerror', e => errs.push(e.message));
  await ap.goto(B + '/admin.html'); await ap.fill('input[type=email]', 'admin@asingh.local'); await ap.fill('input[type=password]', 'Admin#Pass12345'); await ap.click('button[type=submit]'); await ap.waitForSelector('.aig__fab', { timeout: 10000 });
  /* key card */
  await ap.evaluate(() => { location.hash = '#/store'; }); await ap.waitForSelector('#ai-key'); ok(/Not connected/.test(await ap.textContent('#ai-state')), 'store settings shows “not connected” without a key');
  await ap.fill('#ai-key', 'bad key!'); await ap.click('#ai-save'); await ap.waitForFunction(() => document.querySelector('#ai-keyerr').textContent.length > 5); ok(true, 'a malformed key shows a clear message');
  await ap.fill('#ai-key', 'AIzaSyFAKEFAKEFAKEFAKEFAKEFAKE12345'); await ap.click('#ai-save'); await ap.waitForFunction(() => /Connected/.test(document.querySelector('#ai-state').textContent)); ok(/AIza…2345/.test(await ap.textContent('#ai-state')) && !(await ap.content()).includes('FAKEFAKEFAKE'), 'the owner changes the key; only a masked copy is shown');
  await ap.click('#ai-test'); await ap.waitForTimeout(500); ok(seen.some(s => s.key === 'AIzaSyFAKEFAKEFAKEFAKEFAKEFAKE12345'), 'Test connection uses the key saved in the panel');
  /* guide */
  await ap.click('.aig__fab'); await ap.waitForSelector('.aig:not([hidden])'); await ap.fill('#aig-in', 'change the hero title to Festive Edit'); await ap.press('#aig-in', 'Enter');
  await ap.waitForSelector('.aig__m--bot button:has-text("Apply")'); ok(true, 'the guide offers an “Apply” button for the change it understood'); ok(await ap.locator('.aig__m--bot button:has-text("Open Home page")').count() === 1, 'and a button that opens the right admin section');
  await ap.click('.aig__m--bot button:has-text("Apply")'); await ap.waitForSelector('.aig__m--bot button:has-text("Done")'); const cat = await ap.evaluate(async () => (await (await fetch('/api/admin/catalog')).json()).site.heroTitle); ok(cat === 'Festive Edit', 'pressing Apply really changes the website');
  /* writing helper */
  await ap.evaluate(() => { location.hash = '#/products'; }); await ap.waitForSelector('.prow__main'); await ap.click('.prow__main'); await ap.waitForSelector('#pf2'); await ap.click('.adm__ai summary'); await ap.click('#ai-go'); await ap.waitForSelector('#ai-apply'); await ap.click('#ai-apply');
  ok((await ap.inputValue('#e-blurb')).includes('georgette') && await ap.inputValue('#e-cat') === 'anarkali', 'writing helper fills the product form after Apply');
  /* edit-words page */
  await ap.keyboard.press('Escape'); await ap.evaluate(() => { location.hash = '#/texts'; }); await ap.waitForSelector('a[href="index.html?edit=1"]'); ok(true, '“Edit any words” page explains the 3 simple steps and opens the live site in edit mode');
  /* shopper chat with Gemini */
  const mob = await (await br.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true })).newPage(); await mob.goto(B + '/index.html'); await mob.waitForSelector('#aibtn'); await mob.click('#aibtn'); await mob.waitForSelector('.chat__chips'); await mob.fill('#chat-in', 'red gown for wedding'); await mob.press('#chat-in', 'Enter'); await mob.waitForSelector('.chat__prod');
  ok(/lovely/.test(await mob.locator('.chat__m--bot').last().innerText()), 'shoppers get the AI answer with a product card'); ok(errs.length === 0, 'no console errors in the admin (' + errs.join('|') + ')');
} catch (e) { console.log('ERR', e.message.split('\n')[0]); fails++; }
await br.close(); srv.kill(); mock.close(); fs.rmSync(DIR, { recursive: true, force: true }); console.log(fails ? `\n${fails} FAILED` : '\nAI E2E PASS'); process.exit(fails ? 1 : 0);
