'use strict';
/* Payment layer. Today: manual UPI QR + screenshot review. Tomorrow: add a gateway by
   (1) listing it in METHODS, (2) adding an adapter to ADAPTERS, (3) setting WEBHOOK_SECRET_<NAME>.
   The gateway calls POST /api/webhooks/<name>; a verified "paid" event marks the order paid and alerts the admin. */
const crypto = require('crypto');

const razorpayOn = () => !!(process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET);
/* Which payment methods customers see: UPI/QR always; online (Razorpay) when its keys are set in the server's environment;
   cash on delivery when the owner turns it on in Admin → Payment & QR. Disabled methods are not shown at all. */
function allMethods(settings) {
  const cod = (settings && settings.cod) || {};
  return [
    { id: 'upi_qr', label: 'UPI / QR code', note: 'Scan the QR with any UPI app, then upload your payment screenshot', kind: 'manual', enabled: true },
    { id: 'razorpay', label: 'Cards, UPI apps, netbanking & wallets', note: 'Pay securely online — your order is confirmed instantly', kind: 'gateway', enabled: razorpayOn() },
    { id: 'cod', label: 'Cash on delivery', note: cod.fee ? 'Pay when your parcel arrives (+₹' + cod.fee + ' handling)' : 'Pay in cash or UPI when your parcel arrives', kind: 'cod', enabled: !!cod.enabled }
  ];
}

const hmac = (secret, raw) => crypto.createHmac('sha256', secret).update(raw).digest('hex');
const safeEq = (a, b) => { const x = Buffer.from(String(a || '')), y = Buffer.from(String(b || '')); return x.length === y.length && crypto.timingSafeEqual(x, y); };

/* An adapter turns a provider's raw webhook into { orderNumber, status: 'paid'|'failed', reference, amount? } */
const ADAPTERS = {
  // Generic: any system that can sign `HMAC-SHA256(secret, rawBody)` into the X-Signature header and send
  // { "orderNumber": "CV-...", "status": "paid" | "failed", "reference": "txn_123", "amount": 1234 }
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

function publicMethods(settings) { return allMethods(settings).filter(m => m.enabled).map(m => ({ id: m.id, label: m.label, note: m.note, kind: m.kind, enabled: true })); }
function method(idv, settings) { return allMethods(settings).find(m => m.id === idv && m.enabled); }

/* ---- Razorpay (Orders API + Checkout). Amounts are in paise. RAZORPAY_BASE exists so tests can point at a local mock. ---- */
const rzpBase = () => (process.env.RAZORPAY_BASE || 'https://api.razorpay.com').replace(/\/+$/, '');
async function rzpCreateOrder({ amountInr, receipt, notes }) {
  const auth = Buffer.from(process.env.RAZORPAY_KEY_ID + ':' + process.env.RAZORPAY_KEY_SECRET).toString('base64');
  const ctrl = new AbortController(), t = setTimeout(() => ctrl.abort(), 10000);
  try {
    const r = await fetch(rzpBase() + '/v1/orders', { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Basic ' + auth }, body: JSON.stringify({ amount: Math.round(amountInr * 100), currency: 'INR', receipt: String(receipt).slice(0, 40), notes: notes || {} }), signal: ctrl.signal });
    const j = await r.json().catch(() => ({})); if (!r.ok || !j.id) throw new Error((j.error && j.error.description) || 'Razorpay could not create the payment');
    return j;
  } finally { clearTimeout(t); }
}
/* Checkout returns razorpay_payment_id + razorpay_signature = HMAC_SHA256(secret, order_id + "|" + payment_id) */
const rzpVerify = (rzpOrderId, paymentId, signature) => razorpayOn() && safeEq(hmac(process.env.RAZORPAY_KEY_SECRET, rzpOrderId + '|' + paymentId), signature);
function adapter(name) { const secret = process.env['WEBHOOK_SECRET_' + String(name).toUpperCase()]; return ADAPTERS[name] && secret ? { ...ADAPTERS[name], secret } : null; }
module.exports = { publicMethods, method, adapter, hmac, razorpayOn, rzpCreateOrder, rzpVerify };
