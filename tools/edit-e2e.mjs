// Owner edit-anywhere text, movable/closable AI icon, one-row top controls. Run on a FRESH server: bash /tmp/fresh.sh && node tools/edit-e2e.mjs
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const BASE = process.env.BASE || 'http://localhost:4173', H = { 'Content-Type': 'application/json', 'X-Requested-With': 'asingh' };
let fails = 0; const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
try {
  /* top controls: one row on phones */
  const mc = await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }); const m = await mc.newPage(); const errs = []; m.on('pageerror', e => errs.push(e.message));
  await m.goto(BASE + '/index.html'); await m.waitForSelector('.announce__ctl .themebtn');
  const ys = await m.$$eval('.announce__ctl .themebtn:not([hidden])', els => els.map(e => Math.round(e.getBoundingClientRect().top)));
  ok(ys.length >= 2 && ys.every(y => Math.abs(y - ys[0]) <= 2), 'theme, language (and install) buttons sit in ONE row on a phone (' + ys.join(',') + ')');
  const wd = await m.$$eval('.announce__ctl .themebtn:not([hidden])', els => els.map(e => Math.round(e.getBoundingClientRect().width))); ok(wd.every(w => w >= 70), 'each button is wide enough to tap (' + wd.join(',') + ')');
  ok(await m.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no sideways scroll on the phone');
  /* AI icon: draggable, remembers place, × hides it for good */
  await m.waitForSelector('#aibtn'); ok((await m.locator('#aibtn').innerText()).includes('AI'), 'चंद्रवंशी AI icon is on screen');
  const box0 = await m.locator('#aiwrap').boundingBox(); const cdp = await mc.newCDPSession(m), tx = Math.round(box0.x + 28), ty = Math.round(box0.y + 28);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: tx, y: ty, id: 1 }] }); for (let i = 1; i <= 8; i++) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: tx, y: ty - i * 25, id: 1 }] }); await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await m.waitForTimeout(150);
  const box1 = await m.locator('#aiwrap').boundingBox(); ok(box1.y < box0.y - 150, 'the icon can be dragged to another place'); ok(await m.locator('.chat').count() === 0 || await m.locator('.chat').isHidden(), 'dragging does not open the chat');
  await m.reload(); await m.waitForSelector('#aiwrap'); const box2 = await m.locator('#aiwrap').boundingBox(); ok(Math.abs(box2.y - box1.y) < 4, 'the new position is remembered after a refresh');
  await m.click('#aibtn'); await m.waitForSelector('.chat:not([hidden])'); ok(true, 'tapping (not dragging) opens the chat'); await m.keyboard.press('Escape');
  await m.click('#aix'); await m.waitForTimeout(200); ok(await m.locator('#aiwrap').count() === 0, '× hides the icon');
  await m.reload(); await m.waitForSelector('.footer'); ok(await m.locator('#aiwrap').count() === 0, 'it stays hidden after a refresh');
  await m.evaluate(() => document.querySelector('[data-ai-show]').click()); await m.waitForSelector('#aiwrap'); ok(true, 'the footer link brings it back');
  ok(errs.length === 0, 'no console errors (' + errs.join('|') + ')'); await mc.close();

  /* owner edit mode */
  const dc = await b.newContext({ viewport: { width: 1280, height: 900 } }); const p = await dc.newPage(); const e2 = []; p.on('pageerror', e => e2.push(e.message));
  await p.goto(BASE + '/index.html'); ok(await p.locator('#editbtn').count() === 0, 'shoppers do not see the edit button');
  const login = await p.evaluate(async (h) => { const r = await fetch('/api/auth/login', { method: 'POST', headers: h, body: JSON.stringify({ email: 'admin@asingh.local', password: 'Admin#Pass12345' }) }); return r.status; }, H); ok(login === 200, 'owner signs in');
  await p.goto(BASE + '/index.html?edit=1'); await p.waitForSelector('#ed-ui:not([hidden])'); ok(true, 'edit mode opens from the admin link');
  const hero = p.locator('.hero h1, .hero__title').first(); const before = (await hero.innerText()).trim();
  await hero.click(); await p.waitForSelector('#ed-in'); ok(await p.inputValue('#ed-in') !== '', 'tapping a heading opens the editor with its words'); ok(new URL(p.url()).pathname.endsWith('index.html'), 'edit mode does not follow links');
  await p.fill('#ed-in', 'Brand new heading'); await p.click('#ed-save'); await p.waitForFunction(() => /Brand new heading/.test(document.body.innerText)); ok(true, 'new wording shows at once');
  await p.reload(); await p.waitForFunction(() => /Brand new heading/.test(document.body.innerText)); ok(true, 'and is still there after a refresh');
  await p.goto(BASE + '/index.html?edit=1'); await p.waitForSelector('#ed-ui:not([hidden])');
  const btn = p.locator('.footer a, .footer button').filter({ hasText: /[A-Za-z]{4}/ }).first(); const bt = (await btn.innerText()).trim(); await btn.click(); await p.waitForSelector('#ed-in'); await p.fill('#ed-in', 'Footer words changed'); await p.click('#ed-save'); await p.waitForFunction(() => /Footer words changed/.test(document.body.innerText)); ok(true, 'footer / menu text can be edited too (' + bt + ')');
  await p.click('.nav__link >> nth=0').catch(() => {}); ok(new URL(p.url()).pathname.endsWith('index.html'), 'menus do not navigate while editing'); if (await p.locator('#ed-cancel').count()) await p.click('#ed-cancel');
  await p.locator('.hero h1, .hero__title').first().click(); await p.waitForSelector('#ed-in'); await p.click('#ed-reset'); await p.waitForFunction((t) => document.body.innerText.includes(t), before); ok(true, '“Restore original” puts the old wording back');
  const sec = p.locator('[data-sec="bestsellers"]'); if (await sec.count()) { await sec.locator('[data-ed-hide]').click(); await p.waitForTimeout(400); ok(await p.locator('[data-sec="bestsellers"]').count() === 0, '“Hide this section” removes a whole block'); await p.goto(BASE + '/index.html'); ok(!(await p.locator('[data-sec="bestsellers"]').first().isVisible()), 'it stays hidden for shoppers'); }
  await p.goto(BASE + '/index.html?edit=1'); await p.waitForSelector('#ed-ui:not([hidden])'); await p.click('#ed-done'); ok(await p.locator('#ed-ui').isHidden() && await p.locator('#editbtn').isVisible(), '“Done” leaves edit mode');
  /* Hindi wording */
  await p.evaluate(() => localStorage.setItem('asingh.lang', 'hi')); await p.goto(BASE + '/index.html?edit=1'); await p.waitForSelector('#ed-ui:not([hidden])'); await p.waitForTimeout(500);
  const hi = p.locator('.hero__lead, .hero p').first(); await hi.click(); await p.waitForSelector('#ed-in'); ok(/हिन्दी/.test(await p.textContent('.ed__lang')), 'in Hindi mode the editor edits the Hindi wording'); await p.fill('#ed-in', 'मेरा हिंदी शब्द'); await p.click('#ed-save'); await p.waitForFunction(() => document.body.innerText.includes('मेरा हिंदी शब्द')); ok(true, 'Hindi change appears');
  ok(e2.length === 0, 'no console errors while editing (' + e2.join('|') + ')');
  /* sticky parts switched off from the admin card */
  await p.evaluate(() => localStorage.setItem('asingh.lang', 'en')); await p.goto(BASE + '/admin.html#/store'); await p.waitForSelector('#st-none'); await p.click('#st-none'); await p.waitForTimeout(600);
  const m2 = await (await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true })).newPage(); await m2.goto(BASE + '/product.html?id=jodha-gown'); await m2.waitForSelector('#add-btn'); await m2.waitForTimeout(800);
  ok(await m2.evaluate(() => ['ns-header', 'ns-buy', 'ns-wa', 'ns-ai', 'ns-top', 'ns-panels'].every(c => document.documentElement.classList.contains(c))), 'storefront switches every sticky part off');
  ok(await m2.evaluate(() => getComputedStyle(document.querySelector('.header')).position === 'static' && ['.stickybuy', '.aiwrap', '.totop'].every(s => { const e = document.querySelector(s); return !e || getComputedStyle(e).display === 'none'; })), 'header scrolls away; bottom bar, AI icon and back-to-top are gone');
  await p.click('#st-all'); await p.waitForTimeout(500); await m2.reload(); await m2.waitForSelector('#add-btn'); ok(await m2.evaluate(() => !document.documentElement.className.includes('ns-')), '“Restore all” brings them back');
} catch (e) { console.log('ERR', e.message.split('\n')[0]); fails++; }
await b.close(); console.log(fails ? `\n${fails} FAILED` : '\nEDIT E2E PASS'); process.exit(fails ? 1 : 0);
