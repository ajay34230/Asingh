/* LocalDrop service worker: lets browsers install LocalDrop as an app and open its shell fast. Files and data always come live from the host. */
var CACHE = 'localdrop-shell-v2';
var SHELL = ['/', '/index.html', '/css/app.css', '/manifest.webmanifest', '/icon-192.png', '/finder.html', '/js/finder.js'];
self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(SHELL); }).catch(function () { /* offline install is optional */ }));
  self.skipWaiting();
});
self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (ks) { return Promise.all(ks.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); })); }));
  self.clients.claim();
});
self.addEventListener('fetch', function (e) {
  var u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin || u.pathname.indexOf('/api/') === 0) return;
  // Network first, so a new host version is picked up; the cache only covers a dropped connection.
  e.respondWith(fetch(e.request).then(function (r) {
    var copy = r.clone();
    if (r.ok) caches.open(CACHE).then(function (c) { c.put(e.request, copy); });
    return r;
  }).catch(function () { return caches.match(e.request).then(function (m) { return m || (e.request.mode === 'navigate' ? caches.match('/finder.html') : caches.match('/index.html')); }); }));
});
