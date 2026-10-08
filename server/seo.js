'use strict';
/* SEO + social-sharing tags injected server-side, so Google, WhatsApp, Facebook and Instagram previews are right without running JavaScript. */
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
function origin(req) { if (process.env.SITE_URL) return process.env.SITE_URL.replace(/\/+$/, ''); const proto = (req.headers['x-forwarded-proto'] || 'http').split(',')[0].trim(); return proto + '://' + req.headers.host; }
const abs = (o, u) => /^https?:/i.test(u || '') ? u : o + '/' + String(u || '').replace(/^\/+/, '');
function tags(s) {
  const o = s.origin, url = abs(o, s.path || ''), img = abs(o, s.image || 'img/icons/share.png'), desc = esc(String(s.desc || '').slice(0, 200)), title = esc(s.title);
  let h = `<meta name="description" content="${desc}">\n`;
  if (s.verify) h += `<meta name="google-site-verification" content="${esc(s.verify)}">\n`;
  if (s.noindex) h += '<meta name="robots" content="noindex, nofollow">\n'; else h += `<link rel="canonical" href="${esc(url)}">\n`;
  h += `<meta property="og:site_name" content="${esc(s.site)}"><meta property="og:type" content="${s.type || 'website'}"><meta property="og:title" content="${title}"><meta property="og:description" content="${desc}"><meta property="og:url" content="${esc(url)}"><meta property="og:image" content="${esc(img)}"><meta property="og:locale" content="en_IN">\n`;
  h += `<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${title}"><meta name="twitter:description" content="${desc}"><meta name="twitter:image" content="${esc(img)}">\n`;
  h += '<link rel="icon" type="image/png" sizes="32x32" href="/img/icons/icon-32.png"><link rel="apple-touch-icon" href="/img/icons/apple-touch-icon.png"><link rel="manifest" href="/manifest.webmanifest"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-status-bar-style" content="default"><meta name="apple-mobile-web-app-title" content="' + esc(String(s.site || '').slice(0, 14)) + '">\n';
  if (s.ld) h += `<script type="application/ld+json">${JSON.stringify(s.ld).replace(/</g, '\\u003c')}</script>\n`;
  return h;
}
const apply = (html, s) => html.replace(/<title>[^<]*<\/title>/, `<title>${esc(s.title)}</title>`).replace(/<meta name="description"[^>]*>\n?/, '').replace('<!--@seo-->', tags(s));
const crumbs = (o, items) => ({ '@context': 'https://schema.org', '@type': 'BreadcrumbList', itemListElement: items.map((x, i) => ({ '@type': 'ListItem', position: i + 1, name: x[0], item: abs(o, x[1]) })) });
module.exports = { origin, abs, tags, apply, crumbs, esc };
