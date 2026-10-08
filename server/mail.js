'use strict';
/* Transactional email through an HTTP API (no SMTP, no dependencies). Set RESEND_API_KEY and MAIL_FROM
   (e.g. "ASINGH <orders@yourdomain.com>"). Without them the store works normally and simply sends no email. */
const esc = s => String(s == null ? '' : s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const enabled = () => !!(process.env.RESEND_API_KEY && process.env.MAIL_FROM);
async function send(to, subject, html) {
  if (!enabled() || !to) return false;
  const ctrl = new AbortController(), t = setTimeout(() => ctrl.abort(), 8000);
  try {
    const r = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + process.env.RESEND_API_KEY }, body: JSON.stringify({ from: process.env.MAIL_FROM, to: [to], subject, html }), signal: ctrl.signal });
    if (!r.ok) console.warn('mail failed:', r.status); return r.ok;
  } catch (e) { console.warn('mail failed:', e.message); return false; } finally { clearTimeout(t); }
}
const shell = (brand, title, body, link) => `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;color:#2a1620"><h2 style="letter-spacing:.2em;color:#5a1030">${esc(brand)}</h2><h3>${esc(title)}</h3>${body}${link ? `<p><a href="${esc(link[1])}" style="display:inline-block;background:#5a1030;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none">${esc(link[0])}</a></p>` : ''}<p style="color:#777;font-size:12px">Sent by ${esc(brand)}. If you didn’t expect this email you can ignore it.</p></div>`;
const MSG = { paid: 'Your payment is verified. We’ll start preparing your order.', processing: 'Your order is being crafted.', shipped: 'Your order has shipped.', delivered: 'Your order was delivered. We hope you love it!', cancelled: 'Your order was cancelled.', payment_rejected: 'We couldn’t verify your payment screenshot. Please upload a clear one.' };
function orderEmail(brand, o, origin, kind) {
  const title = kind === 'created' ? 'Order ' + o.number + ' placed' : 'Order ' + o.number + ': ' + (MSG[o.status] ? o.status.replace('_', ' ') : 'update');
  const lines = o.items.map(i => `<li>${esc(i.name)} · ${esc(i.color)} · ${esc(i.size)} × ${i.qty}</li>`).join('');
  const body = `<p>${esc(kind === 'created' ? 'Thank you! Please pay by QR/UPI and upload the screenshot on your order page.' : MSG[o.status] || 'There is an update on your order.')}</p><ul>${lines}</ul><p>Total: ₹${o.totals.total.toLocaleString('en-IN')}</p>${o.tracking && o.tracking.id ? `<p>Courier: ${esc(o.tracking.courier || '')} ${esc(o.tracking.id)}</p>` : ''}<p>Guests can track with order number <b>${esc(o.number)}</b> and mobile number.</p>`;
  return { subject: `${brand} — ${title}`, html: shell(brand, title, body, ['View order', origin + '/order.html?id=' + o.id]) };
}
function resetEmail(brand, link) { return { subject: brand + ' — reset your password', html: shell(brand, 'Reset your password', '<p>Use the button below within 1 hour to choose a new password.</p>', ['Choose a new password', link]) }; }
module.exports = { enabled, send, orderEmail, resetEmail };
