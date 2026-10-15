/* LocalDrop: start-up, sign-in, the app shell and navigation. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  LD.screens = LD.screens || {};
  var TABS = [
    { id: 'files', label: 'Files', icon: 'folder' },
    { id: 'drop', label: 'Drop', icon: 'message' },
    { id: 'nearby', label: 'Nearby', icon: 'radar' },
    { id: 'settings', label: 'Settings', icon: 'sliders' }
  ];

  var rootEl = document.getElementById('root');
  var booting = false;
  var shellBuilt = false;
  var shell = null;

  // ---- routing --------------------------------------------------------------
  function parseHash() {
    var raw = (location.hash || '').replace(/^#\/?/, '');
    var parts = raw.split('/');
    var tab = parts.shift() || '';
    if (!TABS.some(function (t) { return t.id === tab; })) return { tab: S.isHost ? 'nearby' : 'files', path: '' };
    var path = '';
    try { path = parts.map(decodeURIComponent).join('/'); } catch (e) { path = ''; }
    return { tab: tab, path: tab === 'files' ? path : '' };
  }
  LD.go = function (tab, path, replace) {
    var hash = '#/' + tab + (tab === 'files' && path ? '/' + path.split('/').map(encodeURIComponent).join('/') : '');
    if (location.hash === hash) { route(); return; }
    if (replace) location.replace(hash); else location.hash = hash;
  };

  function route() {
    if (!shellBuilt) return;
    var r = parseHash();
    var prev = S.tab;
    S.tab = r.tab;
    if (r.tab === 'drop') { S.unread = 0; LD.emit('unread'); }
    LD.emit('tab', r.tab);
    TABS.forEach(function (t) {
      var scr = shell.screens[t.id];
      var on = t.id === r.tab;
      scr.hidden = !on;
      scr.classList.toggle('active', on);
      shell.navBtns[t.id].classList.toggle('on', on);
      shell.navBtns[t.id].setAttribute('aria-current', on ? 'page' : 'false');
    });
    if (r.tab === 'files') LD.screens.files.setPath(r.path);
    if (prev !== r.tab && LD.screens[r.tab] && LD.screens[r.tab].onShow) LD.screens[r.tab].onShow();
    var main = shell.main;
    if (prev !== r.tab && !LD.reducedMotion()) {
      var scr2 = shell.screens[r.tab];
      scr2.classList.remove('enter');
      void scr2.offsetWidth;
      scr2.classList.add('enter');
    }
    main.scrollTop = 0;
  }
  window.addEventListener('hashchange', route);

  /** Android's Back button asks the page first. */
  window.LDBack = function () {
    if (LD.overlays.closeTop()) return true;
    if (!shellBuilt) return false;
    if (S.tab === 'files' && S.path) {
      if (LD.screens.files.handleBack && LD.screens.files.handleBack()) return true;
      LD.go('files', LD.parentPath(S.path));
      return true;
    }
    if (S.tab !== (S.isHost ? 'nearby' : 'files')) {
      LD.go(S.isHost ? 'nearby' : 'files');
      return true;
    }
    return false;
  };
  window.onLDHostChange = function () { LD.emit('host-change'); };

  // ---- shell ----------------------------------------------------------------
  function buildShell() {
    LD.clear(rootEl);
    var navBtns = {};
    var badge = h('span', { class: 'nav-badge', hidden: true });
    var nav = h('nav', { class: 'nav', 'aria-label': 'Sections' }, TABS.map(function (t) {
      var b = h('button', { class: 'nav-btn', onClick: function () { LD.go(t.id, t.id === 'files' ? S.path : ''); }, 'aria-label': t.label },
        h('span', { class: 'nav-ic' }, LD.icon(t.icon, 22), t.id === 'drop' ? badge : null),
        h('span', { class: 'nav-label' }, t.label));
      navBtns[t.id] = b;
      return b;
    }));
    var dot = h('span', { class: 'conn-dot' });
    var connText = h('span', { class: 'conn-text' });
    var conn = h('button', { class: 'conn', onClick: function () { LD.go('nearby'); }, 'aria-label': 'Connection' }, dot, connText);
    var topbar = h('header', { class: 'topbar' },
      h('div', { class: 'brand' }, h('span', { class: 'brand-mark' }, LD.logo(30)), h('h1', {}, 'LocalDrop')),
      conn,
      h('button', { class: 'icon-btn invite-btn', 'aria-label': 'Invite someone with a QR code', onClick: function () { LD.openInvite(); } }, LD.icon('qr', 22)));
    var offline = h('div', { class: 'offline', role: 'status', hidden: true }, LD.icon('wifi', 16), h('span', {}, 'Connection lost. Trying to reconnect…'));
    var screens = {};
    var main = h('main', { class: 'main', id: 'main' });
    TABS.forEach(function (t) {
      var s = h('section', { class: 'screen screen-' + t.id, hidden: true, 'aria-label': t.label });
      screens[t.id] = s;
      main.appendChild(s);
    });
    var app = h('div', { class: 'app' }, topbar, offline, h('div', { class: 'body' }, nav, main));
    rootEl.appendChild(app);
    shell = { main: main, screens: screens, navBtns: navBtns, offline: offline, badge: badge, dot: dot, connText: connText };
    shellBuilt = true;

    ['files', 'drop', 'nearby', 'settings'].forEach(function (id) { LD.screens[id].mount(screens[id]); });

    function updateConn() {
      var others = S.devices.filter(function (d) { return !d.host && d.online && (!S.you || d.id !== S.you.id); }).length;
      var host = S.devices.filter(function (d) { return d.host; })[0];
      var txt;
      if (S.isHost) txt = others ? others + ' connected' : 'No one yet';
      else txt = 'Connected' + (host ? ' to ' + host.name : '');
      connText.textContent = txt;
      dot.classList.toggle('live', S.online && (!S.isHost || others > 0));
      dot.classList.toggle('off', !S.online);
    }
    LD.on('devices', updateConn);
    LD.on('online', function (on) {
      offline.hidden = on;
      updateConn();
    });
    function updateBadge() {
      badge.hidden = !S.unread;
      badge.textContent = S.unread > 9 ? '9+' : String(S.unread);
    }
    LD.on('message', updateBadge);
    LD.on('unread', updateBadge);
    LD.on('arrived', function (d) { LD.toast(d.name + ' joined', 'ok'); });
    LD.on('perms', function () { document.body.classList.toggle('no-upload', !S.perms.upload); });
    updateConn();
    updateBadge();
  }

  // ---- sign in ----------------------------------------------------------------
  function deviceId() {
    var id = LD.store.get('ld_device', '');
    if (!id) { id = LD.uuid(); LD.store.set('ld_device', id); }
    return id;
  }

  function showLogin(info, message) {
    shellBuilt = false;
    LD.overlays.closeAll();
    var guess = LD.guessDevice();
    var hashPin = (location.hash.match(/[#&]pin=(\d{4,8})/) || [])[1] || '';
    var nameIn = h('input', { class: 'input', value: LD.store.get('ld_name', '') || guess.name, maxlength: 40, autocomplete: 'off', 'aria-label': 'Name of this device' });
    var pinIn = h('input', {
      class: 'input pin-input', type: 'password', inputmode: 'numeric', autocomplete: 'off', maxlength: 8, placeholder: '••••••', value: hashPin,
      'aria-label': 'PIN', pattern: '[0-9]*'
    });
    var err = h('div', { class: 'field-error', role: 'alert' }, message || '');
    var btn = h('button', { class: 'btn primary big', type: 'submit' }, 'Join', LD.icon('chevron-right', 18));
    var needPin = !!(info && info.pinRequired);
    var form = h('form', { class: 'login-form', onSubmit: function (e) { e.preventDefault(); submit(); } },
      h('label', { class: 'field-label' }, 'Name this device'), nameIn,
      needPin ? h('label', { class: 'field-label' }, 'PIN shown on the host phone') : null,
      needPin ? pinIn : null,
      err, btn);
    var card = h('div', { class: 'login-card' },
      h('div', { class: 'login-art' }, h('span', { class: 'ring r1' }), h('span', { class: 'ring r2' }), h('span', { class: 'ring r3' }), LD.logo(54)),
      h('h2', {}, 'Join ' + ((info && info.hostName) || 'LocalDrop')),
      h('p', { class: 'login-sub' }, needPin ? 'Enter the PIN to share files and messages with this device.' : 'Share files and messages with this device.'),
      form);
    LD.clear(rootEl).appendChild(h('div', { class: 'login' }, card));
    setTimeout(function () { (needPin && !hashPin ? pinIn : nameIn).focus(); }, 150);

    var busy = false;
    function submit() {
      if (busy) return;
      var name = nameIn.value.trim() || guess.name;
      if (needPin && !pinIn.value.trim()) { err.textContent = 'Enter the PIN.'; pinIn.focus(); return; }
      busy = true;
      btn.disabled = true;
      err.textContent = '';
      LD.store.set('ld_name', name);
      LD.api.post('/api/login', { deviceId: deviceId(), name: name, kind: guess.kind, pin: pinIn.value.trim() }, { quiet: true })
        .then(function () {
          if (hashPin) history.replaceState(null, '', location.pathname + location.search);
          boot();
        }, function (e) {
          busy = false;
          btn.disabled = false;
          err.textContent = e.message;
          if (e.status === 401) { pinIn.value = ''; pinIn.focus(); card.classList.remove('shake'); void card.offsetWidth; card.classList.add('shake'); }
        });
    }
    if (hashPin && needPin) submit();
  }

  function showMessage(icon, title, text, actionLabel, action) {
    shellBuilt = false;
    LD.overlays.closeAll();
    LD.clear(rootEl).appendChild(h('div', { class: 'login' }, h('div', { class: 'login-card' },
      LD.empty(icon, title, text, actionLabel ? h('button', { class: 'btn primary', onClick: action }, actionLabel) : null))));
  }

  // ---- boot ---------------------------------------------------------------------
  function boot() {
    if (booting) return;
    booting = true;
    LD.api.get('/api/info', { quiet: true }).then(function (info) {
      if (!info.authed && !info.host) {
        booting = false;
        showLogin(info);
        return null;
      }
      if (!info.authed) {
        // The host phone signs itself in.
        return LD.api.post('/api/login', { deviceId: 'host', name: 'Host' }, { quiet: true }).then(function () {
          booting = false;
          return bootDone();
        });
      }
      return bootDone();

      function bootDone() {
        return LD.api.get('/api/info', { quiet: true }).then(function (i) {
          booting = false;
          start(i);
        });
      }
    }).catch(function (e) {
      booting = false;
      showMessage('wifi', "Can't reach LocalDrop", e.message || 'Check that you are on the same Wi-Fi as the host.', 'Try again', function () { boot(); });
    });
  }

  function start(info) {
    S.info = info;
    S.you = info.you;
    S.perms = info.perms || S.perms;
    S.isHost = !!info.host;
    S.path = '';
    document.body.classList.toggle('is-host', S.isHost);
    document.body.classList.toggle('is-guest', !S.isHost);
    document.body.classList.toggle('no-upload', !S.perms.upload);
    buildShell();
    LD.connectEvents();
    LD.loadMessages().catch(function () { /* shown when the Drop tab opens */ });
    if (!location.hash || location.hash === '#') LD.go(S.isHost ? 'nearby' : 'files', '', true);
    route();
    if (S.isHost && !LD.store.get('ld_seen_invite', '')) {
      LD.store.set('ld_seen_invite', '1');
      setTimeout(function () { LD.openInvite(); }, 700);
    }
  }

  var recheck = LD.debounce(function () { if (shellBuilt) { shellBuilt = false; boot(); } }, 200);
  LD.on('unauthorized', recheck);
  LD.on('kicked', function () {
    showMessage('lock', 'Disconnected', 'The host has disconnected this device or changed the PIN.', 'Join again', function () { boot(); });
  });

  // ---- go -----------------------------------------------------------------------
  LD.theme.apply();
  window.addEventListener('load', function () { document.documentElement.classList.add('ready'); });
  boot();
})();
