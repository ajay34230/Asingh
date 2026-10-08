# चंद्रवंशी · By Tanwar Baisa — project report

Girls' suits & ethnic wear store: fast, no-dependency Node server + vanilla JS storefront + admin console.
Branch: `claude/extreme-responsive-design-t9g7mk`.

## Delivered (all 15 tasks)
| # | Task | Result |
|---|------|--------|
| 1 | Audit | Crawler (`tools/audit.mjs`): broken links, console errors, a11y, SEO — all findings fixed |
| 2 | Content pages, contact form, newsletter | About, Contact, FAQ, Shipping & returns, Privacy, Terms, Care guide (English + Hindi); contact form → admin Inbox; newsletter → admin Subscribers (+CSV) |
| 3 | SEO, social, PWA | Canonical/OG/Twitter tags, JSON-LD (Product, Organization, Breadcrumb), sitemap, robots, manifest, icons from the brand logo, branded 404, server-rendered product/shop/home content |
| 4 | Commerce | Discount codes (admin-managed), stock counts (down on order, back on cancel), shop "Show more", recently viewed |
| 5 | Email, password reset, customers | Order/status emails via Resend (optional), forgot-password, admin reset link, admin Customers list/delete |
| 6 | Reviews, returns | Verified-buyer reviews with moderation; cancellation / return / exchange requests with admin approve/decline |
| 7 | Admin analytics, exports, backup, slips | Analytics page, orders CSV, full backup, packing slip, bills (PDF/text) |
| 8 | Final QA | See below |
| 9 | Customer self-service | Cancel, request cancel, change password/email, sign out other devices, download data, delete account, unsubscribe |
| 10 | Google compliance | Merchant feed, Search Console field, GA4 only after cookie consent, policy pages, go-live checklist |
| 11 | Catalogue pivot | 17 styles, 17 demo products with images |
| 12 | Themes | Royal + Bloom, with switcher |
| 13–15 | Phases | Responsive + accessibility reruns; shop paging + recently viewed; packing slip |
Also: Hindi/English switch (+ admin Hindi editor), brand logo shown whole, order prefix CV-.

## Quality evidence
- Server tests: ~190 checks pass (`node server/test.mjs`).
- Browser suites pass: `tools/e2e.mjs`, `admin-e2e.mjs`, `flows.mjs`, `self-e2e.mjs`.
- Responsive matrix (`tools/qa.mjs`, 320–5120px, phone/tablet/desktop, portrait/landscape): Royal-English clean; fixes applied for the last small tap targets seen in Hindi/Bloom runs.
- Accessibility (`tools/a11y.mjs`): 0 findings for Royal and Bloom in English and Hindi (contrast AA, labels, alt, headings, focus rings).
- Security: all 51 admin routes refuse anonymous and customer callers; CSP `script-src 'self'`; HttpOnly SameSite cookies; CSRF header + origin check; scrypt passwords; rate limits on login/track/coupon/review; CSV formula-injection guard; SSRF guard on webhooks; stored-XSS probe through name/message/order note renders as text in admin and customer views.
- Weight: ~68 KB gzipped HTML/CSS/JS per page; images 140 KB–1.1 MB depending on page.

## Not done / needs the owner
Real products, photos, payment QR/UPI, contact details; legal review of policy pages; a host with a persistent disk; optional Resend + Google IDs; refund tracking and shipping labels; admin console in Hindi.
