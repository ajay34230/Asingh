'use strict';
/* Server-rendered home page blocks, so the admin's text, section visibility and hero photo are right on first paint (no flash of demo content). */
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = n => '₹' + Number(n).toLocaleString('en-IN');
const svg = p => `<svg class="ico" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`;
const TRUST_ICONS = [svg('<circle cx="6.5" cy="6.5" r="2.5"/><circle cx="6.5" cy="17.5" r="2.5"/><path d="m8.5 8 11 9M8.5 16l11-9"/>'), svg('<path d="M3 6h11v10H3zM14 10h4l3 3v3h-7"/><circle cx="7.5" cy="17.5" r="1.7"/><circle cx="17.5" cy="17.5" r="1.7"/>'), svg('<path d="M4 12a8 8 0 1 0 2.6-5.9L4 8.5"/><path d="M4 4v4.5h4.5"/>'), svg('<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>')];
const set = (cat, name, w) => w.map(x => `${name(x)} ${x}w`).join(', ');

function hero(cat) {
  const t = cat.site, h = t.heroImage, title = esc(t.heroTitle).replace(/\*([^*]+)\*/, '<em class="shine">$1</em>');
  const orns = [1, 2, 3, 4, 5, 6, 7].map(i => `<span class="orn orn--${i}" aria-hidden="true"></span>`).join('');
  const T = 'media="(max-width: 699.98px), (orientation: portrait)"';
  let picture, preload;
  if (h) {
    const u = (k, w) => `/media/s/${h.rev}-${k}-${w}.${h.ext}`, tall = set(cat, w => u('tall', w), h.tall), wide = set(cat, w => u('wide', w), h.wide);
    picture = `<picture class="hero__img"><source ${T} srcset="${tall}" sizes="100vw"><img src="${u('wide', 1920)}" srcset="${wide}" sizes="100vw" alt="" width="1920" height="960" fetchpriority="high" decoding="async"></picture>`;
    preload = `<link rel="preload" as="image" ${T} imagesrcset="${tall}" imagesizes="100vw" fetchpriority="high">\n<link rel="preload" as="image" media="(min-width: 700px) and (orientation: landscape)" imagesrcset="${wide}" imagesizes="100vw" fetchpriority="high">`;
  } else {
    const f = (n, ws, ext) => ws.map(w => `img/${n}-${w}.${ext} ${w}w`).join(', ');
    picture = `<picture class="hero__img"><source ${T} type="image/avif" srcset="${f('hero-tall', [480, 800, 1080], 'avif')}" sizes="100vw"><source ${T} type="image/webp" srcset="${f('hero-tall', [480, 800, 1080], 'webp')}" sizes="100vw"><source type="image/avif" srcset="${f('hero-wide', [1280, 1920, 2560, 3840], 'avif')}" sizes="100vw"><source type="image/webp" srcset="${f('hero-wide', [1280, 1920, 2560, 3840], 'webp')}" sizes="100vw"><img src="img/hero-wide-1920.jpg" alt="" width="1920" height="960" fetchpriority="high" decoding="async"></picture>`;
    preload = `<link rel="preload" as="image" type="image/avif" ${T} imagesrcset="${f('hero-tall', [480, 800, 1080], 'avif')}" imagesizes="100vw" fetchpriority="high">\n<link rel="preload" as="image" type="image/avif" media="(min-width: 700px) and (orientation: landscape)" imagesrcset="${f('hero-wide', [1280, 1920, 2560, 3840], 'avif')}" imagesizes="100vw" fetchpriority="high">`;
  }
  const html = `<section class="hero" aria-labelledby="hero-h" data-anim>${orns}${picture}<div class="container hero__in"><div class="hero__copy">${t.heroEyebrow ? `<p class="eyebrow eyebrow--light">${esc(t.heroEyebrow)}</p>` : ''}<h1 id="hero-h" class="hero__title">${title}</h1>${t.heroLead ? `<p class="hero__lead">${esc(t.heroLead)}</p>` : ''}<div class="hero__cta"><a class="btn btn--gold btn--lg" href="shop.html">${esc(t.heroCta || 'Shop now')}</a><a class="btn btn--outline-light btn--lg" href="shop.html?stitch=custom">Custom stitching</a></div></div></div></section>`;
  return { html, preload };
}
const marquee = cat => { const w = cat.site.marquee; if (!cat.site.sections.marquee || !w.length) return ''; const set1 = w.map(x => `<span>${esc(x)}</span>`).join(' '), reps = Math.max(2, Math.ceil(24 / w.length) * 2); return `<div class="marquee" data-anim aria-hidden="true"><div class="marquee__track">${Array(reps).fill(set1).join(' ')}</div></div>`; };
const trust = cat => { const t = cat.site; if (!t.sections.trust || !t.trust.length) return ''; return `<section class="trust" aria-label="Our promises"><ul class="container trust__list">${t.trust.map((x, i) => `<li>${TRUST_ICONS[i % 4]}<span><strong>${esc(x.title)}</strong><small>${esc(x.sub || (/shipping/i.test(x.title) ? (t.shipFreeFrom ? 'On orders over ' + money(t.shipFreeFrom) : 'On every order') : ''))}</small></span></li>`).join('')}</ul></section>`; };
const occasions = cat => { const t = cat.site; if (!t.sections.occasions || !t.occasions.length) return ''; return `<section class="section container" aria-labelledby="occ-h"><div class="section__head"><h2 id="occ-h" class="h2">Dressed for every occasion</h2></div><ul class="occs">${t.occasions.map((o, i) => `<li><a class="occ occ--${i % 4 + 1}" href="shop.html?occ=${esc(o.id)}"><span class="occ__k">${String(i + 1).padStart(2, '0')}</span><span class="occ__t">${esc(o.label)}</span>${o.sub ? `<span class="occ__s">${esc(o.sub)}</span>` : ''}</a></li>`).join('')}</ul></section>`; };
const story = cat => { const t = cat.site.story; if (!cat.site.sections.story || !t.steps.length) return ''; return `<section class="story" aria-labelledby="story-h"><picture class="story__img" aria-hidden="true"><source type="image/avif" srcset="img/hero-wide-1280.avif 1280w, img/hero-wide-1920.avif 1920w, img/hero-wide-2560.avif 2560w" sizes="100vw"><source type="image/webp" srcset="img/hero-wide-1280.webp 1280w, img/hero-wide-1920.webp 1920w, img/hero-wide-2560.webp 2560w" sizes="100vw"><img src="img/hero-wide-1920.jpg" alt="" width="1280" height="640" loading="lazy" decoding="async"></picture><div class="container story__in"><div class="story__head" data-reveal>${t.eyebrow ? `<p class="eyebrow eyebrow--light">${esc(t.eyebrow)}</p>` : ''}<h2 id="story-h" class="h1">${esc(t.title)}</h2></div><ol class="steps">${t.steps.map((s, i) => `<li class="step" data-reveal><span class="step__n">${String(i + 1).padStart(2, '0')}</span><h3>${esc(s.title)}</h3><p>${esc(s.text)}</p></li>`).join('')}</ol>${t.cta ? `<a class="btn btn--gold btn--lg story__cta" href="shop.html?stitch=custom">${esc(t.cta)}</a>` : ''}</div></section>`; };

function renderIndex(html, cat) {
  const t = cat.site, h = hero(cat), off = [['collections', 'collections'], ['newArrivals', 'newArrivals'], ['bestsellers', 'bestsellers'], ['testimonials', 'testimonials']].filter(x => !t.sections[x[0]]).map(x => `[data-sec="${x[1]}"]{display:none!important}`).join('');
  return html.replace('<!--@title-->', esc(t.name) + ' — ' + esc(t.heroEyebrow || 'Rajputi dresses')).replace('<!--@head-->', h.preload + (off ? `\n<style>${off}</style>` : ''))
    .replace('<!--@hero-->', h.html).replace('<!--@marquee-->', marquee(cat)).replace('<!--@trust-->', trust(cat)).replace('<!--@occasions-->', occasions(cat)).replace('<!--@story-->', story(cat));
}
module.exports = { renderIndex };
