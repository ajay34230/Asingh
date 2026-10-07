/* Page modules: home, shop, product, cart, checkout. */
(function () {
  'use strict';
  var A = window.ASINGH, U = A.U, $ = U.$, $$ = U.$$, money = U.money, esc = U.esc, Cart = U.Cart, Sheet = U.Sheet, byId = U.byId, sById = U.stitchById;
  var page = document.body.getAttribute('data-page');
  var mqChange = function (mq, f) { mq.addEventListener ? mq.addEventListener('change', f) : mq.addListener(f); };

  /* ================= HOME ================= */
  function home() {
    var list = A.PRODUCTS.slice().sort(function (a, b) { return (b.isNew - a.isNew); }).slice(0, 8);
    $('#new-grid').innerHTML = list.map(function (p) { return U.card(p); }).join('');
    $('#best-track').innerHTML = A.PRODUCTS.filter(function (p) { return p.best; }).map(function (p) { return '<div class="rail__item">' + U.card(p, { sizes: '(min-width:1100px) 22vw, (min-width:700px) 31vw, 60vw' }) + '</div>'; }).join('');
    var cols = [['Bridal lehengas', 'lehengas'], ['Festive anarkalis', 'anarkalis'], ['Heritage sarees', 'sarees'], ['Everyday suits', 'suits']];
    $('#collections-track').innerHTML = cols.map(function (c, i) {
      return '<li class="rail__item"><a class="tile" href="shop.html?cat=' + c[1] + '">' + U.picture('collection', i + 1, { w: 1200, h: 1200, sizes: '(min-width:1100px) 24vw, (min-width:700px) 46vw, 72vw', alt: '' }) + '<span class="tile__cap"><span class="tile__n">0' + (i + 1) + '</span>' + c[0] + U.icon('right', 'ico--sm') + '</span></a></li>';
    }).join('');
    U.bindRails(document);
    // Scroll-reveal for the made-to-measure story; content is visible by default without JS or with reduced motion.
    var els = $$('[data-reveal]');
    if ('IntersectionObserver' in window && !U.reduceMotion.matches) {
      document.documentElement.classList.add('reveal-on');
      var io = new IntersectionObserver(function (en) { en.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); } }); }, { threshold: 0.15 });
      els.forEach(function (e) { io.observe(e); });
    }
  }

  /* ================= SHOP ================= */
  function shop() {
    var colors = []; A.PRODUCTS.forEach(function (p) { p.colors.forEach(function (c) { if (!colors.some(function (x) { return x.name === c.name; })) colors.push(c); }); });
    colors.sort(function (a, b) { return a.name.localeCompare(b.name); });
    var KEYS = ['cat', 'occ', 'price', 'color', 'stitch'];
    var LABELS = { cat: {}, occ: {}, price: {}, color: {}, stitch: {} };
    A.CATEGORIES.forEach(function (c) { LABELS.cat[c.id] = c.label; });
    A.OCCASIONS.forEach(function (c) { LABELS.occ[c.id] = c.label; });
    A.PRICE_BANDS.forEach(function (c) { LABELS.price[c.id] = c.label; });
    colors.forEach(function (c) { LABELS.color[c.name] = c.name; });
    A.STITCH.forEach(function (c) { LABELS.stitch[c.id] = c.label; });

    var filtersEl = $('#filters'), form = $('#filter-form'), grid = $('#grid'), count = $('#count'), chipsEl = $('#applied'), sortEl = $('#sort'), applyBtn = $('#apply');
    var group = function (key, title, items, open) {
      return '<details class="fgroup"' + (open ? ' open' : '') + '><summary>' + title + '</summary><div class="fgroup__body">' + items.map(function (i) {
        return '<label class="check"><input type="checkbox" name="' + key + '" value="' + esc(i.id) + '"><span class="check__box" aria-hidden="true">' + U.icon('check') + '</span>' +
          (i.hex ? '<span class="swatch" style="background:' + i.hex + '" aria-hidden="true"></span>' : '') + '<span>' + i.label + '</span></label>';
      }).join('') + '</div></details>';
    };
    form.innerHTML =
      group('cat', 'Category', A.CATEGORIES, true) + group('price', 'Price', A.PRICE_BANDS, true) +
      group('stitch', 'Stitching', A.STITCH, true) + group('occ', 'Occasion', A.OCCASIONS, false) +
      group('color', 'Colour', colors.map(function (c) { return { id: c.name, label: c.name, hex: c.hex }; }), false);

    function readURL() {
      var u = new URLSearchParams(location.search), s = { q: u.get('q') || '', sort: u.get('sort') || 'featured', wishlist: u.get('wishlist') === '1' };
      KEYS.forEach(function (k) { s[k] = (u.get(k) || '').split(',').filter(Boolean); });
      return s;
    }
    function readForm() {
      var s = { q: state.q, sort: sortEl.value, wishlist: state.wishlist };
      KEYS.forEach(function (k) { s[k] = $$('[name="' + k + '"]:checked', form).map(function (i) { return i.value; }); });
      return s;
    }
    function writeForm(s) { $$('input[type=checkbox]', form).forEach(function (i) { i.checked = s[i.name].indexOf(i.value) > -1; }); sortEl.value = s.sort; }
    function match(p, s) {
      if (s.wishlist && !Cart.isWish(p.id)) return false;
      if (s.q && !A.search(s.q).some(function (x) { return x.id === p.id; })) return false;
      if (s.cat.length && s.cat.indexOf(p.cat) < 0) return false;
      if (s.occ.length && !p.occ.some(function (o) { return s.occ.indexOf(o) > -1; })) return false;
      if (s.stitch.length && !p.stitch.some(function (o) { return s.stitch.indexOf(o) > -1; })) return false;
      if (s.color.length && !p.colors.some(function (c) { return s.color.indexOf(c.name) > -1; })) return false;
      if (s.price.length && !A.PRICE_BANDS.some(function (b) { return s.price.indexOf(b.id) > -1 && p.price >= b.min && p.price < b.max; })) return false;
      return true;
    }
    function sorted(list, sort) {
      var l = list.slice();
      var f = { new: function (a, b) { return (b.isNew - a.isNew); }, 'price-asc': function (a, b) { return a.price - b.price; }, 'price-desc': function (a, b) { return b.price - a.price; }, rating: function (a, b) { return b.rating - a.rating; }, featured: function (a, b) { return (b.best - a.best); } }[sort];
      return f ? l.sort(f) : l;
    }
    var state = readURL();
    function render() {
      var res = sorted(A.PRODUCTS.filter(function (p) { return match(p, state); }), state.sort);
      var title = state.wishlist ? 'Your wishlist' : state.q ? 'Results for “' + state.q + '”' : (state.cat.length === 1 ? LABELS.cat[state.cat[0]] : 'All collections');
      $('#shop-title').textContent = title; document.title = title + ' — ' + A.BRAND;
      count.textContent = res.length + (res.length === 1 ? ' piece' : ' pieces');
      grid.innerHTML = res.length ? res.map(function (p) { return U.card(p); }).join('') :
        '<div class="empty empty--grid"><p class="empty__title">' + (state.wishlist ? 'Nothing saved yet' : 'No pieces match your filters') + '</p><p>' + (state.wishlist ? 'Tap the heart on any piece to save it here.' : 'Try removing a filter or two.') + '</p>' + (state.wishlist ? '<a class="btn" href="shop.html">Browse the collection</a>' : '<button type="button" class="btn" data-clear>Clear all filters</button>') + '</div>';
      var chips = []; KEYS.forEach(function (k) { state[k].forEach(function (v) { chips.push('<li><button type="button" class="pill pill--x" data-rm="' + k + '|' + esc(v) + '" aria-label="Remove filter ' + esc(LABELS[k][v] || v) + '">' + esc(LABELS[k][v] || v) + U.icon('close', 'ico--xs') + '</button></li>'); }); });
      if (state.q) chips.push('<li><button type="button" class="pill pill--x" data-rm="q|" aria-label="Remove search ' + esc(state.q) + '">“' + esc(state.q) + '”' + U.icon('close', 'ico--xs') + '</button></li>');
      chipsEl.innerHTML = chips.length ? chips.join('') + '<li><button type="button" class="link" data-clear>Clear all</button></li>' : '';
      chipsEl.hidden = !chips.length;
      var n = chips.length - (state.q ? 1 : 0); var fb = $('#filter-open'); fb.querySelector('.count').textContent = n; fb.querySelector('.count').hidden = !n;
      applyBtn.textContent = 'Show ' + res.length + ' piece' + (res.length === 1 ? '' : 's');
    }
    function commit(s) {
      state = s;
      var u = new URLSearchParams(); KEYS.forEach(function (k) { if (s[k].length) u.set(k, s[k].join(',')); });
      if (s.q) u.set('q', s.q); if (s.sort !== 'featured') u.set('sort', s.sort); if (s.wishlist) u.set('wishlist', '1');
      history.replaceState(null, '', location.pathname + (u.toString() ? '?' + u : ''));
      render();
    }
    function preview() { var s = readForm(); var n = A.PRODUCTS.filter(function (p) { return match(p, s); }).length; applyBtn.textContent = 'Show ' + n + ' piece' + (n === 1 ? '' : 's'); }
    function syncMode() {
      var inline = U.mqDesktop.matches;
      if (inline) { Sheet.close('filters'); filtersEl.removeAttribute('aria-hidden'); filtersEl.removeAttribute('role'); filtersEl.removeAttribute('aria-modal'); }
      else if (!filtersEl.classList.contains('is-open')) filtersEl.setAttribute('aria-hidden', 'true');
      $$('.fgroup', form).forEach(function (d) { if (inline) d.open = true; });
    }
    form.addEventListener('change', function () { if (U.mqDesktop.matches) commit(readForm()); else preview(); });
    sortEl.addEventListener('change', function () { commit(readForm()); });
    applyBtn.addEventListener('click', function () { commit(readForm()); Sheet.close('filters'); });
    document.addEventListener('click', function (e) {
      var rm = e.target.closest('[data-rm]');
      if (rm) { var kv = rm.getAttribute('data-rm').split('|'), s = readFromState(); if (kv[0] === 'q') s.q = ''; else s[kv[0]] = s[kv[0]].filter(function (x) { return x !== kv[1]; }); writeForm(s); commit(s); }
      if (e.target.closest('[data-clear]')) { var c = { q: '', sort: state.sort, wishlist: false }; KEYS.forEach(function (k) { c[k] = []; }); writeForm(c); commit(c); if (!U.mqDesktop.matches) preview(); }
    });
    function readFromState() { var s = { q: state.q, sort: state.sort, wishlist: state.wishlist }; KEYS.forEach(function (k) { s[k] = state[k].slice(); }); return s; }
    A.onWishChange = function () { if (state.wishlist) render(); };
    mqChange(U.mqDesktop, syncMode);
    writeForm(state); syncMode(); render();
    $('#filter-clear-sheet').addEventListener('click', function () { var c = { q: state.q, sort: state.sort, wishlist: false }; KEYS.forEach(function (k) { c[k] = []; }); writeForm(c); preview(); });
    document.addEventListener('sheetclose', function (e) { if (e.detail === 'filters') writeForm(state); });
  }

  /* ================= PRODUCT ================= */
  function product() {
    var id = new URLSearchParams(location.search).get('id'), p = byId[id] || A.PRODUCTS[0];
    document.title = p.name + ' — ' + A.BRAND;
    var cat = A.CATEGORIES.filter(function (c) { return c.id === p.cat; })[0];
    var slides = [1, 2, 3].map(function (n) {
      return '<li class="gal__slide" id="slide-' + n + '"><button type="button" class="gal__zoom" data-zoom="' + n + '" aria-label="Zoom image ' + n + ' of 3">' +
        U.picture(p.id, n, { sizes: '(min-width:1100px) 46vw, (min-width:700px) 60vw, 100vw', alt: p.name + ' — ' + ['full view', 'fabric detail', 'flat lay'][n - 1], eager: n === 1 }) + '<span class="gal__hint" aria-hidden="true">' + U.icon('zoom') + '</span></button></li>';
    }).join('');
    var wish = Cart.isWish(p.id);
    $('#pdp').innerHTML =
      '<div class="pdp__gallery"><ul class="gal" id="gal" tabindex="0" aria-label="Product images — swipe or scroll">' + slides + '</ul>' +
      '<div class="gal__dots" role="group" aria-label="Choose image">' + [1, 2, 3].map(function (n) { return '<button type="button" class="gal__dot" data-slide="' + n + '" aria-label="Show image ' + n + '"' + (n === 1 ? ' aria-current="true"' : '') + '></button>'; }).join('') + '</div></div>' +
      '<div class="pdp__info"><p class="eyebrow"><a href="shop.html?cat=' + p.cat + '">' + cat.label + '</a></p>' +
      '<h1 class="pdp__title">' + esc(p.name) + '</h1>' +
      '<div class="pdp__price" id="pdp-price"></div>' +
      '<p class="pdp__rating"><a href="#reviews">' + U.stars(p.rating) + ' <span>' + p.rating.toFixed(1) + ' · ' + p.reviews + ' reviews</span></a></p>' +
      '<p class="pdp__blurb">' + esc(p.blurb) + '</p>' +
      '<form id="buy" novalidate>' +
      '<fieldset class="field"><legend class="field__l">Colour: <strong id="color-name">' + esc(p.colors[0].name) + '</strong></legend><div class="swatches">' + p.colors.map(function (c, i) {
        return '<label class="sw"><input type="radio" name="color" value="' + esc(c.name) + '"' + (i === 0 ? ' checked' : '') + '><span class="sw__dot" style="background:' + c.hex + '"></span><span class="vh">' + esc(c.name) + '</span></label>'; }).join('') + '</div></fieldset>' +
      '<fieldset class="field"><legend class="field__l">Stitching status</legend>' + U.stitchRadios(p, 'stitch') + '</fieldset>' +
      '<section class="field" aria-labelledby="inc-h"><h2 class="field__l" id="inc-h">What’s included</h2><ul class="ticks">' + p.inc.map(function (i) { return '<li>' + U.icon('check', 'ico--xs') + esc(i) + '</li>'; }).join('') + '</ul></section>' +
      '<fieldset class="field" id="size-field"><legend class="field__l">Size <button type="button" class="link" data-size-guide>Size guide</button></legend>' + U.sizeRadios('size') + '<p class="field__err" id="size-err" role="alert" hidden>Please choose a size to continue.</p></fieldset>' +
      '<div class="field"><label class="field__l" for="note">Customisation <span class="muted">(optional)</span></label><textarea class="input" id="note" name="note" rows="3" maxlength="240" placeholder="Height, sleeve length, blouse back style, monogram…" autocomplete="off"></textarea></div>' +
      '<section class="field ship" aria-labelledby="ship-h"><h2 class="field__l" id="ship-h">Shipping</h2><div class="ship__row"><label class="vh" for="pin">PIN code</label><input class="input" id="pin" name="pin" inputmode="numeric" autocomplete="postal-code" maxlength="6" pattern="[1-9][0-9]{5}" placeholder="Enter PIN code"><button class="btn btn--ghost" type="button" id="pin-check">Check</button></div><p class="ship__msg" id="ship-msg" role="status" aria-live="polite">' + U.icon('truck', 'ico--xs') + ' Free shipping over ' + money(A.FREE_SHIP_FROM) + '. Easy 7-day returns on unstitched pieces.</p></section>' +
      '<div class="pdp__cta"><button class="btn btn--lg btn--grow" type="submit" id="add-btn">Add to bag</button><button type="button" class="icon-btn icon-btn--bordered" data-wish="' + p.id + '" aria-pressed="' + wish + '" aria-label="' + (wish ? 'Remove from' : 'Add to') + ' wishlist">' + U.icon('heart') + '</button></div></form>' +
      '<div class="pdp__acc"><details open><summary>Details &amp; care</summary><ul class="bullets">' + p.details.map(function (d) { return '<li>' + esc(d) + '</li>'; }).join('') + '</ul></details>' +
      '<details><summary>Shipping &amp; returns</summary><p>Unstitched and semi-stitched pieces can be returned within 7 days. Custom-stitched pieces are made to order and are not returnable, but we offer one complimentary alteration.</p></details></div></div>';

    var rev = '<h2 class="h2" id="reviews-h">Reviews</h2><div class="reviews__sum"><p class="reviews__score">' + p.rating.toFixed(1) + '</p><div>' + U.stars(p.rating) + '<p class="muted">Based on ' + p.reviews + ' reviews</p></div></div><ul class="reviews__list">' +
      A.REVIEWS.map(function (r) { return '<li class="review"><p>' + U.stars(r.stars) + '</p><h3>' + esc(r.title) + '</h3><p>' + esc(r.body) + '</p><p class="muted">' + esc(r.who) + ', ' + esc(r.city) + '</p></li>'; }).join('') + '</ul><p class="muted">Sample reviews shown for demonstration.</p>';
    $('#reviews').innerHTML = rev;
    var rel = A.PRODUCTS.filter(function (x) { return x.id !== p.id; }).sort(function (a, b) { return (b.cat === p.cat) - (a.cat === p.cat) || b.rating - a.rating; }).slice(0, 8);
    $('#related-track').innerHTML = rel.map(function (x) { return '<div class="rail__item">' + U.card(x, { sizes: '(min-width:1100px) 22vw, (min-width:700px) 31vw, 60vw' }) + '</div>'; }).join('');
    U.bindRails(document);

    var buy = $('#buy'), priceEl = $('#pdp-price'), sticky = $('#sticky-buy');
    function curStitch() { return sById[buy.querySelector('[name=stitch]:checked').value]; }
    function price() { var html = U.priceHTML(p, curStitch().add); priceEl.innerHTML = html; $('#sticky-price').innerHTML = html; }
    price();
    buy.addEventListener('change', function (e) {
      if (e.target.name === 'color') $('#color-name').textContent = e.target.value;
      if (e.target.name === 'stitch') { price(); updateShip(); }
      if (e.target.name === 'size') $('#size-err').hidden = true;
    });
    function updateShip() { if ($('#ship-msg').getAttribute('data-ok')) checkPin(); }
    function checkPin() {
      var pin = $('#pin'), msg = $('#ship-msg');
      if (!/^[1-9][0-9]{5}$/.test(pin.value)) { pin.setAttribute('aria-invalid', 'true'); msg.removeAttribute('data-ok'); msg.textContent = 'Please enter a valid 6-digit PIN code.'; return; }
      pin.removeAttribute('aria-invalid');
      var r = { unstitched: [5, 8], semi: [7, 11], custom: [13, 19] }[curStitch().id], f = function (d) { var t = new Date(); t.setDate(t.getDate() + d); return t.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }); };
      msg.setAttribute('data-ok', '1'); msg.textContent = 'Delivery to ' + pin.value + ' between ' + f(r[0]) + ' – ' + f(r[1]) + '.';
    }
    $('#pin-check').addEventListener('click', checkPin);
    $('#pin').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); checkPin(); } });
    function needSize() { var f = $('#size-field'); $('#size-err').hidden = false; f.scrollIntoView({ block: 'center', behavior: U.reduceMotion.matches ? 'auto' : 'smooth' }); setTimeout(function () { buy.querySelector('[name=size]').focus({ preventScroll: true }); }, 250); }
    buy.addEventListener('submit', function (e) {
      e.preventDefault();
      var size = buy.querySelector('[name=size]:checked'); if (!size) { needSize(); return; }
      Cart.add(p.id, { size: size.value, stitch: curStitch().id, color: buy.querySelector('[name=color]:checked').value, note: $('#note').value.trim() });
      U.afterAdd();
    });
    $('#sticky-add').addEventListener('click', function () { buy.requestSubmit ? buy.requestSubmit() : buy.dispatchEvent(new Event('submit', { cancelable: true })); });
    // Sticky purchase bar: shown while the main Add button is out of view (small screens only via CSS).
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (en) { sticky.classList.toggle('is-on', !en[0].isIntersecting); }, { threshold: 0.01 }).observe($('#add-btn'));
    } else sticky.classList.add('is-on');
    // Gallery dots follow the swipe position.
    var gal = $('#gal'), dots = $$('.gal__dot');
    gal.addEventListener('scroll', function () { var i = Math.round(gal.scrollLeft / gal.clientWidth); dots.forEach(function (d, k) { if (k === i) d.setAttribute('aria-current', 'true'); else d.removeAttribute('aria-current'); }); }, { passive: true });
    dots.forEach(function (d) { d.addEventListener('click', function () { var n = +d.getAttribute('data-slide') - 1; gal.scrollTo({ left: n * gal.clientWidth, behavior: U.reduceMotion.matches ? 'auto' : 'smooth' }); }); });
    // Zoom lightbox (tap/click/keyboard — hover is never the only way to inspect an image)
    var lb = $('#lightbox'), lbImg = $('#lb-img'), cur = 1;
    function showLb(n) { cur = (n + 2) % 3 + 1; lbImg.innerHTML = U.picture(p.id, cur, { sizes: '(min-width:1100px) 120vw, 200vw', alt: p.name + ' — image ' + cur + ' of 3', eager: true }); $('#lb-count').textContent = cur + ' / 3'; $('.lightbox__scroll', lb).scrollTo(0, 0); }
    document.addEventListener('click', function (e) { var z = e.target.closest('[data-zoom]'); if (z) { showLb(+z.getAttribute('data-zoom')); Sheet.open('lightbox', z); } });
    $('#lb-prev').addEventListener('click', function () { showLb(cur - 1); }); $('#lb-next').addEventListener('click', function () { showLb(cur + 1); });
  }

  /* ================= CART PAGE ================= */
  function cartPage() {
    var list = $('#cart-list'), side = $('#cart-side'), bar = $('#cart-bar');
    function render() {
      if (!Cart.items.length) { list.innerHTML = U.emptyCart(); side.hidden = true; bar.hidden = true; return; }
      side.hidden = false; bar.hidden = false;
      list.innerHTML = '<ul class="lines lines--page">' + Cart.items.map(function (i) { return U.line(i); }).join('') + '</ul>';
      side.innerHTML = '<h2 class="h3">Order summary</h2>' + U.shipMeter() + U.totalsHTML() + '<a class="btn btn--block btn--lg" href="checkout.html">Checkout</a><p class="secure">' + U.icon('lock', 'ico--xs') + ' Secure checkout · Easy returns on unstitched pieces</p>';
      bar.innerHTML = '<div><span class="muted">Total</span><strong>' + money(Cart.total()) + '</strong></div><a class="btn btn--lg" href="checkout.html">Checkout</a>';
    }
    Cart.subscribe(render);
  }

  /* ================= CHECKOUT ================= */
  var STATES = ['Andhra Pradesh', 'Assam', 'Bihar', 'Chandigarh', 'Chhattisgarh', 'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Odisha', 'Punjab', 'Rajasthan', 'Tamil Nadu', 'Telangana', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'];
  function checkout() {
    var form1 = $('#step-details'), form2 = $('#step-pay'), done = $('#step-done'), steps = $$('.progress li'), sum = $('#summary');
    var order = $('#order-lines');
    $('#state').insertAdjacentHTML('beforeend', STATES.map(function (s) { return '<option>' + s + '</option>'; }).join(''));
    function renderSummary() {
      var n = Cart.count();
      order.innerHTML = '<ul class="lines lines--mini">' + Cart.items.map(function (i) {
        var p = byId[i.id];
        return '<li class="line line--mini"><a class="line__img" href="product.html?id=' + p.id + '" tabindex="-1" aria-hidden="true">' + U.picture(p.id, 1, { sizes: '72px', alt: '' }) + '<span class="line__qty">' + i.qty + '</span></a><div class="line__info"><p class="line__name">' + esc(p.name) + '</p><p class="line__meta">Size ' + esc(i.size) + ' · ' + esc(sById[i.stitch].label) + '</p></div><span class="line__price">' + money(Cart.unit(i) * i.qty) + '</span></li>';
      }).join('') + '</ul>' + U.totalsHTML();
      $('#sum-total').textContent = money(Cart.total()); $('#pay-total').textContent = money(Cart.total());
      $('#sum-count').textContent = n + ' item' + (n === 1 ? '' : 's');
    }
    var finished = false;
    Cart.subscribe(function () { if (finished) return; if (!Cart.items.length) { $('#co-empty').hidden = false; $('#co-main').hidden = true; } else { $('#co-empty').hidden = true; $('#co-main').hidden = false; renderSummary(); } });
    var syncSum = function () { sum.open = U.mqDesktop.matches || window.matchMedia('(min-width: 900px)').matches; };
    syncSum(); mqChange(window.matchMedia('(min-width: 900px)'), syncSum);

    var RULES = {
      email: { test: function (v) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v); }, msg: 'Enter a valid email, e.g. name@example.com' },
      phone: { test: function (v) { return /^(\+91[\s-]?)?[6-9][0-9]{9}$/.test(v.replace(/\s|-/g, '')) || /^(\+91)?[6-9][0-9]{9}$/.test(v.replace(/\s|-/g, '')); }, msg: 'Enter a 10-digit mobile number' },
      name: { test: function (v) { return v.trim().length >= 2; }, msg: 'Enter your full name' },
      line1: { test: function (v) { return v.trim().length >= 5; }, msg: 'Enter your house, building and street' },
      pin: { test: function (v) { return /^[1-9][0-9]{5}$/.test(v); }, msg: 'Enter a valid 6-digit PIN code' },
      city: { test: function (v) { return v.trim().length >= 2; }, msg: 'Enter your city' },
      state: { test: function (v) { return !!v; }, msg: 'Choose your state' }
    };
    function check(inp) {
      var r = RULES[inp.name]; if (!r) return true;
      var ok = r.test(inp.value.trim()), err = document.getElementById(inp.id + '-err');
      inp.setAttribute('aria-invalid', ok ? 'false' : 'true'); err.textContent = ok ? '' : r.msg; return ok;
    }
    form1.addEventListener('focusout', function (e) { if (e.target.name && RULES[e.target.name] && e.target.value) check(e.target); });
    form1.addEventListener('input', function (e) { if (e.target.getAttribute('aria-invalid') === 'true') check(e.target); });
    function go(n) {
      form1.hidden = n !== 1; form2.hidden = n !== 2; done.hidden = n !== 3;
      steps.forEach(function (s, i) { s.classList.toggle('is-done', i + 1 < n); if (i + 1 === n) s.setAttribute('aria-current', 'step'); else s.removeAttribute('aria-current'); });
      $('.checkout__aside').hidden = n === 3; var h = (n === 1 ? form1 : n === 2 ? form2 : done).querySelector('h2'); h.setAttribute('tabindex', '-1'); h.focus({ preventScroll: true });
      window.scrollTo({ top: Math.max(0, $('.progress').getBoundingClientRect().top + window.scrollY - 80), behavior: U.reduceMotion.matches ? 'auto' : 'smooth' });
    }
    form1.addEventListener('submit', function (e) {
      e.preventDefault();
      var bad = $$('input[name],select[name]', form1).filter(function (i) { return !check(i); });
      if (bad.length) { $('#form-err').textContent = 'Please fix ' + bad.length + ' field' + (bad.length > 1 ? 's' : '') + ' to continue.'; bad[0].focus(); return; }
      $('#form-err').textContent = ''; $('#ship-to').textContent = [$('#name').value, $('#line1').value, $('#city').value + ' ' + $('#pin').value].join(', '); go(2);
    });
    $('#back-1').addEventListener('click', function () { go(1); });
    form2.addEventListener('submit', function (e) {
      e.preventDefault();
      var no = 'AS' + Date.now().toString().slice(-8);
      $('#order-no').textContent = no; $('#order-email').textContent = $('#email').value;
      finished = true; Cart.clear(); go(3);
    });
    $$('.paymethod input', form2).forEach(function (i) { i.addEventListener('change', function () { $('#pay-note').textContent = i.value === 'cod' ? 'Pay in cash or by UPI when your order arrives.' : 'You’ll be taken to our secure payment partner to complete this payment.'; }); });
  }

  ({ home: home, shop: shop, product: product, cart: cartPage, checkout: checkout }[page] || function () {})();
})();
