// Responsive QA: loads each page at every viewport in the matrix (portrait + landscape),
// then checks overflow, clipped/overlapping controls, tap-target size and image sizing.
// Usage: node tools/qa.mjs [--shots] ; needs `npx playwright` (chromium) and a server on :4173
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'node:fs';
const BASE = process.env.BASE || 'http://localhost:4173';
const widths = [280, 320, 360, 375, 390, 414, 480, 600, 768, 820, 912, 1024, 1280, 1366, 1440, 1600, 1920, 2560, 3840];
const heights = { 280: 653, 320: 568, 360: 740, 375: 667, 390: 844, 414: 896, 480: 854, 600: 960, 768: 1024, 820: 1180, 912: 1368, 1024: 768, 1280: 800, 1366: 768, 1440: 900, 1600: 900, 1920: 1080, 2560: 1440, 3840: 2160 };
const extra = [[667, 375], [844, 390], [932, 430], [1024, 768], [1180, 820], [1366, 1024], [653, 280], [960, 600], [1024, 600], [540, 720], [884, 1104], [1280, 720], [2560, 1080], [3440, 1440], [5120, 1440]]; // landscape phones/tablets
const pages = ['index.html', 'shop.html?cat=poshak', 'product.html?id=maharani-poshak', 'cart.html', 'checkout.html', 'account.html', 'track.html', 'admin.html'];
const shots = process.argv.includes('--shots');
const only = (process.argv.find(a => a.startsWith('--only=')) || '').slice(7);
const vps = [...widths.map(w => [w, heights[w]]), ...extra];
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
const problems = [];
fs.mkdirSync('/tmp/shots', { recursive: true });
for (const [w, h] of vps) {
  const touch = w < 1100;
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, hasTouch: touch, isMobile: touch && w < 1000, deviceScaleFactor: touch ? 2 : 1 });
  for (const pg of pages) {
    if (only && !pg.includes(only)) continue;
    const page = await ctx.newPage();
    const errs = []; page.on('pageerror', e => errs.push(String(e))); page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
    await page.goto(`${BASE}/${pg}`, { waitUntil: 'load' });
    if (pg.startsWith('cart') || pg.startsWith('checkout')) {
      await page.evaluate(() => { localStorage.setItem('asingh.cart.v1', JSON.stringify([{ key: 'k1', id: 'maharani-poshak', size: 'M', stitch: 'custom', color: 'Mulberry', note: 'Height 5ft 6in', qty: 1 }, { key: 'k2', id: 'kota-doria-suit', size: 'S', stitch: 'unstitched', color: 'Indigo', note: '', qty: 2 }])); });
      await page.reload({ waitUntil: 'load' });
    }
    await page.waitForTimeout(250);
    const r = await page.evaluate(() => {
      const vw = document.documentElement.clientWidth, out = [];
      const sw = document.documentElement.scrollWidth; if (sw > vw + 1) out.push(`h-overflow: scrollWidth ${sw} > ${vw}`);
      const vis = el => { const s = getComputedStyle(el), b = el.getBoundingClientRect(); return s.visibility !== 'hidden' && s.display !== 'none' && b.width > 0 && b.height > 0 && !el.closest('.sheet:not(.is-open):not(.sheet--filters)') && !el.closest('[inert]'); };
      const inRail = el => el.closest('.rail__track,.gal');
      document.querySelectorAll('body *').forEach(el => {
        if (!vis(el) || inRail(el)) return;
        const b = el.getBoundingClientRect();
        if (el.closest('.sheet') && !el.closest('.sheet.is-open') && !el.closest('.sheet--filters')) return;
        if (el.closest('.hero__img,.story__img,.sheet__panel:not(.x)') && el.closest('.sheet:not(.sheet--filters)')) return;
        if (b.right > vw + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.toast,.tablewrap,.lightbox__scroll,.hero__img,.story__img,.mega,.marquee,.totop')) out.push(`overflow-right ${el.tagName}.${(el.className && el.className.baseVal === undefined ? el.className : '').toString().slice(0, 30)} right=${Math.round(b.right)}`);
      });
      // interactive controls: tap-target size
      document.querySelectorAll('a[href],button,input:not([type=hidden]),select,textarea,summary').forEach(el => {
        if (!vis(el)) return; const b = el.getBoundingClientRect();
        if (el.closest('.sheet:not(.is-open):not(.sheet--filters)')) return;
        if (el.type === 'radio' || el.type === 'checkbox') return;
        if (el.matches('.skip')) return;
        const inline = el.tagName === 'A' && (b.width >= 100 && b.height >= 30) || (getComputedStyle(el).display === 'inline' && el.closest('p,li,.crumbs'));
        if ((b.height < 40 || b.width < 40) && !inline && !el.closest('.footer__legal')) out.push(`small-target ${el.tagName}.${String(el.className).slice(0, 30)} ${Math.round(b.width)}x${Math.round(b.height)} "${(el.textContent || el.getAttribute('aria-label') || '').trim().slice(0, 20)}"`);
      });
      // text size
      document.querySelectorAll('p,li,span,a,button,label,small,dd,dt,summary').forEach(el => { if (!vis(el) || !el.childNodes.length) return; const t = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()); if (t && parseFloat(getComputedStyle(el).fontSize) < 12) out.push(`tiny-text ${el.tagName} ${getComputedStyle(el).fontSize} "${el.textContent.trim().slice(0, 20)}"`); });
      // broken images
      document.querySelectorAll('img').forEach(i => { if (i.closest('.sheet:not(.is-open):not(.sheet--filters),[hidden]') || i.offsetParent === null) return; if (i.complete && i.naturalWidth === 0 && i.currentSrc) out.push('broken-img ' + i.currentSrc); });
      // header overlap: nav/actions don't collide
      const bar = document.querySelector('.header__bar'); if (bar) { const kids = [...bar.children].filter(vis).map(k => k.getBoundingClientRect()); for (let i = 0; i < kids.length - 1; i++) if (kids[i].right > kids[i + 1].left + 1) out.push('header-collision ' + i); }
      // content max width
      const cs = document.querySelector('main .container, main'); out._cw = Math.round(cs.getBoundingClientRect().width);
      const cols = (g => g ? getComputedStyle(g).gridTemplateColumns.split(' ').length : 0)(document.querySelector('.grid'));
      return { out: [...out], cols, cw: out._cw };
    });
    const tag = `${w}x${h} ${pg}`;
    if (r.out.length || errs.length) problems.push({ tag, issues: [...new Set(r.out)].slice(0, 12), errs });
    if (!process.argv.includes('--quiet')) console.log(tag.padEnd(46), 'cols', r.cols, 'content', r.cw, r.out.length ? `⚠ ${r.out.length}` : 'ok');
    if (shots && (!only || true)) await page.screenshot({ path: `/tmp/shots/${w}x${h}-${pg.split('?')[0].replace('.html', '')}.png`, fullPage: false });
    await page.close();
  }
  await ctx.close();
}
await browser.close();
console.log('\n==== PROBLEMS ====');
for (const p of problems) { console.log(p.tag); p.issues.forEach(i => console.log('   -', i)); p.errs.forEach(e => console.log('   ERR', e)); }
console.log(problems.length ? `\n${problems.length} viewport/page combos with issues` : '\nAll clean');
