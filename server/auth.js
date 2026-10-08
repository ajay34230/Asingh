'use strict';
const crypto = require('crypto');
const { id } = require('./db');

const SESSION_DAYS = 30;
const sha = s => crypto.createHash('sha256').update(s).digest('hex');

function hashPassword(pw) {
  const salt = crypto.randomBytes(16);
  const h = crypto.scryptSync(pw, salt, 64, { N: 16384, r: 8, p: 1 });
  return 's1$' + salt.toString('hex') + '$' + h.toString('hex');
}
const DUMMY = hashPassword('dummy-password-for-timing');
function verifyPassword(pw, stored) {
  try {
    const [v, saltHex, hashHex] = String(stored || DUMMY).split('$');
    if (v !== 's1') return false;
    const h = crypto.scryptSync(pw, Buffer.from(saltHex, 'hex'), 64, { N: 16384, r: 8, p: 1 });
    return crypto.timingSafeEqual(h, Buffer.from(hashHex, 'hex'));
  } catch (e) { return false; }
}

function parseCookies(req) {
  const out = {}; (req.headers.cookie || '').split(';').forEach(p => { const i = p.indexOf('='); if (i > 0) out[p.slice(0, i).trim()] = decodeURIComponent(p.slice(i + 1).trim()); });
  return out;
}

class Auth {
  constructor(db, opts = {}) { this.db = db; this.secure = !!opts.secure; this.bySid = new Map(); db.data.sessions.forEach(s => this.bySid.set(s.h, s)); this.prune(); }
  prune() { const now = Date.now(); const keep = this.db.data.sessions.filter(s => s.exp > now); if (keep.length !== this.db.data.sessions.length) { this.db.data.sessions = keep; this.bySid = new Map(keep.map(s => [s.h, s])); this.db.save(); } }
  user(req) {
    const t = parseCookies(req).as_sid; if (!t) return null;
    const s = this.bySid.get(sha(t)); if (!s || s.exp < Date.now()) return null;
    return this.db.data.users.find(u => u.id === s.uid) || null;
  }
  login(req, res, user) {
    const token = crypto.randomBytes(32).toString('base64url'); const s = { h: sha(token), uid: user.id, exp: Date.now() + SESSION_DAYS * 864e5, at: Date.now() };
    this.db.data.sessions.push(s); this.bySid.set(s.h, s); this.db.save();
    const https = this.secure || req.headers['x-forwarded-proto'] === 'https';
    this.setCookie(res, `as_sid=${token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${SESSION_DAYS * 86400}${https ? '; Secure' : ''}`);
  }
  logout(req, res) {
    const t = parseCookies(req).as_sid;
    if (t) { const h = sha(t); this.db.data.sessions = this.db.data.sessions.filter(s => s.h !== h); this.bySid.delete(h); this.db.save(); }
    this.setCookie(res, 'as_sid=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0');
  }
  revokeOthers(user, req) { const t = parseCookies(req).as_sid, keep = t ? sha(t) : ''; this.db.data.sessions = this.db.data.sessions.filter(s => s.uid !== user.id || s.h === keep); this.bySid = new Map(this.db.data.sessions.map(s => [s.h, s])); this.db.save(); }
  setCookie(res, c) { const prev = res.getHeader('Set-Cookie'); res.setHeader('Set-Cookie', prev ? [].concat(prev, c) : c); }
}

/* sliding-window limiter, per key */
function limiter(max, windowMs) {
  const hits = new Map();
  return key => {
    const now = Date.now(), arr = (hits.get(key) || []).filter(t => now - t < windowMs);
    arr.push(now); hits.set(key, arr);
    if (hits.size > 5000) for (const [k, v] of hits) if (!v.length || now - v[v.length - 1] > windowMs) hits.delete(k);
    return arr.length <= max;
  };
}
const publicUser = u => u && ({ id: u.id, role: u.role, name: u.name || '', email: u.email || '', isGuest: !!u.isGuest, profile: u.profile || {}, addresses: u.addresses || [] });
module.exports = { Auth, hashPassword, verifyPassword, limiter, publicUser, id };
