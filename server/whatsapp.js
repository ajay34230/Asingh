'use strict';
/* Automatic WhatsApp order messages through the WhatsApp Business Cloud API (Meta).
   Server environment: WHATSAPP_TOKEN (permanent access token), WHATSAPP_PHONE_ID (the sending number's ID),
   WHATSAPP_TEMPLATE (name of your approved template, default "order_update"), WHATSAPP_LANG (default "en").
   The template needs a body with exactly 3 variables:  Hello {{1}}, your order {{2}} {{3}}
   WHATSAPP_BASE exists so tests can use a local mock. Without these settings nothing is sent. */
const enabled = () => !!(process.env.WHATSAPP_TOKEN && process.env.WHATSAPP_PHONE_ID);
const base = () => (process.env.WHATSAPP_BASE || 'https://graph.facebook.com/v20.0').replace(/\/+$/, '');
const MSG = { created: 'has been received. Total ₹{total}. Please complete the payment to confirm it.', awaiting_payment: 'is waiting for payment.', payment_review: 'payment screenshot received — we are verifying it.', payment_rejected: 'payment could not be verified. Please upload a clear screenshot.', paid: 'payment is verified. Thank you!', processing: 'is being prepared for you.', shipped: 'has been shipped.{track}', delivered: 'has been delivered. We hope you love it!', cancelled: 'has been cancelled.', cod: 'is confirmed — please keep ₹{total} ready to pay on delivery.' };
function text(o, kind) {
  const key = kind === 'created' ? (o.method === 'cod' ? 'cod' : o.method === 'razorpay' ? 'created' : 'created') : o.status;
  const track = o.tracking && o.tracking.id ? ' Courier: ' + (o.tracking.courier || '') + ' ' + o.tracking.id + '.' : '';
  return (MSG[key] || MSG[o.status] || 'has an update.').replace('{total}', o.totals.total.toLocaleString('en-IN')).replace('{track}', track);
}
async function send(toPhone, name, orderNo, msg) {
  if (!enabled()) return false; let to = String(toPhone || '').replace(/\D/g, ''); if (to.length === 10) to = '91' + to; if (to.length < 11) return false;
  const ctrl = new AbortController(), t = setTimeout(() => ctrl.abort(), 10000);
  try {
    const r = await fetch(base() + '/' + process.env.WHATSAPP_PHONE_ID + '/messages', { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + process.env.WHATSAPP_TOKEN },
      body: JSON.stringify({ messaging_product: 'whatsapp', to, type: 'template', template: { name: process.env.WHATSAPP_TEMPLATE || 'order_update', language: { code: process.env.WHATSAPP_LANG || 'en' }, components: [{ type: 'body', parameters: [name, orderNo, msg].map(v => ({ type: 'text', text: String(v).slice(0, 300) })) }] } }), signal: ctrl.signal });
    if (!r.ok) console.warn('whatsapp failed:', r.status); return r.ok;
  } catch (e) { console.warn('whatsapp failed:', e.message); return false; } finally { clearTimeout(t); }
}
module.exports = { enabled, text, send };
