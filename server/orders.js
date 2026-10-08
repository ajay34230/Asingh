'use strict';
/* Order validation, server-side pricing (never trust client prices) and the status machine. */
const A = require('../js/data.js');
const { id } = require('./db');

const STATUS = {
  awaiting_payment: 'Awaiting payment', payment_review: 'Payment under review', payment_rejected: 'Payment needs attention',
  paid: 'Payment verified', processing: 'Being crafted', shipped: 'Shipped', delivered: 'Delivered', cancelled: 'Cancelled'
};
/* What the admin may change an order to. Forward steps plus one step back, so a mis-click can be corrected. */
const ADMIN_NEXT = {
  awaiting_payment: ['paid', 'cancelled'], payment_review: ['paid', 'payment_rejected', 'cancelled'], payment_rejected: ['paid', 'awaiting_payment', 'cancelled'],
  paid: ['processing', 'shipped', 'cancelled'], processing: ['paid', 'shipped', 'cancelled'], shipped: ['processing', 'delivered'], delivered: ['shipped'], cancelled: ['awaiting_payment']
};
/* Short, memorable order numbers — "AS-48213". Random (not sequential) so they don't reveal how many orders you have;
   tracking also needs the buyer's mobile number, so a guessed number reveals nothing. */
const normNumber = s => { let u = String(s || '').toUpperCase().replace(/[^A-Z0-9]/g, ''); if (/^\d+$/.test(u)) u = 'AS' + u; return u; };
const normPhone = s => String(s || '').replace(/\D/g, '').slice(-10);
function newNumber(db) {
  const used = new Set(db.data.orders.map(o => normNumber(o.number)));
  for (let digits = 5; digits <= 8; digits++) {
    const lo = Math.pow(10, digits - 1), span = 9 * lo;
    for (let i = 0; i < 40; i++) { const n = 'AS' + (lo + require('crypto').randomInt(span)); if (!used.has(n)) return 'AS-' + n.slice(2); }
  }
  throw Object.assign(new Error('Could not allocate an order number'), { status: 500 });
}

const bad = m => Object.assign(new Error(m), { status: 400 });
const str = (v, max) => String(v == null ? '' : v).trim().slice(0, max);

function price(rawItems, cat) {
  if (!Array.isArray(rawItems) || !rawItems.length || rawItems.length > 30) throw bad('Your bag is empty or too large.');
  const items = rawItems.map(r => {
    const p = cat.find(r && r.id); if (!p || !p.published) throw bad('Sorry — one of the items is no longer available.');
    if (p.soldOut) throw bad(p.name + ' is sold out right now.');
    const size = str(r.size, 4); if (cat.sizes.indexOf(size) < 0) throw bad('Choose a valid size for ' + p.name + '.');
    const stitch = str(r.stitch, 12); const so = cat.stitchOpt(stitch); if (!so || p.stitch.indexOf(stitch) < 0) throw bad('Stitching option not available for ' + p.name + '.');
    const color = (p.colors.find(c => c.name === r.color) || p.colors[0]).name;
    const qty = Math.max(1, Math.min(9, parseInt(r.qty, 10) || 1));
    const unit = p.price + cat.stitchAdd(stitch);
    return { id: p.id, img: cat.thumb(p), name: p.name, size, stitch, stitchLabel: so.label, color, note: str(r.note, 240), qty, unit };
  });
  const subtotal = items.reduce((a, i) => a + i.unit * i.qty, 0);
  const shipping = subtotal >= cat.site.shipFreeFrom ? 0 : cat.site.shipFlat;
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

function create(db, user, body, methodId, cat) {
  const { items, totals } = price(body.items, cat);
  const now = Date.now(), d = new Date(now);
  const number = newNumber(db);
  const order = { id: id(10), number, userId: user.id, items, totals, customer: customer(body.customer), method: methodId, status: 'awaiting_payment', proof: null, createdAt: now, updatedAt: now, timeline: [{ at: now, status: 'awaiting_payment', note: 'Order placed', by: 'customer' }] };
  db.data.orders.unshift(order); db.save(); return order;
}
function transition(db, order, status, note, by) {
  const now = Date.now(); order.status = status; order.updatedAt = now; order.timeline.push({ at: now, status, note: note || '', by }); db.save(); return order;
}
/* customers see their own order; proof file name and internal ids stay server-side */
function view(o, isAdmin) {
  const v = { id: o.id, number: o.number, status: o.status, statusLabel: STATUS[o.status], items: o.items, totals: o.totals, customer: o.customer, method: o.method, createdAt: o.createdAt, updatedAt: o.updatedAt, timeline: o.timeline.map(t => ({ at: t.at, status: t.status, label: STATUS[t.status], note: String(t.by).startsWith('webhook') ? '' : t.note })), proof: o.proof ? { at: o.proof.at, utr: o.proof.utr, mime: o.proof.mime } : null, tracking: o.tracking || null, request: o.request || null };
  if (isAdmin) { v.userId = o.userId; v.next = ADMIN_NEXT[o.status] || []; v.timeline = o.timeline.map(t => ({ at: t.at, status: t.status, label: STATUS[t.status], note: t.note, by: t.by })); }
  return v;
}
/* Limited, address-free view for the public tracking page (needs number + mobile). */
function trackView(o, canClaim) {
  return { number: o.number, status: o.status, statusLabel: STATUS[o.status], createdAt: o.createdAt, updatedAt: o.updatedAt, tracking: o.tracking || null, totals: o.totals,
    items: o.items.map(i => ({ id: i.id, name: i.name, color: i.color, size: i.size, stitchLabel: i.stitchLabel, qty: i.qty })),
    timeline: o.timeline.map(t => ({ at: t.at, status: t.status, label: STATUS[t.status], note: t.by === 'admin' ? t.note : '' })), canClaim: !!canClaim };
}
function cleanTracking(t) {
  if (!t || typeof t !== 'object') return null;
  const courier = str(t.courier, 40), id = str(t.id, 60); let url = str(t.url, 300);
  if (!courier && !id && !url) return null;
  if (url) { let u; try { u = new URL(url); } catch (e) { throw bad('Tracking link is not a valid URL.'); } if (u.protocol !== 'https:') throw bad('Tracking link must start with https://'); url = u.href; }
  return { courier, id, url };
}
module.exports = { STATUS, ADMIN_NEXT, create, transition, view, trackView, cleanTracking, normNumber, normPhone, price };
