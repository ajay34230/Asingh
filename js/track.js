/* Guest-friendly order tracking: order number + mobile → status, progress, courier. */
(function (A) {
  'use strict';
  var U = A.U, $ = U.$, esc = U.esc, money = U.money, api = U.api, O = A.Orders;
  var form = $('#tf'), out = $('#tr'), err = $('#te'), timer = null, current = null, KEY = 'asingh.lastOrder';
  var q = new URLSearchParams(location.search), pre = (q.get('n') || U.store.get(KEY, '') || '').replace(/^(?:AS|CV)-?/i, '');
  if (pre) $('#tn').value = pre;
  if ($('#tn').value) setTimeout(function () { $('#tp').focus(); }, 50);

  function show(o) {
    current = o; U.store.set(KEY, String(o.number).replace(/^(?:AS|CV)-?/i, ''));
    var lead = { awaiting_payment: 'We’re waiting for your payment. Pay by QR and upload the screenshot to continue.', payment_review: 'We received your screenshot and are verifying your payment.', payment_rejected: 'We couldn’t verify your payment. Please upload a clear screenshot.', paid: 'Payment verified — your order will go to our artisans next.', processing: 'Your order is being crafted by our artisans.', shipped: 'Your order is on its way!', delivered: 'Delivered. We hope you love it.', cancelled: 'This order was cancelled.' }[o.status] || '';
    out.innerHTML = '<section class="ocardx trackres" aria-labelledby="trh"><header class="ohead"><div><p class="eyebrow">Order</p><h2 class="h1" id="trh">' + esc(o.number) + '</h2><p class="muted">Placed ' + O.fmtDate(o.createdAt) + ' · updated ' + O.fmtDate(o.updatedAt) + '</p></div>' + O.chip(o.status) + '</header>' +
      '<p class="trackres__lead">' + esc(lead) + '</p>' + O.trackingCard(o.tracking) + O.timeline(o) +
      '<h3 class="h3">Items</h3><ul class="oitems">' + o.items.map(function (i) { return '<li><span class="oitems__img">' + U.picture(i.id, 1, { sizes: '52px', alt: '' }) + '</span><span class="oitems__t"><strong>' + esc(i.name) + '</strong><small>' + esc(i.color) + ' · Size ' + esc(i.size) + ' · ' + esc(i.stitchLabel) + (i.qty > 1 ? ' · ×' + i.qty : '') + '</small></span><span></span></li>'; }).join('') + '</ul>' +
      '<p class="trackres__tot"><span>Order total</span><strong>' + money(o.totals.total) + '</strong></p>' +
      '<div class="oact">' + (o.canClaim ? '<button type="button" class="btn" id="claim">' + ((o.status === 'awaiting_payment' || o.status === 'payment_rejected') ? 'Pay / upload screenshot' : 'Open full order on this device') + '</button>' : '<button type="button" class="btn" id="si">Sign in for full details</button>') + '<button type="button" class="btn btn--ghost" id="again">Check another order</button></div>' +
      '<p class="muted live"><i></i> Updates automatically while this page is open.</p></section>';
    U.reveal(out); out.scrollIntoView({ block: 'start', behavior: U.reduceMotion.matches ? 'auto' : 'smooth' });
    $('#again').addEventListener('click', function () { clearInterval(timer); out.innerHTML = ''; $('#tn').value = ''; $('#tp').value = ''; $('#tn').focus(); });
    var c = $('#claim'); if (c) c.addEventListener('click', function () { c.disabled = true; api('POST', '/api/track/claim', { number: o.number, phone: $('#tp').value }).then(function (r) { location.href = 'order.html?id=' + r.orderId; }, function (e) { c.disabled = false; U.toast(e.message); }); });
    var s = $('#si'); if (s) s.addEventListener('click', function () { U.Auth.ensure().then(function () { location.href = 'account.html'; }, function () {}); });
    clearInterval(timer); if (['delivered', 'cancelled'].indexOf(o.status) < 0) timer = setInterval(function () { if (!document.hidden) fetchOrder(true); }, 30000);
  }
  function fetchOrder(silent) {
    return api('POST', '/api/track', { number: $('#tn').value, phone: $('#tp').value }).then(function (r) {
      if (silent && current && r.order.updatedAt === current.updatedAt) return; var changed = current && silent; show(r.order); if (changed) U.toast('Your order status was updated');
    }, function (e) { if (!silent) throw e; });
  }
  form.addEventListener('submit', function (e) {
    e.preventDefault(); err.textContent = '';
    if (!/\d{4,}/.test($('#tn').value)) { err.textContent = 'Enter your order number, e.g. 48213.'; $('#tn').focus(); return; }
    if ($('#tp').value.replace(/\D/g, '').length < 10) { err.textContent = 'Enter the 10-digit mobile number you used at checkout.'; $('#tp').focus(); return; }
    var b = $('[type=submit]', form); b.disabled = true; b.classList.add('is-busy');
    fetchOrder(false).then(function () { b.disabled = false; b.classList.remove('is-busy'); }, function (er) { b.disabled = false; b.classList.remove('is-busy'); err.textContent = er.message; out.innerHTML = ''; });
  });
})(window.ASINGH);
