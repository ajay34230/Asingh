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

{{name}} brings you girls’ suits and ethnic wear — Anarkali suits, lehenga cholis, shararas and ghararas, kurti sets, Patiala and straight suits, Rajputi poshaks, indo-western dresses and ethnic gowns — with the craft of traditional embroidery.

## Crafted by hand
Every piece is finished with traditional work such as **gota patti**, **zardozi**, **bandhani** and **shisha mirror work**. Nothing is mass-produced: each dress is made for you, in your size.

## Made to your measure
Choose it unstitched, semi-stitched, or fully custom-stitched to your measurements. Our team confirms every detail with you before we begin.

## Our promise
- Honest descriptions and real photographs
- Fair prices, with free shipping above a minimum order
- Friendly help before and after you buy

*Replace this text with your own story in the admin: Pages → About us.*`, titleHi: "हमारे बारे में", bodyHi: `# हमारी कहानी

{{name}} आपके लिए लड़कियों के सूट और एथनिक वियर लाता है — अनारकली सूट, लहंगा चोली, शरारा और ग़रारा, कुर्ती सेट, पटियाला और स्ट्रेट सूट, राजपूती पोशाक, इंडो-वेस्टर्न ड्रेस और एथनिक गाउन — पारंपरिक कढ़ाई की कारीगरी के साथ।

## हाथों से तैयार
हर परिधान पर **गोटा पट्टी**, **ज़रदोज़ी**, **बांधनी** और **शीशे के काम** जैसा पारंपरिक काम होता है। कुछ भी थोक में नहीं बनता: हर ड्रेस आपके लिए, आपके साइज़ में बनती है।

## आपके माप के अनुसार
इसे बिना सिला, अर्ध-सिला या पूरी तरह आपके माप से कस्टम-सिला चुनें। काम शुरू करने से पहले हमारी टीम हर बात आपसे पक्की करती है।

## हमारा वादा
- ईमानदार विवरण और असली तस्वीरें
- उचित दाम, और न्यूनतम ऑर्डर से ऊपर मुफ़्त शिपिंग
- खरीदने से पहले और बाद में दोस्ताना मदद` },
  { slug: 'contact', title: 'Contact us', group: 'help', body: `We’d love to help you choose the right dress, check a measurement, or follow up on an order.

**Email:** {{email}}
**Phone / WhatsApp:** {{phone}}
**Hours:** {{hours}}
**Address:** {{address}}

Already ordered? You can [track your order](track.html) with your order number and mobile number.`, titleHi: "संपर्क करें", bodyHi: `हम आपको सही ड्रेस चुनने, माप जाँचने या ऑर्डर की जानकारी लेने में खुशी से मदद करेंगे।

**ईमेल:** {{email}}
**फ़ोन / WhatsApp:** {{phone}}
**समय:** {{hours}}
**पता:** {{address}}

ऑर्डर कर चुके हैं? अपने ऑर्डर नंबर और मोबाइल नंबर से [अपना ऑर्डर ट्रैक करें](track.html)।` },
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
See our [Care guide](care-guide.html).`, titleHi: "अक्सर पूछे जाने वाले प्रश्न", bodyHi: `## ऑर्डर कैसे करूँ?
अपनी ड्रेस बैग में जोड़ें, साइज़ और सिलाई चुनें, और चेकआउट करें — गेस्ट के रूप में (खाते की ज़रूरत नहीं) या खाते से। आप हमारा UPI QR स्कैन करके भुगतान करेंगे और भुगतान का स्क्रीनशॉट अपलोड करेंगे।

## भुगतान कैसे होता है?
ऑर्डर करने के बाद हम अपना भुगतान QR और सही रकम दिखाते हैं। किसी भी UPI ऐप से भुगतान करें, फिर स्क्रीनशॉट अपलोड करें। हम उसे जाँचकर आपका ऑर्डर पक्का करते हैं।

## अपना ऑर्डर कैसे ट्रैक करूँ?
हमारे दिए ऑर्डर नंबर (जैसे AS-48213) और अपने मोबाइल नंबर के साथ [ट्रैकिंग पेज](track.html) पर जाएँ। साइन इन की ज़रूरत नहीं।

## बिना सिला, अर्ध-सिला और कस्टम-सिला का क्या मतलब है?
**बिना सिले** परिधान कपड़े के रूप में आते हैं जिन्हें आप अपने दर्ज़ी के पास ले जा सकती हैं। **अर्ध-सिले** परिधान आंशिक रूप से बने होते हैं और फ़िट के लिए गुंजाइश रहती है। **कस्टम-सिले** परिधान हमारे कारीगर आपके माप से बनाते हैं।

## कितना समय लगता है?
बिना सिले परिधान कुछ दिनों में शिप हो जाते हैं। कस्टम-सिले में ज़्यादा समय लगता है — समय हर प्रोडक्ट पर दिखाया गया है।

## क्या रिटर्न या एक्सचेंज हो सकता है?
कृपया हमारा [शिपिंग और रिटर्न](shipping-returns.html) पेज पढ़ें।

## अपनी ड्रेस की देखभाल कैसे करूँ?
हमारी [देखभाल गाइड](care-guide.html) देखें।` },
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

*These are starting templates — please review and edit them to match your real policy.*`, titleHi: "शिपिंग और रिटर्न", bodyHi: `## शिपिंग
- हम पूरे भारत में शिप करते हैं। आपके बैग में दिखाई गई रकम से ऊपर मुफ़्त शिपिंग; उससे कम पर छोटा फ़्लैट शुल्क लगता है।
- बिना सिले परिधान आमतौर पर कुछ दिनों में शिप हो जाते हैं। अर्ध-सिले और कस्टम-सिले में ज़्यादा समय लगता है — अनुमान हर प्रोडक्ट पेज पर है।
- आप अपने ऑर्डर की स्थिति और कूरियर ट्रैकिंग का विवरण [ट्रैकिंग पेज](track.html) पर देखेंगे।

## रिटर्न और एक्सचेंज
- बिना सिले और अर्ध-सिले परिधान डिलीवरी के 7 दिन के भीतर लौटाए जा सकते हैं, यदि वे अनपहने, बिना धुले और मूल हालत में हों।
- कस्टम-सिले परिधान आपके माप से बनते हैं और वापस नहीं हो सकते, पर हम एक बार मुफ़्त अल्टरेशन देते हैं।
- रिटर्न शुरू करने के लिए कृपया अपने ऑर्डर नंबर के साथ [हमसे संपर्क करें](contact.html)।

## रद्द करना
भुगतान सत्यापित होने तक आप अपने ऑर्डर पेज से ऑर्डर रद्द कर सकते हैं। उसके बाद कृपया हमसे संपर्क करें।` },
  { slug: 'privacy-policy', title: 'Privacy policy', group: 'legal', body: `## What we collect
When you order we collect your name, email, mobile number and delivery address, and the payment screenshot you upload. If you create an account we also store your password securely (we cannot read it). If you subscribe or contact us, we keep your email and message.

## How we use it
Only to process and deliver your order, verify payment, contact you about it, and — if you subscribed — send you updates. We do not sell your data.

## Who can see it
Only you (when signed in or tracking with your order number and mobile number) and our store team. Payment screenshots are stored privately.

## Cookies
We use one essential cookie to keep you signed in or remember your guest session. If we enable Google Analytics, it loads only after you press “Accept” on the cookie notice, and you can change your mind any time with “Cookie settings” in the footer. We do not use advertising cookies or sell your data.

## How long we keep it
Order records are kept for accounting and tax purposes. When you delete your account we erase your name, email, phone and address from them. Newsletter details are removed when you unsubscribe or delete your account.

## Your choices
You can download your data, change your password and email, sign out of other devices, unsubscribe, or delete your account yourself under **My account → Privacy & security**. You can also write to {{email}}.

*This is a starting template, not legal advice — please review it with a professional before launch.*`, titleHi: "गोपनीयता नीति", bodyHi: `## हम क्या जानकारी लेते हैं
ऑर्डर करते समय हम आपका नाम, ईमेल, मोबाइल नंबर, डिलीवरी का पता और आपका अपलोड किया भुगतान स्क्रीनशॉट लेते हैं। खाता बनाने पर आपका पासवर्ड सुरक्षित रूप से संग्रहीत होता है (हम उसे पढ़ नहीं सकते)। सब्सक्राइब करने या संपर्क करने पर हम आपका ईमेल और संदेश रखते हैं।

## हम इसका उपयोग कैसे करते हैं
केवल आपका ऑर्डर प्रोसेस और डिलीवर करने, भुगतान सत्यापित करने, उसके बारे में आपसे संपर्क करने और — यदि आपने सब्सक्राइब किया है — अपडेट भेजने के लिए। हम आपका डेटा बेचते नहीं हैं।

## इसे कौन देख सकता है
केवल आप (साइन इन करने पर या ऑर्डर नंबर और मोबाइल नंबर से ट्रैक करने पर) और हमारी स्टोर टीम। भुगतान स्क्रीनशॉट निजी रूप से रखे जाते हैं।

## कुकीज़
आपको साइन इन रखने या गेस्ट सत्र याद रखने के लिए हम एक ज़रूरी कुकी इस्तेमाल करते हैं। यदि हम Google Analytics चालू करते हैं, तो वह कुकी सूचना पर “स्वीकार करें” दबाने के बाद ही लोड होता है, और आप फ़ुटर में “कुकी सेटिंग” से कभी भी अपना फ़ैसला बदल सकते हैं। हम विज्ञापन कुकीज़ का उपयोग नहीं करते और आपका डेटा नहीं बेचते।

## हम इसे कितने समय रखते हैं
ऑर्डर रिकॉर्ड लेखा और कर के उद्देश्य से रखे जाते हैं। आपके खाता हटाने पर हम उनसे आपका नाम, ईमेल, फ़ोन और पता मिटा देते हैं। सदस्यता रद्द करने या खाता हटाने पर न्यूज़लेटर का विवरण हटा दिया जाता है।

## आपके विकल्प
आप **मेरा खाता → गोपनीयता और सुरक्षा** में अपना डेटा डाउनलोड कर सकते हैं, पासवर्ड और ईमेल बदल सकते हैं, दूसरे डिवाइस से साइन आउट कर सकते हैं, सदस्यता रद्द कर सकते हैं या खाता खुद हटा सकते हैं। आप {{email}} पर भी लिख सकते हैं।` },
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

*This is a starting template, not legal advice — please review it with a professional before launch.*`, titleHi: "नियम और शर्तें", bodyHi: `## ऑर्डर
ऑर्डर करना खरीदने का प्रस्ताव है। भुगतान सत्यापित होने पर हम उसे पक्का करते हैं। यदि कोई आइटम उपलब्ध न हो या भुगतान सत्यापित न हो सके तो हम ऑर्डर रद्द कर सकते हैं, और चुकाई गई रकम लौटा देंगे।

## कीमतें
कीमतें भारतीय रुपयों में हैं और जब तक अन्यथा न लिखा हो, लागू करों सहित हैं। हम कभी भी कीमतें बदल सकते हैं; चेकआउट के समय की कीमत लागू होती है।

## प्रोडक्ट के रंग
हम अपनी ड्रेस की तस्वीरें ध्यान से लेते हैं, पर स्क्रीन और रोशनी के अनुसार रंग थोड़े अलग दिख सकते हैं। हाथ के काम में छोटे अंतर सामान्य हैं।

## कस्टम-सिले ऑर्डर
कस्टम-सिले परिधान आपके दिए माप से बनते हैं। कृपया ऑर्डर से पहले अपने साइज़ का विवरण जाँच लें।

## संपर्क
कोई प्रश्न? {{email}} पर लिखें।` },
  { slug: 'care-guide', title: 'Care guide', group: 'help', body: `## Looking after your dress
- **Dry clean only** for embroidered, gota patti and zardozi pieces.
- Store folded in a **cotton or muslin cloth**, away from direct sunlight and damp.
- Avoid perfume or spray directly on the fabric or the zari.
- Refold every few months along different lines to avoid permanent creases.

## Bandhani and leheriya
Air out after wearing. Wash separately (hand-wash cold) if the label allows; the dyes may bleed in the first wash.

## Zari and gota patti
Keep away from moisture to prevent tarnishing. Never iron directly on zari — use a cloth between the iron and the work.`, titleHi: "देखभाल गाइड", bodyHi: `## अपनी ड्रेस की देखभाल
- कढ़ाई, गोटा पट्टी और ज़रदोज़ी वाले परिधान **सिर्फ़ ड्राई क्लीन** कराएँ।
- इन्हें **सूती या मलमल के कपड़े** में तह करके रखें, सीधी धूप और नमी से दूर।
- कपड़े या ज़री पर सीधे परफ़्यूम या स्प्रे न करें।
- स्थायी सलवटों से बचने के लिए हर कुछ महीने में अलग-अलग जगह से तह बदलें।

## बांधनी और लहरिया
पहनने के बाद हवा में रखें। लेबल अनुमति दे तो अलग से (ठंडे पानी में हाथ से) धोएँ; पहली धुलाई में रंग छूट सकते हैं।

## ज़री और गोटा पट्टी
कालिख से बचाने के लिए नमी से दूर रखें। ज़री पर सीधे इस्त्री कभी न करें — इस्त्री और काम के बीच कपड़ा रखें।` }
];
module.exports = { render, plain, DEFAULT_PAGES, esc };
