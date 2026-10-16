/* LocalDrop: the Settings screen. This device, appearance, and (on the host) sharing, security and permissions. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  var el = {};
  var cfg = null;
  var revealed = false;

  function hostInfo() {
    if (!LD.isHostApp) return null;
    try { return JSON.parse(window.LDHost.info()); } catch (e) { return null; }
  }

  function row(icon, title, sub, right, onClick, extra) {
    var inner = [
      h('span', { class: 'row-ic' }, LD.icon(icon, 20)),
      h('span', { class: 'row-text' }, h('b', {}, title), sub ? h('span', {}, sub) : null),
      right || (onClick ? LD.icon('chevron-right', 18) : null)
    ];
    var attrs = { class: 'srow' + (onClick ? ' tap' : '') + (extra ? ' ' + extra : '') };
    if (onClick) { attrs.onClick = onClick; return h('button', attrs, inner); }
    return h('div', attrs, inner);
  }
  function card(title, rows, note) {
    return h('section', { class: 'scard' }, title ? h('h3', { class: 'block-title' }, title) : null, h('div', { class: 'scard-body' }, rows), note ? h('p', { class: 'scard-note' }, note) : null);
  }
  function badge(text, kind) { return h('span', { class: 'pill ' + (kind || '') }, text); }

  function save(patch) {
    return LD.api.post('/api/admin/settings', patch).then(function (c) { cfg = c; render(); return c; }, function (e) { LD.fail(e); render(); throw e; });
  }

  function loadCfg() {
    if (!S.isHost) { render(); return; }
    LD.api.get('/api/admin/settings').then(function (c) { cfg = c; render(); }, function (e) { LD.fail(e); render(); });
  }

  function render() {
    var scroll = el.root.parentNode ? el.root.parentNode.scrollTop : 0;
    LD.clear(el.root);
    var me = S.devices.filter(function (d) { return S.you && d.id === S.you.id; })[0];
    var myName = (me && me.name) || (S.you && S.you.name) || 'This device';

    el.root.appendChild(h('h2', { class: 'page-title' }, 'Settings'));

    // This device
    el.root.appendChild(card('This device', [
      row('edit', 'Device name', myName, null, LD.renameSelf),
      row('moon', 'Appearance', null, LD.segmented([
        { value: 'auto', label: 'Auto' }, { value: 'light', label: 'Light' }, { value: 'dark', label: 'Dark' }
      ], LD.theme.mode(), function (v) { LD.theme.set(v); }), null, 'stack'),
      !S.isHost ? row('power', 'Leave this network', 'Sign this device out of LocalDrop', null, function () {
        LD.confirm({ title: 'Leave LocalDrop?', body: 'You can rejoin any time with the address and PIN.', confirm: 'Leave' }).then(function (ok) {
          if (ok) LD.api.post('/api/logout', {}, { quiet: true }).then(function () { location.hash = ''; location.reload(); });
        });
      }) : null
    ]));

    if (S.isHost && cfg) hostSections();

    // Links and trash
    el.root.appendChild(card('Files', [
      row('link', 'Share links', 'Links you have made', null, LD.manageLinks),
      row('trash', 'Trash', 'Restore deleted items within 30 days', null, LD.openTrash),
      row('apk', 'Apps to install', 'Get the LocalDrop app or others from the host phone', null, LD.openApps)
    ]));

    // About
    el.root.appendChild(card('About', [
      row('qr', 'Invite devices', 'Show the QR code and address', null, function () { LD.openInvite(); }),
      row('download', 'Get the app', 'Download the Android app (APK) or install the web app (PWA)', null, function () { LD.openGetApp(); }),
      row('wifi', 'Connection help and speed test', 'Works across routers on one network', null, LD.openHelp),
      row('info', 'LocalDrop', 'Version ' + ((S.info && S.info.version) || (cfg && cfg.version) || '1.0'), null, null),
      row('shield', 'Privacy', 'Everything stays on your own network. Nothing goes to the internet.', null, null)
    ]));
    if (el.root.parentNode) el.root.parentNode.scrollTop = scroll;
  }

  function hostSections() {
    var hi = hostInfo();

    // Shared folder
    var roots = cfg.roots.map(function (r) {
      var on = r.selected;
      return h('button', { class: 'radio-row' + (on ? ' on' : '') + (r.available ? '' : ' locked'), onClick: function () {
        if (!r.available) {
          if (LD.isHostApp) { LD.toast('Allow access to files first', 'info'); window.LDHost.requestStorage(); }
          return;
        }
        if (on) return;
        LD.api.post('/api/admin/root', { id: r.id }).then(function () { LD.toast('Now sharing ' + r.label, 'ok'); loadCfg(); LD.screens.files.reload(); }, LD.fail);
      } },
        h('span', { class: 'radio' }, h('i', {})),
        h('span', { class: 'row-text' }, h('b', {}, r.label), h('span', {}, r.available ? r.note : 'Needs permission to see all files')),
        r.available ? null : LD.icon('lock', 16));
    });
    var used = Math.max(0, cfg.storage.total - cfg.storage.free);
    el.root.appendChild(card('What you share', [
      h('div', { class: 'radio-list' }, roots),
      cfg.storage.total ? h('div', { class: 'storage in-card' },
        h('div', { class: 'progress thin' }, h('i', { style: { width: Math.min(100, used / cfg.storage.total * 100) + '%' } })),
        h('span', {}, LD.fmtSize(cfg.storage.free) + ' free of ' + LD.fmtSize(cfg.storage.total))) : null
    ], 'Connected devices can see everything inside the chosen folder.'));

    // Security
    var pinRows = [
      row('lock', 'Require a PIN', 'Turn off to let anyone on the network join with just a name', LD.toggle(cfg.pinEnabled, function (on) { save({ pinEnabled: on }); }, 'Require a PIN'))
    ];
    if (cfg.pinEnabled) {
      pinRows.push(row('key', 'PIN', null, h('span', { class: 'pin-inline' },
        h('b', { class: 'pin-digits' }, revealed ? cfg.pin : '•'.repeat(String(cfg.pin).length)),
        h('button', { class: 'icon-btn', 'aria-label': revealed ? 'Hide PIN' : 'Show PIN', onClick: function () { revealed = !revealed; render(); } }, LD.icon(revealed ? 'eye-off' : 'eye', 18)))));
      pinRows.push(row('edit', 'Choose a new PIN', '4 to 8 digits. Signs everyone out.', null, function () {
        LD.form({ title: 'New PIN', label: '4 to 8 digits', type: 'text', inputmode: 'numeric', maxlength: 8, confirm: 'Change PIN', submit: function (v) {
          if (!/^[0-9]{4,8}$/.test(v.trim())) throw new Error('A PIN is 4 to 8 digits.');
          return save({ pin: v.trim() });
        } }).then(function (r) { if (r) LD.toast('PIN changed. Everyone was signed out.', 'ok'); });
      }));
      pinRows.push(row('refresh', 'Make a random PIN', 'Signs everyone out', null, function () {
        LD.confirm({ title: 'Make a new PIN?', body: 'Every connected device will be signed out and need the new PIN.', confirm: 'New PIN' }).then(function (ok) {
          if (ok) LD.api.post('/api/admin/regen-pin', {}).then(function () { LD.toast('New PIN ready', 'ok'); revealed = true; loadCfg(); }, LD.fail);
        });
      }));
    }
    pinRows.push(row('users', 'LocalDrop phones join without a PIN', 'Phones with the LocalDrop app on this network can join by themselves. Turn off to make them type the PIN', LD.toggle(cfg.autoTrust !== false, function (on) { save({ autoTrust: on }); }, 'LocalDrop phones join without a PIN')));
    if (LD.isHostApp && window.LDHost && window.LDHost.autoConnect) {
      pinRows.push(row('wifi', 'Join nearby LocalDrop phones automatically', 'Phones with the app on the same network meet in one shared room. Turn off to stay on your own', LD.toggle(window.LDHost.autoConnect(), function (on) { window.LDHost.setAutoConnect(on); LD.emit('nearby'); }, 'Join nearby LocalDrop phones automatically')));
    }
    el.root.appendChild(card('Security', pinRows, cfg.pinEnabled ? null : 'Without a PIN, anyone on this network can open your files.'));

    // What guests may do
    el.root.appendChild(card('What others can do', [
      row('upload', 'Upload files', 'Other devices can add files', LD.toggle(cfg.guestUpload, function (on) { save({ guestUpload: on }); }, 'Guests can upload')),
      row('edit', 'Change files', 'Rename, move, copy, delete and edit', LD.toggle(cfg.guestModify, function (on) { save({ guestModify: on }); }, 'Guests can change files')),
      row('link', 'Share links', 'Let anyone with a link download without a PIN', LD.toggle(cfg.allowLinks, function (on) { save({ allowLinks: on }); }, 'Allow share links')),
      LD.isHostApp ? row('apk', 'Share other apps', 'Let devices download the installers of apps on this phone. LocalDrop itself is always shareable', LD.toggle(cfg.shareApps, function (on) { save({ shareApps: on }); }, 'Share other apps')) : null
    ], 'Downloading is always allowed for devices that have joined.'));

    // This phone (Android app)
    if (hi) {
      var hs = hi.hotspot || {};
      el.root.appendChild(card('This phone', [
        row('hotspot', 'LocalDrop hotspot', hs.running ? 'On: ' + (hs.ssid || '') : 'Make a Wi-Fi network from this phone',
          badge(hs.running ? 'On' : 'Off', hs.running ? 'ok' : ''), function () { LD.openInvite(); }),
        row('folder', 'Access to all files', hi.storageAccess ? 'Allowed' : 'Needed to share Downloads, Photos or the whole phone',
          hi.storageAccess ? badge('Allowed', 'ok') : h('span', { class: 'btn small primary' }, 'Allow'), hi.storageAccess ? null : function () { window.LDHost.requestStorage(); }),
        row('bell', 'Notifications', hi.notifications ? 'Shows who is connected' : 'Allow to see the status in your notification shade',
          hi.notifications ? badge('Allowed', 'ok') : h('span', { class: 'btn small primary' }, 'Allow'), hi.notifications ? null : function () { window.LDHost.requestNotifications(); }),
        row('battery', 'Keep running in the background', hi.batteryUnrestricted ? 'Battery limits are off for LocalDrop' : 'Stops Android from pausing sharing when the screen is off',
          hi.batteryUnrestricted ? badge('On', 'ok') : h('span', { class: 'btn small primary' }, 'Allow'), hi.batteryUnrestricted ? null : function () { window.LDHost.keepRunning(); })
      ]));
    }

    // Traffic
    el.root.appendChild(card('This session', [
      row('download', 'Received from other devices', LD.fmtSize(cfg.bytesUp || 0), null, null),
      row('upload', 'Sent to other devices', LD.fmtSize(cfg.bytesDown || 0), null, null)
    ]));

    if (LD.isHostApp) {
      el.root.appendChild(h('button', { class: 'btn danger wide stop-btn', onClick: function () {
        LD.confirm({ title: 'Stop sharing?', body: 'Connected devices will be disconnected and the server will stop.', confirm: 'Stop and close', danger: true }).then(function (ok) {
          if (ok) window.LDHost.quit();
        });
      } }, LD.icon('power', 18), 'Stop sharing and close'));
    }
  }

  function mount(root) {
    el.root = h('div', { class: 'settings' });
    root.appendChild(el.root);
    render();
    loadCfg();
    LD.on('host-change', function () { render(); });
    LD.on('settings-changed', function () { if (S.isHost) loadCfg(); });
    LD.on('devices', function () { if (S.tab === 'settings') render(); });
    document.addEventListener('visibilitychange', function () { if (!document.hidden && S.tab === 'settings') render(); });
  }

  LD.screens.settings = { mount: mount, onShow: function () { loadCfg(); } };
})();
