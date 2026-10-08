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
  /* Google Analytics hosts are allowed only when the admin has set a GA4 id */
  const csp = () => { const ga = catalog.site.ga4Id, gs = ga ? ' https://www.googletagmanager.com' : '', gc = ga ? ' https://*.google-analytics.com https://*.analytics.google.com https://*.googletagmanager.com' : ''; return `default-src 'self'; img-src 'self' data: blob:${gc}; style-src 'self' 'unsafe-inline'; script-src 'self'${gs}; connect-src 'self'${gc}; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'`; };
  const headersFor = isHtml => ({
    'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'strict-origin-when-cross-origin', 'X-Frame-Options': 'DENY', 'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(self)',
    ...(isHtml ? { 'Content-Security-Policy': csp() } : {})
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

  /* ---- HTML pages: server-injected SEO/share tags, CMS pages, sitemap/robots/manifest, branded 404 ---- */
  const SEO = require('./seo'), Pages = require('./pages');
  const tplCache = new Map();
  const tpl = name => { const f = path.join(Static.ROOT, name), mt = fs.statSync(f).mtimeMs, c = tplCache.get(name); if (c && c.mt === mt) return c.html; const html = fs.readFileSync(f, 'utf8'); tplCache.set(name, { mt, html }); return html; };
  const sendHtml = (req, res, status, html, extra) => {
    const raw = Buffer.from(html), etag = '"' + crypto.createHash('sha1').update(raw).digest('base64url').slice(0, 20) + '"';
    const h = { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache', ETag: etag, Vary: 'Accept-Encoding', ...headersFor(true), ...extra };
    if (status === 200 && req.headers['if-none-match'] === etag) { res.writeHead(304, h); return res.end(); }
    if (/\bgzip\b/.test(req.headers['accept-encoding'] || '')) { const gz = zlib.gzipSync(raw, { level: 6 }); res.writeHead(status, { ...h, 'Content-Encoding': 'gzip', 'Content-Length': gz.length }); return res.end(req.method === 'HEAD' ? undefined : gz); }
    res.writeHead(status, { ...h, 'Content-Length': raw.length }); res.end(req.method === 'HEAD' ? undefined : raw);
  };
  const SSR = require('./ssr');
  const feedImg = p => (p.images.length ? catalog.imgUrl(p, p.images[0], 'feed') : `img/${p.id}-1-800.jpg`);
  const first = p => (p.images.length ? catalog.imgUrl(p, p.images[0], p.imageStore[p.images[0]].ws.indexOf(800) > -1 ? 800 : p.imageStore[p.images[0]].ws[0]) : `img/${p.id}-1-800.jpg`);
  const siteLd = o => ({ '@context': 'https://schema.org', '@type': 'Organization', name: catalog.site.name, url: o, logo: o + '/img/icons/icon-512.png', ...(catalog.site.contactEmail ? { email: catalog.site.contactEmail } : {}), ...(catalog.site.contactPhone ? { telephone: catalog.site.contactPhone } : {}), ...(catalog.site.contactEmail || catalog.site.contactPhone ? { contactPoint: { '@type': 'ContactPoint', contactType: 'customer service', areaServed: 'IN', availableLanguage: ['en', 'hi'], ...(catalog.site.contactEmail ? { email: catalog.site.contactEmail } : {}), ...(catalog.site.contactPhone ? { telephone: catalog.site.contactPhone } : {}) } } : {}) });
  /* per-page SEO description */
  function seoFor(name, req, u) {
    const o = SEO.origin(req), t = catalog.site, base = { origin: o, site: t.name, verify: t.googleSiteVerification };
    const noindex = { ...base, title: ({ cart: 'Your bag', checkout: 'Checkout', account: 'My account', track: 'Track your order', order: 'Your order', invoice: 'Order bill', admin: 'Admin' }[name] || name) + ' — ' + t.name, desc: t.name, noindex: true, path: name + '.html' };
    if (name === 'shop') {
      const c = catalog.categories.find(x => x.id === u.searchParams.get('cat')), q = u.searchParams.get('q');
      if (q || u.searchParams.get('wishlist')) return { ...noindex, title: 'Search — ' + t.name };
      const label = c ? c.label : 'All Rajputi dresses';
      const demo = catalog.products.find(p => p.published && (!c || p.cat === c.id));
      return { ...base, title: `${label} | ${t.name}`, desc: `Shop ${label.toLowerCase()} at ${t.name}: ${t.heroLead}`, path: 'shop.html' + (c ? '?cat=' + c.id : ''), image: demo ? first(demo) : '', ld: SEO.crumbs(o, [['Home', '/'], ['Shop', 'shop.html']].concat(c ? [[c.label, 'shop.html?cat=' + c.id]] : [])) };
    }
    if (name === 'product') {
      const p = catalog.find(u.searchParams.get('id'));
      if (!p || !p.published) return { ...noindex, title: 'Piece not available — ' + t.name, status: 404 };
      const cat = catalog.categories.find(x => x.id === p.cat), url = 'product.html?id=' + p.id, img = SEO.abs(o, feedImg(p)), price = SSR.basePrice(catalog, p);
      const free = price >= t.shipFreeFrom, onlyCustom = p.stitch.every(x => x === 'custom');
      const offer = { '@type': 'Offer', priceCurrency: 'INR', price, priceValidUntil: new Date(Date.now() + 90 * 864e5).toISOString().slice(0, 10), itemCondition: 'https://schema.org/NewCondition', availability: 'https://schema.org/' + (p.soldOut ? 'OutOfStock' : 'InStock'), url: SEO.abs(o, url), seller: { '@type': 'Organization', name: t.name },
        shippingDetails: { '@type': 'OfferShippingDetails', shippingRate: { '@type': 'MonetaryAmount', value: free ? 0 : t.shipFlat, currency: 'INR' }, shippingDestination: { '@type': 'DefinedRegion', addressCountry: 'IN' }, deliveryTime: { '@type': 'ShippingDeliveryTime', handlingTime: { '@type': 'QuantitativeValue', minValue: t.handlingMin, maxValue: t.handlingMax, unitCode: 'DAY' }, transitTime: { '@type': 'QuantitativeValue', minValue: t.deliveryMin, maxValue: t.deliveryMax, unitCode: 'DAY' } } },
        hasMerchantReturnPolicy: t.returnDays > 0 && !onlyCustom ? { '@type': 'MerchantReturnPolicy', applicableCountry: 'IN', returnPolicyCategory: 'https://schema.org/MerchantReturnFiniteReturnWindow', merchantReturnDays: t.returnDays, returnMethod: 'https://schema.org/ReturnByMail', returnFees: 'https://schema.org/ReturnFeesCustomerResponsibility' } : { '@type': 'MerchantReturnPolicy', applicableCountry: 'IN', returnPolicyCategory: 'https://schema.org/MerchantReturnNotPermitted' } };
      const real = !p.demo && p.rating && p.reviews > 0;   // never publish demo/placeholder ratings as structured data
      const ld = [{ '@context': 'https://schema.org', '@type': 'Product', name: p.name, description: p.blurb || p.name, image: p.images.length ? p.images.map(r => SEO.abs(o, catalog.imgUrl(p, r, 'feed'))) : [img], sku: p.id, mpn: p.id, category: cat && cat.label, material: p.fabric || undefined, color: p.colors.map(c => c.name).join(', '), brand: { '@type': 'Brand', name: t.name }, ...(real ? { aggregateRating: { '@type': 'AggregateRating', ratingValue: p.rating, reviewCount: p.reviews } } : {}), offers: offer }, SEO.crumbs(o, [['Home', '/'], ['Shop', 'shop.html'], [cat ? cat.label : 'Shop', 'shop.html?cat=' + p.cat], [p.name, url]])];
      return { ...base, title: `${p.name} | ${t.name}`, desc: (p.blurb || p.name) + ` Price ₹${price.toLocaleString('en-IN')}.`, path: url, image: feedImg(p), type: 'product', ld, product: p };
    }
    return noindex;
  }
  const htmlRoute = name => async (req, res) => {
    const u = new URL(req.url, 'http://x'), s = seoFor(name, req, u); let html = tpl(name + '.html');
    html = SEO.apply(html, s);
    if (name === 'product' && s.product) html = html.replace('<div class="pdp" id="pdp"></div>', '<div class="pdp" id="pdp">' + SSR.product(catalog, s.product) + '</div>');
    if (name === 'shop' && !u.searchParams.get('q') && !u.searchParams.get('wishlist')) { const c = u.searchParams.get('cat'); html = html.replace('<div class="grid grid--shop" id="grid"></div>', '<div class="grid grid--shop" id="grid">' + SSR.grid(catalog, catalog.products.filter(p => p.published && (!c || p.cat === c))) + '</div>'); }
    if (name === 'product' && s.status === 404) return sendHtml(req, res, 404, html); sendHtml(req, res, 200, html);
  };
  ['shop', 'product', 'cart', 'checkout', 'account', 'track', 'order', 'invoice', 'admin'].forEach(n => { route('GET', new RegExp('^\\/' + n + '\\.html$'), htmlRoute(n)); route('HEAD', new RegExp('^\\/' + n + '\\.html$'), htmlRoute(n)); });
  const serveHome = async (req, res) => {
    const o = SEO.origin(req), t = catalog.site; let html = Home.renderIndex(tpl('index.html'), catalog);
    const h = t.heroImage ? `/media/s/${t.heroImage.rev}-wide-1920.${t.heroImage.ext}` : 'img/hero-wide-1920.jpg';
    html = html.replace('<div class="grid" id="new-grid"></div>', '<div class="grid" id="new-grid">' + SSR.grid(catalog, catalog.products.filter(p => p.published).sort((a, b) => (b.isNew ? 1 : 0) - (a.isNew ? 1 : 0)), 8) + '</div>');
    html = SEO.apply(html, { origin: o, verify: t.googleSiteVerification, site: t.name, title: t.name + ' — ' + (t.heroEyebrow || 'Rajputi dresses'), desc: t.heroLead, path: '', image: h, ld: [siteLd(o), { '@context': 'https://schema.org', '@type': 'WebSite', name: t.name, url: o, potentialAction: { '@type': 'SearchAction', target: o + '/shop.html?q={search_term_string}', 'query-input': 'required name=search_term_string' } }] });
    sendHtml(req, res, 200, html);
  };
  route('GET', /^\/(index\.html)?$/, serveHome); route('HEAD', /^\/(index\.html)?$/, serveHome);
  /* admin-editable content pages live at /<slug>.html (about, faq, contact, privacy-policy…) */
  const serveCms = async (req, res, m) => {
    const p = catalog.page(m[1]); if (!p || !p.published) return serve404(req, res);
    const o = SEO.origin(req), t = catalog.site; let html = tpl('page.html'), extra = '';
    const body = Pages.render(p.body, catalog.pageVars());
    if (p.slug === 'contact') extra = '<section class="contactform" aria-labelledby="cf-h"><h2 id="cf-h" class="h3">Send us a message</h2><form id="contact-form" novalidate><div class="fields"><div class="field"><label class="field__l" for="c-name">Your name</label><input class="input" id="c-name" name="name" autocomplete="name" maxlength="80" required></div><div class="field"><label class="field__l" for="c-email">Email</label><input class="input" id="c-email" name="email" type="email" inputmode="email" autocomplete="email" maxlength="120" required></div><div class="field"><label class="field__l" for="c-phone">Mobile <span class="muted">(optional)</span></label><input class="input" id="c-phone" name="phone" type="tel" inputmode="tel" autocomplete="tel" maxlength="20"></div><div class="field field--wide"><label class="field__l" for="c-msg">How can we help?</label><textarea class="input" id="c-msg" name="message" rows="5" maxlength="2000" required></textarea></div></div><div class="hp" aria-hidden="true"><label>Website <input name="website" tabindex="-1" autocomplete="off"></label></div><p class="field__err" id="c-err" role="alert"></p><button class="btn btn--lg" type="submit"><span>Send message</span></button><p class="muted" id="c-ok" role="status"></p></form></section>';
    html = SEO.apply(html, { origin: o, site: t.name, title: `${p.title} | ${t.name}`, desc: Pages.plain(Pages.render(p.body, catalog.pageVars()).replace(/<[^>]+>/g, ' '), 160) || p.title, path: p.slug + '.html', verify: t.googleSiteVerification, ld: SEO.crumbs(o, [['Home', '/'], [p.title, p.slug + '.html']]) });
    html = html.replace('<!--@crumb-->', SEO.esc(p.title)).replace('<!--@h1-->', SEO.esc(p.title)).replace('<!--@body-->', body).replace('<!--@extra-->', extra);
    sendHtml(req, res, 200, html);
  };
  route('GET', /^\/([a-z0-9-]{2,40})\.html$/, serveCms); route('HEAD', /^\/([a-z0-9-]{2,40})\.html$/, serveCms);
  function serve404(req, res) { const o = SEO.origin(req); sendHtml(req, res, 404, SEO.apply(tpl('404.html'), { origin: o, site: catalog.site.name, title: 'Page not found — ' + catalog.site.name, desc: 'Page not found', noindex: true, path: '' })); }
  /* sitemap, robots, web-app manifest */
  route('GET', /^\/sitemap\.xml$/, async (req, res) => {
    const o = SEO.origin(req), u = [['', 1], ['shop.html', .9]].concat(catalog.categories.filter(c => catalog.products.some(p => p.published && p.cat === c.id)).map(c => ['shop.html?cat=' + c.id, .8]), catalog.products.filter(p => p.published).map(p => ['product.html?id=' + p.id, .7]), catalog.pages.filter(p => p.published).map(p => [p.slug + '.html', .4]), [['track.html', .3]]);
    const body = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + u.map(x => `<url><loc>${SEO.esc(SEO.abs(o, x[0]))}</loc><priority>${x[1]}</priority></url>`).join('\n') + '\n</urlset>\n';
    res.writeHead(200, { 'Content-Type': 'application/xml; charset=utf-8', 'Cache-Control': 'public, max-age=3600' }); res.end(body);
  });
  route('GET', /^\/robots\.txt$/, async (req, res) => { const o = SEO.origin(req); res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'public, max-age=3600' }); res.end(`User-agent: *\nAllow: /\nDisallow: /api/\nDisallow: /admin.html\nDisallow: /account.html\nDisallow: /order.html\nDisallow: /invoice.html\nDisallow: /cart.html\nDisallow: /checkout.html\nSitemap: ${o}/sitemap.xml\n`); });
  route('GET', /^\/manifest\.webmanifest$/, async (req, res) => { const t = catalog.site; res.writeHead(200, { 'Content-Type': 'application/manifest+json', 'Cache-Control': 'public, max-age=3600' }); res.end(JSON.stringify({ name: t.name, short_name: t.name.slice(0, 12), description: t.heroLead, start_url: '/', display: 'standalone', background_color: '#faf6ef', theme_color: '#5b1530', lang: 'en-IN', icons: [{ src: '/img/icons/icon-192.png', sizes: '192x192', type: 'image/png' }, { src: '/img/icons/icon-512.png', sizes: '512x512', type: 'image/png' }, { src: '/img/icons/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }] })); });
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
  route('GET', /^\/media\/p\/([a-z0-9-]+)\/([A-Za-z0-9_]{6,12})-(400|800|1200|feed)\.(webp|jpg|png)$/, async (req, res, m) => {
    const f = catalog.mediaPath(m[1], `${m[2]}-${m[3]}.${m[4]}`); if (!fs.existsSync(f)) throw fail(404, 'Not found');
    const t = sniffImage(fs.readFileSync(f).subarray(0, 16)); if (!t) throw fail(404, 'Not found');
    res.writeHead(200, { 'Content-Type': t.mime, 'Cache-Control': 'public, max-age=31536000, immutable', ...headersFor(false) }); fs.createReadStream(f).pipe(res);
  });

  /* admin */
  /* ---- public: contact form + newsletter (stored, never just a fake success message) ---- */
  const contactLimit = limiter(5, 10 * 60e3), newsLimit = limiter(8, 10 * 60e3);
  const validEmail0 = e => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e);
  route('POST', /^\/api\/contact$/, async (req, res) => {
    if (!contactLimit(ip(req))) throw fail(429, 'Too many messages. Please try again in a few minutes.');
    const b = await jsonBody(req); if (b.website) return send(res, 201, { ok: true });   // honeypot: bots fill the hidden field
    const name = String(b.name || '').trim().slice(0, 80), email = String(b.email || '').trim().toLowerCase().slice(0, 120), phone = String(b.phone || '').trim().slice(0, 20), message = String(b.message || '').trim().slice(0, 2000);
    if (name.length < 2) throw fail(400, 'Please enter your name.'); if (!validEmail0(email)) throw fail(400, 'Please enter a valid email so we can reply.'); if (message.length < 5) throw fail(400, 'Please write your message.');
    D.messages.unshift({ id: id(8), at: Date.now(), name, email, phone, message, read: false, replied: false }); D.messages.length = Math.min(D.messages.length, 2000); db.save();
    notifier.push('message', null, 'New message from ' + name, message.slice(0, 100)); send(res, 201, { ok: true });
  });
  route('POST', /^\/api\/newsletter$/, async (req, res) => {
    if (!newsLimit(ip(req))) throw fail(429, 'Too many attempts. Please try again later.');
    const b = await jsonBody(req), email = String(b.email || '').trim().toLowerCase().slice(0, 120); if (b.website) return send(res, 200, { ok: true });
    if (!validEmail0(email)) throw fail(400, 'Please enter a valid email address.');
    const had = D.subscribers.some(x => x.email === email); if (!had) { D.subscribers.push({ email, at: Date.now(), source: String(b.source || 'footer').slice(0, 20) }); db.save(); }
    send(res, 200, { ok: true, already: had });
  });

  /* ---- admin: content pages, inbox, subscribers ---- */
  route('GET', /^\/api\/admin\/pages$/, async (req, res) => { need(req, 'admin'); send(res, 200, { pages: catalog.pages }); });
  route('POST', /^\/api\/admin\/pages$/, async (req, res) => { need(req, 'admin'); send(res, 201, { page: catalog.savePage(null, await jsonBody(req)) }); });
  route('POST', /^\/api\/admin\/pages\/preview$/, async (req, res) => { need(req, 'admin'); send(res, 200, { html: Pages.render((await jsonBody(req)).body, catalog.pageVars()) }); });
  route('PUT', /^\/api\/admin\/pages\/([a-z0-9-]+)$/, async (req, res, m) => { need(req, 'admin'); send(res, 200, { page: catalog.savePage(m[1], await jsonBody(req)) }); });
  route('DELETE', /^\/api\/admin\/pages\/([a-z0-9-]+)$/, async (req, res, m) => { need(req, 'admin'); catalog.removePage(m[1]); send(res, 200, { ok: true }); });
  route('GET', /^\/api\/admin\/messages$/, async (req, res) => { need(req, 'admin'); send(res, 200, { messages: D.messages.slice(0, 300), unread: D.messages.filter(m => !m.read).length }); });
  route('PATCH', /^\/api\/admin\/messages\/([\w-]+)$/, async (req, res, m) => { need(req, 'admin'); const x = D.messages.find(y => y.id === m[1]); if (!x) throw fail(404, 'Not found'); const b = await jsonBody(req); if (b.read !== undefined) x.read = !!b.read; if (b.replied !== undefined) x.replied = !!b.replied; db.save(); send(res, 200, { message: x }); });
  route('DELETE', /^\/api\/admin\/messages\/([\w-]+)$/, async (req, res, m) => { need(req, 'admin'); D.messages = D.messages.filter(y => y.id !== m[1]); db.save(); send(res, 200, { ok: true }); });
  route('GET', /^\/api\/admin\/subscribers$/, async (req, res) => { need(req, 'admin'); send(res, 200, { subscribers: D.subscribers.slice().reverse().slice(0, 1000), total: D.subscribers.length }); });
  route('DELETE', /^\/api\/admin\/subscribers$/, async (req, res) => { need(req, 'admin'); const e = String((await jsonBody(req)).email || '').toLowerCase(); D.subscribers = D.subscribers.filter(x => x.email !== e); db.save(); send(res, 200, { ok: true }); });
  const csv = rows => rows.map(r => r.map(v => { v = String(v == null ? '' : v); if (/^[=+\-@\t\r]/.test(v)) v = "'" + v; return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }).join(',')).join('\r\n') + '\r\n';
  route('GET', /^\/api\/admin\/subscribers\.csv$/, async (req, res) => { need(req, 'admin'); res.writeHead(200, { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': 'attachment; filename="subscribers.csv"', 'Cache-Control': 'no-store' }); res.end('\ufeff' + csv([['email', 'subscribed_at', 'source']].concat(D.subscribers.map(x => [x.email, new Date(x.at).toISOString(), x.source])))); });

  /* ---- admin: catalogue, categories, store settings ---- */
  const adminProduct = p => ({ ...p, imageUrls: p.images.map(r => ({ rev: r, url: catalog.imgUrl(p, r, p.imageStore[r].ws.indexOf(400) > -1 ? 400 : p.imageStore[r].ws[0]) })), thumb: catalog.thumb(p), imageStore: undefined });
  route('GET', /^\/api\/admin\/catalog$/, async (req, res) => { need(req, 'admin'); send(res, 200, { products: catalog.products.map(adminProduct), categories: catalog.categories, site: catalog.site, stitch: A.STITCH.map(x => ({ id: x.id, label: x.label })), occasions: A.OCCASIONS, demoCount: catalog.products.filter(p => p.demo).length }); });
  route('POST', /^\/api\/admin\/products$/, async (req, res) => { need(req, 'admin'); const p = catalog.create(await jsonBody(req)); send(res, 201, { product: adminProduct(p) }); });
  route('PUT', /^\/api\/admin\/products\/([a-z0-9-]+)$/, async (req, res, m) => { need(req, 'admin'); send(res, 200, { product: adminProduct(catalog.update(m[1], await jsonBody(req))) }); });
  route('DELETE', /^\/api\/admin\/products\/([a-z0-9-]+)$/, async (req, res, m) => { need(req, 'admin'); catalog.remove(m[1]); send(res, 200, { ok: true }); });
  route('POST', /^\/api\/admin\/products\/([a-z0-9-]+)\/image$/, async (req, res, m) => {
    need(req, 'admin'); const p = catalog.find(m[1]); if (!p) throw fail(404, 'Product not found');
    const q = new URL(req.url, 'http://x').searchParams, data = await readBody(req, 1.6e6); const t = sniffImage(data); if (!t) throw fail(400, 'Please upload a JPG, PNG or WebP photo.');
    catalog.addImage(p, q.get('rev') || '', q.get('w') === 'feed' ? 'feed' : parseInt(q.get('w'), 10), t.ext, data); send(res, 200, { product: adminProduct(p) });
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
    send(res, 200, { unreadMessages: D.messages.filter(m => !m.read).length, subscribers: D.subscribers.length, products: catalog.products.length, demoProducts: catalog.products.filter(p => p.demo).length, counts: c, revenue: rev, orders: D.orders.length, customers: D.users.filter(u => u.role === 'customer' && !u.isGuest).length, guests: D.users.filter(u => u.isGuest).length, unread: D.notifications.filter(n => !n.read).length, qrIsDemo: !D.settings.qrFile, upiSet: !!D.settings.upiId });
  });
  /* analytics: sales, funnel and top products over the last N days (default 30) */
  route('GET', /^\/api\/admin\/analytics$/, async (req, res) => {
    need(req, 'admin'); const days = Math.min(365, Math.max(7, parseInt(new URL(req.url, 'http://x').searchParams.get('days'), 10) || 30));
    const DAY = 864e5, t0 = new Date(); t0.setHours(0, 0, 0, 0); const start = t0.getTime() - (days - 1) * DAY, key = t => { const d = new Date(t); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
    const PAID = ['paid', 'processing', 'shipped', 'delivered'], inR = D.orders.filter(o => o.createdAt >= start), series = [], byDay = {};
    for (let i = 0; i < days; i++) { const k = key(start + i * DAY); byDay[k] = { date: k, orders: 0, revenue: 0 }; series.push(byDay[k]); }
    const counts = {}, prod = {}, city = {}; Object.keys(Orders.STATUS).forEach(k => counts[k] = 0);
    let revenue = 0, paidN = 0;
    inR.forEach(o => {
      counts[o.status]++; const d = byDay[key(o.createdAt)]; if (d) d.orders++;
      if (PAID.indexOf(o.status) > -1) { paidN++; revenue += o.totals.total; if (d) d.revenue += o.totals.total; o.items.forEach(i => { const r = prod[i.id] || (prod[i.id] = { id: i.id, name: i.name, qty: 0, revenue: 0 }); r.qty += i.qty; r.revenue += (i.unit || 0) * i.qty; }); const c = (o.customer.city || '—') + ', ' + (o.customer.state || ''); city[c] = (city[c] || 0) + 1; }
    });
    const settled = inR.filter(o => PAID.indexOf(o.status) > -1 || ['cancelled', 'payment_rejected'].indexOf(o.status) > -1 || o.status === 'awaiting_payment' || o.status === 'payment_review').length;
    const prev = D.orders.filter(o => o.createdAt >= start - days * DAY && o.createdAt < start && PAID.indexOf(o.status) > -1).reduce((a, o) => a + o.totals.total, 0);
    const done = D.orders.filter(o => o.status === 'delivered' && o.timeline.length), fulfil = done.map(o => { const a = o.timeline.find(t => PAID.indexOf(t.status) > -1), b = o.timeline.slice().reverse().find(t => t.status === 'delivered'); return a && b ? b.at - a.at : 0; }).filter(Boolean);
    send(res, 200, { days, series, counts, orders: inR.length, paidOrders: paidN, revenue, prevRevenue: prev, aov: paidN ? Math.round(revenue / paidN) : 0, conversion: settled ? Math.round(paidN / settled * 100) : 0,
      avgDeliveryDays: fulfil.length ? Math.round(fulfil.reduce((a, b) => a + b, 0) / fulfil.length / DAY * 10) / 10 : null,
      top: Object.values(prod).sort((a, b) => b.qty - a.qty).slice(0, 6), cities: Object.entries(city).sort((a, b) => b[1] - a[1]).slice(0, 5).map(e => ({ city: e[0], orders: e[1] })),
      pipeline: D.orders.filter(o => ['payment_review', 'paid', 'processing', 'shipped'].indexOf(o.status) > -1).sort((a, b) => a.updatedAt - b.updatedAt).slice(0, 8).map(o => Orders.view(o, true)) });
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
      const url = req.url.split('?')[0], mutating = req.method !== 'GET' && req.method !== 'HEAD';
      if (mutating) {
        if (!url.startsWith('/api/')) throw fail(405, 'Method not allowed');
        if (!url.startsWith('/api/webhooks/')) {
          if (req.headers['x-requested-with'] !== 'asingh') throw fail(403, 'Blocked request');
          const o = req.headers.origin; if (o && new URL(o).host !== req.headers.host) throw fail(403, 'Blocked cross-origin request');
        }
      }
      for (const [method, re, fn] of routes) { const m = re.exec(url); if (m && method === req.method) return await fn(req, res, m); }
      if (url.startsWith('/api/') || url.startsWith('/media/')) throw fail(404, 'Not found');
      if (Static.serve(req, res, headersFor)) return;
      serve404(req, res);
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
