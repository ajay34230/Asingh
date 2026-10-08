'use strict';
/* Order validation, server-side pricing (never trust client prices) and the status machine. */
const A = require('../js/data.js');
const { id } = require('./db');

const STATUS = {
  awaiting_payment: 'Awaiting payment', payment_review: 'Payment under review', payment_rejected: 'Payment needs attention',
  paid: 'Payment verified', processing: 'Being crafted', shipped: 'Shipped', delivered: 'Delivered', cancelled: 'Cancelled'
};
const ADMIN_NEXT = { paid: ['processing', 'cancelled'], processing: ['shipped', 'cancelled'], shipped: ['delivered'], payment_review: ['paid', 'payment_rejected', 'cancelled'], awaiting_payment: ['cancelled'], payment_rejected: ['cancelled', 'paid'] };

const bad = m => Object.assign(new Error(m), { status: 400 });
const str = (v, max) => String(v == null ? '' : v).trim().slice(0, max);
const byId = Object.fromEntries(A.PRODUCTS.map(p => [p.id, p]));
const stitchBy = Object.fromEntries(A.STITCH.map(s => [s.id, s]));

function price(rawItems) {
  if (!Array.isArray(rawItems) || !rawItems.length || rawItems.length > 30) throw bad('Your bag is empty or too large.');
  const items = rawItems.map(r => {
    const p = byId[r && r.id]; if (!p) throw bad('Unknown product.');
    const size = str(r.size, 4); if (A.SIZES.indexOf(size) < 0) throw bad('Choose a valid size for ' + p.name + '.');
    const stitch = str(r.stitch, 12); if (p.stitch.indexOf(stitch) < 0) throw bad('Stitching option not available for ' + p.name + '.');
    const color = (p.colors.find(c => c.name === r.color) || p.colors[0]).name;
    const qty = Math.max(1, Math.min(9, parseInt(r.qty, 10) || 1));
    const unit = p.price + stitchBy[stitch].add;
    return { id: p.id, name: p.name, size, stitch, stitchLabel: stitchBy[stitch].label, color, note: str(r.note, 240), qty, unit };
  });
  const subtotal = items.reduce((a, i) => a + i.unit * i.qty, 0);
  const shipping = subtotal >= A.FREE_SHIP_FROM ? 0 : A.SHIP_FLAT;
  return { items, totals: { subtotal, shipping, total: subtotal + shipping } };
}

function customer(c) {
  c = c || {};
  const out = { name: str(c.name, 80), email: str(c.email, 120).toLowerCase(), phone: str(c.phone, 20).replace(/[\s-]/g, ''), line1: str(c.line1, 160), line2: str(c.line2, 160), pin: str(c.pin, 6), city: str(c.city, 60), state: str(c.state, 40) };
  if (out.name.length < 2) throw bad('Enter your full name.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(out.email)) throw bad('Enter a valid email.');
  if (!/^(\+91)?[6-9][0-9]{9}$/.test(out.phone)) throw bad('Enter a valid 10-digit mobile number.');
  if (out.line1.length < 5) throw bad('Enter your address.');
  if (!/^[1-9][0-9]{5}$/.test(out.pin)) throw bad('Enter a valid 6-digit PIN code.');
  if (out.city.length < 2 || !out.state) throw bad('Enter your city and state.');
  return out;
}

function create(db, user, body, methodId) {
  const { items, totals } = price(body.items);
  const now = Date.now(), d = new Date(now);
  const number = 'AS' + String(d.getUTCFullYear()).slice(2) + String(d.getUTCMonth() + 1).padStart(2, '0') + String(d.getUTCDate()).padStart(2, '0') + '-' + String(1000 + (db.nextSeq() * 7919 % 9000));
  const order = { id: id(10), number, userId: user.id, items, totals, customer: customer(body.customer), method: methodId, status: 'awaiting_payment', proof: null, createdAt: now, updatedAt: now, timeline: [{ at: now, status: 'awaiting_payment', note: 'Order placed', by: 'customer' }] };
  db.data.orders.unshift(order); db.save(); return order;
}
function transition(db, order, status, note, by) {
  const now = Date.now(); order.status = status; order.updatedAt = now; order.timeline.push({ at: now, status, note: note || '', by }); db.save(); return order;
}
/* customers see their own order; proof file name and internal ids stay server-side */
function view(o, isAdmin) {
  const v = { id: o.id, number: o.number, status: o.status, statusLabel: STATUS[o.status], items: o.items, totals: o.totals, customer: o.customer, method: o.method, createdAt: o.createdAt, updatedAt: o.updatedAt, timeline: o.timeline.map(t => ({ at: t.at, status: t.status, label: STATUS[t.status], note: t.note })), proof: o.proof ? { at: o.proof.at, utr: o.proof.utr, mime: o.proof.mime } : null };
  if (isAdmin) { v.userId = o.userId; v.next = ADMIN_NEXT[o.status] || []; v.timeline = o.timeline.map(t => ({ at: t.at, status: t.status, label: STATUS[t.status], note: t.note, by: t.by })); }
  return v;
}
module.exports = { STATUS, ADMIN_NEXT, create, transition, view, price };
