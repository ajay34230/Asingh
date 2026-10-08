/* Catalogue data — Rajputi dresses only. Replace with your real catalogue / API. */
var __root = typeof window !== 'undefined' ? window : globalThis;
__root.ASINGH = __root.ASINGH || {};
(function (A) {
  A.BRAND = 'ASINGH';
  A.FREE_SHIP_FROM = 15000;
  A.SHIP_FLAT = 250;
  A.STITCH = [
    { id: 'unstitched', label: 'Unstitched', note: 'Fabric as a set of pieces — stitch with your tailor', add: 0, eta: 'Ships in 2–3 days' },
    { id: 'semi', label: 'Semi-stitched', note: 'Ghagra stitched, kanchli piece with margins to fit', add: 600, eta: 'Ships in 4–6 days' },
    { id: 'custom', label: 'Custom-stitched', note: 'Made to your measurements by our artisans', add: 1800, eta: 'Ships in 10–14 days' }
  ];
  A.SIZES = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  A.CATEGORIES = [
    { id: 'poshak', label: 'Rajputi Poshak' },
    { id: 'ghagra', label: 'Ghagra Choli' },
    { id: 'bandhani', label: 'Bandhani & Leheriya' },
    { id: 'odhni', label: 'Odhni' },
    { id: 'suits', label: 'Rajputi Suits' }
  ];
  A.OCCASIONS = [
    { id: 'wedding', label: 'Vivah (Wedding)' },
    { id: 'festive', label: 'Teej & Gangaur' },
    { id: 'sangeet', label: 'Sangeet & Mehendi' },
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
    poshak: ['Ghagra with can-can & drawstring (6 m flare)', 'Kanchli (blouse) with embroidered sleeves', 'Odhni (2.5 m) with gota-patti border', 'Matching dori & tassels'],
    ghagra: ['Ghagra with can-can (5 m flare)', 'Choli / blouse fabric (1 m)', 'Odhni (2.5 m) with finished edges'],
    odhni: ['Odhni (2.5 m × 1.2 m)', 'Hand-finished edges with tassels'],
    suit: ['Kurta (2.5 m)', 'Salwar / churidar (2.5 m)', 'Odhni / dupatta (2.2 m)']
  };
  var care = 'Hand-finished in Rajasthan. Dry clean only. Colours may vary slightly by screen.';
  A.PRODUCTS = [
    { id: 'maharani-poshak', name: 'Maharani Gota-Patti Bridal Poshak', cat: 'poshak', occ: ['wedding'], fabric: 'Pure georgette · zardozi', price: 38900, was: 46500, badge: 'Bestseller', best: true, isNew: false, rating: 4.9, reviews: 128, colors: [c('Mulberry', '#7a1f3d'), c('Emerald', '#14463c'), c('Midnight', '#2c3a6b')], inc: inc.poshak, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A full-flare bridal poshak with zardozi blossoms, a broad gota-patti hem and a heavy odhni — made the way Rajputana brides have worn it for generations.', details: ['Pure georgette with zardozi embroidery', 'Gota-patti hem and odhni border', 'Fully lined with can-can', care] },
    { id: 'jodha-poshak', name: 'Jodha Emerald Gota Poshak', cat: 'poshak', occ: ['wedding', 'sangeet'], fabric: 'Velvet · gota patti', price: 42500, was: null, badge: 'Limited', best: true, isNew: true, rating: 4.9, reviews: 64, colors: [c('Emerald', '#14463c'), c('Wine', '#7a1f3d')], inc: inc.poshak, stitch: ['semi', 'custom'], blurb: 'Rich emerald velvet laced with a lattice of gota-patti ribbon, paired with a rust odhni.', details: ['Velvet with gota-patti lattice', 'Contrast odhni with zari border', 'Can-can and concealed zip', care] },
    { id: 'gangaur-ghagra', name: 'Gangaur Leheriya Ghagra Choli', cat: 'ghagra', occ: ['festive', 'sangeet'], fabric: 'Chiffon · leheriya', price: 17400, was: null, badge: 'New', best: true, isNew: true, rating: 4.8, reviews: 76, colors: [c('Sunset', '#c4572b'), c('Rani', '#c23a6e')], inc: inc.ghagra, stitch: ['unstitched', 'semi', 'custom'], blurb: 'Tie-dyed leheriya waves in sunset tones, finished with a gota-patti hem — made for Gangaur and Teej.', details: ['Hand-dyed leheriya chiffon', 'Gota-patti border', 'Odhni with matching waves', care] },
    { id: 'teej-leheriya', name: 'Teej Rani-Pink Leheriya Set', cat: 'bandhani', occ: ['festive'], fabric: 'Georgette · leheriya', price: 15600, was: 18200, badge: 'Sale', best: true, isNew: false, rating: 4.8, reviews: 93, colors: [c('Rani Pink', '#c23a6e'), c('Peacock', '#1d6b5a')], inc: inc.ghagra, stitch: ['unstitched', 'semi', 'custom'], blurb: 'Playful pink-and-green leheriya in feather-light georgette — the classic monsoon Teej set.', details: ['Leheriya-dyed georgette', 'Contrast peacock odhni', 'Gota-patti border', care] },
    { id: 'jaipur-bandhani', name: 'Jaipur Bandhani Ghagra Set', cat: 'bandhani', occ: ['festive', 'wedding'], fabric: 'Gajji silk · bandhani', price: 21800, was: 24900, badge: 'Sale', best: true, isNew: false, rating: 4.7, reviews: 211, colors: [c('Sindoor', '#a8281f'), c('Kesariya', '#e8913a')], inc: inc.ghagra, stitch: ['unstitched', 'semi', 'custom'], blurb: 'Hand-tied bandhani dots across gajji silk in sindoor red, with a golden odhni.', details: ['Hand-tied bandhani on gajji silk', 'Gold gota-patti hem', 'Odhni included', care] },
    { id: 'marwari-odhni', name: 'Marwari Bandhani Odhni', cat: 'odhni', occ: ['festive', 'everyday'], fabric: 'Georgette · bandhani', price: 3900, was: null, badge: '', best: false, isNew: false, rating: 4.6, reviews: 58, colors: [c('Sindoor', '#b0243a'), c('Kesariya', '#e8913a')], inc: inc.odhni, stitch: ['unstitched'], blurb: 'A classic Marwari bandhani odhni with a gota-patti border and tassels.', details: ['Hand-tied bandhani', 'Gota-patti border', 'Tassel finish', care] },
    { id: 'kota-doria-suit', name: 'Kota Doria Rajputi Suit', cat: 'suits', occ: ['everyday', 'festive'], fabric: 'Kota doria cotton', price: 8900, was: null, badge: 'New', best: false, isNew: true, rating: 4.6, reviews: 54, colors: [c('Sand', '#e4cfa8'), c('Rose', '#d98b8b')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'Airy Kota doria weave in a Rajputi-cut kurta and salwar — easy for summer days.', details: ['Kota doria cotton', 'Block-print border', 'Breathable and light', care] },
    { id: 'mewar-gota-suit', name: 'Mewar Navy Gota-Patti Suit', cat: 'suits', occ: ['festive', 'sangeet'], fabric: 'Cotton silk · gota patti', price: 11200, was: null, badge: '', best: false, isNew: false, rating: 4.7, reviews: 47, colors: [c('Navy', '#2c3a6b'), c('Maroon', '#7a1f3d')], inc: inc.suit, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A Mewar-inspired suit in deep navy with gota-patti trims and a marigold odhni.', details: ['Cotton silk', 'Gota-patti lattice', 'Odhni with border', care] },
    { id: 'udaipur-mirror', name: 'Udaipur Mirror-Work Ghagra', cat: 'ghagra', occ: ['sangeet', 'festive'], fabric: 'Tussar silk · shisha work', price: 24800, was: 28900, badge: 'Sale', best: false, isNew: false, rating: 4.7, reviews: 61, colors: [c('Amethyst', '#3d2a6b'), c('Teal', '#1d6b5a')], inc: inc.ghagra, stitch: ['unstitched', 'semi', 'custom'], blurb: 'Hand-set shisha mirrors catch the light across amethyst silk — made for the dance floor.', details: ['Tussar silk with shisha embroidery', 'Contrast marigold choli', 'Pink odhni with border', care] },
    { id: 'rani-sa-poshak', name: 'Rani Sa Pink Poshak', cat: 'poshak', occ: ['wedding', 'festive'], fabric: 'Banarasi silk · gota', price: 32500, was: null, badge: '', best: true, isNew: false, rating: 4.9, reviews: 167, colors: [c('Rani', '#d6457f'), c('Mulberry', '#7a1f3d')], inc: inc.poshak, stitch: ['unstitched', 'semi', 'custom'], blurb: 'A royal rani-pink poshak with gota-patti lattice and an ivory odhni.', details: ['Banarasi silk', 'Gota-patti lattice', 'Ivory odhni with border', care] },
    { id: 'pushkar-odhni', name: 'Pushkar Leheriya Odhni', cat: 'odhni', occ: ['festive', 'everyday'], fabric: 'Chiffon · leheriya', price: 3400, was: null, badge: '', best: false, isNew: true, rating: 4.5, reviews: 33, colors: [c('Marigold', '#e8913a'), c('Rani', '#c23a6e')], inc: inc.odhni, stitch: ['unstitched'], blurb: 'A vivid multi-colour leheriya odhni that lifts any plain suit or ghagra.', details: ['Leheriya-dyed chiffon', 'Gota border', 'Hand-finished edges', care] },
    { id: 'kesariya-poshak', name: 'Kesariya Zardozi Poshak', cat: 'poshak', occ: ['wedding', 'festive'], fabric: 'Chanderi silk · zardozi', price: 27400, was: null, badge: 'New', best: false, isNew: true, rating: 4.8, reviews: 29, colors: [c('Kesariya', '#e0902a'), c('Wine', '#7a1f3d')], inc: inc.poshak, stitch: ['unstitched', 'semi', 'custom'], blurb: 'The saffron colour of Rajput valour — Chanderi silk with wine zardozi and a crimson odhni.', details: ['Chanderi silk', 'Zardozi embroidery', 'Crimson odhni with border', care] }
  ];
  A.REVIEWS = [
    { who: 'Priya S.', city: 'Jaipur', stars: 5, title: 'Exactly what I wanted for the wedding', body: 'The gota-patti work is beautifully done and the flare is generous. Custom stitching fit perfectly on the first try.' },
    { who: 'Anjali K.', city: 'Jodhpur', stars: 5, title: 'Wore it for Gangaur', body: 'So many compliments. The leheriya colours are rich and true to the listing. Delivery was a day early.' },
    { who: 'Meenal R.', city: 'Mumbai', stars: 4, title: 'Lovely, slightly long', body: 'Gorgeous piece. I’d suggest sharing your height with the custom stitching notes — the team adjusted it quickly.' }
  ];
})(__root.ASINGH);
if (typeof module !== 'undefined' && module.exports) module.exports = __root.ASINGH; // server re-uses this catalogue to price orders
