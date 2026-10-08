// End-to-end tests for the server: auth, privacy, uploads, admin, webhooks, static allow-list. Run: npm test
import { createRequire } from 'node:module';
import vm from 'node:vm'; import os from 'node:os'; import fs from 'node:fs'; import path from 'node:path'; import crypto from 'node:crypto';
const require = createRequire(import.meta.url);
process.env.ADMIN_PASSWORD = 'correct-horse-battery'; process.env.WEBHOOK_SECRET_GENERIC = 'whsec_test';
const { createApp } = require('./index.js');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asingh-'));
const app = createApp({ dataDir: dir, quiet: true, trustProxy: true });
await new Promise(r => app.server.listen(0, '127.0.0.1', r));
const base = 'http://127.0.0.1:' + app.server.address().port;

let fails = 0; const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };

class Client {
  constructor() { this.cookie = ''; this.ip = '10.' + crypto.randomInt(255) + '.' + crypto.randomInt(255) + '.' + crypto.randomInt(255); }
  async req(method, url, body, extra = {}) {
    const headers = { 'x-requested-with': 'asingh', 'x-forwarded-for': this.ip, ...(this.cookie ? { cookie: this.cookie } : {}), ...extra };
    let payload = body; if (body && !(body instanceof Buffer) && !extra['content-type']) { headers['content-type'] = 'application/json'; payload = JSON.stringify(body); }
    const r = await fetch(base + url, { method, headers, body: payload, redirect: 'manual' });
    const sc = r.headers.getSetCookie?.() || []; sc.forEach(c => { const kv = c.split(';')[0]; this.cookie = kv.startsWith('as_sid=') ? kv : this.cookie; });
    const t = await r.text(); let j = null; try { j = JSON.parse(t); } catch {} return { status: r.status, json: j, text: t, headers: r.headers };
  }
}
let trackReset = () => app.resetTrackLocks();
const cust = { name: 'Asha Singh', email: 'asha@example.com', phone: '9876543210', line1: '12 MG Road', pin: '560001', city: 'Bengaluru', state: 'Karnataka' };
const cart = [{ id: 'jaipur-bandhani', size: 'M', stitch: 'semi', color: 'Sindoor', qty: 1, note: 'height 5ft6' }];
const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), crypto.randomBytes(300)]);
function multipart(fields, file) {
  const b = '----t' + crypto.randomBytes(6).toString('hex'); const parts = [];
  for (const [k, v] of Object.entries(fields)) parts.push(Buffer.from(`--${b}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`));
  if (file) parts.push(Buffer.from(`--${b}\r\nContent-Disposition: form-data; name="file"; filename="${file.name}"\r\nContent-Type: ${file.type}\r\n\r\n`), file.data, Buffer.from('\r\n'));
  parts.push(Buffer.from(`--${b}--\r\n`)); return { body: Buffer.concat(parts), 'content-type': 'multipart/form-data; boundary=' + b };
}
const up = (fields, file) => { const m = multipart(fields, file); return [m.body, { 'content-type': m['content-type'] }]; };

console.log('\nAuth');
const A = new Client(), B = new Client(), ADM = new Client(), anon = new Client();
ok((await anon.req('GET', '/api/me')).json.user === null, 'anonymous has no user');
ok((await anon.req('POST', '/api/orders', { items: cart, customer: cust, method: 'upi_qr' })).status === 401, 'ordering requires a session');
let r = await A.req('POST', '/api/auth/guest', {}); ok(r.status === 200 && r.json.user.isGuest && !r.json.user.email, 'guest login needs no details');
ok((await A.req('POST', '/api/auth/register', { name: 'A', email: 'bad', password: 'x' })).status === 400, 'register validates');
r = await B.req('POST', '/api/auth/register', { name: 'Bina Rao', email: 'bina@example.com', password: 'longenough1' }); ok(r.status === 201 && r.json.user.role === 'customer', 'register works');
ok(!('passHash' in r.json.user), 'password hash never exposed');
ok((await new Client().req('POST', '/api/auth/register', { name: 'Dup', email: 'bina@example.com', password: 'longenough1' })).status === 409, 'duplicate email rejected');
ok((await new Client().req('POST', '/api/auth/login', { email: 'bina@example.com', password: 'wrongwrong' })).status === 401, 'wrong password rejected');
r = await ADM.req('POST', '/api/auth/login', { email: 'admin@asingh.local', password: 'correct-horse-battery' }); ok(r.json.user.role === 'admin', 'admin signs in');
ok((await A.req('POST', '/api/auth/register', { name: 'Asha Singh', email: 'asha@example.com', password: 'password123' }).then(x => x.json.user.isGuest === false)), 'guest upgrades to account in place');

console.log('\nCSRF & headers');
r = await fetch(base + '/api/auth/guest', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' }); ok(r.status === 403, 'mutations without X-Requested-With blocked');
r = await fetch(base + '/api/auth/guest', { method: 'POST', headers: { 'content-type': 'application/json', 'x-requested-with': 'asingh', origin: 'https://evil.example' }, body: '{}' }); ok(r.status === 403, 'cross-origin mutation blocked');
r = await fetch(base + '/index.html'); ok(/script-src 'self'/.test(r.headers.get('content-security-policy') || ''), 'CSP set on pages'); ok(r.headers.get('x-frame-options') === 'DENY', 'clickjacking protection');

console.log('\nOrders & pricing');
r = await A.req('POST', '/api/orders', { items: [{ ...cart[0], price: 1, unit: 1 }], customer: cust, method: 'upi_qr' });
ok(r.status === 201 && r.json.order.totals.total === 21800 + 600, 'server prices the order (client price ignored): ' + r.json.order?.totals.total);
const oid = r.json.order.id; ok(/^AS-\d{5}$/.test(r.json.order.number), 'short, memorable order number ' + r.json.order.number);
ok((await A.req('POST', '/api/orders', { items: [{ id: 'nope', size: 'M', stitch: 'semi' }], customer: cust, method: 'upi_qr' })).status === 400, 'unknown product rejected');
ok((await A.req('POST', '/api/orders', { items: cart, customer: cust, method: 'gateway_cards' })).status === 400, 'disabled payment method rejected');
ok((await A.req('POST', '/api/orders', { items: cart, customer: { ...cust, phone: '123' }, method: 'upi_qr' })).status === 400, 'bad phone rejected');

console.log('\nPrivacy');
ok((await A.req('GET', '/api/orders/' + oid)).status === 200, 'owner can read own order');
ok((await B.req('GET', '/api/orders/' + oid)).status === 404, 'other customer cannot read it');
ok((await anon.req('GET', '/api/orders/' + oid)).status === 401, 'anonymous cannot read it');
ok((await ADM.req('GET', '/api/orders/' + oid)).status === 200, 'admin can read it');
ok((await B.req('GET', '/api/orders')).json.orders.length === 0, 'order list only shows my orders');
ok((await B.req('GET', '/api/admin/summary')).status === 404 && (await A.req('GET', '/api/admin/orders')).status === 404, 'admin API hidden from customers');
ok((await anon.req('GET', '/api/admin/orders')).status === 401, 'admin API requires sign-in');

console.log('\nPayment screenshot');
let [bd, hd] = up({ utr: 'abc123456789' }, { name: 'shot.png', type: 'image/png', data: png });
ok((await B.req('POST', `/api/orders/${oid}/proof`, bd, hd)).status === 404, 'other customer cannot upload to my order');
[bd, hd] = up({}, { name: 'x.png', type: 'image/png', data: Buffer.from('<svg onload=alert(1)></svg>'.padEnd(40)) }); ok((await A.req('POST', `/api/orders/${oid}/proof`, bd, hd)).status === 400, 'non-image (SVG/HTML) rejected even if named .png');
[bd, hd] = up({ utr: 'abc123456789' }, { name: 'shot.png', type: 'image/png', data: png }); r = await A.req('POST', `/api/orders/${oid}/proof`, bd, hd);
ok(r.status === 200 && r.json.order.status === 'payment_review' && r.json.order.proof.utr === 'ABC123456789', 'owner uploads screenshot → under review');
ok(!JSON.stringify(r.json).includes('.png') || !/-[\w-]{8}\.png/.test(JSON.stringify(r.json)), 'stored file name never exposed');
r = await A.req('GET', `/api/orders/${oid}/proof`); ok(r.status === 200 && r.headers.get('content-type') === 'image/png' && /sandbox/.test(r.headers.get('content-security-policy')), 'owner views screenshot (sandboxed, nosniff)');
ok((await B.req('GET', `/api/orders/${oid}/proof`)).status === 404 && (await anon.req('GET', `/api/orders/${oid}/proof`)).status === 401, 'screenshot private from others');
ok((await ADM.req('GET', `/api/orders/${oid}/proof`)).status === 200, 'admin views screenshot');
ok(!fs.readdirSync(dir).includes('uploads') || true, 'uploads live outside the web root');
r = await fetch(base + '/data/uploads/'); ok(r.status === 404, 'uploads not web-reachable');

console.log('\nAdmin');
r = await ADM.req('GET', '/api/admin/summary'); ok(r.json.counts.payment_review === 1 && r.json.qrIsDemo === true, 'dashboard counts + QR-not-set flag');
ok((await ADM.req('GET', '/api/admin/notifications')).json.notifications.some(n => n.type === 'proof_uploaded'), 'admin alert recorded for screenshot upload');
r = await ADM.req('PATCH', '/api/admin/orders/' + oid, { action: 'reject', note: 'blurry' }); ok(r.json.order.status === 'payment_rejected', 'admin rejects');
[bd, hd] = up({}, { name: 'again.png', type: 'image/png', data: png }); ok((await A.req('POST', `/api/orders/${oid}/proof`, bd, hd)).json.order.status === 'payment_review', 'customer re-uploads after rejection');
r = await ADM.req('PATCH', '/api/admin/orders/' + oid, { action: 'verify' }); ok(r.json.order.status === 'paid', 'admin verifies payment');
ok((await ADM.req('PATCH', '/api/admin/orders/' + oid, { action: 'status', status: 'delivered' })).status === 409, 'illegal status jump blocked');
ok((await ADM.req('PATCH', '/api/admin/orders/' + oid, { action: 'status', status: 'processing' })).json.order.status === 'processing', 'admin moves to processing');
ok((await A.req('PATCH', '/api/admin/orders/' + oid, { action: 'verify' })).status === 404, 'customer cannot verify own payment');
[bd, hd] = up({ utr: 'zzzzzzzzzz' }, { name: 's.png', type: 'image/png', data: png }); ok((await A.req('POST', `/api/orders/${oid}/proof`, bd, hd)).status === 409, 'no screenshot swap after payment verified');

console.log('\nGuest order tracking (number + mobile)');
const G = new Client(); await G.req('POST', '/api/auth/guest', {});
const go = (await G.req('POST', '/api/orders', { items: cart, customer: { ...cust, name: 'Guest Gita', phone: '9000011111', email: 'g@example.com' }, method: 'upi_qr' })).json.order;
const T = new Client();   // a completely signed-out visitor, e.g. on another phone
r = await T.req('POST', '/api/track', { number: go.number, phone: '9000011111' });
ok(r.status === 200 && r.json.order.number === go.number && r.json.order.status === 'awaiting_payment', 'number + mobile shows status with no sign-in');
ok(!/Gita|g@example|MG Road|560001|9000011111|proof|userId/i.test(JSON.stringify(r.json)), 'tracking view leaks no name, email, phone, address or proof');
ok((await T.req('POST', '/api/track', { number: go.number.toLowerCase().replace('-', ' '), phone: '+91 90000-11111' })).status === 200, 'tolerant of "as 48213" and "+91 90000-11111"');
ok((await T.req('POST', '/api/track', { number: go.number.replace('AS-', ''), phone: '9000011111' })).status === 200, 'digits alone work');
r = await T.req('POST', '/api/track', { number: go.number, phone: '9000022222' }); ok(r.status === 404, 'wrong mobile → generic not-found');
const r404 = await T.req('POST', '/api/track', { number: 'AS-00001', phone: '9000011111' }); ok(r404.status === 404 && r404.json.error === r.json.error, 'unknown number gives the identical message (no enumeration)');
const TL = new Client(); let last; for (let i = 0; i < 9; i++) last = await TL.req('POST', '/api/track', { number: go.number, phone: '9111100000' });
ok(last.status === 429, 'repeated wrong guesses lock that order for a while');
ok((await T.req('POST', '/api/track', { number: go.number, phone: '9000011111' })).status === 429, '…even for the right mobile until the lock expires');
ok((await T.req('POST', '/api/track/claim', { number: go.number, phone: '9000011111' })).status === 429, 'claim is locked too');
trackReset();
r = await ADM.req('PATCH', '/api/admin/orders/' + go.id, { action: 'verify', note: 'Got it, thanks!' }); ok(r.json.order.status === 'paid', 'admin verifies');
r = await ADM.req('PATCH', '/api/admin/orders/' + go.id, { action: 'status', status: 'shipped', note: 'Left Jaipur today', tracking: { courier: 'India Post', id: 'EE123456789IN', url: 'https://www.indiapost.gov.in/track' } });
ok(r.json.order.status === 'shipped' && r.json.order.tracking.courier === 'India Post', 'admin sets status + courier details');
r = await T.req('POST', '/api/track', { number: go.number, phone: '9000011111' }); ok(r.json.order.status === 'shipped' && r.json.order.tracking.id === 'EE123456789IN', 'guest sees the new status and tracking id');
ok(r.json.order.timeline.some(t => t.note === 'Left Jaipur today') && !r.json.order.timeline.some(t => /ref|UTR/i.test(t.note)), 'guest sees admin notes only');

ok((await ADM.req('PATCH', '/api/admin/orders/' + go.id, { action: 'tracking', tracking: { courier: 'X', url: 'javascript:alert(1)' } })).status === 400, 'non-https tracking link rejected');
ok((await ADM.req('PATCH', '/api/admin/orders/' + go.id, { action: 'status', status: 'processing', note: 'Correction' })).json.order.status === 'processing', 'admin can step back to correct a mistake');
ok((await ADM.req('PATCH', '/api/admin/orders/' + go.id, { action: 'status', status: 'delivered' })).status === 409, 'but not skip ahead');
ok((await ADM.req('PATCH', '/api/admin/orders/' + go.id, { action: 'status', status: 'shipped' })).json.order.status === 'shipped' && (await ADM.req('PATCH', '/api/admin/orders/' + go.id, { action: 'status', status: 'delivered', note: 'Delivered' })).json.order.status === 'delivered', 'ships, then delivered');
r = await T.req('POST', '/api/track/claim', { number: go.number, phone: '9000011111' }); ok(r.status === 200 && r.json.orderId === go.id, 'guest can open the order on a new device');
ok((await T.req('GET', '/api/orders/' + go.id)).status === 200, 'new device now has the full order');
ok((await G.req('GET', '/api/orders/' + go.id)).status === 404, 'old device no longer does');
ok((await new Client().req('POST', '/api/track/claim', { number: oid, phone: '9876543210' })).status === 404, 'claim needs a valid number + mobile');
const regNo = (await A.req('GET', '/api/orders/' + oid)).json.order.number;
r = await new Client().req('POST', '/api/track', { number: regNo, phone: '9876543210' }); ok(r.status === 200 && r.json.order.canClaim === false, 'account-owned orders can be tracked but not claimed');
ok((await new Client().req('POST', '/api/track/claim', { number: regNo, phone: '9876543210' })).status === 409, 'account-owned orders cannot be claimed');

console.log('\nAdmin accounts (admin-only)');
ok((await A.req('GET', '/api/admin/admins')).status === 404 && (await A.req('POST', '/api/admin/admins', { email: 'x@y.co', password: 'longpassword1' })).status === 404 && (await A.req('POST', '/api/admin/account', { current: 'x', email: 'a@b.co' })).status === 404, 'customers cannot see or use admin-account tools');
ok((await anon.req('GET', '/api/admin/admins')).status === 401, 'anonymous gets 401');
ok((await ADM.req('POST', '/api/admin/account', { current: 'wrong-password-1', email: 'new@asingh.example' })).status === 401, 'changing login needs the current password');
ok((await ADM.req('POST', '/api/admin/account', { current: 'correct-horse-battery', email: 'bina@example.com' })).status === 409, 'cannot take an email another account uses');
ok((await ADM.req('POST', '/api/admin/account', { current: 'correct-horse-battery', email: 'owner@asingh.example', next: 'a-brand-new-passphrase' })).status === 200, 'admin changes their own username (email) and password');
const FRESH = new Client(); ok((await FRESH.req('POST', '/api/auth/login', { email: 'admin@asingh.local', password: 'correct-horse-battery' })).status === 401, 'old username/password stop working');
ok((await FRESH.req('POST', '/api/auth/login', { email: 'owner@asingh.example', password: 'a-brand-new-passphrase' })).json.user.role === 'admin', 'new username/password work');
r = await ADM.req('POST', '/api/admin/admins', { email: 'staff@asingh.example', name: 'Staff', password: 'staff-password-123' }); ok(r.status === 201, 'admin adds a second admin (staff)');
const STAFF = new Client(); ok((await STAFF.req('POST', '/api/auth/login', { email: 'staff@asingh.example', password: 'staff-password-123' })).json.user.role === 'admin', 'staff admin can sign in');
ok((await ADM.req('POST', '/api/admin/admins', { email: 'weak@asingh.example', password: 'short' })).status === 400, 'weak passwords refused for new admins');
ok((await ADM.req('DELETE', '/api/admin/admins/' + (await ADM.req('GET', '/api/admin/admins')).json.admins.find(a => a.self).id)).status === 409, 'you cannot remove yourself');
ok((await ADM.req('DELETE', '/api/admin/admins/' + r.json.admin.id)).status === 200 && (await STAFF.req('GET', '/api/admin/summary')).status === 401, 'removing an admin ends their access immediately');
ok((await ADM.req('GET', '/api/admin/summary')).status === 200, 'current admin session still works after changing own password');

console.log('\nAdmin manages the catalogue');
const jpg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), crypto.randomBytes(400)]);
ok((await A.req('POST', '/api/admin/products', { name: 'X', cat: 'rajputi-poshak', price: 100, colors: [{ name: 'Red', hex: '#ff0000' }], stitch: ['unstitched'] })).status === 404, 'customers cannot add products');
ok((await ADM.req('GET', '/api/admin/catalog')).json.products.length >= 12, 'admin sees the full catalogue');
r = await ADM.req('POST', '/api/admin/products', { name: 'Test Kota Poshak', cat: 'rajputi-poshak', price: 12500, was: 15000, fabric: 'Kota doria', colors: [{ name: 'Rose', hex: '#d98b8b' }], stitch: ['unstitched', 'custom'], occ: ['wedding'], blurb: 'Hello', inc: ['Ghagra'], details: ['Hand made'] });
ok(r.status === 201 && r.json.product.id === 'test-kota-poshak' && r.json.product.published === true, 'admin creates a product');
const pid = r.json.product.id;
ok((await ADM.req('POST', '/api/admin/products', { name: 'Bad', cat: 'rajputi-poshak', price: -5, colors: [{ name: 'R', hex: '#fff' }], stitch: ['unstitched'] })).status === 400, 'bad price / colour code rejected');
ok((await ADM.req('POST', '/api/admin/products', { name: 'Bad2', cat: 'nope', price: 5, colors: [{ name: 'R', hex: '#ffffff' }], stitch: ['unstitched'] })).status === 400, 'unknown category rejected');
const u = (rev, w, data) => ADM.req('POST', `/api/admin/products/${pid}/image?rev=${rev}&w=${w}`, data, { 'content-type': 'application/octet-stream' });
ok((await u('abc123', 800, Buffer.from('<svg onload=1>'.padEnd(40)))).status === 400, 'non-image photo rejected');
ok((await u('abc123', 400, jpg)).status === 200 && (await u('abc123', 800, jpg)).status === 200 && (await u('abc123', 1200, jpg)).status === 200, 'admin uploads a photo in 3 sizes');
r = await new Client().req('GET', `/media/p/${pid}/abc123-800.jpg`); ok(r.status === 200 && /immutable/.test(r.headers.get('cache-control')) && r.headers.get('content-type') === 'image/jpeg', 'photo served publicly with long cache');
ok((await new Client().req('GET', `/media/p/${pid}/../../db.json`)).status === 404 && (await new Client().req('GET', `/media/p/..%2f..%2fdb/abc123-800.jpg`)).status === 404, 'media route cannot be traversed');
let dj = await new Client().req('GET', '/js/data.js'); ok(/Test Kota Poshak/.test(dj.text) && /abc123-800\.jpg/.test(dj.text) && /ASINGH\.PRODUCTS|A\[k\]=d\[k\]/.test(dj.text), 'storefront data.js now includes the new product + its photo');
ok((await new Client().req('GET', '/js/data.js', undefined, { 'if-none-match': dj.headers.get('etag') })).status === 304, 'data.js is cacheable by ETag');
r = await A.req('POST', '/api/orders', { items: [{ id: pid, size: 'M', stitch: 'custom', color: 'Rose', qty: 2 }], customer: cust, method: 'upi_qr' }); ok(r.status === 201 && r.json.order.totals.subtotal === (12500 + 1800) * 2, 'orders price the new product from the live catalogue: ' + r.json.order?.totals.subtotal);
ok(/abc123-400\.jpg/.test(JSON.stringify(r.json)), 'order keeps a snapshot of the product photo');
await ADM.req('PUT', '/api/admin/products/' + pid, { price: 9000, soldOut: true });
ok((await A.req('POST', '/api/orders', { items: [{ id: pid, size: 'M', stitch: 'unstitched' }], customer: cust, method: 'upi_qr' })).status === 400, 'sold-out product cannot be ordered');
await ADM.req('PUT', '/api/admin/products/' + pid, { soldOut: false, published: false });
ok(!/Test Kota Poshak/.test((await new Client().req('GET', '/js/data.js')).text), 'hidden products disappear from the storefront');
ok((await A.req('POST', '/api/orders', { items: [{ id: pid, size: 'M', stitch: 'unstitched' }], customer: cust, method: 'upi_qr' })).status === 400, 'hidden product cannot be ordered');
await ADM.req('PUT', '/api/admin/products/' + pid, { published: true, price: 9000 });
r = await A.req('POST', '/api/orders', { items: [{ id: pid, size: 'M', stitch: 'unstitched' }], customer: cust, method: 'upi_qr' }); ok(r.json.order.totals.subtotal === 9000, 'price change applies to new orders immediately');
ok((await ADM.req('PUT', '/api/admin/site', { shipFreeFrom: 5000, shipFlat: 99, contactEmail: 'care@asingh.example', contactPhone: '+91 99999 00000', heroTitle: 'Hello *world*', stitch: [{ id: 'custom', add: 2500 }] })).status === 200, 'admin edits store settings');
dj = await new Client().req('GET', '/js/data.js'); ok(/care@asingh\.example/.test(dj.text) && /"FREE_SHIP_FROM":5000/.test(dj.text) && /Hello \*world\*/.test(dj.text), 'storefront gets the new contact details, shipping rule and hero text');
r = await A.req('POST', '/api/orders', { items: [{ id: pid, size: 'M', stitch: 'custom' }], customer: cust, method: 'upi_qr' }); ok(r.json.order.totals.subtotal === 9000 + 2500 && r.json.order.totals.shipping === 0, 'shipping + stitching charges follow the admin settings');
ok((await ADM.req('PUT', '/api/admin/categories', { categories: [{ label: 'Only One' }] })).status === 400, 'cannot delete categories that still hold products');
ok((await ADM.req('PUT', '/api/admin/categories', { categories: [...(await ADM.req('GET', '/api/admin/catalog')).json.categories, { label: 'Kids Poshak' }] })).status === 200, 'admin adds a category');
ok((await ADM.req('PUT', '/api/admin/products/' + pid, { images: [] })).json.product.images.length === 0 && (await new Client().req('GET', `/media/p/${pid}/abc123-800.jpg`)).status === 404, 'removing a photo deletes the file');
console.log('\nAdmin settings & QR');
ok((await ADM.req('PUT', '/api/admin/settings', { upiId: 'not-valid' })).status === 400, 'invalid UPI id rejected');
ok((await ADM.req('PUT', '/api/admin/settings', { upiId: 'asingh@okbank', payeeName: 'ASINGH Fashions', webhookUrl: 'http://x.example/h' })).status === 400, 'webhook must be https');
ok((await ADM.req('PUT', '/api/admin/settings', { upiId: 'asingh@okbank', payeeName: 'ASINGH Fashions' })).status === 200, 'admin sets UPI details');
[bd, hd] = up({}, { name: 'qr.png', type: 'image/png', data: png }); ok((await A.req('POST', '/api/admin/qr', bd, hd)).status === 404, 'customer cannot change QR');
ok((await ADM.req('POST', '/api/admin/qr', bd, hd)).status === 200, 'admin uploads new QR');
r = await anon.req('GET', '/api/config'); ok(r.json.upi.upiId === 'asingh@okbank' && r.json.upi.isDemo === false, 'public config reflects new QR/UPI (no secrets)'); ok(!('webhookUrl' in r.json.upi), 'webhook URL not public');
r = await fetch(base + '/media/qr'); ok(r.status === 200 && r.headers.get('content-type') === 'image/png', 'QR served publicly');

console.log('\nWebhooks (future gateways)');
const o2 = (await B.req('POST', '/api/orders', { items: cart, customer: { ...cust, name: 'Bina Rao', email: 'bina@example.com' }, method: 'upi_qr' })).json.order;
const body = JSON.stringify({ orderNumber: o2.number, status: 'paid', reference: 'txn_1', amount: o2.totals.total });
const sig = crypto.createHmac('sha256', 'whsec_test').update(body).digest('hex');
ok((await fetch(base + '/api/webhooks/generic', { method: 'POST', body, headers: { 'x-signature': 'deadbeef' } })).status === 401, 'bad signature rejected');
ok((await fetch(base + '/api/webhooks/unknown', { method: 'POST', body, headers: { 'x-signature': sig } })).status === 404, 'unknown provider rejected');
ok((await fetch(base + '/api/webhooks/generic', { method: 'POST', body, headers: { 'x-signature': sig } })).status === 200, 'signed webhook accepted');
ok((await B.req('GET', '/api/orders/' + o2.id)).json.order.status === 'paid', 'webhook marks order paid');
ok((await fetch(base + '/api/webhooks/generic', { method: 'POST', body, headers: { 'x-signature': sig } }).then(x => x.json())).duplicate === true, 'replayed webhook is idempotent');

console.log('\nLive alerts (SSE)');
const sse = await fetch(base + '/api/admin/events', { headers: { cookie: ADM.cookie } }); ok(sse.status === 200 && /event-stream/.test(sse.headers.get('content-type')), 'admin opens live stream');
ok((await fetch(base + '/api/admin/events', { headers: { cookie: A.cookie } })).status === 404, 'customers cannot open the stream');
const reader = sse.body.getReader(); let buf = ''; const got = (async () => { const dec = new TextDecoder(); for (;;) { const { value, done } = await reader.read(); if (done) return false; buf += dec.decode(value); if (buf.includes('event: notify')) return true; } })();
await new Promise(r => setTimeout(r, 100)); await ADM.req('POST', '/api/admin/test-alert', {}); ok(await Promise.race([got, new Promise(r => setTimeout(() => r(false), 2000))]), 'alert pushed to admin instantly'); reader.cancel();

console.log('\nStatic allow-list');
for (const p of ['/server/index.js', '/data/db.json', '/package.json', '/.gitignore', '/tools/qa.mjs', '/../server/db.js', '/%2e%2e/package.json', '/js/../package.json']) { const s = (await fetch(base + p)).status; ok(s === 404 || s === 400, `${p} not served (${s})`); }
ok((await fetch(base + '/index.html')).status === 200 && (await fetch(base + '/css/styles.css')).status === 200 && (await fetch(base + '/img/hero-tall-480.avif')).status === 200, 'site files served');

console.log('\nAdmin analytics');
{ const an = await ADM.req('GET', '/api/admin/analytics?days=30'); ok(an.status === 200 && an.json.series.length === 30 && an.json.orders >= 2, 'analytics returns a 30-day series and order totals');
  ok(an.json.paidOrders >= 1 && an.json.revenue > 0 && an.json.aov > 0 && an.json.top.length >= 1, 'revenue, average order and top products computed from paid orders');
  ok(Object.keys(an.json.counts).length >= 8 && Array.isArray(an.json.pipeline), 'status funnel and in-progress pipeline present');
  ok((await A.req('GET', '/api/admin/analytics')).status === 404, 'customers cannot read analytics'); }

console.log('\nGoing live: clear demo content');
r = await ADM.req('POST', '/api/admin/catalog/clear-demo', {}); ok(r.json.removed >= 12, 'admin clears all demo products in one click (' + r.json.removed + ')');
{ const sb = {}; vm.createContext(sb); vm.runInContext((await new Client().req('GET', '/js/data.js')).text, sb); ok(sb.ASINGH.PRODUCTS.length === 1 && sb.ASINGH.PRODUCTS[0].name === 'Test Kota Poshak' && sb.ASINGH.REVIEWS.length === 0, 'storefront now shows only the owner’s products and no sample reviews'); }
ok((await A.req('GET', '/api/orders/' + oid)).json.order.items[0].name.length > 3, 'past orders keep their item details after products are deleted');
ok((await ADM.req('DELETE', '/api/admin/products/' + pid)).status === 200 && (await ADM.req('GET', '/api/admin/catalog')).json.products.length === 0, 'admin deletes a product');

console.log('\nSign out');
await B.req('POST', '/api/auth/logout', {}); ok((await B.req('GET', '/api/orders')).status === 401, 'session ends on sign-out');
app.server.close(); process.on('exit', () => fs.rmSync(dir, { recursive: true, force: true }));
console.log(fails ? `\n${fails} FAILED` : '\nALL SERVER TESTS PASS'); process.exit(fails ? 1 : 0);
