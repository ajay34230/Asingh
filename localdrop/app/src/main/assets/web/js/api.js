/* LocalDrop: talking to the server (requests, uploads, live events) and the shared app state. */
(function () {
  'use strict';
  var LD = window.LD;

  function ApiError(status, message) {
    this.name = 'ApiError';
    this.status = status;
    this.message = message;
  }
  ApiError.prototype = Object.create(Error.prototype);
  LD.ApiError = ApiError;

  LD.state = {
    info: null,
    you: null,
    perms: { upload: true, modify: true, links: true },
    isHost: false,
    devices: [],
    activity: [],
    messages: [],
    unread: 0,
    online: true,
    tab: 'files',
    path: ''
  };

  function request(method, url, body, opts) {
    opts = opts || {};
    var headers = { 'X-Requested-With': 'LocalDrop' };
    var payload;
    if (body !== undefined) {
      headers['Content-Type'] = 'application/json';
      payload = JSON.stringify(body);
    }
    return fetch(url, {
      method: method,
      headers: headers,
      body: payload,
      credentials: 'same-origin',
      cache: 'no-store',
      signal: opts.signal
    }).then(function (res) {
      var ct = res.headers.get('content-type') || '';
      var parse = ct.indexOf('json') >= 0 ? res.json().catch(function () { return null; }) : Promise.resolve(null);
      return parse.then(function (data) {
        if (res.status === 401 && !opts.quiet) LD.emit('unauthorized');
        if (!res.ok) throw new ApiError(res.status, (data && data.error) || res.statusText || 'Something went wrong.');
        return data;
      });
    }, function (e) {
      if (e && e.name === 'AbortError') throw e;
      throw new ApiError(0, "Can't reach the other device. Check that you're on the same Wi-Fi.");
    });
  }

  LD.api = {
    get: function (url, o) { return request('GET', url, undefined, o); },
    post: function (url, body, o) { return request('POST', url, body === undefined ? {} : body, o); },
    put: function (url, body, o) { return request('PUT', url, body === undefined ? {} : body, o); }
  };

  /** Uploads one file, reporting progress. Resolves with {name, path, size}. */
  LD.upload = function (file, o) {
    return new Promise(function (resolve, reject) {
      var xhr = new XMLHttpRequest();
      var q = new URLSearchParams();
      q.set('path', o.path || '');
      q.set('name', file.name);
      if (o.rel) q.set('rel', o.rel);
      if (file.lastModified) q.set('mtime', String(file.lastModified));
      if (o.conflict) q.set('conflict', o.conflict);
      if (o.quiet) q.set('quiet', '1');
      xhr.open('PUT', '/api/upload?' + q.toString());
      xhr.setRequestHeader('X-Requested-With', 'LocalDrop');
      xhr.upload.onprogress = function (e) {
        if (e.lengthComputable && o.onProgress) o.onProgress(e.loaded, e.total);
      };
      xhr.onload = function () {
        var d = null;
        try { d = JSON.parse(xhr.responseText); } catch (e) { /* not JSON */ }
        if (xhr.status >= 200 && xhr.status < 300) resolve(d);
        else {
          if (xhr.status === 401) LD.emit('unauthorized');
          reject(new ApiError(xhr.status, (d && d.error) || 'The upload failed.'));
        }
      };
      xhr.onerror = function () { reject(new ApiError(0, 'The connection dropped. Check your Wi-Fi and try again.')); };
      xhr.onabort = function () { reject(new DOMException('Aborted', 'AbortError')); };
      xhr.ontimeout = xhr.onerror;
      if (o.signal) {
        if (o.signal.aborted) { reject(new DOMException('Aborted', 'AbortError')); return; }
        o.signal.addEventListener('abort', function () { xhr.abort(); });
      }
      xhr.send(file);
    });
  };

  LD.fileUrl = function (path, download) {
    return '/api/file?path=' + encodeURIComponent(path) + (download ? '&dl=1' : '');
  };
  LD.thumbUrl = function (path, w) {
    return '/api/thumb?path=' + encodeURIComponent(path) + '&w=' + (w || 320);
  };
  LD.zipUrl = function (paths, name) {
    return '/api/zip?' + paths.map(function (p) { return 'path=' + encodeURIComponent(p); }).join('&') +
      (name ? '&name=' + encodeURIComponent(name) : '');
  };

  /** Starts a browser download for a URL. */
  LD.download = function (url) {
    var a = document.createElement('a');
    a.href = url;
    a.rel = 'noopener';
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    setTimeout(function () { document.body.removeChild(a); }, 1000);
  };

  // ---- live events ----------------------------------------------------------
  var es = null;
  var lastOpen = 0;

  LD.connectEvents = function () {
    if (es) { es.close(); es = null; }
    es = new EventSource('/api/events');
    var st = LD.state;

    es.addEventListener('open', function () {
      lastOpen = Date.now();
      if (!st.online) { st.online = true; LD.emit('online', true); }
    });
    es.addEventListener('hello', function (e) {
      var d = JSON.parse(e.data);
      st.devices = d.devices;
      st.activity = d.activity || [];
      if (d.perms) st.perms = d.perms;
      LD.emit('devices', st.devices);
      LD.emit('activity', st.activity);
      LD.emit('perms', st.perms);
      LD.emit('reconnected');
    });
    es.addEventListener('devices', function (e) {
      var old = st.devices;
      st.devices = JSON.parse(e.data);
      LD.emit('devices', st.devices);
      // Announce newcomers (but not on the first load).
      st.devices.forEach(function (d) {
        if (d.host || !d.online) return;
        var was = old.filter(function (o) { return o.id === d.id; })[0];
        if (!was || !was.online) LD.emit('arrived', d);
      });
    });
    es.addEventListener('activity', function (e) {
      var a = JSON.parse(e.data);
      st.activity.push(a);
      if (st.activity.length > 100) st.activity.shift();
      LD.emit('activity', st.activity);
    });
    es.addEventListener('files', function (e) {
      LD.emit('files-changed', JSON.parse(e.data));
    });
    es.addEventListener('message', function (e) {
      var m = JSON.parse(e.data);
      if (st.messages.some(function (x) { return x.id === m.id; })) return;
      st.messages.push(m);
      var mine = st.you && m.from && m.from.id === st.you.id;
      if (!mine && st.tab !== 'drop') st.unread++;
      LD.emit('message', m);
    });
    es.addEventListener('message-delete', function (e) {
      var id = JSON.parse(e.data).id;
      st.messages = st.messages.filter(function (m) { return m.id !== id; });
      LD.emit('messages-changed');
    });
    es.addEventListener('messages-cleared', function () {
      st.messages = [];
      LD.emit('messages-changed');
    });
    es.addEventListener('settings', function (e) {
      var d = JSON.parse(e.data);
      if (d.perms) { st.perms = d.perms; LD.emit('perms', st.perms); }
      LD.emit('settings-changed', d);
    });
    es.addEventListener('kicked', function () {
      es.close();
      LD.emit('kicked');
    });
    es.onerror = function () {
      if (st.online) { st.online = false; LD.emit('online', false); }
      // A closed stream means the server refused us (signed out, wrong PIN changed): check why.
      if (es && es.readyState === 2) {
        LD.api.get('/api/info', { quiet: true }).then(function (i) {
          if (!i.authed) LD.emit('unauthorized');
        }, function () { /* offline: the browser keeps retrying */ });
      }
    };
  };

  LD.loadMessages = function () {
    return LD.api.get('/api/messages?limit=300').then(function (list) {
      LD.state.messages = list;
      LD.emit('messages-changed');
    });
  };
})();
