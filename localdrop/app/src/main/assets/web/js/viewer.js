/* LocalDrop: full-screen viewer for images, video, audio, PDF and text, with swipe between files. */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  function entryFromPath(path) {
    return LD.api.get('/api/files?path=' + encodeURIComponent(LD.parentPath(path))).then(function (d) {
      return d.entries.filter(function (e) { return e.path === path; })[0];
    });
  }

  function isTextual(e) {
    return e.kind === 'text' || e.kind === 'code' || (e.mime || '').indexOf('text/') === 0 || /^(md|json|xml|csv|log|ini|cfg|yml|yaml)$/.test(LD.ext(e.name));
  }

  LD.viewer = {
    openPath: function (path, edit) {
      entryFromPath(path).then(function (e) { if (e) LD.viewer.open([e], 0, edit); }, LD.fail);
    },

    open: function (list, index, startEditing) {
      var cur = index;
      var closed = false;
      var editing = false;
      var title = h('b', { class: 'v-title' });
      var count = h('span', { class: 'v-count' });
      var stage = h('div', { class: 'v-stage' });
      var actions = h('div', { class: 'v-actions' });
      var prev = h('button', { class: 'v-nav prev', 'aria-label': 'Previous file', onClick: function () { go(-1); } }, LD.icon('chevron-left', 26));
      var next = h('button', { class: 'v-nav next', 'aria-label': 'Next file', onClick: function () { go(1); } }, LD.icon('chevron-right', 26));
      var el = h('div', { class: 'viewer', role: 'dialog', 'aria-modal': 'true', 'aria-label': 'File viewer' },
        h('div', { class: 'v-bar' },
          h('button', { class: 'icon-btn', 'aria-label': 'Close', onClick: function () { close(); } }, LD.icon('arrow-left', 22)),
          h('div', { class: 'v-heading' }, title, count), actions),
        stage, prev, next);
      document.getElementById('layer').appendChild(el);
      requestAnimationFrame(function () { requestAnimationFrame(function () { el.classList.add('in'); }); });
      var entry = { close: function () { if (editing && dirty) { LD.confirm({ title: 'Discard your changes?', confirm: 'Discard', danger: true }).then(function (ok) { if (ok) { dirty = false; close(); } }); return; } close(); } };
      var dirty = false;
      LD.overlays.push(entry);

      function close() {
        if (closed) return;
        closed = true;
        LD.overlays.remove(entry);
        document.removeEventListener('keydown', onKey);
        stopMedia();
        el.classList.remove('in');
        setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, LD.reducedMotion() ? 0 : 260);
      }
      function stopMedia() {
        LD.$$('video,audio', stage).forEach(function (m) { try { m.pause(); m.removeAttribute('src'); m.load(); } catch (e) { /* ignore */ } });
      }
      function onKey(e) {
        if (editing) return;
        if (e.key === 'ArrowLeft') go(-1);
        else if (e.key === 'ArrowRight') go(1);
      }
      document.addEventListener('keydown', onKey);

      function go(d) {
        if (editing && dirty) return;
        var n = cur + d;
        if (n < 0 || n >= list.length) return;
        cur = n;
        stage.dataset.dir = d > 0 ? 'next' : 'prev';
        show();
      }

      // swipe between files
      var sx = null, sy = 0;
      stage.addEventListener('touchstart', function (e) { if (e.touches.length === 1) { sx = e.touches[0].clientX; sy = e.touches[0].clientY; } }, { passive: true });
      stage.addEventListener('touchend', function (e) {
        if (sx == null || editing) return;
        var t = e.changedTouches[0];
        var dx = t.clientX - sx, dy = t.clientY - sy;
        sx = null;
        var zoomed = stage.querySelector('.v-img.zoom');
        if (!zoomed && Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) go(dx < 0 ? 1 : -1);
      }, { passive: true });

      function menuActions(e) {
        LD.clear(actions);
        actions.appendChild(h('button', { class: 'icon-btn', 'aria-label': 'Download', onClick: function () { LD.download(LD.fileUrl(e.path, true)); } }, LD.icon('download', 22)));
        if (S.perms.links) actions.appendChild(h('button', { class: 'icon-btn', 'aria-label': 'Share link', onClick: function () { LD.shareLink(e); } }, LD.icon('link', 22)));
        actions.appendChild(h('button', { class: 'icon-btn', 'aria-label': 'More', onClick: function () { LD.fileActions.menu(e, list); } }, LD.icon('more', 22)));
      }

      function show() {
        var e = list[cur];
        stopMedia();
        editing = false;
        dirty = false;
        title.textContent = e.name;
        count.textContent = list.length > 1 ? (cur + 1) + ' of ' + list.length : LD.fmtSize(e.size);
        prev.hidden = cur === 0;
        next.hidden = cur === list.length - 1;
        menuActions(e);
        var page = h('div', { class: 'v-page' });
        LD.clear(stage).appendChild(page);
        var url = LD.fileUrl(e.path);
        var kind = e.kind || 'file';
        if (kind === 'image') {
          var img = h('img', { class: 'v-img', src: url, alt: e.name, draggable: 'false' });
          var spin = h('div', { class: 'v-spin' });
          img.addEventListener('load', function () { spin.remove(); });
          img.addEventListener('error', function () { spin.remove(); img.remove(); page.appendChild(fallback(e, 'This image can’t be shown here.')); });
          var scroller = h('div', { class: 'v-zoom' }, img);
          img.addEventListener('click', function () { img.classList.toggle('zoom'); scroller.classList.toggle('zoomed', img.classList.contains('zoom')); });
          page.appendChild(scroller);
          page.appendChild(spin);
          // warm up neighbours
          [cur - 1, cur + 1].forEach(function (i) { if (list[i] && list[i].kind === 'image') { var pre = new Image(); pre.src = LD.fileUrl(list[i].path); } });
        } else if (kind === 'video') {
          page.appendChild(h('video', { class: 'v-video', src: url, controls: true, playsinline: true, preload: 'metadata', autoplay: true }));
        } else if (kind === 'audio') {
          page.appendChild(h('div', { class: 'v-audio' },
            h('div', { class: 'v-disc' }, LD.icon('music', 54)),
            h('b', {}, e.name), h('span', {}, LD.fmtSize(e.size)),
            h('audio', { src: url, controls: true, autoplay: true, preload: 'metadata' })));
        } else if (kind === 'pdf') {
          if (LD.isHostApp) page.appendChild(fallback(e, 'PDFs open in another app on this phone.', true));
          else page.appendChild(h('iframe', { class: 'v-pdf', src: url, title: e.name }));
        } else if (isTextual(e) && e.size <= 1024 * 1024) {
          text(e, page);
        } else {
          page.appendChild(fallback(e));
        }
      }

      function fallback(e, msg, openable) {
        return h('div', { class: 'v-fallback' },
          h('span', { class: 'tile big k-' + (e.kind || 'file') }, LD.icon(LD.kindIcon(e.kind || 'file'), 40)),
          h('b', {}, e.name),
          h('span', {}, msg || 'No preview for this kind of file. ' + LD.fmtSize(e.size)),
          h('div', { class: 'btn-row' },
            openable ? h('button', { class: 'btn', onClick: function () { window.LDHost.openExternal(LD.fileUrl(e.path)); } }, LD.icon('external', 18), 'Open') : null,
            h('button', { class: 'btn primary', onClick: function () { LD.download(LD.fileUrl(e.path, true)); } }, LD.icon('download', 18), 'Download')));
      }

      function text(e, page) {
        page.appendChild(h('div', { class: 'v-spin' }));
        LD.api.get('/api/text?path=' + encodeURIComponent(e.path)).then(function (d) {
          if (closed || list[cur] !== e) return;
          LD.clear(page);
          var pre = h('pre', { class: 'v-text' }, d.content || '');
          var ta = h('textarea', { class: 'v-edit', spellcheck: 'false', hidden: true, 'aria-label': 'Edit ' + e.name });
          ta.value = d.content || '';
          ta.addEventListener('input', function () { dirty = true; saveBtn.disabled = false; });
          var saveBtn = h('button', { class: 'btn small primary', disabled: true, onClick: save }, 'Save');
          var editBtn = h('button', { class: 'btn small', onClick: function () { toggle(true); } }, LD.icon('edit', 16), 'Edit');
          var bar = h('div', { class: 'v-textbar' }, S.perms.modify ? editBtn : null, saveBtn);
          saveBtn.hidden = true;
          page.appendChild(bar);
          page.appendChild(pre);
          page.appendChild(ta);
          function toggle(on) {
            editing = on;
            pre.hidden = on;
            ta.hidden = !on;
            editBtn.hidden = on;
            saveBtn.hidden = !on;
            if (on) ta.focus();
          }
          function save() {
            saveBtn.disabled = true;
            LD.api.post('/api/text', { path: e.path, content: ta.value }).then(function (r) {
              dirty = false;
              pre.textContent = ta.value;
              e.size = r.size; e.mtime = r.mtime;
              toggle(false);
              LD.toast('Saved', 'ok');
            }, function (err) { saveBtn.disabled = false; LD.fail(err); });
          }
          if (startEditing && S.perms.modify) { startEditing = false; toggle(true); }
        }, function (err) {
          if (closed) return;
          LD.clear(page).appendChild(fallback(e, err.message));
        });
      }

      show();
      return { close: close };
    }
  };
})();
