// Reports bytes transferred (gzip not applied by local server; we gzip-estimate text) and request counts per page.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import zlib from 'node:zlib';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
for (const [n, w, h, mob] of [['phone 390', 390, 844, true], ['desktop 1440', 1440, 900, false], ['4K 3840', 3840, 2160, false]]) {
  for (const pg of ['index.html', 'shop.html', 'product.html?id=jodha-gown']) {
    const ctx = await b.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: mob ? 3 : (w > 3000 ? 1 : 1), isMobile: mob, hasTouch: mob });
    const p = await ctx.newPage(); let img = 0, txt = 0, tgz = 0, reqs = 0;
    p.on('response', async r => { try { const buf = await r.body(); reqs++; const t = r.headers()['content-type'] || ''; if (/image/.test(t) || /\.(avif|webp|jpg)$/.test(r.url())) img += buf.length; else { txt += buf.length; tgz += zlib.gzipSync(buf).length; } } catch {} });
    await p.goto('http://localhost:4173/' + pg, { waitUntil: 'networkidle' }); await p.waitForTimeout(400);
    console.log(`${n.padEnd(13)} ${pg.padEnd(34)} requests ${String(reqs).padStart(3)}  images ${(img / 1024).toFixed(0).padStart(5)} KB  html/css/js ${(txt / 1024).toFixed(0)} KB (≈${(tgz / 1024).toFixed(0)} KB gzipped)`);
    await ctx.close();
  }
}
await b.close();
