/* Core: helpers, cart/wishlist stores, shared chrome (header, menu, search, cart drawer, footer). No dependencies. */
(function (A) {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var fmt = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 });
  var money = function (n) { return fmt.format(n); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var store = {
    get: function (k, d) { try { var v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (e) { return d; } },
    set: function (k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* storage unavailable: carry on in memory */ } }
  };
  var byId = {}; A.PRODUCTS.forEach(function (p) { byId[p.id] = p; });
  var stitchById = {}; A.STITCH.forEach(function (s) { stitchById[s.id] = s; });
  var mqDesktop = window.matchMedia('(min-width: 1100px)');
  var mqSmall = window.matchMedia('(max-width: 699.98px)');
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ---------- Icons ---------- */
  var ICONS = {
    search: '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>',
    heart: '<path d="M12 20.5s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7.6a4.3 4.3 0 0 1 7.5 2.7C19.5 15.9 12 20.5 12 20.5z"/>',
    bag: '<path d="M5.5 8h13l-1 12h-11z"/><path d="M9 8V6.5a3 3 0 0 1 6 0V8"/>',
    user: '<circle cx="12" cy="8.5" r="3.6"/><path d="M4.8 20a7.2 7.2 0 0 1 14.4 0"/>',
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    close: '<path d="M6 6l12 12M18 6 6 18"/>',
    chev: '<path d="m6 9 6 6 6-6"/>',
    left: '<path d="m15 5-7 7 7 7"/>',
    right: '<path d="m9 5 7 7-7 7"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    filter: '<path d="M4 6h16M7 12h10M10 18h4"/>',
    check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
    truck: '<path d="M3 6h11v10H3zM14 10h4l3 3v3h-7"/><circle cx="7.5" cy="17.5" r="1.7"/><circle cx="17.5" cy="17.5" r="1.7"/>',
    scissors: '<circle cx="6.5" cy="6.5" r="2.5"/><circle cx="6.5" cy="17.5" r="2.5"/><path d="m8.5 8 11 9M8.5 16l11-9"/>',
    ret: '<path d="M4 12a8 8 0 1 0 2.6-5.9L4 8.5"/><path d="M4 4v4.5h4.5"/>',
    star: '<path d="m12 3.5 2.6 5.4 5.9.8-4.3 4.1 1 5.9L12 16.9 6.8 19.7l1-5.9L3.5 9.7l5.9-.8z"/>',
    lock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    zoom: '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2M11 8.5v5M8.5 11h5"/>'
  };
  function icon(n, cls) {
    return '<svg class="ico ' + (cls || '') + '" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' + ICONS[n] + '</svg>';
  }

  /* ---------- Responsive images ---------- */
  function picture(slug, n, o) {
    o = o || {};
    var sizes = o.sizes || '(min-width:1100px) 25vw, 50vw', alt = esc(o.alt || ''), pr = byId[slug];
    var pri = o.eager ? ' fetchpriority="high"' : ' loading="lazy"';
    if (pr && pr.nimg === 0) return '<picture><img src="img/placeholder.svg" width="1200" height="1500" alt="' + alt + '"' + pri + ' decoding="async"></picture>';
    var c = A.IMGS && (A.IMGS[slug + '-' + n] || A.IMGS[slug + '-1']);
    if (c) {   // photos uploaded by the store owner (one format, up to three widths)
      var ws = Object.keys(c).map(Number).sort(function (a, b) { return a - b; }), pick = c[800] || c[ws[ws.length - 1]];
      return '<picture><img src="' + esc(pick) + '" srcset="' + ws.map(function (w) { return esc(c[w]) + ' ' + w + 'w'; }).join(', ') + '" sizes="' + sizes + '" width="1200" height="1500" alt="' + alt + '"' + pri + ' decoding="async"></picture>';
    }
    var W = o.widths || [400, 800, 1200], base = 'img/' + slug + '-' + n + '-';
    var ss = function (ext) { return W.map(function (w) { return base + w + '.' + ext + ' ' + w + 'w'; }).join(', '); };
    return '<picture><source type="image/avif" srcset="' + ss('avif') + '" sizes="' + sizes + '">' +
      '<source type="image/webp" srcset="' + ss('webp') + '" sizes="' + sizes + '">' +
      '<img src="' + base + '800.jpg" width="' + (o.w || 1200) + '" height="' + (o.h || 1500) + '" alt="' + alt + '"' + pri + ' decoding="async"></picture>';
  }

  /* ---------- Stores ---------- */
  var subs = [];
  var Cart = {
    items: store.get('asingh.cart.v1', []).filter(function (i) { return byId[i.id]; }),
    wish: store.get('asingh.wish.v1', []).filter(function (id) { return byId[id]; }),
    coupon: null,
    discount: function () { return Cart.coupon ? Math.min(Cart.coupon.discount, Cart.subtotal()) : 0; },
    save: function () { Cart.coupon = null; store.set('asingh.cart.v1', Cart.items); store.set('asingh.wish.v1', Cart.wish); subs.forEach(function (f) { f(); }); },
    subscribe: function (f) { subs.push(f); f(); },
    unit: function (it) { var p = byId[it.id]; return p.price + (stitchById[it.stitch] ? stitchById[it.stitch].add : 0); },
    count: function () { return Cart.items.reduce(function (a, i) { return a + i.qty; }, 0); },
    subtotal: function () { return Cart.items.reduce(function (a, i) { return a + Cart.unit(i) * i.qty; }, 0); },
    shipping: function () { var s = Cart.subtotal() - Cart.discount(); return s === 0 || s >= A.FREE_SHIP_FROM ? 0 : A.SHIP_FLAT; },
    total: function () { return Cart.subtotal() - Cart.discount() + Cart.shipping(); },
    add: function (id, o) {
      var key = [id, o.size, o.stitch, o.color || '', o.note || ''].join('|');
      var f = Cart.items.filter(function (i) { return i.key === key; })[0];
      if (f) f.qty = Math.min(9, f.qty + (o.qty || 1)); else Cart.items.push({ key: key, id: id, size: o.size, stitch: o.stitch, color: o.color || '', note: o.note || '', qty: o.qty || 1 });
      Cart.save();
    },
    setQty: function (key, q) { Cart.items.forEach(function (i) { if (i.key === key) i.qty = Math.max(1, Math.min(9, q)); }); Cart.save(); },
    remove: function (key) { Cart.items = Cart.items.filter(function (i) { return i.key !== key; }); Cart.save(); },
    clear: function () { Cart.items = []; Cart.save(); },
    isWish: function (id) { return Cart.wish.indexOf(id) > -1; },
    toggleWish: function (id) { var i = Cart.wish.indexOf(id); if (i > -1) Cart.wish.splice(i, 1); else Cart.wish.push(id); Cart.save(); return i === -1; }
  };

  /* ---------- Toast ---------- */
  var toastTimer;
  function toast(msg, action) {
    var t = $('#toast'); if (!t) return;
    t.innerHTML = '<span>' + esc(msg) + '</span>' + (action ? '<a href="' + action.href + '">' + esc(action.label) + '</a>' : '');
    t.classList.add('is-on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.classList.remove('is-on'); }, 4200);
  }

  /* ---------- Sheets (drawers / bottom sheets / full-screen) ---------- */
  var openSheets = [];
  var FOCUSABLE = 'a[href],button:not([disabled]),input:not([disabled]):not([type=hidden]),select,textarea,[tabindex]:not([tabindex="-1"])';
  function setBackground(inert) {
    var pg = $('#page'); if (!pg) return;
    Array.prototype.forEach.call(pg.children, function (el) {
      var holds = openSheets.some(function (s) { return el.contains(s); });
      if (inert && !holds) el.setAttribute('inert', ''); else el.removeAttribute('inert');
    });
    document.documentElement.classList.toggle('scroll-lock', inert);
  }
  var Sheet = {
    open: function (id, trigger) {
      var el = document.getElementById(id); if (!el || el.classList.contains('is-open')) return;
      el._trigger = trigger || document.activeElement;
      el.classList.add('is-open'); el.removeAttribute('aria-hidden');
      el.setAttribute('role', 'dialog'); el.setAttribute('aria-modal', 'true');
      openSheets.push(el); setBackground(true);
      if (trigger && trigger.setAttribute) trigger.setAttribute('aria-expanded', 'true');
      var focus = $('[data-autofocus]', el) || $(FOCUSABLE, el);
      setTimeout(function () { if (focus) focus.focus({ preventScroll: true }); }, 30);
      document.dispatchEvent(new CustomEvent('sheetopen', { detail: id }));
    },
    close: function (id) {
      var el = typeof id === 'string' ? document.getElementById(id) : id; if (!el || !el.classList.contains('is-open')) return;
      el.classList.remove('is-open'); el.setAttribute('aria-hidden', 'true'); el.removeAttribute('aria-modal');
      openSheets = openSheets.filter(function (s) { return s !== el; });
      if (!openSheets.length) setBackground(false);
      var t = el._trigger; if (t && t.setAttribute) t.setAttribute('aria-expanded', 'false');
      if (t && t.focus && document.contains(t)) t.focus({ preventScroll: true });
      document.dispatchEvent(new CustomEvent('sheetclose', { detail: el.id }));
    },
    closeAll: function () { openSheets.slice().forEach(function (s) { Sheet.close(s); }); }
  };
  document.addEventListener('keydown', function (e) {
    var top = openSheets[openSheets.length - 1]; if (!top) return;
    if (e.key === 'Escape') { Sheet.close(top); return; }
    if (e.key === 'Tab') {
      var f = $$(FOCUSABLE, top).filter(function (n) { return n.offsetParent !== null; });
      if (!f.length) return;
      var first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });
  document.addEventListener('click', function (e) {
    var o = e.target.closest('[data-open]');
    if (o) { e.preventDefault(); Sheet.open(o.getAttribute('data-open'), o); return; }
    var c = e.target.closest('[data-close]');
    if (c) { e.preventDefault(); var s = c.closest('.sheet'); if (s) Sheet.close(s); }
  });

  /* ---------- Shared building blocks ---------- */
  function stars(r) {
    var pct = Math.round(r / 5 * 100);
    return '<span class="stars" role="img" aria-label="Rated ' + r + ' out of 5"><span class="stars__bg" aria-hidden="true">★★★★★</span><span class="stars__fg" aria-hidden="true" style="width:' + pct + '%">★★★★★</span></span>';
  }
  function priceHTML(p, extra) {
    return '<p class="price"><span class="price__now">' + money(p.price + (extra || 0)) + '</span>' +
      (p.was ? ' <s class="price__was"><span class="vh">Was </span>' + money(p.was) + '</s> <span class="price__off">' + Math.round((1 - p.price / p.was) * 100) + '% off</span>' : '') + '</p>';
  }
  function card(p, o) {
    o = o || {};
    var wish = Cart.isWish(p.id);
    return '<article class="card" data-id="' + p.id + '">' +
      '<div class="card__media"><a class="card__link" href="product.html?id=' + p.id + '" tabindex="-1" aria-hidden="true">' +
      picture(p.id, 1, { sizes: o.sizes || '(min-width:1100px) 22vw, (min-width:700px) 31vw, 48vw', alt: '' }) +
      (p.nimg > 1 ? '<span class="card__alt">' + picture(p.id, 2, { sizes: o.sizes || '(min-width:1100px) 22vw, 31vw', alt: '' }) + '</span>' : '') + '</a>' +
      (p.soldOut ? '<span class="badge badge--soldout">Sold out</span>' : p.badge ? '<span class="badge badge--' + p.badge.toLowerCase().replace(/[^a-z]/g, '') + '">' + esc(p.badge) + '</span>' : '') +
      '<button type="button" class="card__wish icon-btn" data-wish="' + p.id + '" aria-pressed="' + wish + '" aria-label="' + (wish ? 'Remove ' : 'Add ') + esc(p.name) + (wish ? ' from' : ' to') + ' wishlist">' + icon('heart') + '</button>' +
      (p.soldOut ? '' : '<button type="button" class="card__quick btn btn--light" data-quick="' + p.id + '" aria-label="Quick add ' + esc(p.name) + '">' + icon('plus') + '<span>Quick add</span></button>') + '</div>' +
      '<div class="card__body"><h3 class="card__title"><a href="product.html?id=' + p.id + '">' + esc(p.name) + '</a></h3>' +
      '<p class="card__meta">' + esc(p.fabric) + '</p>' + priceHTML(p) + '<p class="card__sw" aria-hidden="true">' + p.colors.map(function (c) { return '<span style="background:' + c.hex + '"></span>'; }).join('') + '</p><span class="vh">Colours: ' + esc(p.colors.map(function (c) { return c.name; }).join(', ')) + '</span>' +
      (p.rating ? '<p class="card__rating">' + stars(p.rating) + ' <span class="card__count">' + p.rating.toFixed(1) + (p.reviews ? ' (' + p.reviews + ')' : '') + '</span></p>' : '') + '</div></article>';
  }
  function sizeRadios(name) {
    return '<div class="chips" role="radiogroup" aria-label="Size">' + A.SIZES.map(function (s) {
      return '<label class="chip"><input type="radio" name="' + name + '" value="' + s + '"><span>' + s + '</span></label>';
    }).join('') + '</div>';
  }
  function stitchRadios(p, name, sel) {
    return '<div class="optlist" role="radiogroup" aria-label="Stitching">' + p.stitch.map(function (id, i) {
      var s = stitchById[id];
      return '<label class="opt"><input type="radio" name="' + name + '" value="' + id + '"' + ((sel ? sel === id : i === 0) ? ' checked' : '') + '>' +
        '<span class="opt__body"><span class="opt__title">' + s.label + '<span class="opt__price">' + (s.add ? '+' + money(s.add) : 'Included') + '</span></span>' +
        '<span class="opt__note">' + s.note + ' · ' + s.eta + '</span></span></label>';
    }).join('') + '</div>';
  }
  function line(it, compact) {
    var p = byId[it.id], s = stitchById[it.stitch], u = Cart.unit(it);
    return '<li class="line" data-key="' + esc(it.key) + '">' +
      '<a class="line__img" href="product.html?id=' + p.id + '" tabindex="-1" aria-hidden="true">' + picture(p.id, 1, { sizes: '96px', alt: '' }) + '</a>' +
      '<div class="line__info"><a class="line__name" href="product.html?id=' + p.id + '">' + esc(p.name) + '</a>' +
      '<p class="line__meta">' + esc(it.color) + (it.color ? ' · ' : '') + 'Size ' + esc(it.size) + ' · ' + esc(s ? s.label : '') + '</p>' +
      (it.note ? '<p class="line__note">“' + esc(it.note) + '”</p>' : '') +
      '<div class="line__row"><div class="qty" role="group" aria-label="Quantity for ' + esc(p.name) + '">' +
      '<button type="button" class="qty__btn" data-qty="-1" aria-label="Decrease quantity">' + icon('minus') + '</button>' +
      '<output class="qty__val" aria-live="polite">' + it.qty + '</output>' +
      '<button type="button" class="qty__btn" data-qty="1" aria-label="Increase quantity">' + icon('plus') + '</button></div>' +
      '<span class="line__price">' + money(u * it.qty) + '</span></div>' +
      '<button type="button" class="link line__remove" data-remove aria-label="Remove ' + esc(p.name) + ' from cart">Remove</button></div></li>';
  }
  function totalsHTML() {
    var sub = Cart.subtotal(), sh = Cart.shipping(), left = A.FREE_SHIP_FROM - sub;
    var dc = Cart.discount();
    return '<dl class="totals"><div><dt>Subtotal</dt><dd>' + money(sub) + '</dd></div>' + (dc ? '<div class="totals__disc"><dt>Discount <small>' + esc(Cart.coupon.code) + '</small></dt><dd>− ' + money(dc) + '</dd></div>' : '') +
      '<div><dt>Shipping</dt><dd>' + (sub === 0 ? '—' : sh ? money(sh) : 'Free') + '</dd></div>' +
      '<div class="totals__total"><dt>Total <small>incl. taxes</small></dt><dd>' + money(sub - dc + sh) + '</dd></div></dl>';
  }
  function shipMeter() {
    var sub = Cart.subtotal(); if (!sub) return '';
    var left = A.FREE_SHIP_FROM - sub, pct = Math.min(100, Math.round(sub / A.FREE_SHIP_FROM * 100));
    return '<div class="meter"><p>' + (left > 0 ? 'Add <strong>' + money(left) + '</strong> more for free shipping' : '<strong>You’ve unlocked free shipping</strong>') + '</p><div class="meter__bar" aria-hidden="true"><span style="width:' + pct + '%"></span></div></div>';
  }
  function emptyCart() {
    return '<div class="empty"><p class="empty__title">Your bag is empty</p><p>Discover handcrafted pieces made to be treasured.</p><a class="btn" href="shop.html">Start shopping</a></div>';
  }

/* ---------- API + accounts ---------- */
  function api(method, url, body) {
    var o = { method: method, credentials: 'same-origin', headers: { 'X-Requested-With': 'asingh' } };
    if (body !== undefined) { o.headers['Content-Type'] = 'application/json'; o.body = JSON.stringify(body); }
    return fetch(url, o).then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { if (!r.ok) { var e = new Error(j.error || 'Something went wrong'); e.status = r.status; throw e; } return j; }); });
  }
  function upload(url, form, onProgress) {   // XHR gives real upload progress
    return new Promise(function (resolve, reject) {
      var x = new XMLHttpRequest(); x.open('POST', url); x.withCredentials = true; x.setRequestHeader('X-Requested-With', 'asingh');
      if (x.upload && onProgress) x.upload.onprogress = function (e) { if (e.lengthComputable) onProgress(e.loaded / e.total); };
      x.onload = function () { var j = {}; try { j = JSON.parse(x.responseText); } catch (e) { /* ignore */ } if (x.status >= 200 && x.status < 300) resolve(j); else { var er = new Error(j.error || 'Upload failed'); er.status = x.status; reject(er); } };
      x.onerror = function () { reject(new Error('Network error — please check your connection and try again.')); };
      x.send(form);
    });
  }
  var Auth = { user: null, waiting: null };
  Auth.refresh = function () { return api('GET', '/api/me').then(function (r) { Auth.user = r.user; Auth.paint(); return r.user; }, function () { Auth.user = null; Auth.paint(); return null; }); };
  Auth.paint = function () {
    var u = Auth.user, a = $('.header__account'); if (!a) return;
    var av = $('.avatar', a); if (av) { av.hidden = !u; av.textContent = u ? ((u.isGuest ? 'G' : (u.name || u.email || '?').trim().charAt(0).toUpperCase()) || '?') : ''; }
    a.setAttribute('aria-label', u ? (u.isGuest ? 'Guest account and orders' : 'Account of ' + (u.name || u.email)) : 'Sign in or create account');
    document.documentElement.classList.toggle('is-auth', !!u);
  };
  Auth.ensure = function () {
    if (Auth.user) return Promise.resolve(Auth.user);
    return new Promise(function (resolve, reject) { Auth.waiting = { resolve: resolve, reject: reject }; Sheet.open('auth'); });
  };
  Auth.done = function (u) { var w = Auth.waiting; Auth.waiting = null; Auth.user = u; Auth.paint(); Sheet.close('auth'); toast(u.isGuest ? 'Continuing as guest' : 'Welcome, ' + (u.name || 'back')); if (w) w.resolve(u); document.dispatchEvent(new CustomEvent('authchange', { detail: u })); };
  Auth.signOut = function () { return api('POST', '/api/auth/logout', {}).then(function () { Auth.user = null; Auth.paint(); document.dispatchEvent(new CustomEvent('authchange', { detail: null })); }); };
  function strength(pw) { var s = 0; if (pw.length >= 8) s++; if (pw.length >= 12) s++; if (/[a-z]/.test(pw) && /[A-Z]/.test(pw)) s++; if (/\d/.test(pw) && /[^\w]/.test(pw) || /\d.*[a-z]|[a-z].*\d/i.test(pw) && pw.length >= 10) s++; return Math.min(4, s); }
  Auth.mount = function (el, o) {
    o = o || {}; var upOnly = !!o.upgradeOnly;
    el.innerHTML = '<div class="authbox">' +
      (upOnly ? '' : '<div class="tabs" role="tablist" aria-label="Sign in or create account"><button type="button" role="tab" id="t-in" aria-selected="true" aria-controls="p-in">Sign in</button><button type="button" role="tab" id="t-up" aria-selected="false" aria-controls="p-up" tabindex="-1">Create account</button></div>') +
      (upOnly ? '' : '<form class="aform" id="p-in" role="tabpanel" aria-labelledby="t-in" novalidate data-auth="in">' +
        '<div class="field"><label class="field__l" for="ai-email">Email</label><input class="input" id="ai-email" name="email" type="email" autocomplete="username" inputmode="email" autocapitalize="off" required></div>' +
        '<div class="field"><label class="field__l" for="ai-pw">Password</label><div class="pw"><input class="input" id="ai-pw" name="password" type="password" autocomplete="current-password" required><button type="button" class="pw__t" aria-label="Show password" data-pw>Show</button></div></div>' +
        '<p class="forgot"><button type="button" class="link" data-forgot>Forgot password?</button></p>' +
        '<button class="btn btn--block btn--lg" type="submit"><span>Sign in</span></button></form>') +
      '<form class="aform" id="p-up" role="tabpanel" aria-labelledby="t-up" novalidate data-auth="up"' + (upOnly ? '' : ' hidden') + '>' +
        (upOnly ? '<p class="aform__lead">Create a free account to keep your orders safe and track them from any device.</p>' : '') +
        '<div class="field"><label class="field__l" for="au-name">Full name</label><input class="input" id="au-name" name="name" autocomplete="name" required></div>' +
        '<div class="field"><label class="field__l" for="au-email">Email</label><input class="input" id="au-email" name="email" type="email" autocomplete="email" inputmode="email" autocapitalize="off" required></div>' +
        '<div class="field"><label class="field__l" for="au-pw">Password <span class="muted">(8+ characters)</span></label><div class="pw"><input class="input" id="au-pw" name="password" type="password" autocomplete="new-password" minlength="8" required><button type="button" class="pw__t" aria-label="Show password" data-pw>Show</button></div><div class="meter-pw" aria-hidden="true"><span></span></div></div>' +
        '<button class="btn btn--block btn--lg" type="submit"><span>Create account</span></button></form>' +
      (o.guest === false ? '' : '<div class="or"><span>or</span></div><button type="button" class="btn btn--ghost btn--block guestbtn" data-guest><span>Continue as guest</span><small>No details needed</small></button>') +
      '<p class="auth__msg" role="alert" aria-live="assertive"></p><p class="auth__fine">' + icon('lock', 'ico--xs') + ' Your details stay private. Only you and the store team can see your orders.</p></div>';
    var msg = $('.auth__msg', el), tabs = $$('[role=tab]', el);
    function show(w) { tabs.forEach(function (t) { var on = t.id === 't-' + w; t.setAttribute('aria-selected', on); t.tabIndex = on ? 0 : -1; }); $$('.aform', el).forEach(function (f) { f.hidden = f.id !== 'p-' + w; }); msg.textContent = ''; var f = $('#p-' + w + ' input', el); if (f && o.focus !== false) f.focus({ preventScroll: true }); }
    tabs.forEach(function (t) { t.addEventListener('click', function () { show(t.id.slice(2)); }); t.addEventListener('keydown', function (e) { if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { var n = tabs[t === tabs[0] ? 1 : 0]; n.click(); n.focus(); } }); });
    $$('[data-pw]', el).forEach(function (b) { b.addEventListener('click', function () { var i = b.previousElementSibling, sh = i.type === 'password'; i.type = sh ? 'text' : 'password'; b.textContent = sh ? 'Hide' : 'Show'; b.setAttribute('aria-label', sh ? 'Hide password' : 'Show password'); }); });
    var up = $('#au-pw', el); if (up) up.addEventListener('input', function () { var m = $('.meter-pw span', el), s = strength(up.value); m.style.width = s * 25 + '%'; m.style.background = ['#c0392b', '#c0392b', '#e8913a', '#c9a227', '#1f6b45'][s]; });
    var fg = $('[data-forgot]', el); if (fg) fg.addEventListener('click', function () {
      var pn = $('#p-in', el), em = $('[name=email]', pn).value;
      pn.innerHTML = '<p class="muted">Enter your email and we’ll send a link to choose a new password.</p><div class="field"><label class="field__l" for="fg-e">Email</label><input class="input" id="fg-e" type="email" autocomplete="email" value="' + esc(em) + '"></div><p class="field__err" id="fg-m" role="status"></p><button class="btn btn--block btn--lg" type="button" id="fg-b"><span>Send reset link</span></button>';
      $('#fg-b', pn).addEventListener('click', function () { var b = this; b.disabled = true; api('POST', '/api/auth/forgot', { email: $('#fg-e', pn).value }).then(function (r) { $('#fg-m', pn).textContent = r.emailEnabled ? 'If an account exists for that email, a reset link is on its way. Check your inbox.' : 'Email isn’t set up for this store yet. Please contact us and we’ll send you a reset link.'; }, function (er) { $('#fg-m', pn).textContent = er.message; b.disabled = false; }); });
    });
    function busy(f, on) { var b = $('[type=submit]', f); b.disabled = on; b.classList.toggle('is-busy', on); }
    $$('.aform', el).forEach(function (f) {
      f.addEventListener('submit', function (e) {
        e.preventDefault(); msg.textContent = ''; var d = {}; new FormData(f).forEach(function (v, k) { d[k] = v; });
        var up = f.getAttribute('data-auth') === 'up'; if (!d.email || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(d.email)) { msg.textContent = 'Enter a valid email address.'; $('[name=email]', f).focus(); return; }
        if (!d.password || (up && d.password.length < 8)) { msg.textContent = up ? 'Password must be at least 8 characters.' : 'Enter your password.'; $('[name=password]', f).focus(); return; }
        busy(f, true); api('POST', up ? '/api/auth/register' : '/api/auth/login', d).then(function (r) { busy(f, false); (o.onDone || Auth.done)(r.user); }, function (er) { busy(f, false); msg.textContent = er.message; });
      });
    });
    var g = $('[data-guest]', el); if (g) g.addEventListener('click', function () { g.disabled = true; api('POST', '/api/auth/guest', {}).then(function (r) { g.disabled = false; (o.onDone || Auth.done)(r.user); }, function (er) { g.disabled = false; msg.textContent = er.message; }); });
    if (o.tab === 'up') show('up');
  };
  document.addEventListener('sheetopen', function (e) { if (e.detail === 'auth') { var m = $('#auth-mount'); if (m && !m.firstChild) Auth.mount(m, {}); else { var f = $('#auth-mount input'); if (f) f.focus({ preventScroll: true }); } } });
  document.addEventListener('sheetclose', function (e) { if (e.detail === 'auth' && Auth.waiting) { Auth.waiting.reject(new Error('cancelled')); Auth.waiting = null; } });
  document.addEventListener('click', function (e) { var a = e.target.closest('[data-account]'); if (a && !Auth.user) { e.preventDefault(); Sheet.close('menu'); setTimeout(function () { Sheet.open('auth', a); }, 60); } });


  /* ---------- Cookie notice + Google Analytics (loads only after "Accept") ---------- */
  (function () {
    var id = A.SITE && A.SITE.ga4Id; if (!id) return;
    var KEY = 'asingh.consent', get = function () { try { return localStorage.getItem(KEY); } catch (e) { return null; } }, set = function (v) { try { localStorage.setItem(KEY, v); } catch (e) {} };
    function loadGA() {
      if (window.__ga) return; window.__ga = 1; window.dataLayer = window.dataLayer || []; window.gtag = function () { window.dataLayer.push(arguments); };
      gtag('js', new Date()); gtag('config', id, { anonymize_ip: true });
      var sc = document.createElement('script'); sc.async = true; sc.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id); document.head.appendChild(sc);
    }
    function banner() {
      var b = document.createElement('div'); b.className = 'consent'; b.setAttribute('role', 'dialog'); b.setAttribute('aria-label', 'Cookie notice');
      b.innerHTML = '<p>We use one essential cookie to keep you signed in. With your OK we also use Google Analytics to learn which pages help shoppers. <a href="privacy-policy.html">Privacy policy</a></p><div class="consent__b"><button type="button" class="btn btn--ghost" data-c="no">Decline</button><button type="button" class="btn" data-c="yes">Accept</button></div>';
      b.addEventListener('click', function (e) { var c = e.target.closest('[data-c]'); if (!c) return; set(c.getAttribute('data-c')); b.remove(); if (c.getAttribute('data-c') === 'yes') loadGA(); });
      document.body.appendChild(b);
    }
    document.addEventListener('click', function (e) { if (e.target.closest('[data-cookie-settings]')) { e.preventDefault(); var o = document.querySelector('.consent'); if (o) o.remove(); try { localStorage.removeItem(KEY); } catch (x) {} window.__ga = window.__ga; banner(); } });
    var v = get(); if (v === 'yes') loadGA(); else if (!v) setTimeout(banner, 1200);
  })();
  /* ---------- Chrome ---------- */
  var shortLabel = function (l) { return l.length > 13 ? l.split(/[\s&]+/)[0] : l; };
  var NAV = [{ label: 'New In', href: 'shop.html?sort=new' }].concat(A.CATEGORIES.slice(0, 4).map(function (c, i) { return { label: shortLabel(c.label), href: 'shop.html?cat=' + c.id, xl: i > 1 }; }), [{ label: 'Custom Stitching', href: 'shop.html?stitch=custom', xl: true }]);
  function footerCols() {
    var pg = A.PAGES || [], link = function (p) { return '<li><a href="' + esc(p.slug) + '.html">' + esc(p.title) + '</a></li>'; };
    var help = pg.filter(function (p) { return p.group === 'help'; }).map(link).join('');
    var legal = pg.filter(function (p) { return p.group === 'legal'; }).map(link).join('');
    return '<details class="footer__col" open><summary>Help</summary><ul>' + help + '<li><a href="track.html">Track your order</a></li><li><a href="#size-guide" data-size-guide>Size guide</a></li>' + (A.SITE && A.SITE.ga4Id ? '<li><a href="#cookies" data-cookie-settings>Cookie settings</a></li>' : '') + '</ul></details>' +
      (legal ? '<details class="footer__col" open><summary>Policies</summary><ul>' + legal + '</ul></details>' : '');
  }
  function contactItems() {
    var t = A.SITE || {}, out = '';
    if (t.contactEmail) out += '<li><a href="mailto:' + esc(t.contactEmail) + '">' + esc(t.contactEmail) + '</a></li>';
    if (t.contactPhone) out += '<li><a href="tel:' + esc(String(t.contactPhone).replace(/[^\d+]/g, '')) + '">' + esc(t.contactPhone) + '</a></li>';
    if (t.contactHours) out += '<li>' + esc(t.contactHours) + '</li>';
    if (t.contactAddress) out += '<li>' + esc(t.contactAddress) + '</li>';
    return out || '<li><a href="track.html">Track your order</a></li>';
  }
  function buildChrome() {
    var page = document.body.getAttribute('data-page');
    var sprite = '';
    var header = '<a class="skip" href="#main">Skip to content</a>' +
      '<p class="announce"><span>' + (A.FREE_SHIP_FROM ? 'Free shipping over ' + money(A.FREE_SHIP_FROM) : 'Free shipping on all orders') + '</span>' + ((A.SITE && A.SITE.announcement) ? '<span class="announce__sep" aria-hidden="true">·</span><span class="announce__opt">' + esc(A.SITE.announcement) + '</span>' : '') + '<span class="announce__sep" aria-hidden="true">·</span><a class="announce__track" href="track.html">Track your order</a><button type="button" class="themebtn" data-theme-toggle aria-label="Change theme"><span class="themebtn__dot" aria-hidden="true"></span><span class="themebtn__t"></span></button></p>' +
      '<header class="header" id="site-header"><div class="header__bar container">' +
      '<a class="logo" href="index.html" aria-label="' + A.BRAND + ' home">' + A.BRAND + '</a>' +
      '<nav class="nav" aria-label="Primary"><ul class="nav__list">' +
      '<li class="nav__item nav__item--mega"><button type="button" class="nav__link nav__trigger" aria-expanded="false" aria-controls="mega">Shop ' + icon('chev', 'ico--xs') + '</button></li>' +
      NAV.map(function (n) { return '<li class="nav__item' + (n.xl ? ' nav__item--xl' : '') + '"><a class="nav__link" href="' + n.href + '">' + n.label + '</a></li>'; }).join('') +
      '</ul></nav>' +
      '<div class="header__actions">' +
      '<button type="button" class="searchpill" data-open="search" aria-label="Search" aria-expanded="false" aria-controls="search">' + icon('search') + '<span class="searchpill__t">Search suits…</span></button>' +
      '<a class="icon-btn header__account" href="account.html" data-account aria-label="Account">' + icon('user') + '<span class="avatar" hidden></span></a>' +
      '<a class="icon-btn header__wish" href="shop.html?wishlist=1" aria-label="Wishlist"><span class="icon-btn__ico">' + icon('heart') + '<span class="count" data-wish-count hidden>0</span></span></a>' +
      '<button type="button" class="icon-btn header__cart" data-open="cart" aria-label="Open cart" aria-expanded="false" aria-controls="cart"><span class="icon-btn__ico">' + icon('bag') + '<span class="count" data-cart-count hidden>0</span></span></button>' +
      '<button type="button" class="icon-btn header__menu" data-open="menu" aria-label="Open menu" aria-expanded="false" aria-controls="menu">' + icon('menu') + '</button>' +
      '</div></div>' +
      '<span class="sp" aria-hidden="true"></span><div class="mega" id="mega" hidden><div class="container mega__in">' +
      '<div class="mega__cats"><h2 class="mega__h">Shop by style</h2><ul>' + A.CATEGORIES.map(function (c) { return '<li><a href="shop.html?cat=' + c.id + '">' + c.label + '</a></li>'; }).join('') + '<li><a class="mega__all" href="shop.html">View all</a></li></ul></div>' +
      '<div><h2 class="mega__h">Occasion</h2><ul>' + A.OCCASIONS.map(function (c) { return '<li><a href="shop.html?occ=' + c.id + '">' + c.label + '</a></li>'; }).join('') + '</ul></div>' +
      '<div><h2 class="mega__h">Stitching</h2><ul>' + A.STITCH.map(function (c) { return '<li><a href="shop.html?stitch=' + c.id + '">' + c.label + '</a></li>'; }).join('') + '</ul></div>' +
      '<a class="mega__feature" href="product.html?id=rani-sa-anarkali">' + picture('rani-sa-anarkali', 1, { sizes: '(min-width:1100px) 22vw, 0px', alt: '' }) + '<span class="mega__cap"><small>Bestseller</small>Rani Pink Anarkali Suit</span></a>' +
      '</div></div></header>';
    var footer = '<footer class="footer"><div class="container footer__in">' +
      '<div class="footer__brand"><a class="logo" href="index.html">' + A.BRAND + '</a><p>Girls’ suits &amp; ethnic wear — anarkali, lehenga choli, sharara, kurti sets and more — made to your measure.</p>' +
      '<form class="newsletter" action="#" data-newsletter novalidate><div class="hp" aria-hidden="true"><label>Website <input name="website" tabindex="-1" autocomplete="off"></label></div><label for="nl-email" class="vh">Email address</label><input id="nl-email" type="email" name="email" inputmode="email" autocomplete="email" placeholder="Your email address" required><button class="btn" type="submit">Subscribe</button><p class="newsletter__msg" role="status" aria-live="polite"></p></form></div>' +
      '<details class="footer__col" open><summary>Shop</summary><ul>' + A.CATEGORIES.map(function (c) { return '<li><a href="shop.html?cat=' + c.id + '">' + c.label + '</a></li>'; }).join('') + '</ul></details>' +
      footerCols() +
      '<details class="footer__col" open><summary>Contact</summary><ul>' + contactItems() + '</ul></details>' +
      '</div><p class="footer__legal container">© ' + new Date().getFullYear() + ' ' + A.BRAND + '. All rights reserved.</p></footer>';
    var sheets =
      '<div class="sheet sheet--menu" id="menu" aria-hidden="true"><div class="sheet__backdrop" data-close></div><div class="sheet__panel" aria-label="Menu">' +
      '<div class="sheet__head"><a class="logo" href="index.html">' + A.BRAND + '</a><button type="button" class="icon-btn" data-close aria-label="Close menu">' + icon('close') + '</button></div>' +
      '<div class="sheet__body"><button type="button" class="searchpill searchpill--wide" data-open="search" aria-label="Search">' + icon('search') + '<span>Search suits…</span></button>' +
      '<ul class="menu"><li><a href="shop.html">Shop all</a></li><li><a href="shop.html?sort=new">New in</a></li>' +
      A.CATEGORIES.map(function (c) { return '<li><a href="shop.html?cat=' + c.id + '">' + c.label + '</a></li>'; }).join('') + '</ul>' +
      '<h2 class="menu__h">Theme</h2><div class="themepick" role="group" aria-label="Theme"><button type="button" data-theme-set="royal"><i class="tsw tsw--royal"></i>Royal</button><button type="button" data-theme-set="bloom"><i class="tsw tsw--bloom"></i>Bloom</button></div>' +
      '<h2 class="menu__h">Shop by occasion</h2><ul class="pills">' + A.OCCASIONS.map(function (c) { return '<li><a href="shop.html?occ=' + c.id + '">' + c.label + '</a></li>'; }).join('') + '</ul>' +
      '<ul class="menu menu--sub"><li><a href="track.html">Track your order</a></li><li><a href="shop.html?stitch=custom">Custom stitching</a></li><li><a href="shop.html?wishlist=1">Wishlist</a></li><li><a href="account.html" data-account>Account &amp; orders</a></li></ul></div></div></div>' +
      '<div class="sheet sheet--search" id="search" aria-hidden="true"><div class="sheet__backdrop" data-close></div><div class="sheet__panel" aria-label="Search">' +
      '<form class="searchform" action="shop.html" role="search"><label class="vh" for="q">Search products</label>' + icon('search') +
      '<input id="q" name="q" type="search" inputmode="search" enterkeyhint="search" autocomplete="off" placeholder="Search poshak, ghagra, bandhani…" data-autofocus>' +
      '<button type="button" class="icon-btn" data-close aria-label="Close search">' + icon('close') + '</button></form>' +
      '<div class="sheet__body" id="search-out" aria-live="polite"></div></div></div>' +
      '<div class="sheet sheet--cart" id="cart" aria-hidden="true"><div class="sheet__backdrop" data-close></div><div class="sheet__panel" aria-label="Shopping bag">' +
      '<div class="sheet__head"><h2 class="sheet__title">Your bag <span data-cart-count-text></span></h2><button type="button" class="icon-btn" data-close aria-label="Close cart">' + icon('close') + '</button></div>' +
      '<div class="sheet__body" id="cart-body"></div><div class="sheet__foot" id="cart-foot"></div></div></div>' +
      '<div class="sheet sheet--quick" id="quick" aria-hidden="true"><div class="sheet__backdrop" data-close></div><div class="sheet__panel" aria-label="Quick add">' +
      '<div class="sheet__head"><h2 class="sheet__title" id="quick-title">Quick add</h2><button type="button" class="icon-btn" data-close aria-label="Close">' + icon('close') + '</button></div>' +
      '<form class="sheet__body" id="quick-form" novalidate></form></div></div>' +
      '<div class="sheet sheet--size" id="size-guide" aria-hidden="true"><div class="sheet__backdrop" data-close></div><div class="sheet__panel" aria-label="Size guide">' +
      '<div class="sheet__head"><h2 class="sheet__title">Size guide</h2><button type="button" class="icon-btn" data-close aria-label="Close">' + icon('close') + '</button></div>' +
      '<div class="sheet__body"><p>Measurements are in inches, taken on the body. Between sizes? Choose custom stitching and we’ll make it to your measurements.</p>' +
      '<div class="tablewrap" tabindex="0" role="region" aria-label="Size chart"><table class="sizes"><thead><tr><th scope="col">Size</th><th scope="col">Bust</th><th scope="col">Waist</th><th scope="col">Hip</th></tr></thead><tbody>' +
      (A.SIZECHART || []).map(function (r) { return '<tr><th scope="row">' + esc(r.size) + '</th><td>' + esc(r.bust) + '</td><td>' + esc(r.waist) + '</td><td>' + esc(r.hip) + '</td></tr>'; }).join('') +
      '</tbody></table></div></div></div></div>' +
 '<div class="sheet sheet--quick sheet--auth" id="auth" aria-hidden="true"><div class="sheet__backdrop" data-close></div><div class="sheet__panel" aria-label="Sign in">' +
      '<div class="sheet__head"><h2 class="sheet__title">Welcome to ' + A.BRAND + '</h2><button type="button" class="icon-btn" data-close aria-label="Close">' + icon('close') + '</button></div>' +
      '<div class="sheet__body" id="auth-mount"></div></div></div>' +
      '<button type="button" class="totop" id="totop" aria-label="Back to top">' + icon('chev') + '</button><div class="toast" id="toast" role="status" aria-live="polite"></div>';
    var pg = $('#page');
    pg.insertAdjacentHTML('afterbegin', header);
    var sk = $('.skip'); if (sk) sk.addEventListener('click', function (ev) { ev.preventDefault(); var m = $('#main'); if (m) { m.setAttribute('tabindex', '-1'); m.focus(); m.scrollIntoView(); } });
    pg.insertAdjacentHTML('beforeend', footer);
    pg.insertAdjacentHTML('afterend', sheets);
    // Footer accordions: open on larger screens, collapsed on small ones.
    var syncFooter = function () { $$('.footer__col').forEach(function (d) { if (mqSmall.matches) d.removeAttribute('open'); else d.setAttribute('open', ''); }); };
    syncFooter(); (mqSmall.addEventListener ? mqSmall.addEventListener('change', syncFooter) : mqSmall.addListener(syncFooter));
    // Mark current nav item
    $$('.nav__link[href]').forEach(function (a) { if (a.getAttribute('href') === location.pathname.split('/').pop() + location.search) a.setAttribute('aria-current', 'page'); });
    if (page === 'cart' || page === 'checkout') document.documentElement.classList.add('has-' + page);
  }

  function bindMega() {
    var trig = $('.nav__trigger'), mega = $('#mega'), hdr = $('#site-header'), t;
    if (!trig) return;
    var set = function (on) { mega.hidden = !on; trig.setAttribute('aria-expanded', String(on)); };
    trig.addEventListener('click', function () { set(mega.hidden); });
    trig.parentNode.addEventListener('mouseenter', function () { if (mqDesktop.matches && window.matchMedia('(hover:hover)').matches) { clearTimeout(t); set(true); } });
    hdr.addEventListener('mouseleave', function () { t = setTimeout(function () { set(false); }, 160); });
    hdr.addEventListener('mouseenter', function () { clearTimeout(t); });
    hdr.addEventListener('focusout', function (e) { if (!hdr.contains(e.relatedTarget)) set(false); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && !mega.hidden) { set(false); trig.focus(); } });
  }

  function bindSearch() {
    var q = $('#q'), out = $('#search-out');
    var popular = ['Bridal poshak', 'Bandhani', 'Leheriya', 'Gota patti'];
    function idle() {
      out.innerHTML = '<h2 class="menu__h">Popular searches</h2><ul class="pills">' + popular.map(function (s) { return '<li><a href="shop.html?q=' + encodeURIComponent(s) + '">' + s + '</a></li>'; }).join('') + '</ul>';
    }
    function run() {
      var v = q.value.trim().toLowerCase(); if (!v) { idle(); return; }
      var r = A.search(v).slice(0, 6);
      out.innerHTML = r.length ? '<ul class="results">' + r.map(function (p) {
        return '<li><a class="result" href="product.html?id=' + p.id + '"><span class="result__img">' + picture(p.id, 1, { sizes: '72px', alt: '' }) + '</span><span class="result__t"><strong>' + esc(p.name) + '</strong><span>' + esc(p.fabric) + ' · ' + money(p.price) + '</span></span></a></li>';
      }).join('') + '</ul><a class="btn btn--ghost result__all" href="shop.html?q=' + encodeURIComponent(v) + '">See all results</a>' : '<p class="empty__sub">No matches for “' + esc(q.value.trim()) + '”. Try “poshak” or “bandhani”.</p>';
    }
    A.search = function (v) {
      var words = v.toLowerCase().split(/\s+/).filter(Boolean);
      return A.PRODUCTS.filter(function (p) {
        var hay = [p.name, p.fabric, p.cat, p.occ.join(' '), p.colors.map(function (c) { return c.name; }).join(' ')].join(' ').toLowerCase();
        return words.every(function (w) { w = ({ lehnga: 'lehenga', ghagra: 'ghagra', salwar: 'suit', churidar: 'suit', kurta: 'suit', dupatta: 'dupatta', anarkali: 'anarkali', gotapatti: 'gota' })[w] || w; return hay.indexOf(w.replace(/s$/, '')) > -1; });
      });
    };
    q.addEventListener('input', run); idle();
    document.addEventListener('sheetopen', function (e) { if (e.detail === 'search') { q.select(); } if (e.detail !== 'search' && e.detail !== 'menu') return; });
    // Opening search from the menu should replace the menu.
    document.addEventListener('click', function (e) { var b = e.target.closest('.sheet--menu [data-open="search"]'); if (b) Sheet.close('menu'); }, true);
  }

  var bumpPrev = Cart.count();
  function bindCartUI() {
    var body = $('#cart-body'), foot = $('#cart-foot');
    function render() {
      var n = Cart.count();
      $$('[data-cart-count]').forEach(function (c) { c.textContent = n > 9 ? '9+' : n; c.hidden = !n; if (n > bumpPrev) { c.classList.remove('bump'); void c.offsetWidth; c.classList.add('bump'); } });
      bumpPrev = n;
      $$('[data-wish-count]').forEach(function (c) { c.textContent = Cart.wish.length; c.hidden = !Cart.wish.length; });
      var ct = $('[data-cart-count-text]'); if (ct) ct.textContent = n ? '(' + n + ')' : '';
      var cb = $('.header__cart'); if (cb) cb.setAttribute('aria-label', 'Open cart, ' + n + ' item' + (n === 1 ? '' : 's'));
      if (!body) return;
      if (!Cart.items.length) { body.innerHTML = emptyCart(); foot.innerHTML = ''; return; }
      body.innerHTML = shipMeter() + '<ul class="lines">' + Cart.items.map(function (i) { return line(i); }).join('') + '</ul>';
      foot.innerHTML = totalsHTML() + '<a class="btn btn--block btn--lg" href="checkout.html">Checkout · ' + money(Cart.total()) + '</a><a class="link link--center" href="cart.html">View full cart</a>';
    }
    Cart.subscribe(render);
    document.addEventListener('click', function (e) {
      var li = e.target.closest('.line'), b;
      if (li && (b = e.target.closest('[data-qty]'))) { var it = Cart.items.filter(function (i) { return i.key === li.getAttribute('data-key'); })[0]; if (it) Cart.setQty(it.key, it.qty + parseInt(b.getAttribute('data-qty'), 10)); }
      if (li && e.target.closest('[data-remove]')) { Cart.remove(li.getAttribute('data-key')); toast('Removed from your bag'); }
      var w = e.target.closest('[data-wish]');
      if (w) { var id = w.getAttribute('data-wish'), on = Cart.toggleWish(id); $$('[data-wish="' + id + '"]').forEach(function (x) { x.classList.remove('pop'); void x.offsetWidth; if (on) x.classList.add('pop'); x.setAttribute('aria-pressed', on); x.setAttribute('aria-label', (on ? 'Remove ' : 'Add ') + byId[id].name + (on ? ' from' : ' to') + ' wishlist'); }); toast(on ? 'Saved to wishlist' : 'Removed from wishlist', on ? { href: 'shop.html?wishlist=1', label: 'View' } : null); if (A.onWishChange) A.onWishChange(); }
      var sg = e.target.closest('[data-size-guide]'); if (sg) { e.preventDefault(); Sheet.open('size-guide', sg); }
    });
  }

  function bindQuick() {
    var form = $('#quick-form');
    document.addEventListener('click', function (e) {
      var b = e.target.closest('[data-quick]'); if (!b) return;
      var p = byId[b.getAttribute('data-quick')];
      $('#quick-title').textContent = p.name;
      form.setAttribute('data-id', p.id);
      form.innerHTML = '<div class="quick__top"><div class="quick__img">' + picture(p.id, 1, { sizes: '96px', alt: '' }) + '</div><div>' + priceHTML(p) + '<p class="card__meta">' + esc(p.fabric) + '</p><a class="link" href="product.html?id=' + p.id + '">Full details</a></div></div>' +
        '<fieldset class="field"><legend class="field__l">Size <button type="button" class="link" data-size-guide>Size guide</button></legend>' + sizeRadios('qsize') + '<p class="field__err" role="alert" hidden>Please choose a size.</p></fieldset>' +
        '<fieldset class="field"><legend class="field__l">Stitching</legend>' + stitchRadios(p, 'qstitch') + '</fieldset>' +
        '<div class="sheet__foot sheet__foot--in"><button class="btn btn--block btn--lg" type="submit">Add to bag · <span data-qprice>' + money(p.price) + '</span></button></div>';
      Sheet.open('quick', b);
    });
    form.addEventListener('change', function () {
      var p = byId[form.getAttribute('data-id')], s = form.querySelector('[name=qstitch]:checked');
      var el = form.querySelector('[data-qprice]'); if (el && s) el.textContent = money(p.price + stitchById[s.value].add);
    });
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var size = form.querySelector('[name=qsize]:checked'), err = form.querySelector('.field__err');
      if (!size) { err.hidden = false; form.querySelector('[name=qsize]').focus(); return; }
      var p = byId[form.getAttribute('data-id')];
      Cart.add(p.id, { size: size.value, stitch: form.querySelector('[name=qstitch]:checked').value, color: p.colors[0].name });
      U_fly(form.querySelector('[type=submit]')); Sheet.close('quick'); afterAdd();
    });
  }
  function U_fly(el) { A.U.fly(el); }
  function afterAdd() {
    if (mqSmall.matches) toast('Added to your bag', { href: 'cart.html', label: 'View bag' });
    else setTimeout(function () { Sheet.open('cart', $('.header__cart')); }, 60);
  }

  function bindNewsletter() {
    document.addEventListener('submit', function (e) {
      var f = e.target.closest('[data-newsletter]'); if (!f) return; e.preventDefault();
      var i = f.querySelector('input[type=email]'), m = f.querySelector('.newsletter__msg'), b = f.querySelector('button');
      var hp = f.querySelector('[name=website]');
      if (!i.checkValidity() || !i.value.trim()) { m.textContent = 'Please enter a valid email address.'; i.setAttribute('aria-invalid', 'true'); i.focus(); return; }
      i.removeAttribute('aria-invalid'); b.disabled = true; m.textContent = '';
      api('POST', '/api/newsletter', { email: i.value, website: hp ? hp.value : '', source: 'footer' }).then(function (r) { b.disabled = false; m.textContent = r.already ? 'You’re already on our list — thank you!' : 'Thank you — you’re on the list.'; f.reset(); }, function (er) { b.disabled = false; m.textContent = er.message; });
    });
  }

  // Header: hide on scroll-down for small screens to reclaim space, show on scroll-up.
  function bindHeader() {
    var h = $('#site-header'), last = window.scrollY, ticking = false;
    window.addEventListener('scroll', function () {
      if (ticking) return; ticking = true;
      requestAnimationFrame(function () {
        var y = window.scrollY, dy = y - last;
        h.classList.toggle('is-stuck', y > 8);
        var max = document.documentElement.scrollHeight - innerHeight; h.style.setProperty('--sp', max > 0 ? Math.min(1, y / max).toFixed(4) : 0);
        var tt = $('#totop'); if (tt) tt.classList.toggle('is-on', y > innerHeight * 1.2);
        if (Math.abs(dy) > 8) { h.classList.toggle('is-hidden', dy > 0 && y > 240 && !reduceMotion.matches && window.matchMedia('(max-width: 899.98px)').matches); last = y; }
        ticking = false;
      });
    }, { passive: true });
    h.addEventListener('focusin', function () { h.classList.remove('is-hidden'); });
  }

  function bindFX() {
    var tt = $('#totop'); if (tt) tt.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: reduceMotion.matches ? 'auto' : 'smooth' }); });
    // Pause ambient animations (hero ornaments, marquee) while off-screen to save battery.
    if ('IntersectionObserver' in window) {
      var pio = new IntersectionObserver(function (en) { en.forEach(function (e) { e.target.classList.toggle('is-off', !e.isIntersecting); }); });
      $$('[data-anim]').forEach(function (el) { pio.observe(el); });
    }
    if (reduceMotion.matches || !window.matchMedia('(hover:hover) and (pointer:fine)').matches) return;
    // Cursor spotlight on tiles/cards and gentle parallax on the hero art (desktop pointers only).
    var raf = 0, ev;
    document.addEventListener('pointermove', function (e) {
      ev = e; if (raf) return;
      raf = requestAnimationFrame(function () {
        raf = 0; var t = ev.target.closest && ev.target.closest('.tile,.step,.occ,.quote,.card__media');
        if (t) { var r = t.getBoundingClientRect(); t.style.setProperty('--mx', ((ev.clientX - r.left) / r.width * 100).toFixed(1) + '%'); t.style.setProperty('--my', ((ev.clientY - r.top) / r.height * 100).toFixed(1) + '%'); }
        var hero = $('.hero'); if (hero && ev.clientY < hero.getBoundingClientRect().bottom) { hero.style.setProperty('--px', ((ev.clientX / innerWidth - .5) * -22).toFixed(1) + 'px'); hero.style.setProperty('--py', ((ev.clientY / innerHeight - .5) * -14).toFixed(1) + 'px'); }
      });
    }, { passive: true });
  }

  // Horizontal rails (swipe on touch; arrow buttons on pointer devices)
  function bindRails(root) {
    $$('[data-rail]', root).forEach(function (r) {
      if (r._bound) return; r._bound = true;
      var track = $('.rail__track', r), prev = $('.rail__btn--prev', r), next = $('.rail__btn--next', r);
      if (!track) return;
      var upd = function () { if (!prev) return; prev.disabled = track.scrollLeft < 4; next.disabled = track.scrollLeft + track.clientWidth >= track.scrollWidth - 4; };
      var go = function (d) { track.scrollBy({ left: d * track.clientWidth * 0.85, behavior: reduceMotion.matches ? 'auto' : 'smooth' }); };
      if (prev) { prev.addEventListener('click', function () { go(-1); }); next.addEventListener('click', function () { go(1); }); }
      track.addEventListener('scroll', function () { requestAnimationFrame(upd); }, { passive: true }); window.addEventListener('resize', upd); upd();
    });
  }

  /* Scroll reveal: one shared IntersectionObserver; content stays visible without JS / with reduced motion. */
  var io = null;
  if ('IntersectionObserver' in window && !reduceMotion.matches) {
    document.documentElement.classList.add('reveal-on');
    io = new IntersectionObserver(function (en) { en.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); } }); }, { threshold: 0.08, rootMargin: '0px 0px -4% 0px' });
  }
  function reveal(root) {
    if (!io) return;
    $$('.card,.tile,.occs li,.rail__item--quote,.pdp__trust li,.section__head,.review,.step,.story__head,.footer__col,.trust__list li,.summary-card,.pdp__info>*,.reviews__sum,[data-reveal]', root || document).forEach(function (el, i) {
      if (el._rv || el.closest('.sheet')) return; el._rv = 1;
      el.classList.add('rv'); el.style.transitionDelay = (i % 6) * 60 + 'ms'; io.observe(el);
    });
  }
  /* Add-to-bag: a small gold dot flies to the cart icon (Web Animations API, skipped for reduced motion). */
  function fly(from) {
    if (reduceMotion.matches || !from || !from.getBoundingClientRect || !from.animate) return;
    var hdr = $('#site-header'); if (hdr) hdr.classList.remove('is-hidden');
    var to = $('.header__cart'); if (!to) return;
    var a = from.getBoundingClientRect(), b = to.getBoundingClientRect(), d = document.createElement('span');
    d.className = 'fly'; d.style.left = a.left + a.width / 2 - 9 + 'px'; d.style.top = a.top + a.height / 2 - 9 + 'px'; document.body.appendChild(d);
    var an = d.animate([{ transform: 'translate(0,0) scale(1)', opacity: 1 }, { transform: 'translate(' + (b.left + b.width / 2 - a.left - a.width / 2) + 'px,' + (b.top + b.height / 2 - a.top - a.height / 2) + 'px) scale(.35)', opacity: .5 }], { duration: 650, easing: 'cubic-bezier(.45,-.15,.6,.5)' });
    an.onfinish = function () { d.remove(); };
  }
  /* Warm the next page on intent (hover / touch) — cheap and makes navigation feel instant. */
  var warmed = {};
  function warm(e) {
    var a = e.target.closest && e.target.closest('a[href]'); if (!a || a.origin !== location.origin || warmed[a.href] || !/\.html/.test(a.pathname)) return;
    warmed[a.href] = 1; var l = document.createElement('link'); l.rel = 'prefetch'; l.href = a.href; document.head.appendChild(l);
  }
  document.addEventListener('pointerover', warm, { passive: true }); document.addEventListener('touchstart', warm, { passive: true });

  /* ---------- Theme switch (Royal / Bloom) ---------- */
  (function () {
    var T = window.ASINGH_THEME; if (!T) return;
    function paint() { var t = T.get(); $$('.themebtn__t').forEach(function (e) { e.textContent = t === 'bloom' ? 'Royal theme' : 'Bloom theme'; }); $$('[data-theme-set]').forEach(function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-theme-set') === t); }); }
    document.addEventListener('click', function (e) {
      var tg = e.target.closest('[data-theme-toggle]'); if (tg) { T.toggle(tg); return; }
      var st = e.target.closest('[data-theme-set]'); if (st) T.set(st.getAttribute('data-theme-set'), st);
    });
    document.addEventListener('asingh:theme', paint); document.addEventListener('asingh:ready', paint); paint(); setTimeout(paint, 0);
  })();

  A.U = { api: api, upload: upload, Auth: Auth, reveal: reveal, fly: fly, $: $, $$: $$, money: money, esc: esc, picture: picture, icon: icon, stars: stars, priceHTML: priceHTML, card: card, sizeRadios: sizeRadios, stitchRadios: stitchRadios, line: line, totalsHTML: totalsHTML, shipMeter: shipMeter, emptyCart: emptyCart, byId: byId, stitchById: stitchById, Cart: Cart, Sheet: Sheet, toast: toast, afterAdd: afterAdd, bindRails: bindRails, store: store, mqDesktop: mqDesktop, mqSmall: mqSmall, reduceMotion: reduceMotion };

  document.addEventListener('load', function (e) { if (e.target.tagName === 'IMG') e.target.classList.add('ld'); }, true);
  $$('img').forEach(function (i) { if (i.complete && i.naturalWidth) i.classList.add('ld'); });
  buildChrome(); Auth.refresh(); bindMega(); bindSearch(); bindCartUI(); bindQuick(); bindNewsletter(); bindHeader(); bindFX(); bindRails(document); reveal(document);
  document.documentElement.classList.add('js');
  document.dispatchEvent(new Event('asingh:ready'));
})(window.ASINGH);
