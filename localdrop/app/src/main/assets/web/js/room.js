/* LocalDrop: the shared room. Phones that have the app and are on the same network find each other and end up in one place without anyone scanning anything. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  var app = LD.isHostApp && window.LDHost && window.LDHost.room;
  var onRemote = location.hostname !== '127.0.0.1' && location.hostname !== 'localhost';
  var moving = false;
  var strikes = 0;

  function room() { try { return JSON.parse(window.LDHost.room()); } catch (e) { return {}; } }

  function ping(url) {
    var ctl = new AbortController();
    var t = setTimeout(function () { ctl.abort(); }, 2500);
    return fetch(url + 'api/ping', { mode: 'no-cors', cache: 'no-store', signal: ctl.signal }).then(function () { clearTimeout(t); return true; }, function () { clearTimeout(t); return false; });
  }

  function leave(url, text) {
    if (moving) return;
    moving = true;
    LD.toast(text, 'ok');
    setTimeout(function () { location.href = url; }, 600);
  }

  function goHome() { leave(window.LDHost.home(), 'Back on your own phone'); }

  // ---- the app on a phone ---------------------------------------------------------------------------
  function check() {
    if (!app || moving) return;
    var r = room();
    if (!r.on) { if (onRemote) goHome(); return; }
    var l = r.leader;
    if (!l) return;
    if (!onRemote) {
      if (l.self) return;
      ping(l.url).then(function (ok) {
        if (ok) leave((l.tlsUrl || l.url) + '#aj=1', 'Joining ' + l.name + '’s room');
        else { window.LDHost.peerDown(l.id); setTimeout(check, 400); }
      });
    } else {
      if (l.self) { goHome(); return; }
      var want = (l.tlsUrl || l.url).replace(/^https?:\/\/([^/]+).*$/, '$1');
      if (want !== location.host) { leave((l.tlsUrl || l.url) + '#aj=1', 'Moving to ' + l.name + '’s room'); return; }
      ping(location.origin + '/').then(function (ok) {
        if (ok) { strikes = 0; return; }
        if (++strikes >= 2) { strikes = 0; window.LDHost.peerDown(l.id); setTimeout(check, 400); }
      });
    }
  }

  // ---- a bar that says which room this phone is in --------------------------------------------------
  function bar() {
    if (!app || !onRemote) return;
    var name = ((room().leader || {}).name) || 'another phone';
    var el = h('div', { class: 'room-bar', role: 'status' },
      LD.icon('wifi', 16), h('span', {}, 'In ' + name + '’s room'),
      h('button', { class: 'room-leave', onClick: function () { window.LDHost.setAutoConnect(false); goHome(); } }, 'Use my own phone'));
    document.body.appendChild(el);
    document.body.classList.add('in-room');
  }

  // ---- browsers (PWA or any browser): follow the room host --------------------------------------------
  // A PC can stay on its own page: open http://127.0.0.1:8080/#stay once.
  function stay() {
    try { if (location.hash.indexOf('stay') > 0) localStorage.setItem('ld_stay', '1'); if (location.hash.indexOf('own') > 0) localStorage.removeItem('ld_stay'); return !!localStorage.getItem('ld_stay'); } catch (e) { return false; }
  }

  function follow() {
    var pc = S.isHost && S.info && S.info.platform === 'desktop' && !stay();
    if (app || !S.info || (S.isHost && !pc)) return;
    var r = S.info.room;
    if (!r || !r.leader || r.leader.self || moving) return;
    var l = r.leader;
    var base = location.protocol === 'https:' && l.tlsUrl ? l.tlsUrl : l.url;
    var name = pc ? S.info.hostName : (LD.store.get('ld_name', '') || '');
    var id = pc ? r.self : (LD.store.get('ld_device', '') || '');
    ping(l.url).then(function (ok) {
      if (!ok) return;
      leave(base + '#aj=1&n=' + encodeURIComponent(name) + '&d=' + encodeURIComponent(id), 'Joining ' + l.name + '’s room');
    });
  }

  // Remember where LocalDrop lives, so the app can find it again when the address changes (see finder.js).
  function remember() {
    try {
      var f = JSON.parse(localStorage.getItem('ldfind') || '{}');
      var hs = (f.hosts || []).filter(function (x) { return x !== location.host; });
      hs.unshift(location.host);
      f.hosts = hs.slice(0, 6);
      f.n = LD.store.get('ld_name', '') || f.n || '';
      f.d = LD.store.get('ld_device', '') || f.d || '';
      localStorage.setItem('ldfind', JSON.stringify(f));
    } catch (e) { /* storage unavailable */ }
  }

  LD.room = { check: check, follow: follow, bar: bar, remember: remember };
  LD.on('nearby', check);
  if (app) {
    setTimeout(check, 3000);
    setInterval(check, 8000);
  }
  setInterval(function () {
    var pc = S.isHost && S.info && S.info.platform === 'desktop';
    if (app || !S.info || (S.isHost && !pc) || !S.you) return;
    LD.api.get('/api/info', { quiet: true }).then(function (i) { S.info.room = i.room; follow(); }, function () { /* offline for now */ });
  }, 15000);
})();
