'use strict';
/* Payment layer. Today: manual UPI QR + screenshot review. Tomorrow: add a gateway by
   (1) listing it in METHODS, (2) adding an adapter to ADAPTERS, (3) setting WEBHOOK_SECRET_<NAME>.
   The gateway calls POST /api/webhooks/<name>; a verified "paid" event marks the order paid and alerts the admin. */
const crypto = require('crypto');

const METHODS = [
  { id: 'upi_qr', label: 'UPI / QR code', note: 'Scan the QR with any UPI app, then upload your payment screenshot', kind: 'manual', enabled: true },
  { id: 'gateway_cards', label: 'Cards, netbanking & wallets', note: 'Instant confirmation — coming soon', kind: 'gateway', enabled: false },
  { id: 'cod', label: 'Cash on delivery', note: 'Coming soon', kind: 'manual', enabled: false }
];

const hmac = (secret, raw) => crypto.createHmac('sha256', secret).update(raw).digest('hex');
const safeEq = (a, b) => { const x = Buffer.from(String(a || '')), y = Buffer.from(String(b || '')); return x.length === y.length && crypto.timingSafeEqual(x, y); };

/* An adapter turns a provider's raw webhook into { orderNumber, status: 'paid'|'failed', reference, amount? } */
const ADAPTERS = {
  // Generic: any system that can sign `HMAC-SHA256(secret, rawBody)` into the X-Signature header and send
  // { "orderNumber": "AS-...", "status": "paid" | "failed", "reference": "txn_123", "amount": 1234 }
  generic: {
    verify: (raw, headers, secret) => safeEq(hmac(secret, raw), headers['x-signature']),
    parse: j => ({ orderNumber: j.orderNumber, status: j.status === 'paid' ? 'paid' : 'failed', reference: j.reference, amount: j.amount })
  },
  // Razorpay-style skeleton (HMAC-SHA256 of the raw body in X-Razorpay-Signature). Check against the provider's current docs before enabling.
  razorpay: {
    verify: (raw, headers, secret) => safeEq(hmac(secret, raw), headers['x-razorpay-signature']),
    parse: j => { const p = j && j.payload && j.payload.payment && j.payload.payment.entity; return p ? { orderNumber: p.notes && p.notes.order_number, status: j.event === 'payment.captured' ? 'paid' : 'failed', reference: p.id, amount: p.amount / 100 } : null; }
  }
};

function publicMethods() { return METHODS.map(m => ({ id: m.id, label: m.label, note: m.note, kind: m.kind, enabled: m.enabled })); }
function method(idv) { return METHODS.find(m => m.id === idv && m.enabled); }
function adapter(name) { const secret = process.env['WEBHOOK_SECRET_' + String(name).toUpperCase()]; return ADAPTERS[name] && secret ? { ...ADAPTERS[name], secret } : null; }
module.exports = { publicMethods, method, adapter, hmac };
