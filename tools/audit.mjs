// Site audit: crawls every page (phone + desktop) and reports console errors, failed requests, dead links,
// missing alt / labels / names, duplicate ids, heading problems and SEO/meta gaps. Needs a running server (:4173).
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const B = process.env.BASE || 'http://localhost:4173';
const pages = ['/', '/shop.html', '/shop.html?cat=gown', '/product.html?id=jodha-gown', '/cart.html', '/checkout.html', '/account.html', '/track.html', '/order.html', '/invoice.html', '/admin.html'];
const extra = (process.env.PAGES || '').split(',').filter(Boolean);
const br = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const issues = {}; const add = (p, m) => { (issues[p] = issues[p] || new Set()).add(m); };
const links = new Set();
for (const [w, h, mobile] of [[390, 844, true], [1440, 900, false]]) {
  const ctx = await br.newContext({ viewport: { width: w, height: h }, isMobile: mobile, hasTouch: mobile });
  for (const url of [...pages, ...extra]) {
    const p = await ctx.newPage(); const tag = url;
    p.on('pageerror', e => add(tag, 'JS error: ' + e.message)); p.on('console', m => { if (['error', 'warning'].includes(m.type()) && !/Failed to load resource.*(401|404)/.test(m.text())) add(tag, 'console ' + m.type() + ': ' + m.text().slice(0, 120)); });
    p.on('requestfailed', r => add(tag, 'request failed: ' + r.url().slice(0, 90))); p.on('response', r => { if (r.status() >= 400 && !/\/api\/(me|orders|admin)/.test(r.url())) add(tag, r.status() + ' ' + r.url().replace(B, '').slice(0, 90)); });
    await p.goto(B + url, { waitUntil: 'networkidle' }).catch(() => {}); await p.waitForTimeout(500);
    const r = await p.evaluate(() => {
      const out = [], q = s => [...document.querySelectorAll(s)];
      const meta = n => (document.querySelector(`meta[name="${n}"],meta[property="${n}"]`) || {}).content;
      if (!document.title || document.title.length < 8) out.push('missing/short <title>');
      if (!meta('description')) out.push('no meta description'); if (!document.querySelector('link[rel=canonical]')) out.push('no canonical link'); if (!meta('og:title') || !meta('og:image')) out.push('no Open Graph title/image (bad link previews)');
      if (!document.documentElement.lang) out.push('no html lang');
      const ids = {}; q('[id]').forEach(e => { ids[e.id] = (ids[e.id] || 0) + 1; }); Object.keys(ids).filter(k => ids[k] > 1).forEach(k => out.push('duplicate id #' + k));
      q('img').forEach(i => { if (!i.hasAttribute('alt')) out.push('img without alt: ' + (i.currentSrc || i.src).slice(-40)); });
      q('button,a[href],[role=button]').forEach(e => { if (e.offsetParent === null && getComputedStyle(e).position !== 'fixed') return; const n = (e.textContent || '').trim() || e.getAttribute('aria-label') || e.getAttribute('title') || (e.querySelector('img[alt]') || {}).alt; if (!n) out.push('control without a name: ' + e.outerHTML.slice(0, 70)); });
      q('input:not([type=hidden]):not([type=file]),select,textarea').forEach(e => { if (e.offsetParent === null && e.type !== 'radio' && e.type !== 'checkbox') return; const has = e.getAttribute('aria-label') || e.getAttribute('aria-labelledby') || (e.id && document.querySelector(`label[for="${e.id}"]`)) || e.closest('label'); if (!has) out.push('input without a label: ' + e.outerHTML.slice(0, 70)); });
      const hs = q('h1,h2,h3').map(h => +h.tagName[1]); if (hs.filter(x => x === 1).length !== 1) out.push('page has ' + hs.filter(x => x === 1).length + ' <h1>');
      hs.forEach((h, i) => { if (i && h - hs[i - 1] > 1) out.push('heading level jumps h' + hs[i - 1] + '→h' + h); });
      const links = q('a[href]').map(a => a.getAttribute('href')).filter(h => h && !/^(mailto:|tel:|upi:|javascript:|https?:)/.test(h));
      if (document.body.scrollWidth > innerWidth + 1) out.push('horizontal overflow');
      return { out: [...new Set(out)], links };
    });
    r.out.forEach(m => add(tag + (mobile ? '' : ''), m)); r.links.forEach(l => links.add(l));
    await p.close();
  }
  await ctx.close();
}
const dead = [];
for (const l of links) { if (l.startsWith('#')) continue; const u = new URL(l, B + '/'); const s = (await fetch(u, { redirect: 'manual' }).catch(() => ({ status: 0 }))).status; if (s >= 400 || s === 0) dead.push(`${l} → ${s}`); }
console.log('\n=== DEAD INTERNAL LINKS ===\n' + (dead.length ? dead.join('\n') : 'none'));
console.log('\n=== PAGE ISSUES ===');
for (const [p, set] of Object.entries(issues)) { console.log(p); [...set].slice(0, 14).forEach(m => console.log('   - ' + m)); }
console.log(Object.keys(issues).length ? '\n(issues above)' : '\nAll clean');
await br.close();
