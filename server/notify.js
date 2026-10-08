'use strict';
/* Admin alerts: persisted notifications + live Server-Sent Events + optional outbound webhook (Slack/Discord/Telegram-style). */
const dns = require('dns').promises, net = require('net');
const { id } = require('./db');

class Notifier {
  constructor(db) { this.db = db; this.clients = new Set(); }
  attach(req, res) {
    res.writeHead(200, { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-store', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
    res.write('retry: 4000\n\n'); this.clients.add(res);
    const hb = setInterval(() => res.write(': hb\n\n'), 25000);
    req.on('close', () => { clearInterval(hb); this.clients.delete(res); });
  }
  push(type, order, title, body) {
    const n = { id: id(6), at: Date.now(), type, orderId: order && order.id, number: order && order.number, title, body, read: false };
    this.db.data.notifications.unshift(n); this.db.data.notifications.length = Math.min(this.db.data.notifications.length, 300); this.db.save();
    const msg = `event: notify\ndata: ${JSON.stringify(n)}\n\n`; this.clients.forEach(c => { try { c.write(msg); } catch (e) { this.clients.delete(c); } });
    this.webhook(`🔔 ${title}${body ? ' — ' + body : ''}`, n).catch(e => console.warn('webhook failed:', e.message));
    return n;
  }
  async webhook(text, payload) {
    const url = process.env.ADMIN_WEBHOOK_URL || (this.db.data.settings || {}).webhookUrl; if (!url) return;
    const u = new URL(url); if (u.protocol !== 'https:' && !process.env.ALLOW_HTTP_WEBHOOK) throw new Error('webhook must be https');
    if (!(await isPublicHost(u.hostname)) && !process.env.ALLOW_PRIVATE_WEBHOOK) throw new Error('webhook host not public');
    const ctrl = new AbortController(), t = setTimeout(() => ctrl.abort(), 5000);
    try { await fetch(u, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ text, content: text, event: payload }), signal: ctrl.signal, redirect: 'error' }); } finally { clearTimeout(t); }
  }
}
const PRIV = [/^10\./, /^127\./, /^169\.254\./, /^192\.168\./, /^172\.(1[6-9]|2\d|3[01])\./, /^0\./, /^::1$/, /^fc|^fd/i, /^fe80/i];
async function isPublicHost(h) {
  try { const ips = net.isIP(h) ? [h] : (await dns.lookup(h, { all: true })).map(r => r.address); return ips.length > 0 && ips.every(ip => !PRIV.some(r => r.test(ip))); } catch (e) { return false; }
}
module.exports = { Notifier, isPublicHost };
