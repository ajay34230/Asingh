/* Page modules: home, shop, product, cart, checkout. */
(function () {
  'use strict';
  var A = window.ASINGH, U = A.U, api = U.api, $ = U.$, $$ = U.$$, money = U.money, esc = U.esc, Cart = U.Cart, Sheet = U.Sheet, byId = U.byId, sById = U.stitchById;
  var page = document.body.getAttribute('data-page');
  var mqChange = function (mq, f) { mq.addEventListener ? mq.addEventListener('change', f) : mq.addListener(f); };

  /* ================= HOME ================= */
  function home() {
    var empty = '<div class="empty empty--grid"><p class="empty__title">New pieces are on the way</p><p>Please check back soon.</p></div>';
    var list = A.PRODUCTS.slice().sort(function (a, b) { return (b.isNew - a.isNew); }).slice(0, 8);
    $('#new-grid').innerHTML = list.length ? list.map(function (p) { return U.card(p); }).join('') : empty;
    var best = A.PRODUCTS.filter(function (p) { return p.best; }); if (!best.length) best = A.PRODUCTS.slice(0, 6);
    $('#best-track').closest('section').hidden = !best.length;
    $('#best-track').innerHTML = best.map(function (p) { return '<div class="rail__item">' + U.card(p, { sizes: '(min-width:1100px) 22vw, (min-width:700px) 31vw, 60vw' }) + '</div>'; }).join('');
    // collection tiles: one per category that has products, using that category's first product photo
    var cols = A.CATEGORIES.map(function (c) { return { c: c, p: A.PRODUCTS.filter(function (x) { return x.cat === c.id; })[0] }; }).filter(function (x) { return x.p; });
    $('#collections-track').closest('section').hidden = !cols.length;
    $('#collections-track').innerHTML = cols.map(function (x, i) {
      return '<li class="rail__item"><a class="tile" href="shop.html?cat=' + x.c.id + '">' + U.picture(x.p.id, 1, { sizes: '(min-width:1100px) 24vw, (min-width:700px) 46vw, 72vw', alt: '' }) + '<span class="tile__cap"><span class="tile__n">' + (i < 9 ? '0' : '') + (i + 1) + '</span>' + esc(x.c.label) + U.icon('right', 'ico--sm') + '</span></a></li>';
    }).join('');
    var quotes = A.REVIEWS || []; $('#quotes-track').closest('section').hidden = !quotes.length;
    $('#quotes-track').innerHTML = quotes.map(function (r) {
      return '<li class="rail__item rail__item--quote"><figure class="quote"><span class="quote__mark" aria-hidden="true">“</span><p class="stars-row">' + U.stars(r.stars) + '</p><blockquote>' + esc(r.body) + '</blockquote><figcaption><strong>' + esc(r.who) + '</strong>' + (r.city ? ' · ' + esc(r.city) : '') + '</figcaption></figure></li>';
    }).join('');
    $$('.section__head .muted').forEach(function (m) { if (/Sample reviews/.test(m.textContent) && !A.PRODUCTS.some(function (p) { return p.demo; })) m.hidden = true; });
    U.bindRails(document); U.reveal(document);
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
    var PAGE = 24, shown = PAGE, lastKey = '', asked = {};
    function render() {
      var res = sorted(A.PRODUCTS.filter(function (p) { return match(p, state); }), state.sort);
      if (!res.length && state.q && !state.wishlist && !asked[state.q]) { asked[state.q] = 1; U.aiSearch(state.q).then(function (ids) { if (ids.length) render(); }); }
      var title = state.wishlist ? 'Your wishlist' : state.q ? 'Results for “' + state.q + '”' : (state.cat.length === 1 ? LABELS.cat[state.cat[0]] : 'All collections');
      $('#shop-title').textContent = title; document.title = title + ' — ' + A.BRAND;
      count.textContent = res.length + (res.length === 1 ? ' piece' : ' pieces');
      var key = JSON.stringify([state.q, state.sort, state.wishlist, KEYS.map(function (k) { return state[k]; })]); if (key !== lastKey) { shown = PAGE; lastKey = key; }
      var more = $('#more'); if (!more) { more = document.createElement('div'); more.id = 'more'; more.className = 'more'; grid.parentNode.insertBefore(more, grid.nextSibling); more.addEventListener('click', function (e) { if (e.target.closest('[data-more]')) { shown += PAGE; render(); } }); }
      more.innerHTML = res.length > shown ? '<p class="muted" role="status">Showing ' + shown + ' of ' + res.length + '</p><button type="button" class="btn btn--ghost" data-more>Show more</button>' : '';
      grid.innerHTML = res.length ? res.slice(0, shown).map(function (p) { return U.card(p); }).join('') :
        '<div class="empty empty--grid"><p class="empty__title">' + (state.wishlist ? 'Nothing saved yet' : 'No pieces match your filters') + '</p><p>' + (state.wishlist ? 'Tap the heart on any piece to save it here.' : 'Try removing a filter or two.') + '</p>' + (state.wishlist ? '<a class="btn" href="shop.html">Browse the collection</a>' : '<button type="button" class="btn" data-clear>Clear all filters</button>') + '</div>';
      var chips = []; KEYS.forEach(function (k) { state[k].forEach(function (v) { chips.push('<li><button type="button" class="pill pill--x" data-rm="' + k + '|' + esc(v) + '" aria-label="Remove filter ' + esc(LABELS[k][v] || v) + '">' + esc(LABELS[k][v] || v) + U.icon('close', 'ico--xs') + '</button></li>'); }); });
      if (state.q) chips.push('<li><button type="button" class="pill pill--x" data-rm="q|" aria-label="Remove search ' + esc(state.q) + '">“' + esc(state.q) + '”' + U.icon('close', 'ico--xs') + '</button></li>');
      chipsEl.innerHTML = chips.length ? chips.join('') + '<li><button type="button" class="link" data-clear>Clear all</button></li>' : '';
      chipsEl.hidden = !chips.length;
      var n = chips.length - (state.q ? 1 : 0); var fb = $('#filter-open'); fb.querySelector('.count').textContent = n; fb.querySelector('.count').hidden = !n;
      applyBtn.textContent = 'Show ' + res.length + ' piece' + (res.length === 1 ? '' : 's');
      U.reveal(grid);
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
    form.addEventListener('submit', function (e) { e.preventDefault(); });
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
  function notifyHtml(p) {
    var so = p.sizeOut || [], co = p.colorOut || []; if (!p.soldOut && !so.length && !co.length) return '';
    var u = U.Auth.user || {}, opts = function (list, ph) { return list.length ? '<select class="input input--select" name="' + ph + '"><option value="">Any ' + ph + '</option>' + list.map(function (x) { return '<option>' + esc(x) + '</option>'; }).join('') + '</select>' : ''; };
    return '<details class="notify" id="notify"' + (p.soldOut ? ' open' : '') + '><summary>' + (p.soldOut ? 'Notify me when it’s back' : 'Waiting for a sold-out size or colour?') + '</summary><form id="nf" novalidate><div class="field"><label class="field__l" for="nf-e">Email</label><input class="input" id="nf-e" name="email" type="email" autocomplete="email" value="' + esc(u.email || '') + '"></div><div class="field"><label class="field__l" for="nf-p">Mobile <span class="muted">(optional)</span></label><input class="input" id="nf-p" name="phone" inputmode="tel" autocomplete="tel"></div>' + (p.soldOut ? '' : opts(so, 'size') + opts(co, 'color')) + '<input type="text" name="website" class="hp" tabindex="-1" autocomplete="off" aria-hidden="true"><p class="field__err" id="nf-e2" role="alert"></p><button class="btn btn--ghost" type="submit"><span>Notify me</span></button></form></details>';
  }
  function product() {
    var id = new URLSearchParams(location.search).get('id'), p = byId[id];
    if (!p) { $('#pdp').innerHTML = '<div class="empty" style="grid-column:1/-1"><p class="empty__title">This piece isn’t available</p><p>It may have been removed or is not on sale right now.</p><a class="btn" href="shop.html">Browse the collection</a></div>'; $('#reviews').hidden = true; var rl = $('#rel-h'); if (rl) rl.closest('section').hidden = true; return; }
    document.title = p.name + ' — ' + A.BRAND;
    var N = p.nimg || 1, demoAlt = ['full view', 'fabric detail', 'flat lay'];
    var cat = A.CATEGORIES.filter(function (c) { return c.id === p.cat; })[0];
    var seq = []; for (var q = 1; q <= N; q++) seq.push(q);
    var slides = seq.map(function (n) {
      return '<li class="gal__slide" id="slide-' + n + '"><button type="button" class="gal__zoom" data-zoom="' + n + '" aria-label="Zoom image ' + n + ' of ' + N + '">' +
        U.picture(p.id, n, { sizes: '(min-width:1100px) 46vw, (min-width:700px) 60vw, 100vw', alt: p.name + (p.demo !== false && N === 3 ? ' — ' + demoAlt[n - 1] : N > 1 ? ' — photo ' + n : ''), eager: n === 1 }) + '<span class="gal__hint" aria-hidden="true">' + U.icon('zoom') + '</span></button></li>';
    }).join('');
    var wish = Cart.isWish(p.id);
    $('#pdp').innerHTML =
      '<div class="pdp__gallery"><ul class="gal" id="gal" tabindex="0" aria-label="Product images — swipe or scroll">' + slides + '</ul>' +
      (N > 1 ? '<div class="gal__dots" role="group" aria-label="Choose image">' : '<div hidden>') + seq.map(function (n) { return '<button type="button" class="gal__dot" data-slide="' + n + '" aria-label="Show image ' + n + '"' + (n === 1 ? ' aria-current="true"' : '') + '></button>'; }).join('') + '</div></div>' +
      '<div class="pdp__info"><p class="eyebrow"><a href="shop.html?cat=' + p.cat + '">' + cat.label + '</a></p>' +
      '<h1 class="pdp__title">' + esc(p.name) + '</h1>' +
      '<div class="pdp__price" id="pdp-price"></div>' +
      (p.rating ? '<p class="pdp__rating"><a href="#reviews">' + U.stars(p.rating) + ' <span>' + p.rating.toFixed(1) + (p.reviews ? ' · ' + p.reviews + ' reviews' : '') + '</span></a></p>' : '') +
      '<p class="pdp__blurb">' + esc(p.blurb) + '</p>' +
      '<form id="buy" novalidate>' +
      '<fieldset class="field"><legend class="field__l">Colour: <strong id="color-name">' + esc(p.colors[0].name) + '</strong></legend><div class="swatches">' + p.colors.map(function (c, i) {
        var cout = (p.colorOut || []).indexOf(c.name) > -1, first = p.colors.findIndex(function (z) { return (p.colorOut || []).indexOf(z.name) < 0; }); return '<label class="sw' + (cout ? ' sw--out' : '') + '"><input type="radio" name="color" value="' + esc(c.name) + '"' + (i === (first < 0 ? 0 : first) ? ' checked' : '') + (cout ? ' disabled' : '') + '><span class="sw__dot" style="background:' + c.hex + '"></span><span class="vh">' + esc(c.name) + (cout ? ' — sold out' : '') + '</span></label>'; }).join('') + '</div></fieldset>' +
      '<fieldset class="field"><legend class="field__l">Stitching status</legend>' + U.stitchRadios(p, 'stitch') + '</fieldset>' +
      '<section class="field" aria-labelledby="inc-h"><h2 class="field__l" id="inc-h">What’s included</h2><ul class="ticks">' + p.inc.map(function (i) { return '<li>' + U.icon('check', 'ico--xs') + esc(i) + '</li>'; }).join('') + '</ul></section>' +
      '<fieldset class="field" id="size-field"><legend class="field__l">Size <button type="button" class="link" data-size-guide>Size guide</button></legend>' + U.sizeRadios('size', p) + '<details class="sizefinder"><summary>Find my size</summary><div class="sizefinder__f"><div class="field"><label class="field__l" for="sf-b">Bust (inches)</label><input class="input" id="sf-b" inputmode="decimal" maxlength="5"></div><div class="field"><label class="field__l" for="sf-w">Waist (inches)</label><input class="input" id="sf-w" inputmode="decimal" maxlength="5"></div><div class="field"><label class="field__l" for="sf-h">Hip (inches)</label><input class="input" id="sf-h" inputmode="decimal" maxlength="5"></div></div><p class="sizefinder__r muted" id="sf-r" role="status">Measure over light clothing. Enter at least one measurement.</p><button type="button" class="btn btn--ghost btn--sm" id="sf-pick" hidden>Choose this size</button></details><p class="field__err" id="size-err" role="alert" hidden>Please choose a size to continue.</p></fieldset>' +
      '<div class="field"><label class="field__l" for="note">Customisation <span class="muted">(optional)</span></label><textarea class="input" id="note" name="note" rows="3" maxlength="240" placeholder="Height, sleeve length, blouse back style, monogram…" autocomplete="off"></textarea></div>' +
      '<section class="field ship" aria-labelledby="ship-h"><h2 class="field__l" id="ship-h">Shipping</h2><div class="ship__row"><label class="vh" for="pin">PIN code</label><input class="input" id="pin" name="pin" inputmode="numeric" autocomplete="postal-code" maxlength="6" pattern="[1-9][0-9]{5}" placeholder="Enter PIN code"><button class="btn btn--ghost" type="button" id="pin-check">Check</button></div><p class="ship__msg" id="ship-msg" role="status" aria-live="polite">' + U.icon('truck', 'ico--xs') + ' Free shipping over ' + money(A.FREE_SHIP_FROM) + '. Easy 7-day returns on unstitched pieces.</p></section>' +
      '<p class="pdp__share"><a href="https://wa.me/?text=' + encodeURIComponent(p.name + ' — ' + location.href) + '" target="_blank" rel="noopener">Share on WhatsApp</a></p>' + (p.left && !p.soldOut ? '<p class="stockleft">Only ' + p.left + ' left</p>' : '') + '<div class="pdp__cta"><button class="btn btn--lg btn--grow" type="submit" id="add-btn"' + (p.soldOut ? ' disabled' : '') + '>' + (p.soldOut ? 'Sold out' : 'Add to bag') + '</button><button type="button" class="icon-btn icon-btn--bordered" data-wish="' + p.id + '" aria-pressed="' + wish + '" aria-label="' + (wish ? 'Remove from' : 'Add to') + ' wishlist">' + U.icon('heart') + '</button></div></form>' + notifyHtml(p) +
      '<ul class="pdp__trust">' + [['scissors', 'Quality crafted'], ['truck', 'Free shipping over ' + money(A.FREE_SHIP_FROM)], ['ret', (((A.SITE || {}).returnDays) ? A.SITE.returnDays + '-day returns*' : 'Easy returns*')]].map(function (t) { return '<li>' + U.icon(t[0]) + '<span>' + t[1] + '</span></li>'; }).join('') + '</ul><div class="pdp__acc"><details open><summary>Details &amp; care</summary><ul class="bullets">' + p.details.map(function (d) { return '<li>' + esc(d) + '</li>'; }).join('') + '</ul></details>' +
      '' + (((A.SITE || {}).policies || {}).returns || ((A.SITE || {}).policies || {}).shipping ? '<details><summary>Shipping &amp; returns</summary>' + ((A.SITE.policies.shipping) ? '<p>' + esc(A.SITE.policies.shipping) + '</p>' : '') + ((A.SITE.policies.returns) ? '<p>' + esc(A.SITE.policies.returns) + '</p>' : '') + '</details>' : '') + '</div></div>';

    var rv = $('#reviews');
    function paintReviews(list, canReview, mine) {
      var head = '<h2 class="h2" id="reviews-h">' + (p.demo ? 'What customers say' : 'Reviews') + '</h2>';
      var sum = p.rating ? '<div class="reviews__sum"><p class="reviews__score">' + p.rating.toFixed(1) + '</p><div>' + U.stars(p.rating) + (p.reviews ? '<p class="muted">Based on ' + p.reviews + ' review' + (p.reviews === 1 ? '' : 's') + '</p>' : '') + '</div></div>' : '';
      var ul = list.length ? '<ul class="reviews__list">' + list.map(function (r) { return '<li class="review"><p>' + U.stars(r.stars) + '</p>' + (r.title ? '<h3>' + esc(r.title) + '</h3>' : '') + '<p>' + esc(r.body) + '</p><p class="muted">' + esc(r.who) + (r.city ? ', ' + esc(r.city) : '') + (p.demo ? '' : ' · verified buyer') + '</p></li>'; }).join('') + '</ul>' : '';
      var form = canReview ? '<form class="review-form" id="rvf" novalidate><h3>Write a review</h3><fieldset class="rq__k"><legend class="vh">Rating</legend>' + [5, 4, 3, 2, 1].map(function (n) { return '<label class="chipradio"><input type="radio" name="st" value="' + n + '"' + (n === 5 ? ' checked' : '') + '><span>' + n + ' ★</span></label>'; }).join('') + '</fieldset><div class="field"><label class="field__l" for="rv-t">Title <span class="muted">(optional)</span></label><input class="input" id="rv-t" maxlength="80"></div><div class="field"><label class="field__l" for="rv-b">Your review</label><textarea class="input" id="rv-b" rows="3" maxlength="800"></textarea></div><p class="field__err" id="rv-e" role="alert"></p><button class="btn btn--ghost" type="submit"><span>Submit review</span></button><p class="muted">Reviews appear after our team approves them.</p></form>' : (mine === 'pending' ? '<p class="muted">Thanks — your review is waiting for approval.</p>' : '');
      if (!list.length && !p.rating && !form) { rv.hidden = true; return; }
      rv.hidden = false; rv.innerHTML = head + sum + ul + form;
      var f = $('#rvf'); if (f) f.addEventListener('submit', function (e) { e.preventDefault(); api('POST', '/api/products/' + p.id + '/reviews', { stars: f.elements.st.value, title: $('#rv-t').value, body: $('#rv-b').value }).then(function () { U.toast('Thanks! Your review will appear once approved.'); paintReviews(list, false, 'pending'); }, function (er) { $('#rv-e').textContent = er.message; }); });
    }
    if (p.demo) paintReviews(A.REVIEWS || [], false, null);
    else { rv.hidden = true; api('GET', '/api/products/' + p.id + '/reviews').then(function (r) { paintReviews(r.reviews, r.canReview, r.mine); }, function () {}); }
    var rel = A.PRODUCTS.filter(function (x) { return x.id !== p.id; }).sort(function (a, b) { return (b.cat === p.cat) - (a.cat === p.cat) || b.rating - a.rating; }).slice(0, 8);
    var relSec = $('#rel-h').closest('section'); relSec.hidden = !rel.length;
    $('#related-track').innerHTML = rel.map(function (x) { return '<div class="rail__item">' + U.card(x, { sizes: '(min-width:1100px) 22vw, (min-width:700px) 31vw, 60vw' }) + '</div>'; }).join('');
    U.bindRails(document); U.reveal(document);

    var buy = $('#buy'), priceEl = $('#pdp-price'), sticky = $('#sticky-buy');
    function curStitch() { return sById[buy.querySelector('[name=stitch]:checked').value]; }
    function price() { var html = U.priceHTML(p, curStitch().add); priceEl.innerHTML = html; $('#sticky-price').innerHTML = html; }
    price();
    buy.addEventListener('change', function (e) {
      if (e.target.name === 'color') { $('#color-name').textContent = e.target.value; var ix = (p.imgColors || []).indexOf(e.target.value); if (ix > -1) { var sl = $$('#gal > li')[ix]; if (sl) sl.scrollIntoView({ behavior: U.reduceMotion.matches ? 'auto' : 'smooth', block: 'nearest', inline: 'start' }); } }
      if (e.target.name === 'stitch') { price(); updateShip(); }
      if (e.target.name === 'size') $('#size-err').hidden = true;
    });
    function updateShip() { if ($('#ship-msg').getAttribute('data-ok')) checkPin(); }
    function checkPin() {
      var pin = $('#pin'), msg = $('#ship-msg');
      if (!/^[1-9][0-9]{5}$/.test(pin.value)) { pin.setAttribute('aria-invalid', 'true'); msg.removeAttribute('data-ok'); msg.textContent = 'Please enter a valid 6-digit PIN code.'; return; }
      pin.removeAttribute('aria-invalid');
      var r = { unstitched: [5, 8], semi: [7, 11], custom: [13, 19] }[curStitch().id], f = function (d) { var t = new Date(); t.setDate(t.getDate() + d); return t.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }); };
      msg.setAttribute('data-ok', '1'); msg.textContent = 'Checking…'; var want = pin.value;
      api('GET', '/api/pincheck?pin=' + encodeURIComponent(want)).then(function (c) {
        if (pin.value !== want) return;
        if (c.serviceable === false) { msg.removeAttribute('data-ok'); msg.textContent = 'Sorry — we can’t deliver to ' + want + ' yet. Please message us on WhatsApp and we’ll try to help.'; return; }
        msg.textContent = 'Delivery to ' + want + ' between ' + f(r[0]) + ' – ' + f(r[1]) + '.' + (c.live && c.cod ? ' Cash on delivery available.' : '');
      }, function () { msg.textContent = 'Delivery to ' + want + ' between ' + f(r[0]) + ' – ' + f(r[1]) + '.'; });
    }
    $('#pin-check').addEventListener('click', checkPin);
    $('#pin').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); checkPin(); } });
    function needSize() { var f = $('#size-field'); $('#size-err').hidden = false; f.scrollIntoView({ block: 'center', behavior: U.reduceMotion.matches ? 'auto' : 'smooth' }); setTimeout(function () { buy.querySelector('[name=size]').focus({ preventScroll: true }); }, 250); }
    buy.addEventListener('submit', function (e) {
      e.preventDefault();
      var size = buy.querySelector('[name=size]:checked'); if (!size) { needSize(); return; }
      Cart.add(p.id, { size: size.value, stitch: curStitch().id, color: buy.querySelector('[name=color]:checked').value, note: $('#note').value.trim() });
      U.fly($('#add-btn').getBoundingClientRect().top > 0 && $('#add-btn').getBoundingClientRect().top < innerHeight ? $('#add-btn') : $('#sticky-add')); U.afterAdd();
    });
    if (p.soldOut) sticky.hidden = true;
    $('#sticky-add').addEventListener('click', function () { buy.requestSubmit ? buy.requestSubmit() : buy.dispatchEvent(new Event('submit', { cancelable: true })); });
    var nf = $('#nf'); if (nf) nf.addEventListener('submit', function (e) { e.preventDefault(); var d = { pid: p.id, email: nf.elements.email.value, phone: nf.elements.phone.value, website: nf.elements.website.value, size: nf.elements.size ? nf.elements.size.value : '', color: nf.elements.color ? nf.elements.color.value : '' }; api('POST', '/api/notify', d).then(function () { $('#notify').innerHTML = '<summary>You’re on the list ✓</summary><p class="muted">We’ll email you the moment it’s available.</p>'; U.toast('We’ll let you know'); }, function (er) { $('#nf-e2').textContent = er.message; }); });
    // Size finder: the smallest size whose chart measurements are at least the customer's (in every measurement they gave)
    (function () {
      var ids = ['sf-b', 'sf-w', 'sf-h'], keys = ['bust', 'waist', 'hip'], out = $('#sf-r'), pick = $('#sf-pick'), best = null; if (!out) return;
      function calc() {
        var v = ids.map(function (i) { var x = parseFloat(($('#' + i).value || '').replace(',', '.')); return x > 0 ? x : null; });
        if (v.every(function (x) { return x === null; })) { out.textContent = 'Measure over light clothing. Enter at least one measurement.'; pick.hidden = true; return; }
        var rows = A.SIZECHART || [], hit = null; for (var r = 0; r < rows.length && !hit; r++) { var ok = true; keys.forEach(function (k, j) { if (v[j] !== null && rows[r][k] < v[j]) ok = false; }); if (ok && (p.sizeOut || []).indexOf(rows[r].size) < 0) hit = rows[r]; }
        if (!hit) { best = null; pick.hidden = true; out.textContent = 'You are between our standard sizes — choose Custom stitching and we will make it to your measurements.'; return; }
        best = hit.size; out.textContent = 'We suggest size ' + hit.size + ' (bust ' + hit.bust + '″ · waist ' + hit.waist + '″ · hip ' + hit.hip + '″). Between sizes? Custom stitching fits perfectly.'; pick.hidden = false;
      }
      ids.forEach(function (i) { $('#' + i).addEventListener('input', calc); });
      pick.addEventListener('click', function () { var r = $('input[name=size][value="' + best + '"]'); if (r && !r.disabled) { r.checked = true; r.dispatchEvent(new Event('change', { bubbles: true })); var e = $('#size-err'); if (e) e.hidden = true; } });
    })();
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
    function showLb(n) { cur = ((n - 1 + N) % N) + 1; lbImg.innerHTML = U.picture(p.id, cur, { sizes: '(min-width:1100px) 120vw, 200vw', alt: p.name + ' — image ' + cur + ' of ' + N, eager: true }); $('#lb-count').textContent = cur + ' / ' + N; $('.lightbox__scroll', lb).scrollTo(0, 0); }
    document.addEventListener('click', function (e) { var z = e.target.closest('[data-zoom]'); if (z) { showLb(+z.getAttribute('data-zoom')); Sheet.open('lightbox', z); } });
    $('#lb-prev').hidden = $('#lb-next').hidden = N < 2;
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
    var recs = A.PRODUCTS.filter(function (p) { return !Cart.items.some(function (i) { return i.id === p.id; }); }).sort(function (a, b) { return b.rating - a.rating; }).slice(0, 8);
    $('#cart-recs').innerHTML = recs.map(function (x) { return '<div class="rail__item">' + U.card(x, { sizes: '(min-width:1100px) 22vw, (min-width:700px) 31vw, 60vw' }) + '</div>'; }).join('');
    U.bindRails(document);
    Cart.subscribe(render); U.reveal(document);
  }

  /* ================= CHECKOUT ================= */
  var STATES = ['Andhra Pradesh', 'Assam', 'Bihar', 'Chandigarh', 'Chhattisgarh', 'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Odisha', 'Punjab', 'Rajasthan', 'Tamil Nadu', 'Telangana', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'];
  function checkout() {
    var form1 = $('#step-details'), form2 = $('#step-method'), qr = $('#step-qr'), done = $('#step-done'), steps = $$('.progress li'), sum = $('#summary'), order = $('#order-lines');
    $('#state').insertAdjacentHTML('beforeend', STATES.map(function (s) { return '<option>' + s + '</option>'; }).join(''));
    var finished = false, placed = null, cust = null;
    function couponBox() {
      return Cart.coupon ? '<p class="coupon coupon--on"><span>' + U.icon('check', 'ico--xs') + ' <strong>' + esc(Cart.coupon.code) + '</strong> applied (' + esc(Cart.coupon.label) + ')</span><button type="button" class="link" id="cp-rm">Remove</button></p>'
        : '<form class="coupon" id="cp" novalidate><label class="vh" for="cp-c">Discount code</label><input class="input" id="cp-c" placeholder="Discount code" autocomplete="off" maxlength="20"><button class="btn btn--ghost" type="submit">Apply</button><p class="field__err" id="cp-e" role="alert"></p></form>';
    }
    function bindCoupon() {
      var f = $('#cp'), rm = $('#cp-rm');
      if (rm) rm.addEventListener('click', function () { Cart.coupon = null; renderSummary(); });
      if (f) f.addEventListener('submit', function (e) { e.preventDefault(); var code = $('#cp-c').value.trim(); if (!code) return; U.Auth.ensure().then(function () { return api('POST', '/api/coupon', { code: code, items: Cart.items.map(function (i) { return { id: i.id, size: i.size, stitch: i.stitch, color: i.color, qty: i.qty }; }) }); }).then(function (r) { Cart.coupon = { code: r.code, discount: r.discount, label: r.label }; renderSummary(); U.toast('Code applied'); }, function (er) { if (er && er.message !== 'cancelled') $('#cp-e').textContent = er.message; }); });
    }
    function renderSummary() {
      var n = Cart.count();
      order.innerHTML = '<ul class="lines lines--mini">' + Cart.items.map(function (i) {
        var p = byId[i.id];
        return '<li class="line line--mini"><a class="line__img" href="product.html?id=' + p.id + '" tabindex="-1" aria-hidden="true">' + U.picture(p.id, 1, { sizes: '72px', alt: '' }) + '<span class="line__qty">' + i.qty + '</span></a><div class="line__info"><p class="line__name">' + esc(p.name) + '</p><p class="line__meta">Size ' + esc(i.size) + ' · ' + esc(sById[i.stitch].label) + '</p></div><span class="line__price">' + money(Cart.unit(i) * i.qty) + '</span></li>';
      }).join('') + '</ul>' + couponBox() + U.totalsHTML();
      bindCoupon();
      $('#sum-total').textContent = money(Cart.total()); $('#sum-count').textContent = n + ' item' + (n === 1 ? '' : 's');
    }
    function renderPlacedSummary(o) {
      order.innerHTML = '<ul class="lines lines--mini">' + o.items.map(function (i) { return '<li class="line line--mini"><a class="line__img" href="product.html?id=' + i.id + '" tabindex="-1" aria-hidden="true">' + U.picture(i.id, 1, { sizes: '72px', alt: '' }) + '<span class="line__qty">' + i.qty + '</span></a><div class="line__info"><p class="line__name">' + esc(i.name) + '</p><p class="line__meta">Size ' + esc(i.size) + ' · ' + esc(i.stitchLabel) + '</p></div><span class="line__price">' + money(i.unit * i.qty) + '</span></li>'; }).join('') + '</ul>' +
        '<dl class="totals"><div><dt>Subtotal</dt><dd>' + money(o.totals.subtotal) + '</dd></div>' + (o.totals.discount ? '<div class="totals__disc"><dt>Discount <small>' + esc(o.totals.coupon || '') + '</small></dt><dd>− ' + money(o.totals.discount) + '</dd></div>' : '') + '<div><dt>Shipping</dt><dd>' + (o.totals.shipping ? money(o.totals.shipping) : 'Free') + '</dd></div>' + (o.totals.codFee ? '<div><dt>Cash on delivery fee</dt><dd>' + money(o.totals.codFee) + '</dd></div>' : '') + (o.totals.gift ? '<div><dt>Gift wrap</dt><dd>' + money(o.totals.gift) + '</dd></div>' : '') + '<div class="totals__total"><dt>Total</dt><dd>' + money(o.totals.total) + '</dd></div></dl>';
      $('#sum-total').textContent = money(o.totals.total); $('#sum-count').textContent = o.items.length + ' item' + (o.items.length === 1 ? '' : 's');
    }
    var syncSum = function () { sum.open = window.matchMedia('(min-width: 900px)').matches; };
    syncSum(); mqChange(window.matchMedia('(min-width: 900px)'), syncSum);

    /* signed-in / guest note + prefill */
    function authNote() {
      var u = U.Auth.user, n = $('#authnote');
      n.innerHTML = u ? (u.isGuest ? 'Checking out as a <strong>guest</strong> — no account needed. <button type="button" class="link" data-signin>Sign in instead</button>' : 'Signed in as <strong>' + esc(u.name || u.email) + '</strong>.') : 'Have an account? <button type="button" class="link" data-signin>Sign in</button> for faster checkout — or just continue as a guest, no details needed.';
    }
    function prefill() {
      var u = U.Auth.user; if (!u) return; var p = u.profile || {};
      var set = function (id, v) { var el = document.getElementById(id); if (el && !el.value && v) el.value = v; };
      set('email', u.email); set('name', u.name); set('phone', p.phone); set('line1', p.line1); set('line2', p.line2); set('pin', p.pin); set('city', p.city); set('state', p.state);
    }
    /* saved addresses: pick one to fill the form, or tick "save" for next time */
    function savedUI() {
      var u = U.Auth.user, fields = $('#step-details .fields'); if (!fields) return;
      var old = $('#saved-wrap'); if (old) old.remove(); var ck = $('#save-wrap'); if (ck) ck.remove();
      if (!u || u.isGuest) return;
      var list = u.addresses || [];
      if (list.length) {
        var w = document.createElement('div'); w.className = 'field field--wide'; w.id = 'saved-wrap';
        w.innerHTML = '<label class="field__l" for="saved-addr">Saved addresses</label><select class="input input--select" id="saved-addr"><option value="">Use a new address</option>' + list.map(function (a) { return '<option value="' + esc(a.id) + '">' + esc(a.label + ' — ' + a.name + ', ' + a.line1 + ', ' + a.city + ' ' + a.pin) + '</option>'; }).join('') + '</select>';
        fields.insertBefore(w, fields.firstChild);
        $('#saved-addr', w).addEventListener('change', function () {
          var a = list.filter(function (x) { return x.id === this.value; }.bind(this))[0]; if (!a) return;
          [['name', a.name], ['phone', a.phone], ['line1', a.line1], ['line2', a.line2], ['pin', a.pin], ['city', a.city], ['state', a.state]].forEach(function (kv) { var el = document.getElementById(kv[0]); if (el) { el.value = kv[1] || ''; el.dispatchEvent(new Event('input', { bubbles: true })); } });
        });
      }
      if (list.length < 6) { var c = document.createElement('label'); c.className = 'check field--wide'; c.id = 'save-wrap'; c.innerHTML = '<input type="checkbox" id="save-addr" checked> <span>Save this address for next time</span>'; fields.appendChild(c); }
    }
    $('#authnote').addEventListener('click', function (e) { if (e.target.closest('[data-signin]')) U.Auth.ensure().then(function () {}, function () {}); });
    document.addEventListener('authchange', function () { authNote(); prefill(); savedUI(); });
    api('GET', '/api/me').then(function (r) { U.Auth.user = r.user; U.Auth.paint(); authNote(); prefill(); savedUI(); }, authNote);

    var RULES = {
      email: { test: function (v) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v); }, msg: 'Enter a valid email, e.g. name@example.com' },
      phone: { test: function (v) { return /^(\+91)?[6-9][0-9]{9}$/.test(v.replace(/\s|-/g, '')); }, msg: 'Enter a 10-digit mobile number' },
      name: { test: function (v) { return v.trim().length >= 2; }, msg: 'Enter your full name' },
      line1: { test: function (v) { return v.trim().length >= 5; }, msg: 'Enter your house, building and street' },
      pin: { test: function (v) { return /^[1-9][0-9]{5}$/.test(v); }, msg: 'Enter a valid 6-digit PIN code' },
      city: { test: function (v) { return v.trim().length >= 2; }, msg: 'Enter your city' },
      state: { test: function (v) { return !!v; }, msg: 'Choose your state' }
    };
    function check(inp) { var r = RULES[inp.name]; if (!r) return true; var ok = r.test(inp.value.trim()), err = document.getElementById(inp.id + '-err'); inp.setAttribute('aria-invalid', ok ? 'false' : 'true'); err.textContent = ok ? '' : r.msg; return ok; }
    form1.addEventListener('focusout', function (e) { if (e.target.name && RULES[e.target.name] && e.target.value) check(e.target); });
    form1.addEventListener('input', function (e) { if (e.target.getAttribute('aria-invalid') === 'true') check(e.target); });

    function go(n) {
      form1.hidden = n !== 1; form2.hidden = n !== 2; qr.hidden = n !== 3; done.hidden = n !== 4;
      steps.forEach(function (s, i) { s.classList.toggle('is-done', i + 1 < n); if (i + 1 === n) s.setAttribute('aria-current', 'step'); else s.removeAttribute('aria-current'); });
      if (n === 4) confetti();
      var h = (n === 1 ? form1 : n === 2 ? form2 : n === 3 ? qr : done).querySelector('h2'); h.setAttribute('tabindex', '-1'); h.focus({ preventScroll: true });
      window.scrollTo({ top: Math.max(0, $('.progress').getBoundingClientRect().top + window.scrollY - 80), behavior: U.reduceMotion.matches ? 'auto' : 'smooth' });
    }
    function confetti() {
      if (U.reduceMotion.matches) return;
      var box = document.createElement('div'); box.className = 'confetti'; box.setAttribute('aria-hidden', 'true'); var cols = ['#e9c46a', '#c23a6e', '#e8913a', '#1d6b5a', '#7a1f3d'];
      for (var i = 0; i < 36; i++) { var s = document.createElement('i'); s.style.cssText = '--x:' + (Math.random() * 100).toFixed(1) + 'vw;--d:' + (Math.random() * .6).toFixed(2) + 's;--t:' + (2.2 + Math.random() * 1.6).toFixed(2) + 's;--r:' + Math.round(Math.random() * 720 - 360) + 'deg;--s:' + (7 + Math.random() * 7).toFixed(0) + 'px;background:' + cols[i % 5]; box.appendChild(s); }
      document.body.appendChild(box); setTimeout(function () { box.remove(); }, 4500);
    }
    function showDone(o) {
      placed = o; finished = true; U.store.set('asingh.pending', null); renderPlacedSummary(o);
      var cod = o.method === 'cod', t = $('#done-title'), x = $('#done-text'), link = ' — check any time on the <a href="track.html">tracking page</a> with your order number and mobile number.';
      if (o.status === 'paid') { t.textContent = 'Payment received — thank you!'; x.innerHTML = 'Your order is confirmed and we’ll start preparing it' + link; }
      else if (cod) { t.textContent = 'Order confirmed — pay on delivery'; x.innerHTML = 'Please keep ' + money(o.totals.total) + ' ready (cash or UPI) when your parcel arrives. We’ll update the status' + link; }
      A.Orders.numberCard(o, $('#done-numcard'), 'Save this number — with your mobile number you can check progress any time, even without signing in.'); $('#track').href = 'order.html?id=' + o.id; $('#bill').href = 'invoice.html?id=' + o.id; go(4);
    }
    function showQr(o) {
      placed = o; finished = true; U.store.set('asingh.pending', o.id); renderPlacedSummary(o);
      A.Orders.numberCard(o, $('#qr-numcard')); $('#track').href = 'order.html?id=' + o.id; $('#bill').href = 'invoice.html?id=' + o.id;
      A.Orders.payPanel(o, $('#qr-mount'), function (upd) { placed = upd; if (upd.status === 'payment_review') { U.store.set('asingh.pending', null); A.Orders.numberCard(upd, $('#done-numcard'), 'Save this number — with your mobile number you can check progress any time, even without signing in.'); go(4); } else if (upd.status === 'paid') showDone(upd); });
      go(3);
    }

    form1.addEventListener('submit', function (e) {
      e.preventDefault();
      var bad = $$('input[name],select[name]', form1).filter(function (i) { return !check(i); });
      if (bad.length) { $('#form-err').textContent = 'Please fix ' + bad.length + ' field' + (bad.length > 1 ? 's' : '') + ' to continue.'; bad[0].focus(); return; }
      $('#form-err').textContent = '';
      U.Auth.ensure().then(function () {
        cust = { name: $('#name').value.trim(), email: $('#email').value.trim(), phone: $('#phone').value.trim(), line1: $('#line1').value.trim(), line2: $('#line2').value.trim(), pin: $('#pin').value.trim(), city: $('#city').value.trim(), state: $('#state').value };
        $('#ship-to').textContent = [cust.name, cust.line1, cust.city + ' ' + cust.pin].join(', '); go(2);
      }, function () { $('#form-err').textContent = 'Please choose how you’d like to continue — sign in, create an account, or continue as a guest.'; });
    });
    $('#back-1').addEventListener('click', function () { go(1); });

    /* payment methods come from the server — adding a gateway later needs no change here */
    if (A.SITE && A.SITE.giftFee) {
      var gw = document.createElement('fieldset'); gw.className = 'field gift'; gw.innerHTML = '<legend class="field__l">Gift wrap</legend><label class="check"><input type="checkbox" id="gift-on"> <span>Wrap it as a gift <strong>+' + money(A.SITE.giftFee) + '</strong></span></label><div id="gift-msg-w" hidden><label class="field__l" for="gift-msg">Message on the card <span class="muted">(optional)</span></label><textarea class="input" id="gift-msg" rows="2" maxlength="200" placeholder="With love…"></textarea></div>';
      form2.insertBefore(gw, form2.firstChild);
      $('#gift-on').addEventListener('change', function () { Cart.gift = this.checked ? { on: true, message: '' } : null; $('#gift-msg-w').hidden = !this.checked; renderSummary(); });
      $('#gift-msg').addEventListener('input', function () { if (Cart.gift) Cart.gift.message = this.value; });
    }
    A.Orders.config().then(function (cfg) {
      $('#methods').insertAdjacentHTML('beforeend', cfg.methods.map(function (m, i) {
        return '<label class="paymethod' + (m.enabled ? '' : ' is-off') + '"><input type="radio" name="pay" value="' + m.id + '"' + (m.enabled && i === 0 ? ' checked' : '') + (m.enabled ? '' : ' disabled') + '><span><strong>' + esc(m.label) + (m.enabled ? '' : ' <em class="soon">Soon</em>') + '</strong><small>' + esc(m.note) + '</small></span></label>';
      }).join(''));
    });
    form2.addEventListener('submit', function (e) {
      e.preventDefault(); var m = form2.querySelector('[name=pay]:checked'), btn = $('#place'), err = $('#method-err'); err.textContent = '';
      if (!m) { err.textContent = 'Please choose a payment method.'; return; }
      btn.disabled = true; btn.classList.add('is-busy');
      api('POST', '/api/orders', { items: Cart.items.map(function (i) { return { id: i.id, size: i.size, stitch: i.stitch, color: i.color, note: i.note, qty: i.qty }; }), customer: cust, method: m.value, coupon: Cart.coupon ? Cart.coupon.code : undefined, gift: Cart.giftFee() ? Cart.gift : undefined }).then(function (r) { finished = true; var sv = $('#save-addr'); if (sv && sv.checked && U.Auth.user && !U.Auth.user.isGuest) api('POST', '/api/me/addresses', { label: 'Home', name: cust.name, phone: cust.phone, line1: cust.line1, line2: cust.line2, pin: cust.pin, city: cust.city, state: cust.state }).then(function (x) { U.Auth.user = x.user; }, function () {}); Cart.clear(); if (r.order.method === 'cod' || r.order.status === 'paid') showDone(r.order); else { showQr(r.order); if (r.order.method === 'razorpay') setTimeout(function () { var b = $('#pay-online'); if (b) b.click(); }, 400); } }, function (er) { btn.disabled = false; btn.classList.remove('is-busy'); err.textContent = er.message; });
    });

    Cart.subscribe(function () {
      if (finished) return;
      if (!Cart.items.length) { /* maybe resuming an unpaid order */ var pid = U.store.get('asingh.pending', null); if (pid) { api('GET', '/api/orders/' + pid).then(function (r) { if (r.order.status === 'awaiting_payment' || r.order.status === 'payment_rejected') { $('#co-empty').hidden = true; $('#co-main').hidden = false; showQr(r.order); } else { $('#co-empty').hidden = false; $('#co-main').hidden = true; } }, function () { $('#co-empty').hidden = false; $('#co-main').hidden = true; }); } else { $('#co-empty').hidden = false; $('#co-main').hidden = true; } }
      else { $('#co-empty').hidden = true; $('#co-main').hidden = false; renderSummary(); }
    });
  }

  /* ================= RECENTLY VIEWED (kept on this device only) ================= */
  var RKEY = 'asingh.recent.v1';
  function recentIds() { return (U.store.get(RKEY, []) || []).filter(function (id) { return byId[id]; }); }
  function recentStrip(excludeId) {
    var ids = recentIds().filter(function (id) { return id !== excludeId; }).slice(0, 10), main = $('#main'); if (!main) return;
    var old = $('#recent'); if (old) old.remove(); if (ids.length < 1) return;
    var sec = document.createElement('section'); sec.id = 'recent'; sec.className = 'section container'; sec.setAttribute('aria-labelledby', 'recent-h');
    sec.innerHTML = '<div class="section__head"><h2 id="recent-h" class="h2">Recently viewed</h2><button type="button" class="link" data-clear-recent>Clear</button></div><div class="rail" data-rail><div class="rail__track" tabindex="0" role="region" aria-label="Recently viewed — scroll horizontally">' + ids.map(function (id) { return '<div class="rail__item">' + U.card(byId[id], { sizes: '(min-width:1100px) 22vw, (min-width:700px) 31vw, 60vw' }) + '</div>'; }).join('') + '</div></div>';
    main.appendChild(sec); U.bindRails(sec); U.reveal(sec);
    $('[data-clear-recent]', sec).addEventListener('click', function () { U.store.set(RKEY, []); sec.remove(); });
  }
  function noteViewed(id) { var l = (U.store.get(RKEY, []) || []).filter(function (x) { return x !== id; }); l.unshift(id); U.store.set(RKEY, l.slice(0, 12)); }

  ({ home: home, shop: shop, product: product, cart: cartPage, checkout: checkout }[page] || function () {})();
  if (page === 'product') { var vid = new URLSearchParams(location.search).get('id'); if (byId[vid]) { recentStrip(vid); noteViewed(vid); } }
  else if (page === 'home' || page === 'cart') recentStrip(null);

})();
