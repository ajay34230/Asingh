/* LocalDrop: the Nearby screen. A live radar of connected devices, the invite card and recent activity. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  var el = {};
  var hero = { addrs: null, pin: null, pinOn: false };

  var ACT = {
    upload: ['upload', 'ok'], download: ['download', 'info'], mkdir: ['folder-plus', 'ok'], rename: ['edit', 'info'], move: ['move', 'info'],
    copy: ['copy', 'info'], delete: ['trash', 'warn'], restore: ['undo', 'ok'], share: ['link', 'info'], edit: ['edit', 'info'],
    join: ['wifi', 'ok'], leave: ['power', 'muted']
  };

  function hash(s) {
    var x = 2166136261;
    for (var i = 0; i < s.length; i++) { x ^= s.charCodeAt(i); x = Math.imul(x, 16777619); }
    return x >>> 0;
  }

  function others() { return S.devices.filter(function (d) { return !S.you || d.id !== S.you.id; }); }

  // ---- radar --------------------------------------------------------------------------------------
  function renderRadar() {
    var online = others().filter(function (d) { return d.online; }).sort(function (a, b) { return hash(a.id) - hash(b.id); });
    var me = S.devices.filter(function (d) { return S.you && d.id === S.you.id; })[0] || { name: (S.you && S.you.name) || 'You', kind: (S.you && S.you.kind) || 'phone' };
    var existing = {};
    LD.$$('.node', el.stage).forEach(function (n) { existing[n.dataset.id] = n; });
    var keep = {};
    online.forEach(function (d, i) {
      var n = online.length;
      var ring = n > 5 ? (i % 2) : 0;
      var ang = (i / n) * Math.PI * 2 - Math.PI / 2 + (ring ? Math.PI / n : 0) + ((hash(d.id) % 100) / 100 - 0.5) * 0.25;
      var r = ring ? 41 : (n > 1 ? 33 : 30);
      var x = 50 + Math.cos(ang) * r, y = 50 + Math.sin(ang) * r;
      var node = existing[d.id];
      if (!node) {
        node = h('button', { class: 'node', dataset: { id: d.id }, onClick: function () { openDevice(d.id); } },
          h('span', { class: 'node-badge' }),
          h('span', { class: 'node-name' }));
        node.style.left = '50%';
        node.style.top = '50%';
        el.stage.appendChild(node);
        requestAnimationFrame(function () { requestAnimationFrame(function () { node.classList.add('in'); node.style.left = x + '%'; node.style.top = y + '%'; }); });
      } else {
        node.style.left = x + '%';
        node.style.top = y + '%';
      }
      keep[d.id] = true;
      var badge = node.querySelector('.node-badge');
      LD.clear(badge).appendChild(LD.icon(LD.deviceIcon(d.kind), 22));
      node.querySelector('.node-name').textContent = d.name;
      node.setAttribute('aria-label', d.name + ', online. Tap for options.');
    });
    Object.keys(existing).forEach(function (id) {
      if (keep[id]) return;
      var n = existing[id];
      n.classList.remove('in');
      n.style.left = '50%';
      n.style.top = '50%';
      setTimeout(function () { if (n.parentNode) n.parentNode.removeChild(n); }, 450);
    });
    LD.clear(el.me).appendChild(LD.icon(LD.deviceIcon(me.kind), 26));
    el.meName.textContent = (S.isHost ? me.name || 'This phone' : me.name) + ' (you)';
    el.stage.classList.toggle('lonely', !online.length);
    el.callBtn.hidden = !online.length;
    el.caption.textContent = online.length ? online.length + (online.length === 1 ? ' device nearby' : ' devices nearby') :
      (S.isHost ? 'Waiting for devices to join' : 'Only you are here for now');
    el.sub.textContent = online.length ? 'Tap a device to send it something.' : (S.isHost ? 'Scan the QR code on another device, or open the address in its browser.' : 'Ask others to scan your QR code to join.');
  }

  // ---- device list ----------------------------------------------------------------------------------
  // ---- other LocalDrop phones on this network (found automatically by the Android app) -----------------
  var seenPeers = {};
  function loadPeers() {
    if (!LD.isHostApp || !window.LDHost || !window.LDHost.nearby || !el.peersWrap) return;
    var list = [];
    try { list = JSON.parse(window.LDHost.nearby()); } catch (e) { list = []; }
    Promise.all(list.map(function (p) {
      var ctl = new AbortController();
      var t = setTimeout(function () { ctl.abort(); }, 2500);
      return fetch(p.url + 'api/ping', { mode: 'no-cors', cache: 'no-store', signal: ctl.signal })
        .then(function () { clearTimeout(t); return p; }, function () { clearTimeout(t); return null; });
    })).then(function (ok) {
      var live = ok.filter(Boolean);
      LD.clear(el.peers);
      el.peersWrap.hidden = !live.length;
      live.forEach(function (p) {
        if (!seenPeers[p.url]) { seenPeers[p.url] = true; LD.toast('Found ' + p.name + ' nearby', 'ok'); }
        el.peers.appendChild(h('div', { class: 'dev-row online' },
          h('span', { class: 'dev-main' }, LD.deviceBadge('phone', 42),
            h('span', { class: 'dev-text' }, h('span', { class: 'dev-name' }, p.name), h('span', { class: 'dev-meta' }, 'LocalDrop \u00b7 ' + p.host + ':' + p.port))),
          h('button', { class: 'btn small primary', onClick: function () { window.LDHost.join(p.url); } }, LD.icon('wifi', 16), 'Connect')));
      });
    });
  }
  window.onLDNearby = LD.debounce(loadPeers, 400);

  function openCallPicker() {
    var list = others().filter(function (d) { return d.online; });
    var sheet;
    var body = list.length ? h('div', { class: 'call-add-list' }, list.map(function (d) {
      return h('div', { class: 'call-add-row' }, LD.deviceBadge(d.kind, 40), h('span', {}, d.name),
        h('button', { class: 'icon-btn call-act', 'aria-label': 'Voice call ' + d.name, onClick: function () { sheet.close(); LD.calls.start(d.id, false); } }, LD.icon('phone-call', 20)),
        h('button', { class: 'icon-btn call-act', 'aria-label': 'Video call ' + d.name, onClick: function () { sheet.close(); LD.calls.start(d.id, true); } }, LD.icon('video', 20)));
    })) : LD.empty('radar', 'No one to call yet', 'Calls work between devices that are connected. Invite one with the QR code.');
    sheet = LD.sheet({ title: 'Call someone', body: body });
  }

  function renderDevices() {
    LD.clear(el.devices);
    var all = S.devices;
    el.devicesWrap.hidden = false;
    if (!others().length) {
      el.devices.appendChild(h('div', { class: 'call-hint' }, LD.icon('phone-call', 22),
        h('div', {}, h('b', {}, 'Voice and video calls'), h('span', {}, 'Calls appear here as soon as another device joins. Invite one with the QR code.')),
        h('button', { class: 'btn small primary', onClick: function () { LD.openInvite(); } }, 'Invite')));
      return;
    }
    all.forEach(function (d, i) {
      var self = S.you && d.id === S.you.id;
      var canCall = d.online && !self && LD.calls;
      el.devices.appendChild(h('div', { class: 'dev-row' + (d.online ? ' online' : ''), style: { '--i': Math.min(i, 10) } },
        h('button', { class: 'dev-main', onClick: function () { openDevice(d.id); } },
          LD.deviceBadge(d.kind, 42),
          h('span', { class: 'dev-text' },
            h('span', { class: 'dev-name' }, d.name, self ? h('em', {}, 'You') : null, d.host ? h('em', { class: 'host' }, 'Host') : null),
            h('span', { class: 'dev-meta' }, d.online ? 'Online' + (d.ip ? ' \u00b7 ' + d.ip : '') : 'Last seen ' + LD.fmtAgo(d.lastSeen)))),
        canCall ? h('button', { class: 'icon-btn call-act', 'aria-label': 'Voice call ' + d.name, onClick: function () { LD.calls.start(d.id, false); } }, LD.icon('phone-call', 20)) : null,
        canCall ? h('button', { class: 'icon-btn call-act', 'aria-label': 'Video call ' + d.name, onClick: function () { LD.calls.start(d.id, true); } }, LD.icon('video', 20)) : null,
        h('span', { class: 'dot' + (d.online ? ' live' : '') })));
    });
  }

  function openDevice(id) {
    var d = S.devices.filter(function (x) { return x.id === id; })[0];
    if (!d) return;
    var self = S.you && d.id === S.you.id;
    var fileIn = h('input', { type: 'file', multiple: true, hidden: true, onChange: function () {
      var fs = fileIn.files;
      sheet.close();
      LD.go('drop');
      LD.screens.drop.sendTo(d.id, fs);
    } });
    var acts = [];
    if (!self) {
      acts.push(h('button', { class: 'btn primary', onClick: function () { sheet.close(); LD.screens.drop.setTarget(d.id); LD.go('drop'); } }, LD.icon('message', 18), 'Message'));
      if (d.online && LD.calls) {
        acts.push(h('button', { class: 'btn', onClick: function () { sheet.close(); LD.calls.start(d.id, false); } }, LD.icon('phone-call', 18), 'Voice call'));
        acts.push(h('button', { class: 'btn', onClick: function () { sheet.close(); LD.calls.start(d.id, true); } }, LD.icon('video', 18), 'Video call'));
      }
      acts.push(h('button', { class: 'btn', disabled: !S.perms.upload, onClick: function () { fileIn.click(); } }, LD.icon('send', 18), 'Send files'));
    } else {
      acts.push(h('button', { class: 'btn', onClick: function () { sheet.close(); renameSelf(); } }, LD.icon('edit', 18), 'Rename'));
    }
    var body = h('div', { class: 'device-sheet' },
      h('div', { class: 'device-hero' }, LD.deviceBadge(d.kind, 64), h('h3', {}, d.name),
        h('span', { class: 'dev-meta' }, (d.online ? 'Online' : 'Offline') + (d.host ? ' · host' : '') + (self ? ' · this device' : ''))),
      h('dl', { class: 'details' },
        d.ip ? [h('dt', {}, 'Address'), h('dd', {}, d.ip)] : null,
        [h('dt', {}, 'Last seen'), h('dd', {}, d.online ? 'Now' : LD.fmtAgo(d.lastSeen))]),
      h('div', { class: 'btn-row' }, acts),
      fileIn,
      S.isHost && !self && !d.host ? h('button', { class: 'btn danger wide', onClick: function () {
        LD.confirm({ title: 'Disconnect ' + d.name + '?', body: 'It will need the PIN to join again.', confirm: 'Disconnect', danger: true }).then(function (ok) {
          if (!ok) return;
          sheet.close();
          LD.api.post('/api/devices/kick', { id: d.id }).then(function () { LD.toast(d.name + ' was disconnected', 'ok'); }, LD.fail);
        });
      } }, LD.icon('power', 18), 'Disconnect this device') : null);
    var sheet = LD.sheet({ title: 'Device', body: body });
  }

  function renameSelf() {
    LD.form({ title: 'Name this device', label: 'Name', value: (S.you && S.you.name) || '', confirm: 'Save', submit: function (name) {
      return LD.api.post('/api/device', { name: name.trim() });
    } }).then(function (r) {
      if (r) { S.you.name = r.name || S.you.name; LD.store.set('ld_name', S.you.name); renderRadar(); }
    });
  }
  LD.renameSelf = renameSelf;

  // ---- activity ---------------------------------------------------------------------------------------------
  function renderActivity() {
    LD.clear(el.activity);
    var list = S.activity.slice(-40).reverse();
    if (!list.length) { el.activityWrap.hidden = true; return; }
    el.activityWrap.hidden = false;
    list.forEach(function (a) {
      var spec = ACT[a.type] || ['info', 'info'];
      var clickable = a.path && a.type !== 'delete';
      var row = h(clickable ? 'button' : 'div', { class: 'act-row ' + spec[1], onClick: clickable ? function () {
        LD.go('files', /\./.test(LD.baseName(a.path)) || a.type === 'upload' || a.type === 'download' || a.type === 'edit' ? LD.parentPath(a.path) : a.path);
      } : null },
        h('span', { class: 'act-ic' }, LD.icon(spec[0], 16)),
        h('span', { class: 'act-text' }, h('b', {}, a.who), ' ' + a.text),
        h('time', { class: 'act-time' }, LD.fmtAgo(a.t)));
      el.activity.appendChild(row);
    });
  }

  // ---- host invite card -----------------------------------------------------------------------------------
  function loadHero() {
    if (!S.isHost) return;
    Promise.all([
      LD.api.get('/api/admin/network').then(function (a) { hero.addrs = a; }, function () { hero.addrs = []; }),
      LD.api.get('/api/admin/settings').then(function (s) { hero.pin = s.pin; hero.pinOn = s.pinEnabled; }, function () { /* unknown */ })
    ]).then(renderHero);
  }

  function renderHero() {
    if (!S.isHost) { el.hero.hidden = true; return; }
    el.hero.hidden = false;
    LD.clear(el.hero);
    var a = hero.addrs && hero.addrs[0];
    if (!a) {
      el.hero.appendChild(h('div', { class: 'hero-empty' }, LD.icon('wifi', 28),
        h('div', {}, h('b', {}, 'Not connected to a network'), h('span', {}, 'Join Wi-Fi or start a hotspot so other devices can reach this phone.')),
        h('button', { class: 'btn primary', onClick: function () { LD.openInvite(); } }, 'Set up')));
      return;
    }
    var link = a.url + (hero.pinOn && hero.pin && LD.store.get('ld_qr_pin', '1') === '1' ? '/#pin=' + hero.pin : '');
    el.hero.appendChild(h('button', { class: 'hero-qr', 'aria-label': 'Show a larger QR code', onClick: function () { LD.openInvite(); } }, LD.qrBlock(link, 168)));
    el.hero.appendChild(h('div', { class: 'hero-text' },
      h('span', { class: 'hero-kicker' }, a.label || 'Network'),
      h('h2', {}, 'Scan or type to join'),
      h('button', { class: 'address', onClick: function () { LD.copyWithToast(a.url, 'Address copied'); } }, h('span', { class: 'address-text' }, a.url.replace(/^http:\/\//, '')), LD.icon('copy', 16)),
      hero.pinOn && hero.pin ? h('div', { class: 'hero-pin' }, LD.icon('key', 15), 'PIN ', h('b', {}, hero.pin)) : h('div', { class: 'hero-pin warn' }, LD.icon('alert', 15), 'No PIN set'),
      h('button', { class: 'btn small primary', onClick: function () { LD.openInvite(); } }, LD.icon('qr', 16), 'Bigger code and hotspot')));
  }

  function mount(root) {
    el.hero = h('section', { class: 'hero', hidden: true });
    el.me = h('span', { class: 'me-badge' });
    el.meName = h('span', { class: 'me-name' });
    el.stage = h('div', { class: 'stage' },
      h('i', { class: 'rr r1' }), h('i', { class: 'rr r2' }), h('i', { class: 'rr r3' }), h('i', { class: 'sweep' }),
      h('i', { class: 'pulse p1' }), h('i', { class: 'pulse p2' }),
      h('div', { class: 'me' }, el.me, el.meName));
    el.caption = h('b', { class: 'radar-caption' });
    el.sub = h('span', { class: 'radar-sub' });
    el.callBtn = h('button', { class: 'btn primary call-start', onClick: function () { openCallPicker(); } }, LD.icon('phone-call', 18), 'Call someone');
    el.devices = h('div', { class: 'dev-list' });
    el.devicesWrap = h('section', { class: 'block', hidden: true }, h('h3', { class: 'block-title' }, 'Devices'), el.devices);
    el.peers = h('div', { class: 'dev-list' });
    el.peersWrap = h('section', { class: 'block', hidden: true }, h('h3', { class: 'block-title' }, 'LocalDrop phones found nearby'),
      el.peers, h('p', { class: 'field-note' }, 'Tap Connect to join that phone. It opens in your browser; enter its PIN if it has one.'));
    el.activity = h('div', { class: 'act-list' });
    el.activityWrap = h('section', { class: 'block', hidden: true }, h('h3', { class: 'block-title' }, 'Recent activity'), el.activity);
    root.appendChild(el.hero);
    root.appendChild(h('section', { class: 'radar' }, el.stage, h('div', { class: 'radar-text' }, el.caption, el.sub),
      S.isHost ? null : h('button', { class: 'btn', onClick: function () { LD.openInvite(); } }, LD.icon('qr', 18), 'Invite someone'),
      el.callBtn));
    root.appendChild(el.peersWrap);
    root.appendChild(el.devicesWrap);
    root.appendChild(el.activityWrap);
    renderRadar();
    renderDevices();
    renderActivity();
    loadHero();
    LD.on('devices', function () { renderRadar(); renderDevices(); if (S.isHost) loadHero(); });
    LD.on('activity', renderActivity);
    LD.on('host-change', loadHero);
    LD.on('settings-changed', loadHero);
    setInterval(function () { if (S.tab === 'nearby') { renderDevices(); renderActivity(); } }, 30000);
  }

  LD.screens.nearby = { mount: mount, onShow: function () { renderRadar(); renderDevices(); renderActivity(); loadHero(); loadPeers(); } };
  setInterval(function () { if (S.tab === 'nearby') loadPeers(); }, 12000);
})();
