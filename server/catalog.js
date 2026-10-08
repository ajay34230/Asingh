'use strict';
/* The live catalogue (products, categories, store settings), editable by the admin.
   Seeded once from js/data.js (demo content). The storefront receives it through a generated /js/data.js overlay,
   so the same front-end code works for demo data and for the store owner's real products. */
const fs = require('fs'), path = require('path');
const A = require('../js/data.js');
const { id } = require('./db');
const Pages = require('./pages');

const bad = m => Object.assign(new Error(m), { status: 400 });
const s = (v, n) => String(v == null ? '' : v).trim().slice(0, n);
const clone = o => JSON.parse(JSON.stringify(o));
const slug2 = t => String(t).toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'page';
const slug = t => String(t).toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 48) || 'item';
const HEX = /^#[0-9a-fA-F]{6}$/, WIDTHS = [400, 800, 1200], MAX_IMAGES = 6;
const OCC_SUB = { wedding: 'Lehengas, anarkalis & bridal sets', festive: 'Chaniya cholis & bright festive suits', sangeet: 'Mirror work, sharara & gharara', party: 'Gowns, peplum & indo-western', everyday: 'Kurti sets & easy cotton suits' };
const defaultSite = () => ({
  name: 'ASINGH', announcement: 'Custom stitching in 10–14 days · one free alteration',
  heroEyebrow: 'Suits & ethnic wear for girls', heroTitle: 'Dressed in *every shade of festive*', heroLead: 'Anarkalis, lehenga cholis, shararas, kurti sets and more — with gota patti, bandhani and zardozi, stitched to your measure in 10–14 days.', heroCta: 'Shop the collection', heroImage: null,
  sections: { marquee: true, trust: true, collections: true, occasions: true, newArrivals: true, story: true, bestsellers: true, testimonials: true },
  marquee: ['Anarkali', 'Lehenga Choli', 'Sharara', 'Gharara', 'Patiala', 'Kurti Sets', 'Indo-Western', 'Ethnic Gowns'],
  trust: [{ title: 'Beautifully crafted', sub: 'Gota patti · bandhani · zardozi' }, { title: 'Free shipping', sub: '' }, { title: '7-day returns', sub: 'On unstitched pieces' }, { title: 'Secure payments', sub: 'UPI / QR with proof of payment' }],
  occasions: A.OCCASIONS.map(o => ({ id: o.id, label: o.label, sub: OCC_SUB[o.id] || '' })),
  story: { eyebrow: 'Made to measure', title: 'Three steps to a perfect fit', cta: 'Explore custom stitching', steps: [
    { title: 'Choose your piece', text: 'Pick your suit, lehenga or dress, then the colour and stitching — unstitched, semi or fully custom.' },
    { title: 'Share your measurements', text: 'Select a standard size or add notes. Our stylists confirm every detail with you.' },
    { title: 'Crafted with care', text: 'Embroidery and finishing done by skilled artisans and delivered in 10–14 days, with one free alteration.' }] },
  policies: { returns: 'Unstitched and semi-stitched pieces can be returned within 7 days. Custom-stitched pieces are made to order and are not returnable, but we offer one complimentary alteration.', shipping: '' },
  stitch: A.STITCH.map(x => ({ id: x.id, label: x.label, note: x.note, eta: x.eta, add: { unstitched: 0, semi: 600, custom: 1800 }[x.id], enabled: true })),
  sizeChart: [['XS', 32, 26, 35], ['S', 34, 28, 37], ['M', 36, 30, 39], ['L', 38, 32, 41], ['XL', 40, 34, 43], ['XXL', 42, 36, 45]].map(r => ({ size: r[0], bust: r[1], waist: r[2], hip: r[3] })),
  contactEmail: '', contactPhone: '', contactAddress: '', contactHours: '',
  googleSiteVerification: '', ga4Id: '', returnDays: 7, handlingMin: 1, handlingMax: 3, deliveryMin: 3, deliveryMax: 7,
  shipFreeFrom: A.FREE_SHIP_FROM, shipFlat: A.SHIP_FLAT, testimonials: []
});
const merge = (d, v) => { const o = { ...d }; Object.keys(v || {}).forEach(k => { o[k] = d[k] && typeof d[k] === 'object' && !Array.isArray(d[k]) && v[k] && typeof v[k] === 'object' && !Array.isArray(v[k]) ? { ...d[k], ...v[k] } : v[k]; }); return o; };

class Catalog {
  constructor(db) {
    this.db = db; const D = db.data;
    if (!D.catalog) {
      D.catalog = { version: 1, categories: A.CATEGORIES.map(c => ({ id: c.id, label: c.label })), site: defaultSite(),
        products: A.PRODUCTS.map(p => Object.assign(clone(p), { published: true, soldOut: false, demo: true, images: [], imageStore: {}, createdAt: Date.now() })) };
      db.save();
    }
    this.D = D.catalog; this.D.site = merge(defaultSite(), this.D.site); delete this.D.site.stitchAdd;
    if (Array.isArray(this.D.pages)) Pages.DEFAULT_PAGES.forEach(d => { if (!this.D.pages.some(p => p.slug === d.slug)) this.D.pages.push({ ...d, published: true, system: true, updatedAt: Date.now() }); });
    if (!Array.isArray(this.D.pages)) { this.D.pages = Pages.DEFAULT_PAGES.map(p => ({ ...p, published: true, system: true, updatedAt: Date.now() })); db.save(); }
    fs.mkdirSync(path.join(db.dir, 'media'), { recursive: true, mode: 0o700 });
  }
  touch() { this.D.version = (this.D.version || 0) + 1; this.db.save(); }
  get site() { return this.D.site; }
  get categories() { return this.D.categories; }
  get products() { return this.D.products; }
  find(pid) { return this.D.products.find(p => p.id === pid); }
  stitchOpt(sid) { return this.site.stitch.find(x => x.id === sid && x.enabled); }
  stitchAdd(sid) { const o = this.stitchOpt(sid); return o ? Number(o.add) || 0 : 0; }
  get sizes() { return this.site.sizeChart.map(r => r.size); }
  get occasions() { return this.site.occasions; }
  /* ---- images ---- */
  imgUrl(p, rev, w) { const e = p.imageStore[rev]; return e ? (w === 'feed' ? (e.feed ? `/media/p/${p.id}/${rev}-feed.jpg` : `/media/p/${p.id}/${rev}-${e.ws.indexOf(1200) > -1 ? 1200 : e.ws[e.ws.length - 1]}.${e.ext}`) : `/media/p/${p.id}/${rev}-${w}.${e.ext}`) : ''; }
  thumb(p) { if (p.images.length) { const r = p.images[0], e = p.imageStore[r]; return this.imgUrl(p, r, e.ws.indexOf(400) > -1 ? 400 : e.ws[0]); } return `img/${p.id}-1-400.webp`; }
  mediaPath(pid, file) { return path.join(this.db.dir, 'media', pid, file); }
  addImage(p, rev, w, ext, data) {
    if (!/^[A-Za-z0-9_]{6,12}$/.test(rev)) throw bad('Bad image id.');
    if (w === 'feed') {   // a JPEG copy for Google Merchant Center (which prefers JPEG/PNG)
      if (ext !== 'jpg') throw bad('The feed copy must be a JPEG.'); const e0 = p.imageStore[rev]; if (!e0) throw bad('Upload the photo first.');
      fs.writeFileSync(path.join(this.db.dir, 'media', p.id, `${rev}-feed.jpg`), data, { mode: 0o600 }); e0.feed = true; this.touch(); return;
    }
    if (WIDTHS.indexOf(w) < 0) throw bad('Bad image size.');
    if (!p.imageStore[rev] && p.images.length >= MAX_IMAGES) throw bad(`Up to ${MAX_IMAGES} photos per product.`);
    const dir = path.join(this.db.dir, 'media', p.id); fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
    const e = p.imageStore[rev] || (p.imageStore[rev] = { ext, ws: [] });
    if (e.ext !== ext) throw bad('All sizes of one photo must use the same format.');
    fs.writeFileSync(path.join(dir, `${rev}-${w}.${ext}`), data, { mode: 0o600 });
    if (e.ws.indexOf(w) < 0) { e.ws.push(w); e.ws.sort((a, b) => a - b); }
    if (p.images.indexOf(rev) < 0) p.images.push(rev);
    this.touch();
  }
  dropImage(p, rev) {
    const e = p.imageStore[rev]; if (!e) return;
    e.ws.forEach(w => fs.rmSync(path.join(this.db.dir, 'media', p.id, `${rev}-${w}.${e.ext}`), { force: true })); fs.rmSync(path.join(this.db.dir, 'media', p.id, `${rev}-feed.jpg`), { force: true });
    delete p.imageStore[rev]; p.images = p.images.filter(r => r !== rev);
  }
  /* ---- products ---- */
  clean(b, base) {
    b = b || {}; const out = base ? { ...base } : {};
    const str = (k, n, req) => { if (b[k] === undefined && base) return; const v = s(b[k], n); if (req && v.length < 2) throw bad(`${k} is required.`); out[k] = v; };
    str('name', 90, true); if (!base || b.fabric !== undefined) out.fabric = s(b.fabric, 60); if (!base || b.badge !== undefined) out.badge = s(b.badge, 16); if (!base || b.blurb !== undefined) out.blurb = s(b.blurb, 600);
    if (!base || b.cat !== undefined) { if (!this.categories.some(c => c.id === b.cat)) throw bad('Choose a category.'); out.cat = b.cat; }
    if (!base || b.price !== undefined) { const v = Math.round(Number(b.price)); if (!(v >= 1 && v <= 1e6)) throw bad('Enter a price between ₹1 and ₹10,00,000.'); out.price = v; }
    if (!base || b.was !== undefined) { const w = b.was === '' || b.was == null ? null : Math.round(Number(b.was)); if (w != null && !(w > out.price)) throw bad('“Was” price must be higher than the selling price (or leave it blank).'); out.was = w; }
    if (!base || b.occ !== undefined) out.occ = (Array.isArray(b.occ) ? b.occ : []).filter(o => this.occasions.some(x => x.id === o));
    if (!base || b.stitch !== undefined) { const st = (Array.isArray(b.stitch) ? b.stitch : []).filter(x => this.site.stitch.some(y => y.id === x && y.enabled)); if (!st.length) throw bad('Choose at least one stitching option.'); out.stitch = this.site.stitch.map(x => x.id).filter(x => st.indexOf(x) > -1); }
    if (!base || b.colors !== undefined) { const cs = (Array.isArray(b.colors) ? b.colors : []).slice(0, 8).map(c => ({ name: s(c && c.name, 24), hex: s(c && c.hex, 7) })).filter(c => c.name); if (!cs.length) throw bad('Add at least one colour.'); cs.forEach(c => { if (!HEX.test(c.hex)) throw bad('Colour codes look like #7a1f3d.'); }); out.colors = cs; }
    if (!base || b.inc !== undefined) out.inc = (Array.isArray(b.inc) ? b.inc : []).map(x => s(x, 120)).filter(Boolean).slice(0, 10);
    if (!base || b.details !== undefined) out.details = (Array.isArray(b.details) ? b.details : []).map(x => s(x, 200)).filter(Boolean).slice(0, 10);
    ['best', 'isNew', 'published', 'soldOut'].forEach(k => { if (b[k] !== undefined) out[k] = !!b[k]; else if (!base) out[k] = k === 'published'; });
    if (!base || b.stock !== undefined) { const n = b.stock === '' || b.stock == null ? null : Math.round(Number(b.stock)); if (n !== null && !(n >= 0 && n <= 99999)) throw bad('Stock must be a whole number (or blank for unlimited).'); out.stock = n; if (n === 0) out.soldOut = true; }
    if (!base || b.rating !== undefined) { const r = b.rating === '' || b.rating == null ? null : Number(b.rating); if (r != null && !(r >= 1 && r <= 5)) throw bad('Rating must be between 1 and 5 (or blank).'); out.rating = r; }
    if (!base || b.reviews !== undefined) out.reviews = b.reviews === '' || b.reviews == null ? 0 : Math.max(0, Math.round(Number(b.reviews)) || 0);
    return out;
  }
  create(b) {
    const p = this.clean(b, null); let pid = slug(p.name), n = 2; while (this.find(pid)) pid = slug(p.name).slice(0, 44) + '-' + n++;
    Object.assign(p, { id: pid, demo: false, images: [], imageStore: {}, createdAt: Date.now() }); this.D.products.unshift(p); this.touch(); return p;
  }
  update(pid, b) {
    const p = this.find(pid); if (!p) throw Object.assign(new Error('Product not found'), { status: 404 });
    Object.assign(p, this.clean(b, p));
    if (Array.isArray(b.images)) { const order = b.images.filter(r => p.imageStore[r]); p.images.slice().forEach(r => { if (order.indexOf(r) < 0) this.dropImage(p, r); }); p.images = order; }
    this.touch(); return p;
  }
  remove(pid) {
    const p = this.find(pid); if (!p) throw Object.assign(new Error('Product not found'), { status: 404 });
    Object.keys(p.imageStore).forEach(r => this.dropImage(p, r)); fs.rmSync(path.join(this.db.dir, 'media', pid), { recursive: true, force: true });
    this.D.products = this.D.products.filter(x => x !== p); this.touch();
  }
  clearDemo() { const demo = this.D.products.filter(p => p.demo); demo.forEach(p => this.remove(p.id)); this.D.site.testimonials = []; this.touch(); return demo.length; }
  /* ---- content pages ---- */
  get pages() { return this.D.pages; }
  page(slug) { return this.D.pages.find(p => p.slug === slug); }
  pageVars() { const t = this.site; return { name: t.name, email: t.contactEmail, phone: t.contactPhone, hours: t.contactHours, address: t.contactAddress }; }
  savePage(slug, b) {
    b = b || {}; let p = slug ? this.page(slug) : null; if (slug && !p) throw Object.assign(new Error('Page not found'), { status: 404 });
    const title = s(b.title !== undefined ? b.title : p && p.title, 80); if (title.length < 2) throw bad('Give the page a title.');
    const body = b.body !== undefined ? String(b.body).slice(0, 20000) : p ? p.body : '';
    const group = ['help', 'legal', 'none'].indexOf(b.group) > -1 ? b.group : p ? p.group : 'help';
    if (!p) { let sl = slug2(b.slug || title), n = 2; if (['index', 'shop', 'product', 'cart', 'checkout', 'account', 'track', 'order', 'invoice', 'admin', 'page', '404', 'sitemap'].indexOf(sl) > -1) sl += '-page'; const base = sl; while (this.page(sl)) sl = base + '-' + n++; p = { slug: sl, system: false }; this.D.pages.push(p); }
    Object.assign(p, { title, body, group, reviewed: true, published: b.published === undefined ? (p.published !== false) : !!b.published, updatedAt: Date.now() }); this.touch(); return p;
  }
  removePage(slug) { const p = this.page(slug); if (!p) throw Object.assign(new Error('Page not found'), { status: 404 }); if (slug === 'contact') throw bad('The contact page can be hidden but not deleted.'); this.D.pages = this.D.pages.filter(x => x !== p); this.touch(); }
  /* ---- categories & site ---- */
  setCategories(list) {
    const seen = new Set(), out = (Array.isArray(list) ? list : []).slice(0, 40).map(c => { const label = s(c && c.label, 30); let cid = s(c && c.id, 30).toLowerCase().replace(/[^a-z0-9-]/g, '') || slug(label); if (!label) return null; while (seen.has(cid)) cid += '-2'; seen.add(cid); return { id: cid, label }; }).filter(Boolean);
    if (!out.length) throw bad('Keep at least one category.');
    const missing = this.D.products.filter(p => !seen.has(p.cat)); if (missing.length) throw bad(`Move or delete these products first: ${missing.slice(0, 3).map(p => p.name).join(', ')}${missing.length > 3 ? '…' : ''}`);
    this.D.categories = out; this.touch();
  }
  setSite(b) {
    b = b || {}; const t = this.D.site, st = (k, n) => { if (b[k] !== undefined) t[k] = s(b[k], n); };
    [['name', 40], ['announcement', 90], ['heroEyebrow', 50], ['heroTitle', 120], ['heroLead', 240], ['heroCta', 30], ['contactEmail', 120], ['contactPhone', 30], ['contactAddress', 200], ['contactHours', 60]].forEach(x => st(x[0], x[1]));
    if (!t.name) t.name = 'ASINGH';
    if (t.contactEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(t.contactEmail)) throw bad('Contact email looks invalid.');
    const money = (k, max, label) => { if (b[k] !== undefined) { const v = Math.round(Number(b[k])); if (!(v >= 0 && v <= max)) throw bad(label + ' is not valid.'); t[k] = v; } };
    money('shipFreeFrom', 1e6, 'Free-shipping amount'); money('shipFlat', 1e4, 'Shipping fee'); money('returnDays', 90, 'Return window'); ['handlingMin', 'handlingMax', 'deliveryMin', 'deliveryMax'].forEach(k => money(k, 60, 'Delivery days'));
    if (t.handlingMax < t.handlingMin || t.deliveryMax < t.deliveryMin) throw bad('Maximum days can’t be smaller than minimum days.');
    if (b.googleSiteVerification !== undefined) { const v = s(b.googleSiteVerification, 100); if (v && !/^[\w-]{8,100}$/.test(v)) throw bad('Search Console code should be the long code from Google (letters, numbers, - and _ only).'); t.googleSiteVerification = v; }
    if (b.ga4Id !== undefined) { const v = s(b.ga4Id, 20).toUpperCase(); if (v && !/^G-[A-Z0-9]{6,14}$/.test(v)) throw bad('Google Analytics ID looks like G-XXXXXXXXXX.'); t.ga4Id = v; }
    if (b.sections && typeof b.sections === 'object') Object.keys(t.sections).forEach(k => { if (b.sections[k] !== undefined) t.sections[k] = !!b.sections[k]; });
    if (Array.isArray(b.marquee)) t.marquee = b.marquee.map(x => s(x, 30)).filter(Boolean).slice(0, 16);
    if (Array.isArray(b.trust)) t.trust = b.trust.slice(0, 4).map(x => ({ title: s(x && x.title, 40), sub: s(x && x.sub, 60) })).filter(x => x.title);
    if (b.story && typeof b.story === 'object') { const o = b.story; if (o.eyebrow !== undefined) t.story.eyebrow = s(o.eyebrow, 40); if (o.title !== undefined) t.story.title = s(o.title, 90); if (o.cta !== undefined) t.story.cta = s(o.cta, 40); if (Array.isArray(o.steps)) t.story.steps = o.steps.slice(0, 4).map(x => ({ title: s(x && x.title, 50), text: s(x && x.text, 200) })).filter(x => x.title); }
    if (b.policies && typeof b.policies === 'object') { if (b.policies.returns !== undefined) t.policies.returns = s(b.policies.returns, 600); if (b.policies.shipping !== undefined) t.policies.shipping = s(b.policies.shipping, 600); }
    if (Array.isArray(b.occasions)) {
      const seen = new Set(), list = b.occasions.slice(0, 8).map(x => { const label = s(x && x.label, 30); let oid = s(x && x.id, 30).toLowerCase().replace(/[^a-z0-9-]/g, '') || slug(label); if (!label) return null; while (seen.has(oid)) oid += '-2'; seen.add(oid); return { id: oid, label, sub: s(x && x.sub, 60) }; }).filter(Boolean);
      this.D.products.forEach(p => { p.occ = (p.occ || []).filter(o => seen.has(o)); }); t.occasions = list;
    }
    if (Array.isArray(b.stitch)) {
      const next = t.stitch.map(cur => { const x = b.stitch.find(y => y && y.id === cur.id) || {}; const add = x.add === undefined ? cur.add : Math.round(Number(x.add)); if (!(add >= 0 && add <= 1e5)) throw bad('Stitching charge must be 0 or more.'); return { id: cur.id, label: s(x.label, 30) || cur.label, note: x.note === undefined ? cur.note : s(x.note, 140), eta: x.eta === undefined ? cur.eta : s(x.eta, 50), add, enabled: x.enabled === undefined ? cur.enabled : !!x.enabled }; });
      if (!next.some(x => x.enabled)) throw bad('Keep at least one stitching option on.');
      t.stitch = next; this.D.products.forEach(p => { p.stitch = (p.stitch || []).filter(id => next.some(x => x.id === id && x.enabled)); if (!p.stitch.length) p.stitch = [next.find(x => x.enabled).id]; });
    }
    if (Array.isArray(b.sizeChart)) { const seen = new Set(), rows = b.sizeChart.slice(0, 12).map(r => ({ size: s(r && r.size, 6).toUpperCase(), bust: s(r && r.bust, 6), waist: s(r && r.waist, 6), hip: s(r && r.hip, 6) })).filter(r => r.size && !seen.has(r.size) && seen.add(r.size)); if (!rows.length) throw bad('Keep at least one size.'); t.sizeChart = rows; }
    if (Array.isArray(b.testimonials)) t.testimonials = b.testimonials.slice(0, 12).map(x => ({ name: s(x && x.name, 40), city: s(x && x.city, 40), stars: Math.min(5, Math.max(1, Math.round(Number(x && x.stars)) || 5)), text: s(x && x.text, 300) })).filter(x => x.name && x.text);
    if (b.heroImageRev !== undefined) this.setHeroImage(b.heroImageRev);
    this.touch();
  }
  /* hero photo: the admin's browser makes 2 crops (wide + tall) × 3 widths and uploads them first */
  heroPath(rev, kind, w, ext) { return path.join(this.db.dir, 'media', 'site', `${rev}-${kind}-${w}.${ext}`); }
  addHeroFile(rev, kind, w, ext, data) {
    if (!/^[A-Za-z0-9_]{6,12}$/.test(rev) || ['wide', 'tall'].indexOf(kind) < 0 || [480, 800, 1080, 1280, 1920, 2560].indexOf(w) < 0) throw bad('Bad hero image request.');
    fs.mkdirSync(path.join(this.db.dir, 'media', 'site'), { recursive: true, mode: 0o700 }); fs.writeFileSync(this.heroPath(rev, kind, w, ext), data, { mode: 0o600 });
  }
  setHeroImage(rev) {
    const old = this.D.site.heroImage, rm = h => h && ['wide', 'tall'].forEach(k => h[k].forEach(w => fs.rmSync(this.heroPath(h.rev, k, w, h.ext), { force: true })));
    if (rev === null || rev === '') { rm(old); this.D.site.heroImage = null; return; }
    if (!/^[A-Za-z0-9_]{6,12}$/.test(String(rev))) throw bad('Bad hero image.');
    const ws = { tall: [480, 800, 1080], wide: [1280, 1920, 2560] }; let ext = null;
    for (const e of ['webp', 'jpg', 'png']) if (fs.existsSync(this.heroPath(rev, 'wide', 1920, e))) ext = e;
    if (!ext || !Object.keys(ws).every(k => ws[k].every(w => fs.existsSync(this.heroPath(rev, k, w, ext))))) throw bad('Upload all hero sizes first.');
    if (old && old.rev !== rev) rm(old); this.D.site.heroImage = { rev, ext, tall: ws.tall, wide: ws.wide };
  }
  /* ---- what the storefront receives ---- */
  publicProduct(p) {
    const o = { id: p.id, name: p.name, cat: p.cat, occ: p.occ, fabric: p.fabric, price: p.price, was: p.was || null, badge: p.badge || '', best: !!p.best, isNew: !!p.isNew, rating: p.rating || 0, reviews: p.reviews || 0, colors: p.colors, inc: p.inc, stitch: p.stitch, blurb: p.blurb, details: p.details, soldOut: !!p.soldOut, demo: !!p.demo };
    if (p.stock != null && p.stock > 0 && p.stock <= 5) o.left = p.stock;
    const live = this.site.stitch.filter(x => x.enabled).map(x => x.id); o.stitch = o.stitch.filter(x => live.indexOf(x) > -1); o.nimg = p.images.length || (p.demo ? 3 : 0); return o;
  }
  imgs() {
    const out = {};
    this.D.products.filter(p => p.published && p.images.length).forEach(p => p.images.forEach((rev, i) => { const e = p.imageStore[rev]; if (!e) return; const m = {}; e.ws.forEach(w => { m[w] = this.imgUrl(p, rev, w); }); out[`${p.id}-${i + 1}`] = m; }));
    return out;
  }
  overlay() {
    const t = this.site, st = t.stitch.filter(x => x.enabled).map(x => ({ id: x.id, label: x.label, note: x.note, eta: x.eta, add: x.add }));
    const data = { PRODUCTS: this.D.products.filter(p => p.published).map(p => this.publicProduct(p)), CATEGORIES: this.categories, STITCH: st, FREE_SHIP_FROM: t.shipFreeFrom, SHIP_FLAT: t.shipFlat, BRAND: t.name, OCCASIONS: t.occasions.map(o => ({ id: o.id, label: o.label })), SIZES: this.sizes, SIZECHART: t.sizeChart, SITE: Object.assign({}, t, { heroImage: t.heroImage }), IMGS: this.imgs(), PAGES: this.D.pages.filter(p => p.published && p.group !== 'none').map(p => ({ slug: p.slug, title: p.title, group: p.group })), REVIEWS: t.testimonials.map(x => ({ who: x.name, city: x.city, stars: x.stars, title: '', body: x.text })) };
    return `\n/* generated from the live catalogue */\n(function(A){var d=${JSON.stringify(data).replace(/</g, '\\u003c')};for(var k in d)A[k]=d[k];})(ASINGH);\n`;
  }
}
module.exports = { Catalog, WIDTHS, MAX_IMAGES };
