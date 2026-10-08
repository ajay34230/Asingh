'use strict';
/* Body reading + multipart parsing + image sniffing. No dependencies. */
function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = []; let n = 0;
    req.on('data', c => { n += c.length; if (n > limit) { reject(Object.assign(new Error('Payload too large'), { status: 413 })); req.destroy(); } else chunks.push(c); });
    req.on('end', () => resolve(Buffer.concat(chunks))); req.on('error', reject);
  });
}
function parseMultipart(buf, contentType) {
  const m = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType || ''); if (!m) throw Object.assign(new Error('Bad multipart'), { status: 400 });
  const delim = Buffer.from('--' + (m[1] || m[2])); const fields = {}; let file = null; let pos = buf.indexOf(delim);
  while (pos !== -1) {
    const next = buf.indexOf(delim, pos + delim.length); if (next === -1) break;
    let part = buf.subarray(pos + delim.length, next); if (part[0] === 13) part = part.subarray(2); // \r\n
    const he = part.indexOf('\r\n\r\n'); if (he > -1) {
      const head = part.subarray(0, he).toString('utf8'), body = part.subarray(he + 4, part.length - 2);
      const nm = /name="([^"]*)"/i.exec(head), fn = /filename="([^"]*)"/i.exec(head);
      if (nm) { if (fn) { if (!file) file = { field: nm[1], filename: fn[1], data: body }; } else fields[nm[1]] = body.toString('utf8').slice(0, 2000); }
    }
    pos = next;
  }
  return { fields, file };
}
function sniffImage(b) {
  if (b.length < 12) return null;
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return { ext: 'jpg', mime: 'image/jpeg' };
  if (b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return { ext: 'png', mime: 'image/png' };
  if (b.subarray(0, 4).toString() === 'RIFF' && b.subarray(8, 12).toString() === 'WEBP') return { ext: 'webp', mime: 'image/webp' };
  return null; // SVG/GIF/HTML deliberately rejected
}
module.exports = { readBody, parseMultipart, sniffImage };
