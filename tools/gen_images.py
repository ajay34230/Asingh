"""Draws the demo catalogue imagery: stylised 'ghost mannequin' Indian ethnic girls' garments (poshak, ghagra-choli,
suit, gown) with gota-patti, bandhani, leheriya, mirror-work and zardozi surfaces, plus hero art.
Output: AVIF + WebP at several widths, one JPEG fallback. Run: python3 tools/gen_images.py
These are illustrative placeholders — replace with real photography (same file names)."""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "img")
os.makedirs(OUT, exist_ok=True)
W, H = 1200, 1500
Y, X = np.mgrid[0:H, 0:W].astype(np.float32)

def rgb(h): h = h.lstrip("#"); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], np.float32)
def mix(a, b, t): return a * (1 - t) + b * t
def smooth(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)

# ---------- surface patterns: return (colour array HxWx3 or None, alpha HxW) ----------
def pat_bandhani(acc, sc=1.0):
    m = Image.new("L", (W, H), 0); d = ImageDraw.Draw(m); st = int(54 * sc); r = max(2, int(5 * sc))
    for j, gy in enumerate(range(-st, H + st, st)):
        for gx in range(-st, W + st, st):
            ox = gx + (st // 2 if j % 2 else 0)
            for dx, dy in ((0, 0), (r * 2, 0), (-r * 2, 0), (0, r * 2), (0, -r * 2)):
                d.ellipse([ox + dx - r, gy + dy - r, ox + dx + r, gy + dy + r], fill=255)
    return None, np.asarray(m.filter(ImageFilter.GaussianBlur(.6)), np.float32) / 255 * .95

def pat_leheriya(cols, sc=1.0):
    t = (X * .55 + Y * .85) / (120 * sc) + .35 * np.sin(Y / (95 * sc))
    idx = np.floor(t).astype(int) % len(cols); frac = t - np.floor(t)
    c = np.stack([np.choose(idx, [cc[k] for cc in cols]) for k in range(3)], -1)
    edge = smooth(np.minimum(frac, 1 - frac) * 14)
    return c * (.85 + .15 * edge[..., None]), np.ones((H, W), np.float32)

def pat_gota(acc, sc=1.0):
    m = Image.new("L", (W, H), 0); d = ImageDraw.Draw(m); st = int(110 * sc); lw = max(3, int(5 * sc))
    for k in range(-H // st - 2, W // st + H // st + 3):
        o = k * st
        d.line([(o, 0), (o + H, H)], fill=255, width=lw); d.line([(o + H, 0), (o, H)], fill=255, width=lw)
    for gy in range(0, H + st, st):
        for gx in range(0, W + st, st):
            d.ellipse([gx - lw * 2, gy - lw * 2, gx + lw * 2, gy + lw * 2], fill=255)
    return None, np.asarray(m.filter(ImageFilter.GaussianBlur(.7)), np.float32) / 255 * .9

def pat_mirror(acc, sc=1.0):
    m = Image.new("L", (W, H), 0); d = ImageDraw.Draw(m); st = int(96 * sc); r = int(20 * sc)
    for j, gy in enumerate(range(0, H + st, st)):
        for gx in range(0, W + st, st):
            ox = gx + (st // 2 if j % 2 else 0)
            d.ellipse([ox - r, gy - r, ox + r, gy + r], fill=255); d.ellipse([ox - r + 5, gy - r + 5, ox + r - 5, gy + r - 5], fill=0)
            d.ellipse([ox - r // 2, gy - r // 2, ox + r // 2, gy + r // 2], fill=255)
            for a in range(8):
                ang = a * math.pi / 4; d.ellipse([ox + math.cos(ang) * (r + 9) - 3, gy + math.sin(ang) * (r + 9) - 3, ox + math.cos(ang) * (r + 9) + 3, gy + math.sin(ang) * (r + 9) + 3], fill=255)
    return None, np.asarray(m.filter(ImageFilter.GaussianBlur(.6)), np.float32) / 255 * .95

def pat_zardozi(acc, sc=1.0):
    m = Image.new("L", (W, H), 0); d = ImageDraw.Draw(m); st = int(120 * sc); r = 17 * sc
    for j, gy in enumerate(range(0, H + st, st)):
        for gx in range(0, W + st, st):
            ox = gx + (st // 2 if j % 2 else 0)
            for a in range(6):
                ang = a * math.pi / 3; d.ellipse([ox + math.cos(ang) * r - r * .6, gy + math.sin(ang) * r - r * .6, ox + math.cos(ang) * r + r * .6, gy + math.sin(ang) * r + r * .6], fill=255)
            d.ellipse([ox - r * .45, gy - r * .45, ox + r * .45, gy + r * .45], fill=0)
    return None, np.asarray(m.filter(ImageFilter.GaussianBlur(.7)), np.float32) / 255 * .9

def pat_doria(acc, sc=1.0):
    g = ((np.floor(X / 5) + np.floor(Y / 5)) % 2).astype(np.float32); lines = ((X % 40 < 2) | (Y % 40 < 2)).astype(np.float32)
    return None, g * .10 + lines * .22

PATS = dict(bandhani=pat_bandhani, gota=pat_gota, mirror=pat_mirror, zardozi=pat_zardozi, doria=pat_doria)

def surface(base, acc, pat, shade, sc=1.0, pal=None):
    """Compose colour surface: base * shade, with pattern in accent (or leheriya palette)."""
    if pat == "leheriya":
        c, a = pat_leheriya(pal, sc); col = c * shade[..., None]
    else:
        _, a = PATS[pat](acc, sc); col = base[None, None, :] * shade[..., None]
        col = mix(col, acc[None, None, :] * (.78 + .22 * shade[..., None]), a[..., None])
    return col

# ---------- geometry ----------
def poly_mask(pts):
    m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    return np.asarray(m.filter(ImageFilter.GaussianBlur(.8)), np.float32) / 255

def bez(p0, p1, p2, p3, n=24):
    t = np.linspace(0, 1, n)[:, None]; p0, p1, p2, p3 = map(np.array, (p0, p1, p2, p3))
    return list((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3)

def mirror_pts(pts, cx=600): return [(2 * cx - x, y) for x, y in pts][::-1]

def ghagra_hw(y, top=620, bot=1330, w0=118, w1=545): return w0 + (w1 - w0) * np.clip((y - top) / (bot - top), 0, 1.15) ** .82

def ghagra_mask():
    ys = np.linspace(620, 1335, 70)
    left = [(600 - ghagra_hw(y), y) for y in ys]
    hem = [(600 + (545 - 2 * i * 545 / 40) , 1330 + 16 * math.sin(i * .9)) for i in range(41)]
    right = [(600 + ghagra_hw(y), y) for y in ys[::-1]]
    return poly_mask(left + [(x, y) for x, y in hem[::-1]][::-1][:0] + [(600 - 545 + 2 * i * 545 / 40, 1330 + 16 * math.sin(i * .9)) for i in range(41)] + right)

def choli_mask(sleeve=560, long=False):
    neck = bez((665, 285), (650, 380), (550, 380), (535, 285))
    pts = [(535, 285), (430, 325), (340, sleeve - 5), (425, sleeve + 12), (462, 440), (488, 650), (712, 650), (738, 440), (775, sleeve + 12), (860, sleeve - 5), (770, 325), (665, 285)] + neck[1:-1]
    return poly_mask(pts)

def kurta_mask():
    neck = bez((665, 285), (650, 380), (550, 380), (535, 285))
    pts = [(535, 285), (430, 325), (330, 690), (410, 712), (462, 440), (452, 1010), (748, 1010), (738, 440), (790, 712), (870, 690), (770, 325), (665, 285)] + neck[1:-1]
    return poly_mask(pts)

def salwar_mask():
    L = [(468, 1000), (606, 1000), (598, 1335), (468, 1340)]; R = [(594, 1000), (732, 1000), (732, 1340), (602, 1335)]
    L = [(470, 1000), (600, 1000), (590, 1340), (455, 1345)]; R = [(600, 1000), (730, 1000), (745, 1345), (610, 1340)]
    return poly_mask(L) + poly_mask(R) - poly_mask(L) * poly_mask(R)

def sash(w0=70, w1=150, a=(470, 300), b=(880, 1030), bow=-160, n=40):
    mid1 = (a[0] + bow, a[1] + 420); mid2 = (b[0] - 60, b[1] - 280)
    c = np.array(bez(a, mid1, mid2, b, n)); t = np.gradient(c, axis=0); nrm = np.stack([-t[:, 1], t[:, 0]], 1); nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-6
    w = np.linspace(w0, w1, n)[:, None]
    wav = np.sin(np.linspace(0, 7, n))[:, None] * 7
    return poly_mask(list(c + nrm * (w + wav)) + list((c - nrm * (w - wav))[::-1])), c, nrm, w

def paint(canvas, mask, col, a=1.0): canvas[:] = mix(canvas, col, (mask * a)[..., None])
def band(mask, y0, y1): return mask * smooth((Y - y0) * .5) * smooth((y1 - Y) * .5)

def folds(cx, hw, freq=5.5, ph=0.0):
    u = (X - cx) / np.maximum(hw, 1); return .70 + .30 * (.5 + .5 * np.cos(u * math.pi * freq + ph + .5 * np.sin(Y / 190)))

def backdrop(tint, dark=False, arch=True):
    base = rgb("#1b0f14") if dark else mix(rgb("#efe4d3"), tint, .12)
    r = np.sqrt(((X - 600) / 760) ** 2 + ((Y - 650) / 980) ** 2)
    c = base[None, None, :] * (1.06 - .42 * r[..., None] ** 1.6)
    c = mix(c, tint[None, None, :] * (.9 if dark else 1.0), .0)
    if arch:  # jharokha-style arch glow
        d = np.where(Y < 520, np.sqrt((X - 600) ** 2 + (Y - 520) ** 2), np.abs(X - 600)) / 430
        glow = smooth(1 - d)
        c = mix(c, (rgb("#f6e6c4") if not dark else tint * 1.3)[None, None, :], (glow * (.30 if dark else .38))[..., None])
        rim = smooth(1 - np.abs(d - 1) * 18) * (Y > 100)
        c = mix(c, rgb("#c9a14a")[None, None, :], (rim * .5)[..., None])
    return c

def finish(img, tint):
    a = np.clip(img, 0, 255)
    rng = np.random.default_rng(7); a = a + rng.normal(0, 2.2, (H, W, 1))
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")

def shadow(canvas, cx=600, y=1372, rx=520, dark=False):
    s = Image.new("L", (W, H), 0); ImageDraw.Draw(s).ellipse([cx - rx, y - 26, cx + rx, y + 26], fill=170)
    s = np.asarray(s.filter(ImageFilter.GaussianBlur(26)), np.float32) / 255
    canvas[:] = canvas * (1 - .5 * s[..., None])

# ---------- garments ----------
def draw_garment(spec, dark=False):
    kind = spec["kind"]; base = rgb(spec["base"]); acc = rgb(spec["acc"]); b2 = rgb(spec["b2"]); od = rgb(spec["odhni"]); pat = spec["pat"]
    pal = [rgb(c) for c in spec.get("pal", [])]
    cv = backdrop(base, dark=dark); shadow(cv)
    ghw = ghagra_hw(Y)
    if kind in ("poshak", "ghagra"):
        gm = ghagra_mask(); sh = folds(600, ghw, 5.5) * (.80 + .20 * smooth((Y - 640) / 160))
        paint(cv, gm, surface(base, acc, pat, sh, 1.0, pal))
        for y0, y1, c, al in ((1190, 1325, acc, .93), (1160, 1172, acc, .8), (1060, 1068, acc, .6) if kind == "poshak" else (0, 0, acc, 0)):
            if al: paint(cv, band(gm, y0, y1), c[None, None, :] * (.78 + .22 * sh[..., None]), al)
        gb = band(gm, 1205, 1310); _, ga = pat_gota(acc, .55); paint(cv, gb * ga, (acc * .55)[None, None, :], .75)
        sx = Image.new("L", (W, H), 0); d = ImageDraw.Draw(sx)   # scalloped hem trim
        for i in range(-12, 13): x = 600 + i * 46; d.ellipse([x - 22, 1318, x + 22, 1362], fill=255)
        sc = np.asarray(sx.filter(ImageFilter.GaussianBlur(.8)), np.float32) / 255
        paint(cv, sc * gm * 0 + sc * (Y > 1318), acc[None, None, :] * .92, .0)
        cm = choli_mask(560 if kind == "poshak" else 520); csh = (.86 + .14 * np.cos((X - 600) / 40)) * (.92 + .08 * smooth((Y - 300) / 300))
        cbase = base if kind == "poshak" else b2
        paint(cv, cm, surface(cbase, acc, "gota" if pat != "gota" else "zardozi", csh, .62))
        for y0, y1 in ((296, 306), (540, 575)): paint(cv, band(cm * ((np.abs(X - 600) > 190) if y0 > 500 else 1), y0, y1), acc[None, None, :], .95)
        paint(cv, poly_mask(bez((665, 285), (650, 380), (550, 380), (535, 285)) + [(535, 285), (665, 285)]) * .0, acc, 0)
        nk = poly_mask(bez((660, 288), (646, 372), (554, 372), (540, 288)) + [(540, 288)]); paint(cv, nk, base[None, None, :] * .42 + rgb('#2a1a14')[None, None, :] * .3, 1)
        paint(cv, poly_mask(bez((665, 285), (650, 380), (550, 380), (535, 285)) + bez((535, 285), (552, 396), (648, 396), (665, 285))) * .95, acc[None, None, :], .0)
    else:  # suit
        sh = (.82 + .18 * np.cos((X - 600) / 55 + .4 * np.sin(Y / 160))) * (.95 - .08 * smooth((Y - 900) / 400))
        sm = salwar_mask(); paint(cv, sm, surface(b2, acc, "doria" if pat != "doria" else "gota", sh, .7))
        paint(cv, band(sm, 1280, 1330), acc[None, None, :], .9)
        km = kurta_mask(); paint(cv, km, surface(base, acc, pat, sh, 1.0, pal))
        paint(cv, band(km * (np.abs(X - 600) < 14), 300, 560), acc[None, None, :], .95)    # placket
        paint(cv, band(km, 965, 1010), acc[None, None, :], .95); paint(cv, band(km * ((np.abs(X - 600) > 190)), 690, 715), acc[None, None, :], .95)
        nk = poly_mask(bez((660, 288), (646, 372), (554, 372), (540, 288)) + [(540, 288)]); paint(cv, nk, base[None, None, :] * .42 + rgb('#2a1a14')[None, None, :] * .3, 1)
    # odhni / dupatta drape
    sm_, c, nrm, w = sash(70, 165 if kind == "poshak" else 120)
    osh = .86 + .14 * np.sin((X * .7 + Y) / 38)
    paint(cv, sm_, od[None, None, :] * osh[..., None], .9)
    em = Image.new("L", (W, H), 0); dd = ImageDraw.Draw(em)
    for sgn in (1, -1):
        e = c + nrm * (w - 14) * sgn; dd.line([tuple(p) for p in e], fill=255, width=11)
    ea = np.asarray(em.filter(ImageFilter.GaussianBlur(.8)), np.float32) / 255 * sm_
    paint(cv, ea, acc[None, None, :] * .95)
    _, ga = pat_zardozi(acc, .55); paint(cv, ga * sm_ * (.55 + .45 * np.sin(Y / 45) ** 2), acc[None, None, :], .55)
    return cv

def flat_odhni(spec, view=1):
    base = rgb(spec["base"]); acc = rgb(spec["acc"]); b2 = rgb(spec["b2"]); pat = spec["pat"]; pal = [rgb(c) for c in spec.get("pal", [])]
    cv = backdrop(rgb(spec["odhni"]), dark=(view == 3), arch=False)
    ang = math.radians(-7 if view == 1 else 6); ca, sa = math.cos(ang), math.sin(ang)
    Xr = (X - 600) * ca + (Y - 750) * sa; Yr = -(X - 600) * sa + (Y - 750) * ca
    wave = 14 * np.sin(Yr / 55) * (np.abs(Xr) > 330)
    m = ((np.abs(Xr) < 470 + wave) & (np.abs(Yr) < 640)).astype(np.float32)
    m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1)), np.float32) / 255
    sh = (.80 + .20 * np.cos(Xr / 85 + .6 * np.sin(Yr / 210))) * (.95 + .05 * np.cos(Yr / 160))
    if view == 2: sh = .78 + .22 * np.cos(Xr / 38 + 1.4 * np.sin(Yr / 120))
    s = surface(base, acc, pat, sh, 1.1 if view != 2 else 1.6, pal)
    shd = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(30)), np.float32) / 255
    cv = cv * (1 - .35 * np.roll(np.roll(shd, 24, 0), 14, 1)[..., None]); paint(cv, m, s)
    for lo, hi in ((380, 440), (452, 462)): paint(cv, m * ((np.abs(Xr) > lo) & (np.abs(Xr) < hi)), acc[None, None, :] * (.8 + .2 * sh[..., None]), .94)
    paint(cv, m * (np.abs(Yr) > 560), acc[None, None, :] * (.8 + .2 * sh[..., None]), .94)
    _, ga = pat_gota(acc, .5); paint(cv, m * ga * ((np.abs(Yr) > 565) | (np.abs(Xr) > 385)), (acc * .5)[None, None, :], .7)
    corner = m * ((Xr > 120) & (Yr < -260 + (Xr - 120) * .0 - 0) * 0 + (Xr + Yr * .0 > 200) & (Yr > 250 + 0))
    return cv

def detail_view(spec, seed):
    base = rgb(spec["base"]); acc = rgb(spec["acc"]); pat = spec["pat"]; pal = [rgb(c) for c in spec.get("pal", [])]
    ph = seed * 1.7
    sh = .72 + .28 * (.5 + .5 * np.cos(X / 70 + 2.2 * np.sin(Y / 230 + ph) + ph)) * (.9 + .1 * np.cos(Y / 90))
    s = surface(base, acc, pat, sh, 2.3, pal)
    # embroidered border across the lower third with scallops
    bm = ((Y > 930) & (Y < 1250)).astype(np.float32)
    s = mix(s, acc[None, None, :] * (.72 + .28 * sh[..., None]), (bm * (np.abs(Y - 1090) < 38) + bm * (np.abs(Y - 960) < 10) + bm * (np.abs(Y - 1220) < 10) > 0)[..., None] * .95)
    _, ga = pat_gota(acc, 1.0); rib = bm * (np.abs(Y - 1090) < 38); s = mix(s, (acc * .45)[None, None, :], (rib * ga)[..., None] * .8)
    _, za = pat_zardozi(acc, 1.5); s = mix(s, acc[None, None, :] * 1.0, (bm * (Y > 1130) * (Y < 1215) * za)[..., None] * .8)
    below = (Y > 1250).astype(np.float32); s = s * (1 - .25 * below[..., None] * smooth((Y - 1250) / 250)[..., None])
    return s

# ---------- catalogue (slug, kind, colours, pattern) ----------
SPECS = {
 "maharani-poshak":  dict(kind="poshak", base="#7a1f3d", acc="#e9c46a", b2="#7a1f3d", odhni="#c9486e", pat="zardozi"),
 "jodha-gown":       dict(kind="poshak", base="#14463c", acc="#e3c06a", b2="#14463c", odhni="#a8352b", pat="gota"),
 "gangaur-chaniya":  dict(kind="ghagra", base="#c4572b", acc="#f4dca0", b2="#7a1f3d", odhni="#e8a33b", pat="leheriya", pal=["#c4572b", "#e8a33b", "#7a1f3d", "#f2d489"]),
 "teej-lehenga":     dict(kind="ghagra", base="#c23a6e", acc="#f6e3b4", b2="#1d6b5a", odhni="#1d6b5a", pat="leheriya", pal=["#c23a6e", "#f09a3a", "#1d6b5a", "#f6e3b4"]),
 "jaipur-bandhani":  dict(kind="ghagra", base="#a8281f", acc="#f7ecd2", b2="#7b1d17", odhni="#e9b44a", pat="bandhani"),
 "marwari-sharara":  dict(kind="suit", base="#b0243a", acc="#f5e3b3", b2="#b0243a", odhni="#e9c46a", pat="bandhani"),
 "kota-doria-suit":  dict(kind="suit", base="#e4cfa8", acc="#8a5a3c", b2="#c9a26e", odhni="#b5532f", pat="doria"),
 "mewar-patiala":    dict(kind="suit", base="#2c3a6b", acc="#e8c875", b2="#1f2b52", odhni="#d98b3a", pat="gota"),
 "udaipur-gharara":  dict(kind="ghagra", base="#3d2a6b", acc="#f0d9a6", b2="#d98b3a", odhni="#c23a6e", pat="mirror"),
 "rani-sa-anarkali": dict(kind="poshak", base="#d6457f", acc="#f6e3b4", b2="#d6457f", odhni="#fff1d6", pat="gota"),
 "pushkar-kurti-palazzo": dict(kind="suit", base="#e8913a", acc="#fff1d6", b2="#e8913a", odhni="#7a1f3d", pat="leheriya", pal=["#e8913a", "#c23a6e", "#1d6b5a", "#f7e3a0"]),
 "kesariya-angrakha": dict(kind="suit", base="#e0902a", acc="#7a1f3d", b2="#e0902a", odhni="#b0243a", pat="zardozi"),
 "gulab-peplum":     dict(kind="suit", base="#d98b9c", acc="#f6e3b4", b2="#b85a74", odhni="#7a1f3d", pat="gota"),
 "nila-kurti-skirt": dict(kind="ghagra", base="#1f5a8a", acc="#f0d9a6", b2="#173f63", odhni="#e9b44a", pat="bandhani"),
 "sabz-a-line":      dict(kind="suit", base="#2f6b4f", acc="#f4dca0", b2="#1e4a36", odhni="#d6457f", pat="doria"),
 "mehndi-frock":     dict(kind="poshak", base="#6f8f3a", acc="#f6e3b4", b2="#6f8f3a", odhni="#d98b3a", pat="gota"),
 "aaina-indo-western": dict(kind="suit", base="#1d6b6b", acc="#f0d9a6", b2="#134848", odhni="#c23a6e", pat="mirror"),
}

def save(im, name, widths, ratio, jpg_w=None):
    for wd in widths:
        r = im.resize((wd, round(wd * ratio)), Image.LANCZOS)
        r.save(f"{OUT}/{name}-{wd}.avif", quality=44); r.save(f"{OUT}/{name}-{wd}.webp", quality=70, method=5)
        if wd == jpg_w: r.save(f"{OUT}/{name}-{wd}.jpg", quality=72, optimize=True, progressive=True)

def render(slug, spec):
    k = spec["kind"]
    if k == "odhni": views = [flat_odhni(spec, 1), Image.fromarray(np.clip(detail_view(spec, 1), 0, 255).astype(np.uint8)), flat_odhni(spec, 3)]
    else: views = [draw_garment(spec), detail_view(spec, 2), draw_garment(spec, dark=True)]
    out = []
    for v in views: out.append(v if isinstance(v, Image.Image) else finish(v, None))
    return out

def hero():
    def feather(w, h, f=.18):
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32); e = np.minimum(np.minimum(xx, w - 1 - xx) / (w * f), np.minimum(yy, h - 1 - yy) / (h * f)); return smooth(e)
    def scene(w, h, items):
        c = np.zeros((h, w, 3), np.float32); yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        r = np.sqrt(((xx - w * .7) / (w * .8)) ** 2 + ((yy - h * .45) / (h * .9)) ** 2)
        c[:] = rgb("#3b1022")[None, None, :] * (1.15 - .75 * r[..., None] ** 1.3)
        for cx, top, sc, name in items:
            g = np.asarray(draw_garment(SPECS[name], dark=True), np.float32); gi = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8))
            gi = gi.resize((int(W * sc), int(H * sc)), Image.LANCZOS); a = np.asarray(gi, np.float32); f = feather(gi.width, gi.height)[..., None]
            x0, y0 = int(cx - gi.width / 2), int(top); xs, ys = max(0, x0), max(0, y0); xe, ye = min(w, x0 + gi.width), min(h, y0 + gi.height)
            sub = a[ys - y0:ye - y0, xs - x0:xe - x0]; ff = f[ys - y0:ye - y0, xs - x0:xe - x0]
            c[ys:ye, xs:xe] = c[ys:ye, xs:xe] * (1 - ff) + sub * ff
        rng = np.random.default_rng(3); return Image.fromarray(np.clip(c + rng.normal(0, 2, (h, w, 1)), 0, 255).astype(np.uint8))
    wide = scene(2560, 1280, [(1580, 90, .78, "jodha-gown"), (2060, 150, .82, "maharani-poshak"), (2480, 260, .66, "rani-sa-anarkali")])
    save(wide, "hero-wide", [1280, 1920, 2560, 3840], .5, 1920)
    tall = scene(1080, 1350, [(540, 8, .6, "maharani-poshak")])
    save(tall, "hero-tall", [480, 800, 1080], 1.25, 800)

if __name__ == "__main__":
    import sys
    if "--hero" in sys.argv: hero(); sys.exit()
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for slug, spec in SPECS.items():
        if only and slug not in only: continue
        ims = render(slug, spec)
        for i, im in enumerate(ims):
            if not isinstance(im, Image.Image): im = finish(im, None)
            save(im, f"{slug}-{i + 1}", [400, 800, 1200], H / W, 800)
        if slug in ("maharani-poshak", "gangaur-chaniya", "jaipur-bandhani", "mewar-patiala") :
            sq = ims[0].crop((0, 160, W, 1360)); k = ["maharani-poshak", "gangaur-chaniya", "jaipur-bandhani", "mewar-patiala"].index(slug) + 1
            save(sq, f"collection-{k}", [400, 800], 1.0, 800)
    if not only: hero()
    print("done")
