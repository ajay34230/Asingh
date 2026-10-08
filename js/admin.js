/* Chandravanshi admin console — standalone (does not load the storefront bundle). */
(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); }, $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var money = function (n) { return '₹' + Number(n || 0).toLocaleString('en-IN'); };
  var when = function (t) { return new Date(t).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }); };
  var ago = function (t) { var s = Math.max(1, Math.round((Date.now() - t) / 1000)); return s < 60 ? s + 's ago' : s < 3600 ? Math.round(s / 60) + 'm ago' : s < 86400 ? Math.round(s / 3600) + 'h ago' : when(t); };
  var LABEL = { awaiting_payment: 'Awaiting payment', payment_review: 'Needs review', payment_rejected: 'Rejected', paid: 'Paid', processing: 'Crafting', shipped: 'Shipped', delivered: 'Delivered', cancelled: 'Cancelled' };
  var TONE = { awaiting_payment: 'warn', payment_review: 'info', payment_rejected: 'bad', paid: 'good', processing: 'good', shipped: 'good', delivered: 'good', cancelled: 'mute' };
  var FULL = { awaiting_payment: 'Awaiting payment', payment_review: 'Payment under review', payment_rejected: 'Payment rejected', paid: 'Payment verified', processing: 'Being crafted', shipped: 'Shipped', delivered: 'Delivered', cancelled: 'Cancelled' };
  var chip = function (s) { return '<span class="chip-s chip-s--' + TONE[s] + '">' + (LABEL[s] || s) + '</span>'; };
  var ICON = { home: '<path d="M4 11 12 4l8 7v9H4z"/>', box: '<path d="M4 8l8-4 8 4v8l-8 4-8-4zM4 8l8 4 8-4M12 12v8"/>', qr: '<path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h3v3h-3zM18 18h2v2h-2z"/>', bell: '<path d="M6 17V11a6 6 0 0 1 12 0v6l1.5 2h-15zM10 21h4"/>', lock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>', out: '<path d="M10 4H5v16h5M15 8l4 4-4 4M19 12H9"/>', close: '<path d="M6 6l12 12M18 6 6 18"/>', check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>', doc: '<path d="M6 3h9l4 4v14H6z"/><path d="M14 3v5h5M9 13h7M9 17h7"/>', mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>', tag: '<path d="M3 12V4h8l9 9-8 8z"/><circle cx="7.5" cy="8.5" r="1.3"/>', layout: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18M9 10v10"/>', users: '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.5 2.7-6 6-6s6 2.5 6 6M16 5.5a3 3 0 0 1 0 5.6M18 14.5c1.9.8 3 2.7 3 5.5"/>', chart: '<path d="M4 20V4M4 20h16M8 16v-5M12 16V8M16 16v-3M20 16V6"/>', gear: '<circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M18.4 5.6l-2.1 2.1M7.7 16.3l-2.1 2.1"/>' };
  var ico = function (n) { return '<svg class="ico" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICON[n] + '</svg>'; };
  function api(method, url, body, form) {
    var o = { method: method, credentials: 'same-origin', headers: { 'X-Requested-With': 'asingh' } };
    if (form) o.body = form; else if (body !== undefined) { o.headers['Content-Type'] = 'application/json'; o.body = JSON.stringify(body); }
    return fetch(url, o).then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { if (!r.ok) { var e = new Error(j.error || 'Request failed'); e.status = r.status; throw e; } return j; }); });
  }
  var app = $('#app'), me = null, es = null, unread = 0, sound = localStorage.getItem('adm.sound') !== '0', ctx = null, state = { view: 'overview', filter: '', q: '' }, titleBase = document.title, flash;
  function toast(msg, tone) { var box = $('#toasts'); while (box.children.length >= 3) box.firstChild.remove(); var t = document.createElement('div'); t.className = 'adm__toast adm__toast--' + (tone || 'ok'); t.textContent = msg; $('#toasts').appendChild(t); setTimeout(function () { t.classList.add('out'); setTimeout(function () { t.remove(); }, 400); }, 3800); }
  function chime() { if (!sound) return; try { ctx = ctx || new (window.AudioContext || window.webkitAudioContext)(); [[880, 0], [1175, .16]].forEach(function (n) { var o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sine'; o.frequency.value = n[0]; o.connect(g); g.connect(ctx.destination); var t = ctx.currentTime + n[1]; g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(.18, t + .02); g.gain.exponentialRampToValueAtTime(.001, t + .35); o.start(t); o.stop(t + .4); }); } catch (e) { /* audio unavailable */ } }

  /* ------------ login ------------ */
  function loginView(msg) {
    app.innerHTML = '<main class="adm__login"><form class="adm__card" id="lf" novalidate><span class="adm__logo">चंद्रवंशी</span><h1>Admin sign in</h1><p class="muted">Only the store owner can see orders and payment details.</p>' +
      '<div class="field"><label class="field__l" for="e">Email</label><input class="input" id="e" type="email" autocomplete="username" inputmode="email" autocapitalize="off" required></div>' +
      '<div class="field"><label class="field__l" for="p">Password</label><input class="input" id="p" type="password" autocomplete="current-password" required></div>' +
      '<p class="field__err" role="alert" id="le">' + esc(msg || '') + '</p><button class="btn btn--block btn--lg" type="submit"><span>Sign in</span></button><p class="adm__fine">' + ico('lock') + ' Sessions are encrypted and expire automatically.</p></form></main>';
    $('#lf').addEventListener('submit', function (e) {
      e.preventDefault(); var b = $('#lf button'); b.disabled = true;
      api('POST', '/api/auth/login', { email: $('#e').value, password: $('#p').value }).then(function (r) {
        if (r.user.role !== 'admin') return api('POST', '/api/auth/logout', {}).then(function () { b.disabled = false; $('#le').textContent = 'This account does not have admin access.'; });
        me = r.user; consoleView();
      }, function (er) { b.disabled = false; $('#le').textContent = er.message; });
    });
  }

  /* ------------ shell ------------ */
  var NAV = [['overview', 'Overview', 'home'], ['orders', 'Orders', 'box'], ['analytics', 'Analytics', 'chart'], ['products', 'Products', 'tag'], ['home', 'Home page', 'layout'], ['pages', 'Pages', 'doc'], ['hindi', 'Hindi (हिन्दी)', 'doc'], ['store', 'Store settings', 'gear'], ['offers', 'Offers', 'tag'], ['reviews', 'Reviews', 'check'], ['customers', 'Customers', 'users'], ['inbox', 'Inbox', 'mail'], ['payment', 'Payment & QR', 'qr'], ['alerts', 'Alerts', 'bell'], ['security', 'Admins & login', 'lock']];
  function consoleView() {
    app.innerHTML = '<div class="adm__shell"><aside class="adm__nav"><a class="adm__brand" href="index.html" title="View storefront">चंद्रवंशी <small>Admin</small></a><nav aria-label="Admin">' + NAV.map(function (n) { return '<a href="#/' + n[0] + '" data-v="' + n[0] + '">' + ico(n[2]) + '<span>' + n[1] + '</span><b class="adm__badge" data-b="' + n[0] + '" hidden></b></a>'; }).join('') + '</nav><button class="adm__out" id="so">' + ico('out') + '<span>Sign out</span></button></aside>' +
      '<div class="adm__main"><header class="adm__top"><h1 id="vt">Overview</h1><div class="adm__tools"><span class="live" id="live" title="Live alerts"><i></i><em>Connecting…</em></span><button class="adm__icon" id="snd" aria-pressed="' + sound + '" aria-label="Alert sound">' + (sound ? '🔔' : '🔕') + '</button><button class="adm__icon adm__bell" id="bell" aria-label="Notifications" aria-expanded="false">' + ico('bell') + '<b class="adm__badge" id="bb" hidden>0</b></button></div></header><main id="view" tabindex="-1"></main></div>' +
      '<nav class="adm__tabs" aria-label="Admin sections">' + NAV.map(function (n) { return '<a href="#/' + n[0] + '" data-v="' + n[0] + '">' + ico(n[2]) + '<span>' + n[1].split(' ')[0] + '</span><b class="adm__badge" data-b="' + n[0] + '" hidden></b></a>'; }).join('') + '</nav>' +
      '<section class="adm__drawer" id="drawer" aria-hidden="true"><div class="adm__scrim" data-x></div><div class="adm__dpanel" role="dialog" aria-modal="true" aria-label="Order details" id="dp"></div></section>' +
      '<section class="adm__pop" id="pop" hidden aria-label="Notifications"></section></div>';
    $('#so').addEventListener('click', function () { api('POST', '/api/auth/logout', {}).then(function () { if (es) es.close(); es = null; loginView(); }); });
    $('#snd').addEventListener('click', function () { sound = !sound; localStorage.setItem('adm.sound', sound ? '1' : '0'); this.textContent = sound ? '🔔' : '🔕'; this.setAttribute('aria-pressed', sound); if (sound) chime(); });
    $('#bell').addEventListener('click', togglePop); $('#drawer').addEventListener('click', function (e) { if (e.target.closest('[data-x]')) closeDrawer(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { closeDrawer(); var p = $('#pop'); if (p && !p.hidden) togglePop(); } });
    window.addEventListener('hashchange', route); connect(); route(); refreshBadges();
  }
  function route() {
    var v = (location.hash.match(/^#\/(\w+)/) || [])[1]; if (!NAV.some(function (n) { return n[0] === v; })) v = 'overview'; state.view = v;
    $$('[data-v]').forEach(function (a) { a.classList.toggle('on', a.getAttribute('data-v') === v); if (a.getAttribute('data-v') === v) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
    $('#vt').textContent = NAV.filter(function (n) { return n[0] === v; })[0][1]; ({ overview: overview, orders: ordersView, payment: paymentView, alerts: alertsView, security: securityView }[v] || ADM.views[v])();
  }
  function refreshBadges() { return api('GET', '/api/admin/summary').then(function (s) { unread = s.unread; var bb = $('#bb'); if (bb) { bb.hidden = !unread; bb.textContent = unread > 9 ? '9+' : unread; } $$('[data-b="inbox"]').forEach(function (b) { b.hidden = !s.unreadMessages; b.textContent = s.unreadMessages; });
      var ob = $$('[data-b="orders"]'); ob.forEach(function (b) { var n = s.counts.payment_review; b.hidden = !n; b.textContent = n; }); document.title = (s.counts.payment_review ? '(' + s.counts.payment_review + ') ' : '') + titleBase; return s; }); }

  /* ------------ live alerts ------------ */
  function connect() {
    if (!window.EventSource) return; es = new EventSource('/api/admin/events');
    es.onopen = function () { var l = $('#live'); if (l) { l.classList.add('on'); $('em', l).textContent = 'Live'; } };
    es.onerror = function () { var l = $('#live'); if (l) { l.classList.remove('on'); $('em', l).textContent = 'Reconnecting…'; } };
    es.addEventListener('notify', function (e) {
      var n = JSON.parse(e.data); chime(); toast(n.title + (n.body ? ' — ' + n.body : ''), 'alert'); var bell = $('#bell'); if (bell) { bell.classList.remove('ring'); void bell.offsetWidth; bell.classList.add('ring'); }
      if (window.Notification && Notification.permission === 'granted' && document.hidden) { try { var no = new Notification(n.title, { body: n.body, tag: n.id }); no.onclick = function () { window.focus(); if (n.orderId) openOrder(n.orderId); }; } catch (x) { /* ignore */ } }
      refreshBadges(); if (state.view === 'overview') overview(true); else if (state.view === 'orders') loadOrders(true); else if (state.view === 'alerts') alertsView(true);
      if (document.hidden) { clearInterval(flash); var on = true; flash = setInterval(function () { document.title = on ? '🔔 ' + n.title : titleBase; on = !on; }, 1000); }
    });
    document.addEventListener('visibilitychange', function () { if (!document.hidden) { clearInterval(flash); refreshBadges(); } });
  }
  function togglePop() {
    var p = $('#pop'), open = p.hidden; p.hidden = !open; $('#bell').setAttribute('aria-expanded', open);
    if (open) api('GET', '/api/admin/notifications').then(function (r) { p.innerHTML = '<header><strong>Notifications</strong><button class="link" id="mr">Mark all read</button></header>' + (r.notifications.length ? '<ul>' + r.notifications.slice(0, 12).map(nItem).join('') + '</ul>' : '<p class="muted pad">Nothing yet. New orders and payment screenshots appear here instantly.</p>');
      $$('[data-o]', p).forEach(function (b) { b.addEventListener('click', function () { togglePop(); openOrder(b.getAttribute('data-o')); }); }); var m = $('#mr', p); if (m) m.addEventListener('click', function () { api('POST', '/api/admin/notifications/read', {}).then(function () { refreshBadges(); togglePop(); }); }); });
  }
  var nItem = function (n) { return '<li class="' + (n.read ? '' : 'unread') + '"><button type="button" ' + (n.orderId ? 'data-o="' + n.orderId + '"' : '') + '><strong>' + esc(n.title) + '</strong><span>' + esc(n.body || '') + '</span><time>' + ago(n.at) + '</time></button></li>'; };

  /* ------------ views ------------ */
  var tokN = 0; function guard() { var t = ++tokN; return function () { return t === tokN; }; }
  function view(html) { var v = $('#view'); v.innerHTML = html; return v; }
  function overview(quiet) {
    var live = guard();
    api('GET', '/api/admin/summary').then(function (s) {
      if (!live()) return;
      var c = s.counts, todo = [!s.upiSet && ['Add your UPI ID', 'payment'], s.qrIsDemo && ['Upload your payment QR', 'payment'], s.demoProducts > 0 && ['Replace the ' + s.demoProducts + ' demo products with yours', 'products'], !s.realProducts && s.demoProducts === 0 && ['Add your first product with photos', 'products'], !s.contactSet && ['Add your email, phone and address (footer, policies, Google)', 'store'], s.unreviewedPages > 0 && ['Review the ' + s.unreviewedPages + ' policy/help pages and save each (they are templates)', 'pages'], !s.https && ['Use your https:// address — payments and Google need it', 'store'], !s.googleSet && ['Optional: verify the site in Google Search Console', 'store']].filter(Boolean);
      var v = view((todo.length ? '<div class="adm__setup"><strong>Finish setup</strong><ul>' + todo.map(function (t) { return '<li><a href="#/' + t[1] + '">' + t[0] + ' →</a></li>'; }).join('') + '</ul><p>Complete these before sharing the link with customers.</p></div>' : '') +
        '<div class="adm__stats"><a class="stat stat--hot" href="#/orders" data-f="payment_review"><span>Needs review</span><strong>' + c.payment_review + '</strong><small>screenshots to verify</small></a><a class="stat" href="#/orders" data-f="awaiting_payment"><span>Awaiting payment</span><strong>' + c.awaiting_payment + '</strong><small>not paid yet</small></a><a class="stat" href="#/orders" data-f="processing"><span>In progress</span><strong>' + (c.paid + c.processing + c.shipped) + '</strong><small>paid → shipping</small></a><div class="stat"><span>Verified revenue</span><strong>' + money(s.revenue) + '</strong><small>' + s.orders + ' orders · ' + s.customers + ' accounts · ' + s.guests + ' guests</small></div></div>' +
        '<h2 class="adm__h">Recent orders</h2><div id="recent" class="adm__list"></div>');
      $$('[data-f]', v).forEach(function (a) { a.addEventListener('click', function () { state.filter = a.getAttribute('data-f'); }); });
      api('GET', '/api/admin/orders').then(function (r) { $('#recent').innerHTML = orderRows(r.orders.slice(0, 6)); bindRows($('#recent')); });
    });
  }
  function orderRows(list) {
    return list.length ? list.map(function (o) { return '<button type="button" class="orow" data-o="' + o.id + '"><span class="orow__img">' + o.items.slice(0, 1).map(function (i) { return '<img src="img/' + i.id + '-1-400.webp" alt="" loading="lazy" width="48" height="60">'; }).join('') + '</span><span class="orow__t"><strong>' + esc(o.number) + '</strong><small>' + esc(o.customer.name) + ' · ' + o.items.length + ' item' + (o.items.length > 1 ? 's' : '') + ' · ' + ago(o.createdAt) + '</small></span>' + chip(o.status) + '<span class="orow__p">' + money(o.totals.total) + '</span></button>'; }).join('') : '<p class="muted pad">No orders match.</p>';
  }
  function bindRows(el) { $$('[data-o]', el).forEach(function (b) { b.addEventListener('click', function () { openOrder(b.getAttribute('data-o')); }); }); }
  function ordersView() {
    guard();
    var chips = [['', 'All']].concat(Object.keys(LABEL).map(function (k) { return [k, LABEL[k]]; }));
    view('<div class="adm__bar"><label class="vh" for="sq">Search orders</label><input class="input" id="sq" type="search" placeholder="Search number, name, phone, UTR…" value="' + esc(state.q) + '"><a class="btn btn--ghost btn--sm" href="/api/admin/orders.csv" download>Export CSV</a></div><div class="fchips" role="group" aria-label="Filter by status">' + chips.map(function (c) { return '<button type="button" data-s="' + c[0] + '" aria-pressed="' + (state.filter === c[0]) + '">' + c[1] + '</button>'; }).join('') + '</div><div id="ol" class="adm__list" aria-live="polite"></div>');
    var t; $('#sq').addEventListener('input', function () { state.q = this.value; clearTimeout(t); t = setTimeout(loadOrders, 220); });
    $$('.fchips button').forEach(function (b) { b.addEventListener('click', function () { state.filter = b.getAttribute('data-s'); $$('.fchips button').forEach(function (x) { x.setAttribute('aria-pressed', x === b); }); loadOrders(); }); });
    loadOrders();
  }
  function loadOrders() { api('GET', '/api/admin/orders?status=' + encodeURIComponent(state.filter) + '&q=' + encodeURIComponent(state.q)).then(function (r) { var l = $('#ol'); if (!l) return; l.innerHTML = orderRows(r.orders); bindRows(l); }); }

  /* ------------ order drawer ------------ */
  var STATUS_MSG = { awaiting_payment: 'is waiting for payment. Please pay by UPI/QR and upload the screenshot on your order page.', payment_review: 'payment screenshot received — we are verifying it.', payment_rejected: 'payment could not be verified. Please upload a clear screenshot.', paid: 'payment is verified. Thank you!', processing: 'is being prepared for you.', shipped: 'has been shipped.', delivered: 'has been delivered. We hope you love it!', cancelled: 'has been cancelled.' };
  function waLink(o) {
    var ph = String(o.customer.phone || '').replace(/\D/g, ''); if (ph.length === 10) ph = '91' + ph;
    var t = o.tracking && o.tracking.id ? ' Courier: ' + (o.tracking.courier || '') + ' ' + o.tracking.id + (o.tracking.url ? ' ' + o.tracking.url : '') + '.' : '';
    return 'https://wa.me/' + ph + '?text=' + encodeURIComponent('Hello ' + o.customer.name + ', your order ' + o.number + ' ' + (STATUS_MSG[o.status] || '') + t);
  }
  function showDrawer(html) { $('#dp').innerHTML = html; var d = $('#drawer'); d.classList.add('open'); d.setAttribute('aria-hidden', 'false'); document.documentElement.classList.add('scroll-lock'); setTimeout(function () { var c = $('#dp [data-x]'); if (c) c.focus(); }, 60); }
  function openOrder(id) {
    api('GET', '/api/orders/' + id).then(function (r) { drawOrder(r.order); var d = $('#drawer'); d.classList.add('open'); d.setAttribute('aria-hidden', 'false'); document.documentElement.classList.add('scroll-lock'); setTimeout(function () { var c = $('#dp [data-x]'); if (c) c.focus(); }, 60); }, function (e) { toast(e.message, 'bad'); });
  }
  function closeDrawer() { var d = $('#drawer'); if (!d) return; d.classList.remove('open'); d.setAttribute('aria-hidden', 'true'); document.documentElement.classList.remove('scroll-lock'); }
  function drawOrder(o) {
    var c = o.customer, p = o.proof, act = '';
    if (o.status === 'payment_review') act = '<button class="btn btn--lg btn--grow" data-a="verify">' + ico('check') + ' Verify payment</button><button class="btn btn--ghost btn--lg" data-a="reject">Reject</button>';
    else if (o.status === 'awaiting_payment' || o.status === 'payment_rejected') act = '<button class="btn btn--ghost btn--grow" data-a="verify">Mark as paid manually</button>';
    var t = o.tracking || {}, opts = [o.status].concat(o.next || []);
    var statusBox = '<section class="adm__status"><h3>Order status</h3><p class="muted">Customers see changes instantly on their order page and on the tracking page (guests use their order number + mobile).</p>' +
      '<div class="field"><label class="field__l" for="ns">Change status</label><select class="input input--select" id="ns">' + opts.map(function (s) { return '<option value="' + s + '"' + (s === o.status ? ' selected' : '') + '>' + FULL[s] + (s === o.status ? ' (current)' : '') + '</option>'; }).join('') + '</select></div>' +
      '<div class="field"><label class="field__l" for="sn">Message to customer <span class="muted">(optional, shown in their progress)</span></label><input class="input" id="sn" maxlength="200" placeholder="e.g. Handed to courier today"></div>' +
      '<details class="adm__trk"' + (o.tracking || o.status === 'shipped' ? ' open' : '') + '><summary>Courier &amp; tracking details</summary><div class="adm__two3"><div class="field"><label class="field__l" for="tc">Courier</label><input class="input" id="tc" maxlength="40" value="' + esc(t.courier || '') + '" placeholder="India Post, DTDC…"></div><div class="field"><label class="field__l" for="ti">Tracking ID</label><input class="input" id="ti" maxlength="60" value="' + esc(t.id || '') + '"></div></div><div class="field"><label class="field__l" for="tu">Tracking link <span class="muted">(https://)</span></label><input class="input" id="tu" type="url" maxlength="300" value="' + esc(t.url || '') + '" placeholder="https://…"></div></details>' +
      '<div class="adm__row"><button class="btn btn--lg btn--grow" id="ss">Save status</button></div></section>';
    var rqs = o.request ? '<section class="adm__act adm__req"><h3>' + ({ cancel: 'Cancellation', return: 'Return', exchange: 'Exchange' })[o.request.type] + ' request · ' + o.request.state + '</h3><p>' + esc(o.request.reason) + '</p>' + (o.request.note ? '<p class="muted">Your reply: ' + esc(o.request.note) + '</p>' : '') + (o.request.state === 'pending' ? '<div class="field"><label class="field__l" for="rn">Reply to customer</label><input class="input" id="rn" maxlength="200" placeholder="e.g. Approved — refund in 3 days"></div><div class="adm__row"><button class="btn btn--grow" data-r="approve">Approve</button><button class="btn btn--ghost" data-r="decline">Decline</button></div>' : '') + '</section>' : '';
    var danger = '<section><h3>Danger zone</h3><button class="btn btn--ghost adm__del" id="delo">Delete this order…</button></section>';
    $('#dp').innerHTML = '<header class="adm__dh"><div><h2>' + esc(o.number) + '</h2><p class="muted">' + when(o.createdAt) + '</p></div>' + chip(o.status) + '<button class="adm__icon" data-x aria-label="Close">' + ico('close') + '</button></header><div class="adm__db">' +
      rqs + (act ? '<div class="adm__act"><div class="field"><label class="field__l" for="nt">Note to customer <span class="muted">(shown on their order)</span></label><input class="input" id="nt" maxlength="200" placeholder="Optional"></div><div class="adm__row">' + act + '</div></div>' : '') +
      '<section><h3>Payment</h3><p class="amt">' + money(o.totals.total) + '<small> · UPI / QR</small></p>' + (p ? '<a class="proof" href="/api/orders/' + o.id + '/proof" target="_blank" rel="noopener"><img src="/api/orders/' + o.id + '/proof?t=' + p.at + '" alt="Customer payment screenshot"><span>Open full size</span></a><p class="muted">Uploaded ' + when(p.at) + (p.utr ? ' · UTR <code>' + esc(p.utr) + '</code>' : '') + '</p>' : '<p class="muted">No screenshot uploaded yet.</p>') + '</section>' +
      '<section><h3>Customer</h3><p><strong>' + esc(c.name) + '</strong><br><a href="tel:' + esc(c.phone) + '">' + esc(c.phone) + '</a> · <a href="mailto:' + esc(c.email) + '">' + esc(c.email) + '</a></p><address>' + esc(c.line1) + (c.line2 ? ', ' + esc(c.line2) : '') + '<br>' + esc(c.city) + ', ' + esc(c.state) + ' ' + esc(c.pin) + '</address></section>' +
      '<section><h3>Items</h3><ul class="oitems">' + o.items.map(function (i) { return '<li><span class="oitems__img"><img src="img/' + i.id + '-1-400.webp" alt="" width="48" height="60"></span><span class="oitems__t"><strong>' + esc(i.name) + '</strong><small>' + esc(i.color) + ' · Size ' + esc(i.size) + ' · ' + esc(i.stitchLabel) + ' · ×' + i.qty + '</small>' + (i.note ? '<small>“' + esc(i.note) + '”</small>' : '') + '</span><span>' + money(i.unit * i.qty) + '</span></li>'; }).join('') + '</ul></section>' +
      statusBox +
      '<section><h3>Bill</h3><div class="adm__row"><a class="btn btn--ghost" href="invoice.html?id=' + o.id + '" target="_blank" rel="noopener">Open bill · Save PDF</a><a class="btn btn--ghost" href="invoice.html?id=' + o.id + '&print=1" target="_blank" rel="noopener">Print</a><a class="btn btn--ghost" href="invoice.html?id=' + o.id + '&slip=1" target="_blank" rel="noopener">Packing slip</a><a class="btn btn--ghost" href="' + esc(waLink(o)) + '" target="_blank" rel="noopener">WhatsApp customer</a></div></section>' +
      '<section><h3>Activity</h3><ol class="log">' + o.timeline.slice().reverse().map(function (t) { return '<li><time>' + when(t.at) + '</time><strong>' + esc(t.label) + '</strong>' + (t.note ? '<span>' + esc(t.note) + '</span>' : '') + '<small>' + esc(t.by) + '</small></li>'; }).join('') + '</ol></section>' + danger + '</div>';
    function go(body, btn) { btn.disabled = true; api('PATCH', '/api/admin/orders/' + o.id, body).then(function (r) { toast('Order updated'); drawOrder(r.order); refreshBadges(); if (state.view === 'orders') loadOrders(); else if (state.view === 'overview') overview(true); }, function (e) { btn.disabled = false; toast(e.message, 'bad'); }); }
    $$('[data-a]', $('#dp')).forEach(function (b) { b.addEventListener('click', function () { var nt = $('#nt') ? $('#nt').value.trim() : ''; if (b.getAttribute('data-a') === 'reject' && !nt && !confirm('Reject without a note? The customer will see a default message.')) return; go({ action: b.getAttribute('data-a'), note: nt }, b); }); });
    $$('[data-r]', $('#dp')).forEach(function (b) { b.addEventListener('click', function () { go({ action: 'request', decision: b.getAttribute('data-r'), note: ($('#rn').value || '').trim() }, b); }); });
    var del = $('#delo'); if (del) del.addEventListener('click', function () { if (!confirm('Permanently delete order ' + o.number + ' and its payment screenshot? This cannot be undone.')) return; api('DELETE', '/api/admin/orders/' + o.id).then(function () { toast('Order deleted'); closeDrawer(); refreshBadges(); if (state.view === 'orders') loadOrders(); else if (state.view === 'overview') overview(true); }, function (e) { toast(e.message, 'bad'); }); });
    var ns = $('#ns'); if (ns) ns.addEventListener('change', function () { if (ns.value === 'shipped') $('.adm__trk').open = true; });
    var ss = $('#ss'); if (ss) ss.addEventListener('click', function () {
      var tr = { courier: $('#tc').value.trim(), id: $('#ti').value.trim(), url: $('#tu').value.trim() }, any = tr.courier || tr.id || tr.url || o.tracking, st = ns.value, note = $('#sn').value.trim();
      if (st === 'cancelled' && !confirm('Cancel this order? The customer will see it as cancelled.')) return;
      if (st === o.status) { if (!any) return toast('Nothing to save — choose a new status or add tracking details.', 'bad'); go({ action: 'tracking', tracking: tr }, ss); }
      else go({ action: 'status', status: st, note: note, tracking: any ? tr : undefined }, ss);
    });
  }

  /* ------------ payment settings ------------ */
  function paymentView() {
    var live = guard();
    api('GET', '/api/admin/settings').then(function (s) {
      if (!live()) return;
      view('<div class="adm__two"><section class="adm__card"><h2>Payment QR</h2><p class="muted">This is the QR customers scan at checkout.</p><figure class="qrcard qrcard--sm"><img id="qrimg" src="' + s.qrUrl + '" alt="Current payment QR" width="320" height="320"><i class="qrcard__c qrcard__c--tl"></i><i class="qrcard__c qrcard__c--tr"></i><i class="qrcard__c qrcard__c--bl"></i><i class="qrcard__c qrcard__c--br"></i></figure>' + (s.qrIsDemo ? '<p class="pay__demo">Showing the demo QR — upload yours.</p>' : '') +
        '<label class="drop" id="qd"><input type="file" id="qf" accept="image/jpeg,image/png,image/webp"><span class="drop__ico" aria-hidden="true">+</span><span class="drop__t"><strong>Upload new QR image</strong><small>PNG, JPG or WebP · up to 3 MB</small></span></label><p class="field__err" id="qe" role="alert"></p>' + (s.qrIsDemo ? '' : '<button class="link" id="qrm">Remove and use demo QR</button>') + '</section>' +
        '<section class="adm__card"><h2>Payee details</h2><form id="pf" novalidate><div class="field"><label class="field__l" for="pn">Payee name</label><input class="input" id="pn" value="' + esc(s.payeeName) + '" maxlength="60"></div><div class="field"><label class="field__l" for="pu">UPI ID</label><input class="input" id="pu" value="' + esc(s.upiId) + '" placeholder="yourname@bank" autocapitalize="off" maxlength="80"><small class="muted">Enables the “Open my UPI app” button with the exact amount filled in.</small></div><div class="field"><label class="field__l" for="pi">Instructions shown to buyers</label><textarea class="input" id="pi" rows="3" maxlength="500">' + esc(s.instructions) + '</textarea></div><p class="field__err" id="pe" role="alert"></p><button class="btn btn--lg" type="submit"><span>Save</span></button></form></section></div>' +
        '<section class="adm__card"><h2>Bill details</h2><p class="muted">Shown at the top of every customer bill (PDF/text).</p><form id="bf" novalidate><div class="adm__two3"><div class="field"><label class="field__l" for="bn">Business name</label><input class="input" id="bn" maxlength="80" value="' + esc((s.invoice || {}).name) + '"></div><div class="field"><label class="field__l" for="bg">GSTIN <span class="muted">(optional)</span></label><input class="input" id="bg" maxlength="15" autocapitalize="characters" value="' + esc((s.invoice || {}).gstin) + '"></div></div><div class="field"><label class="field__l" for="ba">Address</label><textarea class="input" id="ba" rows="2" maxlength="240">' + esc((s.invoice || {}).address) + '</textarea></div><div class="field"><label class="field__l" for="bc">Contact line <span class="muted">(phone · email)</span></label><input class="input" id="bc" maxlength="120" value="' + esc((s.invoice || {}).contact) + '"></div><p class="field__err" id="be" role="alert"></p><button class="btn btn--lg" type="submit"><span>Save bill details</span></button></form></section>' +
        '<section class="adm__card"><h2>Future payment options</h2><p class="muted">Card/UPI gateways confirm payments automatically by calling your store. When you’re ready, set a secret and point the gateway at:</p><pre class="code">POST ' + esc(location.origin) + '/api/webhooks/&lt;provider&gt;\nX-Signature: HMAC-SHA256(secret, raw body)\n{ "orderNumber": "AS261008-1234", "status": "paid", "reference": "txn_123", "amount": 22400 }</pre><p class="muted">Set <code>WEBHOOK_SECRET_GENERIC</code> (or <code>WEBHOOK_SECRET_RAZORPAY</code>) on the server. Verified “paid” events mark the order paid and alert you here — no code changes to the storefront. See the README for adding a provider.</p></section>');
      $('#qf').addEventListener('change', function () { var f = this.files[0]; if (!f) return; var fd = new FormData(); fd.append('file', f); $('#qe').textContent = 'Uploading…'; api('POST', '/api/admin/qr', undefined, fd).then(function (r) { $('#qrimg').src = r.qrUrl; $('#qe').textContent = ''; toast('QR updated'); paymentView(); }, function (e) { $('#qe').textContent = e.message; }); });
      var rm = $('#qrm'); if (rm) rm.addEventListener('click', function () { if (confirm('Remove your QR and show the demo QR?')) api('DELETE', '/api/admin/qr').then(function () { toast('QR removed'); paymentView(); }); });
      $('#bf').addEventListener('submit', function (e) { e.preventDefault(); api('PUT', '/api/admin/settings', { invoice: { name: $('#bn').value, gstin: $('#bg').value, address: $('#ba').value, contact: $('#bc').value } }).then(function () { $('#be').textContent = ''; toast('Bill details saved'); }, function (er) { $('#be').textContent = er.message; }); });
      $('#pf').addEventListener('submit', function (e) { e.preventDefault(); api('PUT', '/api/admin/settings', { payeeName: $('#pn').value, upiId: $('#pu').value, instructions: $('#pi').value }).then(function () { $('#pe').textContent = ''; toast('Saved'); refreshBadges(); }, function (er) { $('#pe').textContent = er.message; }); });
    });
  }
  function alertsView(quiet) {
    var live = guard();
    Promise.all([api('GET', '/api/admin/settings'), api('GET', '/api/admin/notifications')]).then(function (a) {
      if (!live()) return;
      var s = a[0], n = a[1], perm = window.Notification ? Notification.permission : 'unsupported';
      view('<div class="adm__two"><section class="adm__card"><h2>How you’re alerted</h2><ul class="adm__ch"><li><span class="live on"><i></i></span><div><strong>In this console</strong><small>Instant toast, bell and chime whenever a customer places an order or uploads a screenshot.</small></div></li><li><span>🔔</span><div><strong>Browser notifications</strong><small>' + (perm === 'granted' ? 'Enabled — you’ll get desktop/phone alerts when this tab is in the background.' : perm === 'denied' ? 'Blocked in your browser settings.' : 'Get alerts even when this tab is in the background.') + '</small>' + (perm === 'default' ? '<button class="btn btn--ghost" id="np">Enable notifications</button>' : '') + '</div></li><li><span>🔗</span><div><strong>Phone / chat webhook</strong><small>' + (s.envWebhook ? 'Configured by the server (ADMIN_WEBHOOK_URL).' : 'Send alerts to Slack, Discord or any HTTPS endpoint.') + '</small>' + (s.envWebhook ? '' : '<form id="wf"><label class="vh" for="wu">Webhook URL</label><input class="input" id="wu" type="url" placeholder="https://hooks.slack.com/…" value="' + esc(s.webhookUrl) + '"><button class="btn" type="submit"><span>Save</span></button></form><p class="field__err" id="we" role="alert"></p>') + '</div></li></ul><button class="btn btn--ghost" id="ta">Send a test alert</button></section>' +
        '<section class="adm__card"><header class="adm__ch2"><h2>Recent alerts</h2><button class="link" id="mr2">Mark all read</button></header>' + (n.notifications.length ? '<ul class="adm__nl">' + n.notifications.map(nItem).join('') + '</ul>' : '<p class="muted">Nothing yet.</p>') + '</section></div>');
      var np = $('#np'); if (np) np.addEventListener('click', function () { Notification.requestPermission().then(function () { alertsView(); }); });
      $('#ta').addEventListener('click', function () { api('POST', '/api/admin/test-alert', {}); });
      $('#mr2').addEventListener('click', function () { api('POST', '/api/admin/notifications/read', {}).then(function () { refreshBadges(); alertsView(); }); });
      var wf = $('#wf'); if (wf) wf.addEventListener('submit', function (e) { e.preventDefault(); api('PUT', '/api/admin/settings', { webhookUrl: $('#wu').value }).then(function () { $('#we').textContent = ''; toast('Webhook saved'); }, function (er) { $('#we').textContent = er.message; }); });
      $$('[data-o]', $('#view')).forEach(function (b) { b.addEventListener('click', function () { openOrder(b.getAttribute('data-o')); }); });
    });
  }
  function securityView() { ADM.views.security2(); }

  var ADM = window.ADM = { $: $, $$: $$, esc: esc, money: money, api: api, toast: toast, ico: ico, view: view, showDrawer: showDrawer, closeDrawer: closeDrawer, refreshBadges: refreshBadges, me: function () { return me; }, setMe: function (u) { me = u; }, views: {}, openOrder: openOrder, guard: guard };
  api('GET', '/api/me').then(function (r) { if (r.user && r.user.role === 'admin') { me = r.user; consoleView(); } else loginView(r.user ? 'You are signed in as a customer. Sign in with the admin account to continue.' : ''); }, function () { loginView('Can’t reach the server.'); });
})();
