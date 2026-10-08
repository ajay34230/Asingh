/* Theme: "royal" (wine & gold) or "bloom" (fresh pastel). Runs in <head> so there is no flash of the wrong theme. */
(function () {
  var KEY = 'asingh.theme', root = document.documentElement, COLORS = { royal: '#faf6ef', bloom: '#fbf8ff' };
  function get() { try { var t = localStorage.getItem(KEY); if (t === 'bloom' || t === 'royal') return t; } catch (e) {} return 'royal'; }
  function apply(t) {
    root.setAttribute('data-theme', t);
    var m = document.querySelector('meta[name=theme-color]'); if (m) m.setAttribute('content', COLORS[t]);
  }
  function set(t, from) {
    t = t === 'bloom' ? 'bloom' : 'royal'; try { localStorage.setItem(KEY, t); } catch (e) {}
    var rm = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (document.startViewTransition && !rm) {   // circular reveal from the button that was pressed
      var r = from && from.getBoundingClientRect ? from.getBoundingClientRect() : { left: innerWidth - 40, top: 40, width: 0, height: 0 };
      root.style.setProperty('--tx', Math.round(r.left + r.width / 2) + 'px'); root.style.setProperty('--ty', Math.round(r.top + r.height / 2) + 'px');
      root.classList.add('theme-vt'); var vt = document.startViewTransition(function () { apply(t); });
      vt.finished.then(function () { root.classList.remove('theme-vt'); }, function () { root.classList.remove('theme-vt'); });
    } else apply(t);
    document.dispatchEvent(new CustomEvent('asingh:theme', { detail: t }));
  }
  apply(get());
  window.ASINGH_THEME = { get: get, set: set, toggle: function (from) { set(get() === 'bloom' ? 'royal' : 'bloom', from); } };
})();
