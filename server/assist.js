'use strict';
/* The free "brain" of the shopper assistant: understands English, Hindi (Devanagari) and Hinglish questions without any AI service.
   Used when no Gemini key is set, or when Gemini is busy / out of quota — so shoppers always get a sensible answer. */
const HI2EN = { 'लहंगा': 'lehenga', 'लहंगे': 'lehenga', 'चोली': 'choli', 'अनारकली': 'anarkali', 'सूट': 'suit', 'शरारा': 'sharara', 'गरारा': 'gharara', 'कुर्ती': 'kurti', 'पलाज़ो': 'palazzo', 'पलाजो': 'palazzo', 'पटियाला': 'patiala', 'गाउन': 'gown', 'फ्रॉक': 'frock', 'फ्रोक': 'frock', 'ड्रेस': 'dress', 'घाघरा': 'ghagra', 'चनिया': 'chaniya', 'शादी': 'wedding', 'विवाह': 'wedding', 'सगाई': 'wedding', 'त्योहार': 'festive', 'त्यौहार': 'festive', 'दिवाली': 'festive', 'पूजा': 'puja', 'पार्टी': 'party', 'जन्मदिन': 'birthday', 'संगीत': 'sangeet', 'मेहंदी': 'mehendi', 'हल्दी': 'haldi', 'लाल': 'red', 'गुलाबी': 'pink', 'हरा': 'green', 'हरे': 'green', 'नीला': 'blue', 'नीले': 'blue', 'पीला': 'yellow', 'पीले': 'yellow', 'काला': 'black', 'काले': 'black', 'सफेद': 'white', 'सफ़ेद': 'white', 'नारंगी': 'orange', 'बैंगनी': 'purple', 'भूरा': 'brown', 'डिलीवरी': 'delivery', 'डिलिवरी': 'delivery', 'पहुँचेगा': 'delivery', 'रिटर्न': 'return', 'वापसी': 'return', 'एक्सचेंज': 'exchange', 'कीमत': 'price', 'दाम': 'price', 'क़ीमत': 'price', 'साइज़': 'size', 'साइज': 'size', 'नाप': 'size', 'ऑर्डर': 'order', 'ट्रैक': 'track', 'भुगतान': 'payment', 'पेमेंट': 'payment', 'कैश': 'cash', 'छूट': 'discount', 'डिस्काउंट': 'discount', 'ऑफर': 'offer', 'कूपन': 'coupon', 'धन्यवाद': 'thanks', 'शुक्रिया': 'thanks', 'नमस्ते': 'hello', 'हेलो': 'hello', 'सिलाई': 'stitching', 'बच्ची': 'girl', 'बेटी': 'girl', 'व्हाट्सएप': 'whatsapp', 'नंबर': 'number', 'संपर्क': 'contact' };
const HINGLISH_STOP = new Set('chahiye chahie dikhao dikha dikhaiye batao bataiye bataye mujhe hai hain hoga ho ka ki ke ko me mein mai main aur ya kya koi kuch bhi se tak wala wali wale liye lie dedo do sabse accha achha acha sundar bahut mere meri apka aapka aapke kaise kitna kitne kitni kab kahan please plz pls kindly hi hello hey hii namaste thanks thank you ok okay yes no sir madam ji aap tum hum yeh ye woh wo koi any about regarding there have has available'.split(' '));
const norm = s => String(s || '').toLowerCase().replace(/[ऀ-ॿ]+/g, w => ' ' + (HI2EN[w] || w) + ' ').replace(/(\d[\d,]*)\s*(?:तक|से\s*कम|के\s*(?:अंदर|भीतर))/g, 'under $1').replace(/\s+/g, ' ').trim();
const lev = (a, b) => { const m = a.length, n = b.length; if (Math.abs(m - n) > 2) return 9; const d = Array.from({ length: m + 1 }, (_, i) => [i]); for (let j = 1; j <= n; j++) d[0][j] = j; for (let i = 1; i <= m; i++) for (let j = 1; j <= n; j++) d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)); return d[m][n]; };
const words = s => String(s || '').toLowerCase().split(/[^a-z0-9]+/).filter(w => w.length > 2).map(w => w.replace(/s$/, ''));

function vocab(catalog, pub) {   // style words shoppers may use: category names, product-name words
  const style = new Map();   // word -> Set(category ids)
  catalog.categories.forEach(c => words(c.label + ' ' + c.id.replace(/-/g, ' ')).forEach(w => { if (!['dress', 'set', 'suit'].includes(w) || /suit|set|dress/.test(c.id)) (style.get(w) || style.set(w, new Set()).get(w)).add(c.id); }));
  const extra = new Set(); pub.forEach(p => words(p.name).forEach(w => extra.add(w)));
  return { style, extra };
}
function fixWord(w, known) {   // forgive spelling slips ("lehnga", "sharra")
  if (known.has(w) || w.length < 5) return w; let best = w, bd = 9;
  known.forEach(k => { if (k.length >= 4) { const d = lev(w, k); if (d < bd && d <= (w.length > 7 ? 2 : 1)) { bd = d; best = k; } } }); return best;
}
function intentOf(q) {
  if (/^(hi+|hello+|hey+|namaste|namaskar|good (morning|evening|afternoon)|hlo|helo)\b[\s!.,?]*$/.test(q)) return 'greet';
  if (/^(thanks?|thank you|thx|ok(ay)?|great|nice|good|got it|shukriya|dhanyavad)[\s!.,?]*$/.test(q)) return 'thanks';
  if (/\b(track|tracking|where is my|order status|my order|order kahan|kab aayega|status)\b/.test(q)) return 'track';
  if (/\b(return|exchange|refund|wapas|replace|replacement|change my|money back)\b/.test(q)) return 'return';
  if (/\b(cod|cash on delivery|cash|payment|pay|upi|card|netbanking|gpay|phonepe|paytm|razorpay|emi)\b/.test(q)) return 'payment';
  if (/\b(size|sizes|measure|measurement|fit|fitting|height|age|years? old|year|chart)\b/.test(q) && !/\b(show|dikhao)\b.*\b(under|below)\b/.test(q)) return 'size';
  if (/\b(custom|customi[sz]e|stitch|stitching|silai|tailor|alteration|made to measure|unstitched|semi)\b/.test(q)) return 'custom';
  if (/\b(deliver|delivery|shipping|ship|dispatch|courier|how long|kitne din|how many days|when will|free delivery|shipping charge)\b/.test(q)) return 'delivery';
  if (/\b(contact|whatsapp|call|phone|number|talk|human|speak|address|email|store|shop location)\b/.test(q)) return 'contact';
  if (/\b(offer|offers|discount|coupon|code|sale|deal|promo)\b/.test(q) && !/\b(under|below|less than)\s*\d/.test(q)) return 'offer';
  if (/\b(new arrivals?|latest|new in|just in)\b/.test(q)) return 'new';
  if (/\b(best ?sellers?|popular|trending|top)\b/.test(q)) return 'best';
  if (/\b(what (do|all) you (have|sell)|categories|collections?|catalogue|catalog|types|kya kya|show (me )?(all|everything))\b/.test(q)) return 'browse';
  return 'search';
}
function money(n) { return '₹' + Number(n).toLocaleString('en-IN'); }

function answer(catalog, msgs, lang, helpers) {
  const users = msgs.filter(m => m.role === 'user').map(m => m.text), lastRaw = users[users.length - 1] || '', hiText = /[ऀ-ॿ]/.test(lastRaw) || lang === 'hi' && !/[a-z]{3}/i.test(lastRaw);
  const hi = hiText, last = norm(lastRaw), prev = users.slice(0, -1).map(norm);
  const v = catalog.pageVars(), t = catalog.site, wa = t.whatsapp ? '+' + t.whatsapp : '';
  const T = (en, hin) => hi ? hin : en;
  const reach = T(wa ? `message us on WhatsApp at ${wa}` : 'use the Contact page', wa ? `WhatsApp ${wa} पर संदेश भेजें` : 'Contact पेज का उपयोग करें');
  const prods = catalog.D.products.filter(p => p.published), pub = prods.map(p => catalog.publicProduct(p)), byId = new Map(prods.map(p => [p.id, p]));
  const card = p => { const x = catalog.publicProduct(byId.get(p.id)); return { id: x.id, name: x.name, price: x.price, was: x.was || null }; };
  const chips = list => list.map(([en, hin]) => T(en, hin));
  const base = { products: [], ai: false }, DEF = chips([['Delivery time', 'डिलीवरी में कितना समय?'], ['Return policy', 'रिटर्न पॉलिसी'], ['Custom stitching', 'कस्टम सिलाई']]);
  const say = (reply, extra) => ({ ...base, reply, suggest: DEF, ...extra });
  const intent = intentOf(last);
  switch (intent) {
    case 'greet': return say(T('Namaste! 🙏 Tell me what you are looking for — for example “red lehenga for a wedding” or “suit under ₹3,000”.', 'नमस्ते! 🙏 बताइए आप क्या ढूँढ रहे हैं — जैसे “शादी के लिए लाल लहंगा” या “₹3,000 से कम का सूट”।'), { suggest: chips([['New arrivals', 'नए आगमन'], ['Best sellers', 'बेस्टसेलर'], ['Suit under ₹3,000', '₹3,000 से कम का सूट']]) });
    case 'thanks': return say(T('You are welcome! Let me know if you need anything else.', 'आपका स्वागत है! और कुछ चाहिए तो बताइए।'));
    case 'track': return say(T('Open the Track order page and enter your order number (like AS-12345) with the phone or email you ordered with. If you need help, ' + reach + '.', 'Track order पेज खोलकर अपना ऑर्डर नंबर (जैसे AS-12345) और फ़ोन/ईमेल डालें। मदद चाहिए तो ' + reach + '।'));
    case 'return': return say(T(`Returns and exchanges are accepted within ${v.returnDays} days of delivery for unworn items with tags. Made-to-measure pieces can’t be returned unless faulty. For a return request, ${reach}.`, `डिलीवरी के ${v.returnDays} दिनों के भीतर बिना पहने, टैग वाले आइटम का रिटर्न/एक्सचेंज हो सकता है। नाप से सिले हुए पीस सिर्फ़ खराबी होने पर वापस होते हैं। रिटर्न के लिए ${reach}।`));
    case 'delivery': return say(T(`We dispatch in ${v.dispatch} and delivery takes ${v.delivery}. Custom stitching takes ${v.stitchDays}. Shipping is free over ${v.shipFree}, otherwise ${v.shipFee}. You can check your PIN code on any product page.`, `हम ${v.dispatch} में डिस्पैच करते हैं और डिलीवरी में ${v.delivery} लगते हैं। कस्टम सिलाई में ${v.stitchDays} लगते हैं। ${v.shipFree} से ऊपर शिपिंग फ्री है, वरना ${v.shipFee}। किसी भी प्रोडक्ट पेज पर अपना PIN कोड चेक कर सकते हैं।`));
    case 'payment': { const cod = (catalog.db.data.settings || {}).cod || {}; const codTxt = /\b(cod|cash)\b/.test(last) ? (cod.enabled ? T(`Yes, cash on delivery is available${cod.fee ? ' (₹' + cod.fee + ' handling fee)' : ''}${cod.max ? ' for orders up to ' + money(cod.max) : ''}. Choose it at checkout.`, `हाँ, कैश ऑन डिलीवरी उपलब्ध है${cod.fee ? ' (₹' + cod.fee + ' हैंडलिंग शुल्क)' : ''}${cod.max ? ', ' + money(cod.max) + ' तक के ऑर्डर पर' : ''}। चेकआउट पर चुनें।`) : T('Cash on delivery is not available right now. You can pay by UPI/QR' + (process.env.RAZORPAY_KEY_ID ? ' or by card/netbanking' : '') + '.', 'अभी कैश ऑन डिलीवरी उपलब्ध नहीं है। आप UPI/QR' + (process.env.RAZORPAY_KEY_ID ? ' या कार्ड/नेटबैंकिंग' : '') + ' से भुगतान कर सकते हैं।')) : ''; if (codTxt) return say(codTxt); return say(T('You can pay by UPI/QR (upload the payment screenshot on your order page and also WhatsApp it to us)' + (process.env.RAZORPAY_KEY_ID ? ', by card or netbanking' : '') + ', or choose cash on delivery where it is offered at checkout.', 'आप UPI/QR से भुगतान कर सकते हैं (ऑर्डर पेज पर पेमेंट स्क्रीनशॉट अपलोड करें और हमें WhatsApp भी करें)' + (process.env.RAZORPAY_KEY_ID ? ', कार्ड या नेटबैंकिंग से भी' : '') + ', या चेकआउट पर उपलब्ध होने पर कैश ऑन डिलीवरी चुनें।')); }
    case 'size': return say(T('On every product page use “Find my size” — enter her height or age and it suggests a size. For the most accurate fit, choose Custom stitching and add her measurements in the note. The size chart is on the product page too.', 'हर प्रोडक्ट पेज पर “Find my size” में बच्ची की ऊँचाई या उम्र डालें, यह साइज़ बताएगा। सबसे सही फ़िट के लिए “Custom stitching” चुनें और नोट में नाप लिखें। साइज़ चार्ट भी प्रोडक्ट पेज पर है।'));
    case 'custom': return say(T(`Every piece can be stitched to your measurements — pick Custom on the product page. It takes ${v.stitchDays} and one free alteration is included. You can also order unstitched or semi-stitched.`, `हर पीस आपकी नाप से सिला जा सकता है — प्रोडक्ट पेज पर Custom चुनें। इसमें ${v.stitchDays} लगते हैं और एक बार फ्री अल्टरेशन शामिल है। अनस्टिच्ड या सेमी-स्टिच्ड भी ले सकते हैं।`));
    case 'contact': { const bits = [wa && `WhatsApp ${wa}`, v.phone !== '—' && `phone ${v.phone}`, v.email !== '—' && `email ${v.email}`].filter(Boolean); return say(bits.length ? T(`You can reach us on ${bits.join(', ')}.` + (v.hours !== '—' ? ` Hours: ${v.hours}.` : ''), `आप हमसे ${bits.join(', ')} पर संपर्क कर सकते हैं।` + (v.hours !== '—' ? ` समय: ${v.hours}।` : '')) : T('Please use the Contact page and we will get back to you.', 'कृपया Contact पेज का उपयोग करें, हम आपसे संपर्क करेंगे।')); }
    case 'offer': { const o = t.offer && t.offer.on && t.offer.text; return say(o ? T(`Current offer: ${t.offer.text}` + (t.offer.code ? ` — use code ${t.offer.code} at checkout.` : ''), `अभी का ऑफ़र: ${t.offer.text}` + (t.offer.code ? ` — चेकआउट पर कोड ${t.offer.code} इस्तेमाल करें।` : '')) : T(`There is no special offer running right now, but shipping is free over ${v.shipFree}. Check back soon!`, `अभी कोई ख़ास ऑफ़र नहीं चल रहा, लेकिन ${v.shipFree} से ऊपर शिपिंग फ्री है।`)); }
    case 'new': { const l = pub.filter(p => p.isNew).slice(0, 4); if (l.length) return say(T('Here are our newest pieces:', 'ये हमारे नए पीस हैं:'), { products: l.map(card) }); break; }
    case 'best': { const l = pub.filter(p => p.best).slice(0, 4); if (l.length) return say(T('Our bestsellers:', 'हमारे बेस्टसेलर:'), { products: l.map(card) }); break; }
    case 'browse': { const names = catalog.categories.slice(0, 10).map(c => c.label).join(', '); return say(T(`We have girls’ suits and ethnic wear: ${names} and more. Tell me a style, colour, occasion or budget and I will pick for you.`, `हमारे पास लड़कियों के सूट और एथनिक वियर हैं: ${names} और भी। स्टाइल, रंग, मौक़ा या बजट बताइए, मैं चुनकर दिखाता हूँ।`), { suggest: chips([['Lehenga for wedding', 'शादी के लिए लहंगा'], ['Anarkali suit', 'अनारकली सूट'], ['Suit under ₹3,000', '₹3,000 से कम का सूट']]) }); }
  }
  /* ---- product search: style (hard) + colour/occasion/budget (relaxed step by step if nothing matches) ---- */
  const { style, extra } = vocab(catalog, pub), known = new Set([...style.keys(), ...extra]);
  const parse = txt => { const f = helpers.parseQuery(txt); const ws = f.words.map(w => fixWord(w, known)).filter(w => !HINGLISH_STOP.has(w)); const st = new Set(); ws.forEach(w => { if (style.has(w)) style.get(w).forEach(c => st.add(c)); }); return { ...f, words: ws, styleIds: [...st] }; };
  const f = parse(last), nWords = last.split(' ').length, lastParsed = prev.length ? parse(prev[prev.length - 1]) : null, cheap = /\b(cheap|cheaper|low price|budget|sasta|sasti|affordable|lowest)\b/.test(last);
  if (lastParsed && nWords <= 7 && !f.styleIds.length) f.styleIds = lastParsed.styleIds;   // “in blue?” / “under 2000” keep the earlier style
  const cols = f.colours || [], occ = f.occ || [], max = f.max, min = f.min;
  const SHOPPY = /\b(gift|niece|daughter|sister|girl|kid|child|baby|birthday|wedding|festival|festive|party|function|school|summer|winter|light|heavy|dress|outfit|wear|buy|order|show|want|need|looking|suggest|recommend|choose|pick|something|any)\b/;
  const topPicks = () => (pub.filter(p => p.best).concat(pub.filter(p => p.isNew)).filter((p, i, a) => a.findIndex(x => x.id === p.id) === i).concat(pub)).filter((p, i, a) => a.findIndex(x => x.id === p.id) === i).slice(0, 3);
  if (!f.styleIds.length && !cols.length && !occ.length && !max && !min && !cheap) {
    const hit = helpers.ruleSearch(pub, id => (catalog.categories.find(c => c.id === id) || {}).label || id, lastRaw).slice(0, 4);
    if (hit.length) return say(T('Here are some pieces you might like:', 'ये कुछ पीस आपको पसंद आ सकते हैं:'), { products: hit.map(card) });
    if (SHOPPY.test(last) || f.words.some(w => known.has(w))) return say(T('Happy to help! Here are a few popular pieces to start with. To narrow it down, tell me her age, the occasion and your budget.', 'ज़रूर! शुरुआत के लिए ये कुछ लोकप्रिय पीस हैं। सही चुनने के लिए बच्ची की उम्र, मौक़ा और आपका बजट बताइए।'), { products: topPicks().map(card), suggest: chips([['Wedding, under ₹10,000', 'शादी के लिए, ₹10,000 तक'], ['Birthday party', 'जन्मदिन की पार्टी'], ['Everyday wear', 'रोज़ पहनने के लिए']]) });
    return say(T(`I could not quite understand that. I can help you find a suit (try “red lehenga for wedding” or “anarkali under ₹5,000”) or answer questions about delivery, returns, sizes and payment. For anything else, ${reach}.`, `मैं ठीक से समझ नहीं पाया। मैं सूट ढूँढने में मदद कर सकता हूँ (जैसे “शादी के लिए लाल लहंगा” या “₹5,000 से कम का अनारकली”) या डिलीवरी, रिटर्न, साइज़ और पेमेंट के बारे में बता सकता हूँ। बाकी के लिए ${reach}।`), { suggest: chips([['New arrivals', 'नए आगमन'], ['Best sellers', 'बेस्टसेलर'], ['What do you have?', 'आपके पास क्या-क्या है?']]) });
  }
  const fam = p => p.colors.map(c => helpers.family(c.hex)), famOk = (p, c) => fam(p).includes(c) || (c === 'red' && fam(p).includes('maroon')) || p.colors.some(x => x.name.toLowerCase().includes(c));
  const styleOk = p => !f.styleIds.length || f.styleIds.includes(p.cat), colOk = p => cols.every(c => famOk(p, c)), occOk = p => occ.every(o => (p.occ || []).includes(o)), priceOk = p => (!max || p.price <= max) && (!min || p.price >= min);
  const score = p => { const hay = [p.name, p.fabric, p.blurb || '', p.colors.map(c => c.name).join(' ')].join(' ').toLowerCase(); return f.words.filter(w => !style.has(w) && hay.includes(w)).length + (p.best ? .3 : 0) + (p.isNew ? .2 : 0); };
  const HIC = { red: 'लाल', pink: 'गुलाबी', green: 'हरा', blue: 'नीला', yellow: 'पीला', black: 'काला', white: 'सफ़ेद', orange: 'नारंगी', purple: 'बैंगनी', brown: 'भूरा', grey: 'स्लेटी' }, HIO = { wedding: 'शादी', festive: 'त्योहार', sangeet: 'संगीत/मेहंदी', party: 'पार्टी', everyday: 'रोज़' };
  const tiers = [[1, 1, 1, 1], [1, 1, 1, 0], [1, 0, 1, 1], [1, 1, 0, 1], [1, 0, 1, 0], [1, 0, 0, 1], [1, 0, 0, 0], [0, 1, 1, 1], [0, 0, 1, 1], [0, 1, 0, 1], [0, 0, 0, 1]];   // style, colour, occasion, price
  const label = f.styleIds.length ? (catalog.categories.find(x => x.id === f.styleIds[0]) || {}).label : '';
  for (let i = 0; i < tiers.length; i++) {
    const [st, c, o, pr] = tiers[i]; if (!st && !f.styleIds.length) continue; if (!c && !cols.length && i > 0 && tiers[i][1] !== tiers[0][1]) continue;
    let hit = pub.filter(p => (!st || styleOk(p)) && (!c || colOk(p)) && (!o || occOk(p)) && (!pr || priceOk(p))); if (!hit.length) continue;
    const priceDropped = (max || min) && !pr; hit = hit.sort((a, b) => priceDropped || cheap ? a.price - b.price : score(b) - score(a) || a.price - b.price).slice(0, 4);
    const sug = chips([['Delivery time', 'डिलीवरी में कितना समय?'], ['Custom stitching', 'कस्टम सिलाई'], ['Return policy', 'रिटर्न पॉलिसी']]);
    if (i === 0 || (!(f.styleIds.length) && !cols.length && !occ.length && !max && !min)) return say(cheap ? T('Here are our most affordable pieces:', 'ये हमारे सबसे किफ़ायती पीस हैं:') : T(hit.length === 1 ? 'I found this for you:' : 'Here are some pieces you might like:', hit.length === 1 ? 'आपके लिए यह मिला:' : 'ये कुछ पीस आपको पसंद आ सकते हैं:'), { products: hit.map(card), suggest: sug });
    const dropEn = [!c && cols.length ? cols.join('/') : '', !o && occ.length ? occ.join('/') : '', !pr && (max || min) ? (max ? 'under ' + money(max) : 'above ' + money(min)) : ''].filter(Boolean), dropHi = [!c && cols.length ? cols.map(x => HIC[x] || x).join('/') : '', !o && occ.length ? occ.map(x => HIO[x] || x).join('/') : '', !pr && (max || min) ? (max ? money(max) + ' से कम' : money(min) + ' से ऊपर') : ''].filter(Boolean);
    const dc = !c && cols.length ? cols.join('/') + ' ' : '', dop = !o && occ.length ? ' for ' + occ.join('/') : '', dpr = !pr && (max || min) ? (max ? ' under ' + money(max) : ' above ' + money(min)) : '';
    return say(T(`I don’t have ${dc}${label ? label.toLowerCase() : 'pieces'}${dop}${dpr} right now` + (priceDropped ? ' — here are the lowest-priced ones instead:' : ' — these are the closest:'), `${label ? label + ' ' : ''}${dropHi.length ? dropHi.join(', ') + ' में ' : ''}अभी बिल्कुल वैसा नहीं है` + (priceDropped ? ' — ये सबसे कम कीमत वाले हैं:' : ' — ये सबसे करीब हैं:')), { products: hit.map(card), suggest: chips([['What do you have?', 'आपके पास क्या-क्या है?'], ['Best sellers', 'बेस्टसेलर']]) });
  }
  return say(T(`I could not find a match for that. Tell me another style, colour or budget — or ${reach} and we will help you personally.`, `इसके लिए कुछ नहीं मिला। कोई और स्टाइल, रंग या बजट बताइए — या ${reach}, हम व्यक्तिगत रूप से मदद करेंगे।`), { suggest: chips([['What do you have?', 'आपके पास क्या-क्या है?'], ['Best sellers', 'बेस्टसेलर']]) });
}
module.exports = { answer, norm, intentOf };
