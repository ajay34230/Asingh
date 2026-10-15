/* LocalDrop: small helpers shared by every screen. No frameworks, no build step. */
(function () {
  'use strict';
  var LD = (window.LD = window.LD || {});
  LD.screens = LD.screens || {};

  // ---- events ---------------------------------------------------------------
  var listeners = {};
  LD.on = function (name, fn) {
    (listeners[name] = listeners[name] || []).push(fn);
    return function () {
      listeners[name] = (listeners[name] || []).filter(function (f) { return f !== fn; });
    };
  };
  LD.emit = function (name, data) {
    (listeners[name] || []).slice().forEach(function (fn) {
      try { fn(data); } catch (e) { console.error(e); }
    });
  };

  // ---- DOM ------------------------------------------------------------------
  function append(el, kids) {
    for (var i = 0; i < kids.length; i++) {
      var k = kids[i];
      if (k == null || k === false) continue;
      if (Array.isArray(k)) append(el, k);
      else if (k instanceof Node) el.appendChild(k);
      else el.appendChild(document.createTextNode(String(k)));
    }
  }

  /** h('div', {class: 'x', onClick: fn}, child, 'text') builds elements without ever parsing HTML. */
  LD.h = function (tag, attrs) {
    var el = document.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        var v = attrs[k];
        if (v == null || v === false) continue;
        if (k === 'class') el.className = v;
        else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
        else if (k === 'dataset') Object.assign(el.dataset, v);
        else if (k.slice(0, 2) === 'on' && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
        else if (k === 'value' || k === 'checked' || k === 'disabled' || k === 'selected') el[k] = v;
        else if (v === true) el.setAttribute(k, '');
        else el.setAttribute(k, v);
      }
    }
    append(el, Array.prototype.slice.call(arguments, 2));
    return el;
  };
  LD.clear = function (el) {
    while (el.firstChild) el.removeChild(el.firstChild);
    return el;
  };
  LD.$ = function (sel, root) { return (root || document).querySelector(sel); };
  LD.$$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

  // ---- formatting -----------------------------------------------------------
  LD.fmtSize = function (n) {
    if (n == null) return '';
    if (n < 1024) return n + ' B';
    var u = ['KB', 'MB', 'GB', 'TB'];
    var i = -1;
    do { n /= 1024; i++; } while (n >= 1024 && i < u.length - 1);
    return (n >= 100 ? n.toFixed(0) : n >= 10 ? n.toFixed(1) : n.toFixed(2)).replace(/(\.\d*?)0+$/, '$1').replace(/\.$/, '') + ' ' + u[i];
  };
  LD.fmtSpeed = function (bps) {
    return LD.fmtSize(bps) + '/s';
  };
  LD.fmtAgo = function (t) {
    var s = Math.round((Date.now() - t) / 1000);
    if (s < 10) return 'just now';
    if (s < 60) return s + ' s ago';
    var m = Math.round(s / 60);
    if (m < 60) return m + ' min ago';
    var hr = Math.round(m / 60);
    if (hr < 24) return hr + (hr === 1 ? ' hour ago' : ' hours ago');
    var d = new Date(t);
    var today = new Date();
    var y = new Date(today.getTime() - 86400000);
    if (d.toDateString() === y.toDateString()) return 'Yesterday';
    return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: d.getFullYear() === today.getFullYear() ? undefined : 'numeric' });
  };
  LD.fmtClock = function (t) {
    return new Date(t).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  };
  LD.fmtDay = function (t) {
    var d = new Date(t);
    var today = new Date();
    var y = new Date(today.getTime() - 86400000);
    if (d.toDateString() === today.toDateString()) return 'Today';
    if (d.toDateString() === y.toDateString()) return 'Yesterday';
    return d.toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'long' });
  };

  LD.uuid = function () {
    var b = new Uint8Array(16);
    (window.crypto || window.msCrypto).getRandomValues(b);
    return Array.prototype.map.call(b, function (x) { return ('0' + x.toString(16)).slice(-2); }).join('').replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, '$1-$2-$3-$4-$5');
  };

  LD.debounce = function (fn, ms) {
    var t;
    return function () {
      var a = arguments, self = this;
      clearTimeout(t);
      t = setTimeout(function () { fn.apply(self, a); }, ms);
    };
  };

  LD.store = {
    get: function (k, d) { try { var v = localStorage.getItem(k); return v == null ? d : v; } catch (e) { return d; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) { /* private mode */ } }
  };

  LD.isHostApp = /LocalDropHost/.test(navigator.userAgent) && !!window.LDHost;
  LD.reducedMotion = function () {
    return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  };

  // ---- device guess ---------------------------------------------------------
  LD.guessDevice = function () {
    var ua = navigator.userAgent;
    var os = 'Device', kind = 'other', br = '';
    if (/iPhone/.test(ua)) { os = 'iPhone'; kind = 'phone'; }
    else if (/iPad/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)) { os = 'iPad'; kind = 'tablet'; }
    else if (/Android/.test(ua)) { os = 'Android'; kind = /Mobile/.test(ua) ? 'phone' : 'tablet'; }
    else if (/Windows/.test(ua)) { os = 'Windows'; kind = 'desktop'; }
    else if (/CrOS/.test(ua)) { os = 'Chromebook'; kind = 'laptop'; }
    else if (/Mac OS X/.test(ua)) { os = 'Mac'; kind = 'laptop'; }
    else if (/Linux/.test(ua)) { os = 'Linux'; kind = 'desktop'; }
    if (/Edg\//.test(ua)) br = 'Edge';
    else if (/OPR\/|Opera/.test(ua)) br = 'Opera';
    else if (/Firefox\//.test(ua)) br = 'Firefox';
    else if (/SamsungBrowser/.test(ua)) br = 'Samsung Internet';
    else if (/Chrome\//.test(ua)) br = 'Chrome';
    else if (/Safari\//.test(ua)) br = 'Safari';
    return { kind: kind, name: br ? br + ' on ' + os : os };
  };

  // ---- clipboard ------------------------------------------------------------
  LD.copy = function (text) {
    return new Promise(function (resolve, reject) {
      try {
        if (LD.isHostApp && window.LDHost.copy) { window.LDHost.copy(text); resolve(); return; }
      } catch (e) { /* fall through */ }
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(resolve, function () { legacy(); });
      } else {
        legacy();
      }
      function legacy() {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;';
        document.body.appendChild(ta);
        ta.select();
        ta.setSelectionRange(0, text.length);
        var ok = false;
        try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
        document.body.removeChild(ta);
        ok ? resolve() : reject(new Error('copy failed'));
      }
    });
  };

  /** Turns plain text into text and links, safely. */
  LD.linkify = function (text) {
    var out = [];
    var re = /\b((?:https?:\/\/|www\.)[^\s<]+[^\s<.,;:!?)"'\]])/gi;
    var last = 0, m;
    while ((m = re.exec(text))) {
      if (m.index > last) out.push(text.slice(last, m.index));
      var href = m[1];
      var url = /^www\./i.test(href) ? 'http://' + href : href;
      out.push(LD.h('a', { href: url, target: '_blank', rel: 'noopener noreferrer' }, href));
      last = m.index + m[0].length;
    }
    if (last < text.length) out.push(text.slice(last));
    return out;
  };

  LD.encodePath = function (p) { return encodeURIComponent(p); };
  LD.joinPath = function (a, b) { return a ? a + '/' + b : b; };
  LD.parentPath = function (p) { var i = p.lastIndexOf('/'); return i < 0 ? '' : p.slice(0, i); };
  LD.baseName = function (p) { var i = p.lastIndexOf('/'); return i < 0 ? p : p.slice(i + 1); };
  LD.ext = function (n) { var i = n.lastIndexOf('.'); return i > 0 ? n.slice(i + 1).toLowerCase() : ''; };
})();
