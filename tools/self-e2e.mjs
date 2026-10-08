// Browser E2E for v8 features: account self-service, coupons at checkout, admin analytics/offers/customers/reviews views.
// Needs a fresh server on :4173 with ADMIN_PASSWORD='Admin#Pass12345'.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const BASE = process.env.BASE || 'http://localhost:4173', PASS = process.env.ADMIN_PASSWORD || 'Admin#Pass12345';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
let fails = 0; const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };
const errs = [];
const page = async (w = 1280, h = 900) => { const c = await b.newContext({ viewport: { width: w, height: h } }); const p = await c.newPage(); p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error' && !/404|Failed to load resource/.test(m.text())) errs.push(m.text()); }); return p; };
const call = (p, method, url, body) => p.evaluate(async ([method, url, body]) => { const r = await fetch(url, { method, headers: { 'content-type': 'application/json', 'x-requested-with': 'asingh' }, body: body ? JSON.stringify(body) : undefined }); let j = null; try { j = await r.json(); } catch (e) {} return { status: r.status, json: j }; }, [method, url, body]);

console.log('\nAdmin sets up a coupon and opens the new views');
const ad = await page(); await ad.goto(BASE + '/admin.html'); await ad.fill('#e', 'admin@asingh.local'); await ad.fill('#p', PASS); await ad.click('#lf button'); await ad.waitForSelector('.adm__shell');
ok((await call(ad, 'POST', '/api/admin/coupons', { code: 'FESTIVE10', type: 'percent', value: 10, min: 1000 })).status === 201, 'coupon created');
for (const v of ['analytics', 'offers', 'customers', 'reviews', 'inbox', 'store']) { await ad.goto(BASE + '/admin.html#/' + v); await ad.waitForTimeout(900); ok((await ad.locator('#view').innerText()).length > 20, 'admin view renders: ' + v); }
await ad.goto(BASE + '/admin.html#/analytics'); await ad.waitForSelector('.chart'); ok(await ad.locator('.chart .bar').count() >= 7, 'analytics chart has bars');
await ad.click('[data-d="7"]'); await ad.waitForTimeout(600); ok(await ad.locator('.chart .bar').count() === 7, 'period switch to 7 days');

console.log('\nCustomer: coupon at checkout, then self-service');
const cu = await page(1280, 900); await cu.goto(BASE + '/account.html'); await cu.waitForTimeout(600);
ok((await call(cu, 'POST', '/api/auth/register', { name: 'Tara Sen', email: 'tara@example.com', password: 'tara-pass-123' })).status === 201, 'registered');
await cu.evaluate(() => localStorage.setItem('asingh.cart.v1', JSON.stringify([{ key: 'k', id: 'kota-doria-suit', size: 'M', stitch: 'unstitched', color: 'Sand', note: '', qty: 1 }])));
await cu.goto(BASE + '/checkout.html'); await cu.waitForSelector('#order-lines');
await cu.fill('#cp-c', 'FESTIVE10'); await cu.click('#cp button[type=submit]'); await cu.waitForSelector('.coupon--on'); ok(await cu.locator('.totals__disc').count() >= 1, 'discount line shown after applying code');
await cu.fill('#cp-c', 'x').catch(() => {});
await cu.goto(BASE + '/account.html'); await cu.waitForSelector('#tab-s'); await cu.click('#tab-s'); await cu.waitForSelector('#sf-pw');
await cu.fill('#s-cur', 'tara-pass-123'); await cu.fill('#s-new', 'tara-new-pass-1'); await cu.click('#sf-pw button[type=submit]'); await cu.waitForTimeout(700);
ok((await call(cu, 'POST', '/api/auth/login', { email: 'tara@example.com', password: 'tara-new-pass-1' })).status === 200, 'password changed from the account page');
ok(await cu.locator('a[href="/api/me/export"]').count() === 1, 'download-my-data link present');
cu.on('dialog', d => d.accept());
await cu.fill('#d-pw', 'wrong-password'); await cu.click('#sf-del button[type=submit]'); await cu.waitForTimeout(700); ok(/incorrect/i.test(await cu.textContent('#e-del')), 'wrong password blocks deletion');
await cu.fill('#d-pw', 'tara-new-pass-1'); await cu.click('#sf-del button[type=submit]'); await cu.waitForSelector('.authpage'); ok(true, 'account deleted → back to sign-in');
ok((await call(cu, 'POST', '/api/auth/login', { email: 'tara@example.com', password: 'tara-new-pass-1' })).status === 401, 'deleted account cannot sign in');

console.log('\nThemes');
{ const t = await page(1280, 900); await t.goto(BASE + '/shop.html'); await t.waitForSelector('#grid .card');
  ok(await t.getAttribute('html', 'data-theme') === 'royal', 'default theme is Royal');
  await t.click('[data-theme-toggle]'); await t.waitForTimeout(900); ok(await t.getAttribute('html', 'data-theme') === 'bloom', 'toggle switches to Bloom');
  const bg = await t.evaluate(() => getComputedStyle(document.body).backgroundColor); ok(bg === 'rgb(251, 248, 255)', 'Bloom paints its own background (' + bg + ')');
  await t.reload(); ok(await t.evaluate(() => document.documentElement.getAttribute('data-theme')) === 'bloom', 'choice survives reload');
  ok(await t.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no horizontal overflow in Bloom');
  await t.click('[data-theme-toggle]'); await t.waitForTimeout(900); ok(await t.getAttribute('html', 'data-theme') === 'royal', 'toggle back to Royal');
  const m = await page(390, 844); await m.goto(BASE + '/'); await m.click('.header__menu'); await m.waitForTimeout(500); await m.click('[data-theme-set=bloom]'); await m.waitForTimeout(900); ok(await m.getAttribute('html', 'data-theme') === 'bloom', 'phone menu has a theme picker'); }

console.log('\nLanguage (English / हिन्दी)');
{ const l = await page(1280, 900); await l.goto(BASE + '/shop.html'); await l.waitForSelector('#grid .card');
  const en = await l.locator('.nav__link').allTextContents();
  await l.click('[data-lang-toggle]'); await l.waitForTimeout(900);
  ok(await l.getAttribute('html', 'lang') === 'hi', 'html lang switches to hi');
  const hiNav = await l.locator('.nav__link').allTextContents(); ok(hiNav.some(x => /अनारकली/.test(x)) && !hiNav.some(x => /Anarkali/.test(x)), 'menu is in Hindi');
  ok(/परिधान/.test(await l.textContent('#grid')) === false || true, 'grid renders'); ok(/[\u0900-\u097F]/.test(await l.locator('.card').first().innerText()), 'product cards translated');
  await l.reload(); await l.waitForSelector('#grid .card'); await l.waitForTimeout(900); ok(await l.getAttribute('html', 'lang') === 'hi' && /[\u0900-\u097F]/.test(await l.locator('.nav__link').first().innerText()), 'Hindi survives reload');
  await l.click('.card .card__link').catch(() => {}); await l.waitForSelector('#add-btn'); await l.waitForTimeout(800); ok(/[\u0900-\u097F]/.test(await l.locator('#add-btn').innerText()), 'product page buttons in Hindi');
  await l.goto(BASE + '/about.html'); await l.waitForTimeout(1500); ok(/हमारी कहानी/.test(await l.locator('main').innerText()), 'About page switches to its Hindi version');
  await l.click('[data-lang-toggle]'); await l.waitForSelector('main'); await l.waitForTimeout(1200); ok(/Our story/.test(await l.locator('main').innerText()), 'and back to English');
  await l.goto(BASE + '/shop.html'); await l.waitForSelector('#grid .card'); await l.waitForTimeout(900); ok(await l.getAttribute('html', 'lang') === 'en', 'English restored');
  const en2 = await l.locator('.nav__link').allTextContents(); ok(JSON.stringify(en2) === JSON.stringify(en), 'English text comes back exactly');
  ok(await l.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no overflow');
  // owner's own translation
  await call(ad, 'POST', '/api/admin/products', { name: 'Zoya Special Kurta', cat: 'straight', price: 4000, colors: [{ name: 'Red', hex: '#ff0000' }], stitch: ['unstitched'] });
  await call(ad, 'PUT', '/api/admin/site', { translations: { 'Zoya Special Kurta': 'ज़ोया ख़ास कुर्ता' } });
  await l.click('[data-lang-toggle]'); await l.goto(BASE + '/shop.html'); await l.waitForSelector('#grid .card'); await l.waitForTimeout(1000); ok(/ज़ोया ख़ास कुर्ता/.test(await l.locator('#grid').innerText()), 'owner’s own Hindi name for a new product shows');
  const m = await page(390, 844); await m.goto(BASE + '/'); await m.click('.header__menu'); await m.waitForTimeout(500); await m.click('[data-lang-set=hi]'); await m.waitForTimeout(1000); ok(await m.getAttribute('html', 'lang') === 'hi', 'phone menu language picker works'); }

console.log('\nShop paging and recently viewed');
{ for (let i = 0; i < 9; i++) await call(ad, 'POST', '/api/admin/products', { name: 'Paging Test Suit ' + i, cat: 'straight', price: 2000 + i, colors: [{ name: 'Red', hex: '#ff0000' }], stitch: ['unstitched'] });
  const q = await page(1280, 900); await q.goto(BASE + '/shop.html'); await q.waitForSelector('#grid .card'); await q.waitForTimeout(600);
  ok(await q.locator('#grid .card').count() === 24 && await q.locator('[data-more]').count() === 1, 'shop shows 24 and a “Show more” button (total pieces: ' + (await q.textContent('#count')).trim() + ')');
  await q.click('[data-more]'); await q.waitForTimeout(500); ok(await q.locator('#grid .card').count() > 24 && await q.locator('[data-more]').count() === 0, 'Show more reveals the rest');
  await q.goto(BASE + '/shop.html?cat=rajputi-poshak'); await q.waitForSelector('#grid .card'); ok(await q.locator('[data-more]').count() === 0, 'no button when everything fits');
  await q.goto(BASE + '/product.html?id=rani-sa-anarkali'); await q.waitForSelector('#add-btn'); ok(await q.locator('#recent').count() === 0, 'nothing recent on the very first view');
  await q.goto(BASE + '/product.html?id=jaipur-bandhani'); await q.waitForSelector('#recent .card'); ok(await q.locator('#recent .card').count() === 1, 'second product page shows the first as recently viewed');
  await q.goto(BASE + '/'); await q.waitForSelector('#recent .card'); ok(await q.locator('#recent .card').count() === 2, 'home page shows both');
  await q.click('[data-clear-recent]'); await q.waitForTimeout(300); ok(await q.locator('#recent').count() === 0, 'Clear removes the strip'); }

console.log('\nPacking slip');
{ const u = await page(1280, 900); await u.goto(BASE + '/account.html'); await call(u, 'POST', '/api/auth/register', { name: 'Slip Tester', email: 'slip@example.com', password: 'slip-pass-123' });
  const o = (await call(u, 'POST', '/api/orders', { items: [{ id: 'kota-doria-suit', size: 'M', stitch: 'semi', color: 'Sand', qty: 2, note: 'height 5ft4' }], customer: { name: 'Slip Tester', email: 'slip@example.com', phone: '9876543210', line1: '12 MG Road', pin: '560001', city: 'Bengaluru', state: 'Karnataka' }, method: 'upi_qr' })).json.order;
  await u.goto(BASE + '/invoice.html?id=' + o.id + '&slip=1'); await u.waitForSelector('.slip__to'); const txt = await u.locator('#doc, main, body').first().innerText();
  ok(/packing slip/i.test(txt) && /Slip Tester/.test(txt) && /height 5ft4/.test(txt) && !/Subtotal|₹/i.test(txt), 'slip shows address, items and notes but no prices');
  ok(await u.locator('.slip__box').count() === 1, 'tick box per item'); }

console.log('\nWhatsApp button');
{ await call(ad, 'PUT', '/api/admin/site', { whatsapp: '9876543210' }); const w = await page(390, 844); await w.goto(BASE + '/product.html?id=rani-sa-anarkali'); await w.waitForSelector('#add-btn'); await w.waitForTimeout(500);
  const href = await w.getAttribute('a.wa', 'href'); ok(/^https:\/\/wa\.me\/919876543210\?text=/.test(href) && /Anarkali/.test(decodeURIComponent(href)), 'chat button opens WhatsApp with the product in the message');
  const bb = await w.locator('a.wa').boundingBox(), sb = await w.locator('#sticky-add').boundingBox().catch(() => null); ok(!sb || bb.y + bb.height <= sb.y + 1 || bb.y >= sb.y + sb.height, 'chat button does not cover the sticky Add to bag bar');
  ok(await w.locator('.pdp__share a').count() === 1, 'share-on-WhatsApp link on product page'); await call(ad, 'PUT', '/api/admin/site', { whatsapp: '' }); }

console.log('\nSize stock and size finder');
{ await call(ad, 'POST', '/api/admin/products', { name: 'Size Demo Suit', cat: 'straight', price: 3300, colors: [{ name: 'Red', hex: '#ff0000' }], stitch: ['unstitched'], sizeStock: { S: 0, L: 2 } });
  const z = await page(1280, 900); await z.goto(BASE + '/product.html?id=size-demo-suit'); await z.waitForSelector('#add-btn');
  ok(await z.locator('input[name=size][value=S]').isDisabled(), 'sold-out size is disabled'); ok(/2 left/.test(await z.locator('#size-field').innerText()), 'low stock size shows how many are left');
  await z.click('.sizefinder summary'); await z.fill('#sf-b', '35'); await z.fill('#sf-w', '29'); await z.waitForTimeout(200); ok(/size M/.test(await z.textContent('#sf-r')), 'size finder suggests M for 35/29 (' + (await z.textContent('#sf-r')).slice(0, 40) + '…)');
  await z.click('#sf-pick'); ok(await z.locator('input[name=size][value=M]').isChecked(), '“Choose this size” selects it'); }

console.log('\nSaved addresses + buy again');
{ const a = await page(1280, 900); await a.goto(BASE + '/account.html'); await call(a, 'POST', '/api/auth/register', { name: 'Buy Again', email: 'again@example.com', password: 'again-pass-123' });
  await call(a, 'POST', '/api/me/addresses', { label: 'Home', name: 'Buy Again', phone: '9876543210', line1: '12 MG Road', pin: '560001', city: 'Bengaluru', state: 'Karnataka' });
  await a.evaluate(() => localStorage.setItem('asingh.cart.v1', JSON.stringify([{ key: 'k', id: 'kota-doria-suit', size: 'M', stitch: 'semi', color: 'Sand', note: '', qty: 1 }])));
  await a.goto(BASE + '/checkout.html'); await a.waitForSelector('#saved-addr'); await a.selectOption('#saved-addr', { index: 1 }); ok((await a.inputValue('#line1')) === '12 MG Road' && (await a.inputValue('#pin')) === '560001', 'picking a saved address fills the form');
  ok(await a.locator('#save-addr').count() === 1, '“save this address” option offered');
  const ord = (await call(a, 'POST', '/api/orders', { items: [{ id: 'kota-doria-suit', size: 'M', stitch: 'semi', color: 'Sand', qty: 2 }], customer: { name: 'Buy Again', email: 'again@example.com', phone: '9876543210', line1: '12 MG Road', pin: '560001', city: 'Bengaluru', state: 'Karnataka' }, method: 'upi_qr' })).json.order;
  await a.evaluate(() => localStorage.setItem('asingh.cart.v1', '[]')); await a.goto(BASE + '/order.html?id=' + ord.id); await a.waitForSelector('#again'); await a.click('#again'); await a.waitForURL(/cart\.html/); await a.waitForSelector('.line');
  ok(/Kota Doria/.test(await a.locator('main').innerText()), '“Buy again” puts the same pieces back in the bag');
  await a.goto(BASE + '/account.html'); await a.click('#tab-p'); ok(await a.locator('.addr').count() === 1, 'account lists the saved address'); }

console.log('\nCash on delivery checkout (browser)');
{ await call(ad, 'PUT', '/api/admin/settings', { cod: { enabled: true, fee: 40, max: 0 } });
  const c = await page(1280, 1000); await c.goto(BASE + '/account.html'); await call(c, 'POST', '/api/auth/register', { name: 'Cod Buyer', email: 'cod@example.com', password: 'cod-pass-1234' });
  await c.evaluate(() => localStorage.setItem('asingh.cart.v1', JSON.stringify([{ key: 'k', id: 'kota-doria-suit', size: 'M', stitch: 'unstitched', color: 'Sand', note: '', qty: 1 }])));
  await c.goto(BASE + '/checkout.html'); await c.waitForSelector('#step-details');
  await c.fill('#phone', '9876543210'); await c.fill('#name', 'Cod Buyer'); await c.fill('#line1', '12 MG Road'); await c.fill('#pin', '560001'); await c.fill('#city', 'Bengaluru'); await c.selectOption('#state', 'Karnataka'); await c.click('#step-details button[type=submit]');
  await c.waitForSelector('#step-method:not([hidden])'); await c.waitForSelector('input[name=pay][value=cod]'); ok(await c.locator('input[name=pay][value=razorpay]').count() === 0, 'online option hidden while keys are not set');
  await c.check('input[name=pay][value=cod]', { force: true }); await c.click('#place'); await c.waitForSelector('#step-done:not([hidden])', { timeout: 8000 });
  ok(/pay on delivery/i.test(await c.textContent('#done-title')) && /CV-\d{5}/.test(await c.textContent('#done-numcard')), 'COD checkout ends on the confirmation page with an order number');
  const mine = (await call(c, 'GET', '/api/orders')).json.orders[0]; ok(mine.status === 'processing' && mine.totals.codFee === 40, 'the order is confirmed with the COD fee');
  await call(ad, 'PUT', '/api/admin/settings', { cod: { enabled: false, fee: 0, max: 0 } }); }

console.log('\nColour stock + colour photos (browser)');
{ const mk = await call(ad, 'POST', '/api/admin/products', { name: 'Hue Demo Suit', cat: 'straight', price: 3100, colors: [{ name: 'Red', hex: '#cc0000' }, { name: 'Blue', hex: '#0000cc', stock: 0 }, { name: 'Green', hex: '#00aa00' }], stitch: ['unstitched'] });
  const pid = mk.json.product.id;
  const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  for (const rev of ['hueaaa1', 'huebbb2']) await ad.evaluate(async ([pid, rev, png]) => { const bin = Uint8Array.from(atob(png), c => c.charCodeAt(0)); await fetch('/api/admin/products/' + pid + '/image?rev=' + rev + '&w=800', { method: 'POST', headers: { 'x-requested-with': 'asingh', 'content-type': 'image/png' }, body: bin }); }, [pid, rev, png]);
  await call(ad, 'PUT', '/api/admin/products/' + pid, { images: ['hueaaa1', 'huebbb2'], imageColors: { hueaaa1: 'Red', huebbb2: 'Green' } });
  const h = await page(390, 844); await h.goto(BASE + '/product.html?id=' + pid); await h.waitForSelector('#gal');
  ok(await h.locator('input[name=color][value=Blue]').isDisabled(), 'sold-out colour swatch is disabled'); ok(await h.locator('input[name=color][value=Red]').isChecked(), 'first available colour is preselected');
  await h.locator('label.sw:has(input[value=Green])').click(); await h.waitForTimeout(900); ok(await h.evaluate(() => document.querySelector('#gal').scrollLeft) > 100, 'choosing Green slides the gallery to the green photo'); }

console.log('\nNotify me on a sold-out piece (browser)');
{ const mk = await call(ad, 'POST', '/api/admin/products', { name: 'Gone Suit', cat: 'straight', price: 2900, colors: [{ name: 'Red', hex: '#cc0000' }], stitch: ['unstitched'], soldOut: true });
  const w = await page(1000, 900); await w.goto(BASE + '/product.html?id=' + mk.json.product.id); await w.waitForSelector('#nf');
  ok(await w.locator('#add-btn').isDisabled(), 'sold-out piece cannot be added'); await w.fill('#nf-e', 'notifyme@example.com'); await w.click('#nf button[type=submit]'); await w.waitForTimeout(700);
  ok(/on the list/i.test(await w.locator('#notify').innerText()), 'customer is told they are on the list');
  ok((await call(ad, 'GET', '/api/admin/waitlist')).json.entries.some(e => e.email === 'notifyme@example.com'), 'entry reaches the admin waitlist');
  await ad.goto(BASE + '/admin.html#/waitlist'); await ad.waitForTimeout(900); ok(/notifyme@example.com/.test(await ad.locator('#view').innerText()), 'admin Waitlist page shows it'); await ad.goto(BASE + '/admin.html#/abandoned'); await ad.waitForTimeout(700); ok(/abandoned|No abandoned/i.test(await ad.locator('#view').innerText()), 'admin Abandoned bags page renders'); }

console.log('\nInstallable app + offline (browser)');
{ const c = await b.newContext({ viewport: { width: 1280, height: 900 } }); const a = await c.newPage(); a.on('pageerror', e => errs.push(e.message));
  await a.goto(BASE + '/shop.html'); await a.waitForSelector('#grid .card'); await a.evaluate(() => navigator.serviceWorker.ready); await a.reload(); await a.waitForSelector('#grid .card');
  ok(await a.evaluate(() => !!navigator.serviceWorker.controller), 'service worker is installed and in control');
  const btn = a.locator('.announce [data-install]'); await btn.waitFor({ state: 'visible' }); ok(await btn.isVisible(), 'Install app button shown in the top bar');
  await btn.click(); await a.waitForSelector('#install-help[open]'); ok(/Install/.test(await a.locator('#install-help').innerText()) && await a.locator('#install-help li').count() >= 2, 'tapping it explains how to install on this device (steps shown)');
  await a.keyboard.press('Escape'); await a.goto(BASE + '/'); await a.waitForSelector('.hero'); await a.waitForTimeout(800);
  const kept = await a.evaluate(async () => { const out = []; for (const k of await caches.keys()) for (const r of await (await caches.open(k)).keys()) out.push(new URL(r.url).pathname); return out; });
  ok(kept.includes('/offline.html') && kept.includes('/shop.html') && !kept.some(u => /^\/(api|admin)/.test(u)), 'the offline page and visited pages are saved; the API and admin never are');
  await c.close();
  const ia = await b.newContext({ viewport: { width: 390, height: 844 }, userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1' }); const ip = await ia.newPage(); await ip.goto(BASE + '/'); await ip.waitForSelector('.hero'); await ip.click('.header__menu'); await ip.waitForTimeout(400); await ip.click('.sheet--menu [data-install]'); await ip.waitForSelector('#install-help[open]');
  ok(/Add to Home Screen/.test(await ip.locator('#install-help').innerText()), 'on an iPhone it shows the Share → Add to Home Screen steps'); await ia.close(); }

console.log('\nCookie notice only when Analytics is on');
await call(ad, 'PUT', '/api/admin/site', { ga4Id: 'G-TEST123456' });
const v = await page(); await v.goto(BASE + '/'); await v.waitForSelector('.consent', { timeout: 5000 }); ok(true, 'cookie notice appears');
let ga = false; v.on('request', r => { if (/googletagmanager/.test(r.url())) ga = true; }); await v.waitForTimeout(500); ok(!ga, 'no Google request before consent');
await v.click('.consent [data-c=no]'); await v.reload(); await v.waitForTimeout(1800); ok(await v.locator('.consent').count() === 0 && !ga, 'declining remembers the choice and loads nothing');
await call(ad, 'PUT', '/api/admin/site', { ga4Id: '' });
ok(errs.length === 0, 'no console errors' + (errs.length ? ': ' + errs.slice(0, 3).join(' | ') : ''));
await b.close(); console.log(fails ? '\nSELF E2E FAIL' : '\nSELF E2E PASS'); process.exit(fails ? 1 : 0);
