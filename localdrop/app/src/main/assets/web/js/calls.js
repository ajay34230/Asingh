/* LocalDrop: voice and video calls between devices on the same network (WebRTC; the host only passes the setup messages). */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  var call = null;       // the call in progress
  var incoming = null;   // a call that is ringing here
  var ringer = null;

  function secure() {
    return !!(window.isSecureContext && navigator.mediaDevices && navigator.mediaDevices.getUserMedia && window.RTCPeerConnection);
  }

  // ---- secure page hint -----------------------------------------------------------------------------
  LD.needSecure = function () {
    var port = S.info && S.info.tlsPort;
    var url = port ? 'https://' + location.hostname + ':' + port + '/#/nearby' : '';
    var body = h('div', { class: 'secure' },
      h('p', {}, 'Browsers only allow the microphone and camera on a secure page. LocalDrop has one ready.'),
      url ? h('ol', {},
        h('li', {}, 'Tap the button below.'),
        h('li', {}, 'Your browser will warn that the certificate isn’t trusted. That is expected: LocalDrop made it itself. Choose Advanced, then Continue.'),
        h('li', {}, 'Allow the microphone or camera when asked, then call again.')) :
        h('p', { class: 'field-error' }, 'Secure calling isn’t available on this host.'),
      url ? h('div', { class: 'btn-row' },
        h('button', { class: 'btn', onClick: function () { LD.copyWithToast(url, 'Secure address copied'); } }, LD.icon('copy', 18), 'Copy'),
        h('button', { class: 'btn primary', onClick: function () { location.href = url; } }, LD.icon('lock', 18), 'Open secure page')) : null);
    LD.sheet({ title: 'Calls need a secure page', body: body });
  };

  // ---- sounds -----------------------------------------------------------------------------------------
  var actx = null;
  function audioCtx() {
    try {
      actx = actx || new (window.AudioContext || window.webkitAudioContext)();
      if (actx.state === 'suspended') actx.resume();
    } catch (e) { actx = null; }
    return actx;
  }
  function beep(freq, at, len) {
    var c = audioCtx();
    if (!c) return;
    var o = c.createOscillator(), g = c.createGain();
    o.frequency.value = freq;
    o.connect(g); g.connect(c.destination);
    var t = c.currentTime + at;
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.18, t + 0.03);
    g.gain.linearRampToValueAtTime(0, t + len);
    o.start(t); o.stop(t + len + 0.05);
  }
  function startRing(callerSide) {
    stopRing();
    function once() {
      if (callerSide) { beep(440, 0, 0.9); }
      else { beep(880, 0, 0.18); beep(660, 0.22, 0.18); beep(880, 0.6, 0.18); beep(660, 0.82, 0.18); }
      if (!callerSide && navigator.vibrate) { try { navigator.vibrate([300, 150, 300]); } catch (e) { /* no vibration */ } }
    }
    once();
    ringer = setInterval(once, callerSide ? 3000 : 2200);
  }
  function stopRing() { if (ringer) { clearInterval(ringer); ringer = null; } }

  // ---- signalling ---------------------------------------------------------------------------------------
  function send(to, type, callId, extra) {
    var body = { to: to, type: type, callId: callId };
    if (extra) for (var k in extra) body[k] = extra[k];
    return LD.api.post('/api/signal', body);
  }

  function newId() { return Math.random().toString(36).slice(2, 10) + Date.now().toString(36); }

  function media(video) {
    return navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      video: video ? { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 720 } } : false
    }).catch(function (e) {
      var msg = e && e.name === 'NotAllowedError' ? 'Allow the microphone' + (video ? ' and camera' : '') + ' to make calls.'
        : e && e.name === 'NotFoundError' ? 'No microphone' + (video ? ' or camera' : '') + ' found on this device.'
        : 'Couldn’t start the ' + (video ? 'camera' : 'microphone') + '.';
      throw new Error(msg);
    });
  }

  function fmtTime(ms) {
    var s = Math.round(ms / 1000), m = Math.floor(s / 60);
    return (m < 10 ? '0' : '') + m + ':' + ('0' + (s % 60)).slice(-2);
  }
  function info(id, fallback) {
    var d = S.devices.filter(function (x) { return x.id === id; })[0];
    return d ? { id: d.id, name: d.name, kind: d.kind } : (fallback || { id: id, name: 'Someone', kind: 'phone' });
  }
  function quiet(p) { return p.catch(function () { /* peer gone or ignored */ }); }

  // ---- one connection per person (a call with several people is a mesh of these) -------------------------
  function addPeer(c, who) {
    var P = { id: who.id, name: who.name, kind: who.kind, state: 'ringing', queued: [], held: false };
    P.media = c.video ? h('video', { class: 'call-remote', autoplay: true, playsinline: true }) : h('audio', { autoplay: true });
    P.tag = h('span', { class: 'call-tag' }, 'Ringing…');
    P.avatar = h('div', { class: 'call-avatar' }, h('span', { class: 'ring r1' }), h('span', { class: 'ring r2' }), h('span', { class: 'ring r3' }), LD.deviceBadge(who.kind, 96));
    P.tile = h('div', { class: 'call-tile ringing', dataset: { id: who.id } }, P.media, P.avatar, h('span', { class: 'call-name' }, who.name), P.tag);
    c.peers[who.id] = P;
    c.order.push(who.id);
    c.grid.appendChild(P.tile);
    layout(c);
    return P;
  }

  function connectPeer(c, P) {
    var pc = new RTCPeerConnection({ iceServers: [] });
    P.pc = pc;
    c.local.getTracks().forEach(function (t) { pc.addTrack(t, c.local); });
    pc.onicecandidate = function (e) {
      if (e.candidate) quiet(send(P.id, 'ice', c.id, { data: e.candidate.toJSON ? e.candidate.toJSON() : e.candidate }));
    };
    pc.ontrack = function (e) {
      P.remote = e.streams[0] || P.remote || new MediaStream();
      if (!e.streams[0]) P.remote.addTrack(e.track);
      P.media.srcObject = P.remote;
      P.media.muted = !!c.held;
      var pr = P.media.play();
      if (pr && pr.catch) pr.catch(function () {
        document.addEventListener('click', function once() { P.media.play(); document.removeEventListener('click', once); });
      });
      if (c.video) P.tile.classList.add('has-remote');
    };
    pc.onconnectionstatechange = function () {
      if (call !== c || c.peers[P.id] !== P) return;
      var st = pc.connectionState;
      if (st === 'connected') { P.state = 'connected'; P.tile.classList.remove('ringing'); P.tag.textContent = ''; stopRingIfAny(c); setCallState(c, 'connected'); watchLevel(c, P); }
      else if (st === 'disconnected') P.tag.textContent = 'Reconnecting…';
      else if (st === 'failed') dropPeer(c, P, Object.keys(c.peers).length > 1 ? 'Lost connection to ' + P.name + '.' : 'The connection failed. Check that both devices can reach each other.');
    };
    return pc;
  }

  function addRemoteIce(P, cand) {
    if (P.pc.remoteDescription) P.pc.addIceCandidate(cand).catch(function () { /* stale candidate */ });
    else P.queued.push(cand);
  }
  function flushIce(P) {
    var q = P.queued; P.queued = [];
    q.forEach(function (x) { P.pc.addIceCandidate(x).catch(function () { /* stale candidate */ }); });
  }
  function stopRingIfAny(c) { if (c.state !== 'connected') stopRing(); }

  function members(c, except) {
    return c.order.filter(function (id) { return id !== except; }).map(function (id) { var p = c.peers[id]; return { id: p.id, name: p.name, kind: p.kind }; });
  }

  /** Offer a call (or a place in this call) to someone. */
  function invite(c, who, join) {
    var P = addPeer(c, who);
    var pc = connectPeer(c, P);
    if (join) P.tag.textContent = 'Joining…';
    return pc.createOffer().then(function (o) { return pc.setLocalDescription(o); }).then(function () {
      var data = { type: pc.localDescription.type, sdp: pc.localDescription.sdp, members: join ? [] : members(c, who.id), join: !!join };
      return send(who.id, 'invite', c.id, { video: c.video, data: data });
    }).then(function () {
      if (call !== c || c.peers[who.id] !== P) return;
      if (!join) {
        if (c.state !== 'connected') { setCallState(c, 'ringing'); startRing(true); }
        P.timeout = setTimeout(function () {
          if (call === c && c.peers[who.id] === P && P.state === 'ringing') { quiet(send(who.id, 'end', c.id)); dropPeer(c, P, who.name + ' didn’t answer.'); }
        }, 45000);
      }
    }).catch(function (e) { if (call === c && c.peers[who.id] === P) dropPeer(c, P, (e && e.message) || 'The call couldn’t start.'); });
  }

  // ---- placing a call ---------------------------------------------------------------------------------------
  LD.calls = {
    active: function () { return !!call; },
    start: function (deviceId, video) {
      if (call || incoming) { LD.toast('You are already in a call.', 'error'); return; }
      if (!secure()) { LD.needSecure(); return; }
      var d = S.devices.filter(function (x) { return x.id === deviceId; })[0];
      if (!d || !d.online) { LD.toast('That device is offline.', 'error'); return; }
      audioCtx();
      var c = { id: newId(), video: !!video, role: 'caller', state: 'starting', started: 0, peers: {}, order: [] };
      call = c;
      openUI(c);
      media(video).then(function (stream) {
        if (call !== c) { stream.getTracks().forEach(function (t) { t.stop(); }); return; }
        c.local = stream;
        attachLocal(c);
        return invite(c, { id: d.id, name: d.name, kind: d.kind }, false);
      }).catch(function (e) { if (call === c) finish(c, e.message || 'The call couldn’t start.', true, true); });
    },
    add: function (deviceId) {
      var c = call;
      if (!c || c.state !== 'connected') return;
      var d = info(deviceId);
      if (c.peers[d.id]) return;
      invite(c, d, false);
    }
  };

  // ---- receiving -----------------------------------------------------------------------------------------------
  LD.on('signal', function (m) {
    var from = m.from || {};
    if (m.type === 'invite') {
      if (call && call.id === m.callId && call.local) { joinFrom(call, from, m); return; }
      if (call || incoming) { quiet(send(from.id, 'busy', m.callId)); return; }
      incoming = { id: m.callId, peer: from, video: !!m.video, offer: m.data, members: (m.data && m.data.members) || [] };
      showIncoming(incoming);
      return;
    }
    if (incoming && incoming.id === m.callId && (m.type === 'end' || m.type === 'decline')) { dismissIncoming(from.name + ' stopped calling.'); return; }
    var c = call;
    if (!c || c.id !== m.callId) return;
    var P = c.peers[from.id];
    if (!P) return;
    if (m.type === 'answer') {
      clearTimeout(P.timeout);
      P.pc.setRemoteDescription(m.data).then(function () { flushIce(P); P.state = 'connecting'; P.tag.textContent = 'Connecting…'; if (c.state !== 'connected') { setCallState(c, 'connecting'); stopRing(); } })
        .catch(function () { dropPeer(c, P, 'The call couldn’t be set up.'); });
    } else if (m.type === 'ice' && P.pc) {
      addRemoteIce(P, m.data);
    } else if (m.type === 'decline') {
      dropPeer(c, P, from.name + ' declined the call.');
    } else if (m.type === 'busy') {
      dropPeer(c, P, from.name + (P.state === 'connected' ? ' left the call.' : ' is on another call.'));
    } else if (m.type === 'end') {
      dropPeer(c, P, c.order.length > 1 ? from.name + ' left the call.' : 'The call ended.');
    } else if (m.type === 'hold' || m.type === 'resume') {
      P.held = m.type === 'hold';
      holdUI(c);
    }
  });

  /** Someone already in this call (or just added to it) connects to me directly. */
  function joinFrom(c, from, m) {
    if (c.peers[from.id]) { dropPeerQuiet(c, c.peers[from.id]); }
    var P = addPeer(c, info(from.id, from));
    P.tag.textContent = 'Joining…';
    var pc = connectPeer(c, P);
    pc.setRemoteDescription(m.data).then(function () { flushIce(P); return pc.createAnswer(); })
      .then(function (a) { return pc.setLocalDescription(a); })
      .then(function () { return send(from.id, 'answer', c.id, { data: { type: pc.localDescription.type, sdp: pc.localDescription.sdp } }); })
      .catch(function () { if (call === c && c.peers[from.id] === P) dropPeer(c, P, 'Couldn’t connect to ' + P.name + '.'); });
  }

  function showIncoming(inc) {
    audioCtx();
    startRing(false);
    var group = inc.members.length > 0;
    var sub = (inc.video ? 'Video call' : 'Voice call') + (group ? ' with ' + inc.members.map(function (x) { return x.name; }).join(', ') : '');
    var el = h('div', { class: 'incoming', role: 'alertdialog', 'aria-label': 'Incoming call' },
      h('div', { class: 'incoming-art' }, h('span', { class: 'ring r1' }), h('span', { class: 'ring r2' }), LD.deviceBadge(inc.peer.kind, 64)),
      h('div', { class: 'incoming-text' }, h('b', {}, inc.peer.name), h('span', {}, sub)),
      h('div', { class: 'incoming-actions' },
        h('button', { class: 'call-btn red', 'aria-label': 'Decline', onClick: function () { quiet(send(inc.peer.id, 'decline', inc.id)); dismissIncoming(); } }, LD.icon('phone-off', 24)),
        h('button', { class: 'call-btn green', 'aria-label': 'Answer', onClick: function () { answer(inc); } }, LD.icon(inc.video ? 'video' : 'phone-call', 24))));
    document.body.appendChild(el);
    requestAnimationFrame(function () { el.classList.add('in'); });
    inc.el = el;
    inc.timer = setTimeout(function () { if (incoming === inc) dismissIncoming(); }, 50000);
  }

  function dismissIncoming(msg) {
    var inc = incoming;
    if (!inc) return;
    incoming = null;
    stopRing();
    clearTimeout(inc.timer);
    if (inc.el) { inc.el.classList.remove('in'); setTimeout(function () { if (inc.el.parentNode) inc.el.parentNode.removeChild(inc.el); }, 300); }
    if (msg) LD.toast(msg);
  }

  function answer(inc) {
    if (!secure()) {
      quiet(send(inc.peer.id, 'decline', inc.id));
      dismissIncoming();
      LD.needSecure();
      return;
    }
    var c = { id: inc.id, video: inc.video, role: 'callee', state: 'connecting', started: 0, peers: {}, order: [] };
    dismissIncoming();
    call = c;
    openUI(c);
    media(inc.video).then(function (stream) {
      if (call !== c) { stream.getTracks().forEach(function (t) { t.stop(); }); return; }
      c.local = stream;
      attachLocal(c);
      var P = addPeer(c, { id: inc.peer.id, name: inc.peer.name, kind: inc.peer.kind });
      P.tag.textContent = 'Connecting…';
      var pc = connectPeer(c, P);
      return pc.setRemoteDescription(inc.offer).then(function () { flushIce(P); return pc.createAnswer(); })
        .then(function (a) { return pc.setLocalDescription(a); })
        .then(function () { return send(P.id, 'answer', c.id, { data: { type: pc.localDescription.type, sdp: pc.localDescription.sdp } }); })
        .then(function () {
          // Everyone else already in the call: connect to each directly.
          inc.members.forEach(function (mb) { if (mb.id !== inc.peer.id) invite(c, { id: mb.id, name: mb.name, kind: mb.kind }, true); });
        });
    }).catch(function (e) {
      quiet(send(inc.peer.id, 'decline', c.id));
      if (call === c) finish(c, e.message || 'The call couldn’t start.', false, true);
    });
  }

  // ---- leaving -----------------------------------------------------------------------------------------------------
  function dropPeerQuiet(c, P) {
    clearTimeout(P.timeout);
    try { if (P.pc) P.pc.close(); } catch (e) { /* closed */ }
    if (P.analyser) { try { P.analyser.close && P.analyser.close(); } catch (e) { /* closed */ } }
    if (P.tile.parentNode) P.tile.parentNode.removeChild(P.tile);
    delete c.peers[P.id];
    c.order = c.order.filter(function (id) { return id !== P.id; });
  }

  function dropPeer(c, P, message) {
    if (call !== c || c.peers[P.id] !== P) return;
    dropPeerQuiet(c, P);
    if (!c.order.length) { finish(c, message, true, !/ended\.$/.test(message)); return; }
    LD.toast(message);
    layout(c);
    holdUI(c);
  }

  function finish(c, message, remoteDone, silent) {
    if (call !== c) return;
    call = null;
    stopRing();
    clearTimeout(c.timeout);
    clearInterval(c.clock);
    if (c.raf) cancelAnimationFrame(c.raf);
    c.order.slice().forEach(function (id) { var P = c.peers[id]; if (P) { clearTimeout(P.timeout); try { if (P.pc) P.pc.close(); } catch (e) { /* closed */ } } });
    var streams = [c.local];
    c.order.forEach(function (id) { streams.push(c.peers[id].remote); });
    streams.forEach(function (s) { if (s) s.getTracks().forEach(function (t) { try { t.stop(); } catch (e) { /* stopped */ } }); });
    if (c.actx) { try { c.actx.close(); } catch (e) { /* closed */ } }
    if (LD.isHostApp && window.LDHost.audioMode) { try { window.LDHost.audioMode(false, false); } catch (e) { /* older app */ } }
    LD.overlays.remove(c.entry);
    if (c.ui) {
      c.ui.classList.remove('in');
      setTimeout(function () { if (c.ui.parentNode) c.ui.parentNode.removeChild(c.ui); }, 300);
    }
    var dur = c.started ? ' (' + fmtTime(Date.now() - c.started) + ')' : '';
    if (message) LD.toast(message + (message === 'The call ended.' ? dur : ''), silent ? 'error' : 'info');
    else if (c.started) LD.toast('Call ended' + dur);
  }

  function hangUp(c) {
    c.order.forEach(function (id) { quiet(send(id, 'end', c.id)); });
    finish(c, null);
  }

  // ---- call screen ---------------------------------------------------------------------------------------------------
  var LABEL = { starting: 'Starting…', ringing: 'Ringing…', connecting: 'Connecting…', connected: '' };

  function setCallState(c, st) {
    c.state = st;
    if (st === 'connected' && !c.started) {
      c.started = Date.now();
      c.clock = setInterval(function () { if (c.timeEl) c.timeEl.textContent = fmtTime(Date.now() - c.started); }, 1000);
      c.ui.classList.add('live');
      if (LD.isHostApp && window.LDHost.audioMode) { try { window.LDHost.audioMode(true, c.video); } catch (e) { /* older app */ } }
    }
    layout(c);
  }

  /** Title, status line and tile grid follow who is in the call. */
  function layout(c) {
    if (!c.ui) return;
    var n = c.order.length;
    c.grid.dataset.n = String(Math.min(n, 9));
    c.ui.classList.toggle('group', n > 1);
    c.titleEl.textContent = n === 0 ? '' : n === 1 ? c.peers[c.order[0]].name : 'Group call';
    var status = c.state === 'connected' ? (n > 1 ? (n + 1) + ' people' : '') : LABEL[c.state];
    c.statusEl.textContent = status;
    c.timeEl.hidden = c.state !== 'connected';
    if (c.addBtn) c.addBtn.hidden = c.state !== 'connected';
  }

  /** Hold: stop sending sound and picture; the other side sees "on hold". */
  function setHold(c, on) {
    c.held = on;
    if (c.local) {
      c.local.getAudioTracks().forEach(function (t) { t.enabled = !on && !c.muted; });
      c.local.getVideoTracks().forEach(function (t) { t.enabled = !on && !c.camOff; });
    }
    c.order.forEach(function (id) { var P = c.peers[id]; P.media.muted = on; quiet(send(id, on ? 'hold' : 'resume', c.id)); });
    holdUI(c);
  }
  function holdUI(c) {
    if (!c.ui) return;
    var theirs = c.order.filter(function (id) { return c.peers[id].held; }).map(function (id) { return c.peers[id].name; });
    c.order.forEach(function (id) { var P = c.peers[id]; P.tile.classList.toggle('held', P.held || !!c.held); });
    c.ui.classList.toggle('held', !!c.held);
    c.holdBtn.classList.toggle('on', !!c.held);
    c.holdBtn.setAttribute('aria-pressed', c.held ? 'true' : 'false');
    c.holdBtn.setAttribute('aria-label', c.held ? 'Resume call' : 'Hold call');
    LD.clear(c.holdBtn).appendChild(LD.icon(c.held ? 'phone-call' : 'pause', 24));
    c.holdEl.hidden = !(c.held || theirs.length);
    c.holdEl.textContent = c.held ? 'You put the call on hold' : theirs.join(', ') + (theirs.length > 1 ? ' put' : ' put') + ' the call on hold';
  }

  function openAdd(c) {
    var inCall = {};
    c.order.forEach(function (id) { inCall[id] = true; });
    var list = S.devices.filter(function (d) { return d.online && !inCall[d.id] && (!S.you || d.id !== S.you.id); });
    var panel = h('div', { class: 'call-add', role: 'dialog', 'aria-label': 'Add someone to the call' },
      h('div', { class: 'call-add-card' },
        h('h3', {}, 'Add to the call'),
        list.length ? h('div', { class: 'call-add-list' }, list.map(function (d) {
          return h('button', { class: 'call-add-row', onClick: function () { close(); LD.calls.add(d.id); } }, LD.deviceBadge(d.kind, 40), h('span', {}, d.name), LD.icon('plus', 18));
        })) : h('p', { class: 'field-note' }, 'No one else is online right now.'),
        h('button', { class: 'btn wide', onClick: function () { close(); } }, 'Cancel')));
    function close() { if (panel.parentNode) panel.parentNode.removeChild(panel); }
    panel.addEventListener('click', function (e) { if (e.target === panel) close(); });
    c.ui.appendChild(panel);
  }

  function openUI(c) {
    c.titleEl = h('b', {});
    c.statusEl = h('span', { class: 'call-status' }, LABEL.starting);
    c.timeEl = h('span', { class: 'call-time', hidden: true }, '00:00');
    c.grid = h('div', { class: 'call-grid', dataset: { n: '0' } });
    c.localEl = c.video ? h('video', { class: 'call-local', autoplay: true, playsinline: true, muted: true }) : null;
    if (c.localEl) c.localEl.muted = true;
    var muteBtn = h('button', { class: 'call-btn', 'aria-label': 'Mute microphone', 'aria-pressed': 'false', onClick: function () {
      var on = !c.muted; c.muted = on;
      if (c.local) c.local.getAudioTracks().forEach(function (t) { t.enabled = !on && !c.held; });
      muteBtn.classList.toggle('on', on);
      muteBtn.setAttribute('aria-pressed', on ? 'true' : 'false');
      LD.clear(muteBtn).appendChild(LD.icon(on ? 'mic-off' : 'mic', 24));
    } }, LD.icon('mic', 24));
    var camBtn = c.video ? h('button', { class: 'call-btn', 'aria-label': 'Turn camera off', 'aria-pressed': 'false', onClick: function () {
      var off = !c.camOff; c.camOff = off;
      if (c.local) c.local.getVideoTracks().forEach(function (t) { t.enabled = !off && !c.held; });
      camBtn.classList.toggle('on', off);
      camBtn.setAttribute('aria-pressed', off ? 'true' : 'false');
      LD.clear(camBtn).appendChild(LD.icon(off ? 'video-off' : 'video', 24));
      c.ui.classList.toggle('cam-off', off);
    } }, LD.icon('video', 24)) : null;
    var flipBtn = c.video ? h('button', { class: 'call-btn', 'aria-label': 'Switch camera', onClick: function () { flip(c); } }, LD.icon('refresh', 24)) : null;
    var spkBtn = LD.isHostApp ? h('button', { class: 'call-btn' + (c.video ? ' on' : ''), 'aria-label': 'Loudspeaker', onClick: function () {
      c.speaker = !c.speaker;
      spkBtn.classList.toggle('on', c.speaker);
      try { window.LDHost.audioMode(true, c.speaker); } catch (e) { /* older app */ }
    } }, LD.icon('speaker', 24)) : null;
    if (spkBtn && c.video) c.speaker = true;
    c.holdBtn = h('button', { class: 'call-btn', 'aria-label': 'Hold call', 'aria-pressed': 'false', onClick: function () { if (c.state === 'connected') setHold(c, !c.held); } }, LD.icon('pause', 24));
    c.addBtn = h('button', { class: 'call-btn', 'aria-label': 'Add someone to the call', hidden: true, onClick: function () { openAdd(c); } }, LD.icon('plus', 24));
    c.holdEl = h('div', { class: 'call-hold', hidden: true, role: 'status' });
    var endBtn = h('button', { class: 'call-btn red big', 'aria-label': 'Hang up', onClick: function () { hangUp(c); } }, LD.icon('phone-off', 28));
    c.ui = h('div', { class: 'call' + (c.video ? ' video' : ''), role: 'dialog', 'aria-label': 'Call' },
      c.grid, c.video ? h('div', { class: 'call-shade' }) : null,
      h('div', { class: 'call-top' }, c.titleEl, c.statusEl, c.timeEl),
      c.holdEl, c.localEl,
      h('div', { class: 'call-controls' }, muteBtn, camBtn, flipBtn, spkBtn, c.holdBtn, c.addBtn, endBtn));
    document.body.appendChild(c.ui);
    requestAnimationFrame(function () { c.ui.classList.add('in'); });
    c.entry = { close: function () { LD.toast('Tap the red button to hang up.'); } };
    LD.overlays.push(c.entry);
    layout(c);
  }

  function attachLocal(c) {
    if (c.localEl) { c.localEl.srcObject = c.local; var p = c.localEl.play(); if (p && p.catch) p.catch(function () { /* autoplay */ }); }
  }

  function flip(c) {
    var cur = c.local.getVideoTracks()[0];
    if (!cur) return;
    var facing = (cur.getSettings && cur.getSettings().facingMode) === 'environment' ? 'user' : 'environment';
    navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: facing } } }).then(function (s) {
      var nt = s.getVideoTracks()[0];
      c.order.forEach(function (id) {
        var sender = c.peers[id].pc && c.peers[id].pc.getSenders().filter(function (x) { return x.track && x.track.kind === 'video'; })[0];
        if (sender) sender.replaceTrack(nt);
      });
      c.local.removeTrack(cur); cur.stop(); c.local.addTrack(nt);
      c.localEl.srcObject = c.local;
      c.localEl.classList.toggle('back', facing === 'environment');
    }).catch(function () { LD.toast('Couldn’t switch the camera.', 'error'); });
  }

  /** Pulses each person's avatar with their voice. */
  function watchLevel(c, P) {
    try {
      var AC = window.AudioContext || window.webkitAudioContext;
      if (!AC || !P.remote || P.watching) return;
      P.watching = true;
      c.actx = c.actx || new AC();
      var src = c.actx.createMediaStreamSource(P.remote);
      var an = c.actx.createAnalyser();
      an.fftSize = 256;
      src.connect(an);
      var data = new Uint8Array(an.frequencyBinCount);
      (function tick() {
        if (call !== c || c.peers[P.id] !== P) return;
        an.getByteFrequencyData(data);
        var sum = 0;
        for (var i = 0; i < data.length; i++) sum += data[i];
        P.avatar.style.setProperty('--lvl', Math.min(1, sum / data.length / 70).toFixed(2));
        requestAnimationFrame(tick);
      })();
    } catch (e) { /* the animation is optional */ }
  }

  window.addEventListener('beforeunload', function () { if (call) call.order.forEach(function (id) { quiet(send(id, 'end', call.id)); }); });
})();
