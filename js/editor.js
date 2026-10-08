/* Live text editor — only ever loaded for a signed-in admin. Tap any word or line on the real site and rewrite it;
   the change is saved straight away (English or Hindi, whichever language the page is showing). */
(function () {
  'use strict';
  var A = window.ASINGH, U = A.U, esc = U.esc, on = false, ui, pop, cur = null;
  var SKIP = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1 };
  var inUi = function (el) { return el && el.closest && el.closest('#ed-ui,#ed-pop'); };

  function textAt(x, y) {
    var n = null;
    if (document.caretPositionFromPoint) { var cp = document.caretPositionFromPoint(x, y); n = cp && cp.offsetNode; }
    else if (document.caretRangeFromPoint) { var r = document.caretRangeFromPoint(x, y); n = r && r.startContainer; }
    if (n && n.nodeType === 3 && n.nodeValue.trim() && !SKIP[n.parentNode.nodeName]) {
      var rg = document.createRange(); rg.selectNodeContents(n); var b = rg.getBoundingClientRect();
      if (x >= b.left - 6 && x <= b.right + 6 && y >= b.top - 6 && y <= b.bottom + 6) return n;
    }
    return null;
  }
  function firstText(el) {
    var w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null), n;
    while ((n = w.nextNode())) if (n.nodeValue.trim() && !SKIP[n.parentNode.nodeName]) return n;
    return null;
  }
  function productHint(txt) {
    var t = A.Lang.norm(txt);
    return (A.PRODUCTS || []).some(function (p) { return A.Lang.norm(p.name) === t || A.Lang.norm(p.blurb || '') === t || A.Lang.norm(p.fabric || '') === t; });
  }
  function show(target) {
    cur = target; var hi = A.Lang.mode() === 'hi', shown = target.node ? target.node.nodeValue.trim() : target.el.getAttribute('placeholder') || '';
    var src = target.node ? A.Lang.source(target.node).trim().replace(/\s+/g, ' ') : target.el.getAttribute('data-en-placeholder') || shown;
    var note = '';
    if (target.node && target.node.parentNode.closest('[data-no-i18n]')) note = '<p class="ed__note">This text (the shop name) is set in <a href="admin.html#/store">Admin → Store settings</a>.</p>';
    else if (productHint(src)) note = '<p class="ed__note">This is product text. Change it in <a href="admin.html#/products">Admin → Products</a> (it applies everywhere).</p>';
    pop.innerHTML = '<div class="ed__card" role="dialog" aria-label="Edit text"><div class="ed__top"><strong>Edit this text</strong><span class="ed__lang">' + (hi ? 'हिन्दी' : 'English') + '</span></div>' +
      (hi ? '<p class="ed__orig">English: ' + esc(src) + '</p>' : (src !== shown ? '<p class="ed__orig">Original: ' + esc(src) + '</p>' : '')) + note +
      '<label class="vh" for="ed-in">New wording</label><textarea id="ed-in" rows="' + Math.min(6, Math.max(2, Math.ceil(shown.length / 40))) + '" maxlength="600"></textarea><p class="ed__err" id="ed-err" role="alert"></p>' +
      '<div class="ed__row"><button type="button" class="btn" id="ed-save"><span>Save</span></button><button type="button" class="btn btn--ghost" id="ed-reset"><span>Restore original</span></button><button type="button" class="btn btn--ghost" id="ed-cancel"><span>Cancel</span></button></div></div>';
    pop.hidden = false; var ta = pop.querySelector('#ed-in'); ta.value = shown; cur.src = src; ta.focus(); ta.select();
  }
  function hide() { pop.hidden = true; pop.innerHTML = ''; cur = null; }
  function save(value) {
    var hi = A.Lang.mode() === 'hi', btn = pop.querySelector('#ed-save'), err = pop.querySelector('#ed-err'); err.textContent = '';
    if (cur.src.length > 300) { err.textContent = 'This paragraph is too long to edit here. Long text lives in Admin → Pages.'; return; }
    btn.disabled = true;
    U.api('PUT', '/api/admin/textedit', { lang: hi ? 'hi' : 'en', from: cur.src, to: value }).then(function (r) {
      A.SITE.textEdits = r.textEdits || {}; A.SITE.translations = r.translations || {}; hide(); A.Lang.refresh(); U.toast(value ? 'Saved — everyone sees it now' : 'Restored the original wording');
    }, function (e) { err.textContent = e.message; btn.disabled = false; });
  }
  function onClick(e) {
    if (!on || inUi(e.target)) return;
    var chip = e.target.closest('[data-ed-hide]'); if (chip) { e.preventDefault(); e.stopPropagation(); return hideSection(chip); }
    e.preventDefault(); e.stopPropagation();
    var t = e.target, node = textAt(e.clientX, e.clientY);
    if (!node && t.nodeName !== 'INPUT' && t.nodeName !== 'TEXTAREA') node = firstText(t);
    if (node) return show({ node: node });
    if ((t.nodeName === 'INPUT' || t.nodeName === 'TEXTAREA') && t.getAttribute('placeholder')) return show({ el: t });
    U.toast('No text here — tap on a word or line.');
  }
  function hideSection(chip) {
    var el = chip.closest('[data-sec]'), id = el.getAttribute('data-sec'), s = {}; s[id] = false;
    U.api('PUT', '/api/admin/site', { sections: s }).then(function () { el.remove(); U.toast('Section hidden. Bring it back any time in Admin → Home page.'); }, function (er) { U.toast(er.message); });
  }
  function chips() {
    document.querySelectorAll('[data-sec]').forEach(function (el) {
      if (el.querySelector(':scope > [data-ed-hide]')) return; var b = document.createElement('button'); b.type = 'button'; b.className = 'ed__hide'; b.setAttribute('data-ed-hide', ''); b.textContent = 'Hide this section'; el.style.position = el.style.position || 'relative'; el.appendChild(b);
    });
  }
  function enter() {
    on = true; document.documentElement.classList.add('is-editing'); ui.innerHTML = '<span><strong>Edit mode</strong> — tap any word or line to change it. Changes save instantly.</span><button type="button" class="btn btn--sm" id="ed-done"><span>Done</span></button>'; ui.hidden = false; chips();
    var b = document.getElementById('editbtn'); if (b) b.hidden = true;
  }
  function leave() { on = false; document.documentElement.classList.remove('is-editing'); ui.hidden = true; hide(); document.querySelectorAll('[data-ed-hide]').forEach(function (x) { x.remove(); }); var b = document.getElementById('editbtn'); if (b) b.hidden = false; }
  function build() {
    ui = document.createElement('div'); ui.id = 'ed-ui'; ui.className = 'ed__bar'; ui.hidden = true; ui.setAttribute('role', 'region'); ui.setAttribute('aria-label', 'Edit mode');
    pop = document.createElement('div'); pop.id = 'ed-pop'; pop.className = 'ed__pop'; pop.hidden = true; document.body.appendChild(ui); document.body.appendChild(pop);
    document.addEventListener('click', onClick, true);
    ['submit', 'auxclick'].forEach(function (ev) { document.addEventListener(ev, function (e) { if (on && !inUi(e.target)) { e.preventDefault(); e.stopPropagation(); } }, true); });
    ui.addEventListener('click', function (e) { if (e.target.closest('#ed-done')) leave(); });
    pop.addEventListener('click', function (e) {
      if (e.target.closest('#ed-cancel')) hide(); else if (e.target.closest('#ed-save')) save(pop.querySelector('#ed-in').value.trim()); else if (e.target.closest('#ed-reset')) save('');
    });
    document.addEventListener('keydown', function (e) { if (on && e.key === 'Escape') { if (!pop.hidden) hide(); else leave(); } if (on && !pop.hidden && e.key === 'Enter' && (e.ctrlKey || e.metaKey)) save(pop.querySelector('#ed-in').value.trim()); });
    document.addEventListener('asingh:lang', function () { if (on) hide(); });
  }
  window.ASINGH_EDITOR = { start: function () { if (!ui) build(); enter(); } };
}());
