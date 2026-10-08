/* Order bill: renders the full order (with photos) for print-to-PDF, and a plain-text download. Owner or admin only. */
(function () {
  'use strict';
  var METHOD = { upi_qr: 'UPI / QR', razorpay: 'Online (card / UPI / netbanking / wallet)', cod: 'Cash on delivery' };
  var $ = function (s) { return document.querySelector(s); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var rs = function (n) { return '₹' + Number(n || 0).toLocaleString('en-IN'); };
  var dt = function (t) { return new Date(t).toLocaleString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' }); };
  var d0 = function (t) { return new Date(t).toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' }); };
  var TONE = { awaiting_payment: 'warn', payment_review: 'info', payment_rejected: 'bad', paid: 'good', processing: 'good', shipped: 'good', delivered: 'good', cancelled: 'mute' };
  var PAYLINE = { awaiting_payment: 'PAYMENT DUE', payment_review: 'PAYMENT UNDER REVIEW', payment_rejected: 'PAYMENT NOT VERIFIED', paid: 'PAID', processing: 'PAID', shipped: 'PAID', delivered: 'PAID', cancelled: 'CANCELLED' };
  var isPaid = function (s) { return ['paid', 'processing', 'shipped', 'delivered'].indexOf(s) > -1; };
  function api(url) { return fetch(url, { credentials: 'same-origin' }).then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { if (!r.ok) { var e = new Error(j.error || 'Failed'); e.status = r.status; throw e; } return j; }); }); }
  var id = new URLSearchParams(location.search).get('id'), doc = $('#doc'), data = null;

  function text(o, inv) {
    var L = [], line = function (a, b) { L.push(a + (b ? ' ' + b : '')); }, hr = '='.repeat(56), c = o.customer;
    L.push(hr, (inv.name || 'चंद्रवंशी') + ' — ORDER BILL', hr);
    if (inv.address) L.push(inv.address.replace(/\n+/g, ', ')); if (inv.gstin) L.push('GSTIN: ' + inv.gstin); if (inv.contact) L.push(inv.contact);
    L.push('', 'Order number : ' + o.number, 'Order date   : ' + dt(o.createdAt), 'Status       : ' + o.statusLabel + (isPaid(o.status) ? ' (paid)' : ''), '',
      'BILL TO / SHIP TO', c.name, c.line1 + (c.line2 ? ', ' + c.line2 : ''), c.city + ', ' + c.state + ' ' + c.pin, 'Mobile: ' + c.phone, 'Email : ' + c.email, '', 'ITEMS', '-'.repeat(56));
    o.items.forEach(function (i, n) {
      L.push((n + 1) + '. ' + i.name, '   ' + i.color + ' · Size ' + i.size + ' · ' + i.stitchLabel + ' · Qty ' + i.qty, (i.note ? '   Note: ' + i.note + '\n' : '') + '   ' + rs(i.unit) + ' × ' + i.qty + ' = ' + rs(i.unit * i.qty), '   Photo/page: ' + location.origin + '/product.html?id=' + i.id);
    });
    L.push('-'.repeat(56), 'Subtotal : ' + rs(o.totals.subtotal), o.totals.discount ? 'Discount : -' + rs(o.totals.discount) + ' (' + o.totals.coupon + ')' : null, 'Shipping : ' + (o.totals.shipping ? rs(o.totals.shipping) : 'Free'), o.totals.codFee ? 'COD fee  : ' + rs(o.totals.codFee) : null, o.totals.gift ? 'Gift wrap: ' + rs(o.totals.gift) : null, 'TOTAL    : ' + rs(o.totals.total), isPaid(o.status) ? 'Paid     : ' + rs(o.totals.total) : 'Amount due: ' + rs(o.totals.total), '',
      'Payment: ' + (METHOD[o.method] || 'UPI / QR') + (o.proof && o.proof.utr ? ' · UTR ' + o.proof.utr : ''));
    if (o.tracking) L.push('Shipment: ' + [o.tracking.courier, o.tracking.id].filter(Boolean).join(' · ') + (o.tracking.url ? '\n          ' + o.tracking.url : ''));
    L.push('', 'PROGRESS'); o.timeline.forEach(function (t) { L.push('  ' + dt(t.at) + '  ' + t.label + (t.note ? ' — ' + t.note : '')); });
    L.push('', 'Track this order: ' + location.origin + '/track.html?n=' + o.number.replace(/^(?:AS|CV)-?/i, ''), '(you will need your mobile number)', '', 'Prices include applicable taxes.' + (inv.returns ? ' ' + inv.returns : ''), 'Thank you for shopping with ' + (inv.name || 'चंद्रवंशी') + '.');
    return L.filter(function (x) { return x !== null; }).join('\n');
  }
  /* packing slip: no prices, big delivery address, photos + sizes to pick and pack */
  function renderSlip(o, inv) {
    var c = o.customer; document.title = 'Packing slip ' + o.number + ' — ' + (inv.name || 'चंद्रवंशी');
    doc.innerHTML = '<header class="inv__head"><div><img class="inv__logo" src="img/brand/logo-128.webp" width="72" height="72" alt=""><div class="inv__brand">' + esc(inv.name || 'चंद्रवंशी') + '</div></div><div class="inv__meta"><h1>Packing slip</h1><div class="inv__no">' + esc(o.number) + '</div><p>' + d0(o.createdAt) + '</p></div></header>' +
      '<section class="inv__box slip__to"><h2>Ship to</h2><address><strong>' + esc(c.name) + '</strong><br>' + esc(c.line1) + (c.line2 ? ', ' + esc(c.line2) : '') + '<br>' + esc(c.city) + ', ' + esc(c.state) + ' — <strong>' + esc(c.pin) + '</strong><br>Phone: <strong>' + esc(c.phone) + '</strong></address></section>' +
      '<table><thead><tr><th class="ph"></th><th>Item to pack</th><th class="r">Qty</th><th class="r">Packed</th></tr></thead><tbody>' + o.items.map(function (i) {
        return '<tr><td class="ph"><img src="img/' + esc(i.id) + '-1-400.webp" alt="' + esc(i.name) + '" width="56" height="70"></td><td class="nm"><strong>' + esc(i.name) + '</strong><small>' + esc(i.color) + ' · Size ' + esc(i.size) + ' · ' + esc(i.stitchLabel) + '</small>' + (i.note ? '<small>Customer note: “' + esc(i.note) + '”</small>' : '') + '</td><td class="r"><strong>' + i.qty + '</strong></td><td class="r"><span class="slip__box" aria-hidden="true"></span></td></tr>';
      }).join('') + '</tbody></table>' +
      (o.gift ? '<div class="inv__box slip__gift"><h2>🎁 GIFT — wrap it</h2><p>' + (o.gift.message ? 'Card message: “' + esc(o.gift.message) + '”' : 'No card message.') + '</p></div>' : '') +
      (o.tracking ? '<div class="inv__box"><h2>Courier</h2><p><strong>' + esc(o.tracking.courier || '') + '</strong> ' + esc(o.tracking.id || '') + '</p></div>' : '') +
      '<footer class="inv__foot"><p>Check size and stitching against the notes, fold with tissue, include the bill. Order status: ' + esc(o.statusLabel) + '.</p></footer>';
    var imgs = [].slice.call(doc.querySelectorAll('img')), ready = Promise.all(imgs.map(function (i) { return i.complete ? 0 : new Promise(function (r) { i.onload = i.onerror = r; }); }));
    ready.then(function () { $('#pdf').disabled = false; $('#txt').hidden = true; if (/[?&]print=1/.test(location.search)) setTimeout(function () { window.print(); }, 250); });
    $('#pdf').onclick = function () { window.print(); };
  }
  function render(o, inv) {
    if (/[?&]slip=1/.test(location.search)) return renderSlip(o, inv);
    var c = o.customer, tone = TONE[o.status], paid = isPaid(o.status);
    document.title = 'Bill ' + o.number + ' — ' + (inv.name || 'चंद्रवंशी');
    doc.innerHTML = '<header class="inv__head"><div><img class="inv__logo" src="img/brand/logo-128.webp" width="72" height="72" alt=""><div class="inv__brand">' + esc(inv.name || 'चंद्रवंशी') + '</div><div class="inv__seller">' + esc([inv.address, inv.gstin ? 'GSTIN: ' + inv.gstin : '', inv.contact].filter(Boolean).join('\n')) + '</div></div>' +
      '<div class="inv__meta"><h1>Order bill</h1><div class="inv__no">' + esc(o.number) + '</div><p>' + d0(o.createdAt) + '</p><span class="stamp stamp--' + (paid ? 'good' : tone) + '">' + PAYLINE[o.status] + '</span></div></header>' +
      '<section class="inv__cols"><div><h2>Bill to / ship to</h2><address><strong>' + esc(c.name) + '</strong><br>' + esc(c.line1) + (c.line2 ? ', ' + esc(c.line2) : '') + '<br>' + esc(c.city) + ', ' + esc(c.state) + ' ' + esc(c.pin) + '<br>' + esc(c.phone) + '<br>' + esc(c.email) + '</address></div>' +
      '<div><h2>Order</h2><p>Status: <strong>' + esc(o.statusLabel) + '</strong></p><p>Payment: ' + esc(METHOD[o.method] || 'UPI / QR') + '</p>' + (o.proof && o.proof.utr ? '<p>UTR: <strong>' + esc(o.proof.utr) + '</strong></p>' : '') + '<p>Updated: ' + dt(o.updatedAt) + '</p></div></section>' +
      '<table><thead><tr><th class="ph"></th><th>Item</th><th class="r hide">Price</th><th class="r hide">Qty</th><th class="r">Amount</th></tr></thead><tbody>' + o.items.map(function (i) {
        return '<tr><td class="ph"><img src="img/' + esc(i.id) + '-1-400.webp" alt="' + esc(i.name) + '" width="56" height="70"></td><td class="nm"><strong><a href="product.html?id=' + esc(i.id) + '">' + esc(i.name) + '</a></strong><small>' + esc(i.color) + ' · Size ' + esc(i.size) + ' · ' + esc(i.stitchLabel) + '</small>' + (i.note ? '<small>Note: “' + esc(i.note) + '”</small>' : '') + '</td><td class="r hide">' + rs(i.unit) + '</td><td class="r hide">' + i.qty + '</td><td class="r">' + rs(i.unit * i.qty) + '</td></tr>';
      }).join('') + '</tbody></table>' +
      '<div class="tot"><div><span>Subtotal</span><span>' + rs(o.totals.subtotal) + '</span></div>' + (o.totals.discount ? '<div><span>Discount (' + esc(o.totals.coupon) + ')</span><span>− ' + rs(o.totals.discount) + '</span></div>' : '') + '<div><span>Shipping</span><span>' + (o.totals.shipping ? rs(o.totals.shipping) : 'Free') + '</span></div>' + (o.totals.codFee ? '<div><span>Cash on delivery fee</span><span>' + rs(o.totals.codFee) + '</span></div>' : '') + (o.totals.gift ? '<div><span>Gift wrap</span><span>' + rs(o.totals.gift) + '</span></div>' : '') + '<div class="g"><span>Total</span><span>' + rs(o.totals.total) + '</span></div><div class="' + (paid ? 'paid' : 'due') + '"><span>' + (paid ? 'Paid' : 'Amount due') + '</span><span>' + rs(o.totals.total) + '</span></div></div>' +
      (o.tracking ? '<div class="inv__box"><h2>Shipment</h2><p><strong>' + esc(o.tracking.courier || 'Courier') + '</strong>' + (o.tracking.id ? ' · Tracking ID <strong>' + esc(o.tracking.id) + '</strong>' : '') + (o.tracking.url ? '<br><a href="' + esc(o.tracking.url) + '">' + esc(o.tracking.url) + '</a>' : '') + '</p></div>' : '') +
      '<div class="inv__box"><h2>Progress</h2><ul class="log">' + o.timeline.map(function (t) { return '<li><time>' + dt(t.at) + '</time><span><strong>' + esc(t.label) + '</strong>' + (t.note ? ' — ' + esc(t.note) : '') + '</span></li>'; }).join('') + '</ul></div>' +
      '<footer class="inv__foot"><p><strong>Track this order any time:</strong> ' + esc(location.origin) + '/track.html — order number <strong>' + esc(o.number) + '</strong> + the mobile number above.</p><p>Prices include applicable taxes.' + (inv.returns ? ' ' + esc(inv.returns) : '') + ' This is a computer-generated bill.</p></footer>';
    var imgs = [].slice.call(doc.querySelectorAll('img')), ready = Promise.all(imgs.map(function (i) { return i.complete ? 0 : new Promise(function (r) { i.onload = i.onerror = r; }); }));
    ready.then(function () { $('#pdf').disabled = false; $('#txt').disabled = false; if (/[?&]print=1/.test(location.search)) setTimeout(function () { window.print(); }, 250); });
    $('#pdf').onclick = function () { window.print(); };
    $('#txt').onclick = function () { var b = new Blob([text(o, inv)], { type: 'text/plain;charset=utf-8' }), a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = 'Chandravanshi-bill-' + o.number + '.txt'; document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500); };
  }
  function fail(m, link) { doc.innerHTML = '<div class="err"><p><strong>' + esc(m) + '</strong></p><p>Bills are private — only the person who placed the order (and the store) can open them.</p><p><a href="' + (link || 'account.html') + '">' + (link ? 'Go to sign in' : 'My orders') + '</a></p></div>'; $('#pdf').hidden = $('#txt').hidden = true; $('#hint').hidden = true; }
  if (!id) return fail('No order selected.');
  Promise.all([api('/api/orders/' + encodeURIComponent(id)), api('/api/config')]).then(function (r) { data = r; render(r[0].order, Object.assign({}, r[1].invoice || {}, { returns: ((r[1].site || {}).policies || {}).returns || '' })); }, function (e) { fail(e.status === 401 ? 'Please sign in to view this bill.' : 'We couldn’t find that order.', e.status === 401 ? 'account.html' : ''); });
})();
