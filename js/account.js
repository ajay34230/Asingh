/* Account area + order tracking pages. */
(function (A) {
  'use strict';
  var U = A.U, $ = U.$, $$ = U.$$, esc = U.esc, money = U.money, api = U.api, Auth = U.Auth, O = A.Orders;
  var page = document.body.getAttribute('data-page');
  var STATES = ['Andhra Pradesh', 'Assam', 'Bihar', 'Chandigarh', 'Chhattisgarh', 'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Odisha', 'Punjab', 'Rajasthan', 'Tamil Nadu', 'Telangana', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'];
  var root = $('#acct') || $('#orderpg');

  /* ---------------- account ---------------- */
  function authView() {
    document.title = 'Sign in — ' + A.BRAND;
    root.innerHTML = '<section class="authpage"><div class="authpage__art" aria-hidden="true">' + U.picture('maharani-poshak', 3, { sizes: '(min-width:1000px) 40vw, 0px', alt: '' }) + '<div class="authpage__cap"><p class="eyebrow eyebrow--light">Rajputana, delivered</p><p class="authpage__q">Every poshak is made for you — and every order stays private to you.</p><ul><li>' + U.icon('check', 'ico--xs') + ' Guest checkout, no details needed</li><li>' + U.icon('check', 'ico--xs') + ' Track every order in one place</li><li>' + U.icon('check', 'ico--xs') + ' Upload payment proof securely</li></ul></div></div>' +
      '<div class="authpage__form"><h1 class="h1">Welcome</h1><p class="muted">Sign in, create an account, or continue as a guest.</p><div id="am"></div></div></section>';
    Auth.mount($('#am'), { focus: false, onDone: function (u) { Auth.user = u; Auth.paint(); U.toast(u.isGuest ? 'Continuing as guest' : 'Welcome, ' + (u.name || 'back')); dash(); } });
  }
  function dash() {
    var u = Auth.user; document.title = 'My account — ' + A.BRAND;
    var ini = ((u.isGuest ? 'G' : (u.name || u.email || '?').trim().charAt(0)) || '?').toUpperCase();
    root.innerHTML = '<header class="acct__head"><span class="avatar avatar--lg" aria-hidden="true">' + esc(ini) + '</span><div><h1 class="h1">' + (u.isGuest ? 'Guest account' : 'Namaste, ' + esc((u.name || '').split(' ')[0] || 'there')) + '</h1><p class="muted">' + (u.isGuest ? 'Orders are saved on this device.' : esc(u.email)) + (u.role === 'admin' ? ' · <strong>Admin</strong>' : '') + '</p></div><button type="button" class="btn btn--ghost" id="signout">Sign out</button></header>' +
      (u.role === 'admin' ? '<a class="admincard" href="admin.html"><span>' + U.icon('lock') + '</span><span><strong>Open the admin console</strong><small>Orders, payment QR, alerts</small></span>' + U.icon('right') + '</a>' : '') +
      (u.isGuest ? '<p class="authnote">Lost this device? Track any order without signing in at <a href="track.html">the tracking page</a> using your order number and mobile number.</p><section class="upgrade"><div><h2 class="h3">Keep your orders safe</h2><p class="muted">Create a free account and every order you’ve placed as a guest moves into it.</p></div><div id="up"></div></section>' : '') +
      '<div class="tabs tabs--page" role="tablist"><button role="tab" id="tab-o" aria-selected="true" aria-controls="pn-o">My orders</button><button role="tab" id="tab-p" aria-selected="false" aria-controls="pn-p" tabindex="-1">Profile &amp; address</button><button role="tab" id="tab-s" aria-selected="false" aria-controls="pn-s" tabindex="-1">Privacy &amp; security</button></div>' +
      '<section id="pn-o" role="tabpanel" aria-labelledby="tab-o"><div id="olist" aria-live="polite"><div class="skel skel--card"></div><div class="skel skel--card"></div></div></section>' +
      '<section id="pn-p" role="tabpanel" aria-labelledby="tab-p" hidden><form class="profile" id="pf" novalidate>' + (u.isGuest ? '' : '<div class="field"><label class="field__l" for="p-name">Full name</label><input class="input" id="p-name" name="name" autocomplete="name"></div>') +
      '<div class="fields"><div class="field"><label class="field__l" for="p-phone">Mobile</label><input class="input" id="p-phone" name="phone" type="tel" inputmode="tel" autocomplete="tel"></div><div class="field"><label class="field__l" for="p-pin">PIN code</label><input class="input" id="p-pin" name="pin" inputmode="numeric" maxlength="6" autocomplete="postal-code"></div>' +
      '<div class="field field--wide"><label class="field__l" for="p-l1">Address</label><input class="input" id="p-l1" name="line1" autocomplete="address-line1"></div><div class="field field--wide"><label class="field__l" for="p-l2">Apartment, landmark</label><input class="input" id="p-l2" name="line2" autocomplete="address-line2"></div>' +
      '<div class="field"><label class="field__l" for="p-city">City</label><input class="input" id="p-city" name="city" autocomplete="address-level2"></div><div class="field"><label class="field__l" for="p-state">State</label><select class="input input--select" id="p-state" name="state" autocomplete="address-level1"><option value="">Select</option>' + STATES.map(function (s) { return '<option>' + s + '</option>'; }).join('') + '</select></div></div>' +
      '<p class="muted">Saved details pre-fill checkout. Only you can see them.</p><button class="btn btn--lg" type="submit"><span>Save details</span></button></form></section>' +
      '<section id="pn-s" role="tabpanel" aria-labelledby="tab-s" hidden>' + securityHtml(u) + '</section>';
    $('#signout').addEventListener('click', function () { Auth.signOut().then(function () { authView(); }); });
    var tabs = $$('[role=tab]', root); tabs.forEach(function (t) { t.addEventListener('click', function () { tabs.forEach(function (x) { var on = x === t; x.setAttribute('aria-selected', on); x.tabIndex = on ? 0 : -1; }); $('#pn-o').hidden = t.id !== 'tab-o'; $('#pn-p').hidden = t.id !== 'tab-p'; $('#pn-s').hidden = t.id !== 'tab-s'; }); });
    var p = u.profile || {}, f = $('#pf'); Object.keys(p).forEach(function (k) { if (f.elements[k]) f.elements[k].value = p[k]; }); if (f.elements.name) f.elements.name.value = u.name || '';
    f.addEventListener('submit', function (e) { e.preventDefault(); var d = { name: f.elements.name ? f.elements.name.value : undefined, profile: {} }; ['phone', 'pin', 'line1', 'line2', 'city', 'state'].forEach(function (k) { d.profile[k] = f.elements[k].value; }); api('PATCH', '/api/me', d).then(function (r) { Auth.user = r.user; Auth.paint(); U.toast('Saved'); }, function (er) { U.toast(er.message); }); });
    bindSecurity(u);
    if (u.isGuest) Auth.mount($('#up'), { upgradeOnly: true, guest: false, focus: false, onDone: function (nu) { Auth.user = nu; Auth.paint(); U.toast('Account created — your orders are saved'); dash(); } });
    api('GET', '/api/orders').then(function (r) {
      $('#olist').innerHTML = r.orders.length ? r.orders.map(function (o) {
        var due = o.status === 'awaiting_payment' || o.status === 'payment_rejected';
        return '<a class="ocard" href="order.html?id=' + o.id + '"><span class="ocard__imgs">' + o.items.slice(0, 3).map(function (i) { return '<span>' + U.picture(i.id, 1, { sizes: '56px', alt: '' }) + '</span>'; }).join('') + '</span><span class="ocard__t"><strong>' + esc(o.number) + '</strong><small>' + O.fmtDate(o.createdAt) + ' · ' + o.items.length + ' item' + (o.items.length > 1 ? 's' : '') + '</small></span>' + O.chip(o.status) + '<span class="ocard__p">' + money(o.totals.total) + '</span><span class="ocard__go ' + (due ? 'is-due' : '') + '">' + (due ? 'Pay now' : 'View') + U.icon('right', 'ico--xs') + '</span></a>';
      }).join('') : '<div class="empty"><p class="empty__title">No orders yet</p><p>When you place an order it will appear here.</p><a class="btn" href="shop.html">Start shopping</a></div>';
      U.reveal($('#olist'));
    }, function (er) { $('#olist').innerHTML = '<p class="field__err">' + esc(er.message) + '</p>'; });
  }


  /* ---------------- privacy & security (self-service) ---------------- */
  function securityHtml(u) {
    var pw = u.isGuest ? '' : '<form class="sec" id="sf-pw" novalidate><h2 class="h3">Change password</h2><div class="fields"><div class="field"><label class="field__l" for="s-cur">Current password</label><input class="input" id="s-cur" type="password" autocomplete="current-password"></div><div class="field"><label class="field__l" for="s-new">New password <span class="muted">(8+ characters)</span></label><input class="input" id="s-new" type="password" autocomplete="new-password" minlength="8"></div></div><p class="field__err" id="e-pw" role="alert"></p><button class="btn btn--ghost" type="submit"><span>Update password</span></button></form>' +
      '<form class="sec" id="sf-em" novalidate><h2 class="h3">Change email</h2><div class="fields"><div class="field"><label class="field__l" for="s-email">New email</label><input class="input" id="s-email" type="email" autocomplete="email" value="' + esc(u.email || '') + '"></div><div class="field"><label class="field__l" for="s-pwd">Password</label><input class="input" id="s-pwd" type="password" autocomplete="current-password"></div></div><p class="field__err" id="e-em" role="alert"></p><button class="btn btn--ghost" type="submit"><span>Update email</span></button></form>';
    return pw + '<div class="sec"><h2 class="h3">Your data</h2><p class="muted">Download everything we hold about you — details and orders — as a file.</p><a class="btn btn--ghost" href="/api/me/export" download>Download my data</a></div>' +
      (u.isGuest ? '' : '<div class="sec"><h2 class="h3">Signed in elsewhere?</h2><p class="muted">Sign out of every other phone and computer.</p><button class="btn btn--ghost" id="s-all" type="button">Sign out other devices</button></div>' +
      '<div class="sec"><h2 class="h3">Emails</h2><p class="muted">Stop newsletter emails to <strong>' + esc(u.email) + '</strong>.</p><button class="btn btn--ghost" id="s-unsub" type="button">Unsubscribe</button></div>') +
      '<form class="sec sec--danger" id="sf-del" novalidate><h2 class="h3">Delete my account</h2><p class="muted">' + (u.isGuest ? 'Removes this guest profile and erases the contact details on your orders.' : 'Permanently removes your account and saved details, and erases the contact details on your orders. Orders in progress must finish first.') + ' This cannot be undone.</p>' +
      (u.isGuest ? '' : '<div class="field"><label class="field__l" for="d-pw">Confirm with your password</label><input class="input" id="d-pw" type="password" autocomplete="current-password"></div>') + '<p class="field__err" id="e-del" role="alert"></p><button class="btn btn--danger" type="submit"><span>Delete my account</span></button></form>';
  }
  function bindSecurity(u) {
    var on = function (id, ev, fn) { var e = $(id); if (e) e.addEventListener(ev, fn); }, busy = function (f, v) { var b = $('button[type=submit]', f); if (b) b.disabled = v; };
    on('#sf-pw', 'submit', function (e) { e.preventDefault(); var f = this; busy(f, true); api('POST', '/api/me/password', { current: $('#s-cur').value, next: $('#s-new').value }).then(function () { f.reset(); $('#e-pw').textContent = ''; U.toast('Password updated'); }, function (er) { $('#e-pw').textContent = er.message; }).then(function () { busy(f, false); }); });
    on('#sf-em', 'submit', function (e) { e.preventDefault(); var f = this; busy(f, true); api('POST', '/api/me/email', { email: $('#s-email').value, password: $('#s-pwd').value }).then(function (r) { Auth.user = r.user; $('#s-pwd').value = ''; $('#e-em').textContent = ''; U.toast('Email updated'); }, function (er) { $('#e-em').textContent = er.message; }).then(function () { busy(f, false); }); });
    on('#s-all', 'click', function () { api('POST', '/api/me/signout-all', {}).then(function () { U.toast('Signed out of other devices'); }); });
    on('#s-unsub', 'click', function () { api('POST', '/api/newsletter/unsubscribe', { email: u.email }).then(function () { U.toast('You’re unsubscribed'); }); });
    on('#sf-del', 'submit', function (e) { e.preventDefault(); if (!confirm('Delete your account permanently? This cannot be undone.')) return; var f = this; busy(f, true); api('DELETE', '/api/me', { password: $('#d-pw') ? $('#d-pw').value : '' }).then(function () { Auth.user = null; Auth.paint(); try { localStorage.removeItem('asingh.cart.v1'); } catch (x) {} U.toast('Your account has been deleted'); authView(); }, function (er) { $('#e-del').textContent = er.message; busy(f, false); }); });
  }
  /* order page: ask to cancel (after payment) or return / exchange (after delivery) */
  function requestHtml(o) {
    var r = o.request, days = A.SITE && A.SITE.returnDays;
    if (r) return '<section class="ocardx"><h2 class="h3">' + ({ cancel: 'Cancellation', return: 'Return', exchange: 'Exchange' })[r.type] + ' request</h2><p>' + esc(r.reason) + '</p><p><strong>' + ({ pending: 'Waiting for our team', approved: 'Approved', declined: 'Declined' })[r.state] + '</strong>' + (r.note ? ' — ' + esc(r.note) : '') + '</p></section>' + (r.state === 'pending' ? '' : reqForm(o));
    return reqForm(o);
  }
  function reqForm(o) {
    var kinds = o.status === 'paid' || o.status === 'processing' ? [['cancel', 'Request cancellation']] : o.status === 'delivered' ? [['return', 'Return'], ['exchange', 'Exchange']] : [];
    if (o.status === 'delivered' && o.items.every(function (i) { return i.stitch === 'custom'; })) return '';
    if (!kinds.length) return '';
    return '<section class="ocardx"><h2 class="h3">Need help with this order?</h2><form id="rq" novalidate><fieldset class="rq__k"><legend class="vh">Request type</legend>' + kinds.map(function (k, i) { return '<label class="chipradio"><input type="radio" name="rt" value="' + k[0] + '"' + (i ? '' : ' checked') + '><span>' + k[1] + '</span></label>'; }).join('') + '</fieldset><div class="field"><label class="field__l" for="rq-r">Reason</label><textarea class="input" id="rq-r" rows="3" maxlength="400" placeholder="Tell us briefly what happened"></textarea></div><p class="field__err" id="rq-e" role="alert"></p><button class="btn btn--ghost" type="submit"><span>Send request</span></button></form></section>';
  }

  /* ---------------- single order ---------------- */
  function orderView() {
    var id = new URLSearchParams(location.search).get('id'), timer;
    if (!id) { root.innerHTML = '<div class="empty"><p class="empty__title">No order selected</p><a class="btn" href="account.html">My orders</a></div>'; return; }
    function load(first) {
      api('GET', '/api/orders/' + id).then(function (r) { draw(r.order, first); }, function (er) {
        root.innerHTML = '<div class="empty"><p class="empty__title">' + (er.status === 401 ? 'Please sign in to view this order' : 'We couldn’t find that order') + '</p><p>Orders are private — you can only open your own.</p><a class="btn" href="account.html">' + (er.status === 401 ? 'Sign in' : 'My orders') + '</a></div>';
      });
    }
    function draw(o, first) {
      var vh1 = document.querySelector('main > h1.vh'); if (vh1) vh1.remove();
      document.title = 'Order ' + o.number + ' — ' + A.BRAND; var c = o.customer, due = o.status === 'awaiting_payment' || o.status === 'payment_rejected';
      var keep = $('#paymount') && $('#paymount').firstChild && due && !first;
      root.innerHTML = '<nav class="crumbs" aria-label="Breadcrumb"><ol><li><a href="account.html">My orders</a></li><li aria-current="page">' + esc(o.number) + '</li></ol></nav>' +
        '<header class="ohead"><div><p class="eyebrow">Order</p><h1 class="h1">' + esc(o.number) + '</h1><p class="muted">Placed ' + O.fmtDate(o.createdAt) + '</p></div>' + O.chip(o.status) + '</header>' +
        '<div id="ordnum"></div><div class="ogrid"><div class="ogrid__main">' + (o.tracking ? '<section class="ocardx" aria-label="Shipment">' + O.trackingCard(o.tracking) + '</section>' : '') + '<section class="ocardx" aria-label="Payment"><div id="paymount"></div></section><section class="ocardx"><h2 class="h3">Progress</h2>' + O.timeline(o) + '</section></div>' +
        '<aside class="ogrid__side"><section class="ocardx"><h2 class="h3">Items</h2>' + O.items(o) + '<dl class="totals"><div><dt>Subtotal</dt><dd>' + money(o.totals.subtotal) + '</dd></div>' + (o.totals.discount ? '<div class="totals__disc"><dt>Discount <small>' + esc(o.totals.coupon || '') + '</small></dt><dd>− ' + money(o.totals.discount) + '</dd></div>' : '') + '<div><dt>Shipping</dt><dd>' + (o.totals.shipping ? money(o.totals.shipping) : 'Free') + '</dd></div><div class="totals__total"><dt>Total</dt><dd>' + money(o.totals.total) + '</dd></div></dl></section>' +
        '<section class="ocardx"><h2 class="h3">Delivery</h2><address>' + esc(c.name) + '<br>' + esc(c.line1) + (c.line2 ? '<br>' + esc(c.line2) : '') + '<br>' + esc(c.city) + ', ' + esc(c.state) + ' ' + esc(c.pin) + '<br>' + esc(c.phone) + '<br>' + esc(c.email) + '</address>' +
        '<div class="oact"><a class="btn btn--ghost" href="invoice.html?id=' + o.id + '">Bill · Save PDF</a><a class="btn btn--ghost" href="invoice.html?id=' + o.id + '&amp;print=1" target="_blank" rel="noopener">Print</a>' + (due ? '<button type="button" class="btn btn--ghost" id="cancel">Cancel order</button>' : '') + '</div></section>' + requestHtml(o) + '</aside></div>';
      O.numberCard(o, $('#ordnum'), 'Quote this number if you contact us. Anyone tracking it also needs your mobile number.');
      $$('[data-copy]', root).forEach(function (b) { if (!b._c) { b._c = 1; b.addEventListener('click', function () { O.copy(b.getAttribute('data-copy'), b); }); } });
      A.Orders.payPanel(o, $('#paymount'), function (upd) { draw(upd, false); });
      var cx = $('#cancel'); if (cx) cx.addEventListener('click', function () { if (confirm('Cancel this order?')) api('POST', '/api/orders/' + o.id + '/cancel', {}).then(function (r) { draw(r.order, false); }, function (er) { U.toast(er.message); }); });
      var rq = $('#rq'); if (rq) rq.addEventListener('submit', function (e) { e.preventDefault(); var b = $('button', rq); b.disabled = true; api('POST', '/api/orders/' + o.id + '/request', { type: rq.elements.rt.value, reason: $('#rq-r').value }).then(function (r) { U.toast('Request sent'); draw(r.order, false); }, function (er) { $('#rq-e').textContent = er.message; b.disabled = false; }); });
      U.reveal(root);
      clearTimeout(timer); if (['delivered', 'cancelled'].indexOf(o.status) < 0) timer = setTimeout(function tick() { if (!document.hidden && !$('.pay__form input[type=file]') && !($('#rq-r') && $('#rq-r').value)) load(false); else timer = setTimeout(tick, 20000); }, 20000);
    }
    Auth.refresh().then(function (u) { if (!u) { root.innerHTML = '<div class="empty"><p class="empty__title">Please sign in to view this order</p><p>Orders are private to the person who placed them.</p><button class="btn" id="si">Sign in</button></div>'; $('#si').addEventListener('click', function () { Auth.ensure().then(function () { load(true); }, function () {}); }); } else load(true); });
  }

  function resetView(tok) {
    document.title = 'Reset password — ' + A.BRAND;
    root.innerHTML = '<section class="authpage"><div class="authpage__form"><h1 class="h1">Choose a new password</h1><form id="rf" novalidate><div class="field"><label class="field__l" for="r-pw">New password <span class="muted">(8+ characters)</span></label><input class="input" id="r-pw" type="password" autocomplete="new-password" minlength="8"></div><p class="field__err" id="r-e" role="alert"></p><button class="btn btn--lg" type="submit"><span>Save and sign in</span></button></form></div></section>';
    $('#rf').addEventListener('submit', function (e) { e.preventDefault(); api('POST', '/api/auth/reset', { token: tok, password: $('#r-pw').value }).then(function (r) { Auth.user = r.user; Auth.paint(); history.replaceState(null, '', 'account.html'); U.toast('Password updated'); dash(); }, function (er) { $('#r-e').textContent = er.message; }); });
  }
  var rt = page === 'account' && new URLSearchParams(location.search).get('reset');
  if (rt) resetView(rt);
  else if (page === 'account') Auth.refresh().then(function (u) { if (u) dash(); else authView(); });
  else if (page === 'order') orderView();
})(window.ASINGH);
