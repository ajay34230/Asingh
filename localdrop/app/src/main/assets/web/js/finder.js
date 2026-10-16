/* LocalDrop finder: when the saved address no longer answers, look for LocalDrop on this network and move there. */
(function () {
  'use strict';
  var m = document.getElementById('m'), b = document.getElementById('b');
  var f = {};
  try { f = JSON.parse(localStorage.getItem('ldfind') || '{}'); } catch (e) { /* none saved */ }
  var COMMON = ['192.168.0', '192.168.1', '192.168.2', '192.168.43', '192.168.49', '192.168.100', '192.168.10', '10.0.0', '10.0.1', '172.20.10'];

  function probe(host) {
    var c = new AbortController(), t = setTimeout(function () { c.abort(); }, 900);
    return fetch('http://' + host + '/api/info', { signal: c.signal, mode: 'cors', cache: 'no-store' })
      .then(function (r) { clearTimeout(t); return r.json(); }).then(function (j) { return j && j.app === 'LocalDrop' ? j : null; }, function () { clearTimeout(t); return null; });
  }

  function targets() {
    var ports = {}, pre = {}, out = [];
    (f.hosts || []).forEach(function (h) {
      var p = h.split(':'); ports[p[1] || '80'] = 1;
      var o = p[0].split('.'); if (o.length === 4) pre[o.slice(0, 3).join('.')] = 1;
      out.push(h);
    });
    ports['8080'] = 1;
    COMMON.forEach(function (c) { pre[c] = 1; });
    Object.keys(pre).forEach(function (p) {
      for (var i = 1; i < 255; i++) Object.keys(ports).forEach(function (pt) { out.push(p + '.' + i + (pt === '80' ? '' : ':' + pt)); });
    });
    return out;
  }

  function go(host, info) {
    var r = info.room, url = 'http://' + host + '/';
    if (r && r.leader && !r.leader.self && r.leader.url) url = r.leader.url;
    m.textContent = 'Found one. Joining…';
    location.replace(url + '#aj=1&n=' + encodeURIComponent(f.n || '') + '&d=' + encodeURIComponent(f.d || ''));
  }

  function search() {
    b.hidden = true; m.textContent = 'Searching this network for a LocalDrop device…';
    var list = targets(), idx = 0, done = false, active = 0;
    function pump() {
      while (!done && active < 40 && idx < list.length) {
        (function (h) {
          active++;
          probe(h).then(function (j) {
            active--;
            if (j && !done) { done = true; try { var x = JSON.parse(localStorage.getItem('ldfind') || '{}'); x.hosts = [h].concat((x.hosts || []).filter(function (y) { return y !== h; })).slice(0, 6); localStorage.setItem('ldfind', JSON.stringify(x)); } catch (e) { /* ignore */ } go(h, j); }
            else pump();
          });
        })(list[idx++]);
      }
      if (!done && active === 0 && idx >= list.length) { m.textContent = 'No LocalDrop device found. Make sure you are on the same Wi-Fi.'; b.hidden = false; }
    }
    pump();
  }
  b.onclick = search;
  window.addEventListener('online', search);
  search();
})();
