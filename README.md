# ASINGH — responsive fashion storefront

A dependency-free, device-adaptive ecommerce front end (static HTML/CSS/JS) for handcrafted Indian occasionwear:
home, shop (filters), product, cart/bag drawer, and a 3-step checkout.

Run it: `npx http-server -p 4173` (or any static server) → http://localhost:4173

## How it adapts (not "shrunk desktop")
| Area | Phone | Tablet | Desktop / ultrawide |
|---|---|---|---|
| Header | Logo · search · wishlist · cart · menu (full-screen menu) | + condensed nav, menu becomes side drawer | Full nav + mega menu, account, search pill; content capped at `--max`, hero/story backgrounds stay full-bleed |
| Product grid | Fluid `auto-fill` grid; min card width scales with viewport (`--card-min`) → 2 → 3 → 4 → 5 columns as space allows | | |
| Filters | Bottom sheet (Apply shows live count, Clear all, applied chips) | Left drawer | Sticky sidebar, live apply |
| Product page | Swipe gallery + sticky Add to bag; spec order per brief | Portrait: adaptive stack · Landscape: gallery + info side-by-side | Editorial gallery grid + sticky buy box |
| Cart | Full-screen + sticky checkout bar | Right drawer / page | Right drawer + two-column cart page |
| Checkout | One column, collapsible summary, large inputs, correct keyboards + autocomplete | Centered single column | Details ‖ sticky summary |

Also: `clamp()` fluid type/spacing, `srcset`/`sizes` with AVIF → WebP → JPEG (hero is art-directed: portrait vs wide crop, up to 3840px), lazy loading with a prioritised hero, `<dialog>`-style focus-trapped sheets with Esc/focus return, ≥44px touch targets, hover is only ever an enhancement (Quick add is always visible on touch), `prefers-reduced-motion`, dark mode, forced-colors, safe-area insets, no JS libraries.

## Files
- `index.html shop.html product.html cart.html checkout.html`
- `css/styles.css`, `js/data.js` (catalogue), `js/app.js` (shared chrome, cart, sheets), `js/pages.js` (page logic)
- `img/` generated placeholder fabric imagery — **replace with real photography** (keep the `name-{n}-{400|800|1200}.{avif,webp,jpg}` naming or regenerate via `python3 tools/gen_images.py`)

## QA tooling
`node tools/qa.mjs` — loads every page at 19 widths (280→3840) plus landscape phone/tablet sizes and checks horizontal overflow, header collisions, touch-target size, tiny text and broken images.
`node tools/flows.mjs` — drives menu, search, filters, quick add, PDP validation, cart and the full checkout on phone/tablet/desktop.
(Both expect a server on :4173 and Playwright's Chromium.)

## Known placeholders
Catalogue, reviews, contact details and imagery are sample content. Checkout is a demo — it takes no payment; wire a gateway (UPI/cards/netbanking) and a real account system before launch. Verified in Chromium only; Safari/Firefox/Samsung Internet should be spot-checked on real devices.
