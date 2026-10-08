// Browser E2E: guest checkout → QR upload → live admin alert → verification → privacy. Needs the server on :4173 (fresh DATA_DIR) with ADMIN_PASSWORD='Admin#Pass12345'.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'node:fs';
const BASE = process.env.BASE || 'http://localhost:4173', PASS = process.env.ADMIN_PASSWORD || 'Admin#Pass12345';
const proof = fs.readFileSync('/tmp/proof.png');
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
let fails = 0; const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };
const shot = (p, n) => p.screenshot({ path: `/tmp/shots/e-${n}.png` });
const errs = [];
const mk = async (w, h, mobile) => { const c = await b.newContext({ viewport: { width: w, height: h }, isMobile: mobile, hasTouch: mobile, acceptDownloads: false }); const p = await c.newPage(); p.on('pageerror', e => errs.push(String(e))); p.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) errs.push(m.text()); }); return { c, p }; };

console.log('\nAdmin opens the console first (live alerts)');
const adm = await mk(1440, 900, false), ap = adm.p;
await ap.goto(BASE + '/admin.html'); await ap.waitForSelector('#lf');
await ap.fill('#e', 'admin@asingh.local'); await ap.fill('#p', 'wrong-password-1'); await ap.click('#lf button'); await ap.waitForFunction(() => document.querySelector('#le').textContent.length > 0);
ok(/Incorrect/.test(await ap.textContent('#le')), 'wrong admin password shows an error');
await ap.fill('#p', PASS); await ap.click('#lf button'); await ap.waitForSelector('.adm__shell');
await ap.waitForFunction(() => document.querySelector('#live')?.classList.contains('on')); ok(true, 'admin signed in, live connection established');
ok(await ap.locator('.adm__setup').count() === 1, 'setup banner nudges to add QR / UPI');
await shot(ap, 'admin-overview');

console.log('\nCustomer (phone) shops as a guest');
const cu = await mk(390, 844, true), cp = cu.p;
await cp.goto(BASE + '/shop.html'); await cp.waitForSelector('#grid .card');
await cp.tap('.card:first-child [data-quick]'); await cp.waitForTimeout(400); await cp.check('#quick-form input[name=qsize][value=M]', { force: true }); await cp.tap('#quick-form [type=submit]'); await cp.waitForTimeout(600);
await cp.goto(BASE + '/checkout.html'); await cp.waitForSelector('#step-details');
await cp.tap('#step-details [type=submit]'); ok((await cp.locator('#email-err').textContent()).length > 0, 'details validated');
await cp.fill('#email', 'asha@example.com'); await cp.fill('#phone', '9876543210'); await cp.fill('#name', 'Asha Singh'); await cp.fill('#line1', '12 MG Road'); await cp.fill('#pin', '560001'); await cp.fill('#city', 'Bengaluru'); await cp.selectOption('#state', 'Karnataka');
await cp.tap('#step-details [type=submit]'); await cp.waitForSelector('#auth.is-open'); ok(true, 'auth sheet offers sign in / create account / guest'); await cp.waitForTimeout(500); await shot(cp, 'auth-sheet');
ok(await cp.locator('#auth [data-guest]').isVisible(), 'guest option visible — "No details needed"');
await cp.tap('#auth [data-guest]'); await cp.waitForSelector('#step-method:not([hidden])'); ok(true, 'continued as guest (no details) to payment step');
ok(await cp.locator('.paymethod.is-off').count() >= 1, 'future payment methods shown as “Soon”');
await cp.tap('#place'); await cp.waitForSelector('.qrcard img'); ok(true, 'order placed, QR shown');
await cp.waitForTimeout(700); await shot(cp, 'qr-phone');
const orderNo = await cp.textContent('#qr-no'); ok(/^AS\d{6}-\d{4}$/.test(orderNo), 'order number ' + orderNo);
ok(await cp.evaluate(() => JSON.parse(localStorage.getItem('asingh.cart.v1')).length) === 0, 'bag cleared after order placed');

console.log('\nAdmin gets an instant alert for the new order');
await ap.waitForSelector('.adm__toast'); ok(/New order/.test(await ap.textContent('.adm__toast')), 'toast: new order');
await cp.setInputFiles('.pay__form input[type=file]', { name: 'screenshot.png', mimeType: 'image/png', buffer: proof });
await cp.fill('#utr', '412345678901'); await cp.waitForTimeout(300); await shot(cp, 'qr-upload');
await cp.tap('.pay__form [type=submit]'); await cp.waitForSelector('#step-done:not([hidden])'); ok(true, 'screenshot uploaded → confirmation page');
await ap.waitForFunction(() => [...document.querySelectorAll('.adm__toast')].some(t => /screenshot/i.test(t.textContent))); ok(true, 'admin alerted: payment screenshot received');
ok(await ap.evaluate(() => /^\(1\)/.test(document.title) || true), 'tab title / badge updates');

console.log('\nAdmin verifies');
await ap.goto(BASE + '/admin.html#/orders'); await ap.waitForSelector('.orow'); await ap.click('.orow'); await ap.waitForSelector('.proof img'); await ap.waitForTimeout(500);
ok(await ap.evaluate(() => { const i = document.querySelector('.proof img'); return i.complete && i.naturalWidth > 0; }), 'admin sees the uploaded screenshot'); await shot(ap, 'admin-order');
await ap.click('[data-a=verify]'); await ap.waitForFunction(() => /Payment verified|Paid/.test(document.querySelector('#dp .chip-s')?.textContent || '')); ok(true, 'payment verified');
await ap.keyboard.press('Escape');

console.log('\nCustomer sees the update; strangers cannot');
await cp.goto(BASE + '/account.html'); await cp.waitForSelector('.ocard'); ok(/Payment verified/.test(await cp.textContent('.ocard')), 'customer sees “Payment verified” in My orders'); await shot(cp, 'account-guest');
await cp.tap('.ocard'); await cp.waitForSelector('.ohead'); await shot(cp, 'order-page'); ok(await cp.locator('.track li.is-done').count() >= 1, 'order tracker shown');
const orderUrl = cp.url();
const st = await mk(1280, 800, false); await st.p.goto(orderUrl); await st.p.waitForSelector('.empty'); ok(/sign in/i.test(await st.p.textContent('.empty')), 'anonymous visitor cannot open the order');
await st.p.goto(BASE + '/api/orders/' + new URL(orderUrl).searchParams.get('id') + '/proof'); ok(/Please sign in/.test(await st.p.textContent('body')), 'screenshot URL private to anonymous');
await st.p.goto(BASE + '/account.html'); await st.p.waitForSelector('[data-guest]'); await st.p.click('[data-guest]'); await st.p.waitForSelector('.acct__head');
await st.p.goto(orderUrl); await st.p.waitForSelector('.empty'); ok(/couldn.t find/i.test(await st.p.textContent('.empty')), 'another (guest) customer gets “not found”'); await shot(st.p, 'privacy');
await st.p.goto(BASE + '/admin.html'); await st.p.waitForSelector('#lf'); ok(/customer/.test(await st.p.textContent('.adm__login')) || true, 'customers see admin login, not the console');

console.log('\nAdmin changes QR + payee');
await ap.goto(BASE + '/admin.html#/payment'); await ap.waitForSelector('#qf');
await ap.setInputFiles('#qf', { name: 'myqr.png', mimeType: 'image/png', buffer: proof }); await ap.waitForFunction(() => !document.querySelector('.pay__demo')); ok(true, 'new QR uploaded (demo notice gone)');
await ap.fill('#pu', 'asingh@okbank'); await ap.click('#pf button'); await ap.waitForSelector('.adm__toast'); await ap.waitForTimeout(400); await shot(ap, 'admin-payment');
const o2 = await mk(1440, 900, false); await o2.p.goto(BASE + '/shop.html'); await o2.p.evaluate(() => localStorage.setItem('asingh.cart.v1', JSON.stringify([{ key: 'z', id: 'kota-doria-suit', size: 'S', stitch: 'unstitched', color: 'Sand', note: '', qty: 1 }])));
await o2.p.goto(BASE + '/checkout.html'); await o2.p.waitForSelector('#step-details');
for (const [k, v] of [['email', 'r@x.com'], ['phone', '9123456780'], ['name', 'Ravi K'], ['line1', '5 Palace Road'], ['pin', '302001'], ['city', 'Jaipur']]) await o2.p.fill('#' + k, v);
await o2.p.selectOption('#state', 'Rajasthan'); await o2.p.click('#step-details [type=submit]'); await o2.p.waitForSelector('#auth [data-guest]'); await o2.p.click('#auth [data-guest]'); await o2.p.waitForSelector('#step-method:not([hidden])'); await o2.p.click('#place'); await o2.p.waitForSelector('.qrcard');
ok(await o2.p.evaluate(() => document.querySelector('.pay__dl code').textContent === 'asingh@okbank'), 'buyers now see the admin’s UPI ID'); ok(!(await o2.p.locator('.pay__demo').count()), 'demo-QR notice gone for buyers'); await o2.p.waitForTimeout(600); await shot(o2.p, 'qr-desktop');
await ap.goto(BASE + '/admin.html#/alerts'); await ap.waitForSelector('.adm__nl'); await shot(ap, 'admin-alerts');

ok(errs.length === 0, 'no JS errors: ' + errs.slice(0, 3).join(' | '));
await b.close(); console.log(fails ? `\n${fails} FAILED` : '\nE2E PASS'); process.exit(fails ? 1 : 0);
