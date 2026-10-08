/* Catalogue data — girls' suits & ethnic wear. Replace with your real catalogue / API. */
var __root = typeof window !== 'undefined' ? window : globalThis;
__root.ASINGH = __root.ASINGH || {};
(function (A) {
  A.BRAND = 'ASINGH';
  A.FREE_SHIP_FROM = 15000;
  A.SHIP_FLAT = 250;
  A.STITCH = [
    { id: 'unstitched', label: 'Unstitched', note: 'Fabric as a set of pieces — stitch with your tailor', add: 0, eta: 'Ships in 2–3 days' },
    { id: 'semi', label: 'Semi-stitched', note: 'Bottom stitched, top piece with margins to fit', add: 600, eta: 'Ships in 4–6 days' },
    { id: 'custom', label: 'Custom-stitched', note: 'Made to your measurements by our artisans', add: 1800, eta: 'Ships in 10–14 days' }
  ];
  A.SIZES = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  A.CATEGORIES = [
    { id: 'anarkali', label: 'Anarkali Suit' },
    { id: 'lehenga-choli', label: 'Lehenga Choli' },
    { id: 'sharara', label: 'Sharara Set' },
    { id: 'gharara', label: 'Gharara Set' },
    { id: 'kurti-palazzo', label: 'Kurti & Palazzo' },
    { id: 'kurti-skirt', label: 'Kurti & Skirt' },
    { id: 'chaniya-choli', label: 'Chaniya Choli' },
    { id: 'rajputi-poshak', label: 'Rajputi Poshak' },
    { id: 'ghagra-choli', label: 'Ghagra Choli' },
    { id: 'angrakha', label: 'Angrakha Dress' },
    { id: 'peplum', label: 'Peplum Suit' },
    { id: 'patiala', label: 'Patiala Suit' },
    { id: 'straight', label: 'Straight Suit' },
    { id: 'a-line', label: 'A-Line Dress' },
    { id: 'frock', label: 'Frock / Anarkali Frock' },
    { id: 'indo-western', label: 'Indo-Western Dress' },
    { id: 'gown', label: 'Ethnic Gown' }
  ];
  A.OCCASIONS = [
    { id: 'wedding', label: 'Wedding & Engagement' },
    { id: 'festive', label: 'Festive & Puja' },
    { id: 'sangeet', label: 'Sangeet & Mehendi' },
    { id: 'party', label: 'Party & Evening' },
    { id: 'everyday', label: 'Everyday & Office' }
  ];
  A.PRICE_BANDS = [
    { id: 'u3', label: 'Under ₹3,000', min: 0, max: 3000 },
    { id: '3-6', label: '₹3,000 – ₹6,000', min: 3000, max: 6000 },
    { id: '6-12', label: '₹6,000 – ₹12,000', min: 6000, max: 12000 },
    { id: 'o12', label: 'Over ₹12,000', min: 12000, max: Infinity }
  ];
  var c = function (name, hex) { return { name: name, hex: hex }; };
  var inc = {
    lehenga: ['Lehenga with can-can (4–5 m flare)', 'Choli / blouse with embroidered sleeves', 'Dupatta (2.5 m) with finished border'],
    suit: ['Kurta / kameez (2.5 m)', 'Bottom — salwar, palazzo or churidar (2.5 m)', 'Dupatta (2.2 m)'],
    set2: ['Kurti (2.5 m)', 'Matching bottom (2.5 m)'],
    dress: ['Dress with lining (3 m)', 'Matching dupatta or belt'],
    poshak: ['Ghagra with can-can (6 m flare)', 'Kanchli (blouse) with embroidered sleeves', 'Odhni (2.5 m) with gota-patti border', 'Matching dori & tassels']
  };
  var care = 'Dry clean recommended for embroidered pieces. Colours may vary slightly by screen.';
  A.PRODUCTS = [
    { id: 'maharani-poshak', name: 'Maharani Gota-Patti Bridal Poshak', cat: 'rajputi-poshak', occ: ['wedding'], fabric: 'Pure georgette · zardozi', price: 38900, was: 46500, badge: 'Bestseller', best: true, isNew: false, rating: 4.9, reviews: 128, colors: [c('Mulberry', '#7a1f3d'), c('Rani', '#c9486e')], inc: inc.poshak, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A bridal Rajputi poshak in mulberry georgette with dense zardozi and gota-patti — the full six-metre flare.', details: ['Pure georgette with zardozi', 'Gota-patti border', 'Odhni included', 'Lined throughout', care] },
    { id: 'jodha-gown', name: 'Jodha Emerald Velvet Ethnic Gown', cat: 'gown', occ: ['wedding', 'party'], fabric: 'Velvet · gota patti', price: 42500, was: null, badge: 'Limited', best: true, isNew: true, rating: 4.9, reviews: 64, colors: [c('Emerald', '#14463c'), c('Wine', '#7a1f3d')], inc: inc.dress, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A floor-length velvet ethnic gown with gota-patti detailing and a sweeping hem, made for receptions and evening events.', details: ['Velvet with gota patti', 'Full-length with train', 'Concealed side zip', 'Lined', care] },
    { id: 'gangaur-chaniya', name: 'Gangaur Leheriya Chaniya Choli', cat: 'chaniya-choli', occ: ['festive', 'sangeet'], fabric: 'Chiffon · leheriya', price: 17400, was: null, badge: 'New', best: true, isNew: true, rating: 4.8, reviews: 76, colors: [c('Sunset', '#c4572b'), c('Teal', '#1d6b5a')], inc: inc.lehenga, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A colourful chaniya choli in hand-dyed leheriya — the perfect Navratri and garba outfit.', details: ['Chiffon leheriya', 'Mirror-work choli', 'Dupatta with border', 'Twirl-friendly flare', care] },
    { id: 'teej-lehenga', name: 'Teej Rani-Pink Leheriya Lehenga Choli', cat: 'lehenga-choli', occ: ['festive', 'wedding'], fabric: 'Georgette · leheriya', price: 15600, was: 18200, badge: 'Sale', best: true, isNew: false, rating: 4.8, reviews: 93, colors: [c('Rani Pink', '#c23a6e'), c('Peacock', '#1d6b5a')], inc: inc.lehenga, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A rani-pink lehenga choli in fluid leheriya georgette with a contrast dupatta.', details: ['Georgette leheriya', 'Embroidered choli', 'Contrast dupatta', 'Can-can included', care] },
    { id: 'jaipur-bandhani', name: 'Jaipur Bandhani Ghagra Choli', cat: 'ghagra-choli', occ: ['festive', 'wedding'], fabric: 'Gajji silk · bandhani', price: 21800, was: 24900, badge: 'Sale', best: true, isNew: false, rating: 4.7, reviews: 211, colors: [c('Sindoor', '#a8281f'), c('Mustard', '#d9a62a')], inc: inc.lehenga, stitch: ['unstitched', 'semi', 'custom'], blurb: 'Hand-tied bandhani dots on rich gajji silk, with a matching choli and odhni.', details: ['Gajji silk bandhani', 'Choli fabric included', 'Odhni with edges finished', 'Generous flare', care] },
    { id: 'marwari-sharara', name: 'Marwari Bandhani Sharara Set', cat: 'sharara', occ: ['festive', 'sangeet'], fabric: 'Georgette · bandhani', price: 6900, was: null, badge: '', best: false, isNew: false, rating: 4.6, reviews: 58, colors: [c('Sindoor', '#b0243a'), c('Marigold', '#e9b44a')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A flowing sharara set — short kurti, flared sharara and dupatta in bandhani georgette.', details: ['Georgette bandhani', 'Flared sharara', 'Dupatta included', 'Easy to dance in', care] },
    { id: 'kota-doria-suit', name: 'Kota Doria Straight Suit', cat: 'straight', occ: ['everyday', 'festive'], fabric: 'Kota doria cotton', price: 5400, was: null, badge: 'New', best: false, isNew: true, rating: 4.6, reviews: 54, colors: [c('Sand', '#e4cfa8'), c('Rose', '#d98b8b')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'An airy Kota doria straight suit with a block-print border — easy for summer days and office.', details: ['Kota doria cotton', 'Block-print border', 'Breathable and light', 'Matching dupatta', care] },
    { id: 'mewar-patiala', name: 'Mewar Navy Gota-Patti Patiala Suit', cat: 'patiala', occ: ['festive', 'sangeet'], fabric: 'Cotton silk · gota patti', price: 7200, was: null, badge: '', best: false, isNew: false, rating: 4.7, reviews: 47, colors: [c('Navy', '#2c3a6b'), c('Maroon', '#7a1f3d')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A deep navy Patiala suit with gota-patti trims, pleated patiala salwar and a marigold dupatta.', details: ['Cotton silk', 'Gota-patti lattice', 'Pleated patiala salwar', 'Dupatta with border', care] },
    { id: 'udaipur-gharara', name: 'Udaipur Mirror-Work Gharara Set', cat: 'gharara', occ: ['sangeet', 'wedding'], fabric: 'Tussar silk · shisha work', price: 24800, was: 28900, badge: 'Sale', best: false, isNew: false, rating: 4.7, reviews: 61, colors: [c('Amethyst', '#3d2a6b'), c('Teal', '#1d6b5a')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'Hand-set shisha mirrors catch the light across a flared gharara — made for the mehendi.', details: ['Tussar silk with shisha embroidery', 'Flared gharara with gathered knee', 'Short kurti and dupatta', 'Lined', care] },
    { id: 'rani-sa-anarkali', name: 'Rani Pink Banarasi Anarkali Suit', cat: 'anarkali', occ: ['wedding', 'festive'], fabric: 'Banarasi silk · gota', price: 12500, was: null, badge: 'Bestseller', best: true, isNew: false, rating: 4.9, reviews: 167, colors: [c('Rani', '#d6457f'), c('Mulberry', '#7a1f3d')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A floor-length Anarkali in Banarasi silk with gota work at the yoke, churidar and dupatta.', details: ['Banarasi silk', 'Gota yoke', 'Churidar and dupatta', 'Floor-length flare', care] },
    { id: 'pushkar-kurti-palazzo', name: 'Pushkar Leheriya Kurti & Palazzo', cat: 'kurti-palazzo', occ: ['everyday', 'festive'], fabric: 'Chiffon · leheriya', price: 3400, was: null, badge: '', best: false, isNew: true, rating: 4.5, reviews: 33, colors: [c('Marigold', '#e8913a'), c('Rani', '#c23a6e')], inc: inc.set2, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A breezy leheriya kurti with matching wide-leg palazzo — comfortable for everyday and brunch.', details: ['Chiffon leheriya', 'Wide-leg palazzo', 'Side pockets', 'Light and breathable', care] },
    { id: 'kesariya-angrakha', name: 'Kesariya Zardozi Angrakha Dress', cat: 'angrakha', occ: ['wedding', 'festive'], fabric: 'Chanderi silk · zardozi', price: 9400, was: null, badge: 'New', best: false, isNew: true, rating: 4.8, reviews: 29, colors: [c('Kesariya', '#e0902a'), c('Maroon', '#7a1f3d')], inc: inc.dress, stitch: ['unstitched', 'semi', 'custom'], blurb: 'An angrakha-style wrap dress in Chanderi silk with zardozi along the overlapping panels.', details: ['Chanderi silk', 'Overlapping angrakha panels', 'Zardozi trims', 'Churidar included', care] },
    { id: 'gulab-peplum', name: 'Gulab Gota Peplum Suit', cat: 'peplum', occ: ['party', 'everyday'], fabric: 'Crepe · gota patti', price: 5900, was: 6900, badge: 'Sale', best: false, isNew: true, rating: 4.6, reviews: 22, colors: [c('Gulab', '#d98b9c'), c('Ivory', '#f1e6d3')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A flattering peplum kurta with gota-patti hem, cigarette trousers and a sheer dupatta.', details: ['Crepe with gota patti', 'Peplum waist', 'Cigarette trousers', 'Sheer dupatta', care] },
    { id: 'nila-kurti-skirt', name: 'Nila Bandhani Kurti & Skirt', cat: 'kurti-skirt', occ: ['festive', 'party'], fabric: 'Rayon · bandhani', price: 4800, was: null, badge: 'New', best: false, isNew: true, rating: 4.5, reviews: 18, colors: [c('Nila', '#1f5a8a'), c('Sindoor', '#a8281f')], inc: inc.set2, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A short bandhani kurti with a swishy flared skirt — an easy festive co-ord.', details: ['Rayon bandhani', 'Flared skirt with elastic waist', 'Short kurti', 'Light and comfortable', care] },
    { id: 'sabz-a-line', name: 'Sabz Chikankari A-Line Dress', cat: 'a-line', occ: ['everyday', 'party'], fabric: 'Cotton · chikankari', price: 4200, was: null, badge: '', best: false, isNew: false, rating: 4.6, reviews: 41, colors: [c('Sabz', '#2f6b4f'), c('Powder Blue', '#b9cde0')], inc: inc.dress, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A knee-to-calf A-line dress with hand chikankari at the yoke — pairs with a dupatta or stands alone.', details: ['Cotton with chikankari', 'A-line silhouette', 'Side pockets', 'Easy-care', care] },
    { id: 'mehndi-frock', name: 'Mehndi Gota Anarkali Frock', cat: 'frock', occ: ['sangeet', 'party'], fabric: 'Georgette · gota patti', price: 8600, was: null, badge: 'New', best: false, isNew: true, rating: 4.7, reviews: 26, colors: [c('Mehndi', '#6f8f3a'), c('Peach', '#e7a58a')], inc: inc.dress, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A twirl-ready Anarkali frock in mehndi-green georgette with gota-patti borders.', details: ['Georgette with gota patti', 'Flared frock', 'Matching dupatta', 'Lined', care] },
    { id: 'aaina-indo-western', name: 'Aaina Mirror Indo-Western Dress', cat: 'indo-western', occ: ['party', 'sangeet'], fabric: 'Crepe · mirror work', price: 11800, was: 13900, badge: 'Sale', best: false, isNew: true, rating: 4.7, reviews: 37, colors: [c('Teal', '#1d6b6b'), c('Black', '#26222a')], inc: inc.dress, stitch: ['unstitched', 'semi', 'custom'], blurb: 'An asymmetrical indo-western dress with mirror-work yoke and cape dupatta — modern, festive, effortless.', details: ['Crepe with mirror work', 'Asymmetric hem', 'Cape dupatta', 'Concealed zip', care] }
  ];
  A.REVIEWS = [
    { who: 'Priya S.', city: 'Jaipur', stars: 5, title: 'Exactly what I wanted for the sangeet', body: 'The gota-patti work is beautifully done and the flare is lovely. Custom stitching fit perfectly on the first try.' },
    { who: 'Anjali K.', city: 'Jodhpur', stars: 5, title: 'Wore it for Navratri', body: 'So many compliments. The colours are rich and true to the listing. Delivery was a day early.' },
    { who: 'Meenal R.', city: 'Mumbai', stars: 4, title: 'Lovely, slightly long', body: 'Gorgeous piece. I’d suggest sharing your height with the custom stitching notes — the team adjusted it quickly.' }
  ];
})(__root.ASINGH);
if (typeof module !== 'undefined' && module.exports) module.exports = __root.ASINGH; // server re-uses this catalogue to price orders
