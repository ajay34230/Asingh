/* Catalogue data. Replace with your real catalogue / API. */
window.ASINGH = window.ASINGH || {};
(function (A) {
  A.BRAND = 'ASINGH';
  A.FREE_SHIP_FROM = 15000;
  A.SHIP_FLAT = 250;
  A.STITCH = [
    { id: 'unstitched', label: 'Unstitched', note: 'Fabric as a set of pieces — stitch with your tailor', add: 0, eta: 'Ships in 2–3 days' },
    { id: 'semi', label: 'Semi-stitched', note: 'Pre-shaped with room to adjust at your tailor', add: 600, eta: 'Ships in 4–6 days' },
    { id: 'custom', label: 'Custom-stitched', note: 'Made to your measurements by our artisans', add: 1800, eta: 'Ships in 10–14 days' }
  ];
  A.SIZES = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  A.CATEGORIES = [
    { id: 'lehengas', label: 'Lehengas' },
    { id: 'anarkalis', label: 'Anarkalis' },
    { id: 'sarees', label: 'Sarees' },
    { id: 'suits', label: 'Suits & Kurtas' },
    { id: 'gowns', label: 'Gowns' },
    { id: 'dupattas', label: 'Dupattas' }
  ];
  A.OCCASIONS = [
    { id: 'wedding', label: 'Wedding' },
    { id: 'festive', label: 'Festive' },
    { id: 'party', label: 'Party' },
    { id: 'everyday', label: 'Everyday' }
  ];
  A.PRICE_BANDS = [
    { id: 'u10', label: 'Under ₹10,000', min: 0, max: 10000 },
    { id: '10-20', label: '₹10,000 – ₹20,000', min: 10000, max: 20000 },
    { id: '20-30', label: '₹20,000 – ₹30,000', min: 20000, max: 30000 },
    { id: 'o30', label: 'Over ₹30,000', min: 30000, max: Infinity }
  ];
  var c = function (name, hex) { return { name: name, hex: hex }; };
  var inc = {
    lehenga: ['Embroidered lehenga skirt (3 m flare)', 'Blouse fabric (0.9 m)', 'Net dupatta with scalloped border', 'Can-can & drawstring'],
    anarkali: ['Anarkali kurta (3.5 m flare)', 'Churidar bottom (2.5 m)', 'Dupatta (2.2 m)'],
    saree: ['Saree (5.5 m)', 'Unstitched blouse piece (0.8 m)', 'Fall & pico finishing on request'],
    suit: ['Kurta (2.5 m)', 'Bottom (2.5 m)', 'Dupatta (2.2 m)'],
    gown: ['Gown with attached can-can', 'Dupatta (2.5 m)', 'Matching belt'],
    dupatta: ['Dupatta (2.5 m)', 'Hand-finished edges']
  };
  var base = 'Hand-finished with zari detailing. Dry clean only. Colours may vary slightly by screen. Made in India.';
  A.PRODUCTS = [
    { id: 'noor-lehenga', name: 'Noor Embroidered Bridal Lehenga', cat: 'lehengas', occ: ['wedding'], fabric: 'Raw silk with zari', price: 38900, was: 46500, badge: 'Bestseller', best: true, isNew: false, rating: 4.9, reviews: 128, colors: [c('Mulberry', '#7a1f3d'), c('Emerald', '#14463c'), c('Midnight', '#2c3a6b')], inc: inc.lehenga, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A statement bridal lehenga in raw silk, scattered with hand-embroidered zari blossoms and a scalloped hem.', details: ['Raw silk with zari thread embroidery', 'Net dupatta, hand-finished scallops', 'Fully lined, can-can attached', 'Care: dry clean only', base] },
    { id: 'zarina-anarkali', name: 'Zarina Paisley Anarkali Set', cat: 'anarkalis', occ: ['festive', 'wedding'], fabric: 'Chanderi silk', price: 17400, was: null, badge: 'New', best: true, isNew: true, rating: 4.8, reviews: 76, colors: [c('Forest', '#14463c'), c('Wine', '#7a1f3d')], inc: inc.anarkali, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A floor-grazing Chanderi anarkali with tonal paisley motifs and a soft, fluid fall.', details: ['Chanderi silk with woven paisley', 'Churidar & dupatta included', 'Lined in cotton silk', base] },
    { id: 'mehr-saree', name: 'Mehr Striped Banarasi Saree', cat: 'sarees', occ: ['festive', 'party'], fabric: 'Banarasi silk', price: 21800, was: 24900, badge: 'Sale', best: true, isNew: false, rating: 4.7, reviews: 211, colors: [c('Terracotta', '#b5532f'), c('Teal', '#1d5b6b')], inc: inc.saree, stitch: ['unstitched', 'semi'], blurb: 'Handwoven Banarasi silk in a rust tone, finished with fine gold zari stripes along the length.', details: ['Handwoven Banarasi silk', 'Fine gold zari stripes', 'Blouse piece included', base] },
    { id: 'ishani-suit', name: 'Ishani Buti Straight Suit', cat: 'suits', occ: ['everyday', 'festive'], fabric: 'Cotton silk', price: 8900, was: null, badge: 'New', best: false, isNew: true, rating: 4.6, reviews: 54, colors: [c('Indigo', '#2c3a6b'), c('Sand', '#e8d9c0')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A refined straight-cut suit in cotton silk with subtle buti work — comfortable enough for long days.', details: ['Cotton silk with woven buti', 'Breathable and light', 'Dupatta with tassel detail', base] },
    { id: 'rani-sharara', name: 'Rani Floral Sharara Set', cat: 'suits', occ: ['festive', 'wedding'], fabric: 'Georgette', price: 15600, was: 18200, badge: 'Sale', best: true, isNew: false, rating: 4.8, reviews: 93, colors: [c('Rani Pink', '#c23a6e'), c('Mulberry', '#7a1f3d')], inc: ['Short kurta', 'Flared sharara (4 m)', 'Dupatta (2.2 m)'], stitch: ['unstitched', 'semi', 'custom'], blurb: 'Festive georgette sharara in rani pink, with gold floral embroidery throughout.', details: ['Georgette with floral zari', 'Wide-flare sharara', 'Dupatta with border', base] },
    { id: 'saanvi-kurta', name: 'Saanvi Block-Print Kurta', cat: 'suits', occ: ['everyday'], fabric: 'Organic cotton', price: 5400, was: null, badge: '', best: false, isNew: true, rating: 4.5, reviews: 38, colors: [c('Ivory', '#e8d9c0'), c('Rust', '#b5532f')], inc: ['Kurta (2.5 m)', 'Matching pants (2.2 m)'], stitch: ['unstitched', 'semi', 'custom'], blurb: 'Everyday block-printed kurta in breathable organic cotton.', details: ['Organic cotton', 'Hand block print', 'Machine washable on gentle', base] },
    { id: 'aarohi-gown', name: 'Aarohi Indo-Western Gown', cat: 'gowns', occ: ['party', 'wedding'], fabric: 'Velvet & net', price: 27400, was: null, badge: 'Limited', best: false, isNew: true, rating: 4.9, reviews: 29, colors: [c('Plum', '#3d2a55'), c('Wine', '#7a1f3d')], inc: inc.gown, stitch: ['semi', 'custom'], blurb: 'A velvet-bodice gown with a sweeping net skirt and antique-gold paisley work.', details: ['Velvet and net', 'Attached can-can', 'Concealed side zip', base] },
    { id: 'meera-saree', name: 'Meera Kanjivaram Silk Saree', cat: 'sarees', occ: ['wedding', 'festive'], fabric: 'Kanjivaram silk', price: 32500, was: null, badge: '', best: true, isNew: false, rating: 4.9, reviews: 167, colors: [c('Peacock', '#1d5b6b'), c('Terracotta', '#b5532f')], inc: inc.saree, stitch: ['unstitched', 'semi'], blurb: 'Pure Kanjivaram silk in peacock teal with a gold zari border. An heirloom drape.', details: ['Pure Kanjivaram silk', 'Gold zari border', 'Silk Mark certified', base] },
    { id: 'kiara-lehenga', name: 'Kiara Pastel Festive Lehenga', cat: 'lehengas', occ: ['festive', 'party'], fabric: 'Organza', price: 24800, was: 28900, badge: 'Sale', best: false, isNew: false, rating: 4.7, reviews: 61, colors: [c('Blush', '#d98b8b'), c('Sage', '#9aab8a')], inc: inc.lehenga, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A light-as-air organza lehenga in blush with delicate floral embroidery.', details: ['Organza with floral thread work', 'Soft net lining', 'Dupatta included', base] },
    { id: 'tara-palazzo', name: 'Tara Gold Palazzo Set', cat: 'suits', occ: ['party', 'everyday'], fabric: 'Crepe silk', price: 11200, was: null, badge: '', best: false, isNew: false, rating: 4.6, reviews: 47, colors: [c('Antique Gold', '#a7752e'), c('Black', '#241c18')], inc: ['Short kurta', 'Palazzo (2.5 m)', 'Dupatta (2.2 m)'], stitch: ['unstitched', 'semi', 'custom'], blurb: 'A modern palazzo set in crepe silk with antique-gold buti.', details: ['Crepe silk', 'Wide-leg palazzo', 'Dupatta with gold border', base] },
    { id: 'devika-anarkali', name: 'Devika Olive Anarkali', cat: 'anarkalis', occ: ['festive', 'everyday'], fabric: 'Muslin silk', price: 13600, was: null, badge: '', best: false, isNew: true, rating: 4.7, reviews: 33, colors: [c('Olive', '#4f5d3a'), c('Ink', '#2c3a6b')], inc: inc.anarkali, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A graceful olive anarkali in muslin silk with paisley zari work.', details: ['Muslin silk', 'Zari paisley', 'Churidar & dupatta included', base] },
    { id: 'vanya-dupatta', name: 'Vanya Striped Zari Dupatta', cat: 'dupattas', occ: ['festive', 'everyday'], fabric: 'Tissue silk', price: 3900, was: null, badge: '', best: false, isNew: false, rating: 4.4, reviews: 22, colors: [c('Crimson', '#8f2a2a'), c('Ivory', '#e8d9c0')], inc: inc.dupatta, stitch: ['unstitched'], blurb: 'A luminous tissue-silk dupatta with gold zari stripes to lift any outfit.', details: ['Tissue silk', 'Hand-finished edges', base] }
  ];
  A.REVIEWS = [
    { who: 'Priya S.', city: 'Mumbai', stars: 5, title: 'Better than the photos', body: 'The fabric has real weight and the embroidery is beautifully finished. Custom stitching fit perfectly on the first try.' },
    { who: 'Anjali K.', city: 'Delhi', stars: 5, title: 'Wore it to my sister’s wedding', body: 'So many compliments. The colour is rich and true to the listing. Delivery was a day early.' },
    { who: 'Meenal R.', city: 'Bengaluru', stars: 4, title: 'Lovely, slightly long', body: 'Gorgeous piece. I’d suggest sharing your height with the custom stitching notes — the team adjusted it quickly.' }
  ];
})(window.ASINGH);
