'use strict';
/* Shiprocket connection (labels, courier assignment, live PIN-code check, status webhook).
   Needs SHIPROCKET_EMAIL + SHIPROCKET_PASSWORD (an API user created in Shiprocket → Settings → API) in the server environment.
   SHIPROCKET_PICKUP = the pickup-location name you created in Shiprocket (default "Primary"). SHIPROCKET_BASE exists for tests. */
const base = () => (process.env.SHIPROCKET_BASE || 'https://apiv2.shiprocket.in').replace(/\/+$/, '');
const enabled = () => !!(process.env.SHIPROCKET_EMAIL && process.env.SHIPROCKET_PASSWORD);
let tok = { v: '', at: 0 };

async function call(method, path, body, retry = true) {
  const ctrl = new AbortController(), t = setTimeout(() => ctrl.abort(), 12000);
  try {
    if (!tok.v || Date.now() - tok.at > 8 * 36e5) {
      const r = await fetch(base() + '/v1/external/auth/login', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: process.env.SHIPROCKET_EMAIL, password: process.env.SHIPROCKET_PASSWORD }), signal: ctrl.signal });
      const j = await r.json().catch(() => ({})); if (!j.token) throw new Error('Shiprocket sign-in failed — check SHIPROCKET_EMAIL / SHIPROCKET_PASSWORD');
      tok = { v: j.token, at: Date.now() };
    }
    const r = await fetch(base() + path, { method, headers: { 'content-type': 'application/json', authorization: 'Bearer ' + tok.v }, body: body ? JSON.stringify(body) : undefined, signal: ctrl.signal });
    if (r.status === 401 && retry) { tok = { v: '', at: 0 }; return call(method, path, body, false); }
    const j = await r.json().catch(() => ({})); if (!r.ok) throw new Error(j.message || ('Shiprocket error ' + r.status));
    return j;
  } finally { clearTimeout(t); }
}

/* Which couriers deliver to this PIN from your pickup PIN, and how fast */
async function serviceability({ from, to, weight = 0.8, cod = false }) {
  const j = await call('GET', `/v1/external/courier/serviceability/?pickup_postcode=${from}&delivery_postcode=${to}&weight=${weight}&cod=${cod ? 1 : 0}`);
  const list = (j.data && j.data.available_courier_companies) || [];
  if (!list.length) return { serviceable: false };
  const days = list.map(c => parseInt(c.estimated_delivery_days, 10)).filter(n => n > 0);
  return { serviceable: true, minDays: days.length ? Math.min(...days) : null, cod: list.some(c => c.cod === 1 || c.cod === true) };
}

/* Create the shipment for an order, assign a courier + AWB, and fetch the label */
async function createShipment(order, pkg, site) {
  const c = order.customer, items = order.items.map(i => ({ name: (i.name + ' (' + i.size + ')').slice(0, 100), sku: i.id.slice(0, 40), units: i.qty, selling_price: i.unit }));
  const d = new Date(order.createdAt), pad = n => String(n).padStart(2, '0'), date = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  const parts = c.name.trim().split(/\s+/);
  const created = await call('POST', '/v1/external/orders/create/adhoc', {
    order_id: order.number, order_date: date, pickup_location: process.env.SHIPROCKET_PICKUP || 'Primary', billing_customer_name: parts[0], billing_last_name: parts.slice(1).join(' ') || '.',
    billing_address: c.line1, billing_address_2: c.line2 || '', billing_city: c.city, billing_pincode: c.pin, billing_state: c.state, billing_country: 'India', billing_email: c.email, billing_phone: c.phone.replace(/^\+91/, ''),
    shipping_is_billing: true, order_items: items, payment_method: order.method === 'cod' ? 'COD' : 'Prepaid', sub_total: order.totals.total,
    length: pkg.l, breadth: pkg.b, height: pkg.h, weight: pkg.kg
  });
  const shipmentId = created.shipment_id; if (!shipmentId) throw new Error(created.message || 'Shiprocket did not create the shipment');
  const awbRes = await call('POST', '/v1/external/courier/assign/awb', { shipment_id: shipmentId });
  const a = (awbRes.response && awbRes.response.data) || awbRes.data || {}, awb = a.awb_code, courier = a.courier_name || '';
  if (!awb) throw new Error((awbRes.message) || 'A courier could not be assigned yet — you can assign one in the Shiprocket dashboard');
  let labelUrl = ''; try { const l = await call('POST', '/v1/external/courier/generate/label', { shipment_id: [shipmentId] }); labelUrl = l.label_url || ''; } catch (e) { /* label can be fetched later */ }
  return { shipmentId, awb, courier, labelUrl, trackUrl: 'https://shiprocket.co/tracking/' + awb };
}
async function track(awb) { const j = await call('GET', '/v1/external/courier/track/awb/' + encodeURIComponent(awb)); const t = j.tracking_data || {}; return { status: t.shipment_status_text || (t.shipment_track && t.shipment_track[0] && t.shipment_track[0].current_status) || '', activities: (t.shipment_track_activities || []).slice(0, 8).map(a => ({ at: a.date, text: a.activity, where: a.location })) }; }
/* Map a courier status text to our order status (only ever moves forward) */
function mapStatus(txt) { const s = String(txt || '').toUpperCase(); if (/DELIVERED/.test(s) && !/UNDELIVERED|NOT DELIVERED/.test(s)) return 'delivered'; if (/PICKED|IN TRANSIT|OUT FOR DELIVERY|SHIPPED|REACHED/.test(s)) return 'shipped'; return ''; }
module.exports = { enabled, serviceability, createShipment, track, mapStatus };
