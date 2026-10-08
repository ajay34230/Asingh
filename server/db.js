'use strict';
/* Tiny JSON-file store with atomic writes. Swap for SQLite/Postgres by re-implementing this module's surface. */
const fs = require('fs'), path = require('path'), crypto = require('crypto');

const id = (n = 9) => crypto.randomBytes(n).toString('base64url');

class DB {
  constructor(dir) {
    this.dir = dir; this.file = path.join(dir, 'db.json'); this.uploads = path.join(dir, 'uploads');
    fs.mkdirSync(this.uploads, { recursive: true, mode: 0o700 });
    this.data = { users: [], sessions: [], orders: [], notifications: [], settings: {}, seq: 0, messages: [], subscribers: [], coupons: [], resets: [], reviews: [] };
    // (older databases get the new collections below after loading)
    if (fs.existsSync(this.file)) { try { Object.assign(this.data, JSON.parse(fs.readFileSync(this.file, 'utf8'))); } catch (e) { fs.copyFileSync(this.file, this.file + '.corrupt-' + Date.now()); } }
    ['messages', 'subscribers', 'coupons', 'resets', 'reviews'].forEach(k => { if (!Array.isArray(this.data[k])) this.data[k] = []; });
    this.timer = null;
    process.on('exit', () => this.flush());
  }
  save() { if (this.timer) return; this.timer = setTimeout(() => { this.timer = null; this.flush(); }, 40); }
  flush() {
    try { const tmp = this.file + '.tmp'; fs.writeFileSync(tmp, JSON.stringify(this.data), { mode: 0o600 }); fs.renameSync(tmp, this.file); }
    catch (e) { console.error('db write failed', e.message); }
  }
  nextSeq() { this.data.seq += 1; this.save(); return this.data.seq; }
}
module.exports = { DB, id };
