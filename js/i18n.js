/* Language: English / हिन्दी. Translates the storefront in place: exact-match dictionary + a few patterns, plus the
   store owner's own translations (Admin → Hindi) for products, categories and other custom text. English is the source. */
(function (A) {
  'use strict';
  var KEY = 'asingh.lang', root = document.documentElement, HI = {}, PAT = [], OWN = {};
  var SKIP = { SCRIPT: 1, STYLE: 1, TEXTAREA: 1, NOSCRIPT: 1, CODE: 1 }, ATTRS = ['placeholder', 'aria-label', 'title', 'alt'];
  var orig = new WeakMap();   // text node -> English text
  var lang = 'en', obs = null, busy = false;

  function norm(s) { return String(s).replace(/\s+/g, ' ').trim(); }
  function lookup(en, depth) {
    var k = norm(en); if (!k) return null;
    if (OWN[k]) return OWN[k]; if (HI[k]) return HI[k];
    depth = depth || 0; if (depth > 3) return null;
    for (var i = 0; i < PAT.length; i++) {
      var m = PAT[i][0].exec(k);
      if (m) { var out = PAT[i][1].replace(/\$(\d)/g, function (_, n) { var g = m[n]; if (g == null) return ''; var h = lookup(g, depth + 1); return h == null ? g : h; }); return out === k ? null : out; }
    }
    var seps = [' · ', ', ', ' / ', ' — '];                      // "Georgette · bandhani", "Emerald, Wine"
    for (var j = 0; j < seps.length; j++) {
      if (k.indexOf(seps[j]) > 0) { var any = false, parts = k.split(seps[j]).map(function (x) { var h = lookup(x, depth + 1); if (h != null) any = true; return h == null ? x : h; }); if (any) return parts.join(seps[j]); }
    }
    return null;
  }
  function tr(s) { if (lang !== 'hi') return s; var h = lookup(s); return h == null ? s : h; }

  function doText(n) {
    var p = n.parentNode; if (!p || SKIP[p.nodeName] || (p.closest && p.closest('[data-no-i18n]'))) return;
    var cur = n.nodeValue, saved = orig.get(n);
    if (saved !== undefined && norm(cur) === norm(saved.hi)) return;                  // already our translation
    var h = lookup(cur); if (h == null) { orig.delete(n); return; }
    var lead = /^\s*/.exec(cur)[0], trail = /\s*$/.exec(cur)[0];
    orig.set(n, { en: cur, hi: h }); n.nodeValue = lead + h + trail;
  }
  function doAttrs(el) {
    if (!el.getAttribute || (el.closest && el.closest('[data-no-i18n]'))) return;
    ATTRS.forEach(function (a) {
      var v = el.getAttribute(a); if (!v) return; var key = 'data-en-' + a, saved = el.getAttribute(key);
      if (saved !== null && norm(v) === norm(lookup(saved) || saved)) return;
      var h = lookup(v); if (h == null) return; if (saved === null) el.setAttribute(key, v); el.setAttribute(a, h);
    });
  }
  function walk(node) {
    if (node.nodeType === 3) return doText(node);
    if (node.nodeType !== 1 || SKIP[node.nodeName]) return;
    doAttrs(node);
    for (var c = node.firstChild; c; c = c.nextSibling) walk(c);
  }
  function title() {
    if (!document.documentElement.hasAttribute('data-en-title')) document.documentElement.setAttribute('data-en-title', document.title);
    var en = document.documentElement.getAttribute('data-en-title');
    if (document.title !== en && document.title !== (lang === 'hi' ? parts(en) : en)) { en = document.title; document.documentElement.setAttribute('data-en-title', en); }
    document.title = lang === 'hi' ? parts(en) : en;
  }
  function parts(t) { return String(t).split(/ (?:—|\|) /).map(function (x) { var h = lookup(x); return h == null ? x : h; }).join(' — '); }

  function restore(node) {
    var w = document.createTreeWalker(node, NodeFilter.SHOW_TEXT, null), n, list = [];
    while ((n = w.nextNode())) list.push(n);
    list.forEach(function (t) { var s = orig.get(t); if (s) { t.nodeValue = s.en; orig.delete(t); } });
    ATTRS.forEach(function (a) { node.querySelectorAll('[data-en-' + a + ']').forEach(function (el) { el.setAttribute(a, el.getAttribute('data-en-' + a)); el.removeAttribute('data-en-' + a); }); });
  }
  function start() {
    if (obs) return; obs = new MutationObserver(function (muts) {
      if (busy || lang !== 'hi') return; busy = true;
      try { muts.forEach(function (m) { if (m.type === 'childList') m.addedNodes.forEach(walk); else if (m.type === 'characterData') doText(m.target); else if (m.type === 'attributes') doAttrs(m.target); }); title(); } finally { busy = false; }
    });
    obs.observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS });
  }
  function apply(l) {
    lang = l === 'hi' ? 'hi' : 'en'; root.setAttribute('lang', lang === 'hi' ? 'hi' : 'en'); root.setAttribute('data-lang', lang);
    try { document.cookie = 'as_lang=' + lang + '; Path=/; Max-Age=31536000; SameSite=Lax'; } catch (e) {}
    if (!document.body) return;
    busy = true; try { if (lang === 'hi') { walk(document.body); } else restore(document.body); title(); } finally { busy = false; }
    if (lang === 'hi') start();
    document.dispatchEvent(new CustomEvent('asingh:lang', { detail: lang }));
  }
  function dict(cb) {   // the Hindi dictionary is only downloaded when Hindi is chosen
    if (A.I18N) return cb(); var sc = document.createElement('script'); sc.src = '/js/i18n-hi.js'; sc.onload = function () { load(); cb(); }; sc.onerror = cb; document.head.appendChild(sc);
  }
  function get() { try { var l = localStorage.getItem(KEY); if (l === 'hi' || l === 'en') return l; } catch (e) {} return 'en'; }
  function set(l) { try { localStorage.setItem(KEY, l); } catch (e) {} if (document.body.hasAttribute('data-cms')) { document.cookie = 'as_lang=' + l + '; Path=/; Max-Age=31536000; SameSite=Lax'; location.reload(); return; } if (l === 'hi') dict(function () { apply('hi'); }); else apply(l); }
  function load() {
    var site = A.SITE || {}; OWN = {}; var t = site.translations || {}; Object.keys(t).forEach(function (k) { if (t[k]) OWN[norm(k)] = t[k]; });
    (A.PAGES || []).forEach(function (p) { if (p.titleHi) OWN[norm(p.title)] = p.titleHi; });
    HI = (A.I18N && A.I18N.hi) || {}; PAT = (A.I18N && A.I18N.pat) || [];
  }
  A.Lang = { get: get, set: set, tr: tr, lookup: lookup, norm: norm, builtin: function () { return HI; } };
  root.setAttribute('lang', 'en');
  function init() {
    load();
    if (document.body.hasAttribute('data-cms')) {   // server renders the page text in the language of the cookie — keep it in step with the saved choice
      var ck = /(?:^|;\s*)as_lang=hi\b/.test(document.cookie) ? 'hi' : 'en';
      if (ck !== get()) { document.cookie = 'as_lang=' + get() + '; Path=/; Max-Age=31536000; SameSite=Lax'; location.reload(); return; }
    } if (get() === 'hi') dict(function () { apply('hi'); }); else { root.setAttribute('data-lang', 'en'); document.cookie = 'as_lang=en; Path=/; Max-Age=31536000; SameSite=Lax'; } }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { setTimeout(init, 0); }); else setTimeout(init, 0);
  document.addEventListener('asingh:ready', function () { load(); if (get() === 'hi' && A.I18N) apply('hi'); });
})(window.ASINGH = window.ASINGH || {});
