// Lists every English UI string on the storefront so the Hindi dictionary can be checked for gaps.
// Run against a fresh server; prints strings that have no Hindi entry (needs js/i18n-hi.js).
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'node:fs'; import vm from 'node:vm';
const BASE = process.env.BASE || 'http://localhost:4173';
let HI = {}, PAT = []; try { const ctx = { window: {}, ASINGH: {} }; ctx.window.ASINGH = ctx.ASINGH; vm.createContext(ctx); vm.runInContext(fs.readFileSync('js/i18n-hi.js', 'utf8').replace(/\(function \(A\)/, '(function (A)'), ctx); const I = ctx.ASINGH.I18N || ctx.window.ASINGH.I18N; HI = I.hi; PAT = I.pat; } catch (e) { console.error('no dictionary yet:', e.message); }
const norm = s => s.replace(/\s+/g, ' ').trim();
const has = s => HI[s] || PAT.some(p => p[0].test(s));
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const seen = new Map();
const grab = async (p, tag) => {
  const xs = await p.evaluate(() => { const out = []; const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT); let n; while ((n = w.nextNode())) { const el = n.parentElement; if (!el || /SCRIPT|STYLE|TEXTAREA/.test(el.tagName) || el.closest('[data-no-i18n]')) continue; out.push(n.nodeValue); } document.querySelectorAll('[placeholder],[aria-label],[title],[alt]').forEach(e => { if (e.closest('[data-no-i18n]')) return; ['placeholder', 'aria-label', 'title', 'alt'].forEach(a => { const v = e.getAttribute(a); if (v) out.push(v); }); }); out.push(document.title); return out; });
  xs.forEach(x => { const k = norm(x); if (!k || !/[A-Za-z]{2}/.test(k)) return; if (!seen.has(k)) seen.set(k, tag); });
};
const c = await b.newContext({ viewport: { width: 1280, height: 900 } }); const p = await c.newPage();
const go = async (u, tag) => { await p.goto(BASE + u); await p.waitForTimeout(900); await grab(p, tag || u); };
const call = (method, url, body) => p.evaluate(async ([method, url, body]) => { const r = await fetch(url, { method, headers: { 'content-type': 'application/json', 'x-requested-with': 'asingh' }, body: body ? JSON.stringify(body) : undefined }); return r.status; }, [method, url, body]);
await go('/'); await go('/shop.html'); await go('/product.html?id=rani-sa-anarkali'); await go('/cart.html'); await go('/track.html'); await go('/account.html'); await go('/order.html?id=x'); await go('/nope.html', '404');
for (const s of ['about', 'contact', 'faq', 'shipping-returns', 'privacy-policy', 'terms', 'care-guide']) await go('/' + s + '.html');
// open sheets / menus
await go('/'); for (const sel of ['[data-open=search]', '.header__menu', '[data-open=cart]', '[data-account]']) { try { await p.click(sel, { timeout: 2000 }); await p.waitForTimeout(500); await grab(p, 'sheet ' + sel); await p.keyboard.press('Escape'); await p.waitForTimeout(300); } catch (e) {} }
await p.click('.nav__trigger').catch(() => {}); await p.waitForTimeout(400); await grab(p, 'mega');
await go('/shop.html'); await p.click('#filter-open').catch(() => {}); await p.waitForTimeout(400); await grab(p, 'filters'); await p.keyboard.press('Escape');
await p.goto(BASE + '/shop.html?q=zzzz'); await p.waitForTimeout(900); await grab(p, 'no results');
await go('/product.html?id=rani-sa-anarkali'); await p.click('#add-btn').catch(() => {}); await p.waitForTimeout(500); await grab(p, 'pdp add error');
await p.click('[data-size-guide]').catch(() => {}); await p.waitForTimeout(500); await grab(p, 'size guide'); await p.keyboard.press('Escape');
// signed-in customer: account tabs, checkout steps
await call('POST', '/api/auth/register', { name: 'Test User', email: 't' + Date.now() + '@example.com', password: 'test-pass-123' });
await p.evaluate(() => localStorage.setItem('asingh.cart.v1', JSON.stringify([{ key: 'k', id: 'rani-sa-anarkali', size: 'M', stitch: 'semi', color: 'Rani', note: '', qty: 1 }])));
await go('/cart.html'); await go('/checkout.html'); await p.click('#step-details button[type=submit]').catch(() => {}); await p.waitForTimeout(500); await grab(p, 'checkout errors');
await p.fill('[name=name]', 'Test User').catch(() => {}); await p.fill('[name=email]', 'a@b.co').catch(() => {}); await p.fill('[name=phone]', '9876543210').catch(() => {}); await p.fill('[name=line1]', '12 MG Road').catch(() => {}); await p.fill('[name=pin]', '560001').catch(() => {}); await p.fill('[name=city]', 'Bengaluru').catch(() => {}); await p.selectOption('[name=state]', { index: 5 }).catch(() => {});
await p.click('#step-details button[type=submit]').catch(() => {}); await p.waitForTimeout(600); await grab(p, 'checkout step2'); await p.click('#step-method button[type=submit]').catch(() => {}); await p.waitForTimeout(1500); await grab(p, 'checkout qr');
await go('/account.html'); await p.click('#tab-p').catch(() => {}); await grab(p, 'acct profile'); await p.click('#tab-s').catch(() => {}); await grab(p, 'acct security');
const ids = await p.evaluate(async () => (await (await fetch('/api/orders')).json()).orders.map(o => o.id)); if (ids[0]) await go('/order.html?id=' + ids[0], 'order');
const miss = [...seen].filter(([k]) => !has(k)); console.log(JSON.stringify(miss.map(([k, t]) => k)), '\n// total', seen.size, 'missing', miss.length);
fs.writeFileSync('/tmp/claude-0/s/i18n-all.json', JSON.stringify([...seen.keys()], null, 1)); await b.close();
