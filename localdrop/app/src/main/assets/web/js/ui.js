/* LocalDrop: building blocks shared by every screen (toasts, sheets, menus, dialogs, theme). */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;

  // ---- theme ----------------------------------------------------------------
  LD.theme = {
    mode: function () { return LD.store.get('ld_theme', 'auto'); },
    set: function (m) { LD.store.set('ld_theme', m); LD.theme.apply(); },
    isDark: function () {
      var m = LD.theme.mode();
      if (m === 'dark') return true;
      if (m === 'light') return false;
      return !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
    },
    apply: function () {
      var m = LD.theme.mode();
      if (m === 'auto') document.documentElement.removeAttribute('data-theme');
      else document.documentElement.setAttribute('data-theme', m);
      requestAnimationFrame(function () {
        var bg = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim() || '#EDF3F5';
        var meta = document.querySelector('meta[name=theme-color]');
        if (meta) meta.setAttribute('content', bg);
        if (LD.isHostApp && window.LDHost.bars) {
          try { window.LDHost.bars(bg, !LD.theme.isDark()); } catch (e) { /* older app */ }
        }
        LD.emit('theme', LD.theme.isDark());
      });
    }
  };
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var onChange = function () { if (LD.theme.mode() === 'auto') LD.theme.apply(); };
    if (mq.addEventListener) mq.addEventListener('change', onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }

  // ---- overlays (sheets, viewer) are closed by Back, Escape or the page's own buttons ----
  var stack = [];
  LD.overlays = {
    push: function (e) { stack.push(e); },
    remove: function (e) { var i = stack.indexOf(e); if (i >= 0) stack.splice(i, 1); },
    closeTop: function () {
      var e = stack[stack.length - 1];
      if (!e) return false;
      e.close();
      return true;
    },
    closeAll: function () { while (stack.length) stack[stack.length - 1].close(); },
    count: function () { return stack.length; }
  };
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && LD.overlays.closeTop()) e.preventDefault();
  });
  window.addEventListener('hashchange', function () { LD.overlays.closeAll(); });

  function layer() { return document.getElementById('layer'); }

  // ---- toasts ---------------------------------------------------------------
  LD.toast = function (message, kind) {
    var host = document.getElementById('toasts');
    if (!host) return;
    var icon = kind === 'error' ? 'alert' : kind === 'ok' ? 'check-circle' : 'info';
    var t = h('div', { class: 'toast ' + (kind || 'info'), role: 'status' },
      LD.icon(icon, 18), h('span', {}, message));
    host.appendChild(t);
    requestAnimationFrame(function () { t.classList.add('in'); });
    var ms = kind === 'error' ? 5200 : 2800;
    setTimeout(function () {
      t.classList.remove('in');
      setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 300);
    }, ms);
    while (host.children.length > 3) host.removeChild(host.firstChild);
  };
  LD.fail = function (e) {
    LD.toast((e && e.message) || 'Something went wrong.', 'error');
  };

  // ---- sheets ---------------------------------------------------------------
  /** Opens a bottom sheet on phones and a centred dialog on larger screens. */
  LD.sheet = function (opts) {
    var closed = false;
    var head = null;
    var closeBtn = h('button', { class: 'icon-btn', 'aria-label': 'Close', onClick: function () { close(); } }, LD.icon('x', 20));
    if (opts.title) {
      head = h('div', { class: 'sheet-head' },
        h('h2', {}, opts.title),
        opts.headerRight || null,
        closeBtn);
    }
    var body = h('div', { class: 'sheet-body' }, opts.body);
    var grip = h('div', { class: 'sheet-grip' });
    var panel = h('div', { class: 'sheet' + (opts.wide ? ' wide' : ''), role: 'dialog', 'aria-modal': 'true', 'aria-label': opts.title || 'Dialog' },
      grip, head, body);
    var backdrop = h('div', { class: 'backdrop', onClick: function () { close(); } });
    var wrap = h('div', { class: 'sheet-wrap' }, backdrop, panel);
    layer().appendChild(wrap);
    requestAnimationFrame(function () { requestAnimationFrame(function () { wrap.classList.add('in'); }); });
    var entry = { close: function () { close(); } };
    LD.overlays.push(entry);

    // drag down to dismiss
    var startY = null, dy = 0;
    function down(e) {
      if (body.scrollTop > 0 && e.target !== grip && !(head && head.contains(e.target))) return;
      startY = (e.touches ? e.touches[0] : e).clientY;
      dy = 0;
      panel.style.transition = 'none';
    }
    function move(e) {
      if (startY == null) return;
      dy = Math.max(0, (e.touches ? e.touches[0] : e).clientY - startY);
      panel.style.transform = 'translateY(' + dy + 'px)';
    }
    function up() {
      if (startY == null) return;
      startY = null;
      panel.style.transition = '';
      if (dy > 90) close();
      else panel.style.transform = '';
    }
    [grip, head].forEach(function (el) {
      if (!el) return;
      el.addEventListener('touchstart', down, { passive: true });
      el.addEventListener('touchmove', move, { passive: true });
      el.addEventListener('touchend', up);
    });

    function close(result) {
      if (closed) return;
      closed = true;
      LD.overlays.remove(entry);
      wrap.classList.remove('in');
      wrap.classList.add('out');
      setTimeout(function () { if (wrap.parentNode) wrap.parentNode.removeChild(wrap); }, LD.reducedMotion() ? 0 : 280);
      if (opts.onClose) opts.onClose(result);
    }
    setTimeout(function () {
      var f = panel.querySelector('[data-autofocus]');
      if (f) { f.focus(); if (f.select) f.select(); }
    }, 60);
    return { close: close, el: panel, body: body, setTitle: function (t) { if (head) head.querySelector('h2').textContent = t; } };
  };

  /** A list of actions: [{icon, label, hint, danger, disabled, onClick}] */
  LD.menu = function (items, opts) {
    opts = opts || {};
    var sheet;
    var list = h('div', { class: 'menu' }, items.map(function (it) {
      if (it.sep) return h('div', { class: 'menu-sep' });
      return h('button', {
        class: 'menu-item' + (it.danger ? ' danger' : '') + (it.checked ? ' checked' : ''),
        disabled: !!it.disabled,
        onClick: function () {
          sheet.close();
          if (it.onClick) setTimeout(it.onClick, 120);
        }
      },
        it.icon ? h('span', { class: 'menu-ic' }, LD.icon(it.icon, 20)) : h('span', { class: 'menu-ic' }),
        h('span', { class: 'menu-text' }, h('span', { class: 'menu-label' }, it.label), it.hint ? h('span', { class: 'menu-hint' }, it.hint) : null),
        it.checked ? LD.icon('check', 18) : null);
    }));
    sheet = LD.sheet({ title: opts.title, body: list });
    return sheet;
  };

  /**
   * A dialog with one text field. `submit(value)` may be async; if it throws, the message is shown in the dialog.
   * Resolves with whatever submit returned, or null if the person cancelled.
   */
  LD.form = function (opts) {
    return new Promise(function (resolve) {
      var done = false;
      var err = h('div', { class: 'field-error', role: 'alert' });
      var input = h('input', {
        class: 'input', type: opts.type || 'text', value: opts.value || '', placeholder: opts.placeholder || '',
        'data-autofocus': '', autocomplete: 'off', autocapitalize: 'none', spellcheck: 'false', maxlength: opts.maxlength || 200,
        inputmode: opts.inputmode || null
      });
      var okBtn = h('button', { class: 'btn primary', onClick: submit }, opts.confirm || 'Save');
      var body = h('form', { class: 'form', onSubmit: function (e) { e.preventDefault(); submit(); } },
        opts.label ? h('label', { class: 'field-label' }, opts.label) : null,
        input, err,
        opts.note ? h('p', { class: 'field-note' }, opts.note) : null,
        h('div', { class: 'btn-row' },
          h('button', { type: 'button', class: 'btn', onClick: function () { sheet.close(null); } }, 'Cancel'),
          okBtn));
      var sheet = LD.sheet({ title: opts.title, body: body, onClose: function () { if (!done) { done = true; resolve(null); } } });
      if (opts.selectName) {
        setTimeout(function () {
          var v = input.value, dot = v.lastIndexOf('.');
          input.focus();
          input.setSelectionRange(0, dot > 0 ? dot : v.length);
        }, 80);
      }
      function submit() {
        var v = input.value;
        if (opts.required !== false && !v.trim()) { err.textContent = 'Enter a value to continue.'; input.focus(); return; }
        okBtn.disabled = true;
        err.textContent = '';
        Promise.resolve(opts.submit ? opts.submit(v) : v).then(function (r) {
          done = true;
          sheet.close();
          resolve(r === undefined ? v : r);
        }, function (e) {
          okBtn.disabled = false;
          err.textContent = (e && e.message) || 'Something went wrong.';
          input.focus();
        });
      }
    });
  };

  LD.confirm = function (opts) {
    return new Promise(function (resolve) {
      var done = false;
      var body = h('div', { class: 'form' },
        opts.body ? h('p', { class: 'confirm-body' }, opts.body) : null,
        h('div', { class: 'btn-row' },
          h('button', { class: 'btn', 'data-autofocus': '', onClick: function () { sheet.close(false); } }, opts.cancel || 'Cancel'),
          h('button', { class: 'btn ' + (opts.danger ? 'danger' : 'primary'), onClick: function () { done = true; sheet.close(true); resolve(true); } }, opts.confirm || 'Continue')));
      var sheet = LD.sheet({ title: opts.title, body: body, onClose: function () { if (!done) { done = true; resolve(false); } } });
    });
  };

  // ---- small controls -------------------------------------------------------
  LD.toggle = function (checked, onChange, label) {
    var input = h('input', { type: 'checkbox', checked: !!checked, 'aria-label': label || null, onChange: function () { onChange(input.checked, input); } });
    return h('label', { class: 'switch' }, input, h('span', { class: 'switch-track' }, h('span', { class: 'switch-thumb' })));
  };

  LD.segmented = function (options, value, onChange) {
    var wrap = h('div', { class: 'segmented', role: 'tablist' });
    options.forEach(function (o) {
      var b = h('button', {
        role: 'tab', class: o.value === value ? 'on' : '', 'aria-selected': o.value === value ? 'true' : 'false',
        onClick: function () {
          LD.$$('button', wrap).forEach(function (x) { x.classList.remove('on'); x.setAttribute('aria-selected', 'false'); });
          b.classList.add('on');
          b.setAttribute('aria-selected', 'true');
          onChange(o.value);
        }
      }, o.icon ? LD.icon(o.icon, 16) : null, o.label);
      wrap.appendChild(b);
    });
    return wrap;
  };

  LD.deviceBadge = function (kind, size) {
    return h('span', { class: 'dev-badge', style: { width: (size || 40) + 'px', height: (size || 40) + 'px' } },
      LD.icon(LD.deviceIcon(kind), Math.round((size || 40) * 0.5)));
  };

  LD.skeleton = function (n) {
    var rows = [];
    for (var i = 0; i < n; i++) {
      rows.push(h('div', { class: 'sk-row' }, h('div', { class: 'sk sk-tile' }),
        h('div', { class: 'sk-lines' }, h('div', { class: 'sk sk-line', style: { width: (50 + (i * 17) % 35) + '%' } }), h('div', { class: 'sk sk-line short' }))));
    }
    return h('div', { class: 'skeleton', 'aria-hidden': 'true' }, rows);
  };

  LD.empty = function (icon, title, text, action) {
    return h('div', { class: 'empty' },
      h('div', { class: 'empty-art' }, h('span', { class: 'ring r1' }), h('span', { class: 'ring r2' }), h('span', { class: 'ring r3' }), LD.icon(icon, 30)),
      h('h3', {}, title),
      text ? h('p', {}, text) : null,
      action || null);
  };

  /** Pick a folder to move or copy into. Resolves with the chosen path, or null. */
  LD.pickFolder = function (opts) {
    return new Promise(function (resolve) {
      var path = opts.start || '';
      var done = false;
      var crumbs = h('div', { class: 'crumbs' });
      var list = h('div', { class: 'pick-list' });
      var confirmBtn = h('button', { class: 'btn primary', onClick: function () { done = true; sheet.close(); resolve(path); } }, opts.confirm || 'Choose this folder');
      var body = h('div', { class: 'picker' }, crumbs, list,
        h('div', { class: 'btn-row' },
          h('button', { class: 'btn', onClick: function () { sheet.close(); } }, 'Cancel'), confirmBtn));
      var sheet = LD.sheet({ title: opts.title || 'Choose a folder', body: body, onClose: function () { if (!done) { done = true; resolve(null); } } });
      load();

      function blocked(p) {
        return (opts.exclude || []).some(function (x) { return p === x || p.indexOf(x + '/') === 0; });
      }
      function load() {
        LD.clear(list).appendChild(LD.skeleton(3));
        LD.api.get('/api/files?path=' + encodeURIComponent(path)).then(function (d) {
          renderCrumbs();
          LD.clear(list);
          confirmBtn.disabled = blocked(path) || (opts.disableHere && opts.disableHere(path));
          var dirs = d.entries.filter(function (e) { return e.dir; }).sort(function (a, b) { return a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' }); });
          if (!dirs.length) list.appendChild(h('p', { class: 'pick-empty' }, 'No folders in here.'));
          dirs.forEach(function (e) {
            var dis = blocked(e.path);
            list.appendChild(h('button', { class: 'pick-row', disabled: dis, onClick: function () { path = e.path; load(); } },
              h('span', { class: 'tile k-folder small' }, LD.icon('folder', 18)),
              h('span', { class: 'pick-name' }, e.name),
              LD.icon('chevron-right', 18)));
          });
        }, function (e) { LD.clear(list).appendChild(h('p', { class: 'pick-empty' }, e.message)); });
      }
      function renderCrumbs() {
        LD.clear(crumbs);
        var parts = path ? path.split('/') : [];
        crumbs.appendChild(h('button', { class: 'crumb', onClick: function () { path = ''; load(); } }, LD.icon('drive', 15), 'Shared'));
        var acc = '';
        parts.forEach(function (p) {
          acc = acc ? acc + '/' + p : p;
          var target = acc;
          crumbs.appendChild(LD.icon('chevron-right', 14));
          crumbs.appendChild(h('button', { class: 'crumb', onClick: function () { path = target; load(); } }, p));
        });
      }
    });
  };
})();
