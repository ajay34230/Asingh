/* LocalDrop: QR code generator (byte mode, error correction L, versions 1 to 10). Works offline, no libraries. */
(function () {
  'use strict';
  var LD = window.LD;

  // Per version (1..10): [ecc codewords per block, blocks in group 1, data codewords in group 1 blocks, blocks in group 2, data codewords in group 2 blocks] for level L.
  var BLOCKS = [
    null,
    [7, 1, 19, 0, 0], [10, 1, 34, 0, 0], [15, 1, 55, 0, 0], [20, 1, 80, 0, 0], [26, 1, 108, 0, 0],
    [18, 2, 68, 0, 0], [20, 2, 78, 0, 0], [24, 2, 97, 0, 0], [30, 2, 116, 0, 0], [18, 2, 68, 2, 69]
  ];
  var ALIGN = [null, [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]];

  // ---- Reed-Solomon over GF(256) --------------------------------------------
  var EXP = new Array(512), LOG = new Array(256);
  (function () {
    var x = 1;
    for (var i = 0; i < 255; i++) {
      EXP[i] = x;
      LOG[x] = i;
      x <<= 1;
      if (x & 0x100) x ^= 0x11d;
    }
    for (var j = 255; j < 512; j++) EXP[j] = EXP[j - 255];
  })();
  function mul(a, b) { return a === 0 || b === 0 ? 0 : EXP[LOG[a] + LOG[b]]; }
  function generator(deg) {
    var g = [1];
    for (var i = 0; i < deg; i++) {
      var next = new Array(g.length + 1);
      for (var k = 0; k < next.length; k++) next[k] = 0;
      for (var j = 0; j < g.length; j++) {
        next[j] ^= g[j];
        next[j + 1] ^= mul(g[j], EXP[i]);
      }
      g = next;
    }
    return g;
  }
  function eccFor(data, deg) {
    var gen = generator(deg);
    var res = [];
    for (var i = 0; i < deg; i++) res.push(0);
    data.forEach(function (b) {
      var f = b ^ res.shift();
      res.push(0);
      for (var i2 = 0; i2 < deg; i2++) res[i2] ^= mul(gen[i2 + 1], f);
    });
    return res;
  }

  function utf8(str) {
    var bytes = [];
    var s = unescape(encodeURIComponent(str));
    for (var i = 0; i < s.length; i++) bytes.push(s.charCodeAt(i));
    return bytes;
  }

  function capacityBytes(v) {
    var b = BLOCKS[v];
    return b[1] * b[2] + b[3] * b[4];
  }

  function encodeData(bytes, v) {
    var bits = [];
    function put(val, len) { for (var i = len - 1; i >= 0; i--) bits.push((val >>> i) & 1); }
    put(4, 4);
    put(bytes.length, v < 10 ? 8 : 16);
    bytes.forEach(function (b) { put(b, 8); });
    var cap = capacityBytes(v) * 8;
    put(0, Math.min(4, cap - bits.length));
    while (bits.length % 8) bits.push(0);
    var out = [];
    for (var i = 0; i < bits.length; i += 8) {
      var x = 0;
      for (var j = 0; j < 8; j++) x = (x << 1) | bits[i + j];
      out.push(x);
    }
    for (var pad = 0xec; out.length < capacityBytes(v); pad ^= 0xec ^ 0x11) out.push(pad);
    return out;
  }

  function interleave(data, v) {
    var b = BLOCKS[v];
    var blocks = [], ecc = [], pos = 0;
    for (var g = 0; g < 2; g++) {
      var n = g === 0 ? b[1] : b[3], len = g === 0 ? b[2] : b[4];
      for (var i = 0; i < n; i++) {
        var chunk = data.slice(pos, pos + len);
        pos += len;
        blocks.push(chunk);
        ecc.push(eccFor(chunk, b[0]));
      }
    }
    var out = [];
    var maxLen = Math.max(b[2], b[4]);
    for (var k = 0; k < maxLen; k++) blocks.forEach(function (bl) { if (k < bl.length) out.push(bl[k]); });
    for (var e = 0; e < b[0]; e++) ecc.forEach(function (bl) { out.push(bl[e]); });
    return out;
  }

  // ---- matrix ---------------------------------------------------------------
  function makeMatrix(v, codewords, mask) {
    var size = v * 4 + 17;
    var m = [], fn = [];
    for (var r = 0; r < size; r++) {
      m.push(new Array(size).fill(false));
      fn.push(new Array(size).fill(false));
    }
    function set(x, y, dark) { m[y][x] = dark; fn[y][x] = true; }

    function finder(cx, cy) {
      for (var dy = -4; dy <= 4; dy++) {
        for (var dx = -4; dx <= 4; dx++) {
          var x = cx + dx, y = cy + dy;
          if (x < 0 || y < 0 || x >= size || y >= size) continue;
          var d = Math.max(Math.abs(dx), Math.abs(dy));
          set(x, y, d !== 2 && d !== 4);
        }
      }
    }
    finder(3, 3); finder(size - 4, 3); finder(3, size - 4);

    for (var i = 8; i < size - 8; i++) { set(i, 6, i % 2 === 0); set(6, i, i % 2 === 0); }

    var al = ALIGN[v];
    for (var a = 0; a < al.length; a++) {
      for (var b2 = 0; b2 < al.length; b2++) {
        if ((a === 0 && b2 === 0) || (a === 0 && b2 === al.length - 1) || (a === al.length - 1 && b2 === 0)) continue;
        for (var dy2 = -2; dy2 <= 2; dy2++) {
          for (var dx2 = -2; dx2 <= 2; dx2++) {
            set(al[a] + dx2, al[b2] + dy2, Math.max(Math.abs(dx2), Math.abs(dy2)) !== 1);
          }
        }
      }
    }

    // reserve format areas (drawn later)
    function drawFormat(mk) {
      var data = (1 << 3) | mk; // level L = 01
      var rem = data;
      for (var q = 0; q < 10; q++) rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
      var bits = ((data << 10) | rem) ^ 0x5412;
      function bit(n) { return ((bits >>> n) & 1) !== 0; }
      for (var k = 0; k <= 5; k++) set(8, k, bit(k));
      set(8, 7, bit(6)); set(8, 8, bit(7)); set(7, 8, bit(8));
      for (var k2 = 9; k2 < 15; k2++) set(14 - k2, 8, bit(k2));
      for (var k3 = 0; k3 < 8; k3++) set(size - 1 - k3, 8, bit(k3));
      for (var k4 = 8; k4 < 15; k4++) set(8, size - 15 + k4, bit(k4));
      set(8, size - 8, true);
    }
    drawFormat(0);

    if (v >= 7) {
      var rem2 = v;
      for (var q2 = 0; q2 < 12; q2++) rem2 = (rem2 << 1) ^ ((rem2 >>> 11) * 0x1f25);
      var vb = (v << 12) | rem2;
      for (var k5 = 0; k5 < 18; k5++) {
        var dark = ((vb >>> k5) & 1) !== 0;
        var aa = size - 11 + (k5 % 3), bb = Math.floor(k5 / 3);
        set(aa, bb, dark);
        set(bb, aa, dark);
      }
    }

    // place data
    var bitIdx = 0, total = codewords.length * 8;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          var x2 = right - j;
          var upward = ((right + 1) & 2) === 0;
          var y2 = upward ? size - 1 - vert : vert;
          if (!fn[y2][x2] && bitIdx < total) {
            m[y2][x2] = ((codewords[bitIdx >>> 3] >>> (7 - (bitIdx & 7))) & 1) !== 0;
            bitIdx++;
          }
        }
      }
    }

    function applyMask(mk) {
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          var inv;
          switch (mk) {
            case 0: inv = (x + y) % 2 === 0; break;
            case 1: inv = y % 2 === 0; break;
            case 2: inv = x % 3 === 0; break;
            case 3: inv = (x + y) % 3 === 0; break;
            case 4: inv = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; break;
            case 5: inv = ((x * y) % 2) + ((x * y) % 3) === 0; break;
            case 6: inv = (((x * y) % 2) + ((x * y) % 3)) % 2 === 0; break;
            default: inv = (((x + y) % 2) + ((x * y) % 3)) % 2 === 0;
          }
          if (!fn[y][x] && inv) m[y][x] = !m[y][x];
        }
      }
    }

    if (mask >= 0) {
      applyMask(mask);
      drawFormat(mask);
      return m;
    }
    var best = 0, bestScore = Infinity;
    for (var mk2 = 0; mk2 < 8; mk2++) {
      applyMask(mk2);
      drawFormat(mk2);
      var sc = penalty(m, size);
      if (sc < bestScore) { bestScore = sc; best = mk2; }
      applyMask(mk2);
    }
    applyMask(best);
    drawFormat(best);
    return m;
  }

  function penalty(m, size) {
    var score = 0, x, y, run, i;
    for (var pass = 0; pass < 2; pass++) {
      for (y = 0; y < size; y++) {
        run = 1;
        var hist = [];
        for (x = 1; x < size; x++) {
          var cur = pass ? m[x][y] : m[y][x];
          var prev = pass ? m[x - 1][y] : m[y][x - 1];
          if (cur === prev) { run++; if (run === 5) score += 3; else if (run > 5) score++; }
          else run = 1;
        }
        // finder-like patterns
        var line = [];
        for (i = 0; i < size; i++) line.push((pass ? m[i][y] : m[y][i]) ? 1 : 0);
        var s = line.join('');
        var pats = ['10111010000', '00001011101'];
        for (var p = 0; p < 2; p++) {
          var at = s.indexOf(pats[p]);
          while (at >= 0) { score += 40; at = s.indexOf(pats[p], at + 1); }
        }
      }
    }
    for (y = 0; y < size - 1; y++) {
      for (x = 0; x < size - 1; x++) {
        var c = m[y][x];
        if (c === m[y][x + 1] && c === m[y + 1][x] && c === m[y + 1][x + 1]) score += 3;
      }
    }
    var dark = 0;
    for (y = 0; y < size; y++) for (x = 0; x < size; x++) if (m[y][x]) dark++;
    var k = Math.ceil(Math.abs(dark * 20 - size * size * 10) / (size * size)) - 1;
    score += Math.max(0, k) * 10;
    return score;
  }

  /** Returns a square matrix of booleans (true = dark). Throws if the text is too long. */
  LD.qrMatrix = function (text, mask) {
    var bytes = utf8(text);
    var v = 1;
    while (v <= 10) {
      var overhead = v < 10 ? 2 : 3; // mode + length, in whole bytes (rounded up)
      if (bytes.length + overhead <= capacityBytes(v)) break;
      v++;
    }
    if (v > 10) throw new Error('That text is too long for a QR code.');
    var data = encodeData(bytes, v);
    return makeMatrix(v, interleave(data, v), mask === undefined ? -1 : mask);
  };

  /** Draws a QR code into a canvas element and returns it. */
  LD.qrCanvas = function (text, px, opts) {
    opts = opts || {};
    var m = LD.qrMatrix(text);
    var quiet = 3;
    var n = m.length + quiet * 2;
    var scale = Math.max(2, Math.floor((px || 220) / n));
    var c = document.createElement('canvas');
    c.width = c.height = n * scale;
    var g = c.getContext('2d');
    g.fillStyle = opts.light || '#ffffff';
    g.fillRect(0, 0, c.width, c.height);
    g.fillStyle = opts.dark || '#0b2236';
    for (var y = 0; y < m.length; y++) {
      for (var x = 0; x < m.length; x++) {
        if (m[y][x]) g.fillRect((x + quiet) * scale, (y + quiet) * scale, scale, scale);
      }
    }
    c.className = 'qr-canvas';
    c.setAttribute('role', 'img');
    c.setAttribute('aria-label', 'QR code for ' + text);
    return c;
  };
})();
