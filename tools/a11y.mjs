// Accessibility sweep without external libraries: text contrast (WCAG AA), names for controls/images/inputs,
// heading order, one h1, <html lang>, keyboard reachability. Usage: THEME=bloom LANG_=hi node tools/a11y.mjs
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const BASE = process.env.BASE || 'http://localhost:4173', THEME = process.env.THEME || 'royal', LANG = process.env.LANG_ || 'en';
const pages = ['/', '/shop.html', '/product.html?id=rani-sa-anarkali', '/cart.html', '/checkout.html', '/account.html', '/track.html', '/about.html', '/faq.html', '/nope.html'];
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
let total = 0;
for (const [w, h] of [[390, 844], [1280, 900]]) {
  const c = await b.newContext({ viewport: { width: w, height: h } });
  await c.addInitScript(([t, l]) => { localStorage.setItem('asingh.theme', t); localStorage.setItem('asingh.lang', l); localStorage.setItem('asingh.cart.v1', JSON.stringify([{ key: 'k', id: 'rani-sa-anarkali', size: 'M', stitch: 'semi', color: 'Rani', note: '', qty: 1 }])); }, [THEME, LANG]);
  const p = await c.newPage();
  for (const u of pages) {
    await p.goto(BASE + u); await p.waitForTimeout(1500);
    await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 600) { scrollTo(0, y); await new Promise(r => setTimeout(r, 40)); } scrollTo(0, 0); }); await p.waitForTimeout(700);
    const issues = await p.evaluate(() => {
      const out = [], seen = new Set();
      const parse = s => { const m = s.match(/rgba?\(([^)]+)\)/); if (!m) return null; const v = m[1].split(/[ ,\/]+/).filter(Boolean).map(Number); return { r: v[0], g: v[1], b: v[2], a: v[3] === undefined ? 1 : v[3] }; };
      const lum = c => { const f = x => { x /= 255; return x <= .03928 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4); }; return .2126 * f(c.r) + .7152 * f(c.g) + .0722 * f(c.b); };
      const over = (top, bot) => ({ r: top.r * top.a + bot.r * (1 - top.a), g: top.g * top.a + bot.g * (1 - top.a), b: top.b * top.a + bot.b * (1 - top.a), a: 1 });
      const bgOf = el => { let layers = [], n = el, unknown = false; while (n && n.nodeType === 1) { const cs = getComputedStyle(n); if (cs.backgroundImage !== 'none') { unknown = true; break; } const c = parse(cs.backgroundColor); if (c && c.a > 0) { layers.push(c); if (c.a >= 1) break; } n = n.parentElement; } if (unknown) return null; let base = { r: 255, g: 255, b: 255, a: 1 }; for (let i = layers.length - 1; i >= 0; i--) base = over(layers[i], base); return base; };
      const vis = el => { const r = el.getBoundingClientRect(); const cs = getComputedStyle(el); return r.width > 1 && r.height > 1 && cs.visibility !== 'hidden' && cs.display !== 'none' && +cs.opacity > .05 && !el.closest('[hidden],[aria-hidden=true],.vh'); };
      const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT); let n;
      while ((n = w.nextNode())) {
        const t = n.nodeValue.trim(); if (t.length < 2) continue; const el = n.parentElement; if (!el || /SCRIPT|STYLE|NOSCRIPT/.test(el.tagName) || !vis(el) || el.closest('[disabled]')) continue;
        if (el.closest('.tile,.hero,.story,.card__media,.lightbox')) continue;   // text on photos: checked by eye
        const cs = getComputedStyle(el), fg = parse(cs.color), bg = bgOf(el); if (!fg || !bg) continue; const f = over(fg, bg), L1 = lum(f), L2 = lum(bg), ratio = (Math.max(L1, L2) + .05) / (Math.min(L1, L2) + .05);
        const px = parseFloat(cs.fontSize), bold = +cs.fontWeight >= 700, large = px >= 24 || (px >= 18.66 && bold), need = large ? 3 : 4.5;
        if (ratio < need) { const k = el.tagName + el.className + t.slice(0, 20); if (!seen.has(k)) { seen.add(k); out.push(`contrast ${ratio.toFixed(2)} (<${need}) ${el.tagName}.${String(el.className).slice(0, 30)} "${t.slice(0, 34)}"`); } }
      }
      document.querySelectorAll('button,a[href],[role=button]').forEach(e => { if (!vis(e)) return; const name = (e.getAttribute('aria-label') || e.textContent || e.getAttribute('title') || '').trim(); if (!name && !e.querySelector('img[alt]:not([alt=""])')) out.push('no accessible name: ' + e.outerHTML.slice(0, 90)); });
      document.querySelectorAll('input:not([type=hidden]),select,textarea').forEach(e => { if (!vis(e) && e.type !== 'checkbox' && e.type !== 'radio') return; const id = e.id; const has = e.getAttribute('aria-label') || e.getAttribute('aria-labelledby') || (id && document.querySelector('label[for="' + id + '"]')) || e.closest('label'); if (!has) out.push('input without label: ' + e.outerHTML.slice(0, 80)); });
      document.querySelectorAll('img').forEach(e => { if (!e.hasAttribute('alt')) out.push('img without alt: ' + (e.getAttribute('src') || '').slice(0, 60)); });
      const visH = e => { const r = e.getBoundingClientRect(), cs = getComputedStyle(e); return (r.width > 1 || e.classList.contains('vh')) && cs.display !== 'none' && !e.closest('[hidden]'); }; const hs = [...document.querySelectorAll('h1,h2,h3,h4')].filter(visH).map(e => +e.tagName[1]); if (hs.filter(x => x === 1).length !== 1) out.push('h1 count = ' + hs.filter(x => x === 1).length); for (let i = 1; i < hs.length; i++) if (hs[i] - hs[i - 1] > 1) { out.push(`heading jumps h${hs[i - 1]}→h${hs[i]}`); break; }
      if (!document.documentElement.lang) out.push('missing <html lang>');
      return out;
    });
    if (issues.length) { total += issues.length; console.log(`\n${w}px ${u}`); issues.slice(0, 12).forEach(i => console.log('  - ' + i)); }
  }
  await c.close();
}
// keyboard: first 25 Tab stops on the home page must each show a focus indicator
{ const c = await b.newContext({ viewport: { width: 1280, height: 900 } }); await c.addInitScript(t => localStorage.setItem('asingh.theme', t), THEME); const p = await c.newPage(); await p.goto(BASE + '/'); await p.waitForTimeout(1200); let bad = 0;
  for (let i = 0; i < 25; i++) { await p.keyboard.press('Tab'); const r = await p.evaluate(() => { const e = document.activeElement; if (!e || e === document.body) return 'none'; const cs = getComputedStyle(e); return (cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0) || cs.boxShadow !== 'none' ? 'ok' : 'noring:' + e.tagName + '.' + String(e.className).slice(0, 20); }); if (r !== 'ok') { bad++; console.log('  focus: ' + r); } }
  console.log(bad ? `keyboard: ${bad} stops without a visible focus ring` : 'keyboard: every tested Tab stop shows a focus ring'); total += bad; await c.close(); }
await b.close(); console.log(`\n${THEME}/${LANG}: ${total} accessibility findings`); process.exit(total ? 1 : 0);
