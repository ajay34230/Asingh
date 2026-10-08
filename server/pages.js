'use strict';
/* Content pages (About, FAQ, Shipping & Returns, Privacy, Terms, Care, Contact…): safe Markdown-lite + default text. */
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const okUrl = u => /^(https?:\/\/|\/|#|mailto:|tel:|[a-z0-9._-]+\.html)/i.test(u) && !/^\s*javascript:/i.test(u);

function inline(t) {
  let s = esc(t);
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (m, a, u) => { u = u.replace(/&amp;/g, '&'); return okUrl(u) ? `<a href="${esc(u)}"${/^https?:/i.test(u) ? ' target="_blank" rel="noopener noreferrer"' : ''}>${a}</a>` : a; });
  return s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/(^|[\s(])\*([^*\n]+)\*(?=[\s).,;:!?]|$)/g, '$1<em>$2</em>');
}
/* Markdown-lite: # / ## / ### headings, paragraphs, - lists, 1. lists, > quotes, ---, **bold**, *italic*, [links](url) */
function render(md, vars) {
  md = String(md || '').replace(/\{\{(\w+)\}\}/g, (m, k) => (vars && vars[k] != null && vars[k] !== '' ? vars[k] : m));
  const out = [], lines = md.replace(/\r/g, '').split('\n'); let i = 0;
  while (i < lines.length) {
    const l = lines[i];
    if (!l.trim()) { i++; continue; }
    let m;
    if ((m = /^(#{1,3})\s+(.*)$/.exec(l))) { const n = m[1].length + 1; out.push(`<h${n}>${inline(m[2])}</h${n}>`); i++; continue; }
    if (/^---+\s*$/.test(l)) { out.push('<hr>'); i++; continue; }
    if (/^\s*[-*]\s+/.test(l)) { const it = []; while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) it.push(`<li>${inline(lines[i++].replace(/^\s*[-*]\s+/, ''))}</li>`); out.push(`<ul>${it.join('')}</ul>`); continue; }
    if (/^\s*\d+[.)]\s+/.test(l)) { const it = []; while (i < lines.length && /^\s*\d+[.)]\s+/.test(lines[i])) it.push(`<li>${inline(lines[i++].replace(/^\s*\d+[.)]\s+/, ''))}</li>`); out.push(`<ol>${it.join('')}</ol>`); continue; }
    if (/^>\s?/.test(l)) { const q = []; while (i < lines.length && /^>\s?/.test(lines[i])) q.push(lines[i++].replace(/^>\s?/, '')); out.push(`<blockquote>${inline(q.join(' '))}</blockquote>`); continue; }
    const p = []; while (i < lines.length && lines[i].trim() && !/^(#{1,3}\s|---+\s*$|\s*[-*]\s+|\s*\d+[.)]\s+|>\s?)/.test(lines[i])) p.push(lines[i++]); out.push(`<p>${inline(p.join(' '))}</p>`);
  }
  return out.join('\n');
}
const plain = (md, n) => String(md || '').replace(/\{\{\w+\}\}/g, '').replace(/[#>*_\-\[\]()`]|\d+\./g, ' ').replace(/\s+/g, ' ').trim().slice(0, n || 160);

const DEFAULT_PAGES = [
  { slug: 'about', title: 'About us', group: 'help', body: `# Our story

{{name}} brings you authentic Rajputi dresses — poshak, ghagra choli, bandhani and leheriya, odhni and Rajputi suits — made the way Rajasthan has always made them.

## Crafted by hand
Every piece is finished with traditional work such as **gota patti**, **zardozi**, **bandhani** and **shisha mirror work**. Nothing is mass-produced: each dress is made for you, in your size.

## Made to your measure
Choose it unstitched, semi-stitched, or fully custom-stitched to your measurements. Our team confirms every detail with you before we begin.

## Our promise
- Honest descriptions and real photographs
- Fair prices, with free shipping above a minimum order
- Friendly help before and after you buy

*Replace this text with your own story in the admin: Pages → About us.*` },
  { slug: 'contact', title: 'Contact us', group: 'help', body: `We’d love to help you choose the right dress, check a measurement, or follow up on an order.

**Email:** {{email}}
**Phone / WhatsApp:** {{phone}}
**Hours:** {{hours}}
**Address:** {{address}}

Already ordered? You can [track your order](track.html) with your order number and mobile number.` },
  { slug: 'faq', title: 'FAQ', group: 'help', body: `## How do I place an order?
Add your dress to the bag, choose your size and stitching, and check out — as a guest (no account needed) or with an account. You’ll pay by scanning our UPI QR and uploading a screenshot of the payment.

## How does payment work?
After you place the order we show our payment QR and the exact amount. Pay with any UPI app, then upload the screenshot. We verify it and confirm your order.

## How do I track my order?
Use the order number we gave you (like AS-48213) together with your mobile number on the [tracking page](track.html). No sign-in is needed.

## What does unstitched, semi-stitched and custom-stitched mean?
**Unstitched** pieces come as fabric to take to your own tailor. **Semi-stitched** pieces are partly made with room to adjust. **Custom-stitched** pieces are made to your measurements by our artisans.

## How long does it take?
Unstitched pieces ship in a few days. Custom-stitched pieces take longer — the timing is shown on each product.

## Can I return or exchange?
Please read our [Shipping & returns](shipping-returns.html) page.

## How do I look after my dress?
See our [Care guide](care-guide.html).` },
  { slug: 'shipping-returns', title: 'Shipping & returns', group: 'legal', body: `## Shipping
- We ship across India. Free shipping above the amount shown in your bag; a small flat fee applies below it.
- Unstitched pieces usually ship within a few days. Semi-stitched and custom-stitched pieces take longer — the estimate is on each product page.
- You’ll see your order status and courier tracking details on the [tracking page](track.html).

## Returns & exchanges
- Unstitched and semi-stitched pieces can be returned within 7 days of delivery if unused, unwashed and in original condition.
- Custom-stitched pieces are made to your measurements and cannot be returned, but we offer one complimentary alteration.
- To start a return, please [contact us](contact.html) with your order number.

## Cancellations
You can cancel an order from your order page until the payment is verified. After that, please contact us.

*These are starting templates — please review and edit them to match your real policy.*` },
  { slug: 'privacy-policy', title: 'Privacy policy', group: 'legal', body: `## What we collect
When you order we collect your name, email, mobile number and delivery address, and the payment screenshot you upload. If you create an account we also store your password securely (we cannot read it). If you subscribe or contact us, we keep your email and message.

## How we use it
Only to process and deliver your order, verify payment, contact you about it, and — if you subscribed — send you updates. We do not sell your data.

## Who can see it
Only you (when signed in or tracking with your order number and mobile number) and our store team. Payment screenshots are stored privately.

## Cookies
We use one essential cookie to keep you signed in or remember your guest session. We do not use advertising cookies.

## Your choices
You can ask us to delete your data, or delete your account from your account page. Write to {{email}}.

*This is a starting template, not legal advice — please review it with a professional before launch.*` },
  { slug: 'terms', title: 'Terms & conditions', group: 'legal', body: `## Orders
Placing an order is an offer to buy. We confirm it once payment is verified. We may cancel an order if an item is unavailable or payment cannot be verified, and will refund any amount paid.

## Prices
Prices are in Indian rupees and include applicable taxes unless stated otherwise. We may change prices at any time; the price at checkout applies.

## Product colours
We photograph our dresses carefully, but colours may vary slightly by screen and lighting. Handwork means small variations are normal.

## Custom-stitched orders
Custom-stitched pieces are made to the measurements you give. Please check your size details before ordering.

## Contact
Questions? Write to {{email}}.

*This is a starting template, not legal advice — please review it with a professional before launch.*` },
  { slug: 'care-guide', title: 'Care guide', group: 'help', body: `## Looking after your dress
- **Dry clean only** for embroidered, gota patti and zardozi pieces.
- Store folded in a **cotton or muslin cloth**, away from direct sunlight and damp.
- Avoid perfume or spray directly on the fabric or the zari.
- Refold every few months along different lines to avoid permanent creases.

## Bandhani and leheriya
Air out after wearing. Wash separately (hand-wash cold) if the label allows; the dyes may bleed in the first wash.

## Zari and gota patti
Keep away from moisture to prevent tarnishing. Never iron directly on zari — use a cloth between the iron and the work.` }
];
module.exports = { render, plain, DEFAULT_PAGES, esc };
