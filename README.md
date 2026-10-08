# ASINGH — Rajputi dresses storefront

A fast, dependency-free ecommerce site for **Rajputi dresses** (poshak, ghagra choli, bandhani & leheriya, odhni, suits) with accounts, guest checkout, QR payments with screenshot upload, private orders, live admin alerts and an admin console. Node 20+ only — **no `npm install` needed**.

## Run it
```bash
npm start                      # http://localhost:3000
# first run prints a one-time admin password. Or choose your own:
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a-long-passphrase' npm start
npm test                       # 70+ server/privacy tests
```
Storefront: `/` · Account & orders: `/account.html` · Admin console: `/admin.html`

| Env var | Purpose |
|---|---|
| `PORT`, `HOST` | listen address (default `3000`, `0.0.0.0`) |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | create the admin on first run (otherwise a random password is printed once) |
| `DATA_DIR` | where orders, users and uploaded screenshots live (default `./data`, git-ignored, **back it up**) |
| `COOKIE_SECURE=1` | force `Secure` cookies (auto when `X-Forwarded-Proto: https`) |
| `TRUST_PROXY=1` | trust `X-Forwarded-For` for rate limiting when behind a reverse proxy |
| `ADMIN_WEBHOOK_URL` | HTTPS webhook (Slack/Discord-style `{text}`) for admin alerts |
| `WEBHOOK_SECRET_<PROVIDER>` | enables payment webhooks for that provider (see below) |

## Sign-in options
Sign in · Create account · **Continue as guest (no details at all)**. A guest who later creates an account keeps their orders. Passwords use scrypt; sessions are random 256-bit tokens in `HttpOnly; SameSite=Lax` cookies; login/register are rate-limited.

## Payments (today: UPI QR + screenshot)
1. Buyer enters delivery details → picks **UPI / QR** → the order is created and the **QR, exact amount, UPI ID (copy) and “Open my UPI app” deep link** are shown.
2. Buyer uploads a payment screenshot (compressed in the browser, upload progress, optional UTR). Order moves to *Payment under review*.
3. Admin is alerted instantly, opens the order, sees the screenshot, and **verifies or rejects** (with a note the buyer sees; they can re-upload).
4. Admin moves the order through *Being crafted → Shipped → Delivered*; the buyer tracks it live.

**Admin → Payment & QR** lets you upload/replace your QR, set the payee name, UPI ID and the instructions buyers see. Until you upload one, buyers see a clearly-labelled *Demo QR*.

### Adding a payment gateway later (no storefront changes)
- `server/payments.js`: flip a method to `enabled: true` in `METHODS`; add an entry to `ADAPTERS` that verifies the provider's signature and maps its payload to `{ orderNumber, status: 'paid'|'failed', reference, amount }`.
- Set `WEBHOOK_SECRET_<PROVIDER>` and point the provider at `POST /api/webhooks/<provider>`.
- A verified *paid* event marks the order paid (idempotent, amount-checked) and alerts the admin. A working `generic` adapter (HMAC-SHA256 of the raw body in `X-Signature`) and a Razorpay-style skeleton are included — **verify the skeleton against the provider's current docs before enabling**.

## Admin alerts
New order / screenshot uploaded / payment confirmed / cancelled → **instant toast + bell + chime in the console** (Server-Sent Events), **browser notifications** when the tab is in the background, tab-title badge, a stored alert history, and an optional **HTTPS webhook** (Admin → Alerts, or `ADMIN_WEBHOOK_URL`). Hosts that resolve to private IPs are refused (SSRF guard).

## Privacy & security model
- Orders and screenshots are visible **only to the customer who placed them and the admin**; everyone else gets `404`. Screenshots are stored outside the web root with random names (mode 600), validated by magic bytes (JPG/PNG/WebP only), and served only through an authorised endpoint with `nosniff` and a sandbox CSP.
- Prices are recomputed on the server from the catalogue — client prices are ignored.
- CSRF: every state-changing call needs `X-Requested-With` and a same-origin `Origin`. Strict CSP (no inline scripts), `X-Frame-Options: DENY`, static allow-list (server code, data and tools are never served).
- Limits: JSON 200 KB, uploads 6 MB, per-IP/per-user rate limits.
- **Known limits of this build:** JSON-file storage (single server process; swap `server/db.js` for SQLite/Postgres to scale), no email verification or password-reset email (needs an email provider), no social login. Serve it behind HTTPS.

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
- `img/` demo garment illustrations (poshak, ghagra, suit, odhni — drawn by `tools/gen_images.py`) — **replace with real photography** (keep the `name-{n}-{400|800|1200}.{avif,webp,jpg}` naming or regenerate via `python3 tools/gen_images.py`)

## Motion & performance
- Animation is transform/opacity only, CSS-first: staged hero entrance, scroll reveals (one shared `IntersectionObserver`), self-drawing diamond rule under headings, image fade-ins, card hover zoom, button light-sweep, heart pop, cart-count bump, add-to-bag "fly to cart", staggered menu/mega-menu, cross-page fade (View Transitions) and scroll-linked parallax where supported. Everything switches off under `prefers-reduced-motion`.
- Weight: ~38 KB gzipped of HTML/CSS/JS per page; a phone downloads roughly 70–260 KB of images (AVIF → WebP → JPEG, only the size needed). No fonts, no libraries. `content-visibility:auto` skips off-screen sections, backdrop blur is desktop-only, pages are prefetched on hover/touch. `node tools/weight.mjs` reports it.

## v3 additions
Hero with drifting gold ornaments, shimmering key phrase and pointer parallax (art-directed tall crop leaves clear space for text on phones); looping craft marquee; "Dressed for every occasion" tiles (pure CSS, no image weight); testimonials; cursor spotlight on tiles/cards; colour swatches and skeleton shimmer on product cards; container queries so cards adapt to their own width; header scroll-progress bar; back-to-top; PDP trust row; "Complete the look" on the cart page; confetti on order success. Ambient animations pause when off-screen and all motion respects `prefers-reduced-motion`. QA matrix now also covers 1024×600, Fold (280 / 884×1104), Surface Duo, 2560×1080, 3440×1440 and 5120×1440.

## QA tooling
`node tools/qa.mjs` — loads every page at 19 widths (280→3840) plus landscape phone/tablet sizes and checks horizontal overflow, header collisions, touch-target size, tiny text and broken images.
`node tools/weight.mjs` — page weight at phone / desktop / 4K.
`node tools/e2e.mjs` — guest checkout → QR upload → live admin alert → verification → privacy (needs a fresh server: `DATA_DIR=/tmp/x ADMIN_PASSWORD='Admin#Pass12345' PORT=4173 node server/index.js`).
`node tools/flows.mjs` — drives menu, search, filters, quick add, PDP validation, cart and the full checkout on phone/tablet/desktop.
(These expect the server on :4173 and Playwright's Chromium.)

## Known placeholders
Catalogue, reviews, contact details and imagery are sample content (replace the drawn illustrations with real photography using the same file names). Verified in Chromium only; spot-check Safari, Firefox and Samsung Internet on real devices.
