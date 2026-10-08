// Interaction QA: menu, search, filters, quick add, PDP validation, cart, checkout — on phone, tablet, desktop.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const BASE = 'http://localhost:4173';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
let fails = 0; const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };
for (const [name, w, h, touch] of [['phone', 390, 844, true], ['tablet', 820, 1180, true], ['desktop', 1440, 900, false]]) {
  console.log('\n== ' + name + ' ' + w + 'x' + h);
  const ctx = await b.newContext({ viewport: { width: w, height: h }, hasTouch: touch, isMobile: touch });
  const p = await ctx.newPage(); const errs = []; p.on('pageerror', e => errs.push(String(e)));
  await p.goto(BASE + '/index.html'); await p.waitForSelector('#new-grid .card');
  ok(await p.locator('#new-grid .card').count() === 8, 'home renders 8 new arrivals');
  // menu / mega
  if (w < 1100) { await p.click('.header__menu'); await p.waitForTimeout(350); ok(await p.locator('#menu.is-open').count() === 1, 'menu opens'); await p.screenshot({ path: `/tmp/shots/f-${name}-menu.png` }); await p.keyboard.press('Escape'); await p.waitForTimeout(300); ok(await p.locator('#menu.is-open').count() === 0, 'Esc closes menu'); }
  else { await p.hover('.nav__trigger'); await p.waitForTimeout(250); ok(await p.locator('#mega').isVisible(), 'mega menu opens on hover'); await p.screenshot({ path: `/tmp/shots/f-${name}-mega.png` }); await p.mouse.move(700, 600); await p.waitForTimeout(400); await p.focus('.nav__trigger'); await p.keyboard.press('Enter'); ok(await p.locator('#mega').isVisible(), 'mega opens by keyboard'); await p.keyboard.press('Escape'); }
  // search
  await p.click('.searchpill:not(.searchpill--wide)'); await p.waitForTimeout(300); await p.fill('#q', 'poshak'); await p.waitForTimeout(200);
  ok(await p.locator('.result').count() >= 2, 'search suggests poshak'); await p.screenshot({ path: `/tmp/shots/f-${name}-search.png` }); await p.keyboard.press('Escape'); await p.waitForTimeout(300);
  // shop filters
  await p.goto(BASE + '/shop.html'); await p.waitForSelector('#grid .card');
  ok(await p.locator('#grid .card').count() === 12, 'shop lists 12');
  if (w < 1100) { await p.click('#filter-open'); await p.waitForTimeout(350); await p.screenshot({ path: `/tmp/shots/f-${name}-filters.png` }); await p.check('input[name=cat][value=poshak]', { force: true }); const t = await p.textContent('#apply'); ok(/Show 4/.test(t), 'apply button previews count: ' + t); await p.click('#apply'); await p.waitForTimeout(300); }
  else { await p.check('input[name=cat][value=poshak]', { force: true }); await p.waitForTimeout(200); }
  ok(await p.locator('#grid .card').count() === 4, 'filter → 4 poshak'); ok(await p.locator('#applied .pill').count() === 1, 'applied chip shown'); ok(p.url().includes('cat=poshak'), 'URL reflects filter');
  await p.click('#applied [data-clear]'); await p.waitForTimeout(150); ok(await p.locator('#grid .card').count() === 12, 'Clear all resets');
  // quick add
  if (touch) await p.tap('.card:first-child [data-quick]'); else { await p.hover('.card:first-child'); await p.click('.card:first-child [data-quick]'); }
  await p.waitForTimeout(350); await p.click('#quick-form [type=submit]'); ok(await p.locator('#quick-form .field__err').first().isVisible(), 'quick add requires size');
  await p.screenshot({ path: `/tmp/shots/f-${name}-quick.png` });
  await p.check('#quick-form input[name=qsize][value=M]', { force: true }); await p.click('#quick-form [type=submit]'); await p.waitForTimeout(500);
  ok(await p.evaluate(() => JSON.parse(localStorage.getItem('asingh.cart.v1')).length) === 1, 'quick add puts item in cart');
  if (w >= 700) { ok(await p.locator('#cart.is-open').count() === 1, 'cart drawer opens after add'); await p.screenshot({ path: `/tmp/shots/f-${name}-drawer.png` }); await p.keyboard.press('Escape'); }
  // PDP
  await p.goto(BASE + '/product.html?id=jaipur-bandhani'); await p.waitForSelector('#buy');
  await p.evaluate(() => document.querySelector('#add-btn').click()); await p.waitForTimeout(500);
  ok(await p.locator('#size-err').isVisible(), 'PDP blocks add without size');
  await p.check('input[name=size][value=S]', { force: true }); await p.check('input[name=stitch][value=semi]', { force: true });
  ok((await p.textContent('#pdp-price')).includes('22,400'), 'price follows stitching (22,400)');
  await p.fill('#pin', '400001'); await p.click('#pin-check'); ok(/Delivery to 400001/.test(await p.textContent('#ship-msg')), 'pin check estimates delivery');
  await p.evaluate(() => document.querySelector('#add-btn').click()); await p.waitForTimeout(500);
  ok(await p.evaluate(() => JSON.parse(localStorage.getItem('asingh.cart.v1')).length) === 2, 'PDP add works'); await p.keyboard.press('Escape'); await p.waitForTimeout(300);
  await p.click('[data-zoom="1"]'); await p.waitForTimeout(300); ok(await p.locator('#lightbox.is-open').count() === 1, 'zoom lightbox opens'); await p.keyboard.press('Escape'); await p.waitForTimeout(250);
  await p.click('#pdp [data-wish]'); ok(await p.locator('[data-wish-count]').first().isVisible(), 'wishlist count shown');
  // cart page
  await p.goto(BASE + '/cart.html'); await p.waitForSelector('.line');
  await p.click('.line:first-child [data-qty="1"]'); await p.waitForTimeout(150); ok((await p.textContent('.line:first-child .qty__val')).trim() === '2', 'qty increments');
  await p.screenshot({ path: `/tmp/shots/f-${name}-cart.png` });
  ok(errs.length === 0, 'no JS errors ' + errs.join('|'));
  await ctx.close();
}
await b.close(); console.log(fails ? `\n${fails} FAILED` : '\nALL FLOWS PASS'); process.exit(fails ? 1 : 0);
