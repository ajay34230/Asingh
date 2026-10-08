'use strict';
/* ASINGH store server — zero dependencies. Static site + JSON API + private order/proof storage + admin console + live alerts. */
const http = require('http'), fs = require('fs'), path = require('path'), crypto = require('crypto');
const A = require('../js/data.js');
const { DB, id } = require('./db');
const { Auth, hashPassword, verifyPassword, limiter, publicUser } = require('./auth');
const { readBody, parseMultipart, sniffImage } = require('./upload');
const { Notifier } = require('./notify');
const Pay = require('./payments');
const Orders = require('./orders');
const Static = require('./static');
const { Catalog } = require('./catalog');
const Home = require('./home');
const zlib = require('zlib');

function createApp(opts = {}) {
  const dataDir = path.resolve(opts.dataDir || process.env.DATA_DIR || path.join(Static.ROOT, 'data'));
  const db = new DB(dataDir), auth = new Auth(db, { secure: opts.secure || process.env.COOKIE_SECURE === '1' }), notifier = new Notifier(db);
  const D = db.data;
  const catalog = new Catalog(db);
  D.settings = Object.assign({ payeeName: 'ASINGH', upiId: '', instructions: 'Scan the QR with any UPI app, pay the exact amount, then upload a screenshot of the payment on the next screen.', webhookUrl: '', qrFile: '', qrV: 0, invoice: { name: 'ASINGH', address: '', gstin: '', contact: '' } }, D.settings);
  D.settings.invoice = Object.assign({ name: 'ASINGH', address: '', gstin: '', contact: '' }, D.settings.invoice);
  const trackLimit = limiter(20, 10 * 60e3), authLimit = limiter(12, 10 * 60e3), guestLimit = limiter(60, 10 * 60e3), orderLimit = limiter(20, 3600e3), uploadLimit = limiter(15, 3600e3), emailLimit = limiter(8, 15 * 60e3);

  /* ---- admin bootstrap: never ships with a default password ---- */
  const adminEmail = String(process.env.ADMIN_EMAIL || 'admin@asingh.local').toLowerCase();
  if (!D.users.some(u => u.role === 'admin')) {
    const pw = process.env.ADMIN_PASSWORD || crypto.randomBytes(9).toString('base64url');
    D.users.push({ id: id(), role: 'admin', name: 'Store admin', email: adminEmail, passHash: hashPassword(pw), isGuest: false, createdAt: Date.now() }); db.save();
    if (!opts.quiet) console.log(`\n  ┌─ First run: admin account created\n  │  email:    ${adminEmail}\n  │  password: ${process.env.ADMIN_PASSWORD ? '(from ADMIN_PASSWORD)' : pw + '   ← shown once, change it in Admin → Security'}\n  └─ sign in at /admin.html\n`);
  }

  /* ---- helpers ---- */
  const fail = (status, message) => Object.assign(new Error(message), { status });
  const send = (res, status, obj, extra) => { const b = JSON.stringify(obj); res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'Content-Length': Buffer.byteLength(b), ...extra }); res.end(b); };
  const jsonBody = async req => { if (!/^application\/json/i.test(req.headers['content-type'] || '')) throw fail(415, 'Expected JSON'); const b = await readBody(req, 200e3); try { return b.length ? JSON.parse(b) : {}; } catch (e) { throw fail(400, 'Invalid JSON'); } };
  const ip = req => (opts.trustProxy || process.env.TRUST_PROXY ? String(req.headers['x-forwarded-for'] || '').split(',')[0].trim() : '') || req.socket.remoteAddress || '';
  const need = (req, role) => { const u = auth.user(req); if (!u) throw fail(401, 'Please sign in.'); if (role === 'admin' && u.role !== 'admin') throw fail(404, 'Not found'); return u; };
  const ownerOrAdmin = (u, o) => o && (u.role === 'admin' || o.userId === u.id);
  const findOrder = (idv, u) => { const o = D.orders.find(x => x.id === idv); if (!o || !ownerOrAdmin(u, o)) throw fail(404, 'Order not found'); return o; };
  const money = n => '₹' + Number(n).toLocaleString('en-IN');
  const headersFor = isHtml => ({
    'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'strict-origin-when-cross-origin', 'X-Frame-Options': 'DENY', 'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(self)',
    ...(isHtml ? { 'Content-Security-Policy': "default-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; object-src 'none'" } : {})
  });

  /* ---- routes ---- */
  const routes = [];
  const route = (method, re, fn) => routes.push([method, re, fn]);

  route('GET', /^\/api\/config$/, async (req, res) => {
    const s = D.settings;
    send(res, 200, { brand: catalog.site.name, site: { name: catalog.site.name, contactEmail: catalog.site.contactEmail, contactPhone: catalog.site.contactPhone, policies: catalog.site.policies }, methods: Pay.publicMethods(), upi: { payeeName: s.payeeName, upiId: s.upiId, instructions: s.instructions, qrUrl: '/media/qr?v=' + s.qrV, isDemo: !s.qrFile }, invoice: s.invoice });
  });
  route('GET', /^\/media\/qr$/, async (req, res) => {
    const f = D.settings.qrFile ? path.join(db.dir, D.settings.qrFile) : path.join(Static.ROOT, 'server/assets/demo-qr.png');
    if (!fs.existsSync(f)) throw fail(404, 'No QR');
    const t = sniffImage(fs.readFileSync(f).subarray(0, 16)) || { mime: 'image/png' };
    res.writeHead(200, { 'Content-Type': t.mime, 'Cache-Control': 'no-cache', ...headersFor(false) }); fs.createReadStream(f).pipe(res);
  });

  /* auth */
  route('POST', /^\/api\/auth\/register$/, async (req, res) => {
    if (!authLimit(ip(req))) throw fail(429, 'Too many attempts. Try again in a few minutes.');
    const b = await jsonBody(req), name = String(b.name || '').trim().slice(0, 60), email = String(b.email || '').trim().toLowerCase().slice(0, 120), pw = String(b.password || '');
    if (name.length < 2) throw fail(400, 'Please enter your name.');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) throw fail(400, 'Enter a valid email address.');
    if (pw.length < 8 || pw.length > 128) throw fail(400, 'Password must be 8–128 characters.');
    if (D.users.some(u => u.email === email)) throw fail(409, 'An account with this email already exists. Please sign in.');
    const cur = auth.user(req); let user;
    if (cur && cur.isGuest) { Object.assign(cur, { name, email, passHash: hashPassword(pw), isGuest: false }); user = cur; } // guest → full account keeps their orders
    else { user = { id: id(), role: 'customer', name, email, passHash: hashPassword(pw), isGuest: false, createdAt: Date.now(), profile: {} }; D.users.push(user); }
    db.save(); auth.login(req, res, user); send(res, 201, { user: publicUser(user) });
  });
  route('POST', /^\/api\/auth\/login$/, async (req, res) => {
    if (!authLimit(ip(req))) throw fail(429, 'Too many attempts. Try again in a few minutes.');
    const b = await jsonBody(req), email = String(b.email || '').trim().toLowerCase();
    if (!emailLimit(email)) throw fail(429, 'Too many attempts for this account. Try again later.');
    const u = D.users.find(x => x.email === email && !x.isGuest); const ok = verifyPassword(String(b.password || ''), u && u.passHash);
    if (!u || !ok) throw fail(401, 'Incorrect email or password.');
    auth.login(req, res, u); send(res, 200, { user: publicUser(u) });
  });
  route('POST', /^\/api\/auth\/guest$/, async (req, res) => {
    if (!guestLimit(ip(req))) throw fail(429, 'Too many attempts. Try again in a few minutes.');
    let u = auth.user(req); if (!u) { u = { id: id(), role: 'customer', name: '', email: '', isGuest: true, createdAt: Date.now(), profile: {} }; D.users.push(u); db.save(); auth.login(req, res, u); }
    send(res, 200, { user: publicUser(u) });
  });
  route('POST', /^\/api\/auth\/logout$/, async (req, res) => { auth.logout(req, res); send(res, 200, { ok: true }); });
  route('GET', /^\/api\/me$/, async (req, res) => send(res, 200, { user: publicUser(auth.user(req)) }));
  route('PATCH', /^\/api\/me$/, async (req, res) => {
    const u = need(req), b = await jsonBody(req);
    if (typeof b.name === 'string' && !u.isGuest) u.name = b.name.trim().slice(0, 60);
    if (b.profile && typeof b.profile === 'object') { const p = b.profile; u.profile = { phone: String(p.phone || '').slice(0, 20), line1: String(p.line1 || '').slice(0, 160), line2: String(p.line2 || '').slice(0, 160), pin: String(p.pin || '').slice(0, 6), city: String(p.city || '').slice(0, 60), state: String(p.state || '').slice(0, 40) }; }
    db.save(); send(res, 200, { user: publicUser(u) });
  });

  /* orders (private: owner or admin only) */
  route('POST', /^\/api\/orders$/, async (req, res) => {
    const u = need(req); if (!orderLimit(u.id)) throw fail(429, 'Too many orders. Please try again later.');
    const b = await jsonBody(req), m = Pay.method(b.method); if (!m) throw fail(400, 'That payment method is not available yet.');
    const o = Orders.create(db, u, b, m.id, catalog);
    u.profile = { phone: o.customer.phone, line1: o.customer.line1, line2: o.customer.line2, pin: o.customer.pin, city: o.customer.city, state: o.customer.state };
    if (!u.isGuest && !u.name) u.name = o.customer.name; db.save();
    notifier.push('new_order', o, 'New order ' + o.number, `${o.customer.name} · ${money(o.totals.total)} · awaiting payment`);
    send(res, 201, { order: Orders.view(o, false) });
  });
  route('GET', /^\/api\/orders$/, async (req, res) => { const u = need(req); send(res, 200, { orders: D.orders.filter(o => o.userId === u.id).map(o => Orders.view(o, false)) }); });
  route('GET', /^\/api\/orders\/([\w-]+)$/, async (req, res, m) => { const u = need(req); send(res, 200, { order: Orders.view(findOrder(m[1], u), u.role === 'admin') }); });
  route('POST', /^\/api\/orders\/([\w-]+)\/cancel$/, async (req, res, m) => {
    const u = need(req), o = findOrder(m[1], u); if (o.userId !== u.id) throw fail(404, 'Order not found');
    if (['awaiting_payment', 'payment_rejected'].indexOf(o.status) < 0) throw fail(409, 'This order can no longer be cancelled here. Please contact us.');
    Orders.transition(db, o, 'cancelled', 'Cancelled by customer', 'customer'); notifier.push('order_cancelled', o, 'Order cancelled ' + o.number, o.customer.name); send(res, 200, { order: Orders.view(o, false) });
  });
  route('POST', /^\/api\/orders\/([\w-]+)\/proof$/, async (req, res, m) => {
    const u = need(req), o = findOrder(m[1], u); if (o.userId !== u.id) throw fail(404, 'Order not found');
    if (!uploadLimit(u.id)) throw fail(429, 'Too many uploads. Please try again later.');
    if (['awaiting_payment', 'payment_rejected'].indexOf(o.status) < 0) throw fail(409, 'Payment proof can’t be changed for this order.');
    const { fields, file } = parseMultipart(await readBody(req, 6.5e6), req.headers['content-type']);
    if (!file || !file.data.length) throw fail(400, 'Please choose a screenshot to upload.');
    if (file.data.length > 6e6) throw fail(413, 'Screenshot is larger than 6 MB.');
    const t = sniffImage(file.data); if (!t) throw fail(400, 'Please upload a JPG, PNG or WebP image.');
    const utr = String(fields.utr || '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 30);
    if (utr && utr.length < 6) throw fail(400, 'Transaction/UTR reference looks too short.');
    if (o.proof && o.proof.file) fs.rmSync(path.join(db.uploads, o.proof.file), { force: true });
    const name = o.id + '-' + id(6) + '.' + t.ext; fs.writeFileSync(path.join(db.uploads, name), file.data, { mode: 0o600 });
    o.proof = { file: name, mime: t.mime, size: file.data.length, utr, at: Date.now() };
    Orders.transition(db, o, 'payment_review', utr ? 'Screenshot uploaded · ref ' + utr : 'Screenshot uploaded', 'customer');
    notifier.push('proof_uploaded', o, 'Payment screenshot · ' + o.number, `${o.customer.name} · ${money(o.totals.total)} — verify now`);
    send(res, 200, { order: Orders.view(o, false) });
  });
  route('GET', /^\/api\/orders\/([\w-]+)\/proof$/, async (req, res, m) => {
    const u = need(req), o = findOrder(m[1], u); if (!o.proof) throw fail(404, 'No screenshot');
    const f = path.join(db.uploads, path.basename(o.proof.file)); if (!fs.existsSync(f)) throw fail(404, 'No screenshot');
    res.writeHead(200, { 'Content-Type': o.proof.mime, 'Content-Length': o.proof.size, 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'none'; sandbox", 'Content-Disposition': 'inline' });
    fs.createReadStream(f).pipe(res);
  });

  /* guest-friendly tracking: short order number + the mobile number used at checkout (no sign-in needed) */
  const trackFails = new Map();
  function lookup(req, b) {
    if (!trackLimit(ip(req))) throw fail(429, 'Too many lookups. Please wait a few minutes and try again.');
    const num = Orders.normNumber(b.number), phone = Orders.normPhone(b.phone), key = num || 'x';
    const f = trackFails.get(key) || { n: 0, until: 0 };
    if (f.until > Date.now()) throw fail(429, 'Too many wrong attempts for this order. Please try again in 15 minutes, or sign in.');
    const o = num && phone.length === 10 ? D.orders.find(x => Orders.normNumber(x.number) === num) : null;
    if (!o || Orders.normPhone(o.customer.phone) !== phone) { f.n++; if (f.n >= 8) { f.until = Date.now() + 15 * 60e3; f.n = 0; } trackFails.set(key, f); if (trackFails.size > 5000) trackFails.clear(); throw fail(404, 'We couldn’t match that order number and mobile number. Check both and try again.'); }
    trackFails.delete(key); return o;
  }
  const ownerIsGuest = o => { const u = D.users.find(x => x.id === o.userId); return !u || u.isGuest; };
  route('POST', /^\/api\/track$/, async (req, res) => { const o = lookup(req, await jsonBody(req)); send(res, 200, { order: Orders.trackView(o, ownerIsGuest(o)) }); });
  route('POST', /^\/api\/track\/claim$/, async (req, res) => {
    const b = await jsonBody(req), o = lookup(req, b); if (!ownerIsGuest(o)) throw fail(409, 'This order belongs to an account. Please sign in to open it.');
    let u = auth.user(req); if (!u) { u = { id: id(), role: 'customer', name: '', email: '', isGuest: true, createdAt: Date.now(), profile: {} }; D.users.push(u); auth.login(req, res, u); }
    if (u.role === 'admin') throw fail(400, 'Admins cannot claim orders.');
    if (o.userId !== u.id) { o.userId = u.id; o.timeline.push({ at: Date.now(), status: o.status, note: 'Opened on a new device', by: 'customer' }); db.save(); }
    send(res, 200, { orderId: o.id, user: publicUser(u) });
  });

  /* the home page is rendered with the admin's content so the first paint is already correct */
  let homeCache = { v: -1, raw: null, gz: null, etag: '' };
  const serveHome = async (req, res) => {
    const mt = fs.statSync(path.join(Static.ROOT, 'index.html')).mtimeMs;
    if (homeCache.v !== catalog.D.version + ':' + mt) { const raw = Buffer.from(Home.renderIndex(fs.readFileSync(path.join(Static.ROOT, 'index.html'), 'utf8'), catalog)); homeCache = { v: catalog.D.version + ':' + mt, raw, gz: zlib.gzipSync(raw, { level: 9 }), etag: '"h' + catalog.D.version + '-' + raw.length.toString(36) + '"' }; }
    const h = { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache', ETag: homeCache.etag, Vary: 'Accept-Encoding', ...headersFor(true) };
    if (req.headers['if-none-match'] === homeCache.etag) { res.writeHead(304, h); return res.end(); }
    if (/\bgzip\b/.test(req.headers['accept-encoding'] || '')) { res.writeHead(200, { ...h, 'Content-Encoding': 'gzip', 'Content-Length': homeCache.gz.length }); return res.end(req.method === 'HEAD' ? undefined : homeCache.gz); }
    res.writeHead(200, { ...h, 'Content-Length': homeCache.raw.length }); res.end(req.method === 'HEAD' ? undefined : homeCache.raw);
  };
  route('GET', /^\/(index\.html)?$/, serveHome); route('HEAD', /^\/(index\.html)?$/, serveHome);
  route('GET', /^\/media\/s\/([A-Za-z0-9_]{6,12})-(wide|tall)-(480|800|1080|1280|1920|2560)\.(webp|jpg|png)$/, async (req, res, m) => {
    const f = catalog.heroPath(m[1], m[2], +m[3], m[4]); if (!fs.existsSync(f)) throw fail(404, 'Not found');
    const t = sniffImage(fs.readFileSync(f).subarray(0, 16)); if (!t) throw fail(404, 'Not found');
    res.writeHead(200, { 'Content-Type': t.mime, 'Cache-Control': 'public, max-age=31536000, immutable', ...headersFor(false) }); fs.createReadStream(f).pipe(res);
  });
  /* generated storefront data: the static defaults + the live catalogue */
  let dataCache = { v: -1, raw: null, gz: null, etag: '' };
  route('GET', /^\/js\/data\.js$/, async (req, res) => {
    if (dataCache.v !== catalog.D.version) { const raw = Buffer.from(fs.readFileSync(path.join(Static.ROOT, 'js/data.js'), 'utf8') + catalog.overlay()); dataCache = { v: catalog.D.version, raw, gz: zlib.gzipSync(raw, { level: 9 }), etag: '"d' + catalog.D.version + '-' + raw.length.toString(36) + '"' }; }
    const h = { 'Content-Type': 'text/javascript; charset=utf-8', 'Cache-Control': 'no-cache', ETag: dataCache.etag, Vary: 'Accept-Encoding', ...headersFor(false) };
    if (req.headers['if-none-match'] === dataCache.etag) { res.writeHead(304, h); return res.end(); }
    if (/\bgzip\b/.test(req.headers['accept-encoding'] || '')) { res.writeHead(200, { ...h, 'Content-Encoding': 'gzip', 'Content-Length': dataCache.gz.length }); return res.end(dataCache.gz); }
    res.writeHead(200, { ...h, 'Content-Length': dataCache.raw.length }); res.end(dataCache.raw);
  });
  route('GET', /^\/media\/p\/([a-z0-9-]+)\/([A-Za-z0-9_]{6,12})-(400|800|1200)\.(webp|jpg|png)$/, async (req, res, m) => {
    const f = catalog.mediaPath(m[1], `${m[2]}-${m[3]}.${m[4]}`); if (!fs.existsSync(f)) throw fail(404, 'Not found');
    const t = sniffImage(fs.readFileSync(f).subarray(0, 16)); if (!t) throw fail(404, 'Not found');
    res.writeHead(200, { 'Content-Type': t.mime, 'Cache-Control': 'public, max-age=31536000, immutable', ...headersFor(false) }); fs.createReadStream(f).pipe(res);
  });

  /* admin */
  /* ---- admin: catalogue, categories, store settings ---- */
  const adminProduct = p => ({ ...p, imageUrls: p.images.map(r => ({ rev: r, url: catalog.imgUrl(p, r, p.imageStore[r].ws.indexOf(400) > -1 ? 400 : p.imageStore[r].ws[0]) })), thumb: catalog.thumb(p), imageStore: undefined });
  route('GET', /^\/api\/admin\/catalog$/, async (req, res) => { need(req, 'admin'); send(res, 200, { products: catalog.products.map(adminProduct), categories: catalog.categories, site: catalog.site, stitch: A.STITCH.map(x => ({ id: x.id, label: x.label })), occasions: A.OCCASIONS, demoCount: catalog.products.filter(p => p.demo).length }); });
  route('POST', /^\/api\/admin\/products$/, async (req, res) => { need(req, 'admin'); const p = catalog.create(await jsonBody(req)); send(res, 201, { product: adminProduct(p) }); });
  route('PUT', /^\/api\/admin\/products\/([a-z0-9-]+)$/, async (req, res, m) => { need(req, 'admin'); send(res, 200, { product: adminProduct(catalog.update(m[1], await jsonBody(req))) }); });
  route('DELETE', /^\/api\/admin\/products\/([a-z0-9-]+)$/, async (req, res, m) => { need(req, 'admin'); catalog.remove(m[1]); send(res, 200, { ok: true }); });
  route('POST', /^\/api\/admin\/products\/([a-z0-9-]+)\/image$/, async (req, res, m) => {
    need(req, 'admin'); const p = catalog.find(m[1]); if (!p) throw fail(404, 'Product not found');
    const q = new URL(req.url, 'http://x').searchParams, data = await readBody(req, 1.6e6); const t = sniffImage(data); if (!t) throw fail(400, 'Please upload a JPG, PNG or WebP photo.');
    catalog.addImage(p, q.get('rev') || '', parseInt(q.get('w'), 10), t.ext, data); send(res, 200, { product: adminProduct(p) });
  });
  route('PUT', /^\/api\/admin\/categories$/, async (req, res) => { need(req, 'admin'); catalog.setCategories((await jsonBody(req)).categories); send(res, 200, { categories: catalog.categories }); });
  route('PUT', /^\/api\/admin\/site$/, async (req, res) => { need(req, 'admin'); catalog.setSite(await jsonBody(req)); send(res, 200, { site: catalog.site }); });
  route('POST', /^\/api\/admin\/hero-image$/, async (req, res) => {
    need(req, 'admin'); const q = new URL(req.url, 'http://x').searchParams, data = await readBody(req, 2.6e6), t = sniffImage(data); if (!t) throw fail(400, 'Please upload a JPG, PNG or WebP photo.');
    catalog.addHeroFile(q.get('rev') || '', q.get('kind') || '', parseInt(q.get('w'), 10), t.ext, data); send(res, 200, { ok: true });
  });
  /* orders can be deleted by the admin only (e.g. test orders before launch) */
  const dropOrder = o => { if (o.proof && o.proof.file) fs.rmSync(path.join(db.uploads, path.basename(o.proof.file)), { force: true }); };
  route('DELETE', /^\/api\/admin\/orders\/([\w-]+)$/, async (req, res, m) => { need(req, 'admin'); const o = D.orders.find(x => x.id === m[1]); if (!o) throw fail(404, 'Order not found'); dropOrder(o); D.orders = D.orders.filter(x => x !== o); D.notifications = D.notifications.filter(n => n.orderId !== o.id); db.save(); send(res, 200, { ok: true }); });
  route('POST', /^\/api\/admin\/orders\/clear$/, async (req, res) => { need(req, 'admin'); if ((await jsonBody(req)).confirm !== 'DELETE') throw fail(400, 'Type DELETE to confirm.'); const n = D.orders.length; D.orders.forEach(dropOrder); D.orders = []; D.notifications = []; db.save(); send(res, 200, { removed: n }); });
  route('POST', /^\/api\/admin\/catalog\/clear-demo$/, async (req, res) => { need(req, 'admin'); send(res, 200, { removed: catalog.clearDemo() }); });

  route('GET', /^\/api\/admin\/summary$/, async (req, res) => {
    need(req, 'admin'); const c = {}; Object.keys(Orders.STATUS).forEach(k => c[k] = 0); D.orders.forEach(o => c[o.status]++);
    const rev = D.orders.filter(o => ['paid', 'processing', 'shipped', 'delivered'].indexOf(o.status) > -1).reduce((a, o) => a + o.totals.total, 0);
    send(res, 200, { products: catalog.products.length, demoProducts: catalog.products.filter(p => p.demo).length, counts: c, revenue: rev, orders: D.orders.length, customers: D.users.filter(u => u.role === 'customer' && !u.isGuest).length, guests: D.users.filter(u => u.isGuest).length, unread: D.notifications.filter(n => !n.read).length, qrIsDemo: !D.settings.qrFile, upiSet: !!D.settings.upiId });
  });
  route('GET', /^\/api\/admin\/orders$/, async (req, res) => {
    need(req, 'admin'); const q = new URL(req.url, 'http://x').searchParams, st = q.get('status'), s = (q.get('q') || '').toLowerCase();
    send(res, 200, { orders: D.orders.filter(o => (!st || o.status === st) && (!s || (o.number + ' ' + Orders.normNumber(o.number) + ' ' + o.customer.name + ' ' + o.customer.email + ' ' + o.customer.phone + ' ' + (o.proof && o.proof.utr || '')).toLowerCase().includes(s))).slice(0, 300).map(o => Orders.view(o, true)) });
  });
  route('PATCH', /^\/api\/admin\/orders\/([\w-]+)$/, async (req, res, m) => {
    const u = need(req, 'admin'), o = D.orders.find(x => x.id === m[1]); if (!o) throw fail(404, 'Order not found');
    const b = await jsonBody(req), note = String(b.note || '').slice(0, 300);
    if (b.action === 'verify') { if (['payment_review', 'payment_rejected', 'awaiting_payment'].indexOf(o.status) < 0) throw fail(409, 'Not awaiting verification.'); Orders.transition(db, o, 'paid', note || 'Payment verified', 'admin'); }
    else if (b.action === 'reject') { if (o.status !== 'payment_review') throw fail(409, 'Nothing to reject.'); Orders.transition(db, o, 'payment_rejected', note || 'We could not verify this payment. Please upload a clear screenshot.', 'admin'); }
    else if (b.action === 'status') {
      if ((Orders.ADMIN_NEXT[o.status] || []).indexOf(b.status) < 0) throw fail(409, 'Invalid status change.');
      if (b.tracking !== undefined) o.tracking = Orders.cleanTracking(b.tracking);
      Orders.transition(db, o, b.status, note, 'admin');
    }
    else if (b.action === 'tracking') { o.tracking = Orders.cleanTracking(b.tracking); o.updatedAt = Date.now(); o.timeline.push({ at: o.updatedAt, status: o.status, note: o.tracking ? 'Tracking details updated' : 'Tracking details removed', by: 'admin' }); db.save(); }
    else throw fail(400, 'Unknown action');
    send(res, 200, { order: Orders.view(o, true) });
  });
  route('GET', /^\/api\/admin\/settings$/, async (req, res) => { need(req, 'admin'); const s = D.settings; send(res, 200, { invoice: s.invoice, payeeName: s.payeeName, upiId: s.upiId, instructions: s.instructions, webhookUrl: s.webhookUrl, qrUrl: '/media/qr?v=' + s.qrV, qrIsDemo: !s.qrFile, envWebhook: !!process.env.ADMIN_WEBHOOK_URL }); });
  route('PUT', /^\/api\/admin\/settings$/, async (req, res) => {
    need(req, 'admin'); const b = await jsonBody(req), s = D.settings;
    if (b.upiId !== undefined) { const v = String(b.upiId).trim().slice(0, 80); if (v && !/^[\w.\-]{2,}@[\w.\-]{2,}$/.test(v)) throw fail(400, 'UPI ID should look like name@bank.'); s.upiId = v; }
    if (b.invoice && typeof b.invoice === 'object') { const i = b.invoice, c = (v, n) => String(v == null ? '' : v).trim().slice(0, n); const g = c(i.gstin, 15).toUpperCase(); if (g && !/^[0-9A-Z]{15}$/.test(g)) throw fail(400, 'GSTIN should be 15 letters/digits (or leave it blank).'); s.invoice = { name: c(i.name, 80) || 'ASINGH', address: c(i.address, 240), gstin: g, contact: c(i.contact, 120) }; }
    if (b.payeeName !== undefined) s.payeeName = String(b.payeeName).trim().slice(0, 60) || 'ASINGH';
    if (b.instructions !== undefined) s.instructions = String(b.instructions).trim().slice(0, 500);
    if (b.webhookUrl !== undefined) { const v = String(b.webhookUrl).trim().slice(0, 300); if (v) { let u; try { u = new URL(v); } catch (e) { throw fail(400, 'Webhook URL is not valid.'); } if (u.protocol !== 'https:') throw fail(400, 'Webhook URL must start with https://'); } s.webhookUrl = v; }
    db.save(); send(res, 200, { ok: true });
  });
  route('POST', /^\/api\/admin\/qr$/, async (req, res) => {
    need(req, 'admin'); const { file } = parseMultipart(await readBody(req, 3.5e6), req.headers['content-type']);
    if (!file || !file.data.length) throw fail(400, 'Choose a QR image.'); if (file.data.length > 3e6) throw fail(413, 'QR image must be under 3 MB.');
    const t = sniffImage(file.data); if (!t) throw fail(400, 'QR must be a JPG, PNG or WebP image.');
    if (D.settings.qrFile) fs.rmSync(path.join(db.dir, D.settings.qrFile), { force: true });
    const name = 'qr-' + id(5) + '.' + t.ext; fs.writeFileSync(path.join(db.dir, name), file.data, { mode: 0o600 });
    D.settings.qrFile = name; D.settings.qrV = Date.now(); db.save(); send(res, 200, { qrUrl: '/media/qr?v=' + D.settings.qrV });
  });
  route('DELETE', /^\/api\/admin\/qr$/, async (req, res) => { need(req, 'admin'); if (D.settings.qrFile) fs.rmSync(path.join(db.dir, D.settings.qrFile), { force: true }); D.settings.qrFile = ''; D.settings.qrV = Date.now(); db.save(); send(res, 200, { ok: true }); });
  route('GET', /^\/api\/admin\/notifications$/, async (req, res) => { need(req, 'admin'); send(res, 200, { notifications: D.notifications.slice(0, 60), unread: D.notifications.filter(n => !n.read).length }); });
  route('POST', /^\/api\/admin\/notifications\/read$/, async (req, res) => { need(req, 'admin'); D.notifications.forEach(n => n.read = true); db.save(); send(res, 200, { ok: true }); });
  route('POST', /^\/api\/admin\/test-alert$/, async (req, res) => { need(req, 'admin'); notifier.push('test', null, 'Test alert', 'Alerts are working — you will see this here, in your browser, and on your webhook.'); send(res, 200, { ok: true }); });
  route('GET', /^\/api\/admin\/events$/, async (req, res) => { need(req, 'admin'); notifier.attach(req, res); });
  route('POST', /^\/api\/admin\/password$/, async (req, res) => {
    const u = need(req, 'admin'), b = await jsonBody(req); if (!authLimit(ip(req))) throw fail(429, 'Too many attempts.');
    if (!verifyPassword(String(b.current || ''), u.passHash)) throw fail(401, 'Current password is incorrect.');
    const np = String(b.next || ''); if (np.length < 10 || np.length > 128) throw fail(400, 'New password must be 10–128 characters.');
    u.passHash = hashPassword(np); db.save(); auth.revokeOthers(u, req); send(res, 200, { ok: true });
  });

  /* ---- admin accounts: change your own login, add/remove other admins (all admin-only) ---- */
  const validEmail = e => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e);
  const adminView = (u, me) => ({ id: u.id, email: u.email, name: u.name || '', createdAt: u.createdAt, self: u.id === me.id });
  route('GET', /^\/api\/admin\/admins$/, async (req, res) => { const me = need(req, 'admin'); send(res, 200, { admins: D.users.filter(u => u.role === 'admin').map(u => adminView(u, me)) }); });
  route('POST', /^\/api\/admin\/account$/, async (req, res) => {
    const u = need(req, 'admin'), b = await jsonBody(req); if (!authLimit(ip(req))) throw fail(429, 'Too many attempts.');
    if (!verifyPassword(String(b.current || ''), u.passHash)) throw fail(401, 'Current password is incorrect.');
    if (b.email !== undefined && String(b.email).trim().toLowerCase() !== u.email) { const e = String(b.email).trim().toLowerCase().slice(0, 120); if (!validEmail(e)) throw fail(400, 'Enter a valid email — it is your admin username.'); if (D.users.some(x => x.email === e && x.id !== u.id)) throw fail(409, 'That email is already used by another account.'); u.email = e; }
    if (b.next) { const np = String(b.next); if (np.length < 10 || np.length > 128) throw fail(400, 'New password must be 10–128 characters.'); u.passHash = hashPassword(np); }
    if (b.name !== undefined) u.name = String(b.name).trim().slice(0, 60);
    db.save(); if (b.next) auth.revokeOthers(u, req); send(res, 200, { admin: adminView(u, u) });
  });
  route('POST', /^\/api\/admin\/admins$/, async (req, res) => {
    const me = need(req, 'admin'), b = await jsonBody(req), e = String(b.email || '').trim().toLowerCase().slice(0, 120), pw = String(b.password || '');
    if (!validEmail(e)) throw fail(400, 'Enter a valid email for the new admin.'); if (pw.length < 10 || pw.length > 128) throw fail(400, 'Password must be 10–128 characters.');
    if (D.users.some(x => x.email === e)) throw fail(409, 'That email is already used by another account.');
    const u = { id: id(), role: 'admin', name: String(b.name || '').trim().slice(0, 60), email: e, passHash: hashPassword(pw), isGuest: false, createdAt: Date.now() }; D.users.push(u); db.save();
    notifier.push('admin_added', null, 'Admin added', `${e} was added by ${me.email}`); send(res, 201, { admin: adminView(u, me) });
  });
  route('DELETE', /^\/api\/admin\/admins\/([\w-]+)$/, async (req, res, m) => {
    const me = need(req, 'admin'), u = D.users.find(x => x.id === m[1] && x.role === 'admin'); if (!u) throw fail(404, 'Admin not found');
    if (u.id === me.id) throw fail(409, 'You can’t remove your own account. Ask another admin.'); if (D.users.filter(x => x.role === 'admin').length < 2) throw fail(409, 'Keep at least one admin.');
    D.users = D.users.filter(x => x !== u); D.sessions = D.sessions.filter(x => x.uid !== u.id); auth.bySid = new Map(D.sessions.map(x => [x.h, x])); db.save(); send(res, 200, { ok: true });
  });

  /* payment webhooks from future gateways (signature-verified) */
  route('POST', /^\/api\/webhooks\/([a-z0-9_-]+)$/, async (req, res, m) => {
    const raw = await readBody(req, 200e3), ad = Pay.adapter(m[1]); if (!ad) throw fail(404, 'Unknown provider');
    if (!ad.verify(raw, req.headers, ad.secret)) throw fail(401, 'Bad signature');
    let ev; try { ev = ad.parse(JSON.parse(raw.toString('utf8'))); } catch (e) { throw fail(400, 'Bad payload'); }
    const o = ev && D.orders.find(x => Orders.normNumber(x.number) === Orders.normNumber(ev.orderNumber)); if (!o) return send(res, 202, { ignored: true });
    if (ev.status === 'paid') {
      if (['paid', 'processing', 'shipped', 'delivered', 'cancelled'].indexOf(o.status) > -1) return send(res, 200, { ok: true, duplicate: true });
      const mismatch = ev.amount != null && Math.abs(Number(ev.amount) - o.totals.total) > 1;
      Orders.transition(db, o, 'paid', `Confirmed by ${m[1]}${ev.reference ? ' · ' + ev.reference : ''}${mismatch ? ' · AMOUNT MISMATCH ' + ev.amount : ''}`, 'webhook:' + m[1]);
      notifier.push('payment_confirmed', o, 'Payment confirmed · ' + o.number, `${m[1]} · ${money(o.totals.total)}${mismatch ? ' — amount differs, check!' : ''}`);
    } else notifier.push('payment_failed', o, 'Payment failed · ' + o.number, m[1]);
    send(res, 200, { ok: true });
  });

  /* ---- dispatcher ---- */
  const server = http.createServer(async (req, res) => {
    try {
      const url = req.url.split('?')[0];
      if (url.startsWith('/api/') || url === '/media/qr' || url === '/js/data.js' || url.startsWith('/media/p/') || url.startsWith('/media/s/') || url === '/' || url === '/index.html') {
        const mutating = req.method !== 'GET' && req.method !== 'HEAD';
        if (mutating && !url.startsWith('/api/webhooks/')) {
          if (req.headers['x-requested-with'] !== 'asingh') throw fail(403, 'Blocked request');
          const o = req.headers.origin; if (o && new URL(o).host !== req.headers.host) throw fail(403, 'Blocked cross-origin request');
        }
        for (const [method, re, fn] of routes) { const m = re.exec(url); if (m && method === req.method) return await fn(req, res, m); }
        throw fail(404, 'Not found');
      }
      if (req.method !== 'GET' && req.method !== 'HEAD') throw fail(405, 'Method not allowed');
      if (Static.serve(req, res, headersFor)) return;
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', ...headersFor(false) }); res.end('Not found');
    } catch (e) {
      const status = e.status || 500; if (status === 500) console.error(e);
      if (res.headersSent) return res.end();
      send(res, status, { error: status === 500 ? 'Something went wrong. Please try again.' : e.message });
    }
  });
  return { server, db, notifier, resetTrackLocks: () => trackFails.clear() };
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 3000, host = process.env.HOST || '0.0.0.0';
  createApp().server.listen(port, host, () => console.log(`  ASINGH store → http://localhost:${port}   (admin: /admin.html)`));
}
module.exports = { createApp };
