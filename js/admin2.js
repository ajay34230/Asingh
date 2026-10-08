/* Admin: products, home page, store settings, admin accounts. Loaded after admin.js (uses window.ADM). */
(function () {
  'use strict';
  var ADM = window.ADM, $ = ADM.$, $$ = ADM.$$, esc = ADM.esc, api = ADM.api, toast = ADM.toast, view = ADM.view, money = ADM.money, ico = ADM.ico, V = ADM.views;
  var cat = null;
  var load = function () { return api('GET', '/api/admin/catalog').then(function (r) { cat = r; return r; }); };
  var catLabel = function (id) { var c = cat.categories.filter(function (x) { return x.id === id; })[0]; return c ? c.label : id; };
  var rnd = function () { var a = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789', o = ''; for (var i = 0; i < 8; i++) o += a[Math.floor(Math.random() * a.length)]; return o; };

  /* ---------- tiny form helpers ---------- */
  function F(id, label, control, hint) { return '<div class="field"><label class="field__l" for="' + id + '">' + label + '</label>' + control + (hint ? '<small class="muted">' + hint + '</small>' : '') + '</div>'; }
  function I(id, val, o) { o = o || {}; return '<input class="input" id="' + id + '" value="' + esc(val == null ? '' : val) + '"' + (o.max ? ' maxlength="' + o.max + '"' : '') + (o.ph ? ' placeholder="' + esc(o.ph) + '"' : '') + (o.type ? ' type="' + o.type + '"' : '') + (o.mode ? ' inputmode="' + o.mode + '"' : '') + (o.ac ? ' autocomplete="' + o.ac + '"' : '') + '>'; }
  function T(id, val, rows, max, ph) { return '<textarea class="input" id="' + id + '" rows="' + rows + '"' + (max ? ' maxlength="' + max + '"' : '') + (ph ? ' placeholder="' + esc(ph) + '"' : '') + '>' + esc(val == null ? '' : val) + '</textarea>'; }
  function SW(id, label, on, hint) { return '<label class="switch"><input type="checkbox" id="' + id + '"' + (on ? ' checked' : '') + '><span class="switch__t" aria-hidden="true"></span><span class="switch__l">' + label + (hint ? '<small>' + hint + '</small>' : '') + '</span></label>'; }
  var val = function (id) { var e = $('#' + id); return e ? e.value : ''; };
  var chk = function (id) { var e = $('#' + id); return !!(e && e.checked); };
  var lines = function (id) { return val(id).split(/\n/).map(function (x) { return x.trim(); }).filter(Boolean); };

  /* generic repeatable rows: cols = [{k,label,ph,max,type,w}] */
  function rowsHTML(id, items, cols, max, addLabel) {
    return '<div class="rows" id="' + id + '" data-max="' + max + '" data-cols=\'' + esc(JSON.stringify(cols)) + '\'><div class="rows__list">' + items.map(function (it) { return rowHTML(cols, it); }).join('') + '</div><button type="button" class="btn btn--ghost rows__add">' + esc(addLabel || '+ Add') + '</button></div>';
  }
  function rowHTML(cols, it) {
    it = it || {};
    return '<div class="rrow">' + cols.map(function (c) {
      var v = it[c.k] == null ? '' : it[c.k];
      var inner = c.type === 'stars' ? '<select class="input input--select" data-k="' + c.k + '" aria-label="' + esc(c.label) + '">' + [5, 4, 3, 2, 1].map(function (n) { return '<option' + (+v === n || (!v && n === 5) ? ' selected' : '') + '>' + n + '</option>'; }).join('') + '</select>' :
        c.type === 'text' ? '<textarea class="input" data-k="' + c.k + '" rows="2" maxlength="' + (c.max || 300) + '" placeholder="' + esc(c.ph || '') + '" aria-label="' + esc(c.label) + '">' + esc(v) + '</textarea>' :
        '<input class="input" data-k="' + c.k + '" value="' + esc(v) + '" maxlength="' + (c.max || 80) + '" placeholder="' + esc(c.ph || c.label) + '" aria-label="' + esc(c.label) + '"' + (c.type === 'number' ? ' type="number" inputmode="numeric" min="0"' : '') + '>';
      return '<div class="rrow__c" style="--w:' + (c.w || 1) + '">' + inner + '</div>';
    }).join('') + '<button type="button" class="adm__icon rrow__x" aria-label="Remove">' + ico('close') + '</button></div>';
  }
  function bindRows(root) {
    $$('.rows', root).forEach(function (r) {
      if (r._b) return; r._b = 1; var cols = JSON.parse(r.getAttribute('data-cols')), max = +r.getAttribute('data-max'), list = $('.rows__list', r), add = $('.rows__add', r);
      var sync = function () { add.hidden = $$('.rrow', list).length >= max; };
      add.addEventListener('click', function () { list.insertAdjacentHTML('beforeend', rowHTML(cols, {})); sync(); var l = list.lastElementChild.querySelector('input,textarea'); if (l) l.focus(); });
      list.addEventListener('click', function (e) { var x = e.target.closest('.rrow__x'); if (x) { x.closest('.rrow').remove(); sync(); } }); sync();
    });
  }
  function readRows(id) { return $$('#' + id + ' .rrow').map(function (r) { var o = {}; $$('[data-k]', r).forEach(function (e) { o[e.getAttribute('data-k')] = e.value; }); return o; }); }

  /* ---------- photos: crop + resize in the browser, so uploads are small and the shop stays fast ---------- */
  function makeSizes(file, widths, ratio) {
    return createImageBitmap(file).then(function (bm) {
      var r = 1 / ratio, cw, ch; if (bm.width / bm.height > r) { ch = bm.height; cw = Math.round(ch * r); } else { cw = bm.width; ch = Math.round(cw / r); }
      var sx = Math.round((bm.width - cw) / 2), sy = Math.round((bm.height - ch) / 2);
      function render(type, q) { return Promise.all(widths.map(function (w) { var c = document.createElement('canvas'); c.width = w; c.height = Math.round(w * ratio); c.getContext('2d').drawImage(bm, sx, sy, cw, ch, 0, 0, c.width, c.height); return new Promise(function (res) { c.toBlob(function (b) { res({ w: w, blob: b }); }, type, q); }); })); }
      return render('image/webp', 0.82).then(function (p) { return p.every(function (x) { return x.blob && x.blob.type === 'image/webp'; }) ? p : render('image/jpeg', 0.85); });
    });
  }
  function post(url, blob) {
    return fetch(url, { method: 'POST', credentials: 'same-origin', headers: { 'X-Requested-With': 'asingh', 'Content-Type': 'application/octet-stream' }, body: blob }).then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { if (!r.ok) throw new Error(j.error || 'Upload failed'); return j; }); });
  }
  function seq(items, fn) { return items.reduce(function (p, it, i) { return p.then(function () { return fn(it, i); }); }, Promise.resolve()); }

  /* ================= PRODUCTS ================= */
  V.products = function () {
    var live = ADM.guard();
    load().then(function () {
      if (!live()) return;
      var q = '', f = 'all';
      view('<div class="adm__bar adm__bar--row"><label class="vh" for="pq">Search products</label><input class="input" id="pq" type="search" placeholder="Search products…"><button class="btn" id="addp">+ Add product</button></div>' +
        '<div class="fchips" role="group" aria-label="Filter products">' + [['all', 'All'], ['visible', 'Visible'], ['hidden', 'Hidden'], ['sold', 'Sold out'], ['demo', 'Demo']].map(function (c) { return '<button type="button" data-f="' + c[0] + '" aria-pressed="' + (c[0] === 'all') + '">' + c[1] + '</button>'; }).join('') + '</div>' +
        (cat.demoCount ? '<div class="adm__setup"><strong>' + cat.demoCount + ' demo products are still on your site.</strong><p>Edit them to make them yours, or remove them all: <button class="link" id="cleardemo">Remove all demo products &amp; sample reviews</button></p></div>' : '') +
        '<div id="pl" class="adm__list"></div>');
      function list() {
        var s = q.toLowerCase(), ps = cat.products.filter(function (p) { return (!s || (p.name + ' ' + p.fabric + ' ' + catLabel(p.cat)).toLowerCase().indexOf(s) > -1) && (f === 'all' || (f === 'visible' && p.published) || (f === 'hidden' && !p.published) || (f === 'sold' && p.soldOut) || (f === 'demo' && p.demo)); });
        $('#pl').innerHTML = ps.length ? ps.map(function (p) {
          return '<div class="prow' + (p.published ? '' : ' is-off') + '"><button type="button" class="prow__main" data-edit="' + p.id + '"><span class="prow__img"><img src="' + esc(p.thumb) + '" alt="" width="48" height="60" loading="lazy"></span><span class="prow__t"><strong>' + esc(p.name) + '</strong><small>' + esc(catLabel(p.cat)) + ' · ' + money(p.price) + (p.was ? ' <s>' + money(p.was) + '</s>' : '') + '</small></span><span class="prow__chips">' + (p.published ? '' : '<span class="chip-s chip-s--mute">Hidden</span>') + (p.soldOut ? '<span class="chip-s chip-s--warn">Sold out</span>' : '') + (p.demo ? '<span class="chip-s chip-s--info">Demo</span>' : '') + '</span></button>' +
            '<button type="button" class="btn btn--ghost prow__v" data-vis="' + p.id + '">' + (p.published ? 'Hide' : 'Show') + '</button></div>';
        }).join('') : '<p class="muted pad">' + (cat.products.length ? 'No products match.' : 'No products yet — click “Add product”.') + '</p>';
      }
      list();
      $('#pq').addEventListener('input', function () { q = this.value; list(); });
      $$('.fchips button').forEach(function (b) { b.addEventListener('click', function () { f = b.getAttribute('data-f'); $$('.fchips button').forEach(function (x) { x.setAttribute('aria-pressed', x === b); }); list(); }); });
      $('#addp').addEventListener('click', function () { editProduct(null); });
      $('#pl').addEventListener('click', function (e) {
        var ed = e.target.closest('[data-edit]'); if (ed) return editProduct(cat.products.filter(function (p) { return p.id === ed.getAttribute('data-edit'); })[0]);
        var v = e.target.closest('[data-vis]'); if (v) { var p = cat.products.filter(function (x) { return x.id === v.getAttribute('data-vis'); })[0]; api('PUT', '/api/admin/products/' + p.id, { published: !p.published }).then(function () { toast(p.published ? 'Hidden from the shop' : 'Now visible in the shop'); V.products(); }, function (er) { toast(er.message, 'bad'); }); }
      });
      var cd = $('#cleardemo'); if (cd) cd.addEventListener('click', function () { if (confirm('Remove all ' + cat.demoCount + ' demo products and the sample reviews? Your own products stay.')) api('POST', '/api/admin/catalog/clear-demo', {}).then(function (r) { toast(r.removed + ' demo products removed'); ADM.refreshBadges(); V.products(); }, function (er) { toast(er.message, 'bad'); }); });
    });
  };

  function editProduct(p) {
    var isNew = !p; p = p || { name: '', cat: cat.categories[0] && cat.categories[0].id, price: '', was: '', fabric: '', badge: '', blurb: '', occ: [], stitch: [], colors: [{ name: '', hex: '#7a1f3d' }], inc: [], details: [], best: false, isNew: true, published: true, soldOut: false, rating: '', reviews: '', imageUrls: [], demo: false };
    var imgs = (p.imageUrls || []).map(function (x) { return { rev: x.rev, url: x.url }; }), stitchOn = cat.site.stitch.filter(function (x) { return x.enabled; });
    ADM.showDrawer('<header class="adm__dh"><div><h2>' + (isNew ? 'Add product' : 'Edit product') + '</h2><p class="muted">' + (isNew ? 'Fill in the basics — you can add photos below.' : esc(p.name)) + '</p></div><button class="adm__icon" data-x aria-label="Close">' + ico('close') + '</button></header>' +
      '<form class="adm__db pform" id="pf2" novalidate>' +
      F('e-name', 'Name', I('e-name', p.name, { max: 90, ph: 'e.g. Maharani Gota-Patti Bridal Poshak' })) +
      '<div class="adm__two3">' + F('e-cat', 'Category', '<select class="input input--select" id="e-cat">' + cat.categories.map(function (c) { return '<option value="' + esc(c.id) + '"' + (c.id === p.cat ? ' selected' : '') + '>' + esc(c.label) + '</option>'; }).join('') + '</select>') + F('e-fab', 'Fabric / work', I('e-fab', p.fabric, { max: 60, ph: 'Pure georgette · zardozi' })) + '</div>' +
      '<div class="adm__two3">' + F('e-price', 'Selling price (₹)', I('e-price', p.price, { mode: 'numeric', ph: '12500' })) + F('e-was', 'Original price (₹) — optional', I('e-was', p.was || '', { mode: 'numeric', ph: 'shows a discount' })) + '</div>' +
      F('e-blurb', 'Short description', T('e-blurb', p.blurb, 3, 600)) +
      '<fieldset class="field"><legend class="field__l">Photos <span class="muted">(first photo is the main one; cropped to 4:5)</span></legend>' + (p.demo && !imgs.length ? '<p class="muted">Demo drawings are showing. Add your own photos to replace them.</p>' : '') + '<div class="pgrid" id="pgrid"></div><label class="drop drop--sm"><input type="file" id="e-files" accept="image/jpeg,image/png,image/webp" multiple><span class="drop__ico" aria-hidden="true">+</span><span class="drop__t"><strong>Add photos</strong><small>Up to 6 · JPG, PNG or WebP · resized automatically</small></span></label><p class="field__err" id="e-imgerr" role="alert"></p></fieldset>' +
      '<fieldset class="field"><legend class="field__l">Colours</legend>' + rowsHTML('e-colors', p.colors.map(function (c) { return { name: c.name, hex: c.hex }; }), [{ k: 'name', label: 'Colour name', ph: 'Mulberry', max: 24, w: 2 }, { k: 'hex', label: 'Colour code', ph: '#7a1f3d', max: 7, w: 1 }], 8, '+ Add colour') + '<small class="muted">Colour code looks like #7a1f3d. You can copy it from any colour picker.</small></fieldset>' +
      '<fieldset class="field"><legend class="field__l">Stitching offered</legend><div class="chips">' + stitchOn.map(function (x) { return '<label class="chip chip--wide"><input type="checkbox" name="e-st" value="' + x.id + '"' + (p.stitch.indexOf(x.id) > -1 ? ' checked' : '') + '><span>' + esc(x.label) + (x.add ? ' (+' + money(x.add) + ')' : '') + '</span></label>'; }).join('') + '</div></fieldset>' +
      '<fieldset class="field"><legend class="field__l">Occasions</legend><div class="chips">' + cat.site.occasions.map(function (o) { return '<label class="chip chip--wide"><input type="checkbox" name="e-oc" value="' + esc(o.id) + '"' + (p.occ.indexOf(o.id) > -1 ? ' checked' : '') + '><span>' + esc(o.label) + '</span></label>'; }).join('') + '</div></fieldset>' +
      F('e-inc', 'What’s included <span class="muted">(one per line)</span>', T('e-inc', (p.inc || []).join('\n'), 4, 1200, 'Ghagra with can-can\nKanchli (blouse)\nOdhni')) +
      F('e-det', 'Details &amp; care <span class="muted">(one per line)</span>', T('e-det', (p.details || []).join('\n'), 4, 2000, 'Pure georgette\nDry clean only')) +
      '<div class="adm__two3">' + F('e-badge', 'Badge — optional', I('e-badge', p.badge, { max: 16, ph: 'New, Sale, Limited…' })) + '</div>' +
      '<div class="switches">' + SW('e-pub', 'Visible in the shop', p.published, 'Turn off to hide it without deleting') + SW('e-sold', 'Sold out', p.soldOut, 'Shown but can’t be ordered') + SW('e-new', 'Show in “New arrivals”', p.isNew) + SW('e-best', 'Show in “Bestsellers”', p.best) + '</div>' +
      '<details class="adm__trk"><summary>Star rating (optional)</summary><p class="muted">Leave blank unless you have real reviews — nothing is shown on the product when empty.</p><div class="adm__two3">' + F('e-rating', 'Average rating (1–5)', I('e-rating', p.rating || '', { mode: 'decimal' })) + F('e-revs', 'Number of reviews', I('e-revs', p.reviews || '', { mode: 'numeric' })) + '</div></details>' +
      '<p class="field__err" id="e-err" role="alert"></p><div class="adm__row"><button class="btn btn--lg btn--grow" type="submit" id="e-save"><span>' + (isNew ? 'Add product' : 'Save changes') + '</span></button></div>' +
      (isNew ? '' : '<section><h3>Danger zone</h3><button type="button" class="btn btn--ghost adm__del" id="e-del">Delete this product…</button></section>') + '</form>');
    var form = $('#pf2'); bindRows(form);
    function grid() {
      $('#pgrid').innerHTML = imgs.map(function (im, i) { return '<div class="ptile"><img src="' + esc(im.url) + '" alt="Photo ' + (i + 1) + '">' + (i === 0 ? '<span class="ptile__main">Main</span>' : '') + '<div class="ptile__a"><button type="button" data-mv="-1" data-i="' + i + '" aria-label="Move earlier"' + (i === 0 ? ' disabled' : '') + '>←</button><button type="button" data-mv="1" data-i="' + i + '" aria-label="Move later"' + (i === imgs.length - 1 ? ' disabled' : '') + '>→</button><button type="button" data-rm="' + i + '" aria-label="Remove photo">×</button></div>' + (im.parts ? '<span class="ptile__new">New</span>' : '') + '</div>'; }).join('');
    }
    grid();
    $('#pgrid').addEventListener('click', function (e) { var m = e.target.closest('[data-mv]'), r = e.target.closest('[data-rm]'); if (m) { var i = +m.getAttribute('data-i'), j = i + +m.getAttribute('data-mv'); var t = imgs[i]; imgs[i] = imgs[j]; imgs[j] = t; grid(); } if (r) { imgs.splice(+r.getAttribute('data-rm'), 1); grid(); } });
    $('#e-files').addEventListener('change', function () {
      var fs = [].slice.call(this.files), err = $('#e-imgerr'); err.textContent = ''; this.value = '';
      var room = 6 - imgs.length; if (fs.length > room) { err.textContent = 'Only ' + Math.max(room, 0) + ' more photo(s) fit — the first ones were added.'; fs = fs.slice(0, Math.max(room, 0)); }
      seq(fs, function (f) { if (!/^image\/(jpeg|png|webp)$/.test(f.type)) { err.textContent = 'Skipped “' + f.name + '” — use JPG, PNG or WebP.'; return; } return makeSizes(f, [400, 800, 1200], 1.25).then(function (parts) { imgs.push({ rev: rnd(), url: URL.createObjectURL(parts[1].blob), parts: parts }); grid(); }, function () { err.textContent = 'Couldn’t read “' + f.name + '”.'; }); });
    });
    function body() {
      var b = { name: val('e-name'), cat: val('e-cat'), fabric: val('e-fab'), price: val('e-price'), was: val('e-was'), blurb: val('e-blurb'), badge: val('e-badge'), inc: lines('e-inc'), details: lines('e-det'), published: chk('e-pub'), soldOut: chk('e-sold'), isNew: chk('e-new'), best: chk('e-best'), rating: val('e-rating'), reviews: val('e-revs') };
      b.stitch = $$('[name=e-st]:checked', form).map(function (x) { return x.value; }); b.occ = $$('[name=e-oc]:checked', form).map(function (x) { return x.value; });
      b.colors = readRows('e-colors').map(function (c) { return { name: c.name.trim(), hex: c.hex.trim() }; }).filter(function (c) { return c.name; }); return b;
    }
    form.addEventListener('submit', function (e) {
      e.preventDefault(); var err = $('#e-err'), btn = $('#e-save'); err.textContent = ''; btn.disabled = true; btn.classList.add('is-busy');
      var b = body(), id = p.id;
      (isNew ? api('POST', '/api/admin/products', b) : api('PUT', '/api/admin/products/' + p.id, b)).then(function (r) {
        id = r.product.id; var fresh = imgs.filter(function (i) { return i.parts; });
        return seq(fresh, function (im, n) { err.textContent = 'Uploading photo ' + (n + 1) + ' of ' + fresh.length + '…'; return seq(im.parts, function (pt) { return post('/api/admin/products/' + id + '/image?rev=' + im.rev + '&w=' + pt.w, pt.blob); }); });
      }).then(function () { return api('PUT', '/api/admin/products/' + id, { images: imgs.map(function (i) { return i.rev; }) }); })
        .then(function () { toast(isNew ? 'Product added' : 'Saved'); ADM.closeDrawer(); ADM.refreshBadges(); V.products(); }, function (er) { btn.disabled = false; btn.classList.remove('is-busy'); err.textContent = er.message; });
    });
    var del = $('#e-del'); if (del) del.addEventListener('click', function () { if (confirm('Delete “' + p.name + '”? Past orders keep their details. This cannot be undone.')) api('DELETE', '/api/admin/products/' + p.id).then(function () { toast('Product deleted'); ADM.closeDrawer(); V.products(); }, function (er) { toast(er.message, 'bad'); }); });
  }

  /* ================= HOME PAGE ================= */
  V.home = function () {
    var live = ADM.guard();
    load().then(function () {
      if (!live()) return;
      var t = cat.site, S = t.sections, hero = t.heroImage;
      view('<form id="hf" novalidate class="adm__stack">' +
        '<section class="adm__card"><h2>Sections</h2><p class="muted">Show or hide any part of your home page.</p><div class="switches">' + [['marquee', 'Scrolling craft words'], ['trust', 'Promise badges'], ['collections', 'Shop by collection'], ['occasions', 'Occasion tiles'], ['newArrivals', 'New arrivals'], ['story', '“Made to measure” steps'], ['bestsellers', 'Bestsellers'], ['testimonials', 'Customer reviews']].map(function (x) { return SW('s-' + x[0], x[1], S[x[0]]); }).join('') + '</div></section>' +
        '<section class="adm__card"><h2>Top banner</h2>' +
        '<div class="field"><label class="field__l">Banner photo</label><div class="herop"><img id="hprev" src="' + (hero ? '/media/s/' + hero.rev + '-wide-1280.' + hero.ext : 'img/hero-wide-1280.webp') + '" alt="Current banner photo"><div><p class="muted">' + (hero ? 'Your photo is showing.' : 'The demo banner is showing.') + ' Landscape photos work best; it’s cropped for phones automatically.</p><label class="btn btn--ghost"><input type="file" id="hfile" accept="image/jpeg,image/png,image/webp" hidden>Upload banner photo</label> ' + (hero ? '<button type="button" class="link" id="hreset">Use the demo banner</button>' : '') + '<p class="field__err" id="herr" role="alert"></p></div></div></div>' +
        F('h-eye', 'Small line above the title', I('h-eye', t.heroEyebrow, { max: 50 })) + F('h-title', 'Title', I('h-title', t.heroTitle, { max: 120 }), 'Put *stars* around words to make them shimmer gold, e.g. Made the *royal way*') + F('h-lead', 'Sentence under the title', T('h-lead', t.heroLead, 2, 240)) + F('h-cta', 'Main button label', I('h-cta', t.heroCta, { max: 30 })) + '</section>' +
        '<section class="adm__card"><h2>Scrolling craft words</h2>' + F('h-marq', 'One per line', T('h-marq', t.marquee.join('\n'), 5, 600), 'e.g. Gota Patti, Bandhani, Leheriya') + '</section>' +
        '<section class="adm__card"><h2>Promise badges <span class="muted">(up to 4)</span></h2>' + rowsHTML('h-trust', t.trust, [{ k: 'title', label: 'Title', max: 40, w: 2 }, { k: 'sub', label: 'Small text', max: 60, w: 3 }], 4, '+ Add badge') + '<small class="muted">Leave “Free shipping” small text empty to show your free-shipping amount automatically.</small></section>' +
        '<section class="adm__card"><h2>Occasion tiles</h2><p class="muted">These also become the “Occasion” choices when you add products and the filters in the shop.</p>' + rowsHTML('h-occ', t.occasions, [{ k: 'label', label: 'Name', max: 30, w: 2 }, { k: 'sub', label: 'Short line under it', max: 60, w: 3 }, { k: 'id', label: 'id', max: 30, w: 0 }], 8, '+ Add occasion') + '</section>' +
        '<section class="adm__card"><h2>“Made to measure” steps</h2><div class="adm__two3">' + F('h-seye', 'Small heading', I('h-seye', t.story.eyebrow, { max: 40 })) + F('h-stitle', 'Heading', I('h-stitle', t.story.title, { max: 90 })) + '</div>' + rowsHTML('h-steps', t.story.steps, [{ k: 'title', label: 'Step title', max: 50, w: 2 }, { k: 'text', label: 'Description', max: 200, w: 4, type: 'text' }], 4, '+ Add step') + F('h-scta', 'Button label', I('h-scta', t.story.cta, { max: 40 })) + '</section>' +
        '<section class="adm__card"><h2>Customer reviews</h2><p class="muted">Add only real reviews. Removing all of them hides the section.</p>' + rowsHTML('h-quotes', t.testimonials.map(function (x) { return { name: x.name, city: x.city, stars: x.stars, text: x.text }; }), [{ k: 'name', label: 'Name', max: 40, w: 2 }, { k: 'city', label: 'City', max: 40, w: 2 }, { k: 'stars', label: 'Stars', type: 'stars', w: 1 }, { k: 'text', label: 'What they said', type: 'text', max: 300, w: 5 }], 12, '+ Add review') + '</section>' +
        '<p class="field__err" id="hmsg" role="alert"></p><div class="adm__savebar"><button class="btn btn--lg" type="submit" id="hsave"><span>Save home page</span></button><a class="btn btn--ghost btn--lg" href="index.html" target="_blank" rel="noopener">View site</a></div></form>');
      var f = $('#hf'); bindRows(f);
      f.addEventListener('submit', function (e) {
        e.preventDefault(); var b = $('#hsave'); b.disabled = true; b.classList.add('is-busy');
        var secs = {}; ['marquee', 'trust', 'collections', 'occasions', 'newArrivals', 'story', 'bestsellers', 'testimonials'].forEach(function (k) { secs[k] = chk('s-' + k); });
        var occ = readRows('h-occ').map(function (o) { return { id: o.id, label: o.label, sub: o.sub }; });
        api('PUT', '/api/admin/site', { sections: secs, heroEyebrow: val('h-eye'), heroTitle: val('h-title'), heroLead: val('h-lead'), heroCta: val('h-cta'), marquee: lines('h-marq'), trust: readRows('h-trust'), occasions: occ, story: { eyebrow: val('h-seye'), title: val('h-stitle'), cta: val('h-scta'), steps: readRows('h-steps') }, testimonials: readRows('h-quotes') })
          .then(function () { b.disabled = false; b.classList.remove('is-busy'); $('#hmsg').textContent = ''; toast('Home page saved'); }, function (er) { b.disabled = false; b.classList.remove('is-busy'); $('#hmsg').textContent = er.message; });
      });
      $('#hfile').addEventListener('change', function () {
        var file = this.files[0]; if (!file) return; var err = $('#herr'); err.textContent = 'Preparing photo…'; var rev = rnd();
        Promise.all([makeSizes(file, [480, 800, 1080], 1.25), makeSizes(file, [1280, 1920, 2560], 0.5)]).then(function (sets) {
          var jobs = []; sets[0].forEach(function (p) { jobs.push(['tall', p]); }); sets[1].forEach(function (p) { jobs.push(['wide', p]); });
          return seq(jobs, function (j, i) { err.textContent = 'Uploading ' + (i + 1) + ' of ' + jobs.length + '…'; return post('/api/admin/hero-image?rev=' + rev + '&kind=' + j[0] + '&w=' + j[1].w, j[1].blob); });
        }).then(function () { return api('PUT', '/api/admin/site', { heroImageRev: rev }); }).then(function (r) { var h = r.site.heroImage; cat.site.heroImage = h; setHero(h); err.textContent = ''; toast('Banner photo updated'); }, function (er) { err.textContent = er.message; });
      });
      // update the banner in place — never re-render the form, or the admin's unsaved edits would be lost
      function setHero(h) {
        $('#hprev').src = h ? '/media/s/' + h.rev + '-wide-1280.' + h.ext : 'img/hero-wide-1280.webp';
        $('.herop .muted').textContent = (h ? 'Your photo is showing.' : 'The demo banner is showing.') + ' Landscape photos work best; it’s cropped for phones automatically.';
        var old = $('#hreset'); if (old) old.remove();
        if (h) { var b = document.createElement('button'); b.type = 'button'; b.className = 'link'; b.id = 'hreset'; b.textContent = 'Use the demo banner'; b.addEventListener('click', reset); $('.herop .muted').after(b); }
      }
      function reset() { api('PUT', '/api/admin/site', { heroImageRev: null }).then(function () { cat.site.heroImage = null; setHero(null); toast('Demo banner restored'); }); }
      var rs = $('#hreset'); if (rs) rs.addEventListener('click', reset);
    });
  };

  /* ================= STORE SETTINGS ================= */
  V.store = function () {
    var live = ADM.guard();
    load().then(function () {
      if (!live()) return;
      var t = cat.site;
      view('<div class="adm__stack"><form id="sf" novalidate class="adm__stack">' +
        '<section class="adm__card"><h2>Your store</h2><div class="adm__two3">' + F('t-name', 'Store name', I('t-name', t.name, { max: 40 }), 'Shown as the logo and on bills') + F('t-ann', 'Top-bar message', I('t-ann', t.announcement, { max: 90 }), 'Leave empty to hide') + '</div></section>' +
        '<section class="adm__card"><h2>Contact details <span class="muted">(footer)</span></h2><div class="adm__two3">' + F('t-mail', 'Email', I('t-mail', t.contactEmail, { type: 'email', max: 120, ac: 'off' })) + F('t-tel', 'Phone / WhatsApp', I('t-tel', t.contactPhone, { max: 30 })) + '</div><div class="adm__two3">' + F('t-hrs', 'Opening hours', I('t-hrs', t.contactHours, { max: 60, ph: 'Mon–Sat, 10am–7pm' })) + F('t-adr', 'Address', I('t-adr', t.contactAddress, { max: 200 })) + '</div></section>' +
        '<section class="adm__card"><h2>Shipping</h2><div class="adm__two3">' + F('t-free', 'Free shipping above (₹)', I('t-free', t.shipFreeFrom, { mode: 'numeric' }), '0 = always free') + F('t-flat', 'Shipping fee below that (₹)', I('t-flat', t.shipFlat, { mode: 'numeric' })) + '</div></section>' +
        '<section class="adm__card"><h2>Stitching options</h2><p class="muted">Turn options on/off and set what each adds to the price.</p>' + t.stitch.map(function (x) { return '<div class="strow" data-id="' + x.id + '">' + SW('st-on-' + x.id, '<strong>' + esc(x.label) + '</strong>', x.enabled) + '<div class="adm__two3">' + F('st-l-' + x.id, 'Name', I('st-l-' + x.id, x.label, { max: 30 })) + F('st-a-' + x.id, 'Adds to price (₹)', I('st-a-' + x.id, x.add, { mode: 'numeric' })) + '</div>' + F('st-n-' + x.id, 'Description', I('st-n-' + x.id, x.note, { max: 140 })) + F('st-e-' + x.id, 'Timing', I('st-e-' + x.id, x.eta, { max: 50 })) + '</div>'; }).join('') + '</section>' +
        '<section class="adm__card"><h2>Sizes &amp; size chart</h2><p class="muted">These are the size choices customers see. Measurements are in inches.</p>' + rowsHTML('t-sizes', t.sizeChart, [{ k: 'size', label: 'Size', max: 6, w: 1 }, { k: 'bust', label: 'Bust', max: 6, w: 1 }, { k: 'waist', label: 'Waist', max: 6, w: 1 }, { k: 'hip', label: 'Hip', max: 6, w: 1 }], 12, '+ Add size') + '</section>' +
        '<section class="adm__card"><h2>Policies <span class="muted">(product page &amp; bills)</span></h2>' + F('t-ret', 'Returns', T('t-ret', t.policies.returns, 3, 600)) + F('t-shp', 'Shipping notes — optional', T('t-shp', t.policies.shipping, 2, 600)) + '</section>' +
        '<p class="field__err" id="smsg" role="alert"></p><div class="adm__savebar"><button class="btn btn--lg" type="submit" id="ssave"><span>Save settings</span></button></div></form>' +
        '<form id="cf2" novalidate class="adm__card"><h2>Categories</h2><p class="muted">Used for the menu, shop filters and your products. A category can only be removed once it has no products.</p>' + rowsHTML('c-rows', cat.categories, [{ k: 'label', label: 'Category name', max: 30, w: 4 }, { k: 'id', label: 'id', max: 30, w: 0 }], 12, '+ Add category') + '<p class="field__err" id="cmsg" role="alert"></p><button class="btn btn--lg" type="submit"><span>Save categories</span></button></form>' +
        '<section class="adm__card adm__card--danger"><h2>Going live</h2><p class="muted">Clear the demo content before opening to customers.</p><div class="adm__row"><button class="btn btn--ghost adm__del" id="cd2"' + (cat.demoCount ? '' : ' disabled') + '>Remove ' + cat.demoCount + ' demo products &amp; sample reviews</button><button class="btn btn--ghost adm__del" id="co">Delete ALL orders…</button></div><p class="muted">“Delete all orders” removes every order and payment screenshot — use it only to clear test orders.</p></section></div>');
      var sf = $('#sf'); bindRows(document); 
      $$('.rows [data-k=id]').forEach(function (e) { e.closest('.rrow__c').hidden = true; });
      $$('#h-occ [data-k=id]').forEach(function (e) { e.closest('.rrow__c').hidden = true; });
      sf.addEventListener('submit', function (e) {
        e.preventDefault(); var b = $('#ssave'); b.disabled = true; b.classList.add('is-busy');
        var stitch = t.stitch.map(function (x) { return { id: x.id, enabled: chk('st-on-' + x.id), label: val('st-l-' + x.id), add: val('st-a-' + x.id), note: val('st-n-' + x.id), eta: val('st-e-' + x.id) }; });
        api('PUT', '/api/admin/site', { name: val('t-name'), announcement: val('t-ann'), contactEmail: val('t-mail'), contactPhone: val('t-tel'), contactHours: val('t-hrs'), contactAddress: val('t-adr'), shipFreeFrom: val('t-free'), shipFlat: val('t-flat'), stitch: stitch, sizeChart: readRows('t-sizes'), policies: { returns: val('t-ret'), shipping: val('t-shp') } })
          .then(function () { b.disabled = false; b.classList.remove('is-busy'); $('#smsg').textContent = ''; toast('Settings saved'); }, function (er) { b.disabled = false; b.classList.remove('is-busy'); $('#smsg').textContent = er.message; });
      });
      $('#cf2').addEventListener('submit', function (e) { e.preventDefault(); api('PUT', '/api/admin/categories', { categories: readRows('c-rows').map(function (c) { return { id: c.id, label: c.label }; }) }).then(function () { $('#cmsg').textContent = ''; toast('Categories saved'); }, function (er) { $('#cmsg').textContent = er.message; }); });
      $('#cd2').addEventListener('click', function () { if (confirm('Remove all demo products and sample reviews?')) api('POST', '/api/admin/catalog/clear-demo', {}).then(function (r) { toast(r.removed + ' removed'); ADM.refreshBadges(); V.store(); }); });
      $('#co').addEventListener('click', function () { var w = prompt('This permanently deletes EVERY order and payment screenshot.\n\nType DELETE to confirm:'); if (w === 'DELETE') api('POST', '/api/admin/orders/clear', { confirm: 'DELETE' }).then(function (r) { toast(r.removed + ' orders deleted'); ADM.refreshBadges(); }, function (er) { toast(er.message, 'bad'); }); else if (w !== null) toast('Not deleted — you must type DELETE', 'bad'); });
    });
  };

  /* ================= ADMINS & LOGIN ================= */
  V.security2 = function () {
    var live = ADM.guard();
    api('GET', '/api/admin/admins').then(function (r) {
      if (!live()) return;
      var me = r.admins.filter(function (a) { return a.self; })[0] || {};
      view('<div class="adm__two">' +
        '<section class="adm__card"><h2>Your login</h2><p class="muted">Your email is your admin username. Only admins can see or change this.</p><form id="af" novalidate>' + F('a-name', 'Your name', I('a-name', me.name, { max: 60, ac: 'name' })) + F('a-email', 'Username (email)', I('a-email', me.email, { type: 'email', max: 120, ac: 'username' })) + F('a-new', 'New password <span class="muted">(10+ characters — leave blank to keep)</span>', I('a-new', '', { type: 'password', ac: 'new-password' })) + F('a-cur', 'Current password <span class="muted">(required to save)</span>', I('a-cur', '', { type: 'password', ac: 'current-password' })) + '<p class="field__err" id="amsg" role="alert"></p><button class="btn btn--lg" type="submit"><span>Save my login</span></button></form><p class="muted">Changing your password signs you out on other devices.</p></section>' +
        '<section class="adm__card"><h2>Admins <span class="muted">(' + r.admins.length + ')</span></h2><p class="muted">Add staff who should manage orders and products. They get full admin access.</p><ul class="alist">' + r.admins.map(function (a) { return '<li><span><strong>' + esc(a.email) + '</strong>' + (a.self ? ' <span class="chip-s chip-s--good">You</span>' : '') + '<small>' + esc(a.name || '') + '</small></span>' + (a.self ? '' : '<button type="button" class="btn btn--ghost adm__del" data-rm="' + a.id + '">Remove</button>') + '</li>'; }).join('') + '</ul>' +
        '<h3 class="adm__h">Add an admin</h3><form id="nf" novalidate>' + F('n-name', 'Name', I('n-name', '', { max: 60 })) + F('n-email', 'Email (their username)', I('n-email', '', { type: 'email', max: 120, ac: 'off' })) + F('n-pw', 'Temporary password <span class="muted">(10+ characters)</span>', I('n-pw', '', { type: 'text', ac: 'off' })) + '<p class="field__err" id="nmsg" role="alert"></p><button class="btn" type="submit"><span>Add admin</span></button></form></section></div>' +
        '<section class="adm__card adm__card--narrow"><h2>Who can see what?</h2><ul class="ticks"><li>' + ico('check') + 'Only admins can open this console, change products, QR, settings, or see every order.</li><li>' + ico('check') + 'Customers see only their own orders — never anyone else’s.</li><li>' + ico('check') + 'Admin accounts can only be created or removed here, by an admin.</li></ul></section>');
      $('#af').addEventListener('submit', function (e) { e.preventDefault(); api('POST', '/api/admin/account', { name: val('a-name'), email: val('a-email'), next: val('a-new') || undefined, current: val('a-cur') }).then(function () { $('#amsg').textContent = ''; $('#a-cur').value = ''; $('#a-new').value = ''; toast('Login updated'); }, function (er) { $('#amsg').textContent = er.message; }); });
      $('#nf').addEventListener('submit', function (e) { e.preventDefault(); api('POST', '/api/admin/admins', { name: val('n-name'), email: val('n-email'), password: val('n-pw') }).then(function () { toast('Admin added'); V.security2(); }, function (er) { $('#nmsg').textContent = er.message; }); });
      $$('[data-rm]').forEach(function (b) { b.addEventListener('click', function () { if (confirm('Remove this admin? They are signed out immediately.')) api('DELETE', '/api/admin/admins/' + b.getAttribute('data-rm')).then(function () { toast('Admin removed'); V.security2(); }, function (er) { toast(er.message, 'bad'); }); }); });
    });
  };
})();
