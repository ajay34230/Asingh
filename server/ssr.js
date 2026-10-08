'use strict';
/* Plain server-rendered product HTML so search engines, link previews and slow phones see real content immediately.
   The storefront JavaScript replaces these blocks with the interactive versions. */
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const rs = n => '₹' + Number(n).toLocaleString('en-IN');
function imgTag(cat, p, w, alt) {
  if (p.images.length) { const r = p.images[0], e = p.imageStore[r], pick = e.ws.indexOf(w) > -1 ? w : e.ws[e.ws.length - 1]; return `<img src="${esc(cat.imgUrl(p, r, pick))}" width="1200" height="1500" alt="${esc(alt)}" decoding="async">`; }
  if (p.demo) return `<img src="img/${esc(p.id)}-1-800.jpg" width="1200" height="1500" alt="${esc(alt)}" decoding="async">`;
  return `<img src="img/placeholder.svg" width="1200" height="1500" alt="${esc(alt)}">`;
}
const basePrice = (cat, p) => cat.eff(p).price + cat.stitchAdd(p.stitch.filter(id => cat.stitchOpt(id))[0]);
function card(cat, p) {
  return `<article class="card" data-ssr><div class="card__media"><a class="card__link" href="product.html?id=${esc(p.id)}" tabindex="-1" aria-hidden="true">${imgTag(cat, p, 400, '')}</a>${p.soldOut ? '<span class="badge badge--soldout">Sold out</span>' : ''}</div><div class="card__body"><h3 class="card__title"><a href="product.html?id=${esc(p.id)}">${esc(p.name)}</a></h3><p class="card__meta">${esc(p.fabric)}</p><p class="price"><span class="price__now">${rs(basePrice(cat, p))}</span></p></div></article>`;
}
const grid = (cat, list, n) => list.slice(0, n || 48).map(p => card(cat, p)).join('');
function product(cat, p) {
  const c = cat.categories.find(x => x.id === p.cat);
  return `<div class="pdp__gallery"><ul class="gal"><li class="gal__slide"><span class="gal__zoom">${imgTag(cat, p, 800, p.name)}</span></li></ul></div><div class="pdp__info"><p class="eyebrow">${esc(c ? c.label : '')}</p><h1 class="pdp__title">${esc(p.name)}</h1><div class="pdp__price"><p class="price"><span class="price__now">${rs(basePrice(cat, p))}</span>${cat.eff(p).was ? ` <s class="price__was">${rs(cat.eff(p).was + cat.stitchAdd(p.stitch[0]))}</s>` : ''}</p></div><p class="pdp__blurb">${esc(p.blurb)}</p>${p.details && p.details.length ? '<ul class="bullets">' + p.details.map(d => `<li>${esc(d)}</li>`).join('') + '</ul>' : ''}${p.soldOut ? '<p><strong>Sold out</strong></p>' : ''}</div>`;
}
module.exports = { card, grid, product, basePrice, rs, imgTag };
