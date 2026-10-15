/* LocalDrop: the Drop screen. Quick messages, links and files between every device on the network. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  var el = {};
  var to = null; // null = everyone, otherwise a device id
  var pending = []; // uploads in flight, shown as bubbles
  var coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;

  function deviceName(id) {
    var d = S.devices.filter(function (x) { return x.id === id; })[0];
    return d ? d.name : 'a device';
  }
  function nearBottom() { return el.scroll.scrollHeight - el.scroll.scrollTop - el.scroll.clientHeight < 140; }
  function toBottom(smooth) {
    requestAnimationFrame(function () {
      if (smooth && !LD.reducedMotion() && el.scroll.scrollTo) el.scroll.scrollTo({ top: el.scroll.scrollHeight, behavior: 'smooth' });
      else el.scroll.scrollTop = el.scroll.scrollHeight;
    });
  }

  function entryOf(f) { return { name: f.name, path: f.path, size: f.size, mime: f.mime, kind: f.kind, mtime: 0, dir: false }; }

  function fileBubble(f) {
    var e = entryOf(f);
    if (f.kind === 'image' && !/\.svg$/i.test(f.name)) {
      var img = h('img', { class: 'msg-img', src: LD.thumbUrl(f.path, 520), alt: f.name, loading: 'lazy' });
      img.addEventListener('load', function () { if (el.stick) toBottom(); });
      img.addEventListener('error', function () { var p = img.parentNode; if (p) p.replaceWith(fileCard(f, e)); });
      return h('button', { class: 'msg-photo', 'aria-label': 'Open ' + f.name, onClick: function () { LD.viewer.open([e], 0); } }, img);
    }
    return fileCard(f, e);
  }
  function fileCard(f, e) {
    return h('div', { class: 'msg-file' },
      h('button', { class: 'msg-file-main', onClick: function () { LD.viewer.open([e], 0); } },
        h('span', { class: 'tile small k-' + (f.kind || 'file') }, LD.icon(LD.kindIcon(f.kind || 'file'), 18)),
        h('span', { class: 'msg-file-text' }, h('b', {}, f.name), h('span', {}, LD.fmtSize(f.size)))),
      h('button', { class: 'icon-btn', 'aria-label': 'Download ' + f.name, onClick: function () { LD.download(LD.fileUrl(f.path, true)); } }, LD.icon('download', 18)));
  }

  function bubble(m, prev) {
    var mine = S.you && m.from && m.from.id === S.you.id;
    var grouped = prev && prev.from && m.from && prev.from.id === m.from.id && (m.t - prev.t) < 180000 && !!prev.to === !!m.to && sameDay(prev.t, m.t);
    var body = h('div', { class: 'bubble' });
    if (m.to) {
      body.appendChild(h('div', { class: 'private' }, LD.icon('lock', 12), mine ? 'Private to ' + deviceName(m.to) : 'Private'));
    }
    if (m.file) body.appendChild(fileBubble(m.file));
    if (m.text) body.appendChild(h('div', { class: 'msg-text' }, LD.linkify(m.text)));
    body.appendChild(h('div', { class: 'msg-time' }, LD.fmtClock(m.t)));
    var node = h('div', { class: 'msg ' + (mine ? 'mine' : 'theirs') + (grouped ? ' grouped' : ''), dataset: { id: m.id } },
      !mine ? h('div', { class: 'msg-av' }, grouped ? null : LD.deviceBadge(m.from.kind, 30)) : null,
      h('div', { class: 'msg-col' },
        !mine && !grouped ? h('div', { class: 'msg-from' }, m.from.name) : null,
        body));
    // actions
    var open = function (ev) {
      if (ev) ev.preventDefault();
      var items = [];
      if (m.text) items.push({ icon: 'copy', label: 'Copy text', onClick: function () { LD.copyWithToast(m.text, 'Text copied'); } });
      if (m.file) items.push({ icon: 'download', label: 'Download file', onClick: function () { LD.download(LD.fileUrl(m.file.path, true)); } });
      if (m.file) items.push({ icon: 'folder', label: 'Show in Files', onClick: function () { LD.go('files', LD.parentPath(m.file.path)); } });
      if (mine || S.isHost) items.push({ icon: 'trash', label: 'Delete for everyone', danger: true, onClick: function () { LD.api.post('/api/messages/delete', { id: m.id }).catch(LD.fail); } });
      LD.menu(items);
    };
    body.addEventListener('contextmenu', open);
    var timer;
    body.addEventListener('touchstart', function () { timer = setTimeout(function () { open(); }, 520); }, { passive: true });
    ['touchend', 'touchmove', 'touchcancel'].forEach(function (n) { body.addEventListener(n, function () { clearTimeout(timer); }, { passive: true }); });
    return node;
  }
  function sameDay(a, b) { return new Date(a).toDateString() === new Date(b).toDateString(); }

  function render() {
    el.stick = true;
    LD.clear(el.list);
    var msgs = S.messages;
    if (!msgs.length && !pending.length) {
      el.list.appendChild(LD.empty('message', 'Nothing here yet', 'Send a note, a link or a file. Everyone connected sees it right away.'));
      return;
    }
    var prev = null;
    msgs.forEach(function (m) {
      if (!prev || !sameDay(prev.t, m.t)) el.list.appendChild(h('div', { class: 'day' }, h('span', {}, LD.fmtDay(m.t))));
      el.list.appendChild(bubble(m, prev));
      prev = m;
    });
    pending.forEach(function (p) { el.list.appendChild(p.node); });
    toBottom();
  }

  function append(m) {
    var stick = nearBottom() || (S.you && m.from.id === S.you.id);
    var last = S.messages[S.messages.length - 2];
    var emptyEl = el.list.querySelector('.empty');
    if (emptyEl) LD.clear(el.list);
    if (!last || !sameDay(last.t, m.t)) el.list.appendChild(h('div', { class: 'day' }, h('span', {}, LD.fmtDay(m.t))));
    var node = bubble(m, last);
    node.classList.add('new');
    // keep progress bubbles last
    var firstPending = pending.length ? pending[0].node : null;
    if (firstPending && firstPending.parentNode === el.list) el.list.insertBefore(node, firstPending); else el.list.appendChild(node);
    if (stick) toBottom(true);
  }

  function updateTo() {
    var online = S.devices.filter(function (d) { return d.online && (!S.you || d.id !== S.you.id); });
    if (to && !S.devices.some(function (d) { return d.id === to; })) to = null;
    LD.clear(el.who);
    el.who.appendChild(h('span', { class: 'who-label' }, to ? LD.icon('lock', 14) : LD.icon('users', 14), to ? 'Private to ' + deviceName(to) : 'Everyone'));
    el.who.appendChild(LD.icon('chevron-down', 16));
    el.who.classList.toggle('private', !!to);
    el.sub.textContent = online.length ? online.length + (online.length === 1 ? ' other device online' : ' other devices online') : 'No other devices online yet';
  }

  function chooseWho() {
    var items = [{ icon: 'users', label: 'Everyone', hint: 'Visible to all devices', checked: !to, onClick: function () { to = null; updateTo(); } }];
    S.devices.filter(function (d) { return !S.you || d.id !== S.you.id; }).forEach(function (d) {
      items.push({ icon: LD.deviceIcon(d.kind), label: d.name + (d.host ? ' (host)' : ''), hint: d.online ? 'Online. Only you two see it' : 'Offline. They get it when they return',
        checked: to === d.id, onClick: function () { to = d.id; updateTo(); } });
    });
    LD.menu(items, { title: 'Send to' });
  }

  function send() {
    var text = el.input.value.trim();
    if (!text) return;
    el.send.disabled = true;
    LD.api.post('/api/messages', { text: text, to: to }).then(function () {
      el.input.value = '';
      grow();
      el.send.disabled = true;
      el.input.focus();
    }, function (e) { el.send.disabled = false; LD.fail(e); });
  }

  function grow() {
    el.input.style.height = 'auto';
    el.input.style.height = Math.min(el.input.scrollHeight, 140) + 'px';
    el.send.disabled = !el.input.value.trim();
  }

  function sendFiles(files) {
    if (!S.perms.upload) { LD.toast('The host has turned off uploads.', 'error'); return; }
    Array.prototype.forEach.call(files, function (f) {
      var bar = h('i', { style: { width: '0%' } });
      var label = h('span', {}, 'Sending…');
      var node = h('div', { class: 'msg mine pending' }, h('div', { class: 'msg-col' }, h('div', { class: 'bubble' },
        h('div', { class: 'msg-file' }, h('span', { class: 'tile small k-file' }, LD.icon('upload', 18)),
          h('span', { class: 'msg-file-text' }, h('b', {}, f.name), label)),
        h('div', { class: 'progress thin' }, bar))));
      var rec = { node: node };
      pending.push(rec);
      if (el.list.querySelector('.empty')) LD.clear(el.list);
      el.list.appendChild(node);
      toBottom(true);
      var target = to;
      LD.upload(f, {
        path: '', rel: 'Drop', quiet: true, tid: Math.random().toString(36).slice(2, 12) + Date.now().toString(36), to: target || '',
        onProgress: function (l, t) { bar.style.width = Math.round(l / t * 100) + '%'; label.textContent = LD.fmtSize(l) + ' of ' + LD.fmtSize(t); }
      }).then(function (r) {
        return LD.api.post('/api/messages', { text: '', to: target, file: { path: r.path } });
      }).then(function () {
        remove();
      }, function (e) {
        label.textContent = e.message || 'Failed';
        node.classList.add('failed');
        setTimeout(remove, 4500);
      });
      function remove() {
        pending = pending.filter(function (p) { return p !== rec; });
        if (node.parentNode) node.parentNode.removeChild(node);
      }
    });
  }

  function mount(root) {
    el.who = h('button', { class: 'who', onClick: chooseWho, 'aria-label': 'Choose who to send to' });
    el.sub = h('span', { class: 'drop-sub' });
    el.list = h('div', { class: 'msgs' });
    el.scroll = h('div', { class: 'msgs-scroll' }, el.list);
    el.input = h('textarea', { class: 'composer-input', rows: 1, placeholder: 'Write a message or paste a link', 'aria-label': 'Message', enterkeyhint: 'send', maxlength: 8000 });
    el.send = h('button', { class: 'send-btn', 'aria-label': 'Send', disabled: true, onClick: send }, LD.icon('send', 20));
    el.file = h('input', { type: 'file', multiple: true, hidden: true, onChange: function () { sendFiles(el.file.files); el.file.value = ''; } });
    var attach = h('button', { class: 'icon-btn attach', 'aria-label': 'Attach a file', onClick: function () { el.file.click(); } }, LD.icon('clip', 22));
    var more = h('button', { class: 'icon-btn', 'aria-label': 'Drop options', onClick: function () {
      LD.menu([
        { icon: 'folder', label: 'See received files', hint: 'In the Drop folder', onClick: function () { LD.go('files', 'Drop'); } },
        { icon: 'trash', label: 'Clear all messages', danger: true, disabled: !S.isHost, hint: S.isHost ? null : 'Only the host can do this', onClick: function () {
          LD.confirm({ title: 'Clear all messages?', body: 'This removes the conversation for everyone. Files stay in the Drop folder.', confirm: 'Clear', danger: true }).then(function (ok) {
            if (ok) LD.api.post('/api/messages/clear', {}).catch(LD.fail);
          });
        } }
      ]);
    } }, LD.icon('more', 20));
    el.input.addEventListener('input', grow);
    el.input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && !e.shiftKey && !coarse && !e.isComposing) { e.preventDefault(); send(); }
    });
    el.input.addEventListener('paste', function (e) {
      var fs = e.clipboardData && e.clipboardData.files;
      if (fs && fs.length) { e.preventDefault(); sendFiles(fs); }
    });

    root.appendChild(h('div', { class: 'drop-head' }, h('div', { class: 'drop-titles' }, h('h2', {}, 'Drop'), el.sub), el.who, more));
    root.appendChild(el.scroll);
    root.appendChild(h('div', { class: 'composer' }, attach, el.input, el.send, el.file));
    updateTo();
    render();

    LD.on('message', function (m) { if (!S.messages.length) return; append(m); if (S.tab === 'drop') { S.unread = 0; LD.emit('unread'); } });
    LD.on('messages-changed', render);
    LD.on('devices', updateTo);
    LD.on('reconnected', function () { LD.loadMessages().catch(function () { /* keep what we have */ }); });
  }

  LD.screens.drop = {
    mount: mount,
    onShow: function () { updateTo(); toBottom(); },
    setTarget: function (id) { to = id; if (el.who) updateTo(); },
    sendTo: function (id, files) { to = id; if (el.who) updateTo(); sendFiles(files); }
  };
})();
