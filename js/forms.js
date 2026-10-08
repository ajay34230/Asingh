/* Contact page form (progressive enhancement of the server-rendered page). */
(function () {
  'use strict';
  var f = document.getElementById('contact-form'); if (!f) return;
  var err = document.getElementById('c-err'), ok = document.getElementById('c-ok'), btn = f.querySelector('button[type=submit]');
  f.addEventListener('submit', function (e) {
    e.preventDefault(); err.textContent = ''; ok.textContent = '';
    var d = {}; new FormData(f).forEach(function (v, k) { d[k] = v; });
    if (!d.name || d.name.trim().length < 2) { err.textContent = 'Please enter your name.'; f.elements.name.focus(); return; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(d.email || '')) { err.textContent = 'Please enter a valid email so we can reply.'; f.elements.email.focus(); return; }
    if (!d.message || d.message.trim().length < 5) { err.textContent = 'Please write your message.'; f.elements.message.focus(); return; }
    btn.disabled = true; btn.classList.add('is-busy');
    fetch('/api/contact', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'asingh' }, body: JSON.stringify(d) })
      .then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { if (!r.ok) throw new Error(j.error || 'Something went wrong'); }); })
      .then(function () { f.reset(); ok.textContent = 'Thank you — your message has been sent. We’ll reply by email soon.'; ok.focus && ok.setAttribute('tabindex', '-1'); }, function (er) { err.textContent = er.message; })
      .then(function () { btn.disabled = false; btn.classList.remove('is-busy'); });
  });
})();
