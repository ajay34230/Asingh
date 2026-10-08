# ASINGH — girls’ suits & ethnic wear storefront

A fast, dependency-free ecommerce site for **girls’ suits & ethnic wear** (anarkali, lehenga choli, sharara, gharara, kurti sets, patiala, indo-western, gowns and more) with accounts, guest checkout, QR payments with screenshot upload, private orders, live admin alerts and an admin console. Node 20+ only — **no `npm install` needed**.

## Run it
```bash
npm start                      # http://localhost:3000
# first run prints a one-time admin password. Or choose your own:
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a-long-passphrase' npm start
npm test                       # 70+ server/privacy tests
```
Storefront: `/` · Track an order: `/track.html` · Account & orders: `/account.html` · Admin console: `/admin.html`

| Env var | Purpose |
|---|---|
| `PORT`, `HOST` | listen address (default `3000`, `0.0.0.0`) |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | create the admin on first run (otherwise a random password is printed once) |
| `DATA_DIR` | where orders, users and uploaded screenshots live (default `./data`, git-ignored, **back it up**) |
| `COOKIE_SECURE=1` | force `Secure` cookies (auto when `X-Forwarded-Proto: https`) |
| `TRUST_PROXY=1` | trust `X-Forwarded-For` for rate limiting when behind a reverse proxy |
| `SITE_URL` | Your public address, e.g. `https://asingh.onrender.com` (used in sitemap, Google feed, emails) |
| `RESEND_API_KEY` + `MAIL_FROM` | Optional: send order/status/password-reset emails through [Resend](https://resend.com) (free tier). Without them the store works and sends no email |
| `ADMIN_WEBHOOK_URL` | HTTPS webhook (Slack/Discord-style `{text}`) for admin alerts |
| `WEBHOOK_SECRET_<PROVIDER>` | enables payment webhooks for that provider (see below) |

## The admin controls everything (Admin console → `/admin.html`)
| Tab | What the admin can do |
|---|---|
| **Products** | Add, edit, **hide/show**, mark **sold out**, delete. Name, category, price, “was” price, fabric, description, colours, stitching offered, occasions, what’s included, details, badge, photos (up to 6, cropped & resized in the browser so the shop stays light), new/bestseller flags. One click removes all demo products. |
| **Home page** | Show/hide every section (craft words, promise badges, collections, occasions, new arrivals, “made to measure”, bestsellers, reviews); edit hero text, button and **banner photo**; craft words; badges; occasion tiles; the 3-step story; customer reviews (add/remove real ones). |
| **Store settings** | Store name & top-bar message, contact details, shipping rule and fee, **stitching options** (names, prices, on/off), **sizes & size chart**, return/shipping policy text, **categories** (add/rename/remove), and “Going live” tools (remove demo content, delete all test orders). |
| **Orders** | Verify/reject payments, change status (+ courier & tracking link), open the bill, **delete** an order. |
| **Payment & QR** | Upload/replace the QR, UPI ID, payee name, buyer instructions, bill details. |
| **Alerts** | Live toast/chime, browser notifications, Slack/Discord webhook, history. |
| **Admins & login** | See below. |

Everything the admin edits is stored in `DATA_DIR` and appears on the storefront immediately. The home page is rendered by the server from these settings, so there is no flash of old content, and photos are served with long-lived caching.

### Admin username & password
- **First setup:** the first admin is created automatically when the server first starts. Its username is `ADMIN_EMAIL` and its password is `ADMIN_PASSWORD` (environment variables on your host — e.g. Render → Environment, or `/etc/asingh.env` on a VPS). If you set no password, a random one is printed once in the server log. There is no default password and no public “create admin” page, so nobody can claim the admin account by visiting the site first.
- **Changing it:** Admin → **Admins & login** → set your name, **username (email)** and a new password (10+ characters). The current password is required, and other devices are signed out.
- **More admins:** the same page lets an admin **add or remove staff admins**. You can’t remove yourself or the last admin.
- **Admin-only:** every one of these endpoints returns “not found” to customers and 401 to visitors who aren’t signed in. Customers can never become admins — roles are never accepted from the browser.
- Note: `ADMIN_PASSWORD` only matters while no admin exists. If your host wipes its disk on restart (e.g. Render’s free tier) the admin is re-created from the environment variables.

## Order numbers, guest tracking & bills
- **Short order numbers** like `AS-48213` (random, so they don't reveal your order volume). Shown big on the payment and confirmation screens with **Copy / Share / Track** buttons.
- **Guests can track without signing in** at `/track.html` with the **order number + the mobile number used at checkout**. The page shows status, progress, admin messages and courier/tracking ID — never the address, email or payment screenshot. Wrong guesses get one generic message, are rate-limited per IP, and lock that order for 15 minutes after 8 misses. A guest who has verified can tap **“Open full order on this device”** to pay/upload or download the bill.
- **Admin controls the status** (Admin → Orders → open an order → *Order status*): change it forward (or one step back to fix a mistake), add a message the customer sees, and add **courier, tracking ID and tracking link**. Every change appears instantly for the customer; the tracking page also refreshes itself every 30 s.
- **Bill / invoice** (`/invoice.html?id=…`, buyer or admin only): A4 layout with seller details (set in Admin → Payment & QR → *Bill details*, incl. optional GSTIN), buyer and delivery details, **product photos**, itemised prices, totals, PAID / PAYMENT DUE stamp, UTR, courier and progress. **Save as PDF** (opens the browser's print dialog → *Save as PDF*, photos included), **Print**, or **Download text (.txt)**. Available from the order page, the confirmation screen and the admin order view.

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
`node tools/admin-e2e.mjs` — admin console: add a product with a photo, hide/sold-out, home page edits, settings, clear demo, change login, add admin (fresh server).
`node tools/e2e.mjs` — guest checkout → QR upload → live admin alert → verification → privacy (needs a fresh server: `DATA_DIR=/tmp/x ADMIN_PASSWORD='Admin#Pass12345' PORT=4173 node server/index.js`).
`node tools/flows.mjs` — drives menu, search, filters, quick add, PDP validation, cart and the full checkout on phone/tablet/desktop.
(These expect the server on :4173 and Playwright's Chromium.)

## Store features (v8)
**Catalogue:** 17 styles — Anarkali Suit, Lehenga Choli, Sharara Set, Gharara Set, Kurti & Palazzo, Kurti & Skirt, Chaniya Choli, Rajputi Poshak, Ghagra Choli, Angrakha Dress, Peplum Suit, Patiala Suit, Straight Suit, A-Line Dress, Frock / Anarkali Frock, Indo-Western Dress, Ethnic Gown. Admin can rename, add or remove styles (Store settings → Categories).

**Customers:** sign up / sign in / guest, forgot-password (emailed link, or admin-generated link), order tracking, cancel before payment, *request* cancellation after payment, return/exchange requests after delivery (within your return window), verified reviews (shown after you approve), discount codes, change password/email, sign out other devices, download my data, delete my account, unsubscribe.

**Admin:** Overview with go-live checklist, Orders (+CSV export), **Analytics** (revenue, order funnel, top products, live pipeline), Products (photos, stock), Offers (discount codes), Reviews, Customers (reset link, delete), Home page, Pages, Inbox, Store settings (delivery/returns, Google IDs, backup), Payment & QR, Alerts, Admins & login.

**Google:** product/organization/breadcrumb structured data, sitemap + robots, Search Console verification field, Google Merchant Center feed at `/feeds/google-merchant.xml` (real products only), Analytics (GA4) loaded only after the visitor accepts a cookie notice, privacy/returns/shipping policy pages. Before sharing the link, complete the checklist on the admin Overview and review each policy page (they are templates, not legal advice).

## Known placeholders
Catalogue, reviews, contact details and imagery are sample content (replace the drawn illustrations with real photography using the same file names). Verified in Chromium only; spot-check Safari, Firefox and Samsung Internet on real devices.
