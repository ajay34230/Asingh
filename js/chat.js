/* Shopper assistant ("Ask us"). Loaded on first tap. Talks to /api/ai/chat — Gemini when the owner has connected it,
   otherwise free store-policy answers + product search. Never sends names, addresses or payment details. */
(function () {
  'use strict';
  var A = window.ASINGH, U = A.U, esc = U.esc, money = U.money, icon = U.icon;
  var KEY = 'asingh.chat.v1', root, log, input, form, sendBtn, opener, history = [], busy = false;
  var isHi = function () { return /(?:^|;\s*)as_lang=hi/.test(document.cookie); };
  var STARTERS = ['Red lehenga for a wedding', 'Suit under ₹3,000', 'How long is delivery?', 'What is your return policy?'];

  function load() { try { history = JSON.parse(sessionStorage.getItem(KEY) || '[]').slice(-12); } catch (e) { history = []; } }
  function save() { try { sessionStorage.setItem(KEY, JSON.stringify(history.slice(-12))); } catch (e) {} }

  function productCards(list) {
    if (!list || !list.length) return '';
    return '<ul class="chat__prods">' + list.map(function (p) {
      var full = U.byId[p.id];
      return '<li><a class="chat__prod" href="product.html?id=' + encodeURIComponent(p.id) + '"><span class="chat__img">' + (full ? U.picture(p.id, 1, { sizes: '56px', alt: '' }) : '') + '</span><span class="chat__pt"><strong>' + esc(p.name) + '</strong><small>' + money(p.price) + (p.was ? ' <s>' + money(p.was) + '</s>' : '') + '</small></span></a></li>';
    }).join('') + '</ul>';
  }
  function bubble(role, text, prods) {
    var d = document.createElement('div'); d.className = 'chat__m chat__m--' + role;
    var t = document.createElement('p'); t.textContent = text; d.appendChild(t);
    if (prods && prods.length) d.insertAdjacentHTML('beforeend', productCards(prods));
    log.appendChild(d); log.scrollTop = log.scrollHeight; return d;
  }
  function render() {
    log.innerHTML = '';
    if (!history.length) {
      bubble('bot', A.BRAND ? 'Namaste! Ask me about suits, sizes, delivery or returns — I’ll help you find the right piece.' : 'Namaste! How can I help?');
      var c = document.createElement('div'); c.className = 'chat__chips'; c.innerHTML = STARTERS.map(function (s) { return '<button type="button" class="pill" data-q="' + esc(s) + '">' + esc(s) + '</button>'; }).join(''); log.appendChild(c);
    } else history.forEach(function (m) { bubble(m.role === 'assistant' ? 'bot' : 'me', m.content, m.products); });
  }
  function ask(text) {
    text = String(text || '').trim().slice(0, 500); if (!text || busy) return;
    var chips = log.querySelector('.chat__chips'); if (chips) chips.remove();
    history.push({ role: 'user', content: text }); bubble('me', text); input.value = ''; busy = true; sendBtn.disabled = true;
    var wait = bubble('bot', '…'); wait.classList.add('is-wait'); wait.setAttribute('aria-busy', 'true');
    U.api('POST', '/api/ai/chat', { messages: history.map(function (m) { return { role: m.role, content: m.content }; }), lang: isHi() ? 'hi' : 'en' }).then(function (r) {
      wait.remove(); history.push({ role: 'assistant', content: r.reply, products: r.products }); bubble('bot', r.reply, r.products); save();
    }, function (e) {
      wait.remove(); history.pop(); bubble('bot', e.status === 429 ? e.message : 'Sorry, I could not answer just now. Please try again or message us on WhatsApp.');
    }).then(function () { busy = false; sendBtn.disabled = false; input.focus(); });
  }
  function build() {
    root = document.createElement('div'); root.className = 'chat'; root.setAttribute('role', 'dialog'); root.setAttribute('aria-label', 'Shopping assistant'); root.hidden = true;
    root.innerHTML = '<div class="chat__head"><strong>' + icon('spark', 'ico--xs') + ' <span>Ask us</span></strong><button type="button" class="icon-btn" data-chat-close aria-label="Close assistant">' + icon('close') + '</button></div>' +
      '<div class="chat__log" role="log" aria-live="polite" aria-label="Conversation"></div>' +
      '<form class="chat__form" novalidate><label class="vh" for="chat-in">Your question</label><input id="chat-in" class="input" maxlength="500" autocomplete="off" enterkeyhint="send" placeholder="Type your question…"><button class="btn" type="submit"><span>Send</span></button></form>' +
      '<p class="chat__fine">Automated assistant — it can make mistakes. Please don’t share phone numbers or payment details here.</p>';
    document.body.appendChild(root);
    log = root.querySelector('.chat__log'); form = root.querySelector('form'); input = root.querySelector('input'); sendBtn = root.querySelector('[type=submit]');
    form.addEventListener('submit', function (e) { e.preventDefault(); ask(input.value); });
    root.addEventListener('click', function (e) {
      if (e.target.closest('[data-chat-close]')) return close();
      var q = e.target.closest('[data-q]'); if (q) ask(q.getAttribute('data-q'));
    });
    root.addEventListener('keydown', function (e) { if (e.key === 'Escape') { e.stopPropagation(); close(); } });
    load(); render();
  }
  function open(prefill) {
    if (root && !root.hidden) return close();
    opener = document.activeElement; if (!root) build();
    root.hidden = false; var b = document.getElementById('aibtn'); if (b) b.setAttribute('aria-expanded', 'true'); document.documentElement.classList.add('chat-open');
    if (prefill) ask(prefill); else input.focus();
  }
  function close() {
    root.hidden = true; var b = document.getElementById('aibtn'); if (b) b.setAttribute('aria-expanded', 'false'); document.documentElement.classList.remove('chat-open');
    if (opener && opener.focus) opener.focus();
  }
  window.ASINGH_CHAT = { open: open, close: close };
}());
