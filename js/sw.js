/* Service worker: makes the store installable and lets visited pages open offline.
   - pages: network first, falling back to the last copy, then to /offline.html
   - styles and scripts: network first (so a new release shows up on the very next visit), saved copy when offline
   - images: show the saved copy at once and refresh it in the background
   - data.js (catalogue): network first, saved copy when offline
   - orders, accounts, the admin console and every /api/ call are NEVER stored. */
const VERSION = 'cv-v2', SHELL = VERSION + '-shell', PAGES = VERSION + '-pages', ASSETS = VERSION + '-assets';
const PRECACHE = ['/offline.html', '/css/styles.css', '/css/themes.css', '/js/app.js', '/js/theme.js', '/js/i18n.js', '/img/icons/icon-192.png', '/img/brand/logo-128.webp'];
const NEVER = /^\/(api|admin|media\/qr|feeds|sitemap|robots)|\/(admin|invoice|order)\.html$|reset=|\/sw\.js$/;

self.addEventListener('install', e => { e.waitUntil(caches.open(SHELL).then(c => Promise.all(PRECACHE.map(u => c.add(u).catch(() => {})))).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => !k.startsWith(VERSION)).map(k => caches.delete(k)))).then(() => self.clients.claim())); });

const trim = (name, max) => caches.open(name).then(c => c.keys().then(ks => ks.length > max ? c.delete(ks[0]).then(() => trim(name, max)) : 0));

self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== location.origin || NEVER.test(url.pathname + url.search)) return;
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).then(res => { if (res.ok) { const copy = res.clone(); caches.open(PAGES).then(c => c.put(req, copy)).then(() => trim(PAGES, 40)); } return res; })
      .catch(() => caches.match(req).then(hit => hit || caches.match('/offline.html'))));
    return;
  }
  if (url.pathname === '/js/data.js') {
    e.respondWith(fetch(req).then(res => { if (res.ok) { const copy = res.clone(); caches.open(ASSETS).then(c => c.put(req, copy)); } return res; }).catch(() => caches.match(req)));
    return;
  }
  if (/\.(css|js)$/.test(url.pathname)) {
    e.respondWith(fetch(req).then(res => { if (res.ok) { const copy = res.clone(); caches.open(ASSETS).then(c => c.put(req, copy)).then(() => trim(ASSETS, 160)); } return res; }).catch(() => caches.match(req)));
    return;
  }
  if (/\.(css|js|png|jpe?g|webp|avif|svg|woff2?)$/.test(url.pathname) || url.pathname.startsWith('/media/p/') || url.pathname.startsWith('/media/s/')) {
    e.respondWith(caches.match(req).then(hit => {
      const net = fetch(req).then(res => { if (res.ok) { const copy = res.clone(); caches.open(ASSETS).then(c => c.put(req, copy)).then(() => trim(ASSETS, 160)); } return res; }).catch(() => hit);
      return hit || net;
    }));
  }
});
