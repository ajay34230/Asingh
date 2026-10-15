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

  function makePeer(c) {
    var pc = new RTCPeerConnection({ iceServers: [] });
    c.pc = pc;
    c.queued = [];
    c.local.getTracks().forEach(function (t) { pc.addTrack(t, c.local); });
    pc.onicecandidate = function (e) {
      if (e.candidate) send(c.peer.id, 'ice', c.id, { data: e.candidate.toJSON ? e.candidate.toJSON() : e.candidate }).catch(function () { /* peer gone */ });
    };
    pc.ontrack = function (e) {
      c.remote = e.streams[0] || c.remote || new MediaStream();
      if (!e.streams[0]) c.remote.addTrack(e.track);
      attachRemote(c);
    };
    pc.onconnectionstatechange = function () {
      if (call !== c) return;
      var st = pc.connectionState;
      if (st === 'connected') { stopRing(); setState(c, 'connected'); }
      else if (st === 'disconnected') setState(c, 'reconnecting');
      else if (st === 'failed') finish(c, 'The connection failed. Check that both devices can reach each other.', true);
    };
    return pc;
  }

  function addRemoteIce(c, cand) {
    if (c.pc.remoteDescription) c.pc.addIceCandidate(cand).catch(function () { /* stale candidate */ });
    else c.queued.push(cand);
  }
  function flushIce(c) {
    var q = c.queued; c.queued = [];
    q.forEach(function (x) { c.pc.addIceCandidate(x).catch(function () { /* stale candidate */ }); });
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
      var c = { id: newId(), peer: { id: d.id, name: d.name, kind: d.kind }, video: !!video, role: 'caller', state: 'starting', started: 0 };
      call = c;
      openUI(c);
      media(video).then(function (stream) {
        if (call !== c) { stream.getTracks().forEach(function (t) { t.stop(); }); return; }
        c.local = stream;
        attachLocal(c);
        var pc = makePeer(c);
        return pc.createOffer().then(function (o) { return pc.setLocalDescription(o); }).then(function () {
          return send(d.id, 'invite', c.id, { video: !!video, data: { type: pc.localDescription.type, sdp: pc.localDescription.sdp } });
        }).then(function () {
          if (call !== c) return;
          setState(c, 'ringing');
          startRing(true);
          c.timeout = setTimeout(function () { if (call === c && c.state === 'ringing') { send(d.id, 'end', c.id).catch(function () { /* ignore */ }); finish(c, d.name + ' didn’t answer.', true); } }, 45000);
        });
      }).catch(function (e) { if (call === c) finish(c, e.message || 'The call couldn’t start.', true, true); });
    }
  };

  // ---- receiving -----------------------------------------------------------------------------------------------
  LD.on('signal', function (m) {
    var from = m.from || {};
    if (m.type === 'invite') {
      if (call || incoming) { send(from.id, 'busy', m.callId).catch(function () { /* ignore */ }); return; }
      incoming = { id: m.callId, peer: from, video: !!m.video, offer: m.data };
      showIncoming(incoming);
      return;
    }
    if (incoming && incoming.id === m.callId && (m.type === 'end' || m.type === 'decline')) { dismissIncoming(from.name + ' stopped calling.'); return; }
    if (!call || call.id !== m.callId) return;
    var c = call;
    if (m.type === 'answer' && c.role === 'caller') {
      clearTimeout(c.timeout);
      c.pc.setRemoteDescription(m.data).then(function () { flushIce(c); setState(c, 'connecting'); stopRing(); }).catch(function () { finish(c, 'The call couldn’t be set up.', true); });
    } else if (m.type === 'ice' && c.pc) {
      addRemoteIce(c, m.data);
    } else if (m.type === 'decline') {
      finish(c, from.name + ' declined the call.', true);
    } else if (m.type === 'busy') {
      finish(c, from.name + ' is on another call.', true);
    } else if (m.type === 'end') {
      finish(c, 'The call ended.', true);
    }
  });

  function showIncoming(inc) {
    audioCtx();
    startRing(false);
    var el = h('div', { class: 'incoming', role: 'alertdialog', 'aria-label': 'Incoming call' },
      h('div', { class: 'incoming-art' }, h('span', { class: 'ring r1' }), h('span', { class: 'ring r2' }), LD.deviceBadge(inc.peer.kind, 64)),
      h('div', { class: 'incoming-text' }, h('b', {}, inc.peer.name), h('span', {}, inc.video ? 'Video call' : 'Voice call')),
      h('div', { class: 'incoming-actions' },
        h('button', { class: 'call-btn red', 'aria-label': 'Decline', onClick: function () { send(inc.peer.id, 'decline', inc.id).catch(function () { /* ignore */ }); dismissIncoming(); } }, LD.icon('phone-off', 24)),
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
      send(inc.peer.id, 'decline', inc.id).catch(function () { /* ignore */ });
      dismissIncoming();
      LD.needSecure();
      return;
    }
    var c = { id: inc.id, peer: inc.peer, video: inc.video, role: 'callee', state: 'connecting', started: 0 };
    dismissIncoming();
    call = c;
    openUI(c);
    media(inc.video).then(function (stream) {
      if (call !== c) { stream.getTracks().forEach(function (t) { t.stop(); }); return; }
      c.local = stream;
      attachLocal(c);
      var pc = makePeer(c);
      return pc.setRemoteDescription(inc.offer).then(function () { flushIce(c); return pc.createAnswer(); })
        .then(function (a) { return pc.setLocalDescription(a); })
        .then(function () { return send(c.peer.id, 'answer', c.id, { data: { type: pc.localDescription.type, sdp: pc.localDescription.sdp } }); });
    }).catch(function (e) {
      send(c.peer.id, 'decline', c.id).catch(function () { /* ignore */ });
      if (call === c) finish(c, e.message || 'The call couldn’t start.', false, true);
    });
  }

  // ---- ending -----------------------------------------------------------------------------------------------------
  function finish(c, message, remoteDone, silent) {
    if (call !== c) return;
    call = null;
    stopRing();
    clearTimeout(c.timeout);
    clearInterval(c.clock);
    if (c.raf) cancelAnimationFrame(c.raf);
    try { if (c.pc) c.pc.close(); } catch (e) { /* closed */ }
    [c.local, c.remote].forEach(function (s) { if (s) s.getTracks().forEach(function (t) { try { t.stop(); } catch (e) { /* stopped */ } }); });
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
    if (c.state === 'ringing' || c.state === 'connecting' || c.state === 'connected' || c.state === 'reconnecting') send(c.peer.id, 'end', c.id).catch(function () { /* ignore */ });
    finish(c, null);
  }

  function fmtTime(ms) {
    var s = Math.round(ms / 1000), m = Math.floor(s / 60);
    return (m < 10 ? '0' : '') + m + ':' + ('0' + (s % 60)).slice(-2);
  }

  // ---- call screen ---------------------------------------------------------------------------------------------------
  var LABEL = { starting: 'Starting…', ringing: 'Ringing…', connecting: 'Connecting…', connected: '', reconnecting: 'Reconnecting…' };

  function setState(c, st) {
    c.state = st;
    if (st === 'connected' && !c.started) {
      c.started = Date.now();
      c.clock = setInterval(function () { if (c.timeEl) c.timeEl.textContent = fmtTime(Date.now() - c.started); }, 1000);
      if (c.ui) c.ui.classList.add('live');
      if (LD.isHostApp && window.LDHost.audioMode) { try { window.LDHost.audioMode(true, c.video); } catch (e) { /* older app */ } }
      watchLevel(c);
    }
    if (c.statusEl) c.statusEl.textContent = st === 'connected' ? '' : LABEL[st];
    if (c.timeEl) c.timeEl.hidden = st !== 'connected';
  }

  function openUI(c) {
    c.statusEl = h('span', { class: 'call-status' }, LABEL.starting);
    c.timeEl = h('span', { class: 'call-time', hidden: true }, '00:00');
    c.remoteEl = c.video ? h('video', { class: 'call-remote', autoplay: true, playsinline: true }) : h('audio', { autoplay: true });
    c.localEl = c.video ? h('video', { class: 'call-local', autoplay: true, playsinline: true, muted: true }) : null;
    if (c.localEl) c.localEl.muted = true;
    var muteBtn = h('button', { class: 'call-btn', 'aria-label': 'Mute microphone', 'aria-pressed': 'false', onClick: function () {
      var on = !c.muted; c.muted = on;
      if (c.local) c.local.getAudioTracks().forEach(function (t) { t.enabled = !on; });
      muteBtn.classList.toggle('on', on);
      muteBtn.setAttribute('aria-pressed', on ? 'true' : 'false');
      LD.clear(muteBtn).appendChild(LD.icon(on ? 'mic-off' : 'mic', 24));
    } }, LD.icon('mic', 24));
    var camBtn = c.video ? h('button', { class: 'call-btn', 'aria-label': 'Turn camera off', 'aria-pressed': 'false', onClick: function () {
      var off = !c.camOff; c.camOff = off;
      if (c.local) c.local.getVideoTracks().forEach(function (t) { t.enabled = !off; });
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
    var endBtn = h('button', { class: 'call-btn red big', 'aria-label': 'Hang up', onClick: function () { hangUp(c); } }, LD.icon('phone-off', 28));
    c.avatar = h('div', { class: 'call-avatar' }, h('span', { class: 'ring r1' }), h('span', { class: 'ring r2' }), h('span', { class: 'ring r3' }), LD.deviceBadge(c.peer.kind, 96));
    c.ui = h('div', { class: 'call' + (c.video ? ' video' : ''), role: 'dialog', 'aria-label': 'Call with ' + c.peer.name },
      c.remoteEl, c.video ? h('div', { class: 'call-shade' }) : null,
      h('div', { class: 'call-top' }, h('b', {}, c.peer.name), c.statusEl, c.timeEl),
      c.avatar, c.localEl,
      h('div', { class: 'call-controls' }, muteBtn, camBtn, flipBtn, spkBtn, endBtn));
    document.body.appendChild(c.ui);
    requestAnimationFrame(function () { c.ui.classList.add('in'); });
    c.entry = { close: function () { LD.toast('Tap the red button to hang up.'); } };
    LD.overlays.push(c.entry);
  }

  function attachLocal(c) {
    if (c.localEl) { c.localEl.srcObject = c.local; var p = c.localEl.play(); if (p && p.catch) p.catch(function () { /* autoplay */ }); }
  }
  function attachRemote(c) {
    c.remoteEl.srcObject = c.remote;
    var p = c.remoteEl.play();
    if (p && p.catch) p.catch(function () {
      // Autoplay was blocked: any tap starts it.
      document.addEventListener('click', function once() { c.remoteEl.play(); document.removeEventListener('click', once); });
    });
    if (c.video) c.ui.classList.add('has-remote');
  }

  function flip(c) {
    var cur = c.local.getVideoTracks()[0];
    if (!cur) return;
    var facing = (cur.getSettings && cur.getSettings().facingMode) === 'environment' ? 'user' : 'environment';
    navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: facing } } }).then(function (s) {
      var nt = s.getVideoTracks()[0];
      var sender = c.pc.getSenders().filter(function (x) { return x.track && x.track.kind === 'video'; })[0];
      if (sender) sender.replaceTrack(nt);
      c.local.removeTrack(cur); cur.stop(); c.local.addTrack(nt);
      c.localEl.srcObject = c.local;
      c.localEl.classList.toggle('back', facing === 'environment');
    }).catch(function () { LD.toast('Couldn’t switch the camera.', 'error'); });
  }

  /** Pulses the avatar with the other person's voice. */
  function watchLevel(c) {
    try {
      var AC = window.AudioContext || window.webkitAudioContext;
      if (!AC || !c.remote) return;
      c.actx = new AC();
      var src = c.actx.createMediaStreamSource(c.remote);
      var an = c.actx.createAnalyser();
      an.fftSize = 256;
      src.connect(an);
      var data = new Uint8Array(an.frequencyBinCount);
      (function tick() {
        if (call !== c) return;
        an.getByteFrequencyData(data);
        var sum = 0;
        for (var i = 0; i < data.length; i++) sum += data[i];
        c.avatar.style.setProperty('--lvl', Math.min(1, sum / data.length / 70).toFixed(2));
        c.raf = requestAnimationFrame(tick);
      })();
    } catch (e) { /* the animation is optional */ }
  }

  window.addEventListener('beforeunload', function () { if (call) send(call.peer.id, 'end', call.id).catch(function () { /* ignore */ }); });
})();
