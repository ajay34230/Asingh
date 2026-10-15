/* LocalDrop: shows files that other devices are sending to this one while they arrive. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  var rx = {};       // id -> {id, name, size, loaded, from, t, speed, last}
  var tray = null;
  var sweeper = null;

  function trayEl() {
    if (tray) return tray;
    tray = h('div', { class: 'tray rx', role: 'status', 'aria-live': 'polite', hidden: true });
    document.body.appendChild(tray);
    return tray;
  }

  function render() {
    var el = trayEl();
    var ids = Object.keys(rx);
    el.hidden = !ids.length;
    LD.clear(el);
    ids.forEach(function (id) {
      var t = rx[id];
      var pct = t.size ? Math.min(100, Math.round(t.loaded / t.size * 100)) : 0;
      el.appendChild(h('div', { class: 'rx-row' },
        h('div', { class: 'tray-head' },
          h('span', { class: 'tray-ic' }, LD.icon('download', 20)),
          h('div', { class: 'tray-title' },
            h('b', {}, 'Receiving ' + t.name),
            h('span', {}, 'from ' + t.from.name + ' · ' + LD.fmtSize(t.loaded) + ' of ' + LD.fmtSize(t.size) + (t.speed ? ' · ' + LD.fmtSpeed(t.speed) : ''))),
          h('b', { class: 'rx-pct' }, pct + '%')),
        h('div', { class: 'progress' }, h('i', { style: { width: pct + '%' } }))));
    });
  }

  LD.on('transfer', function (m) {
    if (S.you && m.from && m.from.id === S.you.id) return;
    var now = Date.now();
    var t = rx[m.id];
    if (m.state === 'done' || m.state === 'failed') {
      if (t) {
        delete rx[m.id];
        if (m.state === 'failed') LD.toast(m.from.name + '’s file ' + m.name + ' didn’t arrive.', 'error');
        else LD.toast('Received ' + m.name + ' from ' + m.from.name, 'ok');
      }
      render();
      return;
    }
    if (!t) t = rx[m.id] = { id: m.id, name: m.name, size: m.size, loaded: 0, from: m.from, speed: 0, last: now, lastLoaded: 0 };
    var dt = (now - t.last) / 1000;
    if (dt > 0.2) {
      var inst = (m.loaded - t.lastLoaded) / dt;
      t.speed = t.speed ? t.speed * 0.6 + inst * 0.4 : inst;
      t.last = now;
      t.lastLoaded = m.loaded;
    }
    t.loaded = m.loaded;
    t.size = m.size;
    t.seen = now;
    render();
    if (!sweeper) sweeper = setInterval(function () {
      var cut = Date.now() - 20000, changed = false;
      Object.keys(rx).forEach(function (id) { if ((rx[id].seen || 0) < cut) { delete rx[id]; changed = true; } });
      if (changed) render();
      if (!Object.keys(rx).length) { clearInterval(sweeper); sweeper = null; }
    }, 5000);
  });
})();
