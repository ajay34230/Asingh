/* LocalDrop: the invite sheet (address, QR code, PIN, hotspot) that lets other devices join. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  /** A QR code inside a framed card with animated corners. */
  LD.qrBlock = function (text, px) {
    var holder = h('div', { class: 'qr-frame' }, h('i', { class: 'c tl' }), h('i', { class: 'c tr' }), h('i', { class: 'c bl' }), h('i', { class: 'c br' }));
    try {
      holder.appendChild(LD.qrCanvas(text, px || 232));
    } catch (e) {
      holder.appendChild(h('div', { class: 'qr-fail' }, 'This address is too long for a QR code.'));
    }
    return holder;
  };

  function wifiEscape(s) { return String(s).replace(/([\\;,:"])/g, '\\$1'); }

  LD.nativeShare = function (text, title) {
    if (LD.isHostApp && window.LDHost.share) {
      try { window.LDHost.share(text); return Promise.resolve(); } catch (e) { /* try the web share sheet */ }
    }
    if (navigator.share) return navigator.share({ title: title || 'LocalDrop', text: text }).catch(function () { /* cancelled */ });
    return LD.copy(text).then(function () { LD.toast('Copied to the clipboard', 'ok'); }, function () { LD.toast("Couldn't copy. Select the text instead.", 'error'); });
  };

  LD.copyWithToast = function (text, what) {
    LD.copy(text).then(function () { LD.toast((what || 'Copied') + ' to the clipboard', 'ok'); },
      function () { LD.toast("Couldn't copy. Select the text instead.", 'error'); });
  };

  function hostInfo() {
    if (!LD.isHostApp) return null;
    try { return JSON.parse(window.LDHost.info()); } catch (e) { return null; }
  }

  /** Connection help: how to join across routers, plus a live link test (delay and speed). */
  LD.openHelp = function () {
    var result = h('div', { class: 'speed-result' });
    var btn = h('button', { class: 'btn primary wide', onClick: run }, LD.icon('wifi', 18), 'Test the connection');
    var tips = [
      ['Same network, even with several routers', 'Devices can join from any router or Wi-Fi extender, as long as they are on the same home or office network. Routers joined by cable, or set to access point mode, count as one network. If a second router makes its own separate network, use the address that belongs to the host phone\u2019s network.'],
      ['Turn off client isolation', 'If devices can\u2019t see each other, open the router settings and switch off "AP isolation" or "client isolation". Guest Wi-Fi networks usually have it on.'],
      ['Type the address, not a name', 'Use the numbers shown on the host phone, like 192.168.1.20:8080. Names such as "localdrop" only work inside some networks.'],
      ['Use the phone\u2019s own hotspot', 'Nothing else working? Start the LocalDrop hotspot on the host and join that Wi-Fi from the other device. It needs no router at all.'],
      ['VPNs and firewalls', 'Turn off any VPN on both devices. Some office networks block device-to-device traffic.']
    ];
    var body = h('div', { class: 'help' },
      h('div', { class: 'help-where' }, LD.icon('info', 18),
        h('span', {}, S.isHost ? 'This phone is reachable at the addresses in Invite devices.' : 'You are connected to ' + location.host)),
      btn, result,
      h('div', { class: 'help-tips' }, tips.map(function (t) {
        return h('details', {}, h('summary', {}, t[0]), h('p', {}, t[1]));
      })));
    LD.sheet({ title: 'Connection help', body: body });

    function run() {
      btn.disabled = true;
      LD.clear(result).appendChild(h('p', { class: 'field-note' }, 'Measuring\u2026'));
      var times = [];
      var chain = Promise.resolve();
      for (var i = 0; i < 5; i++) {
        chain = chain.then(function () {
          var t0 = performance.now();
          return fetch('/api/ping', { cache: 'no-store' }).then(function (r) { return r.json(); }).then(function () { times.push(performance.now() - t0); });
        });
      }
      chain.then(function () {
        var t1 = performance.now();
        return fetch('/api/speed?mb=8', { cache: 'no-store', credentials: 'same-origin', headers: { 'X-Requested-With': 'LocalDrop' } }).then(function (r) {
          if (!r.ok) throw new Error('The speed test needs you to be signed in.');
          return r.arrayBuffer();
        }).then(function (buf) { return { ms: performance.now() - t1, bytes: buf.byteLength }; });
      }).then(function (sp) {
        var avg = times.reduce(function (a, b) { return a + b; }, 0) / times.length;
        var mbps = sp.bytes * 8 / 1e6 / (sp.ms / 1000);
        var grade = mbps >= 100 ? 'Excellent' : mbps >= 30 ? 'Good' : mbps >= 8 ? 'Fine for most files' : 'Slow. Move closer to the router';
        LD.clear(result).appendChild(h('div', { class: 'speed-grid' },
          h('div', {}, h('b', {}, Math.round(avg) + ' ms'), h('span', {}, 'Delay')),
          h('div', {}, h('b', {}, (mbps >= 10 ? mbps.toFixed(0) : mbps.toFixed(1)) + ' Mbit/s'), h('span', {}, 'Speed')),
          h('div', {}, h('b', {}, grade), h('span', {}, 'Verdict'))));
        btn.disabled = false;
      }).catch(function (e) {
        LD.clear(result).appendChild(h('p', { class: 'field-error' }, e.message || 'The test failed.'));
        btn.disabled = false;
      });
    }
  };

  LD.openInvite = function () {
    var body = h('div', { class: 'invite' });
    var state = { addrs: null, sel: 0, withPin: LD.store.get('ld_qr_pin', '1') === '1', pin: null, pinOn: false };
    var sheet = LD.sheet({ title: S.isHost ? 'Invite devices' : 'Invite someone', body: body, wide: true, onClose: function () { off(); offHost(); } });
    var off = LD.on('devices', function () { /* keeps nothing; the QR does not depend on devices */ });
    var offHost = LD.on('host-change', function () { load(); });

    function load() {
      var jobs = [];
      if (S.isHost) {
        jobs.push(LD.api.get('/api/admin/network').then(function (a) { state.addrs = a; }, function () { state.addrs = []; }));
        jobs.push(LD.api.get('/api/admin/settings').then(function (s) { state.pin = s.pin; state.pinOn = s.pinEnabled; }, function () { /* PIN unknown */ }));
      } else {
        state.addrs = [{ label: 'This network', kind: 'wifi', url: location.origin, ip: location.hostname }];
      }
      Promise.all(jobs).then(render);
    }

    function render() {
      var scroll = sheet.body.scrollTop;
      LD.clear(body);
      var addrs = state.addrs || [];
      if (state.sel >= addrs.length) state.sel = 0;
      var hs = S.isHost ? hostInfo() : null;

      if (!addrs.length) {
        body.appendChild(LD.empty('wifi', 'Not on a network yet',
          'Connect this phone to Wi-Fi, or turn on a hotspot so other devices can join it.'));
      } else {
        var cur = addrs[state.sel];
        var withPin = S.isHost && state.pinOn && state.pin && state.withPin;
        var link = cur.url + (withPin ? '/#pin=' + state.pin : '');
        body.appendChild(h('p', { class: 'invite-lead' }, 'Scan this with the camera on another device, or type the address into any browser.'));
        if (addrs.length > 1) {
          body.appendChild(LD.segmented(addrs.map(function (a, i) { return { value: i, label: a.label, icon: a.kind === 'hotspot' ? 'hotspot' : 'wifi' }; }),
            state.sel, function (v) { state.sel = v; render(); }));
        }
        body.appendChild(h('div', { class: 'invite-qr' }, LD.qrBlock(link, 232)));
        body.appendChild(h('button', { class: 'address', onClick: function () { LD.copyWithToast(cur.url, 'Address copied'); }, 'aria-label': 'Copy address ' + cur.url },
          h('span', { class: 'address-text' }, cur.url.replace(/^http:\/\//, '')),
          LD.icon('copy', 18)));
        if (S.isHost && state.pinOn && state.pin) {
          body.appendChild(h('div', { class: 'pin-row' },
            h('div', { class: 'pin-box' }, h('span', { class: 'pin-label' }, 'PIN'), h('span', { class: 'pin-digits' }, state.pin)),
            h('label', { class: 'check-row' }, LD.toggle(state.withPin, function (on) { state.withPin = on; LD.store.set('ld_qr_pin', on ? '1' : '0'); render(); }, 'Put the PIN in the QR code'),
              h('span', {}, 'Skip the PIN when scanning'))));
        } else if (S.isHost) {
          body.appendChild(h('p', { class: 'invite-note' }, LD.icon('alert', 16), 'No PIN is set. Anyone on this network can open your files. Turn on a PIN in Settings.'));
        }
        body.appendChild(h('div', { class: 'btn-row' },
          h('button', { class: 'btn', onClick: function () { LD.copyWithToast(link, 'Link copied'); } }, LD.icon('copy', 18), 'Copy link'),
          h('button', { class: 'btn primary', onClick: function () { LD.nativeShare(link, 'Join me on LocalDrop'); } }, LD.icon('share', 18), 'Share')));
      }

      body.appendChild(h('button', { class: 'help-link', onClick: function () { LD.openHelp(); } }, LD.icon('info', 16), 'Can\u2019t connect, or using several routers? Get help'));
      if (hs && hs.hotspot) body.appendChild(hotspotCard(hs.hotspot));
      else if (S.isHost && LD.isHostApp) body.appendChild(h('p', { class: 'invite-note' }, 'Tip: turn on your phone hotspot and LocalDrop will show it here automatically.'));
      if (S.isHost && !LD.isHostApp && !addrs.length) body.appendChild(h('p', { class: 'invite-note' }, 'Connect this computer to a network to get an address.'));
      sheet.body.scrollTop = scroll;
    }

    function hotspotCard(hot) {
      var card = h('section', { class: 'hot-card' + (hot.running ? ' on' : '') });
      card.appendChild(h('div', { class: 'hot-head' },
        h('span', { class: 'hot-ic' }, LD.icon('hotspot', 22)),
        h('div', { class: 'hot-title' }, h('strong', {}, 'LocalDrop hotspot'),
          h('span', {}, hot.running ? 'On. Others can join this Wi-Fi.' : hot.starting ? 'Starting…' : 'No router needed. Make a Wi-Fi network from this phone.')),
        hot.running
          ? h('button', { class: 'btn small', onClick: function () { window.LDHost.stopHotspot(); setTimeout(function () { render(); }, 400); } }, 'Stop')
          : h('button', { class: 'btn small primary', disabled: !!hot.starting, onClick: function () { window.LDHost.startHotspot(); } }, 'Start')));
      if (hot.error && !hot.running) card.appendChild(h('p', { class: 'field-error' }, String(hot.error)));
      if (hot.running && hot.ssid) {
        var wifi = 'WIFI:T:WPA;S:' + wifiEscape(hot.ssid) + ';P:' + wifiEscape(hot.password || '') + ';;';
        card.appendChild(h('div', { class: 'hot-body' },
          h('div', { class: 'hot-qr' }, LD.qrBlock(wifi, 164)),
          h('div', { class: 'hot-creds' },
            h('span', { class: 'cred-label' }, '1. Join this Wi-Fi'),
            h('button', { class: 'cred', onClick: function () { LD.copyWithToast(hot.ssid, 'Network name copied'); } }, h('small', {}, 'Name'), h('b', {}, hot.ssid)),
            h('button', { class: 'cred', onClick: function () { LD.copyWithToast(hot.password, 'Password copied'); } }, h('small', {}, 'Password'), h('b', {}, hot.password || '')),
            h('span', { class: 'cred-label' }, '2. Then scan the first code or open the address'))));
      }
      return card;
    }

    load();
    return sheet;
  };
})();
