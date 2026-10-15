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
