/* LocalDrop: "Get the app" sheet. Download the Android app (APK) from this host, or install LocalDrop as a web app (PWA). */
(function () {
  'use strict';
  var LD = window.LD;
  var h = LD.h;
  var S = LD.state;

  var installEvent = null;
  window.addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); installEvent = e; LD.emit('installable'); });
  window.addEventListener('appinstalled', function () { installEvent = null; LD.toast('LocalDrop was installed', 'ok'); });
  if ('serviceWorker' in navigator && window.isSecureContext) {
    window.addEventListener('load', function () { navigator.serviceWorker.register('/sw.js').catch(function () { /* optional */ }); });
  }

  function standalone() {
    return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || window.navigator.standalone === true;
  }

  function webSteps() {
    var ua = navigator.userAgent || '';
    if (/iPhone|iPad|iPod/.test(ua)) return ['Tap the Share button in Safari.', 'Choose "Add to Home Screen".', 'Tap Add. LocalDrop now opens like an app.'];
    if (/Android/.test(ua)) return ['Open the browser menu (three dots).', 'Tap "Install app" or "Add to Home screen".', 'Confirm. LocalDrop now opens like an app.'];
    return ['Look for the install icon at the right end of the address bar.', 'Or open the browser menu and choose "Install LocalDrop" (Chrome, Edge) or "Add to Dock" (Safari).', 'LocalDrop then opens in its own window.'];
  }

  LD.openGetApp = function () {
    var hasApk = !!(S.info && S.info.apk);
    var isAndroid = /Android/i.test(navigator.userAgent || '');
    var body = h('div', { class: 'getapp' });

    body.appendChild(h('section', { class: 'get-card' + (hasApk ? '' : ' off') },
      h('span', { class: 'get-ic' }, LD.icon('apk', 26)),
      h('div', { class: 'get-text' },
        h('b', {}, 'Android app (APK)'),
        h('span', {}, hasApk
          ? (isAndroid ? 'Download it, open the file and allow installs from this source when Android asks. Two phones with the app can find each other automatically.' : 'Download the installer and send it to an Android phone, or open this page on the phone.')
          : 'This host is not an Android phone, so there is no installer here. Open the address of a phone running LocalDrop to get it.')),
      h('button', { class: 'btn primary', disabled: !hasApk, onClick: function () { LD.download('/api/getapp'); LD.toast('Downloading LocalDrop.apk', 'ok'); } }, LD.icon('download', 18), 'Download')));

    var steps = webSteps();
    var pwa = h('section', { class: 'get-card' },
      h('span', { class: 'get-ic web' }, LD.icon('globe', 26)),
      h('div', { class: 'get-text' },
        h('b', {}, 'Web app (PWA)'),
        h('span', {}, standalone() ? 'You are already using the installed web app.' : 'Add LocalDrop to your home screen or desktop. No download, works on iPhone, Android and computers.'),
        standalone() ? null : h('ol', { class: 'get-steps' }, steps.map(function (t) { return h('li', {}, t); }))),
      !standalone() && installEvent ? h('button', { class: 'btn primary', onClick: function () {
        var ev = installEvent; installEvent = null;
        ev.prompt(); if (ev.userChoice) ev.userChoice.then(function () { sheet.close(); });
      } }, LD.icon('plus', 18), 'Install') : null);
    body.appendChild(pwa);
    if (!window.isSecureContext) body.appendChild(h('p', { class: 'field-note' }, 'Some browsers only show the Install button on secure pages. Using "Add to Home screen" from the menu works everywhere.'));
    var sheet = LD.sheet({ title: 'Get the app', body: body });
  };
})();
