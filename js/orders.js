/* Shared order UI: QR payment panel + screenshot upload, status chips, timeline. Used by checkout, order and account pages. */
(function (A) {
  'use strict';
  var U = A.U, $ = U.$, $$ = U.$$, esc = U.esc, money = U.money, api = U.api;
  var LABEL = { awaiting_payment: 'Awaiting payment', payment_review: 'Payment under review', payment_rejected: 'Payment needs attention', paid: 'Payment verified', processing: 'Being crafted', shipped: 'Shipped', delivered: 'Delivered', cancelled: 'Cancelled' };
  var TONE = { awaiting_payment: 'warn', payment_review: 'info', payment_rejected: 'bad', paid: 'good', processing: 'good', shipped: 'good', delivered: 'good', cancelled: 'mute' };
  var STEPS = [['paid', 'Payment verified'], ['processing', 'Being crafted'], ['shipped', 'Shipped'], ['delivered', 'Delivered']];
  var fmtDate = function (t) { return new Date(t).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }); };
  var chip = function (s) { return '<span class="chip-s chip-s--' + TONE[s] + '">' + (LABEL[s] || s) + '</span>'; };
  var cfgP = null; function config() { return cfgP || (cfgP = api('GET', '/api/config')); }

  /* Downscale big phone screenshots in the browser so uploads are fast on slow networks. */
  function compress(file) {
    return new Promise(function (resolve) {
      if (!file || file.size < 900e3 || !window.createImageBitmap) return resolve(file);
      createImageBitmap(file).then(function (bm) {
        var sc = Math.min(1, 1600 / Math.max(bm.width, bm.height)), c = document.createElement('canvas'); c.width = Math.round(bm.width * sc); c.height = Math.round(bm.height * sc);
        c.getContext('2d').drawImage(bm, 0, 0, c.width, c.height); c.toBlob(function (b) { resolve(b && b.size < file.size ? b : file); }, 'image/jpeg', 0.82);
      }, function () { resolve(file); });
    });
  }
  function copy(text, btn) {
    var done = function () { var t = btn.textContent; btn.textContent = 'Copied'; btn.classList.add('is-ok'); setTimeout(function () { btn.textContent = t; btn.classList.remove('is-ok'); }, 1500); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, function () {}); else { var i = document.createElement('input'); i.value = text; document.body.appendChild(i); i.select(); try { document.execCommand('copy'); done(); } catch (e) { /* ignore */ } i.remove(); }
  }
  function timeline(o) {
    var idx = -1; STEPS.forEach(function (s, i) { if (o.status === s[0] || (o.timeline || []).some(function (t) { return t.status === s[0]; })) idx = i; });
    var track = o.status === 'cancelled' ? '' : '<ol class="track" aria-label="Order progress">' + STEPS.map(function (s, i) { return '<li class="' + (i <= idx ? 'is-done' : '') + (i === idx ? ' is-now' : '') + '"><span class="track__dot">' + (i <= idx ? U.icon('check', 'ico--xs') : '') + '</span><span class="track__t">' + s[1] + '</span></li>'; }).join('') + '</ol>';
    var log = '<ol class="log">' + o.timeline.slice().reverse().map(function (t) { return '<li><time>' + fmtDate(t.at) + '</time><strong>' + (t.label || LABEL[t.status]) + '</strong>' + (t.note ? '<span>' + esc(t.note) + '</span>' : '') + '</li>'; }).join('') + '</ol>';
    return track + '<details class="logwrap"><summary>Activity</summary>' + log + '</details>';
  }
  function itemsHTML(o) {
    return '<ul class="oitems">' + o.items.map(function (i) {
      return '<li><span class="oitems__img">' + U.picture(i.id, 1, { sizes: '64px', alt: '' }) + '</span><span class="oitems__t"><strong>' + esc(i.name) + '</strong><small>' + esc(i.color) + ' · Size ' + esc(i.size) + ' · ' + esc(i.stitchLabel) + (i.qty > 1 ? ' · ×' + i.qty : '') + '</small>' + (i.note ? '<small>“' + esc(i.note) + '”</small>' : '') + '</span><span>' + money(i.unit * i.qty) + '</span></li>';
    }).join('') + '</ul>';
  }

  /* The QR payment panel. Re-renders itself as the order moves through review. */
  function payPanel(order, mount, onUpdate) {
    config().then(function (cfg) { render(cfg.upi); }, function () { mount.innerHTML = '<p class="field__err">Couldn’t load payment details. Please refresh.</p>'; });
    function render(upi) {
      var o = order, total = o.totals.total, needs = o.status === 'awaiting_payment' || o.status === 'payment_rejected';
      var link = upi.upiId ? 'upi://pay?pa=' + encodeURIComponent(upi.upiId) + '&pn=' + encodeURIComponent(upi.payeeName) + '&am=' + total + '&cu=INR&tn=' + encodeURIComponent(o.number) : '';
      var rej = o.status === 'payment_rejected' ? (o.timeline.slice().reverse().filter(function (t) { return t.status === 'payment_rejected'; })[0] || {}).note : '';
      var proofImg = o.proof ? '<a class="proofprev" href="/api/orders/' + o.id + '/proof" target="_blank" rel="noopener"><img src="/api/orders/' + o.id + '/proof?t=' + o.proof.at + '" alt="Your uploaded payment screenshot" loading="lazy"></a>' : '';
      if (!needs) {
        mount.innerHTML = '<div class="payok pay--' + TONE[o.status] + '"><span class="payok__ico" aria-hidden="true">' + U.icon(o.status === 'payment_review' ? 'ret' : 'check') + '</span><div><strong>' + (o.status === 'payment_review' ? 'Screenshot received — we’re verifying your payment' : o.status === 'cancelled' ? 'This order was cancelled' : 'Payment verified — thank you!') + '</strong><p class="muted">' + (o.status === 'payment_review' ? 'This usually takes a short while during store hours. You’ll see the status change here.' : o.status === 'cancelled' ? '' : 'Our artisans will start on your order.') + '</p></div>' + proofImg + '</div>';
        return;
      }
      mount.innerHTML = '<div class="pay">' +
        (rej ? '<p class="pay__alert" role="alert">' + U.icon('close', 'ico--xs') + '<span><strong>We couldn’t verify your payment.</strong> ' + esc(rej) + '</span></p>' : '') +
        '<div class="pay__grid"><div class="pay__qr"><figure class="qrcard"><img src="' + esc(upi.qrUrl) + '" alt="UPI payment QR code for ' + esc(upi.payeeName) + '" width="320" height="320"><span class="qrcard__scan" aria-hidden="true"></span><i class="qrcard__c qrcard__c--tl"></i><i class="qrcard__c qrcard__c--tr"></i><i class="qrcard__c qrcard__c--bl"></i><i class="qrcard__c qrcard__c--br"></i></figure>' +
        (upi.isDemo ? '<p class="pay__demo">Demo QR — the store owner hasn’t added their QR yet.</p>' : '<p class="muted">Scan with any UPI app — Google Pay, PhonePe, Paytm, BHIM…</p>') +
        (link ? '<a class="btn btn--gold btn--block pay__app" href="' + esc(link) + '">Open my UPI app</a>' : '') + '</div>' +
        '<div class="pay__info"><p class="pay__amt"><span>Pay exactly</span><strong>' + money(total) + '</strong></p>' +
        '<dl class="pay__dl"><div><dt>Pay to</dt><dd>' + esc(upi.payeeName) + '</dd></div>' + (upi.upiId ? '<div><dt>UPI ID</dt><dd><code>' + esc(upi.upiId) + '</code> <button type="button" class="copy" data-copy="' + esc(upi.upiId) + '">Copy</button></dd></div>' : '') + '<div><dt>Note / reference</dt><dd><code>' + esc(o.number) + '</code> <button type="button" class="copy" data-copy="' + esc(o.number) + '">Copy</button></dd></div></dl>' +
        '<p class="pay__how">' + esc(upi.instructions) + '</p>' +
        '<form class="pay__form" novalidate><h3 class="h3">Upload your payment screenshot</h3>' +
        '<label class="drop" data-drop><input type="file" name="file" accept="image/jpeg,image/png,image/webp" required><span class="drop__ico" aria-hidden="true">' + U.icon('plus') + '</span><span class="drop__t"><strong>Tap to choose</strong> or drop an image here<small>JPG, PNG or WebP · up to 6 MB</small></span><img class="drop__prev" alt="" hidden></label>' +
        '<div class="field"><label class="field__l" for="utr">Transaction / UTR number <span class="muted">(optional, helps us verify faster)</span></label><input class="input" id="utr" name="utr" inputmode="text" autocomplete="off" autocapitalize="characters" maxlength="30" placeholder="e.g. 4123 4567 8901"></div>' +
        '<div class="bar" hidden><span></span></div><p class="field__err" role="alert"></p>' +
        '<button class="btn btn--block btn--lg" type="submit"><span>Submit payment proof</span></button></form></div></div></div>';
      bind(upi);
    }
    function bind() {
      $$('[data-copy]', mount).forEach(function (b) { b.addEventListener('click', function () { copy(b.getAttribute('data-copy'), b); }); });
      var f = $('.pay__form', mount), inp = $('[type=file]', f), drop = $('[data-drop]', f), prev = $('.drop__prev', f), err = $('.field__err', f), bar = $('.bar', f), btn = $('[type=submit]', f), picked = null;
      function pick(file) {
        err.textContent = ''; if (!file) return;
        if (!/^image\/(jpeg|png|webp)$/.test(file.type)) { err.textContent = 'Please choose a JPG, PNG or WebP screenshot.'; return; }
        if (file.size > 25e6) { err.textContent = 'That image is too large. Please choose a smaller screenshot.'; return; }
        picked = file; prev.src = URL.createObjectURL(file); prev.hidden = false; drop.classList.add('has-file'); $('.drop__t strong', drop).textContent = file.name.length > 28 ? file.name.slice(0, 25) + '…' : file.name;
      }
      inp.addEventListener('change', function () { pick(inp.files[0]); });
      ['dragenter', 'dragover'].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.add('is-over'); }); });
      ['dragleave', 'drop'].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.remove('is-over'); if (ev === 'drop' && e.dataTransfer.files[0]) { try { inp.files = e.dataTransfer.files; } catch (x) { /* ignore */ } pick(e.dataTransfer.files[0]); } }); });
      f.addEventListener('submit', function (e) {
        e.preventDefault(); err.textContent = '';
        if (!picked) { err.textContent = 'Please choose your payment screenshot first.'; inp.focus(); return; }
        var utr = $('[name=utr]', f).value.replace(/\s/g, ''); if (utr && utr.length < 6) { err.textContent = 'That reference looks too short — leave it blank if unsure.'; return; }
        btn.disabled = true; btn.classList.add('is-busy'); bar.hidden = false;
        compress(picked).then(function (blob) {
          var fd = new FormData(); fd.append('utr', utr); fd.append('file', blob, 'payment-proof.' + (blob.type === 'image/png' ? 'png' : blob.type === 'image/webp' ? 'webp' : 'jpg'));
          return U.upload('/api/orders/' + order.id + '/proof', fd, function (p) { $('span', bar).style.width = Math.round(p * 100) + '%'; });
        }).then(function (r) { order = r.order; U.toast('Screenshot received'); config().then(function (c) { render(c.upi); }); if (onUpdate) onUpdate(order); }, function (er) { btn.disabled = false; btn.classList.remove('is-busy'); bar.hidden = true; err.textContent = er.message; });
      });
    }
  }
  /* Big, shareable order number — the thing a guest needs to remember */
  function numberCard(o, mount, note) {
    var digits = String(o.number).replace(/^AS-?/i, ''), url = location.origin + '/track.html?n=' + encodeURIComponent(digits), canShare = !!navigator.share;
    mount.innerHTML = '<div class="numcard"><div class="numcard__main"><span class="numcard__l">Your order number</span><strong class="numcard__n" aria-label="Order number ' + esc(o.number.split('').join(' ')) + '">' + esc(o.number) + '</strong><small>' + (note || 'Keep this number. With your mobile number it’s all you need to check your order status — no sign-in required.') + '</small></div>' +
      '<div class="numcard__a"><button type="button" class="copy" data-copy="' + esc(o.number) + '">Copy</button>' + (canShare ? '<button type="button" class="copy" data-share>Share</button>' : '') + '<a class="btn btn--ghost" href="track.html?n=' + esc(digits) + '">Track order</a></div></div>';
    $$('[data-copy]', mount).forEach(function (b) { b.addEventListener('click', function () { copy(b.getAttribute('data-copy'), b); }); });
    var sh = $('[data-share]', mount); if (sh) sh.addEventListener('click', function () { navigator.share({ title: 'My ASINGH order ' + o.number, text: 'My ASINGH order number is ' + o.number + '. Track it here:', url: url }).catch(function () {}); });
  }
  function trackingCard(t) {
    if (!t || (!t.courier && !t.id && !t.url)) return '';
    return '<div class="trackcard"><span class="trackcard__ico" aria-hidden="true">' + U.icon('truck') + '</span><div><strong>' + esc(t.courier || 'Courier') + '</strong>' + (t.id ? '<span>Tracking ID <code>' + esc(t.id) + '</code> <button type="button" class="copy" data-copy="' + esc(t.id) + '">Copy</button></span>' : '') + (t.url ? '<a class="link" href="' + esc(t.url) + '" target="_blank" rel="noopener noreferrer">Track shipment ↗</a>' : '') + '</div></div>';
  }
  A.Orders = { numberCard: numberCard, trackingCard: trackingCard, copy: copy, LABEL: LABEL, chip: chip, timeline: timeline, items: itemsHTML, payPanel: payPanel, config: config, fmtDate: fmtDate, tone: TONE };
})(window.ASINGH);
