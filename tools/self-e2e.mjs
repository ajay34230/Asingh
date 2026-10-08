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

console.log('\nCookie notice only when Analytics is on');
await call(ad, 'PUT', '/api/admin/site', { ga4Id: 'G-TEST123456' });
const v = await page(); await v.goto(BASE + '/'); await v.waitForSelector('.consent', { timeout: 5000 }); ok(true, 'cookie notice appears');
let ga = false; v.on('request', r => { if (/googletagmanager/.test(r.url())) ga = true; }); await v.waitForTimeout(500); ok(!ga, 'no Google request before consent');
await v.click('.consent [data-c=no]'); await v.reload(); await v.waitForTimeout(1800); ok(await v.locator('.consent').count() === 0 && !ga, 'declining remembers the choice and loads nothing');
await call(ad, 'PUT', '/api/admin/site', { ga4Id: '' });
ok(errs.length === 0, 'no console errors' + (errs.length ? ': ' + errs.slice(0, 3).join(' | ') : ''));
await b.close(); console.log(fails ? '\nSELF E2E FAIL' : '\nSELF E2E PASS'); process.exit(fails ? 1 : 0);
