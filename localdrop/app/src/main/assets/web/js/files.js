/* LocalDrop: the Files screen (browse, search, upload, download, organise, share, trash). */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  // ---- helpers shared with other screens ------------------------------------------
  var originCache = { t: 0, v: null };
  /** The address other devices should use. On the host phone that is its Wi-Fi/hotspot address, not 127.0.0.1. */
  LD.publicOrigin = function () {
    if (!S.isHost) return Promise.resolve(location.origin);
    if (originCache.v && Date.now() - originCache.t < 10000) return Promise.resolve(originCache.v);
    return LD.api.get('/api/admin/network').then(function (a) {
      var v = a.length ? a[0].url : location.origin;
      originCache = { t: Date.now(), v: v };
      return v;
    }, function () { return location.origin; });
  };

  LD.sortEntries = function (list, sort) {
    var k = sort.key, d = sort.dir;
    return list.slice().sort(function (a, b) {
      if (a.dir !== b.dir) return a.dir ? -1 : 1;
      var r;
      if (k === 'date') r = a.mtime - b.mtime;
      else if (k === 'size') r = a.size - b.size;
      else if (k === 'type') r = (LD.ext(a.name)).localeCompare(LD.ext(b.name)) || a.name.localeCompare(b.name);
      else r = a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' });
      return (r || a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' })) * d;
    });
  };

  function kindOf(e) { return e.dir ? 'folder' : (e.kind || 'file'); }

  LD.tile = function (e, size) {
    var kind = kindOf(e);
    var t = h('span', { class: 'tile k-' + kind + (size ? ' ' + size : '') }, LD.icon(LD.kindIcon(kind), size === 'small' ? 18 : 24));
    if (!e.dir && (kind === 'image' || kind === 'video') && !/\.svg$/i.test(e.name)) {
      var img = h('img', { src: LD.thumbUrl(e.path, 240) + '&v=' + (e.mtime || 0), alt: '', loading: 'lazy', decoding: 'async' });
      img.addEventListener('load', function () { t.classList.add('has-img'); });
      img.addEventListener('error', function () { if (img.parentNode) img.parentNode.removeChild(img); });
      t.appendChild(img);
      if (kind === 'video') t.appendChild(h('span', { class: 'tile-play' }, LD.icon('play', 12)));
    }
    return t;
  };

  // ---- share link sheet -----------------------------------------------------------------
  LD.shareLink = function (entry) {
    var hours = 24;
    var out = h('div', { class: 'share-out' });
    var body = h('div', { class: 'share' },
      h('div', { class: 'share-file' }, LD.tile(entry, 'small'), h('div', { class: 'share-name' }, entry.name)),
      h('p', { class: 'field-note' }, 'Anyone on this network with the link can download this ' + (entry.dir ? 'folder as a zip' : 'file') + ', without a PIN.'),
      h('label', { class: 'field-label' }, 'Link works for'),
      LD.segmented([{ value: 1, label: '1 hour' }, { value: 24, label: '1 day' }, { value: 168, label: '7 days' }, { value: 0, label: 'No limit' }], 24, function (v) { hours = v; }),
      out);
    var btn = h('button', { class: 'btn primary wide', onClick: create }, LD.icon('link', 18), 'Create link');
    body.insertBefore(btn, out);
    LD.sheet({ title: 'Share with a link', body: body });

    function create() {
      btn.disabled = true;
      Promise.all([LD.api.post('/api/share', { path: entry.path, hours: hours }), LD.publicOrigin()]).then(function (r) {
        var url = r[1] + r[0].url;
        btn.remove();
        LD.clear(out).appendChild(h('div', { class: 'share-done' },
          LD.qrBlock(url, 200),
          h('button', { class: 'address', onClick: function () { LD.copyWithToast(url, 'Link copied'); } }, h('span', { class: 'address-text' }, url.replace(/^http:\/\//, '')), LD.icon('copy', 18)),
          h('p', { class: 'field-note' }, r[0].expires ? 'Expires ' + new Date(r[0].expires).toLocaleString() : 'This link never expires. Remove it any time in Settings.'),
          h('div', { class: 'btn-row' },
            h('button', { class: 'btn', onClick: function () { LD.copyWithToast(url, 'Link copied'); } }, LD.icon('copy', 18), 'Copy'),
            h('button', { class: 'btn primary', onClick: function () { LD.nativeShare(url, entry.name); } }, LD.icon('share', 18), 'Share'))));
        out.classList.add('pop');
      }, function (e) { btn.disabled = false; LD.fail(e); });
    }
  };

  /** Lists and removes the links this device has made. */
  LD.manageLinks = function () {
    var list = h('div', { class: 'link-list' }, LD.skeleton(2));
    LD.sheet({ title: 'Share links', body: list });
    function load() {
      Promise.all([LD.api.get('/api/shares'), LD.publicOrigin()]).then(function (r) {
        LD.clear(list);
        if (!r[0].length) { list.appendChild(LD.empty('link', 'No links yet', 'Open a file’s menu and choose Share link to make one.')); return; }
        r[0].forEach(function (s) {
          var url = r[1] + s.url;
          list.appendChild(h('div', { class: 'link-row' },
            h('span', { class: 'tile small k-' + (s.dir ? 'folder' : 'file') }, LD.icon(s.dir ? 'folder' : 'file', 18)),
            h('div', { class: 'link-main' }, h('b', {}, s.name),
              h('span', {}, (s.downloads || 0) + (s.downloads === 1 ? ' download' : ' downloads') + ' \u00b7 ' + (s.expires ? 'until ' + new Date(s.expires).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }) : 'no expiry'))),
            h('button', { class: 'icon-btn', 'aria-label': 'Copy link', onClick: function () { LD.copyWithToast(url, 'Link copied'); } }, LD.icon('copy', 18)),
            h('button', { class: 'icon-btn', 'aria-label': 'Remove link', onClick: function () { LD.api.post('/api/share/revoke', { token: s.token }).then(load, LD.fail); } }, LD.icon('trash', 18))));
        });
      }, function (e) { LD.clear(list).appendChild(h('p', { class: 'pick-empty' }, e.message)); });
    }
    load();
  };

  // ---- trash --------------------------------------------------------------------------------
  LD.openTrash = function () {
    var body = h('div', { class: 'trash' }, LD.skeleton(3));
    LD.sheet({ title: 'Trash', body: body });
    function load() {
      LD.api.get('/api/trash').then(function (items) {
        LD.clear(body);
        if (!items.length) { body.appendChild(LD.empty('trash', 'Trash is empty', 'Deleted items stay here for 30 days.')); return; }
        items.sort(function (a, b) { return b.deleted - a.deleted; });
        items.forEach(function (it) {
          body.appendChild(h('div', { class: 'link-row' },
            h('span', { class: 'tile small k-' + (it.dir ? 'folder' : 'file') }, LD.icon(it.dir ? 'folder' : 'file', 18)),
            h('div', { class: 'link-main' }, h('b', {}, it.name), h('span', {}, (it.dir ? 'Folder' : LD.fmtSize(it.size)) + ' · deleted ' + LD.fmtAgo(it.deleted))),
            S.perms.modify ? h('button', { class: 'btn small', onClick: function () {
              LD.api.post('/api/trash/restore', { ids: [it.id] }).then(function () { LD.toast('Restored ' + it.name, 'ok'); load(); }, LD.fail);
            } }, LD.icon('undo', 16), 'Restore') : null));
        });
        if (S.isHost) {
          body.appendChild(h('button', { class: 'btn danger wide', onClick: function () {
            LD.confirm({ title: 'Empty the trash?', body: 'This permanently deletes everything in the trash.', confirm: 'Empty trash', danger: true }).then(function (ok) {
              if (ok) LD.api.post('/api/trash/empty', {}).then(function () { LD.toast('Trash emptied', 'ok'); load(); }, LD.fail);
            });
          } }, LD.icon('trash', 18), 'Empty trash'));
        }
      }, function (e) { LD.clear(body).appendChild(h('p', { class: 'pick-empty' }, e.message)); });
    }
    load();
  };

  // ---- uploads ------------------------------------------------------------------------------
  var up = { items: [], running: 0, next: 1, tray: null, hideTimer: null, expanded: false };

  function trayEl() {
    if (up.tray) return up.tray;
    up.tray = h('div', { class: 'tray', role: 'status', hidden: true });
    document.body.appendChild(up.tray);
    return up.tray;
  }

  function renderTray() {
    var tray = trayEl();
    var items = up.items;
    if (!items.length) { tray.hidden = true; return; }
    var total = 0, loaded = 0, done = 0, failed = 0, active = 0, speed = 0;
    items.forEach(function (it) {
      total += it.file.size || 0;
      loaded += it.state === 'done' ? (it.file.size || 0) : it.loaded;
      if (it.state === 'done') done++;
      if (it.state === 'error') failed++;
      if (it.state === 'active') { active++; speed += it.speed || 0; }
    });
    var finished = done + failed + items.filter(function (i) { return i.state === 'cancelled'; }).length === items.length;
    var pct = total ? Math.min(100, Math.round(loaded / total * 100)) : (finished ? 100 : 0);
    tray.hidden = false;
    tray.classList.toggle('done', finished && !failed);
    tray.classList.toggle('open', up.expanded);
    LD.clear(tray);
    var title = finished
      ? (failed ? done + ' uploaded, ' + failed + ' failed' : (done === 1 ? 'Uploaded 1 file' : 'Uploaded ' + done + ' files'))
      : 'Uploading ' + Math.min(items.length, done + failed + Math.max(1, active)) + ' of ' + items.length;
    tray.appendChild(h('div', { class: 'tray-head' },
      h('span', { class: 'tray-ic' }, LD.icon(finished ? (failed ? 'alert' : 'check-circle') : 'upload', 20)),
      h('button', { class: 'tray-title', onClick: function () { up.expanded = !up.expanded; renderTray(); } },
        h('b', {}, title),
        h('span', {}, finished ? LD.fmtSize(total) : LD.fmtSize(loaded) + ' of ' + LD.fmtSize(total) + (speed ? ' · ' + LD.fmtSpeed(speed) : ''))),
      finished
        ? h('button', { class: 'icon-btn', 'aria-label': 'Dismiss', onClick: clearUploads }, LD.icon('x', 18))
        : h('button', { class: 'icon-btn', 'aria-label': 'Cancel all uploads', onClick: cancelAll }, LD.icon('x', 18))));
    tray.appendChild(h('div', { class: 'progress' + (finished ? ' full' : '') }, h('i', { style: { width: pct + '%' } })));
    if (up.expanded) {
      var list = h('div', { class: 'tray-list' });
      items.slice(-30).forEach(function (it) {
        var p = it.file.size ? Math.round((it.state === 'done' ? it.file.size : it.loaded) / it.file.size * 100) : (it.state === 'done' ? 100 : 0);
        list.appendChild(h('div', { class: 'tray-row ' + it.state },
          h('span', { class: 'tray-name' }, (it.rel ? it.rel + '/' : '') + it.file.name),
          h('span', { class: 'tray-state' }, it.state === 'done' ? 'Done' : it.state === 'error' ? it.err : it.state === 'cancelled' ? 'Cancelled' : it.state === 'queued' ? 'Waiting' : p + '%')));
      });
      tray.appendChild(list);
    }
    clearTimeout(up.hideTimer);
    if (finished && !failed) up.hideTimer = setTimeout(clearUploads, 4500);
  }

  function clearUploads() {
    up.items = up.items.filter(function (i) { return i.state === 'queued' || i.state === 'active'; });
    up.expanded = false;
    renderTray();
  }
  function cancelAll() {
    up.items.forEach(function (it) {
      if (it.state === 'queued') it.state = 'cancelled';
      else if (it.state === 'active' && it.ctrl) it.ctrl.abort();
    });
    renderTray();
  }

  function pump() {
    while (up.running < 2) {
      var it = up.items.filter(function (i) { return i.state === 'queued'; })[0];
      if (!it) break;
      start(it);
    }
    renderTray();
    var pending = up.items.some(function (i) { return i.state === 'queued' || i.state === 'active'; });
    if (!pending && up.dirty) { up.dirty = false; LD.emit('files-changed', { dir: '*' }); }
  }

  function start(it) {
    up.running++;
    it.state = 'active';
    it.ctrl = typeof AbortController === 'function' ? new AbortController() : { abort: function () {}, signal: undefined };
    var t0 = Date.now(), last = 0, lastT = t0;
    LD.upload(it.file, {
      path: it.path, rel: it.rel, signal: it.ctrl.signal,
      onProgress: function (l) {
        it.loaded = l;
        var now = Date.now();
        if (now - lastT > 600) { it.speed = (l - last) / ((now - lastT) / 1000); last = l; lastT = now; }
        if (now - (up.paint || 0) > 120) { up.paint = now; renderTray(); }
      }
    }).then(function () {
      it.state = 'done';
      up.dirty = true;
    }, function (e) {
      if (e && e.name === 'AbortError') it.state = 'cancelled';
      else { it.state = 'error'; it.err = (e && e.message) || 'Failed'; }
    }).then(function () {
      up.running--;
      it.speed = 0;
      pump();
    });
  }

  LD.addUploads = function (fileList, path, relMap) {
    if (!S.perms.upload) { LD.toast('The host has turned off uploads.', 'error'); return; }
    var files = Array.prototype.slice.call(fileList);
    if (!files.length) return;
    files.forEach(function (f, i) {
      var rel = '';
      if (relMap) rel = relMap[i] || '';
      else if (f.webkitRelativePath) rel = LD.parentPath(f.webkitRelativePath);
      up.items.push({ id: up.next++, file: f, path: path, rel: rel, state: 'queued', loaded: 0, speed: 0 });
    });
    if (up.items.length > 300) {
      up.items = up.items.filter(function (i, idx) { return idx >= up.items.length - 300 || i.state === 'queued' || i.state === 'active'; });
    }
    pump();
  };

  /** Reads dropped files and folders (a drag from a computer). */
  function collectDropped(dt) {
    return new Promise(function (resolve) {
      var out = [], rels = [];
      var items = dt.items ? Array.prototype.slice.call(dt.items) : [];
      var hasEntries = items.length && items[0].webkitGetAsEntry;
      if (!hasEntries) { resolve({ files: Array.prototype.slice.call(dt.files), rels: [] }); return; }
      var pending = 0;
      function done() { if (pending === 0) resolve({ files: out, rels: rels }); }
      function walk(entry, base) {
        if (!entry) return;
        if (entry.isFile) {
          pending++;
          entry.file(function (f) { out.push(f); rels.push(base); pending--; done(); }, function () { pending--; done(); });
        } else if (entry.isDirectory) {
          pending++;
          var reader = entry.createReader();
          var all = [];
          (function readMore() {
            reader.readEntries(function (batch) {
              if (batch.length) { all = all.concat(Array.prototype.slice.call(batch)); readMore(); }
              else {
                all.forEach(function (c) { walk(c, base ? base + '/' + entry.name : entry.name); });
                pending--;
                done();
              }
            }, function () { pending--; done(); });
          })();
        }
      }
      var entries = items.filter(function (i) { return i.kind === 'file'; }).map(function (i) { return i.webkitGetAsEntry(); });
      entries.forEach(function (e) { walk(e, ''); });
      if (!entries.length) done();
    });
  }

  // ---- the screen -------------------------------------------------------------------------------
  var st = {
    path: null, entries: [], loading: false, error: null,
    sort: { key: LD.store.get('ld_sort', 'name'), dir: LD.store.get('ld_sortdir', '1') === '-1' ? -1 : 1 },
    view: LD.store.get('ld_view', 'list'), filter: 'all',
    q: '', results: null, sel: {}, selecting: false, hidden: LD.store.get('ld_hidden', '0') === '1', seq: 0, fresh: true
  };
  var el = {};

  function selCount() { return Object.keys(st.sel).length; }
  function selEntries() {
    var all = st.results || st.entries;
    return all.filter(function (e) { return st.sel[e.path]; });
  }

  function mount(root) {
    el.root = root;
    el.crumbs = h('nav', { class: 'crumbs scroll-x', 'aria-label': 'Folder path' });
    el.search = h('input', { class: 'search-input', type: 'search', placeholder: 'Search files', 'aria-label': 'Search files', autocomplete: 'off', enterkeyhint: 'search' });
    el.searchClear = h('button', { class: 'icon-btn search-clear', hidden: true, 'aria-label': 'Clear search', onClick: function () { el.search.value = ''; setQuery(''); el.search.focus(); } }, LD.icon('x', 16));
    el.search.addEventListener('input', LD.debounce(function () { setQuery(el.search.value); }, 250));
    el.list = h('div', { class: 'entries' });
    el.storage = h('div', { class: 'storage-line' });
    el.tools = h('div', { class: 'tools' });
    el.selbar = h('div', { class: 'selbar', hidden: true });
    el.fab = h('button', { class: 'fab', 'aria-label': 'Add files', onClick: openAddMenu }, LD.icon('plus', 26));
    el.fileIn = h('input', { type: 'file', multiple: true, hidden: true, onChange: function () { LD.addUploads(el.fileIn.files, st.path); el.fileIn.value = ''; } });
    el.dirIn = h('input', { type: 'file', multiple: true, hidden: true, webkitdirectory: true, onChange: function () { LD.addUploads(el.dirIn.files, st.path); el.dirIn.value = ''; } });
    el.drop = h('div', { class: 'dropzone', hidden: true }, h('div', { class: 'dropzone-card' }, LD.icon('upload', 36), h('b', {}, 'Drop to upload'), h('span', {}, '')));

    root.appendChild(h('div', { class: 'files-head' },
      h('div', { class: 'search' }, LD.icon('search', 18), el.search, el.searchClear),
      el.tools));
    root.appendChild(el.crumbs);
    el.chips = h('div', { class: 'chips scroll-x', role: 'group', 'aria-label': 'Filter by type' });
    root.appendChild(el.chips);
    root.appendChild(el.storage);
    root.appendChild(el.list);
    root.appendChild(el.fab);
    root.appendChild(el.fileIn);
    root.appendChild(el.dirIn);
    document.body.appendChild(el.selbar);
    document.body.appendChild(el.drop);
    renderTools();
    renderChips();

    LD.on('files-changed', function (d) {
      if (S.tab !== 'files' && !up.items.length) { st.stale = true; return; }
      if (st.results) return;
      if (!d || d.dir === '*' || d.dir === st.path || (d.dir || '').indexOf(st.path + '/') === 0 || st.path === '') reloadSoon();
    });
    LD.on('reconnected', function () { if (shellReady()) reloadSoon(); });
    LD.on('settings-changed', function (d) { if (d && d.root) { st.fresh = true; load(); } });

    // drag and drop from a computer
    var depth = 0;
    document.addEventListener('dragenter', function (e) {
      if (S.tab !== 'files' || !hasFiles(e)) return;
      depth++;
      el.drop.hidden = false;
      el.drop.querySelector('span').textContent = 'into ' + (st.path ? LD.baseName(st.path) : (S.info && S.info.rootName) || 'Shared');
    });
    document.addEventListener('dragover', function (e) { if (hasFiles(e)) e.preventDefault(); });
    document.addEventListener('dragleave', function () { depth = Math.max(0, depth - 1); if (!depth) el.drop.hidden = true; });
    document.addEventListener('drop', function (e) {
      if (!hasFiles(e)) return;
      e.preventDefault();
      depth = 0;
      el.drop.hidden = true;
      if (S.tab !== 'files') return;
      var target = st.path;
      collectDropped(e.dataTransfer).then(function (r) { LD.addUploads(r.files, target, r.rels); });
    });
    LD.screens.files.root = root;
  }
  function hasFiles(e) {
    var t = e.dataTransfer && e.dataTransfer.types;
    return !!t && Array.prototype.indexOf.call(t, 'Files') >= 0;
  }
  function shellReady() { return st.path !== null; }

  var reloadSoon = LD.debounce(function () { load(true); }, 350);

  function setPath(p) {
    if (st.path === p && !st.stale) return;
    var changed = st.path !== p;
    st.path = p;
    S.path = p;
    st.stale = false;
    if (changed) {
      st.q = '';
      st.results = null;
      st.sel = {};
      st.selecting = false;
      if (el.search) { el.search.value = ''; el.searchClear.hidden = true; }
      st.fresh = true;
    }
    renderCrumbs();
    renderSelbar();
    load(!changed);
  }

  function load(silent) {
    var seq = ++st.seq;
    if (!silent) {
      st.loading = true;
      st.error = null;
      LD.clear(el.list).appendChild(LD.skeleton(6));
    }
    LD.api.get('/api/files?path=' + encodeURIComponent(st.path) + (st.hidden ? '&hidden=1' : '')).then(function (d) {
      if (seq !== st.seq) return;
      st.loading = false;
      st.entries = d.entries;
      st.error = null;
      // Drop selections that no longer exist.
      Object.keys(st.sel).forEach(function (k) { if (!d.entries.some(function (e) { return e.path === k; })) delete st.sel[k]; });
      renderList();
      renderSelbar();
    }, function (e) {
      if (seq !== st.seq) return;
      st.loading = false;
      if (silent && st.entries.length) return;
      st.error = e;
      LD.clear(el.list).appendChild(LD.empty('alert', "Can't open this folder", e.message,
        h('button', { class: 'btn', onClick: function () { if (e.status === 404 && st.path) LD.go('files', LD.parentPath(st.path)); else load(); } }, e.status === 404 && st.path ? 'Go back' : 'Try again')));
    });
    refreshStorage();
  }

  function refreshStorage() {
    LD.api.get('/api/storage').then(function (s) {
      if (!s.total) { LD.clear(el.storage); return; }
      var used = Math.max(0, s.total - s.free);
      LD.clear(el.storage).appendChild(h('div', { class: 'storage' },
        h('div', { class: 'progress thin' }, h('i', { style: { width: Math.min(100, used / s.total * 100) + '%' } })),
        h('span', {}, LD.fmtSize(s.free) + ' free of ' + LD.fmtSize(s.total))));
    }, function () { /* storage info is optional */ });
  }

  // ---- search -----------------------------------------------------------------------------------------------
  function setQuery(q) {
    q = q.trim();
    el.searchClear.hidden = !el.search.value;
    if (q === st.q) return;
    st.q = q;
    st.sel = {};
    if (!q) { st.results = null; renderList(); renderSelbar(); return; }
    var seq = ++st.seq;
    LD.api.get('/api/search?q=' + encodeURIComponent(q) + '&path=' + encodeURIComponent(st.path) + (st.hidden ? '&hidden=1' : '')).then(function (d) {
      if (seq !== st.seq || q !== st.q) return;
      st.results = d.entries;
      renderList();
    }, LD.fail);
  }

  // ---- rendering ------------------------------------------------------------------------------------------------
  function renderCrumbs() {
    LD.clear(el.crumbs);
    var rootName = (S.info && S.info.rootName) || 'Shared';
    var parts = st.path ? st.path.split('/') : [];
    function crumb(label, path, last, home) {
      return h('button', { class: 'crumb' + (last ? ' current' : ''), 'aria-current': last ? 'page' : 'false', onClick: function () { if (!last) LD.go('files', path); } },
        home ? LD.icon('drive', 15) : null, label);
    }
    el.crumbs.appendChild(crumb(rootName, '', !parts.length, true));
    var acc = '';
    parts.forEach(function (p, i) {
      acc = acc ? acc + '/' + p : p;
      el.crumbs.appendChild(LD.icon('chevron-right', 14));
      el.crumbs.appendChild(crumb(p, acc, i === parts.length - 1, false));
    });
    requestAnimationFrame(function () { el.crumbs.scrollLeft = el.crumbs.scrollWidth; });
  }

  function renderTools() {
    LD.clear(el.tools);
    el.tools.appendChild(h('button', { class: 'icon-btn', 'aria-label': 'Sort', onClick: openSortMenu }, LD.icon('sort', 20)));
    el.tools.appendChild(h('button', { class: 'icon-btn', 'aria-label': st.view === 'grid' ? 'Show as list' : 'Show as grid', onClick: function () {
      st.view = st.view === 'grid' ? 'list' : 'grid';
      LD.store.set('ld_view', st.view);
      st.fresh = true;
      renderTools();
      renderList();
    } }, LD.icon(st.view === 'grid' ? 'list' : 'grid', 20)));
    el.tools.appendChild(h('button', { class: 'icon-btn', 'aria-label': 'More', onClick: openMore }, LD.icon('more', 20)));
  }

  function openSortMenu() {
    var keys = [['name', 'Name'], ['date', 'Date modified'], ['size', 'Size'], ['type', 'Type']];
    var items = keys.map(function (k) {
      return { label: k[1], checked: st.sort.key === k[0], onClick: function () {
        if (st.sort.key === k[0]) st.sort.dir = -st.sort.dir; else { st.sort.key = k[0]; st.sort.dir = k[0] === 'date' || k[0] === 'size' ? -1 : 1; }
        LD.store.set('ld_sort', st.sort.key); LD.store.set('ld_sortdir', String(st.sort.dir));
        st.fresh = true;
        renderList();
      }, hint: st.sort.key === k[0] ? (st.sort.dir === 1 ? (k[0] === 'name' || k[0] === 'type' ? 'A to Z' : 'Smallest first') : (k[0] === 'name' || k[0] === 'type' ? 'Z to A' : (k[0] === 'date' ? 'Newest first' : 'Largest first'))) : null };
    });
    LD.menu(items, { title: 'Sort by' });
  }

  function openMore() {
    LD.menu([
      { icon: 'select', label: 'Select items', onClick: function () { st.selecting = true; renderList(); renderSelbar(); } },
      { icon: 'refresh', label: 'Refresh', onClick: function () { load(); } },
      { icon: st.hidden ? 'eye-off' : 'eye', label: st.hidden ? 'Hide hidden files' : 'Show hidden files', onClick: function () {
        st.hidden = !st.hidden; LD.store.set('ld_hidden', st.hidden ? '1' : '0'); load();
      } },
      { sep: true },
      { icon: 'download', label: 'Download this folder as zip', onClick: function () { LD.download(LD.zipUrl([st.path], st.path ? LD.baseName(st.path) : null)); } },
      { icon: 'link', label: 'My share links', disabled: !S.perms.links, onClick: LD.manageLinks },
      { icon: 'trash', label: 'Trash', onClick: LD.openTrash }
    ]);
  }

  function openAddMenu() {
    var up_ = S.perms.upload, mod = S.perms.modify;
    var items = [
      { icon: 'upload', label: 'Upload files', hint: 'From this device', disabled: !up_, onClick: function () { el.fileIn.click(); } }
    ];
    if (!LD.isHostApp) items.push({ icon: 'folder-plus', label: 'Upload a folder', hint: 'Keeps its structure', disabled: !up_, onClick: function () { el.dirIn.click(); } });
    items.push({ icon: 'folder-plus', label: 'New folder', disabled: !mod, onClick: newFolder });
    items.push({ icon: 'file-plus', label: 'New text file', disabled: !up_, onClick: newTextFile });
    LD.menu(items, { title: 'Add to ' + (st.path ? LD.baseName(st.path) : (S.info && S.info.rootName) || 'Shared') });
  }

  function newFolder() {
    LD.form({ title: 'New folder', label: 'Folder name', placeholder: 'Untitled folder', confirm: 'Create', submit: function (name) {
      return LD.api.post('/api/mkdir', { path: st.path, name: name.trim() });
    } }).then(function (r) { if (r) { LD.toast('Folder created', 'ok'); load(true); } });
  }

  function newTextFile() {
    LD.form({ title: 'New text file', label: 'File name', value: 'Note.txt', selectName: true, confirm: 'Create', submit: function (name) {
      return LD.api.post('/api/newfile', { path: st.path, name: name.trim(), content: '' });
    } }).then(function (r) {
      if (r && r.path) { load(true); LD.viewer.openPath(r.path, true); }
    });
  }

  function meta(e, showPath) {
    var bits = [];
    bits.push(e.dir ? 'Folder' : LD.fmtSize(e.size));
    if (e.mtime) bits.push(LD.fmtAgo(e.mtime));
    if (showPath) { var p = LD.parentPath(e.path); bits.push(p ? p : (S.info && S.info.rootName) || 'Shared'); }
    return bits.join(' · ');
  }

  var FILTERS = [
    ['all', 'All', null], ['image', 'Photos', ['image']], ['video', 'Videos', ['video']], ['audio', 'Music', ['audio']],
    ['doc', 'Documents', ['pdf', 'doc', 'sheet', 'slides', 'text', 'code']], ['archive', 'Zips', ['archive']], ['apk', 'Apps', ['apk']]
  ];
  function renderChips() {
    LD.clear(el.chips);
    FILTERS.forEach(function (f) {
      el.chips.appendChild(h('button', { class: 'chip' + (st.filter === f[0] ? ' on' : ''), 'aria-pressed': st.filter === f[0] ? 'true' : 'false', onClick: function () {
        st.filter = f[0]; st.fresh = true; renderChips(); renderList();
      } }, f[1]));
    });
  }
  function applyFilter(list) {
    if (st.filter === 'all') return list;
    var kinds = FILTERS.filter(function (f) { return f[0] === st.filter; })[0][2];
    return list.filter(function (e) { return e.dir || kinds.indexOf(e.kind) >= 0; });
  }

  function renderList() {
    var searching = !!st.q;
    var raw = searching ? (st.results || []) : applyFilter(st.entries);
    var list = searching ? raw : LD.sortEntries(raw, st.sort);
    st.shown = list;
    el.root.classList.toggle('selecting', st.selecting);
    el.root.classList.toggle('grid', st.view === 'grid' && !searching);
    LD.clear(el.list);
    el.list.className = 'entries ' + (st.view === 'grid' && !searching ? 'grid' : 'list') + (st.fresh ? ' stagger' : '');
    st.fresh = false;
    if (!list.length) {
      el.list.className = 'entries';
      if (searching) el.list.appendChild(LD.empty('search', 'Nothing found', 'No files match “' + st.q + '” in this folder or the folders inside it.'));
      else el.list.appendChild(LD.empty('folder', 'This folder is empty', S.perms.upload ? 'Tap + to add files, or drop them here from a computer.' : 'Nothing has been shared here yet.',
        S.perms.upload ? h('button', { class: 'btn primary', onClick: function () { el.fileIn.click(); } }, LD.icon('upload', 18), 'Upload files') : null));
      return;
    }
    var files = list.filter(function (e) { return !e.dir; });
    list.forEach(function (e, i) {
      var node = st.view === 'grid' && !searching ? card(e, i, files) : row(e, i, searching, files);
      el.list.appendChild(node);
    });
  }

  function interact(node, e, files) {
    var timer = null, long = false, sx = 0, sy = 0;
    node.addEventListener('touchstart', function (ev) {
      long = false;
      var t = ev.touches[0];
      sx = t.clientX; sy = t.clientY;
      timer = setTimeout(function () {
        long = true;
        if (navigator.vibrate) { try { navigator.vibrate(12); } catch (x) { /* not supported */ } }
        st.selecting = true;
        toggleSel(e, true);
      }, 520);
    }, { passive: true });
    node.addEventListener('touchmove', function (ev) {
      var t = ev.touches[0];
      if (Math.abs(t.clientX - sx) > 8 || Math.abs(t.clientY - sy) > 8) clearTimeout(timer);
    }, { passive: true });
    ['touchend', 'touchcancel'].forEach(function (n) { node.addEventListener(n, function () { clearTimeout(timer); }, { passive: true }); });
    node.addEventListener('contextmenu', function (ev) { ev.preventDefault(); if (!long) { st.selecting = true; toggleSel(e, true); } });
    node.addEventListener('click', function (ev) {
      if (long) { long = false; ev.preventDefault(); return; }
      if (st.selecting) { toggleSel(e); return; }
      openEntry(e, files);
    });
  }

  function check(e) {
    return h('span', { class: 'check' + (st.sel[e.path] ? ' on' : ''), 'aria-hidden': 'true' }, LD.icon('check', 14));
  }

  function row(e, i, searching, files) {
    var hit = h('button', { class: 'item-hit', 'aria-label': (e.dir ? 'Folder ' : '') + e.name },
      check(e), LD.tile(e),
      h('span', { class: 'item-text' }, h('span', { class: 'item-name' }, e.name), h('span', { class: 'item-meta' }, meta(e, searching))));
    interact(hit, e, files);
    var node = h('div', { class: 'item' + (st.sel[e.path] ? ' selected' : ''), style: { '--i': Math.min(i, 14) }, dataset: { path: e.path } },
      hit,
      h('button', { class: 'icon-btn item-more', 'aria-label': 'Actions for ' + e.name, onClick: function (ev) { ev.stopPropagation(); openItemMenu(e, files); } }, LD.icon('more', 20)));
    return node;
  }

  function card(e, i, files) {
    var hit = h('button', { class: 'card-hit', 'aria-label': (e.dir ? 'Folder ' : '') + e.name }, check(e), LD.tile(e, 'big'),
      h('span', { class: 'card-name' }, e.name), h('span', { class: 'card-meta' }, e.dir ? 'Folder' : LD.fmtSize(e.size)));
    interact(hit, e, files);
    return h('div', { class: 'card' + (st.sel[e.path] ? ' selected' : ''), style: { '--i': Math.min(i, 14) }, dataset: { path: e.path } },
      hit,
      h('button', { class: 'icon-btn card-more', 'aria-label': 'Actions for ' + e.name, onClick: function (ev) { ev.stopPropagation(); openItemMenu(e, files); } }, LD.icon('more', 18)));
  }

  function openEntry(e, files) {
    if (e.dir) { LD.go('files', e.path); return; }
    var idx = files.indexOf(e);
    LD.viewer.open(files, Math.max(0, idx));
  }

  function toggleSel(e, forceOn) {
    if (forceOn || !st.sel[e.path]) st.sel[e.path] = true; else delete st.sel[e.path];
    if (!selCount() && !forceOn) st.selecting = false;
    LD.$$('[data-path]', el.list).forEach(function (n) {
      var on = !!st.sel[n.dataset.path];
      n.classList.toggle('selected', on);
      var c = n.querySelector('.check');
      if (c) c.classList.toggle('on', on);
    });
    el.root.classList.toggle('selecting', st.selecting);
    renderSelbar();
  }

  function exitSelect() {
    st.selecting = false;
    st.sel = {};
    renderList();
    renderSelbar();
  }

  function renderSelbar() {
    var n = selCount();
    var show = st.selecting && S.tab === 'files';
    el.selbar.hidden = !show;
    document.body.classList.toggle('selecting', show);
    if (!show) return;
    var list = st.shown || [];
    LD.clear(el.selbar);
    var mod = S.perms.modify;
    el.selbar.appendChild(h('div', { class: 'selbar-top' },
      h('button', { class: 'icon-btn', 'aria-label': 'Done selecting', onClick: exitSelect }, LD.icon('x', 20)),
      h('b', {}, n ? n + ' selected' : 'Select items'),
      h('button', { class: 'btn small', onClick: function () {
        var all = list.length && list.every(function (e) { return st.sel[e.path]; });
        st.sel = {};
        if (!all) list.forEach(function (e) { st.sel[e.path] = true; });
        renderList(); renderSelbar();
      } }, list.length && list.every(function (e) { return st.sel[e.path]; }) ? 'Clear' : 'Select all')));
    function act(icon, label, fn, danger, off) {
      return h('button', { class: 'sel-act' + (danger ? ' danger' : ''), disabled: !n || !!off, onClick: fn }, LD.icon(icon, 22), h('span', {}, label));
    }
    el.selbar.appendChild(h('div', { class: 'selbar-actions' },
      act('download', 'Download', function () { downloadMany(selEntries()); }),
      act('move', 'Move', function () { moveCopy(selEntries(), false); }, false, !mod),
      act('copy', 'Copy', function () { moveCopy(selEntries(), true); }, false, !mod),
      act('trash', 'Delete', function () { deleteMany(selEntries()); }, true, !mod)));
  }

  // ---- actions -------------------------------------------------------------------------------------------------------------
  function downloadMany(items) {
    if (!items.length) return;
    if (items.length === 1 && !items[0].dir) { LD.download(LD.fileUrl(items[0].path, true)); return; }
    LD.download(LD.zipUrl(items.map(function (e) { return e.path; }), items.length === 1 ? items[0].name : null));
    LD.toast('Preparing a zip. The download starts right away.', 'ok');
  }

  function moveCopy(items, copy) {
    if (!items.length) return;
    var folders = items.filter(function (e) { return e.dir; }).map(function (e) { return e.path; });
    var parents = items.map(function (e) { return LD.parentPath(e.path); });
    LD.pickFolder({
      title: (copy ? 'Copy ' : 'Move ') + (items.length === 1 ? items[0].name : items.length + ' items') + ' to',
      start: st.path, exclude: folders, confirm: copy ? 'Copy here' : 'Move here',
      disableHere: function (p) { return !copy && parents.every(function (x) { return x === p; }); }
    }).then(function (dest) {
      if (dest == null) return;
      LD.api.post('/api/move', { paths: items.map(function (e) { return e.path; }), dest: dest, copy: copy }).then(function (r) {
        LD.toast((copy ? 'Copied ' : 'Moved ') + r.count + (r.count === 1 ? ' item' : ' items'), 'ok');
        exitSelect();
        load(true);
      }, LD.fail);
    });
  }

  function deleteMany(items) {
    if (!items.length) return;
    LD.confirm({
      title: items.length === 1 ? 'Delete “' + items[0].name + '”?' : 'Delete ' + items.length + ' items?',
      body: 'They go to the Trash, where you can restore them for 30 days.', confirm: 'Move to Trash', danger: true
    }).then(function (ok) {
      if (!ok) return;
      LD.api.post('/api/delete', { paths: items.map(function (e) { return e.path; }) }).then(function (r) {
        LD.toast(r.count === 1 ? 'Moved to Trash' : r.count + ' items moved to Trash', 'ok');
        exitSelect();
        load(true);
      }, LD.fail);
    });
  }

  function rename(e) {
    LD.form({ title: 'Rename', label: 'New name', value: e.name, selectName: !e.dir, confirm: 'Rename', submit: function (name) {
      return LD.api.post('/api/rename', { path: e.path, name: name.trim() });
    } }).then(function (r) { if (r) { LD.toast('Renamed', 'ok'); load(true); } });
  }

  function details(e) {
    var rows = [['Name', e.name], ['Kind', e.dir ? 'Folder' : (e.mime || 'File')], ['Size', e.dir ? '—' : LD.fmtSize(e.size) + ' (' + e.size.toLocaleString() + ' bytes)'],
      ['Modified', new Date(e.mtime).toLocaleString()], ['Location', '/' + LD.parentPath(e.path)]];
    LD.sheet({ title: 'Details', body: h('dl', { class: 'details' }, rows.map(function (r) { return [h('dt', {}, r[0]), h('dd', {}, r[1])]; })) });
  }

  function sendInDrop(e) {
    LD.api.post('/api/messages', { text: '', file: { path: e.path } }).then(function () {
      LD.toast('Sent to everyone in Drop', 'ok');
    }, LD.fail);
  }

  function openItemMenu(e, files) {
    var mod = S.perms.modify;
    var items = [];
    if (!e.dir) items.push({ icon: 'eye', label: 'Open', onClick: function () { openEntry(e, files || [e]); } });
    items.push({ icon: 'download', label: e.dir ? 'Download as zip' : 'Download', onClick: function () { downloadMany([e]); } });
    items.push({ icon: 'link', label: 'Share link', disabled: !S.perms.links, hint: S.perms.links ? null : 'Turned off by the host', onClick: function () { LD.shareLink(e); } });
    if (!e.dir) items.push({ icon: 'send', label: 'Send in Drop', onClick: function () { sendInDrop(e); } });
    items.push({ sep: true });
    items.push({ icon: 'edit', label: 'Rename', disabled: !mod, onClick: function () { rename(e); } });
    items.push({ icon: 'move', label: 'Move to…', disabled: !mod, onClick: function () { moveCopy([e], false); } });
    items.push({ icon: 'copy', label: 'Copy to…', disabled: !mod, onClick: function () { moveCopy([e], true); } });
    items.push({ icon: 'select', label: 'Select', onClick: function () { st.selecting = true; toggleSel(e, true); } });
    items.push({ icon: 'info', label: 'Details', onClick: function () { details(e); } });
    items.push({ sep: true });
    items.push({ icon: 'trash', label: 'Delete', danger: true, disabled: !mod, onClick: function () { deleteMany([e]); } });
    LD.menu(items, { title: e.name });
  }

  LD.fileActions = { menu: openItemMenu, downloadMany: downloadMany };

  LD.screens.files = {
    mount: mount,
    setPath: setPath,
    onShow: function () { if (st.stale) { st.stale = false; load(true); } renderSelbar(); },
    handleBack: function () {
      if (st.selecting) { exitSelect(); return true; }
      if (st.q) { el.search.value = ''; setQuery(''); return true; }
      return false;
    },
    reload: function () { load(true); }
  };
  LD.on('perms', function () { if (el.root) renderSelbar(); });
  LD.on('tab', function () { if (st.path !== null) renderSelbar(); });
})();
