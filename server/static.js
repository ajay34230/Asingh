'use strict';
/* Static file server with an allow-list (server code, data, tools and dotfiles are never reachable), ETag + compression. */
const fs = require('fs'), path = require('path'), zlib = require('zlib'), crypto = require('crypto');
const ROOT = path.resolve(__dirname, '..');
const PAGES = new Set(['index', 'shop', 'product', 'cart', 'checkout', 'account', 'order', 'admin']);
const ALLOWED_DIRS = ['css', 'js', 'img', 'server/assets'];
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.svg': 'image/svg+xml', '.avif': 'image/avif', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.png': 'image/png', '.json': 'application/json', '.ico': 'image/x-icon', '.txt': 'text/plain; charset=utf-8' };
const cache = new Map();

function resolve(urlPath) {
  let p = decodeURIComponent(urlPath.split('?')[0]);
  if (p === '/') p = '/index.html';
  if (p.includes('\0') || p.includes('..')) return null;
  const rel = p.replace(/^\/+/, '');
  if (/^[a-z]+\.html$/.test(rel)) return PAGES.has(rel.slice(0, -5)) ? path.join(ROOT, rel) : null;
  if (rel === 'robots.txt') return path.join(ROOT, 'server/assets/robots.txt');
  if (!ALLOWED_DIRS.some(d => rel.startsWith(d + '/')) || rel.startsWith('server/assets/') && !/\.(png|svg|txt)$/.test(rel)) return null;
  const abs = path.join(ROOT, rel); return abs.startsWith(ROOT + path.sep) ? abs : null;
}

function serve(req, res, headersFor) {
  const abs = resolve(req.url); if (!abs) return false;
  let st; try { st = fs.statSync(abs); if (!st.isFile()) return false; } catch (e) { return false; }
  const ext = path.extname(abs), type = TYPES[ext] || 'application/octet-stream';
  const etag = '"' + st.size.toString(36) + '-' + Math.floor(st.mtimeMs).toString(36) + '"';
  const isHtml = ext === '.html', long = /\.(avif|webp|jpg|png)$/.test(ext);
  const h = { 'Content-Type': type, ETag: etag, 'Cache-Control': isHtml ? 'no-cache' : long ? 'public, max-age=604800' : 'no-cache', Vary: 'Accept-Encoding', ...headersFor(isHtml) };
  if (/admin\.html$|account\.html$|order\.html$/.test(abs)) h['X-Robots-Tag'] = 'noindex, nofollow';
  if (req.headers['if-none-match'] === etag) { res.writeHead(304, h); res.end(); return true; }
  const ae = String(req.headers['accept-encoding'] || ''), enc = /\bbr\b/.test(ae) ? 'br' : /\bgzip\b/.test(ae) ? 'gzip' : '';
  if (enc && /\.(html|css|js|svg|json|txt)$/.test(ext)) {
    const key = abs + '|' + enc + '|' + etag; let buf = cache.get(key);
    if (!buf) { const raw = fs.readFileSync(abs); buf = enc === 'br' ? zlib.brotliCompressSync(raw, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 9 } }) : zlib.gzipSync(raw, { level: 9 }); cache.set(key, buf); }
    res.writeHead(200, { ...h, 'Content-Encoding': enc, 'Content-Length': buf.length }); if (req.method !== 'HEAD') res.end(buf); else res.end(); return true;
  }
  res.writeHead(200, { ...h, 'Content-Length': st.size }); if (req.method === 'HEAD') { res.end(); return true; }
  fs.createReadStream(abs).pipe(res); return true;
}
module.exports = { serve, ROOT };
