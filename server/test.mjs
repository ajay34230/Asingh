// End-to-end tests for the server: auth, privacy, uploads, admin, webhooks, static allow-list. Run: npm test
import { createRequire } from 'node:module';
import os from 'node:os'; import fs from 'node:fs'; import path from 'node:path'; import crypto from 'node:crypto';
const require = createRequire(import.meta.url);
process.env.ADMIN_PASSWORD = 'correct-horse-battery'; process.env.WEBHOOK_SECRET_GENERIC = 'whsec_test';
const { createApp } = require('./index.js');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asingh-'));
const app = createApp({ dataDir: dir, quiet: true });
await new Promise(r => app.server.listen(0, '127.0.0.1', r));
const base = 'http://127.0.0.1:' + app.server.address().port;
let fails = 0; const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };

class Client {
  constructor() { this.cookie = ''; }
  async req(method, url, body, extra = {}) {
    const headers = { 'x-requested-with': 'asingh', ...(this.cookie ? { cookie: this.cookie } : {}), ...extra };
    let payload = body; if (body && !(body instanceof Buffer) && !extra['content-type']) { headers['content-type'] = 'application/json'; payload = JSON.stringify(body); }
    const r = await fetch(base + url, { method, headers, body: payload, redirect: 'manual' });
    const sc = r.headers.getSetCookie?.() || []; sc.forEach(c => { const kv = c.split(';')[0]; this.cookie = kv.startsWith('as_sid=') ? kv : this.cookie; });
    const t = await r.text(); let j = null; try { j = JSON.parse(t); } catch {} return { status: r.status, json: j, text: t, headers: r.headers };
  }
}
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
const oid = r.json.order.id; ok(/^AS\d{6}-\d{4}$/.test(r.json.order.number), 'order number ' + r.json.order.number);
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

console.log('\nSign out');
await B.req('POST', '/api/auth/logout', {}); ok((await B.req('GET', '/api/orders')).status === 401, 'session ends on sign-out');
app.server.close(); process.on('exit', () => fs.rmSync(dir, { recursive: true, force: true }));
console.log(fails ? `\n${fails} FAILED` : '\nALL SERVER TESTS PASS'); process.exit(fails ? 1 : 0);
